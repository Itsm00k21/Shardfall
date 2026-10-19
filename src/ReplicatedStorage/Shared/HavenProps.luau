--!strict
--[[
	Where the crystal props stand on the Boss Plaza. Pure data, so the
	spec can keep them off the spawn, the stations, and the bridge lanes.
	x/z are plaza coordinates. height is the prop's target height in studs.
	The server grounds each one with a downward ray.
]]

export type Spot = {
	kind: string,
	x: number,
	z: number,
	height: number,
	yaw: number,
}

local HavenProps = {}

local SPOTS: { Spot } = {
	{ kind = "CrystalSpire", x = 32, z = 32, height = 10, yaw = 20 },
	{ kind = "CrystalCluster", x = 45, z = -2, height = 7, yaw = 140 },
	{ kind = "CrystalPair", x = 0, z = -46, height = 7.5, yaw = 0 },
	{ kind = "CrystalBed", x = -23, z = -39, height = 3.5, yaw = 60 },
	{ kind = "CrystalCluster", x = -42, z = -15, height = 6, yaw = 250 },
	{ kind = "CrystalBed", x = -26, z = 37, height = 3, yaw = 10 },
}
for _, spot in ipairs(SPOTS) do
	table.freeze(spot)
end
HavenProps.SPOTS = table.freeze(SPOTS)

-- The Quick Travel portal stands west of the spawn pad, facing it.
-- Its prompt carries HavenAction "travel", which opens the Travel panel.
HavenProps.PORTAL = table.freeze({ kind = "CrystalPortal", x = -15, z = 27, height = 11, yaw = -90 } :: Spot)

-- Uniform scale that makes a mesh of this size the target height.
function HavenProps.scaleFor(size: { X: number, Y: number, Z: number }, height: number): number
	if size.Y <= 0 then
		return 1
	end
	return height / size.Y
end

return HavenProps
