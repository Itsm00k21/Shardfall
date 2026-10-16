--!strict

--[[
	Seeded dressing for a Verdant room and a fixed Haven polish pass.

	The same seed always lays the same props. Props stay off the path, the
	spawn, and the exit pad, and the part total stops at the budget.
]]

local ModelFactory = require("./ModelFactory")

local VerdantScatter = {}

export type Spot = {
	kind: string,
	x: number,
	z: number,
	y: number,
	yaw: number,
	scale: number,
}

VerdantScatter.ROOM_BUDGET = 150
VerdantScatter.HAVEN_BUDGET = 80
VerdantScatter.FEET_Y = 0.5
VerdantScatter.PATH_HALF = 5.4

local SPAWN_Z = -16
local PORTAL_Z = 18
local PAD_RADIUS = 8
local MARGIN = 3.5
local ATTEMPTS = 80

local WILD = {
	{ kind = "grass_tuft", weight = 8, spacing = 3.2 },
	{ kind = "flower", weight = 5, spacing = 3.6 },
	{ kind = "boulder", weight = 3, spacing = 7 },
	{ kind = "fallen_log", weight = 2, spacing = 8 },
	{ kind = "giant_mushroom", weight = 2, spacing = 7 },
	{ kind = "vine_hang", weight = 2, spacing = 6 },
	{ kind = "ruin_arch", weight = 1, spacing = 12 },
	{ kind = "firefly", weight = 3, spacing = 5 },
	{ kind = "pond", weight = 1, spacing = 16 },
}

local function unit(state: number): (number, number)
	local nextState = (state * 48271) % 2147483647
	return nextState, (nextState - 1) / 2147483646
end

local function blocked(x: number, z: number, half: number, clearing: number): boolean
	if math.abs(x) > half - MARGIN or math.abs(z) > half - MARGIN then
		return true
	end
	if math.abs(x) < VerdantScatter.PATH_HALF then
		return true
	end
	local spawn = x * x + (z - SPAWN_Z) * (z - SPAWN_Z)
	if spawn < PAD_RADIUS * PAD_RADIUS then
		return true
	end
	local portal = x * x + (z - PORTAL_Z) * (z - PORTAL_Z)
	if portal < PAD_RADIUS * PAD_RADIUS then
		return true
	end
	if clearing > 0 and x * x + z * z < clearing * clearing then
		return true
	end
	return false
end

local function tooClose(spots: { Spot }, x: number, z: number, spacing: number): boolean
	for _, spot in ipairs(spots) do
		local dx = spot.x - x
		local dz = spot.z - z
		local need = math.max(spacing, 3.2)
		if dx * dx + dz * dz < need * need then
			return true
		end
	end
	return false
end

local function push(
	spots: { Spot },
	spent: number,
	budget: number,
	kind: string,
	x: number,
	z: number,
	yaw: number,
	scale: number
): number
	local cost = ModelFactory.partCount(kind)
	if cost <= 0 or spent + cost > budget then
		return spent
	end
	table.insert(spots, {
		kind = kind,
		x = x,
		z = z,
		y = if kind == "firefly" then 4.5 else VerdantScatter.FEET_Y,
		yaw = yaw,
		scale = scale,
	})
	return spent + cost
end

function VerdantScatter.room(seed: number, half: number, mode: string): { Spot }
	local budget = if mode == "waves" then 110 else VerdantScatter.ROOM_BUDGET
	local clearing = if mode == "arena" then 12 else 0
	local spots: { Spot } = {}
	local spent = 0
	local state = math.floor(math.abs(seed)) % 2147483647
	if state < 1 then
		state = 1
	end

	local reserved = {
		{ "tree_giant", -20, -20 },
		{ "tree_pine", 20, -18 },
		{ "tree_mushroom", -18, 16 },
		{ "tree_willow", 20, 14 },
	}
	for _, row in ipairs(reserved) do
		local x = row[2] :: number
		local z = row[3] :: number
		if not blocked(x, z, half, clearing) then
			spent = push(spots, spent, budget, row[1] :: string, x, z, 0.4, 1)
		end
	end

	if mode == "arena" then
		local radius = half * 0.62
		for index = 1, 8 do
			local angle = (index - 1) / 8 * math.pi * 2
			local x = math.cos(angle) * radius
			local z = math.sin(angle) * radius
			if not blocked(x, z, half, 0) and not tooClose(spots, x, z, 4) then
				spent = push(spots, spent, budget, "root_ring", x, z, angle, 1)
			end
		end
	end

	local weightTotal = 0
	for _, row in ipairs(WILD) do
		weightTotal += row.weight
	end
	for _ = 1, ATTEMPTS do
		if spent >= budget then
			break
		end
		local roll
		state, roll = unit(state)
		local px
		state, px = unit(state)
		local pz
		state, pz = unit(state)
		local pyaw
		state, pyaw = unit(state)
		local pscale
		state, pscale = unit(state)
		local x = (px * 2 - 1) * (half - MARGIN)
		local z = (pz * 2 - 1) * (half - MARGIN)
		local cursor = roll * weightTotal
		local kind = WILD[1].kind
		local spacing = WILD[1].spacing
		for _, row in ipairs(WILD) do
			cursor -= row.weight
			if cursor <= 0 then
				kind = row.kind
				spacing = row.spacing
				break
			end
		end
		if not blocked(x, z, half, clearing) and not tooClose(spots, x, z, spacing) then
			local scale = 0.9 + math.floor(pscale * 5) * 0.05
			spent = push(spots, spent, budget, kind, x, z, pyaw * math.pi * 2, scale)
		end
	end
	return spots
end

function VerdantScatter.partTotal(spots: { Spot }): number
	local total = 0
	for _, spot in ipairs(spots) do
		total += ModelFactory.partCount(spot.kind)
	end
	return total
end

local function lantern(parts: { ModelFactory.Desc }, x: number, z: number)
	table.insert(parts, {
		name = "LanternPost",
		className = "Part",
		size = { 0.4, 4.6, 0.4 },
		x = x,
		y = 2.3,
		z = z,
		rx = 0,
		ry = 0,
		rz = 0,
		color = { 92, 64, 40 },
		material = "Wood",
		shape = nil,
		lod = "large",
		particle = nil,
		light = false,
		shadow = true,
		collide = false,
		transparency = 0,
		limb = nil,
	})
	table.insert(parts, {
		name = "Lantern",
		className = "Part",
		size = { 0.7, 0.7, 0.7 },
		x = x,
		y = 4.7,
		z = z,
		rx = 0,
		ry = 0,
		rz = 0,
		color = { 214, 168, 96 },
		material = "SmoothPlastic",
		shape = "Ball",
		lod = "small",
		particle = "fireflies",
		light = true,
		shadow = false,
		collide = false,
		transparency = 0,
		limb = nil,
	})
end

local function banner(parts: { ModelFactory.Desc }, x: number, z: number, yaw: number)
	local clothX = x + math.cos(yaw) * 0.9
	local clothZ = z + math.sin(yaw) * 0.9
	table.insert(parts, {
		name = "BannerPole",
		className = "Part",
		size = { 0.28, 5.2, 0.28 },
		x = x,
		y = 2.6,
		z = z,
		rx = 0,
		ry = yaw,
		rz = 0,
		color = { 72, 48, 32 },
		material = "Wood",
		shape = nil,
		lod = "large",
		particle = nil,
		light = false,
		shadow = true,
		collide = false,
		transparency = 0,
		limb = nil,
	})
	table.insert(parts, {
		name = "Banner",
		className = "Part",
		size = { 0.12, 2.2, 1.3 },
		x = clothX,
		y = 3.6,
		z = clothZ,
		rx = 0,
		ry = yaw,
		rz = 0,
		color = { 64, 140, 86 },
		material = "Fabric",
		shape = nil,
		lod = "large",
		particle = nil,
		light = false,
		shadow = false,
		collide = false,
		transparency = 0,
		limb = nil,
	})
end

function VerdantScatter.haven(): { ModelFactory.Desc }
	local parts: { ModelFactory.Desc } = {}
	local islands = {
		{ x = -200, z = -16, radius = 44 },
		{ x = -112, z = 78, radius = 34 },
		{ x = 168, z = -96, radius = 40 },
		{ x = 196, z = 72, radius = 42 },
		{ x = 64, z = 196, radius = 32 },
	}
	for index, island in ipairs(islands) do
		local reach = math.sqrt(island.x * island.x + island.z * island.z)
		local ux = island.x / reach
		local uz = island.z / reach
		local treeX = island.x + ux * island.radius * 0.55
		local treeZ = island.z + uz * island.radius * 0.55
		local tree = if index % 2 == 0 then "tree_willow" else "tree_pine"
		for _, desc in ipairs(ModelFactory.compose(tree, treeX, 0.16, treeZ, index * 0.4, 0.8)) do
			table.insert(parts, desc)
		end
		local side = index * 1.3
		lantern(parts, island.x - uz * 8, island.z + ux * 8)
		banner(parts, island.x + uz * 6, island.z - ux * 6, side)
		for _, desc in
			ipairs(ModelFactory.compose("grass_tuft", treeX + 2.4, 0.12, treeZ + 1.2, 0.5, 1))
		do
			table.insert(parts, desc)
		end
		for _, desc in ipairs(ModelFactory.compose("firefly", treeX, 5.5, treeZ + 2, 0, 1)) do
			table.insert(parts, desc)
		end
	end
	lantern(parts, -28, -16)
	lantern(parts, 26, -18)
	banner(parts, -18, -24, 0.6)
	for _, desc in ipairs(ModelFactory.compose("tree_willow", 30, 0.16, -22, 0.8, 0.75)) do
		table.insert(parts, desc)
	end
	for _, desc in ipairs(ModelFactory.compose("flower", -22, 0.12, -10, 0.2, 1)) do
		table.insert(parts, desc)
	end
	for _, desc in ipairs(ModelFactory.compose("grass_tuft", 18, 0.12, -12, 1.1, 1)) do
		table.insert(parts, desc)
	end
	return parts
end

return VerdantScatter
