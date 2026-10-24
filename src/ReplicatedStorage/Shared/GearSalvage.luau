--!strict

--[[
	Stage B. Salvage gear into profile.gearEssence.

	That field is the wallet #387 records. Do not add profile.essence
	or a second balance. Default is 0. A missing, negative, NaN, or
	infinite value becomes 0. A fractional value floors. The stored
	number stops at Essence.CAP (the same 1_000_000_000 clamp).

	#381's Schema is not on this base. migrate() copies first and only
	fills gearEssence, autoSalvage, and autoSalvageRarity. schemaVersion
	stays 26. When #381's migration list lands, register that copy as
	one step. Do not bump the version before then: a higher version
	looks newer to a v26 server, and that server refuses the load.

	#387 is being revised (issue #15, comment 6358371837). Dupes may
	grant stars through Stars.applyStats. Gold upgrades get stat
	scaling. This module does not read or write the upgrade field and
	does not decide when a duplicate is capped. The seam is grant():

		GearSalvage.grant(profile, amount)

	Stage A calls it when its own rule says the duplicate overflows.
	Accept.record on #387 can pass grant as its hook so both paths
	share one write. Calling grant and Accept.record's default write
	on the same duplicate pays twice. Pick one.

	grantCappedDupe(profile, rarity, key, ownerId) is the same write
	with a per-session key so a retry adds nothing. It does not look
	at the owned item.

	Auto-salvage (off by default) converts a new drop at or below the
	chosen rarity into Essence. It does not delete a row that is
	already in the bag. Equipped gear, including equipLoadout when
	that table exists, is never salvaged. Locked gear is never
	salvaged. Favorited gear (item.favorite) is never salvaged.
	An explicit list fails with "That item is a favorite." and
	deletes nothing. A rarity sweep skips that piece and reports
	the skip. Nothing here is for sale.

	Salvage selected and salvage-all both preview first. The preview
	stores a token and deletes nothing. confirm (and salvageNow)
	spends that token.
]]

local Essence = require("./Config/Essence")
local InventoryView = require("./InventoryView")
local LaunchGate = require("./LaunchGate")
local Rarities = require("./Rarities")
local Schema = require("./Schema")

local GearSalvage = {}

GearSalvage.FIELD = "gearEssence"
GearSalvage.CAP = Essence.CAP
GearSalvage.TOKEN_SECONDS = 20

local READ = {
	state = true,
	preview = true,
	nudge = true,
	-- Explicit salvage previews a token. confirm is the delete.
	salvage = true,
}

local ACTIONS = {
	state = true,
	lock = true,
	salvage = true,
	preview = true,
	confirm = true,
	salvageNow = true,
	nudge = true,
	auto = true,
}

type Pending = {
	token: string,
	mode: string,
	rarity: string,
	uids: { string },
	expires: number,
}

local pending: { [string]: Pending } = {}
local books: { [string]: { [string]: boolean } } = {}
local bookOrder: { [string]: { string } } = {}
local serial = 0
local BOOK_MAX = 128

local function ownerKey(ownerId: any): string?
	if type(ownerId) ~= "number" or ownerId ~= ownerId then
		return nil
	end
	if ownerId >= math.huge or ownerId <= -math.huge then
		return nil
	end
	return tostring(ownerId)
end

local function validUid(uid: any): boolean
	return type(uid) == "string"
		and #uid > 0
		and #uid <= 64
		and string.match(uid, "^[%w%-]+$") ~= nil
end

local function clock(now: any): number?
	if type(now) ~= "number" or now ~= now or now >= math.huge or now <= -math.huge then
		return nil
	end
	return math.floor(now)
end

local function knownRarity(value: any): boolean
	return type(value) == "string" and Rarities.INDEX[value] ~= nil
end

local function inLoadout(profile: any, uid: string): boolean
	local loadout = profile.equipLoadout
	if type(loadout) ~= "table" then
		return false
	end
	for _, slotUid in pairs(loadout) do
		if slotUid == uid then
			return true
		end
	end
	return false
end

local FAVORITE = "That item is a favorite."

-- Nil when this piece may be salvaged. Equipped, locked, and favorited stay.
local function blockReason(profile: any, item: any): string?
	if type(item) == "table" and (item.kind == "Weapon" or item.kind == "Armor") then
		if item.locked == true then
			return "That item is locked."
		end
		if item.favorite == true then
			return FAVORITE
		end
	end
	local reason = InventoryView.salvageBlock(profile, item)
	if reason ~= nil then
		return reason
	end
	if type(item) == "table" and type(item.uid) == "string" and inLoadout(profile, item.uid) then
		return "Unequip it before salvaging."
	end
	return nil
end

local function readBalance(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then
		return 0
	end
	local whole = math.floor(value)
	if whole > GearSalvage.CAP then
		return GearSalvage.CAP
	end
	return whole
end

-- Writes the three save fields in place. Other keys are left alone.
function GearSalvage.applySave(profile: any)
	if type(profile) ~= "table" then
		return
	end
	profile.gearEssence = readBalance(profile.gearEssence)
	local rarity = profile.autoSalvageRarity
	if not knownRarity(rarity) then
		rarity = ""
	end
	profile.autoSalvageRarity = rarity
	profile.autoSalvage = profile.autoSalvage == true and rarity ~= ""
end

-- A copy of the three fields. The profile argument is not written.
function GearSalvage.view(profile: any): { [string]: any }
	local raw = if type(profile) == "table" then profile else {}
	local copy = {
		gearEssence = raw.gearEssence,
		autoSalvage = raw.autoSalvage,
		autoSalvageRarity = raw.autoSalvageRarity,
	}
	GearSalvage.applySave(copy)
	return copy
end

-- Copy first. The caller's table is not edited.
function GearSalvage.migrate(raw: any): (any?, string?)
	if type(raw) ~= "table" then
		return nil, "corrupt"
	end
	local copy = Schema.deepCopy(raw)
	GearSalvage.applySave(copy)
	return copy, nil
end

-- The capped-dupe seam. Adds amount onto profile.gearEssence.
-- Does not read or delete items. amount <= 0 adds nothing.
function GearSalvage.grant(profile: any, amount: any)
	if type(profile) ~= "table" then
		return
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount >= math.huge then
		return
	end
	local whole = math.floor(amount)
	local current = profile.gearEssence
	if type(current) ~= "number" or current ~= current or current < 0 or current >= math.huge then
		current = 0
	else
		current = math.floor(current)
	end
	local nextValue = current + whole
	if nextValue > GearSalvage.CAP then
		nextValue = GearSalvage.CAP
	end
	profile.gearEssence = nextValue
end

local function remember(owner: string, key: string)
	local seen = books[owner]
	local order = bookOrder[owner]
	if seen == nil or order == nil then
		seen = {}
		order = {}
		books[owner] = seen
		bookOrder[owner] = order
	end
	if seen[key] == true then
		return
	end
	seen[key] = true
	table.insert(order, key)
	while #order > BOOK_MAX do
		local old = table.remove(order, 1)
		if old ~= nil then
			seen[old] = nil
		end
	end
end

-- One Essence grant per owner and key. Does not inspect the owned item.
function GearSalvage.grantCappedDupe(profile: any, rarity: any, key: any, ownerId: any)
	local balance = 0
	if type(profile) == "table" then
		balance = GearSalvage.view(profile).gearEssence
	end
	if type(profile) ~= "table" then
		return {
			ok = false,
			paid = false,
			gained = 0,
			gearEssence = 0,
			error = "Profile is not loaded.",
		}
	end
	local amount = Essence.amount(rarity)
	if amount == nil then
		return {
			ok = false,
			paid = false,
			gained = 0,
			gearEssence = balance,
			error = "Unknown rarity.",
		}
	end
	if not validUid(key) then
		return {
			ok = false,
			paid = false,
			gained = 0,
			gearEssence = balance,
			error = "That duplicate was not accepted.",
		}
	end
	local owner = ownerKey(ownerId)
	if owner == nil then
		return {
			ok = false,
			paid = false,
			gained = 0,
			gearEssence = balance,
			error = "That duplicate was not accepted.",
		}
	end
	local seen = books[owner]
	if seen ~= nil and seen[key] == true then
		return { ok = true, paid = false, gained = 0, gearEssence = balance }
	end
	GearSalvage.applySave(profile)
	local before = profile.gearEssence
	GearSalvage.grant(profile, amount)
	local gained = profile.gearEssence - before
	remember(owner, key)
	return {
		ok = true,
		paid = gained > 0,
		gained = gained,
		gearEssence = profile.gearEssence,
	}
end

function GearSalvage.setLock(profile: any, uid: any, locked: any): (boolean, string?)
	if type(profile) ~= "table" or not validUid(uid) or type(locked) ~= "boolean" then
		return false, "You do not have that item."
	end
	local item = Schema.findItem(profile, uid)
	if item == nil then
		return false, "You do not have that item."
	end
	item.locked = locked
	return true, nil
end

function GearSalvage.setAuto(profile: any, enabled: any, rarity: any): (boolean, string?)
	if type(profile) ~= "table" or type(enabled) ~= "boolean" then
		return false, "Auto-salvage needs a choice."
	end
	if enabled then
		if not knownRarity(rarity) then
			return false, "Unknown rarity."
		end
		profile.autoSalvage = true
		profile.autoSalvageRarity = rarity
	else
		profile.autoSalvage = false
		if knownRarity(rarity) then
			profile.autoSalvageRarity = rarity
		end
	end
	GearSalvage.applySave(profile)
	return true, nil
end

local function copyUids(uids: { string }): { string }
	return table.clone(uids)
end

local function sameList(left: { string }, right: { string }): boolean
	if #left ~= #right then
		return false
	end
	for index, uid in ipairs(left) do
		if right[index] ~= uid then
			return false
		end
	end
	return true
end

-- Unequipped, unlocked, unfavorited weapons and armor at or below rarity.
-- skipped lists each piece that was in range and stayed, with the reason.
function GearSalvage.plan(profile: any, rarity: any): ({ [string]: any }?, string?, { any }?)
	if not knownRarity(rarity) then
		return nil, "Unknown rarity."
	end
	if type(profile) ~= "table" or type(profile.inventory) ~= "table" then
		return nil, "Nothing of that rarity can be salvaged."
	end
	local cap = Rarities.INDEX[rarity]
	local uids = {}
	local skipped = {}
	for uid, item in pairs(profile.inventory) do
		if type(uid) == "string" and type(item) == "table" and type(item.rarity) == "string" then
			local rank = Rarities.INDEX[item.rarity]
			local pay = Essence.amount(item.rarity)
			if rank ~= nil and cap ~= nil and rank <= cap and pay ~= nil then
				local blocked = blockReason(profile, item)
				if blocked == nil then
					table.insert(uids, uid)
				else
					table.insert(skipped, { uid = uid, reason = blocked })
				end
			end
		end
	end
	table.sort(uids)
	table.sort(skipped, function(left, right)
		return left.uid < right.uid
	end)
	if #uids == 0 then
		local onlyFavorites = #skipped > 0
		for _, row in ipairs(skipped) do
			if row.reason ~= FAVORITE then
				onlyFavorites = false
				break
			end
		end
		if onlyFavorites then
			return nil, FAVORITE, skipped
		end
		return nil, "Nothing of that rarity can be salvaged.", skipped
	end
	local gain = 0
	for _, uid in ipairs(uids) do
		gain += Essence.amount(profile.inventory[uid].rarity) :: number
	end
	return {
		uids = uids,
		rarity = rarity,
		gain = gain,
		count = #uids,
		skipped = skipped,
		mode = "rarity",
	},
		nil,
		skipped
end

local function salvageUids(profile: any, uids: { string }): ({ [string]: any }?, string?)
	if type(profile.inventory) ~= "table" then
		return nil, "You do not have that item."
	end
	local total = 0
	for _, uid in ipairs(uids) do
		local item = profile.inventory[uid]
		if type(item) ~= "table" then
			return nil, "You do not have that item."
		end
		local blocked = blockReason(profile, item)
		if blocked ~= nil then
			return nil, blocked
		end
		local pay = Essence.amount(item.rarity)
		if pay == nil then
			return nil, "Unknown rarity."
		end
		total += pay
	end
	GearSalvage.applySave(profile)
	if total > GearSalvage.CAP - profile.gearEssence then
		return nil, "Essence is full."
	end
	for _, uid in ipairs(uids) do
		profile.inventory[uid] = nil
	end
	GearSalvage.grant(profile, total)
	return {
		count = #uids,
		gained = total,
		gearEssence = profile.gearEssence,
		uids = copyUids(uids),
	},
		nil
end

local function pack(profile: any, extra: { [string]: any })
	local view = GearSalvage.view(profile)
	extra.ok = true
	extra.gearEssence = view.gearEssence
	extra.autoSalvage = view.autoSalvage
	extra.autoSalvageRarity = view.autoSalvageRarity
	return extra
end

local function fail(message: string)
	return { ok = false, error = message }
end

local function forSale(payload: { [string]: any }): boolean
	return payload.robux ~= nil or payload.productId ~= nil or payload.receiptId ~= nil
end

local function readUids(value: any): ({ string }?, string?)
	if type(value) ~= "table" or #value < 1 or #value > 100 then
		return nil, "Pick gear to salvage."
	end
	local seen: { [string]: boolean } = {}
	local uids = {}
	for _, uid in ipairs(value) do
		if not validUid(uid) or seen[uid] == true then
			return nil, "Pick gear to salvage."
		end
		seen[uid] = true
		table.insert(uids, uid)
	end
	local extra = 0
	for _ in pairs(value) do
		extra += 1
	end
	if extra ~= #uids then
		return nil, "Pick gear to salvage."
	end
	return uids, nil
end

local function mint(now: number): string
	serial += 1
	local stamp = now % 1000000
	if stamp < 0 then
		stamp = -stamp
	end
	return string.format("es-%d-%d", serial, stamp)
end

local function validToken(token: any): boolean
	return type(token) == "string" and #token <= 64 and string.match(token, "^es%-%d+%-%d+$") ~= nil
end

-- New drop. kept == false means the caller must not insert it.
-- An item already in the bag is never removed here.
function GearSalvage.receive(profile: any, item: any)
	local function keep()
		local balance = 0
		if type(profile) == "table" then
			balance = GearSalvage.view(profile).gearEssence
		end
		return { kept = true, gained = 0, gearEssence = balance }
	end
	if not LaunchGate.on("gearSalvage") then
		return keep()
	end
	if type(profile) ~= "table" or type(item) ~= "table" then
		return keep()
	end
	local settings = GearSalvage.view(profile)
	if settings.autoSalvage ~= true then
		return keep()
	end
	local rank = if type(item.rarity) == "string" then Rarities.INDEX[item.rarity] else nil
	local cap = Rarities.INDEX[settings.autoSalvageRarity]
	if rank == nil or cap == nil or rank > cap then
		return keep()
	end
	if
		type(item.uid) == "string"
		and type(profile.inventory) == "table"
		and profile.inventory[item.uid] ~= nil
	then
		return keep()
	end
	local blocked = blockReason(profile, item)
	if blocked ~= nil then
		local held = keep()
		held.reason = blocked
		return held
	end
	local pay = Essence.amount(item.rarity)
	if pay == nil then
		return keep()
	end
	local balance = GearSalvage.view(profile).gearEssence
	if pay > GearSalvage.CAP - balance then
		return keep()
	end
	GearSalvage.applySave(profile)
	GearSalvage.grant(profile, pay)
	return { kept = false, gained = pay, gearEssence = profile.gearEssence }
end

function GearSalvage.isRead(action: any): boolean
	return type(action) == "string" and READ[action] == true
end

function GearSalvage._reset()
	for key in pairs(pending) do
		pending[key] = nil
	end
	for key in pairs(books) do
		books[key] = nil
	end
	for key in pairs(bookOrder) do
		bookOrder[key] = nil
	end
	serial = 0
end

local function storePlan(owner: string, plan: { [string]: any }, now: number): string
	local token = mint(now)
	local rarity = plan.rarity
	pending[owner] = {
		token = token,
		mode = if plan.mode == "selected" then "selected" else "rarity",
		rarity = if type(rarity) == "string" then rarity else "",
		uids = copyUids(plan.uids),
		expires = now + GearSalvage.TOKEN_SECONDS,
	}
	return token
end

local function withSkipped(result: { [string]: any }, skipped: { any }?): { [string]: any }
	if skipped ~= nil then
		result.skipped = skipped
	end
	return result
end

local function preview(profile: any, ownerId: any, rarity: any, now: any)
	local owner = ownerKey(ownerId)
	local when = clock(now)
	if owner == nil or when == nil then
		return fail("Could not salvage that.")
	end
	local plan, reason, skipped = GearSalvage.plan(profile, rarity)
	if plan == nil then
		return withSkipped(fail(reason or "Nothing of that rarity can be salvaged."), skipped)
	end
	local token = storePlan(owner, plan, when)
	return pack(profile, {
		token = token,
		count = plan.count,
		gain = plan.gain,
		rarity = plan.rarity,
		uids = copyUids(plan.uids),
		skipped = plan.skipped,
		message = string.format("%d pieces would become %d Essence.", plan.count, plan.gain),
	})
end

-- Explicit uids. All-or-nothing. Stores a token and deletes nothing.
local function previewSelected(profile: any, ownerId: any, rawUids: any, now: any)
	local owner = ownerKey(ownerId)
	local when = clock(now)
	if owner == nil or when == nil then
		return fail("Could not salvage that.")
	end
	local uids, why = readUids(rawUids)
	if uids == nil then
		return fail(why or "Pick gear to salvage.")
	end
	table.sort(uids)
	if type(profile.inventory) ~= "table" then
		return fail("You do not have that item.")
	end
	local total = 0
	for _, uid in ipairs(uids) do
		local item = profile.inventory[uid]
		if type(item) ~= "table" then
			return fail("You do not have that item.")
		end
		local blocked = blockReason(profile, item)
		if blocked ~= nil then
			return fail(blocked)
		end
		local pay = Essence.amount(item.rarity)
		if pay == nil then
			return fail("Unknown rarity.")
		end
		total += pay
	end
	local token = storePlan(owner, { mode = "selected", rarity = "", uids = uids }, when)
	return pack(profile, {
		token = token,
		count = #uids,
		gain = total,
		uids = copyUids(uids),
		message = string.format("%d pieces would become %d Essence.", #uids, total),
	})
end

local function recheckSelected(profile: any, uids: { string }): (boolean, string?)
	if type(profile.inventory) ~= "table" then
		return false, "The bag changed. Look again."
	end
	for _, uid in ipairs(uids) do
		local item = profile.inventory[uid]
		if type(item) ~= "table" then
			return false, "The bag changed. Look again."
		end
		local blocked = blockReason(profile, item)
		if blocked ~= nil then
			return false, blocked
		end
		if Essence.amount(item.rarity) == nil then
			return false, "Unknown rarity."
		end
	end
	return true, nil
end

local function confirm(profile: any, ownerId: any, token: any, now: any)
	local owner = ownerKey(ownerId)
	local when = clock(now)
	if owner == nil or when == nil or not validToken(token) then
		return fail("That confirm expired. Look again.")
	end
	local row = pending[owner]
	if row == nil or row.token ~= token or when > row.expires then
		return fail("That confirm expired. Look again.")
	end
	local summary, why
	if row.mode == "selected" then
		local ready, blocked = recheckSelected(profile, row.uids)
		if not ready then
			pending[owner] = nil
			return fail(blocked or "The bag changed. Look again.")
		end
		summary, why = salvageUids(profile, row.uids)
	else
		local plan = GearSalvage.plan(profile, row.rarity)
		if plan == nil or not sameList(plan.uids, row.uids) then
			pending[owner] = nil
			return fail("The bag changed. Look again.")
		end
		summary, why = salvageUids(profile, plan.uids)
	end
	if summary == nil then
		return fail(why or "Could not salvage that.")
	end
	pending[owner] = nil
	summary.message = string.format("Salvaged %d for %d Essence.", summary.count, summary.gained)
	return pack(profile, summary)
end

function GearSalvage.applyAction(profile: any, ownerId: any, action: any, payload: any, now: any)
	if not LaunchGate.on("gearSalvage") then
		return fail("That is closed.")
	end
	if type(profile) ~= "table" then
		return fail("Profile is not loaded.")
	end
	if type(action) ~= "string" or ACTIONS[action] ~= true then
		return fail("Unknown salvage action.")
	end
	if payload ~= nil and type(payload) ~= "table" then
		return fail("Unknown salvage action.")
	end
	local body = if type(payload) == "table" then payload else {}
	if forSale(body) then
		return fail("Nothing here is for sale.")
	end
	if action == "state" then
		return pack(profile, {})
	end
	if action == "lock" then
		local ok, why = GearSalvage.setLock(profile, body.uid, body.locked)
		if not ok then
			return fail(why or "You do not have that item.")
		end
		local word = if body.locked == true then "Locked." else "Unlocked."
		return pack(profile, { uid = body.uid, locked = body.locked, message = word })
	end
	if action == "auto" then
		local ok, why = GearSalvage.setAuto(profile, body.enabled, body.rarity)
		if not ok then
			return fail(why or "Auto-salvage needs a choice.")
		end
		local message = "Auto-salvage off."
		if profile.autoSalvage == true then
			message = string.format("Auto-salvage on: %s and below.", profile.autoSalvageRarity)
		end
		return pack(profile, { message = message })
	end
	if action == "salvage" then
		return previewSelected(profile, ownerId, body.uids, now)
	end
	if action == "preview" then
		if body.uids ~= nil and knownRarity(body.rarity) then
			return fail("Pick gear to salvage.")
		end
		if body.uids ~= nil then
			return previewSelected(profile, ownerId, body.uids, now)
		end
		return preview(profile, ownerId, body.rarity, now)
	end
	if action == "nudge" then
		local rarity = body.rarity
		if not knownRarity(rarity) then
			local saved = GearSalvage.view(profile).autoSalvageRarity
			rarity = if knownRarity(saved) then saved else "Common"
		end
		return preview(profile, ownerId, rarity, now)
	end
	return confirm(profile, ownerId, body.token, now)
end

function GearSalvage.debugGrant(profile: any): (boolean, string)
	if type(profile) ~= "table" then
		return false, "Profile is not loaded."
	end
	GearSalvage.applySave(profile)
	local before = profile.gearEssence
	GearSalvage.grant(profile, 500)
	local gained = profile.gearEssence - before
	if gained <= 0 then
		return true, string.format("Essence already at the cap (%d).", profile.gearEssence)
	end
	return true, string.format("+%d Essence (now %d).", gained, profile.gearEssence)
end

function GearSalvage.debugFill(profile: any, now: any): (boolean, string)
	if
		type(profile) ~= "table"
		or type(profile.inventory) ~= "table"
		or type(profile.pets) ~= "table"
	then
		return false, "Profile is not loaded."
	end
	local cap = Schema.inventoryCap(profile)
	local before = Schema.countItems(profile)
	if before >= cap then
		return true, string.format("Bag is already full (%d/%d).", before, cap)
	end
	local when = clock(now)
	if when == nil then
		when = 0
	end
	local added = 0
	local serialFill = 0
	local limit = cap + 20
	while Schema.countItems(profile) < cap and serialFill < limit do
		serialFill += 1
		local uid = string.format("salvage-fill-%d-%d", when, serialFill)
		if Schema.findItem(profile, uid) == nil then
			Schema.insertItem(profile, {
				uid = uid,
				templateId = "iron_sword",
				name = "Iron Sword",
				kind = "Weapon",
				rarity = "Common",
				traits = {},
				poolId = "dev",
				obtainedAt = when,
				locked = false,
			})
			added += 1
		end
	end
	if added <= 0 then
		return true, string.format("Bag is already full (%d/%d).", Schema.countItems(profile), cap)
	end
	return true,
		string.format(
			"Filled the Bag with %d Common swords (%d/%d).",
			added,
			Schema.countItems(profile),
			cap
		)
end

return GearSalvage
