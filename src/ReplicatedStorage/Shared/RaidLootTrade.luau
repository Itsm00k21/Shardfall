--!strict

--[[
	Raid personal loot trade rules.

	The server passes the item, the proposal, and unix seconds. This
	module does not read players, grant loot, or touch DataStores and
	remotes. It does not read the clock. Pass os.time() as now.
	Thresholds live in CONFIG. Nothing here costs Robux.

	Raid gear may move during the 2-hour window, and only to a player
	who was eligible for that boss in that run. The end instant is
	still inside the window. After it, the piece is bound. A traded
	flag, or a droppedFor id other than the sender, binds it inside
	the window too. One trade.

	Crafted Heartshard weapons do not use that window. They become
	tradeable to anyone once the crafter has at least 1 clear. Raid
	cosmetics stay bound. Relic Set pieces are exempt. RelicSets.isRelic
	skips the window, the run, and the roster. item.bound is not read.
]]

local RelicSets = require("./RelicSets")

local RaidLootTrade = {}

RaidLootTrade.CONFIG = table.freeze({
	bindSeconds = 2 * 60 * 60,
	heartshardClears = 1,
})

RaidLootTrade.HEARTSHARD = "heartshard"
RaidLootTrade.HEARTWOOD_PREFIX = "heartwood_"

RaidLootTrade.GEAR_KINDS = table.freeze({
	weapon = true,
	armor = true,
	accessory = true,
})

RaidLootTrade.RAID_SOURCES = table.freeze({
	raid = true,
	heartwood = true,
	heartwood_story = true,
	heartwood_normal = true,
	heartwood_hard = true,
	heartwood_shardbreaker = true,
	shardbreaker = true,
	fracture = true,
})

RaidLootTrade.CRAFT_SOURCES = table.freeze({
	craft = true,
	crafted = true,
	forge = true,
})

RaidLootTrade.ERRORS = table.freeze({
	time = "Raid time is missing.",
	item = "That item cannot be traded.",
	trader = "That trader is missing.",
	player = "That player is missing.",
	self = "You already hold that.",
	cosmetic = "Raid cosmetics stay bound.",
	heartshard = "Crafted Heartshard weapons bind until the first clear.",
	clears = "That clear count cannot be used.",
	dropTime = "That drop has no time.",
	run = "That drop has no run.",
	early = "That drop is not live yet.",
	bound = "That raid gear is bound.",
	name = "Name someone from that run.",
	runId = "That run id is unusable.",
	wrongRun = "That player was not in this run.",
	ineligible = "That player was not eligible for that boss.",
	traded = "That piece was already traded.",
})

local RELIC = "relic"
local COSMETIC = "cosmetic"
local HEARTSHARD = "heartshard"
local GEAR = "gear"
local OTHER = "other"
local INVALID = "invalid"

export type Transfer = {
	now: number,
	fromUserId: number,
	toUserId: number?,
	crafterClears: number?,
	runId: string?,
	bossId: string?,
}

export type Result = {
	ok: boolean,
	applies: boolean,
	category: string,
	bound: boolean,
	tradeable: boolean,
	windowOpen: boolean,
	remainingSeconds: number,
	reason: string?,
}

export type Window = {
	ok: boolean,
	applies: boolean,
	open: boolean,
	remainingSeconds: number,
	closesAt: number,
	reason: string?,
}

type Fields = {
	ok: boolean,
	applies: boolean,
	category: string,
	bound: boolean,
	tradeable: boolean,
	windowOpen: boolean,
	remainingSeconds: number,
	reason: string?,
}

type Span = {
	droppedAt: number,
	closesAt: number,
	remaining: number,
	open: boolean,
}

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function clock(value: any): number?
	local at = finite(value)
	if at == nil or at < 0 then
		return nil
	end
	return at
end

local function userId(value: any): number?
	local id = finite(value)
	if id == nil or id < 1 or id ~= math.floor(id) then
		return nil
	end
	return id
end

local function text(value: any): string?
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function lower(value: any): string?
	local raw = text(value)
	if raw == nil then
		return nil
	end
	return string.lower(raw)
end

local function pack(fields: Fields): Result
	return {
		ok = fields.ok,
		applies = fields.applies,
		category = fields.category,
		bound = fields.bound,
		tradeable = fields.tradeable,
		windowOpen = fields.windowOpen,
		remainingSeconds = fields.remainingSeconds,
		reason = fields.reason,
	}
end

local function deny(category: string, reason: string): Result
	return pack({
		ok = false,
		applies = true,
		category = category,
		bound = true,
		tradeable = false,
		windowOpen = false,
		remainingSeconds = 0,
		reason = reason,
	})
end

local function allow(category: string): Result
	return pack({
		ok = true,
		applies = true,
		category = category,
		bound = false,
		tradeable = true,
		windowOpen = false,
		remainingSeconds = 0,
	})
end

local function invalid(reason: string): Result
	return deny(INVALID, reason)
end

local function listed(bag: any, id: number): boolean
	if type(bag) ~= "table" then
		return false
	end
	if bag[id] == true then
		return true
	end
	for _, value in pairs(bag) do
		if value == id then
			return true
		end
	end
	return false
end

local function sourceName(item: any): string?
	local source = lower(item.source)
	if source == nil then
		source = lower(item.origin)
	end
	return source
end

local function raidProvenance(item: any): boolean
	if item.raid == true or item.raidCosmetic == true then
		return true
	end
	local source = sourceName(item)
	if source == nil then
		return false
	end
	if RaidLootTrade.RAID_SOURCES[source] == true then
		return true
	end
	local prefix = RaidLootTrade.HEARTWOOD_PREFIX
	return string.sub(source, 1, #prefix) == prefix
end

local function dropStamp(item: any): boolean
	return clock(item.droppedAt) ~= nil and text(item.runId) ~= nil
end

local function hasMark(value: any): boolean
	local id = lower(value)
	if id == nil then
		return false
	end
	return string.find(id, RaidLootTrade.HEARTSHARD, 1, true) ~= nil
end

local function heartshardNamed(item: any): boolean
	if item.heartshard == true then
		return true
	end
	if lower(item.family) == RaidLootTrade.HEARTSHARD then
		return true
	end
	if lower(item.weaponFamily) == RaidLootTrade.HEARTSHARD then
		return true
	end
	return hasMark(item.templateId) or hasMark(item.id)
end

local function isCrafted(item: any): boolean
	if item.crafted == true then
		return true
	end
	local source = sourceName(item)
	if source == nil then
		return false
	end
	return RaidLootTrade.CRAFT_SOURCES[source] == true
end

local function craftedHeartshard(item: any): boolean
	if not heartshardNamed(item) or not isCrafted(item) then
		return false
	end
	local kind = lower(item.kind)
	return kind == nil or kind == "weapon"
end

local function raidCosmetic(item: any): boolean
	if item.raidCosmetic == true then
		return true
	end
	if lower(item.kind) ~= "cosmetic" then
		return false
	end
	if raidProvenance(item) then
		return true
	end
	return text(item.runId) ~= nil
end

local function raidGear(item: any): boolean
	local kind = lower(item.kind)
	if kind == nil or RaidLootTrade.GEAR_KINDS[kind] ~= true then
		return false
	end
	return raidProvenance(item) or dropStamp(item)
end

local function categorize(item: any): string
	if type(item) ~= "table" then
		return INVALID
	end
	if RelicSets.isRelic(item) then
		return RELIC
	end
	if raidCosmetic(item) then
		return COSMETIC
	end
	if craftedHeartshard(item) then
		return HEARTSHARD
	end
	if raidGear(item) then
		return GEAR
	end
	return OTHER
end

function RaidLootTrade.category(item: any): string
	return categorize(item)
end

local function span(item: any, now: number): Span?
	local droppedAt = clock(item.droppedAt)
	if droppedAt == nil then
		return nil
	end
	local closesAt = droppedAt + RaidLootTrade.CONFIG.bindSeconds
	local remaining = closesAt - now
	if remaining < 0 then
		remaining = 0
	end
	return {
		droppedAt = droppedAt,
		closesAt = closesAt,
		remaining = remaining,
		open = now >= droppedAt and now <= closesAt,
	}
end

local function closedWindow(reason: string): Window
	return {
		ok = false,
		applies = false,
		open = false,
		remainingSeconds = 0,
		closesAt = 0,
		reason = reason,
	}
end

function RaidLootTrade.window(item: any, now: any): Window
	local at = clock(now)
	if at == nil then
		return closedWindow(RaidLootTrade.ERRORS.time)
	end
	if type(item) ~= "table" then
		return closedWindow(RaidLootTrade.ERRORS.item)
	end
	if categorize(item) ~= GEAR then
		return {
			ok = true,
			applies = false,
			open = false,
			remainingSeconds = 0,
			closesAt = 0,
		}
	end
	local view = span(item, at)
	if view == nil then
		return {
			ok = false,
			applies = true,
			open = false,
			remainingSeconds = 0,
			closesAt = 0,
			reason = RaidLootTrade.ERRORS.dropTime,
		}
	end
	return {
		ok = true,
		applies = true,
		open = view.open,
		remainingSeconds = view.remaining,
		closesAt = view.closesAt,
	}
end

-- Seconds until the gear window closes. Nil when this item has no
-- window or the clock cannot be used. 0 at the last instant and after
-- it. window().open is how those two differ. A future stamp reports
-- the full wait, which can be longer than bindSeconds, and is not open.
function RaidLootTrade.remaining(item: any, now: any): number?
	local view = RaidLootTrade.window(item, now)
	if view.ok ~= true or view.applies ~= true then
		return nil
	end
	return view.remainingSeconds
end

local function gearResult(
	ok: boolean,
	bound: boolean,
	tradeable: boolean,
	open: boolean,
	remaining: number,
	reason: string?
): Result
	return pack({
		ok = ok,
		applies = true,
		category = GEAR,
		bound = bound,
		tradeable = tradeable,
		windowOpen = open,
		remainingSeconds = remaining,
		reason = reason,
	})
end

local function alreadyTraded(item: any, fromId: number): boolean
	if item.traded == true then
		return true
	end
	local owner = userId(item.droppedFor)
	if owner == nil then
		return false
	end
	return owner ~= fromId
end

local function runProblem(item: any, transfer: any): string?
	if transfer.runId == nil then
		return nil
	end
	local claimed = text(transfer.runId)
	if claimed == nil then
		return RaidLootTrade.ERRORS.runId
	end
	local stamped = text(item.runId)
	if stamped == nil or claimed ~= stamped then
		return RaidLootTrade.ERRORS.wrongRun
	end
	return nil
end

local function bossMismatch(item: any, transfer: any): boolean
	local asked = text(transfer.bossId)
	if asked == nil then
		return false
	end
	local stamped = text(item.bossId)
	if stamped == nil then
		return true
	end
	return asked ~= stamped
end

local function readClears(item: any, transfer: any): (number?, string?)
	local raw = transfer.crafterClears
	if raw == nil then
		raw = item.crafterClears
	end
	if raw == nil then
		raw = item.clears
	end
	if raw == nil then
		return 0, nil
	end
	local count = finite(raw)
	if count == nil or count < 0 or count ~= math.floor(count) then
		return nil, RaidLootTrade.ERRORS.clears
	end
	return count, nil
end

local function checkHeartshard(item: any, transfer: any): Result
	local count, problem = readClears(item, transfer)
	if count == nil then
		return deny(HEARTSHARD, problem or RaidLootTrade.ERRORS.clears)
	end
	if count >= RaidLootTrade.CONFIG.heartshardClears then
		return allow(HEARTSHARD)
	end
	return deny(HEARTSHARD, RaidLootTrade.ERRORS.heartshard)
end

local function checkGear(
	item: any,
	transfer: any,
	now: number,
	fromId: number,
	toId: number?
): Result
	local view = span(item, now)
	if view == nil then
		return gearResult(false, true, false, false, 0, RaidLootTrade.ERRORS.dropTime)
	end
	if now < view.droppedAt then
		return gearResult(false, false, false, false, view.remaining, RaidLootTrade.ERRORS.early)
	end
	if not view.open then
		return gearResult(false, true, false, false, 0, RaidLootTrade.ERRORS.bound)
	end
	if alreadyTraded(item, fromId) then
		return gearResult(false, true, false, true, view.remaining, RaidLootTrade.ERRORS.traded)
	end
	if text(item.runId) == nil then
		return gearResult(false, false, false, true, view.remaining, RaidLootTrade.ERRORS.run)
	end
	local runReason = runProblem(item, transfer)
	if runReason ~= nil then
		return gearResult(false, false, true, true, view.remaining, runReason)
	end
	if toId == nil then
		return gearResult(false, false, true, true, view.remaining, RaidLootTrade.ERRORS.name)
	end
	if bossMismatch(item, transfer) then
		return gearResult(false, false, true, true, view.remaining, RaidLootTrade.ERRORS.ineligible)
	end
	if listed(item.eligible, toId) then
		return gearResult(true, false, true, true, view.remaining, nil)
	end
	local reason = RaidLootTrade.ERRORS.wrongRun
	if listed(item.roster, toId) then
		reason = RaidLootTrade.ERRORS.ineligible
	end
	return gearResult(false, false, true, true, view.remaining, reason)
end

function RaidLootTrade.check(item: any, transfer: any): Result
	if type(transfer) ~= "table" then
		return invalid(RaidLootTrade.ERRORS.time)
	end
	local now = clock(transfer.now)
	if now == nil then
		return invalid(RaidLootTrade.ERRORS.time)
	end
	if type(item) ~= "table" then
		return invalid(RaidLootTrade.ERRORS.item)
	end
	local fromId = userId(transfer.fromUserId)
	if fromId == nil then
		return invalid(RaidLootTrade.ERRORS.trader)
	end
	local toId: number? = nil
	if transfer.toUserId ~= nil then
		toId = userId(transfer.toUserId)
		if toId == nil then
			return invalid(RaidLootTrade.ERRORS.player)
		end
		if toId == fromId then
			return invalid(RaidLootTrade.ERRORS.self)
		end
	end
	local category = categorize(item)
	if category == RELIC then
		return allow(RELIC)
	end
	if category == COSMETIC then
		return deny(COSMETIC, RaidLootTrade.ERRORS.cosmetic)
	end
	if category == HEARTSHARD then
		return checkHeartshard(item, transfer)
	end
	if category == GEAR then
		return checkGear(item, transfer, now, fromId, toId)
	end
	return pack({
		ok = true,
		applies = false,
		category = OTHER,
		bound = false,
		tradeable = true,
		windowOpen = false,
		remainingSeconds = 0,
	})
end

return RaidLootTrade
