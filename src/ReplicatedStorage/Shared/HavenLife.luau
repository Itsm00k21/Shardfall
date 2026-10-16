--!strict

--[[
	Extra Haven dressing toward the sky-island concept.

	Counts and positions are data so tests can check the budget, the walk,
	and that flat tops do not share a face. The builder stamps these parts.
	Audio ids stay blank until a free Roblox id is verified.
]]

local Haven = require("./Haven")

local HavenLife = {}

HavenLife.BUDGET = 160
HavenLife.DAY_SECONDS = 480
HavenLife.START_CLOCK = 15.4

HavenLife.AUDIO = {
	hub = "",
	forge = "",
	market = "",
	garden = "",
	night = "",
}

export type Piece = {
	name: string,
	className: string,
	shape: string?,
	size: { number },
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number,
	color: { number },
	material: string,
	transparency: number,
	collide: boolean,
	particle: string?,
	light: boolean?,
	lod: string,
	lantern: boolean?,
	drift: number?,
}

export type Rig = {
	name: string,
	kind: string,
	x: number,
	z: number,
	points: { { number } }?,
	radius: number?,
	parts: { Piece },
}

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
	transparency: number?,
	shape: string?,
	particle: string?,
	light: boolean?
): Piece
	return {
		name = name,
		className = className,
		shape = shape,
		size = { sx, sy, sz },
		x = x,
		y = y,
		z = z,
		rx = rx,
		ry = ry,
		rz = rz,
		color = color,
		material = material,
		transparency = transparency or 0,
		collide = false,
		particle = particle,
		light = light == true,
		lod = lod,
		lantern = false,
		drift = nil,
	}
end

local WHITE = { 236, 240, 248 }
local MIST = { 170, 220, 255 }
local GOLD = { 255, 186, 96 }
local PINK = { 255, 150, 190 }
local CLOTH = { 86, 124, 210 }

-- A point just outside an island. inward keeps the curtain on the side that
-- faces the plaza, and side steps it off the bridge so the sheet is not
-- hidden in the deck.
local function fallPoint(
	x: number,
	z: number,
	radius: number,
	push: number,
	inward: boolean,
	side: number
): (number, number)
	local reach = math.sqrt(x * x + z * z)
	local dirx = 0
	local dirz = -1
	if reach >= 1 then
		dirx = x / reach
		dirz = z / reach
	end
	local sign = if inward then -1 else 1
	local px = x + dirx * sign * (radius + push)
	local pz = z + dirz * sign * (radius + push)
	return px - dirz * side, pz + dirx * side
end

function HavenLife.pieces(): { Piece }
	local list: { Piece } = {}
	local function add(item: Piece)
		table.insert(list, item)
	end

	local clouds = {
		{ 0, 0, 64 },
		{ -200, -16, 48 },
		{ -112, 78, 40 },
		{ 168, -96, 44 },
		{ 196, 72, 46 },
		{ 64, 196, 36 },
	}
	for index, cloud in ipairs(clouds) do
		add(
			piece(
				"Cloud",
				"Part",
				cloud[3],
				3.2,
				cloud[3] * 0.72,
				cloud[1],
				-38 - index * 0.4,
				cloud[2],
				0,
				index * 12,
				0,
				WHITE,
				"SmoothPlastic",
				"large",
				0.42
			)
		)
	end

	-- Plaza falls flank the heart in the spawn view. A sheet on the north
	-- rim sits behind the crystal. District falls face the walk in.
	local falls = {
		{ math.sin(math.rad(-28)) * 8, -math.cos(math.rad(-28)) * 8, Haven.PLAZA_RADIUS, false },
		{ math.sin(math.rad(28)) * 8, -math.cos(math.rad(28)) * 8, Haven.PLAZA_RADIUS, false },
	}
	for _, district in ipairs(Haven.DISTRICTS) do
		table.insert(falls, { district.x, district.z, district.radius or 30, true })
	end
	for _, fall in ipairs(falls) do
		-- Long axis is local Z. The builder yaws first, then pitches, so the
		-- sheet hangs as a curtain instead of lying flat on the cliff.
		local inward = fall[4] == true
		local side = if inward then 22 else 0
		local fx, fz = fallPoint(fall[1], fall[2], fall[3], 18, inward, side)
		local yaw = math.atan2(fx - fall[1], fz - fall[2])
		local length = 36
		local tilt = 78
		local top = 14
		local centerY = top - math.sin(math.rad(tilt)) * (length / 2)
		add(
			piece(
				"Waterfall",
				"Part",
				18,
				2.6,
				length,
				fx,
				centerY,
				fz,
				tilt,
				math.deg(yaw),
				0,
				{ 168, 198, 210 },
				"Glass",
				"large",
				0.28,
				nil,
				"mist",
				true
			)
		)
		local lipX, lipZ = fallPoint(fall[1], fall[2], fall[3], 2, inward, side)
		add(
			piece(
				"FallLip",
				"WedgePart",
				10,
				0.8,
				4,
				lipX,
				1.2,
				lipZ,
				tilt,
				math.deg(yaw),
				0,
				MIST,
				"Glass",
				"small",
				0.35
			)
		)
	end

	for index = 1, 4 do
		add(
			piece(
				"SkyShard",
				"Part",
				6 + index,
				16 + index * 2,
				5,
				0,
				78,
				0,
				28,
				index * 40,
				12,
				{ 158, 142, 186 },
				"SmoothPlastic",
				"large",
				0.08
			)
		)
		list[#list].drift = 70 + index * 18
	end

	local market = Haven.district("market")
	assert(market ~= nil)
	local stripes = {
		{ -10, -6, { 255, 244, 220 } },
		{ 10, -6, { 255, 250, 240 } },
		{ -10, 8, { 255, 236, 200 } },
		{ 10, 8, { 250, 250, 255 } },
	}
	for index, stripe in ipairs(stripes) do
		add(
			piece(
				"AwningStripe",
				"Part",
				9,
				0.22,
				7,
				market.x + stripe[1],
				6.15 + index * 0.05,
				market.z + stripe[2],
				0,
				0,
				0,
				stripe[3] :: { number },
				"SmoothPlastic",
				"large",
				0
			)
		)
	end
	for index = 1, 4 do
		add(
			piece(
				"Crate",
				"Part",
				2.2,
				1.4 + index * 0.15,
				2.2,
				market.x - 6 + index * 3.2,
				0.9,
				market.z + 18,
				0,
				index * 8,
				0,
				{ 140, 96, 62 },
				"Wood",
				"large",
				0
			)
		)
	end

	local garden = Haven.district("garden")
	assert(garden ~= nil)
	local flowers = {
		{ 10, 12 },
		{ 14, -8 },
		{ -14, 8 },
		{ -8, -14 },
		{ 4, 16 },
		{ -16, -4 },
	}
	local petal = { { 255, 170, 200 }, { 255, 210, 120 }, { 170, 230, 255 } }
	for index, flower in ipairs(flowers) do
		add(
			piece(
				"Flower",
				"Part",
				1.3,
				1.3,
				1.3,
				garden.x + flower[1],
				1.4,
				garden.z + flower[2],
				0,
				0,
				0,
				petal[(index - 1) % #petal + 1],
				"SmoothPlastic",
				"small",
				0,
				"Ball"
			)
		)
	end
	add(
		piece(
			"Petals",
			"Part",
			0.4,
			0.4,
			0.4,
			garden.x,
			6,
			garden.z,
			0,
			0,
			0,
			PINK,
			"SmoothPlastic",
			"small",
			1,
			"Ball",
			"petals"
		)
	)
	add(
		piece(
			"Butterflies",
			"Part",
			0.4,
			0.4,
			0.4,
			garden.x + 8,
			5,
			garden.z - 6,
			0,
			0,
			0,
			GOLD,
			"SmoothPlastic",
			"small",
			1,
			"Ball",
			"butterflies"
		)
	)

	local guild = Haven.district("guild")
	assert(guild ~= nil)
	for index, side in ipairs({ -8, 8 }) do
		add(
			piece(
				"GuildBanner",
				"Part",
				0.2,
				5.2,
				1.6,
				guild.x + side,
				11 + index * 0.3,
				guild.z + 8,
				0,
				0,
				0,
				CLOTH,
				"Fabric",
				"large",
				0
			)
		)
	end

	local observatory = Haven.district("observatory")
	assert(observatory ~= nil)
	add(
		piece(
			"StarBeam",
			"Part",
			1.2,
			26,
			1.2,
			observatory.x,
			28,
			observatory.z,
			18,
			0,
			0,
			{ 180, 190, 210 },
			"Glass",
			"large",
			0.4
		)
	)

	return list
end

function HavenLife.rigs(): { Rig }
	local list: { Rig } = {}
	local loops = {
		{
			{ 24, 10 },
			{ 30, 4 },
			{ 24, -4 },
			{ 16, 4 },
		},
		{
			{ -30, 8 },
			{ -22, 8 },
			{ -22, -4 },
			{ -30, -4 },
		},
		{
			{ 8, -24 },
			{ -4, -24 },
			{ -4, -32 },
			{ 8, -32 },
		},
	}
	for index, points in ipairs(loops) do
		local height = 6.2 + index * 0.5
		local home = points[1]
		local cloak = {
			{ 120, 72, 220 },
			{ 220, 84, 96 },
			{ 48, 150, 170 },
		}
		local flag = {
			{ 196, 164, 84 },
			{ 186, 112, 140 },
			{ 120, 168, 176 },
		}
		table.insert(list, {
			name = "Townsfolk",
			kind = "folk",
			x = home[1],
			z = home[2],
			points = points,
			radius = nil,
			parts = {
				piece(
					"Body",
					"Part",
					3.6,
					height,
					2.4,
					0,
					height / 2,
					0,
					0,
					0,
					0,
					cloak[index],
					"SmoothPlastic",
					"large",
					0
				),
				piece(
					"Head",
					"Part",
					2,
					2,
					2,
					0,
					height + 1.3,
					0,
					0,
					0,
					0,
					{ 236, 206, 176 },
					"SmoothPlastic",
					"large",
					0,
					"Ball"
				),
				piece(
					"TownsfolkFlag",
					"Part",
					8,
					20,
					1.4,
					0,
					height + 12,
					0,
					0,
					0,
					0,
					flag[index],
					"Fabric",
					"large",
					0
				),
				piece(
					"Arm",
					"Part",
					0.7,
					2.6,
					0.7,
					2.1,
					height * 0.55,
					0,
					0,
					0,
					18,
					cloak[index],
					"SmoothPlastic",
					"large",
					0
				),
				piece(
					"Arm",
					"Part",
					0.7,
					2.6,
					0.7,
					-2.1,
					height * 0.55,
					0,
					0,
					0,
					-18,
					cloak[index],
					"SmoothPlastic",
					"large",
					0
				),
			},
		})
	end

	local garden = Haven.district("garden")
	assert(garden ~= nil)
	local flocks = {
		{ 0, 0, 16 },
		{ garden.x, garden.z, 14 },
		{ -40, 20, 18 },
	}
	for _, flock in ipairs(flocks) do
		table.insert(list, {
			name = "Bird",
			kind = "bird",
			x = flock[1],
			z = flock[2],
			points = nil,
			radius = flock[3],
			parts = {
				piece(
					"Body",
					"Part",
					1.4,
					0.7,
					0.7,
					0,
					0,
					0,
					0,
					0,
					0,
					{ 64, 78, 110 },
					"SmoothPlastic",
					"small",
					0,
					"Ball"
				),
				piece(
					"Wing",
					"WedgePart",
					1.6,
					0.2,
					0.7,
					0.8,
					0.2,
					0,
					0,
					0,
					16,
					{ 186, 206, 230 },
					"SmoothPlastic",
					"small",
					0
				),
				piece(
					"Wing",
					"WedgePart",
					1.6,
					0.2,
					0.7,
					-0.8,
					0.2,
					0,
					0,
					0,
					-16,
					{ 186, 206, 230 },
					"SmoothPlastic",
					"small",
					0
				),
			},
		})
	end
	return list
end

function HavenLife.partCount(): number
	local total = #HavenLife.pieces()
	for _, rig in ipairs(HavenLife.rigs()) do
		total += #rig.parts
	end
	return total
end

function HavenLife.clock(elapsed: number): number
	if type(elapsed) ~= "number" or elapsed ~= elapsed or elapsed < 0 then
		elapsed = 0
	end
	return (HavenLife.START_CLOCK + (elapsed / HavenLife.DAY_SECONDS) * 24) % 24
end

function HavenLife.lanternsOn(clockTime: number): boolean
	if type(clockTime) ~= "number" or clockTime ~= clockTime then
		return false
	end
	local hour = clockTime % 24
	return hour < 6.2 or hour >= 18.2
end

function HavenLife.mood(
	clockTime: number
): { brightness: number, ambient: { number }, outdoor: { number } }
	if HavenLife.lanternsOn(clockTime) then
		return {
			brightness = 1.15,
			ambient = { 48, 42, 72 },
			outdoor = { 70, 64, 96 },
		}
	end
	return {
		brightness = 2.15,
		ambient = { 96, 112, 84 },
		outdoor = { 128, 146, 112 },
	}
end

-- Midday values match VerdantLook. The sun sits in the camera near 6:12 and
-- 18:12, and an unclamped bloom size plus sun rays turns that into a yellow screen.
function HavenLife.exposure(clockTime: number): {
	bloomIntensity: number,
	bloomSize: number,
	bloomThreshold: number,
	sunIntensity: number,
	sunSpread: number,
	brightness: number,
}
	local hour = 12
	if type(clockTime) == "number" and clockTime == clockTime then
		hour = clockTime % 24
	end
	local function band(center: number): number
		local distance = math.abs(hour - center)
		if distance > 12 then
			distance = 24 - distance
		end
		if distance >= 1.8 then
			return 0
		end
		return 1 - distance / 1.8
	end
	local glare = math.max(band(6.2), band(18.2))
	return {
		bloomIntensity = 0.12 - glare * 0.08,
		bloomSize = 10 - glare * 4,
		bloomThreshold = 1.6 + glare * 0.2,
		sunIntensity = 0.14 - glare * 0.11,
		sunSpread = 0.35 - glare * 0.18,
		brightness = 2.15 - glare * 1.0,
	}
end

function HavenLife.audioReady(id: string): boolean
	return string.match(id, "^rbxassetid://%d+$") ~= nil
end

return HavenLife
