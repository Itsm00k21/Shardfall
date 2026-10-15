--!strict

--[[
	Haven quick travel.

	Waystones unlock on first touch and stay in the save. Spawn is open
	from the start. A travel pass skips the cooldown; nothing in the game
	sells that pass yet.
]]

local Haven = require("./Haven")

local Travel = {}

Travel.COOLDOWN = 10
Travel.PASS_PITCH = "A travel pass with no cooldown is not for sale yet."

export type Destination = {
	id: string,
	name: string,
	x: number,
	z: number,
	lookX: number,
	lookZ: number,
	stoneX: number,
	stoneZ: number,
}

local function spot(
	id: string,
	name: string,
	x: number,
	z: number,
	lookX: number,
	lookZ: number,
	stoneX: number,
	stoneZ: number
): Destination
	return {
		id = id,
		name = name,
		x = x,
		z = z,
		lookX = lookX,
		lookZ = lookZ,
		stoneX = stoneX,
		stoneZ = stoneZ,
	}
end

local forge = Haven.district("forge")
local market = Haven.district("market")
local garden = Haven.district("garden")
assert(forge ~= nil and market ~= nil and garden ~= nil, "Haven districts missing")

-- Stand on the walk, looking at the station. The crystal sits beside that
-- spot so the first touch is the unlock, not the teleport.
Travel.DESTINATIONS = {
	spot(
		"spawn",
		"Spawn",
		Haven.SPAWN.x,
		Haven.SPAWN.z,
		Haven.SPAWN.lookX,
		Haven.SPAWN.lookZ,
		8,
		18
	),
	spot("forge", "Forge", forge.x + 8, forge.z + 18, forge.x, forge.z, forge.x + 20, forge.z),
	spot(
		"armory",
		"Armory Rolls",
		Haven.ARMORY.x,
		Haven.ARMORY.z - 8,
		Haven.ARMORY.x,
		Haven.ARMORY.z,
		Haven.ARMORY.x + 10,
		Haven.ARMORY.z - 4
	),
	spot(
		"pets",
		"Pet Rolls",
		garden.x - 8,
		garden.z + 16,
		garden.x,
		garden.z,
		garden.x - 16,
		garden.z + 14
	),
	spot(
		"market",
		"Market",
		market.x + 6,
		market.z + 14,
		market.x,
		market.z,
		market.x + 16,
		market.z + 12
	),
	spot("portals", "Dungeon Portals", 0, 244, 0, 252, 18, 244),
} :: { Destination }

local BY_ID: { [string]: Destination } = {}
for _, dest in ipairs(Travel.DESTINATIONS) do
	BY_ID[dest.id] = dest
end

function Travel.get(id: string): Destination?
	return BY_ID[id]
end

function Travel.ids(): { string }
	local list = {}
	for _, dest in ipairs(Travel.DESTINATIONS) do
		table.insert(list, dest.id)
	end
	return list
end

function Travel.arrival(id: string): (number?, number?, number?, number?, number?)
	local dest = BY_ID[id]
	if dest == nil then
		return nil, nil, nil, nil, nil
	end
	local y = if id == "spawn" then Haven.SPAWN.y else Haven.FLOOR_Y + 4
	return dest.x, y, dest.z, dest.lookX, dest.lookZ
end

function Travel.isUnlocked(data: any, id: string): boolean
	if BY_ID[id] == nil then
		return false
	end
	if id == "spawn" then
		return true
	end
	return type(data) == "table" and type(data.waystones) == "table" and data.waystones[id] == true
end

-- True when this touch newly unlocked the stone.
function Travel.touch(data: any, id: string): boolean
	if type(data) ~= "table" or BY_ID[id] == nil then
		return false
	end
	if Travel.isUnlocked(data, id) then
		return false
	end
	if type(data.waystones) ~= "table" then
		data.waystones = {}
	end
	data.waystones[id] = true
	return true
end

function Travel.passSkipsCooldown(data: any): boolean
	return type(data) == "table" and data.travelPass == true
end

function Travel.remaining(data: any, now: number): number
	if type(now) ~= "number" or now ~= now then
		return Travel.COOLDOWN
	end
	if Travel.passSkipsCooldown(data) then
		return 0
	end
	local last = 0
	if type(data) == "table" and type(data.lastTravel) == "number" then
		last = data.lastTravel
	end
	if now < last then
		return Travel.COOLDOWN
	end
	local left = Travel.COOLDOWN - (now - last)
	if left < 0 then
		return 0
	end
	return left
end

-- nil when the trip is allowed. lastTravel is stamped only then.
function Travel.attempt(data: any, id: string, now: number): string?
	if type(data) ~= "table" then
		return "Profile is still loading."
	end
	if BY_ID[id] == nil then
		return "Unknown destination."
	end
	if not Travel.isUnlocked(data, id) then
		return "That waystone is still locked."
	end
	local left = Travel.remaining(data, now)
	if left > 0 then
		return string.format("Waystone cooling down (%ds).", math.ceil(left))
	end
	data.lastTravel = now
	return nil
end

return Travel
