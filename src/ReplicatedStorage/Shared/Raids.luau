--!strict

--[[
	The Heartwood, Story and Normal.

	Lockouts, Raid Marks, and bad-luck protection live on the profile.
	Reserved servers are decided by RaidService. This module only does the
	numbers, so a Studio session can run the same raid alone.

	Raid Marks are granted only by payMarks. applyClear keeps the loot
	lock and the pity roll, then asks payMarks. It does not add marks
	itself. The amount is RaidMarks.payout. The wallet, the Tuesday week,
	and the catch-up bank are RaidMarks.earn. A repeated claim pays 0.
]]

local RaidMarks = require("./RaidMarks")

local Raids = {}

Raids.MARK_CAP = 600
Raids.DROP_BASE = 0.2
Raids.DROP_STEP = 0.1
Raids.DROP_CAP = 0.8
Raids.SOLO_HP = 0.35

local CLAIM_KEEP = 64
local PARTY_MAX = 8

Raids.DIFFICULTIES = {
	story = { id = "story", level = 15, hp = 1, damage = 0.85, loot = "Rare" },
	normal = { id = "normal", level = 15, hp = 1.35, damage = 1, loot = "Epic" },
}

Raids.WINGS = {
	{ id = "twins", name = "Thornwarden Twins" },
	{ id = "sapwell", name = "Mother Sapwell" },
	{ id = "galecrown", name = "Galecrown" },
	{ id = "awakened", name = "Grandmother Gnarl Awakened" },
}

Raids.TAGS = { "Learning", "Farm", "Speedrun", "Achievement" }

Raids.SHOP = {
	rare_chest = { id = "rare_chest", marks = 80, chest = "Rare" },
	epic_chest = { id = "epic_chest", marks = 160, chest = "Epic" },
	title = { id = "title", marks = 200, title = "Heartwood Student" },
}

function Raids.difficulty(id: any)
	if type(id) == "string" then
		return Raids.DIFFICULTIES[id]
	end
	return nil
end

function Raids.weekNumber(now: number): number
	return math.floor(now / (86400 * 7))
end

function Raids.roleOk(classId: any, role: any): (boolean, string)
	if role == "flex" then
		return true, ""
	end
	if type(classId) ~= "string" or classId == "" then
		return false, "Pick a class at the Forge first."
	end
	if role == "tank" and classId == "warden" then
		return true, ""
	end
	if role == "healer" and classId == "tidecaller" then
		return true, ""
	end
	if role == "dps" then
		return true, ""
	end
	return false, "That class does not fill that role. Pick Flex."
end

-- HP follows the party size. A missing healer softens boss damage.
function Raids.combatScale(difficulty: any, players: number, healer: boolean): (number, number)
	local row = Raids.difficulty(difficulty) or Raids.DIFFICULTIES.story
	local count = players
	if count < 1 then
		count = 1
	end
	if count > 8 then
		count = 8
	end
	local hp = row.hp * (count / 8)
	if hp < Raids.SOLO_HP then
		hp = Raids.SOLO_HP
	end
	local damage = row.damage
	if not healer then
		damage *= 0.85
	end
	return hp, damage
end

local function bag(data, key)
	if type(data[key]) ~= "table" then
		data[key] = {}
	end
	return data[key]
end

-- A paid ask is not a clear. Practice is not a clear. The caller amount
-- is never read. payMarks computes the grant.
local function paidAsk(request): boolean
	if request.productId ~= nil or request.robux ~= nil then
		return true
	end
	if request.cost ~= nil or request.skip ~= nil then
		return true
	end
	return false
end

local function claimId(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local length = #value
	if length < 3 or length > 80 then
		return nil
	end
	if string.find(value, "[^%w%-:]") ~= nil then
		return nil
	end
	local colon = string.find(value, ":", 1, true)
	if colon == nil or colon == 1 or colon == length then
		return nil
	end
	return value
end

local function already(data, claim: string): boolean
	local raw = data.raidMarkClaims
	if type(raw) ~= "table" then
		return false
	end
	local count = #raw
	local startAt = 1
	if count > CLAIM_KEEP then
		startAt = count - CLAIM_KEEP + 1
	end
	for index = startAt, count do
		if raw[index] == claim then
			return true
		end
	end
	return false
end

local function remember(data, claim: string)
	local kept = {}
	local raw = data.raidMarkClaims
	if type(raw) == "table" then
		local count = #raw
		local startAt = 1
		if count > CLAIM_KEEP - 1 then
			startAt = count - (CLAIM_KEEP - 1) + 1
		end
		for index = startAt, count do
			local value = raw[index]
			if type(value) == "string" and value ~= claim then
				table.insert(kept, value)
			end
		end
	end
	table.insert(kept, claim)
	data.raidMarkClaims = kept
end

-- Nil is zero first-timers. A count above the party of 8 is clamped.
-- A fractional or negative count is refused.
local function timerCount(value: any): number?
	if value == nil then
		return 0
	end
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	if value < 0 or value ~= math.floor(value) then
		return nil
	end
	if value > PARTY_MAX then
		return PARTY_MAX
	end
	return value
end

-- Until raidMarksBank has been written, a stored week key is still the
-- old Thursday number. earn would bank that gap. A key below 0 stamps
-- this Tuesday and keeps earned marks. The loot lock stays on weekNumber.
-- The schema field itself stays with T-040.
local function marksState(data)
	local weekKey = data.raidMarkWeek
	if data.raidMarksBank == nil then
		weekKey = -1
	end
	return {
		balance = data.raidMarks,
		weekKey = weekKey,
		earnedThisWeek = data.raidMarksEarned,
		bankedCap = data.raidMarksBank,
	}
end

local function resolved(data, claim: string): number
	remember(data, claim)
	return 0
end

-- The only Raid Marks grant. Idempotent per claim. Server numbers only.
function Raids.payMarks(data, request): number
	if type(data) ~= "table" or type(request) ~= "table" then
		return 0
	end
	if paidAsk(request) or request.practice == true then
		return 0
	end
	local claim = claimId(request.claim)
	if claim == nil or already(data, claim) then
		return 0
	end
	local timers = timerCount(request.firstTimers)
	if timers == nil then
		return resolved(data, claim)
	end
	local grant = RaidMarks.payout(request.difficulty, {
		firstTimers = timers,
		locked = request.locked,
		removal = request.removal,
		event = request.event,
	})
	if grant.ok ~= true then
		return resolved(data, claim)
	end
	local ledger = RaidMarks.earn(grant.amount, marksState(data), request.now)
	if ledger.ok ~= true then
		return 0
	end
	data.raidMarks = ledger.balance
	data.raidMarksEarned = ledger.earnedThisWeek
	data.raidMarkWeek = ledger.weekKey
	data.raidMarksBank = ledger.bankedCap
	remember(data, claim)
	return ledger.granted
end

-- One loot roll per boss per difficulty per week. Later clears still pay
-- Marks when the claim is new. A repeated claim pays nothing.
function Raids.applyClear(
	data,
	bossId: string,
	difficulty: string,
	now: number,
	roll: number,
	claim: any
): (number, boolean, boolean)
	local week = Raids.weekNumber(now)
	local locks = bag(data, "raidLock")
	local pity = bag(data, "raidPity")
	local key = bossId .. ":" .. difficulty
	local locked = locks[key] == week
	local paid = Raids.payMarks(data, {
		difficulty = difficulty,
		now = now,
		claim = claim,
		locked = locked,
	})
	local dropped = false
	if not locked then
		local chance = Raids.DROP_BASE + (pity[key] or 0) * Raids.DROP_STEP
		if chance > Raids.DROP_CAP then
			chance = Raids.DROP_CAP
		end
		local row = Raids.difficulty(difficulty) or Raids.DIFFICULTIES.story
		if roll < chance and type(data.chests) == "table" then
			dropped = true
			pity[key] = 0
			data.chests[row.loot] = (data.chests[row.loot] or 0) + 1
		else
			pity[key] = (pity[key] or 0) + 1
		end
		locks[key] = week
	end
	if difficulty == "story" then
		data.raidStory = true
	end
	return paid, dropped, locked
end

function Raids.buy(data, itemId: string): (boolean, string)
	local row = Raids.SHOP[itemId]
	if row == nil then
		return false, "The vendor does not sell that."
	end
	if (data.raidMarks or 0) < row.marks then
		return false, "Not enough Raid Marks."
	end
	data.raidMarks -= row.marks
	if row.chest ~= nil and type(data.chests) == "table" then
		data.chests[row.chest] = (data.chests[row.chest] or 0) + 1
	end
	if row.title ~= nil then
		data.milestoneTitle = row.title
	end
	return true, "Bought."
end

function Raids.tagOk(tag: any): boolean
	if type(tag) ~= "string" then
		return false
	end
	for _, name in ipairs(Raids.TAGS) do
		if name == tag then
			return true
		end
	end
	return false
end

return Raids
