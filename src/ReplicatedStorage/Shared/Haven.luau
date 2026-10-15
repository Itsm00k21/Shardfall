--!strict

--[[
	Haven layout. Plain numbers so tests can check the walk without Studio.

	The plaza is the origin. Districts and the five realm arches sit far
	enough apart that crossing the hub is a short walk, not a teleport.
	Dungeon rooms are built far down +Z (see Dungeons.REALM_OFFSET) so they
	do not overlap these islands.

	The concept art is the plan: crystal and Boss Plaza in the middle,
	Forge and Market to the west, Guild Hall and Pet Garden to the east,
	Observatory to the south-east, realm arches along the south edge.
]]

local Haven = {}

Haven.WALK_SPEED = 16
Haven.PLAZA_RADIUS = 52

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
}

Haven.CRYSTAL = {
	x = 0,
	z = 0,
	height = 36,
}

-- Spawn stands on the plaza, south of the crystal, looking north at it.
Haven.SPAWN = {
	x = 0,
	y = 4,
	z = 30,
	lookX = 0,
	lookZ = 0,
}

Haven.ARMORY = {
	id = "armory",
	name = "Armory",
	x = -26,
	z = 18,
	station = "armory",
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

-- South edge, west to east. Only Verdant Wilds enters the Rootvault.
Haven.PORTALS = {
	{
		id = "void",
		name = "Void Rift",
		x = -160,
		z = 228,
		open = false,
		color = { 150, 70, 220 },
		message = "Void Rift is coming soon.",
	},
	{
		id = "sunken",
		name = "Sunken Reach",
		x = -80,
		z = 228,
		open = false,
		color = { 50, 150, 255 },
		message = "Sunken Reach is coming soon.",
	},
	{
		id = "verdant",
		name = "Verdant Wilds",
		x = 0,
		z = 228,
		open = true,
		dungeonId = "rootvault",
		color = { 64, 196, 96 },
	},
	{
		id = "ember",
		name = "Emberforge",
		x = 80,
		z = 228,
		open = false,
		color = { 255, 150, 40 },
		message = "Emberforge is coming soon.",
	},
	{
		id = "frost",
		name = "Frostveil",
		x = 160,
		z = 228,
		open = false,
		color = { 186, 228, 255 },
		message = "Frostveil is coming soon.",
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

function Haven.spawnOnPlaza(): boolean
	local distance = math.sqrt(Haven.SPAWN.x * Haven.SPAWN.x + Haven.SPAWN.z * Haven.SPAWN.z)
	return distance < Haven.PLAZA_RADIUS - 8
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
