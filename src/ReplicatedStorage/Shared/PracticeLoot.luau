--!strict

--[[
	Practice Grove pays nothing.

	RaidPractice is a normal remote. The death path, the room chest, and
	quest progress all ask pays() before they touch a profile. A client
	phase or hit-point ratio never changes the spawned boss.
]]

local ChestConfig = require("./ChestConfig")
local Drops = require("./Drops")
local Dungeons = require("./Dungeons")
local Loops = require("./Loops")
local Raids = require("./Raids")

local PracticeLoot = {}

export type KillContext = {
	practice: boolean,
	enemyKind: string,
	boss: boolean,
	dungeonId: string,
	difficulty: string,
	roomId: string,
	floorChest: string?,
	now: number,
	rng: any,
	roll: number,
}

function PracticeLoot.pays(practice: boolean): boolean
	return practice ~= true
end

function PracticeLoot.levelGate(level: any): (boolean, string?)
	local need = Raids.DIFFICULTIES.story.level
	local have = 1
	if type(level) == "number" and level == level then
		have = level
	end
	if have < need then
		return false, string.format("Level %d opens The Heartwood.", need)
	end
	return true, nil
end

function PracticeLoot.wing(requested: any, roomCount: number): number
	local count = 1
	if type(roomCount) == "number" and roomCount == roomCount and roomCount >= 1 then
		count = math.floor(roomCount)
	end
	if type(requested) ~= "number" or requested ~= requested then
		return 1
	end
	local wing = math.floor(requested)
	if wing < 1 then
		return 1
	end
	if wing > count then
		return count
	end
	return wing
end

-- The client may send a phase or a hit-point ratio. Both are discarded.
-- The second return is the HP ratio to apply, and nil means leave the spawn.
function PracticeLoot.openedPhase(_phase: any, _hp: any): (number, number?)
	return 1, nil
end

function PracticeLoot.noteQuest(data: any, practice: boolean, id: string, amount: number): number
	if not PracticeLoot.pays(practice) then
		return 0
	end
	return Loops.apply(data, id, amount)
end

function PracticeLoot.grantRoom(data: any, practice: boolean, now: number): boolean
	if not PracticeLoot.pays(practice) then
		return false
	end
	ChestConfig.grantSource(data, "room", now)
	return true
end

-- Materials, chests, Raid Marks, and the floor chest. Practice returns
-- empty tables and does not write the profile.
function PracticeLoot.applyKill(data: any, ctx: KillContext): ({ [string]: number }, { string })
	if not PracticeLoot.pays(ctx.practice) then
		return {}, {}
	end
	local landed = Drops.apply(data.materials, ctx.enemyKind, ctx.rng)
	local chestBits = {}
	local drop = ChestConfig.enemyDrop(data, ctx.enemyKind, ctx.rng)
	if drop ~= nil then
		table.insert(chestBits, drop.label)
	end
	if ctx.boss and ctx.dungeonId == Dungeons.HEARTWOOD_ID then
		local paid, dropped =
			Raids.applyClear(data, ctx.roomId, ctx.difficulty, ctx.now, ctx.roll)
		table.insert(chestBits, string.format("%d Raid Marks", paid))
		if dropped then
			table.insert(chestBits, "raid gear")
		end
	end
	if ctx.boss then
		for _, row in ipairs(ChestConfig.bossKill(data, ctx.now)) do
			table.insert(chestBits, row.label)
		end
		local floorTier = ctx.floorChest
		if floorTier == "Uncommon" or floorTier == "Rare" then
			data.chests[floorTier] = (data.chests[floorTier] or 0) + 1
			table.insert(chestBits, floorTier .. " chest")
		end
	end
	return landed, chestBits
end

return PracticeLoot
