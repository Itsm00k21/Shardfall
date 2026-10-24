--!strict

--[[
	Haven layout. Plain numbers so tests can check the walk without Studio.

	The plaza is the origin. Districts and the five realm arches sit far
	enough apart that crossing the hub is a short walk, not a teleport.
	Dungeon rooms are built far down +Z (see Dungeons.REALM_OFFSET) so they
	do not overlap these islands.

	The concept art is the plan: crystal and Boss Plaza in the middle,
	Forge and Market to the west, Guild Hall and Pet Garden to the east,
	Observatory to the south-east. The six dungeon gates stand on a
	crescent south of spawn. The old realm shelf is gone.
]]

local Dungeons = require("./Dungeons")
local LaunchGate = require("./LaunchGate")
local Raids = require("./Raids")

local Haven = {}

Haven.WALK_SPEED = 16
Haven.PLAZA_RADIUS = 52
-- Studio's default baseplate tops out at y=0. The whole hub sits above it.
Haven.FLOOR_Y = 120
-- Lift a walk overlay (bridge deck, inlay) this far above the floor it
-- crosses. Coplanar tops flicker, including a seam that only bites by a hair.
Haven.LAYER = 0.05
-- Below this, a player who is not in a dungeon fell off the sky island.
Haven.FALL_Y = 60

export type Place = {
	id: string,
	name: string,
	x: number,
	z: number,
	radius: number?,
	station: string?,
	message: string?,
	open: boolean?,
	dungeonId: string?,
	color: { number }?,
	bearing: number?,
	-- Gate dressing. `sealed` is the painted lock. `open` stays the live prompt.
	level: number?,
	subline: string?,
	body: { number }?,
	edge: { number }?,
	glow: { number }?,
	dress: string?,
	sealed: boolean?,
	height: number?,
}

Haven.CRYSTAL = {
	x = 0,
	z = 0,
	height = 36,
}

-- Spawn stands on the plaza, south of the crystal, looking south at Rootvault.
Haven.SPAWN = {
	x = 0,
	y = 124,
	z = 30,
	lookX = 0,
	lookZ = 108,
}

-- Crescent of gates centered on the spawn pad. Bearings run from +Z toward +X.
Haven.GATE_RADIUS = 78
Haven.GATE_STEP = 12
Haven.COURT_RIM = 96
-- Vendor ring, same center. The Market island stays where it is.
Haven.VENDOR_RADIUS = 76
-- Prompt reach. The chord is 16.3, so 18 would light two mouths.
Haven.GATE_REACH = 8
-- The player's right pier sits toward the next arch. 8 would swallow it.
Haven.PIER_REACH = 4
-- Gate names have to read from the pad. Zone signs stay at 70.
Haven.NAMEPLATE_DISTANCE = 96

Haven.ARMORY = {
	id = "armory",
	name = "Armory",
	x = -38,
	z = -35.8,
	station = "armory",
}

Haven.SHOP = {
	id = "shop",
	name = "Shop",
	x = -70.5,
	z = 1.5,
	radius = 12,
	station = "market",
}

Haven.SHRINE = {
	id = "shrine",
	name = "Shrine",
	x = 28.5,
	z = -40.5,
	station = "soon",
	message = "The shrine wakes inside a run.",
}

-- Training Grove dummy. South rim of the plaza disc, west of the Rootvault
-- lane. halfX and halfZ are the prop's footprint. It is not a district and
-- not a gate, so it stays out of Haven.places.
Haven.GROVE = {
	id = "grove",
	name = "Training Grove",
	x = -16,
	z = 48.2,
	halfX = 1.1,
	halfZ = 0.8,
}

-- Five class stones for T-005. Grey, no prompt, not a gate.
Haven.NOVICE = {
	x = -40,
	z = { 18, 10, 2, -6, -14 },
}

Haven.DISTRICTS = {
	{
		id = "forge",
		name = "Forge",
		x = -200,
		z = -16,
		radius = 44,
		station = "craft",
	},
	{
		id = "market",
		name = "Market",
		x = -112,
		z = 78,
		radius = 34,
		station = "soon",
		message = "The daily shop is not open yet.",
	},
	{
		id = "guild",
		name = "Guild Hall",
		x = 168,
		z = -96,
		radius = 40,
		station = "soon",
		message = "The Guild Hall is coming soon.",
	},
	{
		id = "garden",
		name = "Pet Garden",
		x = 196,
		z = 72,
		radius = 42,
		station = "pets",
	},
	{
		id = "observatory",
		name = "Observatory",
		x = 64,
		z = 196,
		radius = 32,
		station = "soon",
		message = "Hidden combos are coming soon.",
	},
} :: { Place }

-- Left to right from the pad: Rootvault, then each later gate to the right.
-- Content open versus sealed is Haven.gateOpen. The built arch uses
-- Haven.gateShownOpen: Rootvault is open, Heartwood is open only while
-- raids are on, and the other four stay sealed. With raids off the orange
-- Heartwood mouth is sealed and labeled Opens later. `color` is the mouth
-- accent the light already uses.
Haven.PORTALS = {
	{
		id = "rootvault",
		name = "Rootvault",
		x = 0,
		z = 108,
		bearing = 0,
		open = true,
		sealed = false,
		dungeonId = "rootvault",
		color = { 64, 196, 96 },
		body = { 86, 62, 40 },
		edge = { 64, 196, 96 },
		dress = "roots",
		level = 1,
		height = 18,
		subline = "Lv 1 · Solo",
	},
	{
		id = "heartwood",
		name = "Heartwood",
		x = 16.2,
		z = 106.3,
		bearing = 12,
		open = true,
		sealed = false,
		dungeonId = "heartwood",
		color = { 214, 140, 64 },
		body = { 92, 140, 72 },
		edge = { 214, 140, 64 },
		dress = "bark",
		level = 15,
		height = 22,
		subline = "Lv 15 · 4–8",
		message = "Opens at level 15.",
	},
	{
		id = "tidecrypt",
		name = "Tidecrypt",
		x = 31.7,
		z = 101.3,
		bearing = 24,
		open = false,
		sealed = true,
		dungeonId = "tidecrypt",
		color = { 36, 96, 140 },
		body = { 210, 120, 110 },
		edge = { 64, 168, 162 },
		dress = "coral",
		level = 20,
		height = 18,
		subline = "Lv 20 · Sealed",
		message = "Tidecrypt is sealed.",
	},
	{
		id = "ember",
		name = "Emberforge",
		x = 45.8,
		z = 93.1,
		bearing = 36,
		open = false,
		sealed = true,
		color = { 255, 120, 40 },
		body = { 28, 26, 28 },
		edge = { 255, 150, 40 },
		dress = "basalt",
		level = 30,
		height = 18,
		subline = "Lv 30 · Sealed",
		message = "Emberforge is sealed.",
	},
	{
		id = "frost",
		name = "Frostveil",
		x = 58,
		z = 82.2,
		bearing = 48,
		open = false,
		sealed = true,
		color = { 186, 228, 255 },
		body = { 150, 176, 190 },
		edge = { 186, 228, 255 },
		dress = "ice",
		level = 40,
		height = 18,
		subline = "Lv 40 · Sealed",
		message = "Frostveil is sealed.",
	},
	{
		id = "void",
		name = "Void Rift",
		x = 67.5,
		z = 69,
		bearing = 60,
		open = false,
		sealed = true,
		color = { 120, 60, 180 },
		body = { 42, 40, 48 },
		edge = { 150, 70, 220 },
		glow = { 18, 16, 24 },
		dress = "obsidian",
		level = 50,
		height = 18,
		subline = "Lv 50 · Sealed",
		message = "Void Rift is sealed.",
	},
} :: { Place }

local function flat(a: { x: number, z: number }, b: { x: number, z: number }): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

function Haven.places(): { Place }
	local list = {}
	for _, district in ipairs(Haven.DISTRICTS) do
		table.insert(list, district)
	end
	for _, portal in ipairs(Haven.PORTALS) do
		table.insert(list, portal)
	end
	table.insert(list, Haven.ARMORY)
	table.insert(list, Haven.SHOP)
	table.insert(list, Haven.SHRINE)
	return list
end

function Haven.district(id: string): Place?
	for _, district in ipairs(Haven.DISTRICTS) do
		if district.id == id then
			return district
		end
	end
	return nil
end

function Haven.portal(id: string): Place?
	for _, portal in ipairs(Haven.PORTALS) do
		if portal.id == id then
			return portal
		end
	end
	return nil
end

-- Open when the dungeon is implemented (an endless arena is not a gate)
-- or this arch is the Heartwood raid. The painted `sealed` flag is not read.
function Haven.gateOpen(portal: Place): boolean
	local dungeonId = portal.dungeonId
	if type(dungeonId) == "string" then
		local dungeon = Dungeons.get(dungeonId)
		if dungeon ~= nil and dungeon.implemented == true and dungeon.endless ~= true then
			return true
		end
	end
	if portal.id == Dungeons.HEARTWOOD_ID and Raids.difficulty("story") ~= nil then
		return true
	end
	return false
end

-- True when the gate's content is live. The hub paints gateShownOpen, so a
-- parked Heartwood raid stays dark until raids are on.
function Haven.gateLit(portal: Place): boolean
	return Haven.gateOpen(portal)
end

-- The arch the player sees. Heartwood's content is live, but while the
-- raids switch is off the orange mouth is sealed so it does not read as a door.
function Haven.gateShownOpen(portal: Place): boolean
	if portal.id == Dungeons.HEARTWOOD_ID and not LaunchGate.on("raids") then
		return false
	end
	return Haven.gateOpen(portal)
end

-- An open plate names the level and the party. A sealed plate keeps its line.
function Haven.gatePlate(portal: Place): string
	local line = portal.subline
	if Haven.gateOpen(portal) then
		if type(line) == "string" and string.find(line, "Sealed", 1, true) == nil then
			return line
		end
		local level = portal.level
		if type(level) ~= "number" then
			level = 1
		end
		return string.format("Lv %d", level)
	end
	if type(line) == "string" then
		return line
	end
	return "Sealed"
end

-- Plate on the built arch. Heartwood says Opens later until raids are on.
function Haven.gateShownPlate(portal: Place): string
	if portal.id == Dungeons.HEARTWOOD_ID and not LaunchGate.on("raids") then
		return "Opens later"
	end
	return Haven.gatePlate(portal)
end

-- Point on the court rim (a circle around spawn) toward a district.
function Haven.courtRim(x: number, z: number): (number, number)
	local dx = x - Haven.SPAWN.x
	local dz = z - Haven.SPAWN.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1 then
		return Haven.SPAWN.x, Haven.SPAWN.z + Haven.COURT_RIM
	end
	local scale = Haven.COURT_RIM / distance
	return Haven.SPAWN.x + dx * scale, Haven.SPAWN.z + dz * scale
end

-- Longest straight line between two stations. That is the walk across Haven.
function Haven.crossingStuds(): number
	local points = Haven.places()
	local best = 0
	for i = 1, #points do
		for j = i + 1, #points do
			local distance = flat(points[i], points[j])
			if distance > best then
				best = distance
			end
		end
	end
	return best
end

function Haven.crossingSeconds(walkSpeed: number?): number
	local speed = walkSpeed
	if type(speed) ~= "number" or speed ~= speed or speed <= 0 then
		speed = Haven.WALK_SPEED
	end
	return Haven.crossingStuds() / speed
end

function Haven.fellOffHub(y: number): boolean
	return type(y) == "number" and y == y and y < Haven.FALL_Y
end

function Haven.spawnOnPlaza(): boolean
	local distance = math.sqrt(Haven.SPAWN.x * Haven.SPAWN.x + Haven.SPAWN.z * Haven.SPAWN.z)
	return distance < Haven.PLAZA_RADIUS - 8
end

export type Footprint = {
	x: number,
	z: number,
	rightX: number,
	rightZ: number,
	forwardX: number,
	forwardZ: number,
	halfX: number,
	halfZ: number,
}

-- Tops within this band are the same surface. The bridge tongues step by
-- 0.02, which stays just outside the band.
function Haven.sameTop(a: number, b: number): boolean
	return math.abs(a - b) < 0.02
end

-- True when two flat rectangles cover the same ground. A shared edge does
-- not count; a bite past that edge does.
function Haven.footprintsOverlap(a: Footprint, b: Footprint): boolean
	local slop = 1e-4
	local axes = {
		{ a.rightX, a.rightZ },
		{ a.forwardX, a.forwardZ },
		{ b.rightX, b.rightZ },
		{ b.forwardX, b.forwardZ },
	}
	local dx = b.x - a.x
	local dz = b.z - a.z
	for _, axis in ipairs(axes) do
		local ax = axis[1]
		local az = axis[2]
		local dist = math.abs(dx * ax + dz * az)
		local spanA = a.halfX * math.abs(a.rightX * ax + a.rightZ * az)
			+ a.halfZ * math.abs(a.forwardX * ax + a.forwardZ * az)
		local spanB = b.halfX * math.abs(b.rightX * ax + b.rightZ * az)
			+ b.halfZ * math.abs(b.forwardX * ax + b.forwardZ * az)
		if dist >= spanA + spanB - slop then
			return false
		end
	end
	return true
end

function Haven.coplanarTops(a: Footprint, topA: number, b: Footprint, topB: number): boolean
	return Haven.sameTop(topA, topB) and Haven.footprintsOverlap(a, b)
end

-- Farthest horizontal point. Dungeon rooms must sit beyond this.
function Haven.reach(): number
	local best = Haven.PLAZA_RADIUS
	for _, place in ipairs(Haven.places()) do
		local extra = place.radius or 8
		local distance = math.sqrt(place.x * place.x + place.z * place.z) + extra
		if distance > best then
			best = distance
		end
	end
	return best
end

return Haven
