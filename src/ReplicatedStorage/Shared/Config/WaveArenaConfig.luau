--!strict

--[[
	Phase 3 wave arena numbers. Tuning edits this file, not the spawner.

	WaveArenaConfig.enabled is the second guard. Nothing builds, drops, or
	draws unless this is true AND LaunchGate.waveArena is true. Both ship
	off. A run keeps every earned drop once. The host writes that through
	the existing profile only after the server settles the run.

	Ids here are new. They are not Rootvault enemy ids. Enemy types 1, 2,
	and 3 are chaser, ranged, and tank. The boss is the wave-5 finale.
]]

local WaveArenaConfig = {}

WaveArenaConfig.enabled = false

-- Kevin-approved floor (Ghost, Oct 24). The shipped diameter is also
-- checked against the biggest wave.
WaveArenaConfig.minDiameter = 90

-- A run that is still going ends on its own after this many seconds.
-- Disconnect, wipe, and this timeout are the only exits.
WaveArenaConfig.timeout = 480

-- How many run ids a profile remembers. One id per run, not one key per
-- drop. Older ids fall off. Purchase receipts live in a different table.
WaveArenaConfig.settleKeep = 50

WaveArenaConfig.arena = table.freeze({
	-- 90 studs across. Three edge gates sit on the rim.
	diameter = 90,
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

-- Three edge gates, equally spaced on the rim. The first faces +Z.
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

-- Type 1. Melee chaser. Footprint stays the graybox size so clearance holds.
WaveArenaConfig.chaser = table.freeze({
	id = "wave_chaser",
	size = table.freeze({ 3.2, 2.2, 4.2 }),
	moveSpeed = 11,
	arrive = 6,
	hp = 36,
	damage = 8,
	attackRange = 6,
	attackInterval = 1.4,
	windup = 0.5,
	opening = 0.4,
	color = table.freeze({ 176, 96, 72 }),
})

-- Type 2. Stays at range and shoots after a telegraph.
WaveArenaConfig.ranged = table.freeze({
	id = "wave_ranged",
	size = table.freeze({ 3.2, 2.2, 4.2 }),
	moveSpeed = 8,
	arrive = 6,
	hp = 28,
	damage = 7,
	attackRange = 22,
	prefer = 16,
	attackInterval = 2.2,
	windup = 0.8,
	opening = 0.6,
	color = table.freeze({ 96, 140, 176 }),
})

-- Type 3. Slow, bulky, short red slam.
WaveArenaConfig.tank = table.freeze({
	id = "wave_tank",
	size = table.freeze({ 3.2, 2.2, 4.2 }),
	moveSpeed = 6,
	arrive = 6,
	hp = 90,
	damage = 12,
	attackRange = 7,
	attackRadius = 7,
	attackInterval = 2.4,
	windup = 0.8,
	opening = 0.8,
	color = table.freeze({ 120, 108, 88 }),
})

-- Boss adds use the chaser's numbers and the add id.
WaveArenaConfig.add = table.freeze({
	id = "wave_add",
	size = table.freeze({ 3.2, 2.2, 4.2 }),
	moveSpeed = 11,
	arrive = 6,
	hp = 36,
	damage = 8,
	attackRange = 6,
	attackInterval = 1.4,
	windup = 0.5,
	opening = 0.4,
	color = table.freeze({ 176, 96, 72 }),
})

-- Boss footprint matches the large rig the clearance pass was written for (8 x 9 x 7).
-- windup is the red warning. Damage lands only after it, inside attackRadius.
-- deathHold is the pause before the results card.
WaveArenaConfig.boss = table.freeze({
	id = "wave_boss",
	size = table.freeze({ 8, 9, 7 }),
	moveSpeed = 8,
	arrive = 8,
	adds = 4,
	hp = 480,
	damage = 22,
	attackRange = 14,
	attackRadius = 8,
	attackInterval = 3.2,
	windup = 1.8,
	opening = 0.8,
	deathHold = 1.5,
	color = table.freeze({ 92, 48, 40 }),
})

WaveArenaConfig.types = table.freeze({
	chaser = 1,
	ranged = 2,
	tank = 3,
})

-- Per-wave mix. Wave 1 is only type 1. Later waves bring in types 2 and 3.
-- The graybox roster stays kind "chaser" so the 12-body clearance test is unchanged.
WaveArenaConfig.mix = table.freeze({
	table.freeze({ "chaser" }),
	table.freeze({ "chaser", "chaser", "ranged" }),
	table.freeze({ "chaser", "ranged", "tank" }),
	table.freeze({ "chaser", "ranged", "tank", "tank" }),
})

-- Graybox player. A live run can pass a server hero snapshot as options.stats.
-- A client tick cannot set damage or hp.
WaveArenaConfig.player = table.freeze({
	hp = 200,
	damage = 12,
	range = 8,
	interval = 0.45,
	speed = 16,
	radius = 2,
	start = table.freeze({ x = 0, z = -18 }),
})

-- Chips sit on the ground. Wave tokens match the economy sheet.
-- bagSlots is how many chips fit in the Bag. The rest are held for this
-- session only, up to overflowCap, then salvaged into Essence at run end.
-- rarity uses the normal salvage table. Nothing here is written as a new save field.
WaveArenaConfig.loot = table.freeze({
	pickupRadius = 12,
	bagSlots = 100,
	overflowCap = 40,
	drops = table.freeze({
		chaser = table.freeze({ id = "shard_chip", fragments = 1, tokens = 0, rarity = "Common" }),
		ranged = table.freeze({ id = "shard_chip", fragments = 1, tokens = 0, rarity = "Common" }),
		tank = table.freeze({ id = "shard_chip", fragments = 2, tokens = 0, rarity = "Common" }),
		add = table.freeze({ id = "shard_chip", fragments = 1, tokens = 0, rarity = "Common" }),
		boss = table.freeze({ id = "boss_core", fragments = 4, tokens = 0, rarity = "Common" }),
	}),
	waveTokens = table.freeze({ 1, 1, 2, 2, 5 }),
})

WaveArenaConfig.feel = table.freeze({
	hitFlash = 0.08,
	deathPuff = 0.45,
	flashColor = table.freeze({ 255, 255, 255 }),
	puffColor = table.freeze({ 210, 206, 196 }),
})

-- An enemy that has not moved `epsilon` studs within `seconds` is
-- teleported toward the centre, or removed if that spot is no better.
WaveArenaConfig.stuck = table.freeze({
	seconds = 30,
	epsilon = 0.75,
	teleportStuds = 16,
	minShift = 4,
})

-- Camera room: a gap around the boss body. Eyes inside it get pushed out
-- so the camera does not sit in the mesh.
WaveArenaConfig.camera = table.freeze({
	roomPad = 6,
	minEyeGap = 3,
})

-- Haven spawn is (0, 124, 30) on the plaza floor at y = 120.
-- The pad sits inside the plaza disc (radius 52) at (14, 120.5, 44).
-- (16, 120.5, 46) left a corner of the 8-stud pad outside that disc.
-- The old lane spot (0, 120.5, 46) overlapped the Training Grove post
-- at (-16, 48.2), reach 8. This spot stays clear of that post.
-- The pad is not built while the arena is gated.
WaveArenaConfig.hubPad = table.freeze({
	position = table.freeze({ x = 14, y = 120.5, z = 44 }),
	size = table.freeze({ 8, 1, 8 }),
	color = table.freeze({ 186, 140, 72 }),
	prompt = "Shard Gate",
	actionText = "Enter",
})

-- M12 results and Run Again. The server reads these numbers.
-- Nothing here is a save field. Best wave stays in session memory.
WaveArenaConfig.results = table.freeze({
	autoReturn = 30,
	soloCountdown = 3,
	runAgainGap = 1,
	frameMs = 50,
	hardLevel = 5,
	lootNames = table.freeze({
		shard_chip = "Shard Chip",
		boss_core = "Boss Core",
	}),
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

-- Core Loop Hard for this arena. Normal stats stay the base. The fight
-- and the purse read this row. It matches Economy.DIFFICULTIES.hard:
-- 2× HP, 1.5× damage, 2× tokens, 2× fragments.
-- clearHeal is the den-clear heal (CLEAR_HEAL) for this row: 10% of max HP
-- when a non-boss wave empties. Other tiers keep the heal they already
-- had. The server reads it only while HardMode.isHardReal() is true.
-- Nothing here is paid.
WaveArenaConfig.hard = table.freeze({
	hpMultiplier = 2,
	damageMultiplier = 1.5,
	tokenMultiplier = 2,
	fragmentMultiplier = 2,
	clearHeal = 0.1,
})

local HARD_BANNED = { robux = true, productId = true, cost = true, skip = true, price = true }

-- The arena Hard row. Pass a table to test a broken copy; nil checks this module.
function WaveArenaConfig.validate(source: any?): (boolean, string)
	local data = if source == nil then WaveArenaConfig else source
	if type(data) ~= "table" then
		return false, "arena config is missing"
	end
	local hard = data.hard
	if type(hard) ~= "table" then
		return false, "hard multipliers are missing"
	end
	for key in pairs(hard) do
		if HARD_BANNED[key] == true then
			return false, "hard must not carry a price"
		end
	end
	if hard.hpMultiplier ~= 2 then
		return false, "hard HP is 2×"
	end
	if hard.damageMultiplier ~= 1.5 then
		return false, "hard damage is 1.5×"
	end
	if hard.tokenMultiplier ~= 2 then
		return false, "hard tokens are 2×"
	end
	if hard.fragmentMultiplier ~= 2 then
		return false, "hard fragments are 2×"
	end
	if hard.clearHeal ~= 0.1 then
		return false, "hard clear heal is 10%"
	end
	return true, ""
end

function WaveArenaConfig.profile(config: any, kind: string): any
	if kind == "boss" then
		return config.boss
	end
	if kind == "add" then
		return config.add
	end
	if kind == "ranged" then
		return config.ranged
	end
	if kind == "tank" then
		return config.tank
	end
	return config.chaser
end

-- Half of the longer ground side. Clearance and pathing both use this circle.
function WaveArenaConfig.footprint(config: any, kind: string): number
	local size = WaveArenaConfig.profile(config, kind).size
	return math.max(size[1], size[3]) / 2
end

return table.freeze(WaveArenaConfig)
