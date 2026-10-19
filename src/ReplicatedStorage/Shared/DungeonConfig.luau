--!strict

--[[
	Dungeon tunables in one place (Kevin's Oct 19 playtest fixes, and the
	Rootvault Trial numbers as they land). Pure data plus tiny helpers.
	Nothing here costs Robux.
]]

local DungeonConfig = {}

-- Rootvault crawl: after the last enemy in a room dies, the banner counts
-- down this many seconds, then the first open door is taken for the
-- player (the same teleport a door click uses). Clicking a door sooner
-- still works.
DungeonConfig.ROOM_CLEAR_SECONDS = 3

function DungeonConfig.roomClearText(seconds: number?): string
	return string.format("Room clear. Next room in %ds.", seconds or DungeonConfig.ROOM_CLEAR_SECONDS)
end

-- Doors the countdown never takes for the player (they spend currency).
DungeonConfig.AUTO_DOOR_SKIP = table.freeze({ shop = true })

-- The door the countdown takes: the first open door that costs nothing.
function DungeonConfig.autoDoor(offer: any): string?
	if type(offer) ~= "table" then
		return nil
	end
	for _, door in ipairs(offer) do
		if type(door) == "table" and type(door.id) == "string" and DungeonConfig.AUTO_DOOR_SKIP[door.id] ~= true then
			return door.id
		end
	end
	return nil
end

return table.freeze(DungeonConfig)
