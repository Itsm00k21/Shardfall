--!strict

--[[
	Brute Den playtest tune. Numbers only.

	The den is Rootvault room "den": one Root Brute and Thorn Sprites.
	It shipped with one sprite at 11 damage and no heal on clear, which
	left players on a sliver for Grandmother Gnarl. The server reads
	this module when that room is built and when it clears.

	No flag. schemaVersion stays 26. Nothing here is saved, and nothing
	costs Robux.
]]

local BruteDen = {}

BruteDen.DUNGEON_ID = "rootvault"
BruteDen.ROOM_ID = "den"
BruteDen.BRUTE_KIND = "root_brute"
BruteDen.THORN_KIND = "thorn_sprite"

-- The den already fielded one sprite. A second is not a light trim.
BruteDen.THORN_COUNT = 1
-- Was 11. Eight still chips a 100 HP bar, and it takes more clean hits
-- to delete it (10 hits at 11, 13 at 8).
BruteDen.THORN_DAMAGE = 8

-- Share of the unbuffed loadout max restored when the den clears.
-- The Healing Spring door is 30%. This stays under that.
BruteDen.CLEAR_HEAL = 0.2

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function whole(value: any): boolean
	return finite(value) and value >= 0 and math.floor(value) == value
end

-- Den lineup. The brute is always first. Thorn sprites follow, THORN_COUNT of them.
function BruteDen.enemies(): { string }
	local lineup: { string } = { BruteDen.BRUTE_KIND }
	local count = BruteDen.THORN_COUNT
	if not whole(count) then
		return lineup
	end
	for _index = 1, count do
		table.insert(lineup, BruteDen.THORN_KIND)
	end
	return lineup
end

-- True only for the Brute Den inside Rootvault. Other rooms and dungeons do not heal.
function BruteDen.applies(dungeonId: any, roomId: any): boolean
	return dungeonId == BruteDen.DUNGEON_ID and roomId == BruteDen.ROOM_ID
end

-- HP restored from an unbuffed max. Non-positive and non-finite maxes heal 0.
-- A positive max heals at least 1, matching the spring's floor.
function BruteDen.clearHeal(baseMax: any): number
	if not finite(baseMax) or baseMax <= 0 then
		return 0
	end
	local amount = math.floor(baseMax * BruteDen.CLEAR_HEAL)
	if amount < 1 then
		return 1
	end
	return amount
end

-- Bounds for the tune. Damage stays under the old 11 and at least 6.
-- Count stays a single sprite. The heal stays a real fraction under the spring's 30%.
function BruteDen.validate(config: any): (boolean, string?)
	if type(config) ~= "table" then
		return false, "config"
	end
	if config.DUNGEON_ID ~= "rootvault" then
		return false, "DUNGEON_ID"
	end
	if config.ROOM_ID ~= "den" then
		return false, "ROOM_ID"
	end
	if config.BRUTE_KIND ~= "root_brute" then
		return false, "BRUTE_KIND"
	end
	if config.THORN_KIND ~= "thorn_sprite" then
		return false, "THORN_KIND"
	end
	if not whole(config.THORN_COUNT) or config.THORN_COUNT > 1 then
		return false, "THORN_COUNT"
	end
	if not whole(config.THORN_DAMAGE) or config.THORN_DAMAGE >= 11 or config.THORN_DAMAGE < 6 then
		return false, "THORN_DAMAGE"
	end
	if not finite(config.CLEAR_HEAL) or config.CLEAR_HEAL < 0.1 or config.CLEAR_HEAL >= 0.3 then
		return false, "CLEAR_HEAL"
	end
	return true, nil
end

return table.freeze(BruteDen)
