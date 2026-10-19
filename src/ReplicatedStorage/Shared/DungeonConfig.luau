--!strict

--[[
	Dungeon tuning that is config, not logic. Phase 0.1 rebase of #364:
	only the spawn-clearance numbers live here. The old boss-HP scaling
	from #362 (room flow) was closed and is not carried over.
]]

local DungeonConfig = {}

-- Spawn clearance (Kevin's clip: Gnarl spawned clipped into a wall and a
-- slope). Spawns first clamp the footprint inside the floor with a margin,
-- then the server tests the built rig's bounding box against solid parts
-- and steps it toward the room centre until it is clear.
DungeonConfig.SPAWN_MARGIN = 3
DungeonConfig.SPAWN_STEP = 2
DungeonConfig.SPAWN_TRIES = 14
-- Bosses take this open spot (room-local studs) instead of a side pad.
DungeonConfig.BOSS_SPAWN = table.freeze({ x = 0, z = 8 })

-- Keeps a footprint (half sizes) at least SPAWN_MARGIN inside a square
-- floor of half width floorHalf centred on the room origin.
function DungeonConfig.insideFloor(x: number, z: number, halfX: number, halfZ: number, floorHalf: number): (number, number)
	local limitX = math.max(0, floorHalf - DungeonConfig.SPAWN_MARGIN - halfX)
	local limitZ = math.max(0, floorHalf - DungeonConfig.SPAWN_MARGIN - halfZ)
	return math.clamp(x, -limitX, limitX), math.clamp(z, -limitZ, limitZ)
end

-- One SPAWN_STEP toward the room centre (0, 0), never past it.
function DungeonConfig.stepInward(x: number, z: number): (number, number)
	local length = math.sqrt(x * x + z * z)
	if length <= DungeonConfig.SPAWN_STEP then
		return 0, 0
	end
	local scale = (length - DungeonConfig.SPAWN_STEP) / length
	return x * scale, z * scale
end

return table.freeze(DungeonConfig)
