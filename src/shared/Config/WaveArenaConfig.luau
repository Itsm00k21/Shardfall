--!strict

--[[
	Phase 3 wave arena numbers. Tuning edits this file, not the spawner.

	WaveArenaConfig.enabled is the second guard. The graybox does not build
	or start a round unless this is true AND LaunchGate.waveArena == true.
	Ghost owns LaunchGate and adds that field. A missing field stays off.

	Ids here are new. They are not Rootvault enemy ids.
]]

local WaveArenaConfig = {}

WaveArenaConfig.enabled = false

-- Roadmap floor. The shipped diameter is also checked against the biggest wave.
WaveArenaConfig.minDiameter = 120

WaveArenaConfig.arena = table.freeze({
	-- 140 leaves room past the 120-stud floor and past the 12-enemy spawn line.
	diameter = 140,
	wallHeight = 14,
	wallThickness = 4,
	floorThickness = 2,
	wallSegments = 48,
	-- Haven sits at the origin. The old crawl sits near z = 4000.
	-- This graybox is placed far from both, and it is not wired to either.
	origin = table.freeze({ x = 0, y = 240, z = 12000 }),
	floorColor = table.freeze({ 148, 148, 148 }),
	wallColor = table.freeze({ 96, 96, 96 }),
	gateColor = table.freeze({ 176, 112, 72 }),
	postColor = table.freeze({ 72, 72, 72 }),
	standColor = table.freeze({ 120, 132, 120 }),
})

-- Three enemy gates, equally spaced. The first faces +Z.
WaveArenaConfig.gates = table.freeze({
	count = 3,
	width = 18,
	facing = math.rad(90),
	postWidth = 2,
	postDepth = 3,
	-- How far a gate post pokes into the walkable disk.
	postInward = 1.5,
})

-- Spawn clearance, borrowed from the closed spawn-clearance pass (PR #364):
-- a margin inside the floor, a step toward the centre, and a try count.
WaveArenaConfig.spawn = table.freeze({
	margin = 3,
	step = 2,
	tries = 14,
	gap = 2,
	-- Bosses take this open spot instead of a gate pad. Arena-local studs.
	boss = table.freeze({ x = 0, z = 8 }),
})

WaveArenaConfig.chaser = table.freeze({
	id = "wave_chaser",
	size = table.freeze({ 3.2, 2.2, 4.2 }),
	moveSpeed = 11,
	arrive = 6,
})

WaveArenaConfig.add = table.freeze({
	id = "wave_add",
	size = table.freeze({ 3.2, 2.2, 4.2 }),
	moveSpeed = 11,
	arrive = 6,
})

-- Boss footprint matches the large rig the clearance pass was written for (8 x 9 x 7).
WaveArenaConfig.boss = table.freeze({
	id = "wave_boss",
	size = table.freeze({ 8, 9, 7 }),
	moveSpeed = 8,
	arrive = 8,
	adds = 4,
})

-- 6, 8, 10, 12, then a boss wave with 4 adds. The server reads this list and nothing else.
WaveArenaConfig.waves = table.freeze({
	table.freeze({ count = 6, kind = "chaser" }),
	table.freeze({ count = 8, kind = "chaser" }),
	table.freeze({ count = 10, kind = "chaser" }),
	table.freeze({ count = 12, kind = "chaser" }),
	table.freeze({ count = 1, kind = "boss", adds = 4 }),
})

WaveArenaConfig.path = table.freeze({
	tick = 0.1,
	stuckSeconds = 30,
})

function WaveArenaConfig.profile(config: any, kind: string): any
	if kind == "boss" then
		return config.boss
	end
	if kind == "add" then
		return config.add
	end
	return config.chaser
end

-- Half of the longer ground side. Clearance and pathing both use this circle.
function WaveArenaConfig.footprint(config: any, kind: string): number
	local size = WaveArenaConfig.profile(config, kind).size
	return math.max(size[1], size[3]) / 2
end

return table.freeze(WaveArenaConfig)
