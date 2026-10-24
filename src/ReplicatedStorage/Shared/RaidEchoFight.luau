--!strict

--[[
	Party bookkeeping for Story Echo.

	DungeonService owns the players. This module owns when a wipe counts,
	when stacks clear, and the unbuffed numbers passed to RaidEcho.apply.
	It does not grant loot, read DataStores, or touch remotes.
]]

local RaidEcho = require("./RaidEcho")

local RaidEchoFight = {}

export type StatKind = "damage" | "healing" | "maxHp"

export type Member = {
	alive: boolean,
}

export type StatBase = {
	damage: number?,
	healing: number?,
	maxHp: number?,
}

export type Fight = {
	state: RaidEcho.State,
	difficulty: string,
	practice: boolean,
	pullStarted: boolean,
	bossId: string,
	-- True after this death has already been offered to wipe, until
	-- someone is alive again. A second call does not add a stack.
	latched: boolean,
	members: { [string]: Member },
	bases: { [string]: StatBase },
}

local function blankBase(): StatBase
	return {}
end

function RaidEchoFight.open(difficulty: string, practice: boolean, userId: string): Fight
	local fight: Fight = {
		state = RaidEcho.fresh(),
		difficulty = difficulty,
		practice = practice == true,
		pullStarted = false,
		bossId = "",
		latched = false,
		members = {},
		bases = {},
	}
	fight.members[userId] = { alive = true }
	fight.bases[userId] = blankBase()
	return fight
end

function RaidEchoFight.setPractice(fight: Fight, practice: boolean)
	fight.practice = practice == true
end

-- Living players, then the party size. Enemies are not part of this count.
function RaidEchoFight.counts(fight: Fight): (number, number)
	local living = 0
	local party = 0
	for _, member in pairs(fight.members) do
		party += 1
		if member.alive == true then
			living += 1
		end
	end
	return living, party
end

-- The boss is in the room. Stacks stay. A changed boss id does not clear them.
function RaidEchoFight.notePull(fight: Fight, bossId: string)
	fight.pullStarted = true
	if type(bossId) == "string" and bossId ~= "" then
		fight.bossId = bossId
	end
end

local function scale(fight: Fight, kind: StatKind, base: number): number
	if fight.practice == true then
		return base
	end
	local applied = RaidEcho.apply({
		kind = kind,
		value = base,
	}, fight.state, fight.difficulty)
	if applied.ok ~= true then
		return base
	end
	if kind == "maxHp" then
		return math.floor(applied.value)
	end
	return math.floor(applied.value + 0.5)
end

-- Remember the unbuffed base, then scale that base. The stored number is
-- the caller's base, never the scaled result, so a later wipe cannot compound.
function RaidEchoFight.applyBase(fight: Fight, userId: string, kind: StatKind, base: number): number
	local row = fight.bases[userId]
	if row == nil then
		row = blankBase()
		fight.bases[userId] = row
	end
	row[kind] = base
	return scale(fight, kind, base)
end

-- Scale the stored base again. Used after a wipe or a reset.
function RaidEchoFight.reapply(fight: Fight, userId: string, kind: StatKind): number?
	local row = fight.bases[userId]
	if row == nil then
		return nil
	end
	local base = row[kind]
	if type(base) ~= "number" then
		return nil
	end
	return scale(fight, kind, base)
end

-- One wipe for a whole-party death. A partial death and a repeat call
-- while everyone is still down return nil and leave the stacks alone.
function RaidEchoFight.setAlive(fight: Fight, userId: string, alive: boolean): RaidEcho.WipeResult?
	local member = fight.members[userId]
	if member == nil then
		fight.members[userId] = { alive = alive }
		if fight.bases[userId] == nil then
			fight.bases[userId] = blankBase()
		end
	else
		member.alive = alive
	end
	local living, party = RaidEchoFight.counts(fight)
	if living > 0 then
		fight.latched = false
		return nil
	end
	if party < 1 or fight.latched then
		return nil
	end
	fight.latched = true
	local result = RaidEcho.wipe(fight.state, {
		difficulty = fight.difficulty,
		practice = fight.practice,
		pullStarted = fight.pullStarted,
		alive = living,
		party = party,
	})
	if result.ok == true then
		fight.state = result.state
	end
	return result
end

-- Drop a player who left. The remaining party keeps the stacks.
function RaidEchoFight.depart(fight: Fight, userId: string)
	fight.members[userId] = nil
	local living = RaidEchoFight.counts(fight)
	if living > 0 then
		fight.latched = false
	end
end

-- Same state table. The joiner reads the party's stacks.
function RaidEchoFight.backfill(fight: Fight, userId: string): Fight
	if fight.members[userId] == nil then
		fight.members[userId] = { alive = true }
	else
		fight.members[userId].alive = true
	end
	if fight.bases[userId] == nil then
		fight.bases[userId] = blankBase()
	end
	local living = RaidEchoFight.counts(fight)
	if living > 0 then
		fight.latched = false
	end
	return fight
end

function RaidEchoFight.bossKill(fight: Fight): RaidEcho.ResetResult
	local result = RaidEcho.reset(fight.state, "kill")
	if result.ok == true then
		fight.state = result.state
	end
	fight.pullStarted = false
	fight.latched = false
	fight.bossId = ""
	return result
end

function RaidEchoFight.runEnd(fight: Fight): RaidEcho.ResetResult
	local result = RaidEcho.reset(fight.state, "end")
	if result.ok == true then
		fight.state = result.state
	end
	fight.pullStarted = false
	fight.latched = false
	fight.bossId = ""
	return result
end

-- Hidden at 0. The percent comes from RaidEcho.bonus, not a hardcoded step.
function RaidEchoFight.chip(state: any, difficulty: any): string?
	local view = RaidEcho.bonus(state, difficulty)
	if view.ok ~= true or view.active ~= true or view.bonus <= 0 then
		return nil
	end
	local pct = math.floor(view.bonus * 100 + 0.5)
	if pct <= 0 then
		return nil
	end
	return string.format("Echo +%d%%", pct)
end

return RaidEchoFight
