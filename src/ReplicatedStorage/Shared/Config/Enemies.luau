--!strict

--[[
	V1 enemy types (roadmap 3.3 and 3.4). Chaser, ranged, and tank.

	Every tunable lives here, including the arena a ranged enemy kites
	inside and the shot ray. EnemyRoster, WaveFlow, and the server
	services read this file. Dungeons.ENEMIES copies the combat fields
	so Config.Enemies (the index alias) carries the same three ids.
	Tuning means editing this module, not the stepper.

	LaunchGate.SHOW.enemyTypes stays false. Live rooms and
	Dungeons.waveKinds do not spawn these ids. The 6/8/10/12 list is
	read only by WaveFlow, and that service no-ops while the flag is
	off. No Robux. No profile fields.
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
Enemies.SHOT_Y = 3
Enemies.LOS_PAD = 1.5

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

-- Roadmap 3.5. Four waves, then stop. Each mix uses chaser, ranged, and
-- tank, and those three counts add up to the wave size. Spawn order is
-- WAVE_ORDER. The live crawl does not read this list.
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
	return true, ""
end

return Enemies
