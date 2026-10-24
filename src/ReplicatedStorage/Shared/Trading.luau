--!strict

--[[
	Direct trades and the trade audit.

	TradeService calls finish() with both live profiles. The client can
	propose an offer, but only finish() moves anything, and only after both
	players have confirmed, the 3 second lock has passed, and both bags
	still match the offer. A failed finish puts both profiles back.

	MarketBoard uses the same item rules, value table, holds, and audit
	shape. Tune the tables below. Do not bury numbers in branches.

	Robux-bought items stay bound. Trading.ROBUX_ITEM_TRADING_ENABLED is
	the kill switch and it stays false. Gems are a farmable currency
	(v1.1), so GEM_TRADING_ENABLED defaults true and New-tier accounts
	still cannot trade them.
]]

local Economy = require("./Economy")
local Materials = require("./Materials")
local Rarities = require("./Rarities")
local Schema = require("./Schema")

local Trading = {}

Trading.GOLD_TAX = 0.10
Trading.LOCK_SECONDS = 3
Trading.LOG_RETENTION_SECONDS = 180 * 86400
Trading.MYTHIC_BIND_SECONDS = 7 * 86400
Trading.NEW_ACCOUNT_DAYS = 14
Trading.STANDARD_LEVEL = 15
Trading.TRUSTED_LEVEL = 40
Trading.CLEAN_DAYS = 60
Trading.LOPSIDED_RATIO = 10
Trading.WARNING_SHARE = 0.95
Trading.GEM_GOLD = 100
Trading.MAX_ITEMS = 12
Trading.MAX_LINES = 8
Trading.MAX_GOLD = 1000000000
Trading.MAX_GEMS = 100000000
Trading.FUNNEL_PARTNERS = 5
Trading.REPEAT_COUNT = 3
Trading.REPEAT_WINDOW = 3600
Trading.SPIKE_DAYS = 3
Trading.SPIKE_MULTIPLE = 5
Trading.HANDOFF_VALUE = 10000
Trading.NEW_HUGE = 1500
Trading.GEM_TRADING_ENABLED = true
Trading.ROBUX_ITEM_TRADING_ENABLED = false

Trading.LOCK_MESSAGE = "The trade changed. Wait 3 seconds, then confirm."

Trading.CAPS = {
	New = 2000,
	NewTrade = 2000,
	StandardBase = 50000,
	StandardPerLevel = 5000,
	StandardMax = 150000,
	-- Receipt trust only. Same ceiling as StandardMax. Level 40 and 60
	-- clean days still use Trusted.
	Receipt = 150000,
	Trusted = 2000000,
}

Trading.NEW_MAX_RARITY = "Rare"

Trading.VALUE = {
	cosmetic = 800,
	rarity = {
		Common = 50,
		Uncommon = 150,
		Rare = 600,
		Epic = 2500,
		Legendary = 12000,
		Mythic = 60000,
		Secret = 200000,
	},
	material = {
		common = 8,
		rare = 40,
		boss = 200,
		scroll = 500,
	},
	chest = {
		Common = 40,
		Uncommon = 150,
		Rare = 600,
		Epic = 2500,
		Legendary = 12000,
		Mythic = 50000,
	},
}

Trading.TRADEABLE_KINDS = {
	Weapon = true,
	Armor = true,
	Accessory = true,
	Pet = true,
	Cosmetic = true,
	Shard = true,
	Material = true,
	Chest = true,
}

export type Offer = {
	gold: number,
	gems: number,
	items: { string },
	materials: { [string]: number },
	chests: { [string]: number },
}

export type Actor = {
	userId: number,
	name: string,
	level: number,
	accountAgeDays: number,
	cleanHistoryDays: number,
	verifiedSpender: boolean,
	patron: boolean,
	verifiedTrader: boolean,
	flagged: boolean,
	tradeLocked: boolean,
	recentHandoff: boolean,
	connected: { [number]: boolean }?,
}

export type Side = {
	userId: number,
	offer: Offer,
	confirmed: boolean,
	committed: boolean,
	acceptedWarning: boolean,
	seenRevision: number,
}

export type Session = {
	id: string,
	left: Side,
	right: Side,
	revision: number,
	changedAt: number,
	status: string,
	settling: boolean,
	auditId: string?,
}

export type AuditParty = {
	userId: number,
	name: string,
	level: number,
	accountAgeDays: number,
	tier: string,
}

export type AuditLine = {
	kind: string,
	id: string,
	uid: string,
	count: number,
	name: string,
	rarity: string,
	itemKind: string,
	fromUserId: number,
	toUserId: number,
	value: number,
	tax: number,
}

export type AuditEntry = {
	id: string,
	kind: string,
	timestamp: number,
	server: string,
	left: AuditParty,
	right: AuditParty,
	lines: { AuditLine },
	estimatedValue: { [number]: number },
	flags: { string },
	warning: string?,
	reversed: boolean,
	reports: { number },
	listingId: string?,
}

export type SpentRow = {
	day: number,
	amount: number,
}

export type Context = {
	spent: { [number]: SpentRow },
	log: { AuditEntry },
	server: string,
	paidTradingAllowed: boolean,
}

export type Result = {
	ok: boolean,
	error: string?,
	pending: boolean?,
	already: boolean?,
	auditId: string?,
	warning: string?,
	needsWarning: boolean?,
	flags: { string }?,
}

type Hold = {
	id: string,
	userId: number,
	items: { [string]: boolean },
	materials: { [string]: number },
	chests: { [string]: number },
}

local holds: { [string]: Hold } = {}
local tradeItems: { [string]: string } = {}
local busy: { [number]: boolean } = {}
local nextSerial = 0
local sharedLog: { AuditEntry } = {}
local sharedSpent: { [number]: SpentRow } = {}

local function whole(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.floor(value)
end

function Trading.reset()
	table.clear(holds)
	table.clear(tradeItems)
	table.clear(busy)
	nextSerial = 0
end

function Trading.shared(server: string, paid: boolean): Context
	return {
		spent = sharedSpent,
		log = sharedLog,
		server = server,
		paidTradingAllowed = paid,
	}
end

function Trading.auditLog(): { AuditEntry }
	return sharedLog
end

function Trading.restoreAudit(entries: { AuditEntry })
	table.clear(sharedLog)
	for _, entry in ipairs(entries) do
		table.insert(sharedLog, entry)
	end
end

function Trading.tryLock(userIds: { number }): boolean
	for _, userId in ipairs(userIds) do
		if busy[userId] == true then
			return false
		end
	end
	for _, userId in ipairs(userIds) do
		busy[userId] = true
	end
	return true
end

function Trading.unlock(userIds: { number })
	for _, userId in ipairs(userIds) do
		busy[userId] = nil
	end
end

function Trading.nextId(prefix: string, now: number): string
	nextSerial += 1
	return string.format("%s-%d-%d", prefix, whole(now, 0), nextSerial)
end

function Trading.emptyOffer(): Offer
	return {
		gold = 0,
		gems = 0,
		items = {},
		materials = {},
		chests = {},
	}
end

-- The grant path is what sets granted. A boolean true is only the old
-- idempotency mark, and a cosmetic or an id with no grant does not count.
function Trading.receiptCounts(entry: any): boolean
	if type(entry) ~= "table" then
		return false
	end
	if entry.verified ~= true or entry.granted ~= true then
		return false
	end
	return entry.cosmetic ~= true
end

function Trading.verifiedFromReceipts(data: any): boolean
	if type(data) ~= "table" or type(data.receipts) ~= "table" then
		return false
	end
	for _, entry in pairs(data.receipts) do
		if Trading.receiptCounts(entry) then
			return true
		end
	end
	return false
end

function Trading.tier(actor: Actor): string
	local level = whole(actor.level, 0)
	local age = whole(actor.accountAgeDays, 0)
	local clean = whole(actor.cleanHistoryDays, 0)
	local newAccount = age < Trading.NEW_ACCOUNT_DAYS
	local opted = actor.verifiedTrader == true and clean >= Trading.CLEAN_DAYS and not newAccount
	if actor.patron == true or opted then
		return "Patron"
	end
	if
		not newAccount
		and (
			level >= Trading.TRUSTED_LEVEL
			or clean >= Trading.CLEAN_DAYS
			or actor.verifiedSpender == true
		)
	then
		return "Trusted"
	end
	if not newAccount and level >= Trading.STANDARD_LEVEL then
		return "Standard"
	end
	return "New"
end

-- Patron is a name, not a limit. The number is the one level, clean days,
-- account age, and a verified receipt already earned. Vip does not raise
-- it. A patron who has not earned Level 40 or 60 clean days stays at or
-- under the verified-spender cap. Nobody, paid or not, passes the
-- non-paid Level-40 / 60-clean tier, and the result is never uncapped.
function Trading.dailyCap(actor: Actor): number
	local level = whole(actor.level, 0)
	local age = whole(actor.accountAgeDays, 0)
	local clean = whole(actor.cleanHistoryDays, 0)
	local newAccount = age < Trading.NEW_ACCOUNT_DAYS
	if not newAccount and (level >= Trading.TRUSTED_LEVEL or clean >= Trading.CLEAN_DAYS) then
		return Trading.CAPS.Trusted
	end
	if not newAccount and actor.verifiedSpender == true then
		return Trading.CAPS.Receipt
	end
	if not newAccount and level >= Trading.STANDARD_LEVEL then
		local extra = math.max(0, level - Trading.STANDARD_LEVEL) * Trading.CAPS.StandardPerLevel
		return math.min(Trading.CAPS.StandardMax, Trading.CAPS.StandardBase + extra)
	end
	return Trading.CAPS.New
end

function Trading.tradeCap(actor: Actor): number
	if Trading.tier(actor) == "New" then
		return Trading.CAPS.NewTrade
	end
	return Trading.dailyCap(actor)
end

function Trading.goldTax(gold: number): number
	if gold <= 0 then
		return 0
	end
	return math.floor(gold * Trading.GOLD_TAX)
end

function Trading.canTradeGems(actor: Actor, paidTradingAllowed: boolean): (boolean, string?)
	if Trading.GEM_TRADING_ENABLED ~= true then
		return false, "Gem trades are turned off."
	end
	if paidTradingAllowed ~= true then
		return false, "Gem trades are off in this region."
	end
	if Trading.tier(actor) == "New" then
		return false, "Gems unlock once your account is Standard."
	end
	return true, nil
end

local function rarityAllowed(actor: Actor, rarity: string): boolean
	if Trading.tier(actor) ~= "New" then
		return true
	end
	local cap = Rarities.INDEX[Trading.NEW_MAX_RARITY] or 0
	local rank = Rarities.INDEX[rarity] or cap + 1
	return rank <= cap
end

local function isRobuxItem(item: any): boolean
	if item.paid == true or item.robux == true then
		return true
	end
	local source = item.source
	return source == "robux" or source == "premium"
end

local function isStarter(item: any): boolean
	if item.starter == true or item.bound == true then
		return true
	end
	local templateId = item.templateId
	if type(templateId) == "string" and string.sub(templateId, 1, 8) == "starter_" then
		return true
	end
	return false
end

function Trading.itemHold(uid: string): string?
	for id, hold in pairs(holds) do
		if hold.items[uid] == true then
			return id
		end
	end
	return nil
end

-- Salvage, sell, and feed all refuse this. A market listing and an open
-- trade offer are the same kind of hold: the item is still in the bag.
function Trading.consumeBlock(uid: string): string?
	if type(uid) ~= "string" or uid == "" then
		return nil
	end
	if Trading.itemHold(uid) ~= nil then
		return "That item is listed on the Market Board."
	end
	if tradeItems[uid] ~= nil then
		return "That item is in a trade."
	end
	return nil
end

local function dropTradeOffer(sessionId: string, offer: Offer)
	for _, uid in ipairs(offer.items) do
		if tradeItems[uid] == sessionId then
			tradeItems[uid] = nil
		end
	end
end

local function keepTradeOffer(sessionId: string, offer: Offer)
	for _, uid in ipairs(offer.items) do
		if type(uid) == "string" and uid ~= "" then
			tradeItems[uid] = sessionId
		end
	end
end

function Trading.heldCount(userId: number, kind: string, id: string, exceptListing: string?): number
	local total = 0
	for holdId, hold in pairs(holds) do
		if hold.userId == userId and holdId ~= exceptListing then
			local bag = if kind == "chest" then hold.chests else hold.materials
			total += bag[id] or 0
		end
	end
	return total
end

function Trading.rejection(item: any, actor: Actor, now: number, exceptListing: string?): string?
	if type(item) ~= "table" then
		return "That item cannot be traded."
	end
	if item.exploit == true then
		return "That item cannot be traded."
	end
	if isRobuxItem(item) and Trading.ROBUX_ITEM_TRADING_ENABLED ~= true then
		return "Robux items stay bound."
	end
	if isStarter(item) then
		return "Starter gear is bound."
	end
	if item.locked == true then
		return "That item is locked."
	end
	local kind = item.kind
	if type(kind) ~= "string" or Trading.TRADEABLE_KINDS[kind] ~= true then
		return "That item cannot be traded."
	end
	local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
	if kind ~= "Cosmetic" and not rarityAllowed(actor, rarity) then
		return "That rarity is bound for a new account."
	end
	if rarity == "Mythic" then
		local obtained = item.obtainedAt
		if type(obtained) ~= "number" or now - obtained < Trading.MYTHIC_BIND_SECONDS then
			return "Mythic shards bind for 7 days."
		end
	end
	local uid = item.uid
	if type(uid) == "string" then
		local hold = Trading.itemHold(uid)
		if hold ~= nil and hold ~= exceptListing then
			return "That item is listed on the Market Board."
		end
	end
	return nil
end

function Trading.estimateItem(item: any): number
	if type(item) ~= "table" then
		return 0
	end
	if item.kind == "Cosmetic" then
		return Trading.VALUE.cosmetic
	end
	local rarity = if type(item.rarity) == "string" then item.rarity else ""
	local base = Trading.VALUE.rarity[rarity] or 0
	local upgrade = math.max(0, whole(item.upgrade, 0))
	local stars = math.max(0, whole(item.stars, 0))
	local mult = (1 + 0.15 * upgrade) * (1 + 0.1 * stars)
	return math.floor(base * mult + 0.5)
end

function Trading.estimateMaterial(id: string, count: number): number
	local definition = Materials.DEFS[id]
	if definition == nil then
		return 0
	end
	local each = Trading.VALUE.material[definition.grade] or 0
	return each * math.max(0, count)
end

function Trading.estimateChest(tier: string, count: number): number
	local each = Trading.VALUE.chest[tier] or 0
	return each * math.max(0, count)
end

function Trading.tooltip(item: any): string
	if type(item) ~= "table" then
		return "Unknown item"
	end
	local stats = {}
	if type(item.stats) == "table" then
		for _, stat in ipairs(item.stats) do
			if type(stat) == "table" then
				if type(stat.display) == "string" then
					table.insert(stats, stat.display)
				elseif type(stat.name) == "string" then
					table.insert(
						stats,
						string.format("%s %s", stat.name, tostring(stat.value or ""))
					)
				end
			end
		end
	end
	local extra = ""
	if #stats > 0 then
		extra = " " .. table.concat(stats, ", ")
	end
	return string.format(
		"%s (%s %s) sockets %d%s",
		tostring(item.name or "Item"),
		tostring(item.rarity or "?"),
		tostring(item.kind or "?"),
		whole(item.sockets, 0),
		extra
	)
end

function Trading.warningText(share: number): string
	return string.format(
		"You're giving ~%d%% of the value. Continue?",
		math.floor(share * 100 + 0.5)
	)
end

local function readMoney(value: any, maxAmount: number): (number?, string?)
	if value == nil then
		return 0, nil
	end
	local amount = tonumber(value)
	if amount == nil or amount ~= amount or amount < 0 or amount > maxAmount then
		return nil, "That amount is not allowed."
	end
	return math.floor(amount), nil
end

local function readUids(value: any): ({ string }?, string?)
	if value == nil then
		return {}, nil
	end
	if type(value) ~= "table" then
		return nil, "Those items are not a list."
	end
	local list = {}
	local seen: { [string]: boolean } = {}
	for _, uid in ipairs(value) do
		if
			type(uid) ~= "string"
			or #uid < 1
			or #uid > 64
			or string.match(uid, "^[%w%-]+$") == nil
		then
			return nil, "That item cannot be traded."
		end
		if seen[uid] then
			return nil, "That item is listed twice."
		end
		seen[uid] = true
		table.insert(list, uid)
		if #list > Trading.MAX_ITEMS then
			return nil, "Too many items in one trade."
		end
	end
	return list, nil
end

local function readCounts(
	value: any,
	allowed: (string) -> boolean,
	label: string
): ({ [string]: number }?, string?)
	if value == nil then
		return {}, nil
	end
	if type(value) ~= "table" then
		return nil, "Bad " .. label .. "."
	end
	local out: { [string]: number } = {}
	local count = 0
	for key, raw in pairs(value) do
		if type(key) ~= "string" or not allowed(key) then
			return nil, "Unknown " .. label .. "."
		end
		local amount = tonumber(raw)
		if amount == nil or amount ~= amount or amount < 1 then
			return nil, "Bad " .. label .. " count."
		end
		amount = math.floor(amount)
		if amount > 999 then
			return nil, "That stack is too large."
		end
		out[key] = amount
		count += 1
		if count > Trading.MAX_LINES then
			return nil, "Too many " .. label .. " lines."
		end
	end
	return out, nil
end

function Trading.normalize(raw: any): (Offer?, string?)
	if raw == nil then
		return Trading.emptyOffer(), nil
	end
	if type(raw) ~= "table" then
		return nil, "That offer is not valid."
	end
	local gold, goldErr = readMoney(raw.gold, Trading.MAX_GOLD)
	if gold == nil then
		return nil, goldErr
	end
	local gems, gemErr = readMoney(raw.gems, Trading.MAX_GEMS)
	if gems == nil then
		return nil, gemErr
	end
	local items, itemErr = readUids(raw.items)
	if items == nil then
		return nil, itemErr
	end
	local materials, matErr = readCounts(raw.materials, function(id)
		return Materials.DEFS[id] ~= nil
	end, "material")
	if materials == nil then
		return nil, matErr
	end
	local chests, chestErr = readCounts(raw.chests, function(tier)
		return Trading.VALUE.chest[tier] ~= nil
	end, "chest")
	if chests == nil then
		return nil, chestErr
	end
	return {
		gold = gold,
		gems = gems,
		items = items,
		materials = materials,
		chests = chests,
	},
		nil
end

function Trading.offerEmpty(offer: Offer): boolean
	if offer.gold > 0 or offer.gems > 0 or #offer.items > 0 then
		return false
	end
	for _, count in pairs(offer.materials) do
		if count > 0 then
			return false
		end
	end
	for _, count in pairs(offer.chests) do
		if count > 0 then
			return false
		end
	end
	return true
end

local function newSide(userId: number): Side
	return {
		userId = userId,
		offer = Trading.emptyOffer(),
		confirmed = false,
		committed = false,
		acceptedWarning = false,
		seenRevision = 0,
	}
end

function Trading.open(
	id: string,
	leftUserId: number,
	rightUserId: number,
	now: number
): (Session?, string?)
	if type(id) ~= "string" or id == "" then
		return nil, "Bad trade."
	end
	if type(leftUserId) ~= "number" or type(rightUserId) ~= "number" then
		return nil, "That player is not here."
	end
	if leftUserId == rightUserId then
		return nil, "You cannot trade with yourself."
	end
	return {
		id = id,
		left = newSide(leftUserId),
		right = newSide(rightUserId),
		revision = 0,
		changedAt = now,
		status = "open",
		settling = false,
		auditId = nil,
	},
		nil
end

function Trading.side(session: Session, userId: number): Side?
	if session.left.userId == userId then
		return session.left
	end
	if session.right.userId == userId then
		return session.right
	end
	return nil
end

local function clearReady(session: Session)
	session.left.confirmed = false
	session.right.confirmed = false
	session.left.committed = false
	session.right.committed = false
	session.left.acceptedWarning = false
	session.right.acceptedWarning = false
	session.left.seenRevision = 0
	session.right.seenRevision = 0
end

function Trading.reopen(session: Session)
	session.status = "open"
	session.auditId = nil
	session.settling = false
	clearReady(session)
end

function Trading.setOffer(
	session: Session,
	userId: number,
	raw: any,
	now: number
): (boolean, string?)
	if session.settling then
		return false, "That trade is already finishing."
	end
	if session.status ~= "open" then
		return false, "That trade is closed."
	end
	local side = Trading.side(session, userId)
	if side == nil then
		return false, "You are not in this trade."
	end
	local offer, err = Trading.normalize(raw)
	if offer == nil then
		return false, err
	end
	dropTradeOffer(session.id, side.offer)
	side.offer = offer
	keepTradeOffer(session.id, offer)
	session.revision += 1
	session.changedAt = now
	clearReady(session)
	return true, nil
end

function Trading.lockRemaining(session: Session, now: number): number
	local left = session.changedAt + Trading.LOCK_SECONDS - now
	if left < 0 then
		return 0
	end
	return left
end

function Trading.confirm(session: Session, userId: number, now: number): (boolean, string?)
	if session.settling then
		return false, "That trade is already finishing."
	end
	if session.status ~= "open" then
		return false, "That trade is closed."
	end
	local side = Trading.side(session, userId)
	if side == nil then
		return false, "You are not in this trade."
	end
	if Trading.lockRemaining(session, now) > 0 then
		return false, Trading.LOCK_MESSAGE
	end
	side.confirmed = true
	side.seenRevision = session.revision
	side.committed = false
	side.acceptedWarning = false
	return true, nil
end

function Trading.cancel(session: Session, userId: number): (boolean, string?)
	if session.settling then
		return false, "That trade is already finishing."
	end
	if session.status ~= "open" then
		return false, "That trade is closed."
	end
	if Trading.side(session, userId) == nil then
		return false, "You are not in this trade."
	end
	dropTradeOffer(session.id, session.left.offer)
	dropTradeOffer(session.id, session.right.offer)
	session.status = "cancelled"
	return true, nil
end

function Trading.prepare(data: any)
	if type(data.inventory) ~= "table" then
		data.inventory = {}
	end
	if type(data.pets) ~= "table" then
		data.pets = {}
	end
	if type(data.materials) ~= "table" then
		data.materials = {}
	end
	if type(data.chests) ~= "table" then
		data.chests = {}
	end
	if type(data.equipped) ~= "table" then
		data.equipped = {
			weapon = nil,
			pet = nil,
			armor = {},
			accessories = {},
		}
	end
	if type(data.equipped.armor) ~= "table" then
		data.equipped.armor = {}
	end
	if type(data.equipped.accessories) ~= "table" then
		data.equipped.accessories = {}
	end
	if type(data.gold) ~= "number" then
		data.gold = 0
	end
	if type(data.gems) ~= "number" then
		data.gems = 0
	end
	if type(data.ledger) ~= "table" then
		data.ledger = {}
	end
end

local function capture(data: any)
	Trading.prepare(data)
	return {
		gold = data.gold,
		gems = data.gems,
		inventory = Schema.deepCopy(data.inventory),
		pets = Schema.deepCopy(data.pets),
		materials = Schema.deepCopy(data.materials),
		chests = Schema.deepCopy(data.chests),
		equipped = Schema.deepCopy(data.equipped),
		ledger = Schema.deepCopy(data.ledger),
		tradeDay = data.tradeDay,
		tradeValueToday = data.tradeValueToday,
	}
end

local function restore(data: any, snap)
	data.gold = snap.gold
	data.gems = snap.gems
	data.inventory = snap.inventory
	data.pets = snap.pets
	data.materials = snap.materials
	data.chests = snap.chests
	data.equipped = snap.equipped
	data.ledger = snap.ledger
	data.tradeDay = snap.tradeDay
	data.tradeValueToday = snap.tradeValueToday
end

function Trading.takeMoney(data: any, currency: string, amount: number, reason: string): string?
	if amount <= 0 then
		return nil
	end
	if currency ~= "gold" and currency ~= "gems" then
		return "Unknown currency."
	end
	local have = data[currency] or 0
	if have < amount then
		if currency == "gold" then
			return "Not enough gold."
		end
		return "Not enough gems."
	end
	data[currency] = have - amount
	Economy.log(data, reason, currency, -amount, data[currency])
	return nil
end

function Trading.giveMoney(data: any, currency: string, amount: number, reason: string): string?
	if amount <= 0 then
		return nil
	end
	if currency ~= "gold" and currency ~= "gems" then
		return "Unknown currency."
	end
	data[currency] = (data[currency] or 0) + amount
	Economy.log(data, reason, currency, amount, data[currency])
	return nil
end

function Trading.takeItem(data: any, uid: string): (any?, string?)
	Trading.prepare(data)
	local item, bag = Schema.findItem(data, uid)
	if item == nil or bag == nil then
		return nil, "You do not have that item."
	end
	if Schema.isEquipped(data, uid) then
		return nil, "That item is equipped."
	end
	bag[uid] = nil
	Schema.clearEquip(data, uid)
	return item, nil
end

function Trading.giveItem(data: any, item: any): string?
	Trading.prepare(data)
	if Schema.findItem(data, item.uid) ~= nil then
		return "That item is already in the inventory."
	end
	if Schema.countItems(data) + 1 > Schema.inventoryCap(data) then
		return "Inventory is full."
	end
	Schema.insertItem(data, item)
	return nil
end

function Trading.materialHave(data: any, userId: number, id: string, exceptListing: string?): number
	Trading.prepare(data)
	local have = data.materials[id] or 0
	local held = Trading.heldCount(userId, "material", id, exceptListing)
	return have - held
end

function Trading.chestHave(data: any, userId: number, tier: string, exceptListing: string?): number
	Trading.prepare(data)
	local have = data.chests[tier] or 0
	local held = Trading.heldCount(userId, "chest", tier, exceptListing)
	return have - held
end

function Trading.takeMaterial(data: any, id: string, count: number): string?
	Trading.prepare(data)
	if Materials.DEFS[id] == nil then
		return "Unknown material."
	end
	local have = data.materials[id] or 0
	if have < count then
		return "You do not have that material."
	end
	data.materials[id] = have - count
	return nil
end

function Trading.giveMaterial(data: any, id: string, count: number): string?
	Trading.prepare(data)
	local definition = Materials.DEFS[id]
	if definition == nil then
		return "Unknown material."
	end
	local nextCount = (data.materials[id] or 0) + count
	if nextCount > definition.stack then
		return "That stack is full."
	end
	data.materials[id] = nextCount
	return nil
end

function Trading.takeChest(data: any, tier: string, count: number): string?
	Trading.prepare(data)
	if Trading.VALUE.chest[tier] == nil then
		return "Unknown chest."
	end
	local have = data.chests[tier] or 0
	if have < count then
		return "You do not have that chest."
	end
	data.chests[tier] = have - count
	return nil
end

function Trading.giveChest(data: any, tier: string, count: number): string?
	Trading.prepare(data)
	if Trading.VALUE.chest[tier] == nil then
		return "Unknown chest."
	end
	local nextCount = (data.chests[tier] or 0) + count
	if nextCount > 999 then
		return "That stack is full."
	end
	data.chests[tier] = nextCount
	return nil
end

local function accountBlock(actor: Actor): string?
	if actor.tradeLocked == true or actor.flagged == true then
		return "This account cannot trade."
	end
	return nil
end

function Trading.spentToday(data: any, userId: number, context: Context, now: number): number
	local day = math.floor(now / 86400)
	if
		type(data) == "table"
		and type(data.tradeDay) == "number"
		and type(data.tradeValueToday) == "number"
	then
		if data.tradeDay == day then
			return data.tradeValueToday
		end
		return 0
	end
	local row = context.spent[userId]
	if row ~= nil and row.day == day then
		return row.amount
	end
	return 0
end

local function rememberSpent(
	data: any,
	userId: number,
	context: Context,
	now: number,
	total: number
)
	local day = math.floor(now / 86400)
	context.spent[userId] = { day = day, amount = total }
	if type(data) ~= "table" then
		return
	end
	if data.tradeDay == nil and data.tradeValueToday == nil then
		return
	end
	data.tradeDay = day
	data.tradeValueToday = total
end

local function offerValue(data: any, offer: Offer): (number?, string?, { any }?)
	local total = offer.gold + offer.gems * Trading.GEM_GOLD
	local found = {}
	for _, uid in ipairs(offer.items) do
		local item = Schema.findItem(data, uid)
		if item == nil then
			return nil, "You do not have that item.", nil
		end
		total += Trading.estimateItem(item)
		table.insert(found, item)
	end
	for id, count in pairs(offer.materials) do
		total += Trading.estimateMaterial(id, count)
	end
	for tier, count in pairs(offer.chests) do
		total += Trading.estimateChest(tier, count)
	end
	return total, nil, found
end

local function checkOffer(
	data: any,
	actor: Actor,
	offer: Offer,
	now: number,
	context: Context,
	exceptListing: string?,
	chargeCap: boolean?
): (number?, string?)
	local blocked = accountBlock(actor)
	if blocked ~= nil then
		return nil, blocked
	end
	Trading.prepare(data)
	if offer.gems > 0 then
		local allowed, why = Trading.canTradeGems(actor, context.paidTradingAllowed)
		if not allowed then
			return nil, why
		end
	end
	local value, valueErr = offerValue(data, offer)
	if value == nil then
		return nil, valueErr
	end
	for _, uid in ipairs(offer.items) do
		local item = Schema.findItem(data, uid)
		local reason = Trading.rejection(item, actor, now, exceptListing)
		if reason ~= nil then
			return nil, reason
		end
		if Schema.isEquipped(data, uid) then
			return nil, "That item is equipped."
		end
	end
	for id, count in pairs(offer.materials) do
		local definition = Materials.DEFS[id]
		if definition == nil then
			return nil, "Unknown material."
		end
		if not rarityAllowed(actor, Materials.rarityName(id)) then
			return nil, "That rarity is bound for a new account."
		end
		if Trading.materialHave(data, actor.userId, id, exceptListing) < count then
			return nil, "You do not have that material."
		end
	end
	for tier, count in pairs(offer.chests) do
		if not rarityAllowed(actor, tier) then
			return nil, "That rarity is bound for a new account."
		end
		if Trading.chestHave(data, actor.userId, tier, exceptListing) < count then
			return nil, "You do not have that chest."
		end
	end
	if offer.gold > (data.gold or 0) then
		return nil, "Not enough gold."
	end
	if offer.gems > (data.gems or 0) then
		return nil, "Not enough gems."
	end
	if chargeCap ~= false then
		if value > Trading.tradeCap(actor) then
			return nil, "That trade is over today's limit."
		end
		local already = Trading.spentToday(data, actor.userId, context, now)
		if already + value > Trading.dailyCap(actor) then
			return nil, "That trade is over today's limit."
		end
	end
	return value, nil
end

local function shareWarning(value: number, other: number): string?
	local total = value + other
	if total <= 0 then
		return nil
	end
	local share = value / total
	if share >= Trading.WARNING_SHARE then
		return Trading.warningText(share)
	end
	return nil
end

local function connected(left: Actor, right: Actor): boolean
	if left.connected ~= nil and left.connected[right.userId] == true then
		return true
	end
	if right.connected ~= nil and right.connected[left.userId] == true then
		return true
	end
	return false
end

local function pairId(a: number, b: number): string
	if a < b then
		return tostring(a) .. ":" .. tostring(b)
	end
	return tostring(b) .. ":" .. tostring(a)
end

local function entryPair(entry: AuditEntry): string
	return pairId(entry.left.userId, entry.right.userId)
end

local function partnerOf(entry: AuditEntry, userId: number): AuditParty?
	if entry.left.userId == userId then
		return entry.right
	end
	if entry.right.userId == userId then
		return entry.left
	end
	return nil
end

local function dedupeFlags(flags: { string }): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, flag in ipairs(flags) do
		if seen[flag] ~= true then
			seen[flag] = true
			table.insert(out, flag)
		end
	end
	return out
end

local function median(values: { number }): number
	local copy = table.clone(values)
	table.sort(copy)
	return copy[math.ceil(#copy / 2)]
end

function Trading.collectFlags(
	entry: AuditEntry,
	history: { AuditEntry },
	leftActor: Actor,
	rightActor: Actor
): { string }
	local flags = {}
	local leftValue = entry.estimatedValue[leftActor.userId] or 0
	local rightValue = entry.estimatedValue[rightActor.userId] or 0
	local high = math.max(leftValue, rightValue)
	local low = math.min(leftValue, rightValue)
	if
		high > 0
		and (low == 0 or high >= low * Trading.LOPSIDED_RATIO)
		and not connected(leftActor, rightActor)
	then
		table.insert(flags, "lopsided")
	end

	local function noteReceiver(actor: Actor, received: number)
		if Trading.tier(actor) == "New" and received >= Trading.NEW_HUGE then
			table.insert(flags, "new_receiver")
		end
		if
			actor.recentHandoff == true
			and (received >= Trading.HANDOFF_VALUE or high >= Trading.HANDOFF_VALUE)
		then
			table.insert(flags, "handoff")
		end
	end
	noteReceiver(leftActor, rightValue)
	noteReceiver(rightActor, leftValue)

	local function funnel(actor: Actor, partner: Actor)
		if Trading.tier(partner) ~= "New" then
			return
		end
		local seen: { [number]: boolean } = {}
		seen[partner.userId] = true
		local day = entry.timestamp - 86400
		for _, prior in ipairs(history) do
			if prior.timestamp >= day then
				local other = partnerOf(prior, actor.userId)
				if other ~= nil and other.tier == "New" then
					seen[other.userId] = true
				end
			end
		end
		local count = 0
		for _ in pairs(seen) do
			count += 1
		end
		if count >= Trading.FUNNEL_PARTNERS then
			table.insert(flags, "funnel")
		end
	end
	funnel(leftActor, rightActor)
	funnel(rightActor, leftActor)

	local templates: { [string]: boolean } = {}
	for _, line in ipairs(entry.lines) do
		if line.kind == "item" and line.id ~= "" then
			templates[line.id] = true
		end
	end
	local repeats = 0
	local window = entry.timestamp - Trading.REPEAT_WINDOW
	local key = entryPair(entry)
	for _, prior in ipairs(history) do
		if prior.timestamp >= window and entryPair(prior) == key then
			for _, line in ipairs(prior.lines) do
				if line.kind == "item" and templates[line.id] == true then
					repeats += 1
					break
				end
			end
		end
	end
	if repeats + 1 >= Trading.REPEAT_COUNT and next(templates) ~= nil then
		table.insert(flags, "repeat")
	end

	local function spike(actor: Actor)
		local byDay: { [number]: number } = {}
		for _, prior in ipairs(history) do
			if partnerOf(prior, actor.userId) ~= nil then
				local day = math.floor(prior.timestamp / 86400)
				local gave = prior.estimatedValue[actor.userId] or 0
				byDay[day] = (byDay[day] or 0) + gave
			end
		end
		local today = math.floor(entry.timestamp / 86400)
		local priorDays = {}
		for day, amount in pairs(byDay) do
			if day ~= today then
				table.insert(priorDays, amount)
			end
		end
		if #priorDays < Trading.SPIKE_DAYS then
			return
		end
		local todayTotal = (byDay[today] or 0) + (entry.estimatedValue[actor.userId] or 0)
		if todayTotal > median(priorDays) * Trading.SPIKE_MULTIPLE then
			table.insert(flags, "spike")
		end
	end
	spike(leftActor)
	spike(rightActor)

	return flags
end

local function partyRecord(actor: Actor): AuditParty
	return {
		userId = actor.userId,
		name = actor.name,
		level = whole(actor.level, 1),
		accountAgeDays = whole(actor.accountAgeDays, 0),
		tier = Trading.tier(actor),
	}
end

local function pushLine(lines: { AuditLine }, line: AuditLine)
	table.insert(lines, line)
end

local function buildLines(
	left: any,
	right: any,
	leftActor: Actor,
	rightActor: Actor,
	leftOffer: Offer,
	rightOffer: Offer
): { AuditLine }
	local lines: { AuditLine } = {}
	local function goods(data: any, offer: Offer, fromId: number, toId: number)
		for _, uid in ipairs(offer.items) do
			local item = Schema.findItem(data, uid)
			local templateId = uid
			local name = "Item"
			local rarity = ""
			local itemKind = ""
			local value = 0
			if type(item) == "table" then
				if type(item.templateId) == "string" and item.templateId ~= "" then
					templateId = item.templateId
				end
				name = tostring(item.name or "Item")
				rarity = tostring(item.rarity or "")
				itemKind = tostring(item.kind or "")
				value = Trading.estimateItem(item)
			end
			pushLine(lines, {
				kind = "item",
				id = templateId,
				uid = uid,
				count = 1,
				name = name,
				rarity = rarity,
				itemKind = itemKind,
				fromUserId = fromId,
				toUserId = toId,
				value = value,
				tax = 0,
			})
		end
		for id, count in pairs(offer.materials) do
			pushLine(lines, {
				kind = "material",
				id = id,
				uid = "",
				count = count,
				name = Materials.displayName(id),
				rarity = Materials.rarityName(id),
				itemKind = "Material",
				fromUserId = fromId,
				toUserId = toId,
				value = Trading.estimateMaterial(id, count),
				tax = 0,
			})
		end
		for tier, count in pairs(offer.chests) do
			pushLine(lines, {
				kind = "chest",
				id = tier,
				uid = "",
				count = count,
				name = tier .. " Chest",
				rarity = tier,
				itemKind = "Chest",
				fromUserId = fromId,
				toUserId = toId,
				value = Trading.estimateChest(tier, count),
				tax = 0,
			})
		end
		if offer.gold > 0 then
			pushLine(lines, {
				kind = "gold",
				id = "gold",
				uid = "",
				count = offer.gold,
				name = "Gold",
				rarity = "",
				itemKind = "Currency",
				fromUserId = fromId,
				toUserId = toId,
				value = offer.gold,
				tax = Trading.goldTax(offer.gold),
			})
		end
		if offer.gems > 0 then
			pushLine(lines, {
				kind = "gems",
				id = "gems",
				uid = "",
				count = offer.gems,
				name = "Gems",
				rarity = "",
				itemKind = "Currency",
				fromUserId = fromId,
				toUserId = toId,
				value = offer.gems * Trading.GEM_GOLD,
				tax = 0,
			})
		end
	end
	goods(left, leftOffer, leftActor.userId, rightActor.userId)
	goods(right, rightOffer, rightActor.userId, leftActor.userId)
	return lines
end

local function roomFor(data: any, incoming: number, outgoing: number): string?
	Trading.prepare(data)
	local net = Schema.countItems(data) - outgoing + incoming
	if net > Schema.inventoryCap(data) then
		return "Inventory is full."
	end
	return nil
end

local function moveGoods(from: any, to: any, offer: Offer): string?
	for _, uid in ipairs(offer.items) do
		local item, err = Trading.takeItem(from, uid)
		if item == nil then
			return err
		end
		local giveErr = Trading.giveItem(to, item)
		if giveErr ~= nil then
			Trading.giveItem(from, item)
			return giveErr
		end
	end
	for id, count in pairs(offer.materials) do
		local takeErr = Trading.takeMaterial(from, id, count)
		if takeErr ~= nil then
			return takeErr
		end
		local giveErr = Trading.giveMaterial(to, id, count)
		if giveErr ~= nil then
			Trading.giveMaterial(from, id, count)
			return giveErr
		end
	end
	for tier, count in pairs(offer.chests) do
		local takeErr = Trading.takeChest(from, tier, count)
		if takeErr ~= nil then
			return takeErr
		end
		local giveErr = Trading.giveChest(to, tier, count)
		if giveErr ~= nil then
			Trading.giveChest(from, tier, count)
			return giveErr
		end
	end
	local goldErr = Trading.takeMoney(from, "gold", offer.gold, "trade")
	if goldErr ~= nil then
		return goldErr
	end
	local netGold = offer.gold - Trading.goldTax(offer.gold)
	local grantGold = Trading.giveMoney(to, "gold", netGold, "trade")
	if grantGold ~= nil then
		return grantGold
	end
	local gemErr = Trading.takeMoney(from, "gems", offer.gems, "trade")
	if gemErr ~= nil then
		return gemErr
	end
	return Trading.giveMoney(to, "gems", offer.gems, "trade")
end

function Trading.prune(log: { AuditEntry }, now: number)
	local cutoff = now - Trading.LOG_RETENTION_SECONDS
	local keep = {}
	for _, entry in ipairs(log) do
		if entry.timestamp >= cutoff then
			table.insert(keep, entry)
		end
	end
	table.clear(log)
	for _, entry in ipairs(keep) do
		table.insert(log, entry)
	end
end

function Trading.append(context: Context, entry: AuditEntry, now: number)
	table.insert(context.log, entry)
	Trading.prune(context.log, now)
end

function Trading.dropEntry(log: { AuditEntry }, tradeId: string)
	for index = #log, 1, -1 do
		if log[index].id == tradeId then
			table.remove(log, index)
			return
		end
	end
end

function Trading.findEntry(log: { AuditEntry }, tradeId: string): AuditEntry?
	for index = #log, 1, -1 do
		local entry = log[index]
		if entry.id == tradeId then
			return entry
		end
	end
	return nil
end

function Trading.search(log: { AuditEntry }, query: any): { AuditEntry }
	local found = {}
	if type(query) ~= "table" then
		return found
	end
	for index = #log, 1, -1 do
		local entry = log[index]
		local userOk = query.userId == nil
			or entry.left.userId == query.userId
			or entry.right.userId == query.userId
		local itemOk = true
		if query.templateId ~= nil or query.itemName ~= nil or query.text ~= nil then
			itemOk = false
			for _, line in ipairs(entry.lines) do
				if query.templateId ~= nil and line.id == query.templateId then
					itemOk = true
				end
				if query.itemName ~= nil and line.name == query.itemName then
					itemOk = true
				end
				if query.text ~= nil then
					local hay = string.lower(line.name .. " " .. line.id)
					if string.find(hay, string.lower(tostring(query.text)), 1, true) ~= nil then
						itemOk = true
					end
				end
			end
		end
		if userOk and itemOk then
			table.insert(found, entry)
		end
	end
	return found
end

function Trading.rollback(entry: AuditEntry, left: any, right: any): (boolean, string?)
	if entry.reversed == true then
		return false, "That trade was already reversed."
	end
	Trading.prepare(left)
	Trading.prepare(right)
	local snapLeft = capture(left)
	local snapRight = capture(right)
	-- left / right profiles are entry.left / entry.right.
	local function owner(userId: number): any
		if userId == entry.left.userId then
			return left
		end
		return right
	end
	local failed: string? = nil
	for _, line in ipairs(entry.lines) do
		local sender = owner(line.toUserId)
		local receiver = owner(line.fromUserId)
		if line.kind == "gold" then
			local net = line.count - line.tax
			failed = Trading.takeMoney(sender, "gold", net, "trade_rollback")
			if failed == nil then
				failed = Trading.giveMoney(receiver, "gold", line.count, "trade_rollback")
			end
		elseif line.kind == "gems" then
			failed = Trading.takeMoney(sender, "gems", line.count, "trade_rollback")
			if failed == nil then
				failed = Trading.giveMoney(receiver, "gems", line.count, "trade_rollback")
			end
		elseif line.kind == "material" then
			failed = Trading.takeMaterial(sender, line.id, line.count)
			if failed == nil then
				failed = Trading.giveMaterial(receiver, line.id, line.count)
			end
		elseif line.kind == "chest" then
			failed = Trading.takeChest(sender, line.id, line.count)
			if failed == nil then
				failed = Trading.giveChest(receiver, line.id, line.count)
			end
		end
		if failed ~= nil then
			break
		end
	end
	if failed == nil then
		for _, line in ipairs(entry.lines) do
			if line.kind == "item" then
				local sender = owner(line.toUserId)
				local receiver = owner(line.fromUserId)
				if line.uid == "" then
					failed = "That item is no longer in the bag."
					break
				end
				if Schema.isEquipped(sender, line.uid) then
					failed = "Unequip it before this can be reversed."
					break
				end
				local item, takeErr = Trading.takeItem(sender, line.uid)
				if item == nil then
					failed = takeErr or "That item is no longer in the bag."
					break
				end
				failed = Trading.giveItem(receiver, item)
				if failed ~= nil then
					break
				end
			end
		end
	end
	if failed ~= nil then
		restore(left, snapLeft)
		restore(right, snapRight)
		return false, failed
	end
	entry.reversed = true
	return true, nil
end

function Trading.report(log: { AuditEntry }, tradeId: string, userId: number): (boolean, string?)
	local entry = Trading.findEntry(log, tradeId)
	if entry == nil then
		return false, "No trade with that id."
	end
	if entry.left.userId ~= userId and entry.right.userId ~= userId then
		return false, "You were not in that trade."
	end
	for _, reporter in ipairs(entry.reports) do
		if reporter == userId then
			return true, nil
		end
	end
	table.insert(entry.reports, userId)
	table.insert(entry.flags, "report")
	return true, nil
end

function Trading.clientEntry(entry: AuditEntry): any
	local function party(record: AuditParty)
		return {
			userId = record.userId,
			name = record.name,
			level = record.level,
			tier = record.tier,
		}
	end
	local lines = {}
	for _, line in ipairs(entry.lines) do
		table.insert(lines, {
			kind = line.kind,
			id = line.id,
			count = line.count,
			name = line.name,
			rarity = line.rarity,
			fromUserId = line.fromUserId,
			toUserId = line.toUserId,
			value = line.value,
		})
	end
	return {
		id = entry.id,
		kind = entry.kind,
		timestamp = entry.timestamp,
		left = party(entry.left),
		right = party(entry.right),
		lines = lines,
		flags = table.clone(entry.flags),
		warning = entry.warning,
		reversed = entry.reversed,
		listingId = entry.listingId,
	}
end

local function reserveSpec(userId: number, listingId: string, offer: Offer): (boolean, string?)
	if holds[listingId] ~= nil then
		return false, "That listing already exists."
	end
	for _, uid in ipairs(offer.items) do
		if Trading.itemHold(uid) ~= nil then
			return false, "That item is listed on the Market Board."
		end
	end
	holds[listingId] = {
		id = listingId,
		userId = userId,
		items = {},
		materials = {},
		chests = {},
	}
	local hold = holds[listingId]
	for _, uid in ipairs(offer.items) do
		hold.items[uid] = true
	end
	for id, count in pairs(offer.materials) do
		hold.materials[id] = count
	end
	for tier, count in pairs(offer.chests) do
		hold.chests[tier] = count
	end
	return true, nil
end

function Trading.reserve(listingId: string, userId: number, offer: Offer): (boolean, string?)
	return reserveSpec(userId, listingId, offer)
end

function Trading.release(listingId: string)
	holds[listingId] = nil
end

function Trading.holdCountFor(userId: number): number
	local count = 0
	for _, hold in pairs(holds) do
		if hold.userId == userId then
			count += 1
		end
	end
	return count
end

function Trading.inspect(
	data: any,
	actor: Actor,
	offer: Offer,
	now: number,
	context: Context,
	exceptListing: string?,
	chargeCap: boolean?
): (number?, string?)
	return checkOffer(data, actor, offer, now, context, exceptListing, chargeCap)
end

function Trading.capture(data: any): any
	return capture(data)
end

function Trading.restore(data: any, snap: any)
	restore(data, snap)
end

function Trading.addSpent(data: any, userId: number, context: Context, now: number, value: number)
	local already = Trading.spentToday(data, userId, context, now)
	rememberSpent(data, userId, context, now, already + value)
end

export type Preview = {
	ok: boolean,
	error: string?,
	leftValue: number,
	rightValue: number,
	warning: string?,
	warningUserId: number?,
	lockRemaining: number,
}

function Trading.preview(
	session: Session,
	left: any,
	right: any,
	leftActor: Actor,
	rightActor: Actor,
	context: Context,
	now: number
): Preview
	local leftValue, leftErr = checkOffer(left, leftActor, session.left.offer, now, context, nil)
	if leftValue == nil then
		return {
			ok = false,
			error = leftErr,
			leftValue = 0,
			rightValue = 0,
			warning = nil,
			warningUserId = nil,
			lockRemaining = Trading.lockRemaining(session, now),
		}
	end
	local rightValue, rightErr =
		checkOffer(right, rightActor, session.right.offer, now, context, nil)
	if rightValue == nil then
		return {
			ok = false,
			error = rightErr,
			leftValue = leftValue,
			rightValue = 0,
			warning = nil,
			warningUserId = nil,
			lockRemaining = Trading.lockRemaining(session, now),
		}
	end
	if session.left.offer.gems > 0 or session.right.offer.gems > 0 then
		local leftGems, leftWhy = Trading.canTradeGems(leftActor, context.paidTradingAllowed)
		if not leftGems then
			return {
				ok = false,
				error = leftWhy,
				leftValue = leftValue,
				rightValue = rightValue,
				warning = nil,
				warningUserId = nil,
				lockRemaining = Trading.lockRemaining(session, now),
			}
		end
		local rightGems, rightWhy = Trading.canTradeGems(rightActor, context.paidTradingAllowed)
		if not rightGems then
			return {
				ok = false,
				error = rightWhy,
				leftValue = leftValue,
				rightValue = rightValue,
				warning = nil,
				warningUserId = nil,
				lockRemaining = Trading.lockRemaining(session, now),
			}
		end
	end
	local warning = shareWarning(leftValue, rightValue)
	local warningUserId = if warning ~= nil then leftActor.userId else nil
	if warning == nil then
		warning = shareWarning(rightValue, leftValue)
		warningUserId = if warning ~= nil then rightActor.userId else nil
	end
	return {
		ok = true,
		error = nil,
		leftValue = leftValue,
		rightValue = rightValue,
		warning = warning,
		warningUserId = warningUserId,
		lockRemaining = Trading.lockRemaining(session, now),
	}
end

local function applyOffers(left: any, right: any, leftOffer: Offer, rightOffer: Offer): string?
	local snapLeft = capture(left)
	local snapRight = capture(right)
	local ok, reason = xpcall(function()
		local leftRoom = roomFor(left, #rightOffer.items, #leftOffer.items)
		if leftRoom ~= nil then
			return leftRoom
		end
		local rightRoom = roomFor(right, #leftOffer.items, #rightOffer.items)
		if rightRoom ~= nil then
			return rightRoom
		end
		local moveErr = moveGoods(left, right, leftOffer)
		if moveErr == nil then
			moveErr = moveGoods(right, left, rightOffer)
		end
		return moveErr
	end, debug.traceback)
	if not ok or reason ~= nil then
		restore(left, snapLeft)
		restore(right, snapRight)
		if not ok then
			return "Could not finish that trade."
		end
	end
	return reason
end

function Trading.finish(
	session: Session,
	userId: number,
	left: any,
	right: any,
	leftActor: Actor,
	rightActor: Actor,
	context: Context,
	now: number,
	acceptWarning: boolean
): Result
	if session.status == "committed" then
		return {
			ok = true,
			already = true,
			auditId = session.auditId,
		}
	end
	if session.settling then
		return { ok = false, error = "That trade is already finishing." }
	end
	if session.status ~= "open" then
		return { ok = false, error = "That trade is closed." }
	end
	local side = Trading.side(session, userId)
	if side == nil then
		return { ok = false, error = "You are not in this trade." }
	end
	if not side.confirmed then
		return { ok = false, error = "Confirm the trade first." }
	end
	if side.seenRevision ~= session.revision then
		return { ok = false, error = "The trade changed. Confirm again." }
	end
	if Trading.lockRemaining(session, now) > 0 then
		return { ok = false, error = Trading.LOCK_MESSAGE }
	end

	local look = Trading.preview(session, left, right, leftActor, rightActor, context, now)
	if not look.ok then
		return { ok = false, error = look.error }
	end
	if Trading.offerEmpty(session.left.offer) and Trading.offerEmpty(session.right.offer) then
		return { ok = false, error = "Add something to the trade." }
	end
	if look.warning ~= nil and look.warningUserId == userId and acceptWarning ~= true then
		return {
			ok = false,
			error = look.warning,
			warning = look.warning,
			needsWarning = true,
		}
	end

	side.committed = true
	side.acceptedWarning = acceptWarning == true
	if not session.left.committed or not session.right.committed then
		return { ok = true, pending = true, warning = look.warning }
	end
	if look.warning ~= nil then
		local giver = if look.warningUserId == leftActor.userId then session.left else session.right
		if giver.acceptedWarning ~= true then
			side.committed = false
			return {
				ok = false,
				error = look.warning,
				warning = look.warning,
				needsWarning = true,
			}
		end
	end

	-- One pair of backups covers the whole commit. A failure in the move
	-- or the audit write puts both profiles back before anything is kept.
	local snapLeft = capture(left)
	local snapRight = capture(right)
	local lines =
		buildLines(left, right, leftActor, rightActor, session.left.offer, session.right.offer)
	session.settling = true
	local failed: string? = nil
	local entryId: string? = nil
	local entryFlags: { string }? = nil
	local callOk, callErr = xpcall(function()
		local reason = applyOffers(left, right, session.left.offer, session.right.offer)
		if reason ~= nil then
			failed = reason
			return
		end
		local entry: AuditEntry = {
			id = Trading.nextId("trade", now),
			kind = "trade",
			timestamp = now,
			server = context.server,
			left = partyRecord(leftActor),
			right = partyRecord(rightActor),
			lines = lines,
			estimatedValue = {
				[leftActor.userId] = look.leftValue,
				[rightActor.userId] = look.rightValue,
			},
			flags = {},
			warning = look.warning,
			reversed = false,
			reports = {},
			listingId = nil,
		}
		entry.flags = dedupeFlags(Trading.collectFlags(entry, context.log, leftActor, rightActor))
		entryId = entry.id
		entryFlags = entry.flags
		Trading.append(context, entry, now)
		rememberSpent(
			left,
			leftActor.userId,
			context,
			now,
			Trading.spentToday(left, leftActor.userId, context, now) + look.leftValue
		)
		rememberSpent(
			right,
			rightActor.userId,
			context,
			now,
			Trading.spentToday(right, rightActor.userId, context, now) + look.rightValue
		)
	end, debug.traceback)
	session.settling = false
	if not callOk or failed ~= nil then
		restore(left, snapLeft)
		restore(right, snapRight)
		if entryId ~= nil then
			Trading.dropEntry(context.log, entryId)
		end
		clearReady(session)
		if not callOk then
			warn("[Shardfall] trade commit failed:", callErr)
			return { ok = false, error = "Could not finish that trade." }
		end
		return { ok = false, error = failed }
	end
	session.status = "committed"
	session.auditId = entryId
	dropTradeOffer(session.id, session.left.offer)
	dropTradeOffer(session.id, session.right.offer)
	return {
		ok = true,
		auditId = entryId,
		warning = look.warning,
		flags = entryFlags,
	}
end

function Trading.recordMarket(
	context: Context,
	seller: Actor,
	buyer: Actor,
	lines: { AuditLine },
	sellerValue: number,
	buyerValue: number,
	now: number,
	listingId: string,
	warning: string?
): AuditEntry
	local entry: AuditEntry = {
		id = Trading.nextId("sale", now),
		kind = "market",
		timestamp = now,
		server = context.server,
		left = partyRecord(seller),
		right = partyRecord(buyer),
		lines = lines,
		estimatedValue = {
			[seller.userId] = sellerValue,
			[buyer.userId] = buyerValue,
		},
		flags = {},
		warning = warning,
		reversed = false,
		reports = {},
		listingId = listingId,
	}
	entry.flags = dedupeFlags(Trading.collectFlags(entry, context.log, seller, buyer))
	Trading.append(context, entry, now)
	return entry
end

return Trading
