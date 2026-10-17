--!strict

--[[
	Part rigs for Verdant monsters and the forest kit.

	Recipes are data. layout() and compose() do not create instances, so the
	scatter tests can count parts and check seeds. buildEnemy() and place()
	are what the Rootvault spawn and room builder call. Every part stays
	anchored. Limbs are posed by CFrame, not physics joints, so a rig cannot
	fall, fling the player, or pick up the player's name tag.
]]

local ModelFactory = {}

export type Piece = {
	name: string,
	className: string,
	size: { number },
	offset: { number },
	rotation: { number },
	color: { number },
	material: string,
	shape: string?,
	lod: string,
	limb: string?,
	particle: string?,
	light: boolean,
	transparency: number,
}

export type Desc = {
	name: string,
	className: string,
	size: { number },
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number,
	color: { number },
	material: string,
	shape: string?,
	lod: string,
	particle: string?,
	light: boolean,
	shadow: boolean,
	collide: boolean,
	transparency: number,
	limb: string?,
}

ModelFactory.MONSTER_BUDGET = 40
ModelFactory.MONSTERS = {
	"vine_crawler",
	"spore_bat",
	"moss_crawler",
	"root_brute",
	"thorn_sprite",
	"grandmother_gnarl",
}

ModelFactory.TREES = { "tree_giant", "tree_pine", "tree_mushroom", "tree_willow" }

local SCALE: { [string]: number } = {
	vine_crawler = 1,
	spore_bat = 1,
	moss_crawler = 1.1,
	root_brute = 1.45,
	thorn_sprite = 1.15,
	grandmother_gnarl = 5,
}

local MOSS = { 86, 150, 78 }
local MOSS_DARK = { 42, 96, 56 }
local BARK = { 118, 78, 48 }
local BARK_DARK = { 72, 46, 32 }
local GOLD = { 255, 196, 96 }
local AMBER = { 255, 168, 64 }
local CYAN = { 90, 230, 196 }
local GLOW = { 170, 255, 176 }
local CAP = { 168, 92, 86 }
local STONE = { 122, 116, 108 }
local WATER = { 64, 168, 156 }

local function piece(
	name: string,
	className: string,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number,
	color: { number },
	material: string,
	lod: string,
	shape: string?,
	limb: string?,
	particle: string?,
	light: boolean?,
	transparency: number?
): Piece
	return {
		name = name,
		className = className,
		size = { sx, sy, sz },
		offset = { x, y, z },
		rotation = { rx, ry, rz },
		color = color,
		material = material,
		shape = shape,
		lod = lod,
		limb = limb,
		particle = particle,
		light = light == true,
		transparency = transparency or 0,
	}
end

local function block(
	name: string,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: { number },
	material: string,
	lod: string,
	limb: string?
): Piece
	return piece(
		name,
		"Part",
		sx,
		sy,
		sz,
		x,
		y,
		z,
		0,
		0,
		0,
		color,
		material,
		lod,
		nil,
		limb,
		nil,
		nil,
		nil
	)
end

local function ball(
	name: string,
	diameter: number,
	x: number,
	y: number,
	z: number,
	color: { number },
	material: string,
	lod: string,
	light: boolean?,
	limb: string?
): Piece
	return piece(
		name,
		"Part",
		diameter,
		diameter,
		diameter,
		x,
		y,
		z,
		0,
		0,
		0,
		color,
		material,
		lod,
		"Ball",
		limb,
		nil,
		light,
		nil
	)
end

local function wedge(
	name: string,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number,
	color: { number },
	material: string,
	lod: string,
	limb: string?
): Piece
	return piece(
		name,
		"WedgePart",
		sx,
		sy,
		sz,
		x,
		y,
		z,
		rx,
		ry,
		rz,
		color,
		material,
		lod,
		nil,
		limb,
		nil,
		nil,
		nil
	)
end

local RECIPES: { [string]: { Piece } } = {
	vine_crawler = {
		block("Segment", 1.15, 0.85, 1.05, 0, 0.7, -0.2, MOSS, "Grass", "large", "segment"),
		block("Segment", 1.25, 0.95, 1.1, 0, 0.72, 0.9, MOSS_DARK, "Grass", "large", "segment"),
		block("Segment", 1.2, 0.9, 1.05, 0, 0.68, 2, MOSS, "Grass", "large", "segment"),
		block("Segment", 1.05, 0.75, 0.95, 0, 0.6, 3, MOSS_DARK, "Grass", "large", "segment"),
		block("Segment", 0.8, 0.55, 0.8, 0, 0.5, 3.9, MOSS, "Grass", "small", "segment"),
		wedge("Leaf", 0.7, 0.35, 1.1, 0.7, 1.15, 0.4, 18, 0, 24, GLOW, "Grass", "small", "segment"),
		wedge(
			"Leaf",
			0.7,
			0.35,
			1.1,
			-0.7,
			1.15,
			1.3,
			18,
			0,
			-24,
			MOSS,
			"Grass",
			"small",
			"segment"
		),
		wedge("Leaf", 0.6, 0.3, 0.95, 0.65, 1.05, 2.3, 16, 0, 20, GLOW, "Grass", "small", nil),
		wedge(
			"Leaf",
			0.55,
			0.28,
			0.85,
			-0.55,
			0.95,
			3.1,
			16,
			0,
			-18,
			MOSS_DARK,
			"Grass",
			"small",
			nil
		),
		ball("Eye", 0.28, 0.22, 0.95, -0.55, AMBER, "Neon", "small", true, nil),
		ball("Eye", 0.28, -0.22, 0.95, -0.55, AMBER, "Neon", "small", true, nil),
	},
	spore_bat = {
		ball("Cap", 1.7, 0, 1.55, 0, CAP, "Grass", "large", nil, "float"),
		block("Gills", 1.2, 0.28, 1.2, 0, 0.85, 0, CYAN, "Neon", "small", "float"),
		ball("Body", 0.85, 0, 0.7, 0.15, MOSS_DARK, "Grass", "large", nil, "float"),
		wedge("Wing", 1.5, 0.22, 1.7, 1.35, 1.15, 0.1, 0, 0, 28, MOSS, "Grass", "large", "wing"),
		wedge("Wing", 1.5, 0.22, 1.7, -1.35, 1.15, 0.1, 0, 0, -28, MOSS, "Grass", "large", "wing"),
		ball("Ear", 0.35, 0.4, 2.15, -0.15, BARK, "Grass", "small", nil, nil),
		ball("Ear", 0.35, -0.4, 2.15, -0.15, BARK, "Grass", "small", nil, nil),
		piece(
			"Spores",
			"Part",
			0.45,
			0.45,
			0.45,
			0,
			1.15,
			-0.2,
			0,
			0,
			0,
			CYAN,
			"Neon",
			"small",
			"Ball",
			"float",
			"spores",
			true,
			0.15
		),
	},
	moss_crawler = {
		block("Shell", 2.4, 1.15, 3.1, 0, 1.15, 0.4, MOSS, "Grass", "large", "body"),
		wedge(
			"ShellLip",
			2.2,
			0.45,
			1.1,
			0,
			1.55,
			-0.7,
			-22,
			0,
			0,
			MOSS_DARK,
			"Grass",
			"large",
			"body"
		),
		ball("Head", 1.15, 0, 0.85, -1.35, BARK, "Wood", "large", nil, "body"),
		block("Leg", 0.35, 0.7, 0.35, 0.95, 0.35, -0.4, BARK_DARK, "Wood", "small", "leg"),
		block("Leg", 0.35, 0.7, 0.35, -0.95, 0.35, -0.4, BARK_DARK, "Wood", "small", "leg"),
		block("Leg", 0.35, 0.7, 0.35, 1.05, 0.35, 1.1, BARK_DARK, "Wood", "small", "leg"),
		block("Leg", 0.35, 0.7, 0.35, -1.05, 0.35, 1.1, BARK_DARK, "Wood", "small", "leg"),
		ball("Eye", 0.26, 0.28, 1.05, -1.7, AMBER, "Neon", "small", true, nil),
		ball("Eye", 0.26, -0.28, 1.05, -1.7, AMBER, "Neon", "small", true, nil),
		ball("Moss", 0.7, 0.55, 1.7, 0.5, GLOW, "Grass", "small", nil, nil),
		ball("Moss", 0.55, -0.4, 1.55, 1.2, CYAN, "Grass", "small", true, nil),
	},
	root_brute = {
		block("Torso", 2.1, 2.4, 1.5, 0, 2.5, 0, BARK, "Wood", "large", "body"),
		ball("Head", 1.35, 0, 4.05, -0.15, BARK_DARK, "Wood", "large", nil, "body"),
		block("Shoulder", 0.8, 0.7, 0.8, 1.35, 3.3, 0, MOSS, "Grass", "large", nil),
		block("Shoulder", 0.8, 0.7, 0.8, -1.35, 3.3, 0, MOSS, "Grass", "large", nil),
		block("Arm", 0.55, 1.7, 0.55, 1.7, 2.15, -0.15, BARK, "Wood", "large", "arm"),
		block("Arm", 0.55, 1.7, 0.55, -1.7, 2.15, -0.15, BARK, "Wood", "large", "arm"),
		ball("Fist", 0.95, 1.85, 1.05, -0.35, BARK_DARK, "Wood", "large", nil, "fist"),
		ball("Fist", 0.95, -1.85, 1.05, -0.35, BARK_DARK, "Wood", "large", nil, "fist"),
		block("Leg", 0.6, 1.5, 0.6, 0.55, 0.75, 0.1, BARK_DARK, "Wood", "large", "leg"),
		block("Leg", 0.6, 1.5, 0.6, -0.55, 0.75, 0.1, BARK_DARK, "Wood", "large", "leg"),
		ball("Eye", 0.32, 0.32, 4.35, -0.55, GOLD, "Neon", "small", true, nil),
		ball("Eye", 0.32, -0.32, 4.35, -0.55, GOLD, "Neon", "small", true, nil),
		wedge("Bark", 1.4, 0.4, 0.8, 0, 3.5, 0.7, 30, 0, 0, MOSS, "Grass", "small", nil),
	},
	thorn_sprite = {
		ball("Body", 0.85, 0, 1.15, 0, GLOW, "Neon", "large", true, "float"),
		wedge("Wing", 0.9, 0.16, 1.25, 0.85, 1.35, 0.1, 0, 0, 36, CYAN, "Neon", "small", "wing"),
		wedge("Wing", 0.9, 0.16, 1.25, -0.85, 1.35, 0.1, 0, 0, -36, CYAN, "Neon", "small", "wing"),
		wedge(
			"Thorn",
			0.28,
			0.7,
			0.28,
			0.35,
			1.7,
			-0.15,
			0,
			0,
			12,
			BARK_DARK,
			"Wood",
			"small",
			nil
		),
		wedge("Thorn", 0.28, 0.7, 0.28, -0.3, 1.75, 0.1, 0, 20, -12, BARK, "Wood", "small", nil),
		wedge(
			"Thorn",
			0.24,
			0.6,
			0.24,
			0.05,
			1.85,
			0.25,
			12,
			-10,
			0,
			BARK_DARK,
			"Wood",
			"small",
			nil
		),
		ball("Core", 0.4, 0, 1.15, 0, GOLD, "Neon", "small", true, "float"),
		ball("Halo", 1.15, 0, 2.15, 0, CYAN, "Neon", "small", true, "float"),
	},
	grandmother_gnarl = {
		block("Trunk", 1.7, 4.4, 1.6, 0, 2.3, 0, BARK_DARK, "Wood", "large", "body"),
		wedge("Knot", 1.2, 0.7, 0.8, 0.55, 2.4, 0.4, 20, 12, 0, BARK, "Wood", "large", nil),
		wedge("Knot", 1.1, 0.65, 0.75, -0.5, 3.1, -0.2, 18, -16, 0, BARK, "Wood", "large", nil),
		ball("Canopy", 2.6, 0, 5.3, 0, MOSS_DARK, "Grass", "large", nil, "body"),
		ball("Eye", 0.38, 0.38, 3.5, -0.72, AMBER, "Neon", "small", true, nil),
		ball("Eye", 0.38, -0.38, 3.5, -0.72, AMBER, "Neon", "small", true, nil),
		block("WeakSpot", 0.7, 0.7, 0.25, 0, 2.6, -0.85, GOLD, "Neon", "large", nil),
		block("Arm", 0.45, 2.2, 0.45, 1.35, 3.4, 0, BARK, "Wood", "large", "arm"),
		block("Arm", 0.45, 2.2, 0.45, -1.35, 3.4, 0, BARK, "Wood", "large", "arm"),
		ball("Fist", 0.7, 1.7, 2.1, -0.2, BARK_DARK, "Wood", "large", nil, "fist"),
		ball("Fist", 0.7, -1.7, 2.1, -0.2, BARK_DARK, "Wood", "large", nil, "fist"),
		ball("Lantern", 0.42, 0.85, 4.6, 0.4, GOLD, "Neon", "small", true, nil),
		ball("Lantern", 0.42, -0.7, 5.1, -0.3, AMBER, "Neon", "small", true, nil),
		ball("Lantern", 0.36, 0.15, 5.6, 0.55, GOLD, "Neon", "small", true, nil),
		block("Tendril", 0.28, 1.4, 0.28, 0.9, 0.7, 0.6, MOSS, "Grass", "small", "tendril"),
		block("Tendril", 0.28, 1.3, 0.28, -0.85, 0.65, 0.45, MOSS, "Grass", "small", "tendril"),
		block("Tendril", 0.24, 1.2, 0.24, 0.4, 0.6, -0.7, MOSS_DARK, "Grass", "small", "tendril"),
		block(
			"Tendril",
			0.24,
			1.15,
			0.24,
			-0.35,
			0.55,
			-0.55,
			MOSS_DARK,
			"Grass",
			"small",
			"tendril"
		),
	},
	tree_giant = {
		block("Trunk", 2.2, 11, 2.2, 0, 5.5, 0, BARK_DARK, "Wood", "large", nil),
		block("Mid", 1.5, 4, 1.5, 0.4, 11.5, 0.2, BARK, "Wood", "large", nil),
		ball("Canopy", 8, 0, 13.5, 0, MOSS, "Grass", "large", nil, nil),
		ball("Canopy", 5.5, 2.4, 12.2, 1.2, MOSS_DARK, "Grass", "large", nil, nil),
		ball("Canopy", 4.5, -2.2, 11.4, -0.8, MOSS, "Grass", "large", nil, nil),
		wedge("Flare", 2.2, 1.4, 1.6, 1.3, 0.8, 0.4, 28, 20, 0, BARK, "Wood", "large", nil),
		wedge("Flare", 2, 1.3, 1.5, -1.2, 0.75, -0.3, 26, -30, 0, BARK_DARK, "Wood", "large", nil),
		ball("Glow", 0.6, 1.2, 10.5, 1.4, CYAN, "Neon", "small", true, nil),
	},
	tree_pine = {
		block("Trunk", 0.7, 4.2, 0.7, 0, 2.1, 0, BARK, "Wood", "large", nil),
		wedge("Layer", 2.6, 1.5, 2.6, 0, 3.7, 0, 22, 0, 0, MOSS_DARK, "Grass", "large", nil),
		wedge("Layer", 2.1, 1.35, 2.1, 0, 4.85, 0, 22, 40, 0, MOSS, "Grass", "large", nil),
		wedge("Layer", 1.4, 1.15, 1.4, 0, 5.85, 0, 22, 18, 0, GLOW, "Grass", "small", nil),
	},
	tree_mushroom = {
		block("Stalk", 0.8, 2.6, 0.8, 0, 1.3, 0, BARK, "Wood", "large", nil),
		ball("Cap", 3.2, 0, 2.9, 0, CAP, "Grass", "large", nil, nil),
		ball("Spot", 0.55, 0.7, 3.5, 0.4, CYAN, "Neon", "small", true, nil),
		ball("Spot", 0.4, -0.6, 3.3, -0.35, GLOW, "Neon", "small", true, nil),
		block("Gills", 2.2, 0.25, 2.2, 0, 2.15, 0, CYAN, "Neon", "small", nil),
	},
	tree_willow = {
		block("Trunk", 0.9, 5.2, 0.9, 0, 2.6, 0, BARK_DARK, "Wood", "large", nil),
		ball("Crown", 3.4, 0, 5.4, 0, MOSS, "Grass", "large", nil, nil),
		wedge("Droop", 0.35, 2.4, 0.35, 1.1, 3.6, 0.2, 0, 0, 38, MOSS_DARK, "Grass", "small", nil),
		wedge("Droop", 0.35, 2.6, 0.35, -1.05, 3.5, 0.15, 0, 0, -36, MOSS, "Grass", "small", nil),
		wedge("Droop", 0.3, 2.2, 0.3, 0.2, 3.7, 1.05, 36, 0, 0, MOSS_DARK, "Grass", "small", nil),
		wedge("Droop", 0.3, 2.3, 0.3, -0.15, 3.55, -1, -34, 0, 0, GLOW, "Grass", "small", nil),
	},
	boulder = {
		ball("Stone", 2.4, 0, 1.05, 0, STONE, "Rock", "large", nil, nil),
		ball("Stone", 1.5, 0.85, 0.7, 0.4, MOSS, "Grass", "large", nil, nil),
		wedge("Moss", 1.2, 0.35, 0.8, -0.4, 1.5, 0.2, 24, 10, 0, GLOW, "Grass", "small", nil),
	},
	ruin_arch = {
		block("Pillar", 0.8, 3.6, 0.8, -1.6, 1.8, 0, STONE, "Slate", "large", nil),
		block("Pillar", 0.8, 3.6, 0.8, 1.6, 1.8, 0, STONE, "Slate", "large", nil),
		block("Lintel", 4.2, 0.7, 0.9, 0, 3.8, 0, STONE, "Slate", "large", nil),
		wedge("Moss", 1.4, 0.3, 0.7, 0.2, 4.2, 0.2, 18, 0, 8, MOSS, "Grass", "small", nil),
	},
	fallen_log = {
		block("Log", 1.1, 0.9, 3.6, 0, 0.55, 0, BARK, "Wood", "large", nil),
		ball("Cap", 0.8, 0, 0.7, 1.5, MOSS, "Grass", "small", nil, nil),
		wedge("Moss", 0.7, 0.25, 1.2, 0.2, 1.05, -0.4, 20, 0, 0, GLOW, "Grass", "small", nil),
	},
	flower = {
		block("Stem", 0.16, 0.85, 0.16, 0, 0.42, 0, MOSS_DARK, "Grass", "small", nil),
		ball("Bloom", 0.55, 0, 0.95, 0, CYAN, "Neon", "small", true, nil),
	},
	giant_mushroom = {
		block("Stalk", 1.1, 2.2, 1.1, 0, 1.1, 0, BARK, "Wood", "large", nil),
		ball("Cap", 2.8, 0, 2.35, 0, CAP, "Grass", "large", nil, nil),
		ball("Spot", 0.45, 0.55, 2.9, 0.3, CYAN, "Neon", "small", true, nil),
	},
	vine_hang = {
		block("Rope", 0.25, 2.4, 0.25, 0, 2.4, 0, MOSS_DARK, "Grass", "small", nil),
		wedge("Leaf", 0.7, 0.25, 0.9, 0.25, 1.5, 0, 16, 0, 20, MOSS, "Grass", "small", nil),
		wedge("Leaf", 0.6, 0.22, 0.8, -0.2, 2, 0.1, 14, 0, -18, GLOW, "Grass", "small", nil),
	},
	grass_tuft = {
		wedge("Blade", 0.35, 0.7, 0.35, 0, 0.35, 0, 18, 0, 12, MOSS, "Grass", "small", nil),
		wedge(
			"Blade",
			0.3,
			0.6,
			0.3,
			0.2,
			0.3,
			0.05,
			16,
			20,
			-14,
			MOSS_DARK,
			"Grass",
			"small",
			nil
		),
	},
	firefly = {
		piece(
			"Mote",
			"Part",
			0.35,
			0.35,
			0.35,
			0,
			0.2,
			0,
			0,
			0,
			0,
			GOLD,
			"Neon",
			"small",
			"Ball",
			nil,
			"fireflies",
			true,
			0.15
		),
	},
	pond = {
		piece(
			"Water",
			"Part",
			6,
			0.35,
			4.5,
			0,
			0.2,
			0,
			0,
			0,
			0,
			WATER,
			"Glass",
			"large",
			nil,
			nil,
			nil,
			nil,
			0.42
		),
	},
	root_ring = {
		block("Root", 1.4, 0.45, 0.55, 0, 0.28, 0, BARK_DARK, "Wood", "large", nil),
		wedge("Spike", 0.45, 0.9, 0.45, 0.35, 0.7, 0, 12, 0, 18, BARK, "Wood", "small", nil),
		ball("Moss", 0.45, -0.35, 0.4, 0.1, MOSS, "Grass", "small", nil, nil),
	},
}

function ModelFactory.scaleOf(kind: string): number
	return SCALE[kind] or 1
end

function ModelFactory.recipe(kind: string): { Piece }?
	return RECIPES[kind]
end

function ModelFactory.partCount(kind: string): number
	local recipe = RECIPES[kind]
	if recipe == nil then
		return 0
	end
	return #recipe
end

function ModelFactory.barLift(kind: string): number
	if kind == "grandmother_gnarl" then
		return 26
	end
	if kind == "root_brute" then
		return 8
	end
	if kind == "spore_bat" or kind == "thorn_sprite" then
		return 4.5
	end
	return 3.2
end

function ModelFactory.layout(kind: string, scaleMultiplier: number?): { Piece }?
	local recipe = RECIPES[kind]
	if recipe == nil then
		return nil
	end
	local multiplier = scaleMultiplier or 1
	if multiplier ~= multiplier or multiplier <= 0 then
		multiplier = 1
	end
	local applied = ModelFactory.scaleOf(kind) * multiplier
	local laid = {}
	for _, source in ipairs(recipe) do
		table.insert(laid, {
			name = source.name,
			className = source.className,
			size = {
				source.size[1] * applied,
				source.size[2] * applied,
				source.size[3] * applied,
			},
			offset = {
				source.offset[1] * applied,
				source.offset[2] * applied,
				source.offset[3] * applied,
			},
			rotation = {
				math.rad(source.rotation[1]),
				math.rad(source.rotation[2]),
				math.rad(source.rotation[3]),
			},
			color = source.color,
			material = source.material,
			shape = source.shape,
			lod = source.lod,
			limb = source.limb,
			particle = source.particle,
			light = source.light,
			transparency = source.transparency,
		})
	end
	return laid
end

function ModelFactory.compose(
	kind: string,
	x: number,
	feetY: number,
	z: number,
	yaw: number,
	scaleMultiplier: number?
): { Desc }
	local laid = ModelFactory.layout(kind, scaleMultiplier)
	local descs = {}
	if laid == nil then
		return descs
	end
	local cosine = math.cos(yaw)
	local sine = math.sin(yaw)
	for _, source in ipairs(laid) do
		local localX = source.offset[1]
		local localZ = source.offset[3]
		table.insert(descs, {
			name = source.name,
			className = source.className,
			size = source.size,
			x = x + localX * cosine - localZ * sine,
			y = feetY + source.offset[2],
			z = z + localX * sine + localZ * cosine,
			rx = source.rotation[1],
			ry = source.rotation[2] + yaw,
			rz = source.rotation[3],
			color = source.color,
			material = source.material,
			shape = source.shape,
			lod = source.lod,
			particle = source.particle,
			light = source.light,
			shadow = source.lod ~= "small",
			collide = false,
			transparency = source.transparency,
			limb = source.limb,
		})
	end
	return descs
end

function ModelFactory.motion(
	kind: string,
	limb: string,
	time: number,
	moving: boolean
): (number, number)
	local speed = if moving then 7.5 else 2.1
	local amp = if moving then 32 else 9
	local idleBob = math.sin(time * 2.4) * (if moving then 0.08 else 0.16)
	if limb == "wing" then
		return math.sin(time * (speed + 4)) * (if moving then 42 else 24), idleBob
	end
	if limb == "arm" or limb == "fist" then
		local side = if string.find(kind, "grandmother", 1, true) ~= nil then 0.6 else 0
		return math.sin(time * speed + side) * amp, 0
	end
	if limb == "segment" or limb == "leg" then
		return math.sin(time * speed) * (if moving then 14 else 5), 0
	end
	if limb == "float" then
		return math.sin(time * 1.6) * 8, math.sin(time * 3) * 0.45
	end
	if limb == "tendril" then
		return math.sin(time * 1.8) * 12, 0
	end
	return 0, idleBob * 0.25
end

local function color3(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local templates: { [string]: Instance } = {}

local function borrow(className: string): Instance
	local template = templates[className]
	if template == nil then
		template = Instance.new(className)
		if template:IsA("BasePart") then
			template.Anchored = true
			template.CanCollide = false
			template.CanTouch = false
			template.CastShadow = false
			template.TopSurface = Enum.SurfaceType.Smooth
			template.BottomSurface = Enum.SurfaceType.Smooth
		end
		templates[className] = template
	end
	return template:Clone()
end

local function attachParticle(part: BasePart, kind: string)
	local emitter = borrow("ParticleEmitter") :: ParticleEmitter
	emitter.Name = kind
	emitter.Rate = if kind == "fireflies" then 3 else 8
	emitter.Lifetime = NumberRange.new(0.8, 1.8)
	emitter.Speed = NumberRange.new(0.2, 1.1)
	emitter.LightEmission = 0.75
	emitter.Size = NumberSequence.new(0.35)
	local tint = if kind == "fireflies" then GOLD else CYAN
	emitter.Color = ColorSequence.new(color3(tint))
	emitter.Parent = part
end

local function attachLight(part: BasePart, channels: { number }, range: number)
	local light = Instance.new("PointLight")
	light.Color = color3(channels)
	light.Brightness = 1.1
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

local function spawnPiece(
	parent: Instance,
	source: Piece,
	cframe: CFrame,
	anchored: boolean
): BasePart
	local created = borrow(source.className)
	local part = created :: BasePart
	part.Name = source.name
	part.Size = Vector3.new(source.size[1], source.size[2], source.size[3])
	part.Color = color3(source.color)
	part.Material = (Enum.Material :: any)[source.material]
	part.Anchored = anchored
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = source.transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = cframe
	if source.shape == "Ball" and part:IsA("Part") then
		part.Shape = Enum.PartType.Ball
	end
	part:SetAttribute("ShardfallLod", source.lod)
	part:SetAttribute("BaseR", source.color[1])
	part:SetAttribute("BaseG", source.color[2])
	part:SetAttribute("BaseB", source.color[3])
	part.Parent = parent
	if source.particle ~= nil then
		attachParticle(part, source.particle)
	end
	if source.light then
		attachLight(part, source.color, if source.lod == "small" then 6 else 12)
	end
	return part
end

local function underCharacter(parent: Instance): boolean
	local cursor: Instance? = parent
	while cursor ~= nil do
		if cursor:IsA("Model") and cursor:FindFirstChildOfClass("Humanoid") ~= nil then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

function ModelFactory.place(
	parent: Instance,
	kind: string,
	feet: CFrame,
	yaw: number,
	scaleMultiplier: number?
): Model?
	local laid = ModelFactory.layout(kind, scaleMultiplier)
	if laid == nil then
		warn("[Shardfall] No kit recipe for " .. kind)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = kind
	model.Parent = parent
	local spun = feet * CFrame.Angles(0, yaw, 0)
	for _, source in ipairs(laid) do
		local localCf = CFrame.new(source.offset[1], source.offset[2], source.offset[3])
			* CFrame.Angles(source.rotation[1], source.rotation[2], source.rotation[3])
		spawnPiece(model, source, spun * localCf, true)
	end
	return model
end

function ModelFactory.buildEnemy(
	parent: Instance,
	kind: string,
	rootCFrame: CFrame,
	rootSize: Vector3,
	displayName: string
): BasePart?
	if underCharacter(parent) then
		warn("[Shardfall] Refused to parent " .. kind .. " rig under a character")
		return nil
	end
	local laid = ModelFactory.layout(kind, 1)
	if laid == nil then
		warn("[Shardfall] No rig recipe for " .. kind)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = kind
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("ShardfallKind", kind)
	model.Parent = parent
	local root = Instance.new("Part")
	root.Name = if displayName ~= "" then displayName else kind
	root.Size = rootSize
	root.Shape = Enum.PartType.Block
	root.CFrame = rootCFrame
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.CastShadow = false
	root.Massless = true
	-- Hit volume. Transparency 1, and it is not the Highlight adornee.
	-- Visuals live on Body so a rim light cannot draw this block.
	root.Transparency = 1
	root:SetAttribute("ShardfallHitbox", true)
	root.Parent = model
	model.PrimaryPart = root
	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = model
	local foot = -rootSize.Y / 2
	for _, source in ipairs(laid) do
		local ox = source.offset[1]
		local oy = foot + source.offset[2]
		local oz = source.offset[3]
		local localCf = CFrame.new(ox, oy, oz)
			* CFrame.Angles(source.rotation[1], source.rotation[2], source.rotation[3])
		local visual = spawnPiece(body, source, root.CFrame * localCf, true)
		visual:SetAttribute("Ox", ox)
		visual:SetAttribute("Oy", oy)
		visual:SetAttribute("Oz", oz)
		visual:SetAttribute("Rx", source.rotation[1])
		visual:SetAttribute("Ry", source.rotation[2])
		visual:SetAttribute("Rz", source.rotation[3])
		visual:SetAttribute("Limb", source.limb or "body")
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanTouch = false
	end
	root:SetAttribute("ShardfallPieces", #laid)
	local roleLight = if kind == "grandmother_gnarl"
		then 22
		elseif kind == "root_brute" or kind == "thorn_sprite" then 12
		elseif kind == "spore_bat" then 8
		else 0
	if roleLight > 0 then
		attachLight(root, if kind == "grandmother_gnarl" then AMBER else CYAN, roleLight)
	end
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Transparency = 1
	return root
end

-- Highlight and hit-flash adorn this, never the transparent hit volume.
function ModelFactory.adorn(root: BasePart): Instance
	local model = root.Parent
	if model ~= nil then
		local body = model:FindFirstChild("Body")
		if body ~= nil then
			return body
		end
	end
	return root
end

local function visualParts(root: BasePart): { BasePart }
	local scope: Instance = ModelFactory.adorn(root)
	local parts = {}
	if scope == root then
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		return parts
	end
	for _, descendant in ipairs(scope:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

function ModelFactory.step(root: BasePart, time: number, moving: boolean)
	local kind = root.Parent
	local kindName = if kind ~= nil then kind.Name else ""
	if root.Anchored ~= true or root.CanCollide == true or root.CanTouch == true then
		if root:GetAttribute("ShardfallLoose") ~= true then
			root:SetAttribute("ShardfallLoose", true)
			warn("[Shardfall] Re-anchored loose rig root " .. root.Name)
		end
		root.Anchored = true
		root.CanCollide = false
		root.CanTouch = false
	end
	for _, child in ipairs(visualParts(root)) do
		if child:IsA("BasePart") then
			if child.Anchored ~= true or child.CanCollide == true or child.CanTouch == true then
				if child:GetAttribute("ShardfallLoose") ~= true then
					child:SetAttribute("ShardfallLoose", true)
					warn("[Shardfall] Re-anchored loose rig part " .. child.Name)
				end
				child.Anchored = true
				child.CanCollide = false
				child.CanTouch = false
			end
			local ox = child:GetAttribute("Ox")
			local oy = child:GetAttribute("Oy")
			local oz = child:GetAttribute("Oz")
			if type(ox) == "number" and type(oy) == "number" and type(oz) == "number" then
				local rx = child:GetAttribute("Rx")
				local ry = child:GetAttribute("Ry")
				local rz = child:GetAttribute("Rz")
				local limb = child:GetAttribute("Limb")
				local limbName = if type(limb) == "string" then limb else "body"
				local pitch, bob = ModelFactory.motion(kindName, limbName, time, moving)
				local flinchUntil = root:GetAttribute("ShardfallFlinchUntil")
				if type(flinchUntil) == "number" and time < flinchUntil then
					pitch += 18
				end
				local localCf = CFrame.new(ox, oy, oz)
					* CFrame.Angles(
						if type(rx) == "number" then rx else 0,
						if type(ry) == "number" then ry else 0,
						if type(rz) == "number" then rz else 0
					)
				child.CFrame = root.CFrame
					* localCf
					* CFrame.new(0, bob, 0)
					* CFrame.Angles(math.rad(pitch), 0, 0)
			end
		end
	end
end

function ModelFactory.flash(root: BasePart)
	local highlight = Instance.new("Highlight")
	highlight.Name = "HitFlash"
	highlight.FillColor = Color3.fromRGB(255, 244, 220)
	highlight.OutlineColor = Color3.fromRGB(255, 220, 140)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0.1
	local adorn = ModelFactory.adorn(root)
	highlight.Adornee = adorn
	highlight.Parent = adorn
	task.delay(0.12, function()
		if highlight.Parent ~= nil then
			highlight:Destroy()
		end
	end)
end

function ModelFactory.tintNamed(root: BasePart, name: string, color: Color3?)
	for _, descendant in ipairs(visualParts(root)) do
		if descendant:IsA("BasePart") and descendant.Name == name then
			if color == nil then
				local red = descendant:GetAttribute("BaseR")
				local green = descendant:GetAttribute("BaseG")
				local blue = descendant:GetAttribute("BaseB")
				if type(red) == "number" and type(green) == "number" and type(blue) == "number" then
					descendant.Color = Color3.fromRGB(red, green, blue)
				end
			else
				descendant.Color = color
			end
		end
	end
end

function ModelFactory.dissolve(root: BasePart)
	local fading = {}
	for _, descendant in ipairs(visualParts(root)) do
		if descendant ~= root then
			descendant.CanCollide = false
			table.insert(fading, descendant)
			for _, child in ipairs(descendant:GetChildren()) do
				if child:IsA("ParticleEmitter") or child:IsA("PointLight") then
					child.Enabled = false
				elseif child:IsA("Motor6D") then
					child.Transform = CFrame.new()
				end
			end
		end
	end
	local puff = Instance.new("ParticleEmitter")
	puff.Name = "Death"
	puff.Rate = 12
	puff.Lifetime = NumberRange.new(0.2, 0.45)
	puff.Speed = NumberRange.new(2, 6)
	puff.Parent = root
	local steps = 5
	for step = 1, steps do
		local alpha = step / steps
		task.delay(0.45 * alpha, function()
			for _, part in ipairs(fading) do
				if part.Parent ~= nil then
					part.Transparency = alpha
				end
			end
			if step == steps and puff.Parent ~= nil then
				puff.Enabled = false
				puff:Destroy()
			end
		end)
	end
	local host = root.Parent
	local folder = if host ~= nil then host.Parent else nil
	if folder == nil then
		return
	end
	for index = 1, 7 do
		local leaf = borrow("Part") :: Part
		leaf.Name = "Leaf"
		leaf.Size = Vector3.new(0.55, 0.16, 0.8)
		leaf.Color = color3(if index % 2 == 0 then MOSS else GLOW)
		leaf.Material = Enum.Material.Grass
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CanQuery = false
		leaf.CanTouch = false
		leaf.CastShadow = false
		leaf:SetAttribute("ShardfallLod", "small")
		local angle = index * 0.9
		leaf.CFrame = root.CFrame
			* CFrame.new(math.cos(angle) * 1.4, 0.6 + index * 0.15, math.sin(angle) * 1.4)
			* CFrame.Angles(0.4, angle, 0.2)
		leaf.Parent = folder
		task.delay(1.3, function()
			if leaf.Parent ~= nil then
				leaf:Destroy()
			end
		end)
	end
end

return ModelFactory
