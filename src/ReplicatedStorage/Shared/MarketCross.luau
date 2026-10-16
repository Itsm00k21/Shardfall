--!strict

--[[
	Cross-server Haven Market Board.

	Listings live in a DataStore. MemoryStore sorted maps, one per item
	category, carry a price-ordered index that expires with the listing.
	Creating a listing takes the goods off the seller's profile (escrow),
	so the same item cannot be sold twice.

	A buy claims the listing with UpdateAsync, then pays the buyer. The
	seller is credited in a mailbox, not their live profile. Joining, or a
	MessagingService ping, applies that mailbox and saves. Cancel and expiry
	return the goods through the same mailbox. The listing fee stays sunk.

	MARKET_XSERVER_ENABLED falls back to the in-memory board in MarketBoard.
]]

local MarketBoard = require("./MarketBoard")
local Schema = require("./Schema")
local Trading = require("./Trading")

local MarketCross = {}

MarketCross.MARKET_XSERVER_ENABLED = true
MarketCross.CATEGORIES = {
	"Weapon",
	"Armor",
	"Accessory",
	"Pet",
	"Material",
	"Chest",
	"Shard",
	"Cosmetic",
	"Other",
}

local ATTEMPTS = 4

local function fail(message: string)
	return { ok = false, error = message }
end

local function attempt(deps: any, callback: () -> any): (boolean, any)
	local lastErr = "Could not reach the market."
	for try = 1, ATTEMPTS do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastErr = tostring(result)
		if deps.sleep ~= nil then
			deps.sleep(try)
		end
	end
	return false, lastErr
end

local function blankBox()
	return {
		entries = {},
		openIds = {},
	}
end

local function copyBox(box: any)
	if type(box) ~= "table" then
		return blankBox()
	end
	local copy = Schema.deepCopy(box)
	if type(copy.entries) ~= "table" then
		copy.entries = {}
	end
	if type(copy.openIds) ~= "table" then
		copy.openIds = {}
	end
	return copy
end

local function openCount(box: any): number
	local count = 0
	if type(box) ~= "table" or type(box.openIds) ~= "table" then
		return 0
	end
	for _, id in ipairs(box.openIds) do
		if type(id) == "string" then
			count += 1
		end
	end
	return count
end

local function withoutId(ids: { any }, listingId: string): { string }
	local kept = {}
	for _, id in ipairs(ids) do
		if id ~= listingId then
			table.insert(kept, id)
		end
	end
	return kept
end

local function addOpenId(box: any, listingId: string)
	local nextBox = copyBox(box)
	for _, id in ipairs(nextBox.openIds) do
		if id == listingId then
			return nextBox
		end
	end
	table.insert(nextBox.openIds, listingId)
	return nextBox
end

local function addMail(box: any, entry: any)
	local nextBox = copyBox(box)
	for _, row in ipairs(nextBox.entries) do
		if row.id == entry.id then
			return nextBox
		end
	end
	table.insert(nextBox.entries, entry)
	nextBox.openIds = withoutId(nextBox.openIds, entry.listingId)
	return nextBox
end

local function dropMail(box: any, ids: { string })
	local nextBox = copyBox(box)
	local kept = {}
	for _, row in ipairs(nextBox.entries) do
		local drop = false
		for _, id in ipairs(ids) do
			if row.id == id then
				drop = true
			end
		end
		if not drop then
			table.insert(kept, row)
		end
	end
	nextBox.entries = kept
	return nextBox
end

local function readBox(deps: any, userId: number): (boolean, any)
	local key = tostring(userId)
	return attempt(deps, function()
		return deps.mailbox:getAsync(key)
	end)
end

local function writeBox(deps: any, userId: number, transform: (any) -> any): (boolean, any)
	local key = tostring(userId)
	return attempt(deps, function()
		return deps.mailbox:updateAsync(key, function(current)
			return transform(current)
		end)
	end)
end

local function readListing(deps: any, listingId: string): (boolean, any)
	return attempt(deps, function()
		return deps.listings:getAsync(listingId)
	end)
end

local function writeListing(deps: any, listingId: string, transform: (any) -> any): (boolean, any)
	return attempt(deps, function()
		return deps.listings:updateAsync(listingId, transform)
	end)
end

local function categoryOf(offer: Trading.Offer, details: { any }): string
	local materialLines = 0
	for _ in pairs(offer.materials) do
		materialLines += 1
	end
	local chestLines = 0
	for _ in pairs(offer.chests) do
		chestLines += 1
	end
	if materialLines > 0 and #offer.items == 0 and chestLines == 0 then
		return "Material"
	end
	if chestLines > 0 and #offer.items == 0 and materialLines == 0 then
		return "Chest"
	end
	local kind = ""
	if type(details[1]) == "table" and type(details[1].kind) == "string" then
		kind = details[1].kind
	end
	for _, name in ipairs(MarketCross.CATEGORIES) do
		if name == kind then
			return name
		end
	end
	return "Other"
end

local function sortPrice(record: any): number
	local price = record.price
	if record.currency == "gems" then
		price = record.price * Trading.GEM_GOLD
	end
	if price > 9999999999 then
		return 9999999999
	end
	if price < 0 then
		return 0
	end
	return price
end

local function indexKey(record: any): string
	return string.format("%s:%010d#%s", record.currency, sortPrice(record), record.id)
end

local function ttlFor(record: any, now: number): number
	local seconds = record.expiresAt - now
	if seconds < 1 then
		return 1
	end
	if seconds > 3888000 then
		return 3888000
	end
	return seconds
end

local function indexValue(record: any): any
	local shown = MarketBoard.view(record, nil)
	return {
		id = record.id,
		price = record.price,
		currency = record.currency,
		sellerUserId = record.sellerUserId,
		sellerName = record.sellerName,
		name = shown.name,
		category = record.category,
	}
end

local function putIndex(deps: any, record: any, now: number): boolean
	local key = indexKey(record)
	local value = indexValue(record)
	local ttl = ttlFor(record, now)
	local ok = attempt(deps, function()
		deps.maps:map(record.category):set(key, value, ttl)
		return true
	end)
	return ok
end

local function dropIndex(deps: any, record: any)
	local key = indexKey(record)
	attempt(deps, function()
		deps.maps:map(record.category):remove(key)
		return true
	end)
end

local function pullGoods(seller: any, offer: Trading.Offer): (any?, string?)
	local goods = {
		items = {},
		materials = {},
		chests = {},
	}
	for _, uid in ipairs(offer.items) do
		local item, err = Trading.takeItem(seller, uid)
		if item == nil then
			return nil, err or "You do not have that item."
		end
		table.insert(goods.items, item)
	end
	for id, count in pairs(offer.materials) do
		local err = Trading.takeMaterial(seller, id, count)
		if err ~= nil then
			return nil, err
		end
		goods.materials[id] = count
	end
	for tier, count in pairs(offer.chests) do
		local err = Trading.takeChest(seller, tier, count)
		if err ~= nil then
			return nil, err
		end
		goods.chests[tier] = count
	end
	return goods, nil
end

local function pushGoods(profile: any, goods: any): string?
	if type(goods) ~= "table" then
		return "That listing is empty."
	end
	for _, item in ipairs(goods.items or {}) do
		local err = Trading.giveItem(profile, Schema.deepCopy(item))
		if err ~= nil then
			return err
		end
	end
	for id, count in pairs(goods.materials or {}) do
		local err = Trading.giveMaterial(profile, id, count)
		if err ~= nil then
			return err
		end
	end
	for tier, count in pairs(goods.chests or {}) do
		local err = Trading.giveChest(profile, tier, count)
		if err ~= nil then
			return err
		end
	end
	return nil
end

local function seen(profile: any, id: string): boolean
	if type(profile.marketClaims) ~= "table" then
		return false
	end
	for _, claim in ipairs(profile.marketClaims) do
		if claim == id then
			return true
		end
	end
	return false
end

local function remember(profile: any, id: string)
	if seen(profile, id) then
		return
	end
	if type(profile.marketClaims) ~= "table" then
		profile.marketClaims = {}
	end
	table.insert(profile.marketClaims, id)
	while #profile.marketClaims > 200 do
		table.remove(profile.marketClaims, 1)
	end
end

local function capFor(actor: Trading.Actor): number
	local tier = Trading.tier(actor)
	return MarketBoard.LISTING_CAP[tier] or MarketBoard.LISTING_CAP.New
end

local function storeActor(actor: Trading.Actor): Trading.Actor
	return {
		userId = actor.userId,
		name = actor.name,
		level = actor.level,
		accountAgeDays = actor.accountAgeDays,
		cleanHistoryDays = actor.cleanHistoryDays,
		verifiedSpender = actor.verifiedSpender == true,
		patron = actor.patron == true,
		verifiedTrader = actor.verifiedTrader == true,
		flagged = actor.flagged == true,
		tradeLocked = actor.tradeLocked == true,
		recentHandoff = actor.recentHandoff == true,
		connected = nil,
	}
end

local function auditLines(record: any, fromId: number, toId: number): { Trading.AuditLine }
	local lines: { Trading.AuditLine } = {}
	local goods = record.goods or {}
	for _, item in ipairs(goods.items or {}) do
		table.insert(lines, {
			kind = "item",
			id = tostring(item.templateId or item.uid or ""),
			uid = tostring(item.uid or ""),
			count = 1,
			name = tostring(item.name or "Item"),
			rarity = tostring(item.rarity or ""),
			itemKind = tostring(item.kind or ""),
			fromUserId = fromId,
			toUserId = toId,
			value = Trading.estimateItem(item),
			tax = 0,
		})
	end
	for id, count in pairs(goods.materials or {}) do
		table.insert(lines, {
			kind = "material",
			id = id,
			uid = "",
			count = count,
			name = id,
			rarity = "",
			itemKind = "Material",
			fromUserId = fromId,
			toUserId = toId,
			value = Trading.estimateMaterial(id, count),
			tax = 0,
		})
	end
	for tier, count in pairs(goods.chests or {}) do
		table.insert(lines, {
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
	return lines
end

local function priceValue(record: any): number
	if record.currency == "gems" then
		return record.price * Trading.GEM_GOLD
	end
	return record.price
end

function MarketCross.memory(): any
	local function documents()
		local docs: { [string]: any } = {}
		local store = { throws = 0 }
		function store:getAsync(key: string)
			return Schema.deepCopy(docs[key])
		end
		function store:updateAsync(key: string, transform: (any) -> any)
			if self.throws > 0 then
				self.throws -= 1
				error("Request was throttled")
			end
			local current = Schema.deepCopy(docs[key])
			local updated = transform(current)
			if updated == nil then
				return Schema.deepCopy(docs[key])
			end
			docs[key] = updated
			return Schema.deepCopy(updated)
		end
		return store
	end

	local mapRows: { [string]: { [string]: any } } = {}
	local maps = { throws = 0 }
	function maps:map(category: string)
		local rows = mapRows[category]
		if rows == nil then
			rows = {}
			mapRows[category] = rows
		end
		local sorted = {}
		function sorted.set(_sorted, key: string, value: any, ttl: number)
			if maps.throws > 0 then
				maps.throws -= 1
				error("MemoryStore budget exceeded")
			end
			rows[key] = {
				value = Schema.deepCopy(value),
				ttl = ttl,
			}
		end
		function sorted.remove(_sorted, key: string)
			if maps.throws > 0 then
				maps.throws -= 1
				error("MemoryStore budget exceeded")
			end
			rows[key] = nil
		end
		function sorted.getRange(_sorted, direction: string, count: number)
			if maps.throws > 0 then
				maps.throws -= 1
				error("MemoryStore budget exceeded")
			end
			local page = {}
			for key, row in pairs(rows) do
				table.insert(page, {
					key = key,
					value = Schema.deepCopy(row.value),
				})
			end
			table.sort(page, function(a, b)
				if direction == "Desc" then
					return a.key > b.key
				end
				return a.key < b.key
			end)
			local limited = {}
			for index = 1, math.min(count, #page) do
				table.insert(limited, page[index])
			end
			return limited
		end
		return sorted
	end

	local bus = {
		published = {},
	}
	function bus:publish(userId: number, kind: string)
		table.insert(self.published, {
			userId = userId,
			kind = kind,
		})
		return true
	end

	return {
		listings = documents(),
		mailbox = documents(),
		maps = maps,
		bus = bus,
	}
end

function MarketCross.list(
	deps: any,
	seller: any,
	actor: Trading.Actor,
	raw: any,
	context: Trading.Context,
	now: number
)
	if MarketCross.MARKET_XSERVER_ENABLED ~= true then
		return fail("Cross-server market is off.")
	end
	if type(raw) ~= "table" then
		return fail("Set a price.")
	end
	local parsedPrice = tonumber(raw.price)
	local currency = raw.currency
	if parsedPrice == nil or (currency ~= "gold" and currency ~= "gems") then
		return fail("Set a price.")
	end
	local price = math.floor(parsedPrice)
	if price < MarketBoard.MIN_PRICE or price > MarketBoard.MAX_PRICE then
		return fail("Set a price.")
	end
	local offer, offerErr = Trading.normalize({
		gold = 0,
		gems = 0,
		items = raw.items,
		materials = raw.materials,
		chests = raw.chests,
	})
	if offer == nil then
		return fail(offerErr or "That offer is not valid.")
	end
	if Trading.offerEmpty(offer) then
		return fail("Add something to the listing.")
	end
	if currency == "gems" then
		local allowed, why = Trading.canTradeGems(actor, context.paidTradingAllowed)
		if not allowed then
			return fail(why or "Gem trades are turned off.")
		end
	end
	local blocked = if actor.tradeLocked == true or actor.flagged == true
		then "This account cannot trade."
		else nil
	if blocked ~= nil then
		return fail(blocked)
	end
	local boxOk, box = readBox(deps, actor.userId)
	if not boxOk then
		return fail("Could not reach the market.")
	end
	if openCount(box) >= capFor(actor) then
		return fail("Too many listings.")
	end
	local value, why = Trading.inspect(seller, actor, offer, now, context, nil)
	if value == nil then
		return fail(why or "That item cannot be traded.")
	end
	local fee = MarketBoard.fee(price, currency)
	Trading.prepare(seller)
	if (seller.gold or 0) < fee then
		return fail("Not enough gold for the listing fee.")
	end
	local snap = Trading.capture(seller)
	local feeErr = Trading.takeMoney(seller, "gold", fee, "market_fee")
	if feeErr ~= nil then
		Trading.restore(seller, snap)
		return fail(feeErr)
	end
	local goods, goodsErr = pullGoods(seller, offer)
	if goods == nil then
		Trading.restore(seller, snap)
		return fail(goodsErr or "You do not have that item.")
	end
	local details = {}
	for _, item in ipairs(goods.items) do
		table.insert(details, {
			uid = item.uid,
			name = tostring(item.name or "Item"),
			rarity = tostring(item.rarity or ""),
			kind = tostring(item.kind or ""),
			templateId = tostring(item.templateId or ""),
			tooltip = Trading.tooltip(item),
		})
	end
	local listingId = Trading.nextId("list", now)
	local record = {
		id = listingId,
		sellerUserId = actor.userId,
		sellerName = actor.name,
		seller = storeActor(actor),
		price = price,
		currency = currency,
		fee = fee,
		offer = offer,
		details = details,
		goods = goods,
		createdAt = now,
		expiresAt = now + MarketBoard.LISTING_SECONDS,
		status = "open",
		buyerUserId = nil,
		version = 1,
		category = categoryOf(offer, details),
		goodsDelivered = false,
	}
	local wrote, saved = writeListing(deps, listingId, function(current)
		if current ~= nil then
			return current
		end
		return record
	end)
	if not wrote or type(saved) ~= "table" or saved.status ~= "open" then
		Trading.restore(seller, snap)
		return fail("Could not list that.")
	end
	Trading.addSpent(seller, actor.userId, context, now, value)
	putIndex(deps, saved, now)
	writeBox(deps, actor.userId, function(current)
		return addOpenId(current, listingId)
	end)
	local lines = auditLines(saved, actor.userId, 0)
	table.insert(lines, {
		kind = "gold",
		id = "gold",
		uid = "",
		count = fee,
		name = "Listing fee",
		rarity = "",
		itemKind = "Currency",
		fromUserId = actor.userId,
		toUserId = 0,
		value = fee,
		tax = fee,
	})
	local entry =
		Trading.auditMarket(context, "list", actor, nil, lines, value, fee, now, listingId)
	return {
		ok = true,
		listing = MarketBoard.view(saved, nil),
		auditId = entry.id,
		record = saved,
	}
end

local function queueReturn(
	deps: any,
	record: any,
	now: number,
	action: string,
	context: Trading.Context?
)
	local entry = {
		id = "return:" .. record.id,
		listingId = record.id,
		kind = "return",
		currency = nil,
		amount = 0,
		goods = record.goods,
		createdAt = now,
	}
	local wrote = writeBox(deps, record.sellerUserId, function(current)
		return addMail(current, entry)
	end)
	dropIndex(deps, record)
	if context ~= nil and type(record.seller) == "table" then
		Trading.auditMarket(
			context,
			action,
			record.seller,
			nil,
			auditLines(record, 0, record.sellerUserId),
			0,
			0,
			now,
			record.id
		)
	end
	pcall(function()
		deps.bus:publish(record.sellerUserId, action)
	end)
	return wrote
end

local function closeListing(
	deps: any,
	listingId: string,
	now: number,
	nextStatus: string,
	sellerUserId: number?
): (boolean, any, string?)
	local wrote, saved = writeListing(deps, listingId, function(current)
		if type(current) ~= "table" then
			return current
		end
		if current.status ~= "open" then
			return current
		end
		if sellerUserId ~= nil and current.sellerUserId ~= sellerUserId then
			return current
		end
		if nextStatus == "expired" and current.expiresAt > now then
			return current
		end
		local nextRecord = Schema.deepCopy(current)
		nextRecord.status = nextStatus
		nextRecord.version = (current.version or 1) + 1
		return nextRecord
	end)
	if not wrote or type(saved) ~= "table" then
		return false, nil, "Could not reach the market."
	end
	return true, saved, nil
end

function MarketCross.cancel(
	deps: any,
	actor: Trading.Actor,
	listingId: string,
	context: Trading.Context,
	now: number
)
	if MarketCross.MARKET_XSERVER_ENABLED ~= true then
		return fail("Cross-server market is off.")
	end
	local beforeOk, before = readListing(deps, listingId)
	local closed, record, err = closeListing(deps, listingId, now, "cancelled", actor.userId)
	if not closed or record == nil then
		return fail(err or "That listing is gone.")
	end
	local logContext: any = nil
	if
		beforeOk
		and type(before) == "table"
		and before.status == "open"
		and record.status == "cancelled"
	then
		logContext = context
	end
	if record.sellerUserId ~= actor.userId then
		return fail("That listing is not yours.")
	end
	if record.status ~= "cancelled" and record.status ~= "expired" then
		return fail("That listing is gone.")
	end
	local queued = queueReturn(deps, record, now, "cancel", logContext)
	return {
		ok = true,
		listing = MarketBoard.view(record, nil),
		returnPending = queued ~= true,
	}
end

function MarketCross.expire(deps: any, listingId: string, context: Trading.Context, now: number)
	local foundOk, found = readListing(deps, listingId)
	if not foundOk or type(found) ~= "table" then
		return fail("That listing is gone.")
	end
	if found.status == "open" and found.expiresAt > now then
		return fail("That listing is still up.")
	end
	local wasOpen = found.status == "open"
	if found.status == "open" then
		local closed, record, err = closeListing(deps, listingId, now, "expired", nil)
		if not closed or record == nil then
			return fail(err or "Could not reach the market.")
		end
		found = record
	end
	if found.status == "expired" or found.status == "cancelled" then
		local logContext = if wasOpen then context else nil
		local queued = queueReturn(deps, found, now, "expire", logContext)
		return {
			ok = true,
			listing = MarketBoard.view(found, nil),
			returnPending = queued ~= true,
		}
	end
	return fail("That listing is gone.")
end

local function grant(
	buyer: any,
	buyerActor: Trading.Actor,
	record: any,
	context: Trading.Context,
	now: number
): (boolean, string?)
	local claimId = "goods:" .. record.id
	if seen(buyer, claimId) then
		return true, nil
	end
	local paying = record.price
	local have = if record.currency == "gems" then buyer.gems or 0 else buyer.gold or 0
	if have < paying then
		if record.currency == "gems" then
			return false, "Not enough gems."
		end
		return false, "Not enough gold."
	end
	local incoming = #(record.goods.items or {})
	if Schema.countItems(buyer) + incoming > Schema.inventoryCap(buyer) then
		return false, "Inventory is full."
	end
	local snap = Trading.capture(buyer)
	local payErr = Trading.takeMoney(buyer, record.currency, paying, "market_buy")
	if payErr ~= nil then
		Trading.restore(buyer, snap)
		return false, payErr
	end
	local giveErr = pushGoods(buyer, record.goods)
	if giveErr ~= nil then
		Trading.restore(buyer, snap)
		return false, giveErr
	end
	remember(buyer, claimId)
	Trading.addSpent(buyer, buyerActor.userId, context, now, priceValue(record))
	return true, nil
end

function MarketCross.reserveBuy(
	deps: any,
	listingId: string,
	buyer: any,
	buyerActor: Trading.Actor,
	context: Trading.Context,
	now: number
)
	if MarketCross.MARKET_XSERVER_ENABLED ~= true then
		return fail("Cross-server market is off.")
	end
	if buyerActor.tradeLocked == true or buyerActor.flagged == true then
		return fail("This account cannot trade.")
	end
	local foundOk, found = readListing(deps, listingId)
	if not foundOk or type(found) ~= "table" then
		return fail("That listing is gone.")
	end
	if found.sellerUserId == buyerActor.userId then
		return fail("You cannot buy your own listing.")
	end
	if found.status == "sold" and found.buyerUserId ~= buyerActor.userId then
		return fail("That listing is gone.")
	end
	if
		found.status ~= "open"
		and not (found.status == "sold" and found.buyerUserId == buyerActor.userId)
	then
		return fail("That listing is gone.")
	end
	if found.expiresAt <= now and found.status == "open" then
		MarketCross.expire(deps, listingId, context, now)
		return fail("That listing is gone.")
	end
	local seller = found.seller
	if type(seller) ~= "table" then
		return fail("That listing is gone.")
	end
	if found.currency == "gems" then
		local buyerGems, buyerWhy = Trading.canTradeGems(buyerActor, context.paidTradingAllowed)
		if not buyerGems then
			return fail(buyerWhy or "Gem trades are turned off.")
		end
		local sellerGems, sellerWhy = Trading.canTradeGems(seller, context.paidTradingAllowed)
		if not sellerGems then
			return fail(sellerWhy or "Gem trades are turned off.")
		end
	end
	local cost = priceValue(found)
	if cost > Trading.tradeCap(buyerActor) then
		return fail("That trade is over today's limit.")
	end
	local already = Trading.spentToday(buyer, buyerActor.userId, context, now)
	if already + cost > Trading.dailyCap(buyerActor) then
		return fail("That trade is over today's limit.")
	end
	local wrote, claimed = writeListing(deps, listingId, function(current)
		if type(current) ~= "table" then
			return current
		end
		if current.status == "sold" and current.buyerUserId == buyerActor.userId then
			return current
		end
		if current.status ~= "open" or current.expiresAt <= now then
			return current
		end
		local nextRecord = Schema.deepCopy(current)
		nextRecord.status = "sold"
		nextRecord.buyerUserId = buyerActor.userId
		nextRecord.version = (current.version or 1) + 1
		nextRecord.payout = {
			currency = current.currency,
			amount = current.price,
			delivered = false,
		}
		nextRecord.goodsDelivered = false
		return nextRecord
	end)
	if not wrote or type(claimed) ~= "table" or claimed.buyerUserId ~= buyerActor.userId then
		return fail("That listing is gone.")
	end
	local granted, grantErr = grant(buyer, buyerActor, claimed, context, now)
	if not granted then
		return {
			ok = false,
			error = grantErr or "Could not buy that.",
			claimed = true,
			record = claimed,
		}
	end
	return {
		ok = true,
		record = claimed,
		listing = MarketBoard.view(claimed, nil),
	}
end

function MarketCross.releaseClaim(
	deps: any,
	listingId: string,
	buyerUserId: number,
	now: number
): boolean
	local wrote, saved = writeListing(deps, listingId, function(current)
		if type(current) ~= "table" then
			return current
		end
		if current.goodsDelivered == true then
			return current
		end
		if current.status ~= "sold" or current.buyerUserId ~= buyerUserId then
			return current
		end
		local nextRecord = Schema.deepCopy(current)
		nextRecord.status = "open"
		nextRecord.buyerUserId = nil
		nextRecord.payout = nil
		nextRecord.version = (current.version or 1) + 1
		return nextRecord
	end)
	if wrote and type(saved) == "table" and saved.status == "open" then
		putIndex(deps, saved, now)
		return true
	end
	return false
end

function MarketCross.commitSale(
	deps: any,
	record: any,
	buyerActor: Trading.Actor,
	context: Trading.Context,
	now: number
)
	local wrote, saved = writeListing(deps, record.id, function(current)
		if type(current) ~= "table" then
			return current
		end
		if current.buyerUserId ~= buyerActor.userId then
			return current
		end
		local nextRecord = Schema.deepCopy(current)
		nextRecord.goodsDelivered = true
		return nextRecord
	end)
	local finalRecord = if wrote and type(saved) == "table" then saved else record
	local payout = {
		id = "sale:" .. finalRecord.id,
		listingId = finalRecord.id,
		kind = "sale",
		currency = finalRecord.currency,
		amount = finalRecord.price,
		goods = nil,
		createdAt = now,
	}
	local mailed = writeBox(deps, finalRecord.sellerUserId, function(current)
		return addMail(current, payout)
	end)
	dropIndex(deps, finalRecord)
	local seller = finalRecord.seller
	local lines = auditLines(finalRecord, finalRecord.sellerUserId, buyerActor.userId)
	table.insert(lines, {
		kind = finalRecord.currency,
		id = finalRecord.currency,
		uid = "",
		count = finalRecord.price,
		name = if finalRecord.currency == "gems" then "Gems" else "Gold",
		rarity = "",
		itemKind = "Currency",
		fromUserId = buyerActor.userId,
		toUserId = finalRecord.sellerUserId,
		value = priceValue(finalRecord),
		tax = 0,
	})
	local entry = nil
	if type(seller) == "table" then
		entry = Trading.auditMarket(
			context,
			"buy",
			seller,
			buyerActor,
			lines,
			priceValue(finalRecord),
			priceValue(finalRecord),
			now,
			finalRecord.id
		)
	end
	pcall(function()
		deps.bus:publish(finalRecord.sellerUserId, "sale")
	end)
	return {
		ok = true,
		auditId = if entry ~= nil then entry.id else nil,
		flags = if entry ~= nil then entry.flags else nil,
		listing = MarketBoard.view(finalRecord, nil),
		payoutPending = mailed ~= true,
		record = finalRecord,
	}
end

function MarketCross.flushPayout(deps: any, record: any, now: number): boolean
	local payout = {
		id = "sale:" .. record.id,
		listingId = record.id,
		kind = "sale",
		currency = record.currency,
		amount = record.price,
		goods = nil,
		createdAt = now,
	}
	local wrote = writeBox(deps, record.sellerUserId, function(current)
		return addMail(current, payout)
	end)
	return wrote == true
end

function MarketCross.buy(
	deps: any,
	listingId: string,
	buyer: any,
	buyerActor: Trading.Actor,
	context: Trading.Context,
	now: number
)
	local reserved = MarketCross.reserveBuy(deps, listingId, buyer, buyerActor, context, now)
	if reserved.ok ~= true then
		return reserved
	end
	return MarketCross.commitSale(deps, reserved.record, buyerActor, context, now)
end

local function applyEntry(profile: any, entry: any): string?
	if entry.kind == "sale" then
		return Trading.giveMoney(profile, entry.currency, entry.amount, "market_sale")
	end
	if entry.kind == "return" then
		return pushGoods(profile, entry.goods)
	end
	return nil
end

local function stripRecord(profile: any, record: any)
	if type(record) ~= "table" or record.status ~= "open" or type(record.goods) ~= "table" then
		return
	end
	for _, item in ipairs(record.goods.items or {}) do
		if type(item) == "table" and type(item.uid) == "string" then
			if Schema.findItem(profile, item.uid) ~= nil then
				Trading.takeItem(profile, item.uid)
			end
		end
	end
end

function MarketCross.settle(
	deps: any,
	profile: any,
	userId: number,
	context: Trading.Context,
	now: number
)
	local boxOk, box = readBox(deps, userId)
	if not boxOk then
		return nil, "Could not reach the market."
	end
	local source = copyBox(box)
	for _, listingId in ipairs(source.openIds) do
		local foundOk, record = readListing(deps, listingId)
		if
			foundOk
			and type(record) == "table"
			and record.status == "open"
			and record.expiresAt <= now
		then
			MarketCross.expire(deps, listingId, context, now)
		elseif foundOk and type(record) == "table" then
			stripRecord(profile, record)
		end
	end
	local againOk, again = readBox(deps, userId)
	if againOk then
		source = copyBox(again)
	end
	local snap = Trading.capture(profile)
	local applied = {}
	for _, entry in ipairs(source.entries) do
		if type(entry) == "table" and type(entry.id) == "string" then
			if seen(profile, entry.id) then
				table.insert(applied, entry.id)
			else
				local err = applyEntry(profile, entry)
				if err ~= nil then
					Trading.restore(profile, snap)
					return nil, err
				end
				remember(profile, entry.id)
				table.insert(applied, entry.id)
				if entry.kind == "sale" and type(entry.amount) == "number" then
					local seller = storeActor({
						userId = userId,
						name = "seller",
						level = profile.level or 1,
						accountAgeDays = 30,
						cleanHistoryDays = 30,
						verifiedSpender = false,
						patron = false,
						verifiedTrader = false,
						flagged = false,
						tradeLocked = false,
						recentHandoff = false,
						connected = nil,
					})
					Trading.auditMarket(context, "payout", seller, nil, {
						{
							kind = tostring(entry.currency or "gold"),
							id = tostring(entry.currency or "gold"),
							uid = "",
							count = entry.amount,
							name = "Payout",
							rarity = "",
							itemKind = "Currency",
							fromUserId = 0,
							toUserId = userId,
							value = entry.amount,
							tax = 0,
						},
					}, 0, entry.amount, now, tostring(entry.listingId or ""))
				end
			end
		end
	end
	return {
		ok = true,
		applied = applied,
	}, nil
end

function MarketCross.ack(deps: any, userId: number, ids: { string }): boolean
	if #ids == 0 then
		return true
	end
	local wrote = writeBox(deps, userId, function(current)
		return dropMail(current, ids)
	end)
	return wrote == true
end

local function matches(row: any, filter: any): boolean
	if type(filter) ~= "table" then
		return true
	end
	if filter.currency ~= nil and row.currency ~= filter.currency then
		return false
	end
	if filter.sellerUserId ~= nil and row.sellerUserId ~= filter.sellerUserId then
		return false
	end
	if filter.search ~= nil then
		local hay = string.lower(tostring(row.name or ""))
		if string.find(hay, string.lower(tostring(filter.search)), 1, true) == nil then
			return false
		end
	end
	if filter.rarity ~= nil then
		local hay = string.lower(tostring(row.name or ""))
		if string.find(hay, string.lower(tostring(filter.rarity)), 1, true) == nil then
			return false
		end
	end
	return true
end

function MarketCross.browse(deps: any, filter: any, context: Trading.Context, now: number): { any }
	local categories = MarketCross.CATEGORIES
	if type(filter) == "table" and type(filter.kind) == "string" then
		categories = { filter.kind }
	end
	local direction = "Asc"
	if type(filter) == "table" and filter.sort == "desc" then
		direction = "Desc"
	end
	local views = {}
	for _, category in ipairs(categories) do
		local pageOk, page = attempt(deps, function()
			return deps.maps:map(category):getRange(direction, 100)
		end)
		if pageOk and type(page) == "table" then
			for _, row in ipairs(page) do
				local summary = if type(row) == "table" then row.value else nil
				if type(summary) == "table" and matches(summary, filter) then
					local foundOk, record = readListing(deps, summary.id)
					if foundOk and type(record) == "table" then
						if record.status == "open" and record.expiresAt <= now then
							MarketCross.expire(deps, record.id, context, now)
						elseif record.status == "open" then
							table.insert(views, MarketBoard.view(record, nil))
						end
					end
				end
			end
		end
	end
	return views
end

function MarketCross.mine(deps: any, userId: number, context: Trading.Context, now: number): { any }
	local views = {}
	local boxOk, box = readBox(deps, userId)
	if not boxOk then
		return views
	end
	for _, listingId in ipairs(copyBox(box).openIds) do
		local foundOk, record = readListing(deps, listingId)
		if foundOk and type(record) == "table" then
			if record.status == "open" and record.expiresAt <= now then
				MarketCross.expire(deps, listingId, context, now)
			elseif record.status == "open" then
				table.insert(views, MarketBoard.view(record, nil))
			end
		end
	end
	return views
end

return MarketCross
