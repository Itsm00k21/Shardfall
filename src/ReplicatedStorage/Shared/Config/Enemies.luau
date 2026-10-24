--!strict

--[[
	V1 enemy types (roadmap 3.3, 3.4), the wave-5 boss (3.6),
	and the stuck-enemy clock (3.8).

	Every tunable lives here, including the arena a ranged enemy kites
	inside and the shot ray. EnemyRoster, WaveFlow, and the server
	services read this file. Dungeons.ENEMIES copies the combat fields
	so Config.Enemies (the index alias) carries the same ids. Tuning
	means editing this module, not the stepper.

	LaunchGate.SHOW.enemyTypes stays false. Live rooms and
	Dungeons.waveKinds do not spawn these ids. Waves and the boss are
	read only by WaveFlow, which no-ops while the flag is off.
	No Robux. No profile fields.

	The wave-5 boss cannot be kited for free. Pressure arms after
	PRESSURE_SECONDS with no damage dealt to its target, and a damaging
	tick shaves PRESSURE_DECAY off that timer instead of clearing it.
	Outside melee, an armed boss fires Shard Volley: a windup, then
	VOLLEY_SHOTS led shots, then VOLLEY_COOLDOWN. The leash slam dashes
	to its mark. The boss is clamped to ARENA and never regens.
]]

local Enemies = {}

export type Style = "melee" | "projectile"

export type Row = {
	id: string,
	name: string,
	role: string,
	maxHealth: number,
	damage: number,
	defense: number,
	attackSpeed: number,
	moveSpeed: number,
	range: number,
	stop: number,
	retreat: number,
	projectileSpeed: number,
	damageTaken: number,
	style: Style,
	minDot: number,
	color: { number },
	size: { number },
}

-- Shared filler for the older EnemyDef shape. These three are not bosses.
Enemies.SHARED = table.freeze({
	hover = 0,
	boss = false,
	phase2At = 0,
	weakSeconds = 0,
	armoredMultiplier = 1,
	fogInterval = 0,
	fogDamage = 0,
	safeRadius = 0,
})

-- A hitch longer than this is cut down so one frame cannot cross the arena.
Enemies.STEP_MAX = 0.5

-- Gray-box preview spacing. The service does not parent parts itself.
Enemies.PREVIEW_GAP = 8
Enemies.PREVIEW_LIFT = 6

-- Square floor. A ranged kite stops on this edge instead of leaving.
-- 90 studs across sits in the locked 80–100 span, centered on the origin.
Enemies.ARENA = table.freeze({
	minX = -45,
	maxX = 45,
	minZ = -45,
	maxZ = 45,
})

-- Horizontal shot ray. High enough to clear the floor, under the walls.
-- LOS_PAD pulls the ray off the shooter and the target so neither is cover.
-- SHOT_RADIUS is how close the projectile path must pass to the target's
-- current position. The aim point from the firing tick is not a hit.
Enemies.SHOT_Y = 3
Enemies.LOS_PAD = 1.5
Enemies.SHOT_RADIUS = 2

-- Wave-5 boss leash. Staying farther than LEASH_RANGE for LEASH_SECONDS
-- starts a slam. LEASH_WINDUP is the telegraph. LEASH_RADIUS is the mark
-- the player can step out of. LEASH_DASH is how fast the boss closes on
-- that mark during the windup. The boss does not heal when this fires.
Enemies.LEASH_RANGE = 24
Enemies.LEASH_SECONDS = 3
Enemies.LEASH_WINDUP = 1.2
Enemies.LEASH_RADIUS = 4
Enemies.LEASH_DASH = 40

-- No damage dealt to the target fills this timer. It arms at
-- PRESSURE_SECONDS. A tick that deals damage subtracts PRESSURE_DECAY
-- and does not snap the timer back to zero.
Enemies.PRESSURE_SECONDS = 4
Enemies.PRESSURE_DECAY = 1.5

-- Shard Volley. Outside melee, once pressure is armed: windup, then
-- VOLLEY_SHOTS shots that lead the target, then the cooldown. Spread is
-- radians around the lead. LEAD_MAX caps a wild velocity spike.
Enemies.VOLLEY_NAME = "Shard Volley"
Enemies.VOLLEY_WINDUP = 0.8
Enemies.VOLLEY_SHOTS = 3
Enemies.VOLLEY_COOLDOWN = 5
Enemies.VOLLEY_SPEED = 64
Enemies.VOLLEY_SPREAD = 0.12
Enemies.VOLLEY_LEAD_MAX = 24

Enemies.ORDER = table.freeze({ "chaser", "ranged", "tank" })

Enemies.TYPES = table.freeze({
	chaser = table.freeze({
		id = "chaser",
		name = "Chaser",
		role = "chaser",
		maxHealth = 42,
		damage = 8,
		defense = 1,
		attackSpeed = 0.9,
		moveSpeed = 14,
		range = 5,
		stop = 4,
		retreat = 0,
		projectileSpeed = 0,
		damageTaken = 1,
		style = "melee" :: Style,
		minDot = 0.15,
		color = table.freeze({ 168, 168, 168 }),
		size = table.freeze({ 2.6, 3.4, 2.6 }),
	}),
	ranged = table.freeze({
		id = "ranged",
		name = "Ranged",
		role = "ranged",
		maxHealth = 26,
		damage = 7,
		defense = 0,
		attackSpeed = 0.65,
		moveSpeed = 10,
		range = 28,
		stop = 20,
		retreat = 12,
		projectileSpeed = 42,
		damageTaken = 1,
		style = "projectile" :: Style,
		minDot = -1,
		color = table.freeze({ 176, 186, 196 }),
		size = table.freeze({ 2, 2.8, 2 }),
	}),
	tank = table.freeze({
		id = "tank",
		name = "Tank",
		role = "tank",
		maxHealth = 130,
		damage = 14,
		defense = 8,
		attackSpeed = 0.4,
		moveSpeed = 6,
		range = 6,
		stop = 5,
		retreat = 0,
		projectileSpeed = 0,
		damageTaken = 0.5,
		style = "melee" :: Style,
		minDot = 0.2,
		color = table.freeze({ 96, 96, 100 }),
		size = table.freeze({ 4.8, 5.4, 4.4 }),
	}),
})

-- Roadmap 3.5. Four trash waves, then the boss wave. Each mix uses
-- chaser, ranged, and tank, and those three counts add up to the wave
-- size. Spawn order is WAVE_ORDER. The live crawl does not read this list.
Enemies.WAVE_COUNTS = table.freeze({ 6, 8, 10, 12 })
Enemies.WAVE_ORDER = table.freeze({ "chaser", "ranged", "tank" })
Enemies.WAVE_MIXES = table.freeze({
	table.freeze({ chaser = 4, ranged = 1, tank = 1 }),
	table.freeze({ chaser = 4, ranged = 2, tank = 2 }),
	table.freeze({ chaser = 5, ranged = 3, tank = 2 }),
	table.freeze({ chaser = 6, ranged = 4, tank = 2 }),
})
-- Gray-box spacing for one wave. The service does not parent parts.
Enemies.WAVE_GAP = 6
Enemies.WAVE_LIFT = 3

-- Roadmap 3.6. Wave 5 is this boss plus BOSS_ADDS. Adds are only the
-- three V1 types, in WAVE_ORDER. The live crawl still uses Gnarl.
Enemies.BOSS_WAVE = 5
Enemies.BOSS_ADDS = 4
Enemies.BOSS_ADD_MIX = table.freeze({
	chaser = 2,
	ranged = 1,
	tank = 1,
})
Enemies.BOSS = table.freeze({
	id = "boss",
	name = "Boss",
	role = "boss",
	maxHealth = 420,
	damage = 22,
	defense = 12,
	attackSpeed = 0.3,
	moveSpeed = 5,
	range = 9,
	stop = 7,
	retreat = 0,
	projectileSpeed = 0,
	damageTaken = 1,
	style = "melee" :: Style,
	minDot = -1,
	-- Catalog bosses need a phase threshold above 0. The gated flow
	-- does not run that phase; it only spawns the block and applies hits.
	phase2At = 0.5,
	color = table.freeze({ 58, 58, 62 }),
	size = table.freeze({ 7.5, 9, 7 }),
})

-- Roadmap 3.8. An enemy with no meaningful progress toward its target
-- and no damage for this long is stuck. validate rejects a wait above 30.
Enemies.STUCK_SECONDS = 30
-- Closing this many studs counts as progress. Damage does too.
Enemies.STUCK_PROGRESS = 0.5
-- First recovery: step this far off the blocked line and aim again.
Enemies.STUCK_NUDGE = 8
-- A respawn point keeps this much air between the body, obstacles, and
-- the other living enemies. The point stays inside ARENA.
Enemies.SPAWN_CLEAR = 3

local REQUIRED = { "chaser", "ranged", "tank" }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function checkNumber(where: string, value: any, minimum: number): (boolean, string)
	if not finite(value) then
		return false, where .. " must be a finite number"
	end
	if value < minimum then
		return false, where .. " is below " .. tostring(minimum)
	end
	return true, ""
end

local function checkBound(where: string, value: any): (boolean, string)
	if not finite(value) then
		return false, where .. " must be a finite number"
	end
	return true, ""
end

-- The floor is a centered square, 80 to 100 studs across. The shot ray
-- stays above the floor and off both bodies.
local function checkArena(source: any): (boolean, string)
	local box = source.ARENA
	if type(box) ~= "table" then
		return false, "ARENA is missing"
	end
	for _, field in ipairs({ "minX", "maxX", "minZ", "maxZ" }) do
		local ok, err = checkBound("ARENA." .. field, box[field])
		if not ok then
			return false, err
		end
	end
	if box.minX >= box.maxX or box.minZ >= box.maxZ then
		return false, "ARENA min must be below max"
	end
	local spanX = box.maxX - box.minX
	local spanZ = box.maxZ - box.minZ
	if spanX < 80 or spanX > 100 or spanZ < 80 or spanZ > 100 then
		return false, "ARENA must span 80 to 100 studs"
	end
	if box.minX ~= -box.maxX or box.minZ ~= -box.maxZ or spanX ~= spanZ then
		return false, "ARENA must be a centered square"
	end
	local yOk, yErr = checkNumber("SHOT_Y", source.SHOT_Y, 0.5)
	if not yOk then
		return false, yErr
	end
	if source.SHOT_Y > 12 then
		return false, "SHOT_Y is above 12"
	end
	local padOk, padErr = checkNumber("LOS_PAD", source.LOS_PAD, 0.05)
	if not padOk then
		return false, padErr
	end
	if source.LOS_PAD > 4 then
		return false, "LOS_PAD is above 4"
	end
	local hitOk, hitErr = checkNumber("SHOT_RADIUS", source.SHOT_RADIUS, 0.5)
	if not hitOk then
		return false, hitErr
	end
	if source.SHOT_RADIUS > 4 then
		return false, "SHOT_RADIUS is above 4"
	end
	return true, ""
end

local function checkRow(id: string, row: any): (boolean, string)
	if type(row) ~= "table" then
		return false, id .. " is missing"
	end
	if row.id ~= id or row.role ~= id then
		return false, id .. " id and role must match the key"
	end
	if type(row.name) ~= "string" or row.name == "" then
		return false, id .. " needs a name"
	end
	local numbers = {
		{ "maxHealth", row.maxHealth, 1 },
		{ "damage", row.damage, 1 },
		{ "defense", row.defense, 0 },
		{ "attackSpeed", row.attackSpeed, 0.05 },
		{ "moveSpeed", row.moveSpeed, 0.05 },
		{ "range", row.range, 0.05 },
		{ "stop", row.stop, 0 },
		{ "retreat", row.retreat, 0 },
		{ "projectileSpeed", row.projectileSpeed, 0 },
		{ "damageTaken", row.damageTaken, 0.05 },
	}
	for _, spec in ipairs(numbers) do
		local field = spec[1] :: string
		local minimum = spec[3] :: number
		local ok, err = checkNumber(id .. "." .. field, spec[2], minimum)
		if not ok then
			return false, err
		end
	end
	if row.damageTaken > 1 then
		return false, id .. ".damageTaken is above 1"
	end
	if row.stop > row.range then
		return false, id .. " stops farther than it can hit"
	end
	if not finite(row.minDot) or row.minDot < -1 or row.minDot > 1 then
		return false, id .. ".minDot must be from -1 to 1"
	end
	if row.style ~= "melee" and row.style ~= "projectile" then
		return false, id .. " style must be melee or projectile"
	end
	if row.style == "projectile" and row.projectileSpeed <= 0 then
		return false, id .. " projectile needs a speed"
	end
	if row.style == "melee" and row.projectileSpeed ~= 0 then
		return false, id .. " melee does not fire a shot"
	end
	if type(row.color) ~= "table" or #row.color ~= 3 then
		return false, id .. " color needs three channels"
	end
	for index, channel in ipairs(row.color) do
		local ok, err = checkNumber(id .. ".color[" .. index .. "]", channel, 0)
		if not ok then
			return false, err
		end
		if channel > 255 then
			return false, id .. " color channel is above 255"
		end
	end
	if type(row.size) ~= "table" or #row.size ~= 3 then
		return false, id .. " size needs three axes"
	end
	for index, axis in ipairs(row.size) do
		local ok, err = checkNumber(id .. ".size[" .. index .. "]", axis, 0.05)
		if not ok then
			return false, err
		end
	end
	return true, ""
end

local EXPECTED_COUNTS = { 6, 8, 10, 12 }

local function keyCount(map: any): number
	local total = 0
	for _ in pairs(map) do
		total += 1
	end
	return total
end

local function checkWaves(source: any): (boolean, string)
	local counts = source.WAVE_COUNTS
	if type(counts) ~= "table" or keyCount(counts) ~= #EXPECTED_COUNTS then
		return false, "WAVE_COUNTS must be 6, 8, 10, 12"
	end
	for index, expected in ipairs(EXPECTED_COUNTS) do
		if counts[index] ~= expected then
			return false, "WAVE_COUNTS must be 6, 8, 10, 12"
		end
	end
	local order = source.WAVE_ORDER
	if type(order) ~= "table" or keyCount(order) ~= #REQUIRED then
		return false, "WAVE_ORDER must be chaser, ranged, tank"
	end
	for index, id in ipairs(REQUIRED) do
		if order[index] ~= id then
			return false, "WAVE_ORDER must be chaser, ranged, tank"
		end
	end
	local mixes = source.WAVE_MIXES
	if type(mixes) ~= "table" or keyCount(mixes) ~= #EXPECTED_COUNTS then
		return false, "WAVE_MIXES must have one row per wave"
	end
	for index, expected in ipairs(EXPECTED_COUNTS) do
		local mix = mixes[index]
		if type(mix) ~= "table" then
			return false, "wave " .. index .. " mix is missing"
		end
		local sum = 0
		local seen = {}
		for key, value in pairs(mix) do
			if table.find(REQUIRED, key) == nil then
				return false, "wave " .. index .. " mix has " .. tostring(key)
			end
			if not finite(value) or value < 1 or value ~= math.floor(value) then
				return false, "wave " .. index .. " " .. tostring(key) .. " count must be a positive integer"
			end
			seen[key] = true
			sum += value
		end
		for _, id in ipairs(REQUIRED) do
			if seen[id] ~= true then
				return false, "wave " .. index .. " must mix in " .. id
			end
		end
		if sum ~= expected then
			return false, "wave " .. index .. " mix must add up to " .. tostring(expected)
		end
	end
	local gapOk, gapErr = checkNumber("WAVE_GAP", source.WAVE_GAP, 1)
	if not gapOk then
		return false, gapErr
	end
	local liftOk, liftErr = checkNumber("WAVE_LIFT", source.WAVE_LIFT, 0)
	if not liftOk then
		return false, liftErr
	end
	return true, ""
end

local EXPECTED_ADDS = 4
local EXPECTED_BOSS_WAVE = 5

-- Wave 5 is one boss plus four adds drawn from chaser, ranged, and tank.
local function checkBoss(source: any): (boolean, string)
	if source.BOSS_ADDS ~= EXPECTED_ADDS then
		return false, "BOSS_ADDS must be 4"
	end
	if source.BOSS_WAVE ~= EXPECTED_BOSS_WAVE then
		return false, "BOSS_WAVE must be 5"
	end
	local counts = source.WAVE_COUNTS
	if type(counts) ~= "table" or keyCount(counts) + 1 ~= source.BOSS_WAVE then
		return false, "BOSS_WAVE must follow the four trash waves"
	end
	local rowOk, rowErr = checkRow("boss", source.BOSS)
	if not rowOk then
		return false, rowErr
	end
	local boss = source.BOSS
	if not finite(boss.phase2At) or boss.phase2At <= 0 or boss.phase2At > 1 then
		return false, "boss.phase2At must be above 0 and at most 1"
	end
	if boss.damageTaken ~= 1 then
		return false, "boss.damageTaken must be 1"
	end
	local tank = source.TYPES.tank
	if type(tank) ~= "table" or not (boss.maxHealth > tank.maxHealth) then
		return false, "boss health must beat the tank"
	end
	if type(boss.size) ~= "table" or type(tank.size) ~= "table" or not (boss.size[2] > tank.size[2]) then
		return false, "boss block must be taller than the tank"
	end
	local mix = source.BOSS_ADD_MIX
	if type(mix) ~= "table" then
		return false, "BOSS_ADD_MIX is missing"
	end
	local sum = 0
	for key, value in pairs(mix) do
		if table.find(REQUIRED, key) == nil then
			return false, "boss adds must be drawn from chaser, ranged, tank"
		end
		if not finite(value) or value < 1 or value ~= math.floor(value) then
			return false, "boss add " .. tostring(key) .. " count must be a positive integer"
		end
		local add = source.TYPES[key]
		if type(add) ~= "table" or add.id ~= key then
			return false, "boss add " .. tostring(key) .. " is not a Config enemy"
		end
		sum += value
	end
	if sum ~= EXPECTED_ADDS then
		return false, "boss adds must add up to 4"
	end
	return true, ""
end

-- The stall clock cannot run past 30 seconds. The nudge and the spawn
-- pad have to be real distances that still fit the arena.
local function checkStuck(source: any): (boolean, string)
	local secondsOk, secondsErr = checkNumber("STUCK_SECONDS", source.STUCK_SECONDS, 0.05)
	if not secondsOk then
		return false, secondsErr
	end
	if source.STUCK_SECONDS > 30 then
		return false, "STUCK_SECONDS is above 30"
	end
	local progressOk, progressErr = checkNumber("STUCK_PROGRESS", source.STUCK_PROGRESS, 0.05)
	if not progressOk then
		return false, progressErr
	end
	if source.STUCK_PROGRESS > 4 then
		return false, "STUCK_PROGRESS is above 4"
	end
	local nudgeOk, nudgeErr = checkNumber("STUCK_NUDGE", source.STUCK_NUDGE, 0.5)
	if not nudgeOk then
		return false, nudgeErr
	end
	if source.STUCK_NUDGE > 16 then
		return false, "STUCK_NUDGE is above 16"
	end
	local clearOk, clearErr = checkNumber("SPAWN_CLEAR", source.SPAWN_CLEAR, 0.5)
	if not clearOk then
		return false, clearErr
	end
	if source.SPAWN_CLEAR > 8 then
		return false, "SPAWN_CLEAR is above 8"
	end
	local box = source.ARENA
	if type(box) == "table" and finite(box.maxX) and finite(box.minX) then
		if source.SPAWN_CLEAR * 4 >= box.maxX - box.minX then
			return false, "SPAWN_CLEAR does not fit the arena"
		end
	end
	return true, ""
end

-- Leash numbers live next to the boss. A slam that is instant, or a
-- range inside melee, does not count. The boss still does not heal.
local function checkLeash(source: any): (boolean, string)
	local rangeOk, rangeErr = checkNumber("LEASH_RANGE", source.LEASH_RANGE, 0.05)
	if not rangeOk then
		return false, rangeErr
	end
	local secondsOk, secondsErr = checkNumber("LEASH_SECONDS", source.LEASH_SECONDS, 0.5)
	if not secondsOk then
		return false, secondsErr
	end
	if source.LEASH_SECONDS > 8 then
		return false, "LEASH_SECONDS is above 8"
	end
	local windOk, windErr = checkNumber("LEASH_WINDUP", source.LEASH_WINDUP, 0.5)
	if not windOk then
		return false, windErr
	end
	if source.LEASH_WINDUP > 4 then
		return false, "LEASH_WINDUP is above 4"
	end
	local radiusOk, radiusErr = checkNumber("LEASH_RADIUS", source.LEASH_RADIUS, 2)
	if not radiusOk then
		return false, radiusErr
	end
	if source.LEASH_RADIUS > 12 then
		return false, "LEASH_RADIUS is above 12"
	end
	local boss = source.BOSS
	if type(boss) ~= "table" or not finite(boss.range) or source.LEASH_RANGE <= boss.range then
		return false, "LEASH_RANGE must sit outside the boss melee range"
	end
	local box = source.ARENA
	if type(box) == "table" and finite(box.maxX) and finite(box.minX) then
		if source.LEASH_RANGE >= box.maxX - box.minX then
			return false, "LEASH_RANGE must fit inside the arena"
		end
	end
	local dashOk, dashErr = checkNumber("LEASH_DASH", source.LEASH_DASH, 0.05)
	if not dashOk then
		return false, dashErr
	end
	if source.LEASH_DASH > 90 then
		return false, "LEASH_DASH is above 90"
	end
	if type(boss) ~= "table" or not finite(boss.moveSpeed) or source.LEASH_DASH <= boss.moveSpeed then
		return false, "LEASH_DASH must beat the boss move speed"
	end
	return true, ""
end

-- Pressure and Shard Volley. A decay that wipes an armed timer is a
-- hard reset, and a volley that is not three led shots is not this cast.
local function checkPressure(source: any): (boolean, string)
	local secondsOk, secondsErr = checkNumber("PRESSURE_SECONDS", source.PRESSURE_SECONDS, 2)
	if not secondsOk then
		return false, secondsErr
	end
	if source.PRESSURE_SECONDS > 8 then
		return false, "PRESSURE_SECONDS is above 8"
	end
	local decayOk, decayErr = checkNumber("PRESSURE_DECAY", source.PRESSURE_DECAY, 0.05)
	if not decayOk then
		return false, decayErr
	end
	if source.PRESSURE_DECAY >= source.PRESSURE_SECONDS then
		return false, "PRESSURE_DECAY must not clear an armed timer"
	end
	if source.VOLLEY_NAME ~= "Shard Volley" then
		return false, "VOLLEY_NAME must be Shard Volley"
	end
	local windOk, windErr = checkNumber("VOLLEY_WINDUP", source.VOLLEY_WINDUP, 0.3)
	if not windOk then
		return false, windErr
	end
	if source.VOLLEY_WINDUP > 3 then
		return false, "VOLLEY_WINDUP is above 3"
	end
	if source.VOLLEY_SHOTS ~= 3 then
		return false, "VOLLEY_SHOTS must be 3"
	end
	local coolOk, coolErr = checkNumber("VOLLEY_COOLDOWN", source.VOLLEY_COOLDOWN, 2)
	if not coolOk then
		return false, coolErr
	end
	if source.VOLLEY_COOLDOWN > 12 then
		return false, "VOLLEY_COOLDOWN is above 12"
	end
	local speedOk, speedErr = checkNumber("VOLLEY_SPEED", source.VOLLEY_SPEED, 40)
	if not speedOk then
		return false, speedErr
	end
	if source.VOLLEY_SPEED > 120 then
		return false, "VOLLEY_SPEED is above 120"
	end
	if not finite(source.VOLLEY_SPREAD) or source.VOLLEY_SPREAD < 0 or source.VOLLEY_SPREAD > 0.5 then
		return false, "VOLLEY_SPREAD must be from 0 to 0.5"
	end
	local leadOk, leadErr = checkNumber("VOLLEY_LEAD_MAX", source.VOLLEY_LEAD_MAX, 12)
	if not leadOk then
		return false, leadErr
	end
	if source.VOLLEY_LEAD_MAX > 36 then
		return false, "VOLLEY_LEAD_MAX is above 36"
	end
	return true, ""
end

-- The three types, or the wave-5 boss. Nil for any other id.
function Enemies.row(kind: string): Row?
	if type(kind) ~= "string" then
		return nil
	end
	local boss = Enemies.BOSS
	if boss ~= nil and kind == boss.id then
		return (boss :: any) :: Row
	end
	local found = Enemies.TYPES[kind]
	if found == nil or found.id ~= kind then
		return nil
	end
	return found
end

-- Returns false and a reason when a roster or its wave list breaks the
-- V1 rules. Pass nothing to check this module.
function Enemies.validate(roster: any?): (boolean, string)
	local source = if type(roster) == "table" then roster else Enemies
	local order = source.ORDER
	if type(order) ~= "table" or #order ~= #REQUIRED then
		return false, "ORDER must be chaser, ranged, tank"
	end
	for index, id in ipairs(REQUIRED) do
		if order[index] ~= id then
			return false, "ORDER must be chaser, ranged, tank"
		end
	end
	local stepOk, stepErr = checkNumber("STEP_MAX", source.STEP_MAX, 0.05)
	if not stepOk then
		return false, stepErr
	end
	if source.STEP_MAX > 1 then
		return false, "STEP_MAX is above 1"
	end
	local gapOk, gapErr = checkNumber("PREVIEW_GAP", source.PREVIEW_GAP, 1)
	if not gapOk then
		return false, gapErr
	end
	local liftOk, liftErr = checkNumber("PREVIEW_LIFT", source.PREVIEW_LIFT, 0)
	if not liftOk then
		return false, liftErr
	end
	local shared = source.SHARED
	if type(shared) ~= "table" or shared.boss ~= false then
		return false, "SHARED.boss must stay false"
	end
	local sharedNumbers = {
		{ "hover", shared.hover, 0 },
		{ "phase2At", shared.phase2At, 0 },
		{ "weakSeconds", shared.weakSeconds, 0 },
		{ "armoredMultiplier", shared.armoredMultiplier, 0.05 },
		{ "fogInterval", shared.fogInterval, 0 },
		{ "fogDamage", shared.fogDamage, 0 },
		{ "safeRadius", shared.safeRadius, 0 },
	}
	for _, spec in ipairs(sharedNumbers) do
		local field = spec[1] :: string
		local ok, err = checkNumber("SHARED." .. field, spec[2], spec[3] :: number)
		if not ok then
			return false, err
		end
	end
	if shared.phase2At > 1 then
		return false, "SHARED.phase2At is above 1"
	end
	local types = source.TYPES
	if type(types) ~= "table" then
		return false, "TYPES is missing"
	end
	for _, id in ipairs(REQUIRED) do
		local ok, err = checkRow(id, types[id])
		if not ok then
			return false, err
		end
	end
	local chaser = types.chaser
	local ranged = types.ranged
	local tank = types.tank
	if not (tank.maxHealth > chaser.maxHealth and chaser.maxHealth > ranged.maxHealth) then
		return false, "health must rank tank, then chaser, then ranged"
	end
	if not (chaser.moveSpeed > ranged.moveSpeed and ranged.moveSpeed > tank.moveSpeed) then
		return false, "move speed must rank chaser, then ranged, then tank"
	end
	if not (ranged.range > tank.range and ranged.range > chaser.range) then
		return false, "ranged range must be the longest"
	end
	if ranged.retreat <= 0 or ranged.retreat >= ranged.stop or ranged.stop > ranged.range then
		return false, "ranged must hold a band between retreat and stop"
	end
	if chaser.retreat ~= 0 or tank.retreat ~= 0 then
		return false, "chaser and tank do not retreat"
	end
	local arenaOk, arenaErr = checkArena(source)
	if not arenaOk then
		return false, arenaErr
	end
	if source.LOS_PAD * 2 >= ranged.retreat then
		return false, "LOS_PAD must sit inside the ranged retreat"
	end
	if tank.damageTaken >= 1 or chaser.damageTaken ~= 1 or ranged.damageTaken ~= 1 then
		return false, "only the tank reduces damage taken"
	end
	if tank.defense <= chaser.defense then
		return false, "tank defense must beat the chaser"
	end
	if chaser.style ~= "melee" or tank.style ~= "melee" or ranged.style ~= "projectile" then
		return false, "chaser and tank are melee; ranged is a projectile"
	end
	local waveOk, waveErr = checkWaves(source)
	if not waveOk then
		return false, waveErr
	end
	local bossOk, bossErr = checkBoss(source)
	if not bossOk then
		return false, bossErr
	end
	local stuckOk, stuckErr = checkStuck(source)
	if not stuckOk then
		return false, stuckErr
	end
	local leashOk, leashErr = checkLeash(source)
	if not leashOk then
		return false, leashErr
	end
	local pressureOk, pressureErr = checkPressure(source)
	if not pressureOk then
		return false, pressureErr
	end
	return true, ""
end

return Enemies
