--!strict

--[[
	Builds the Haven blockout from Haven.luau.

	Simple parts, themed colors, and a low count. The crystal's shards orbit
	on a heartbeat. ProximityPrompts carry HavenAction so the client can open
	the existing panel, and the Verdant arch is also an EnterPad for the
	Rootvault.

	StreamingEnabled cannot be set from a script. It lives on Workspace in
	default.project.json. The hub model is Persistent so the islands stay
	replicated at spawn. Crawl rooms are outside this model and stream in
	when the player is teleported.

	Floors are plain blocks. A cylinder's axis is local X, and Shape changes
	were dropping that rotation in Studio, and the walk surface was also
	buried in the default baseplate at y=0. Every part is lifted by
	Haven.FLOOR_Y. The Haven model is parented directly under Workspace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Dungeons = require(ReplicatedStorage.Shared.Dungeons)
local Haven = require(ReplicatedStorage.Shared.Haven)

local HavenBuilder = {}

local orbitConnection: RBXScriptConnection? = nil

local function rgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean,
	world: boolean?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = Enum.PartType.Block
	piece.Size = size
	piece.Anchored = true
	piece.CanCollide = collide
	piece.CanTouch = false
	piece.Transparency = 0
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Color = color
	piece.Material = material
	-- Local CFrames are lifted once. A CFrame taken from a part that
	-- already went through here is already at hub height.
	if world == true then
		piece.CFrame = cframe
	else
		piece.CFrame = cframe + Vector3.new(0, Haven.FLOOR_Y, 0)
	end
	piece.Parent = parent
	return piece
end

-- Square slab. yTop is the local walk height before FLOOR_Y is added.
local function slab(
	parent: Instance,
	name: string,
	x: number,
	yTop: number,
	z: number,
	width: number,
	depth: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	return part(
		parent,
		name,
		Vector3.new(width, thickness, depth),
		CFrame.new(x, yTop - thickness / 2, z),
		color,
		material,
		collide
	)
end

local function disc(
	parent: Instance,
	name: string,
	x: number,
	yTop: number,
	z: number,
	diameter: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	return slab(parent, name, x, yTop, z, diameter, diameter, thickness, color, material, collide)
end

local function ball(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	z: number,
	diameter: number,
	color: Color3,
	material: Enum.Material
): Part
	local piece = part(
		parent,
		name,
		Vector3.new(diameter, diameter, diameter),
		CFrame.new(x, y, z),
		color,
		material,
		false
	)
	piece.Shape = Enum.PartType.Ball
	return piece
end

local function sign(parent: Instance, cframe: CFrame, text: string, width: number)
	local board = part(
		parent,
		"Sign",
		Vector3.new(width, 4, 0.4),
		cframe,
		Color3.fromRGB(48, 42, 36),
		Enum.Material.Wood,
		false
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(236, 226, 190)
	label.Text = text
	label.Parent = gui
end

local function promptOn(
	host: BasePart,
	actionText: string,
	objectText: string,
	action: string,
	message: string?
)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HavenAction", action)
	if message ~= nil then
		prompt:SetAttribute("HavenMessage", message)
	end
	prompt.Parent = host
end

local function approach(
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	inset: number
): (number, number)
	local dx = toX - fromX
	local dz = toZ - fromZ
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 0.1 then
		return fromX, fromZ
	end
	return fromX + dx / distance * inset, fromZ + dz / distance * inset
end

local BRIDGE_WIDTH = 18
local BRIDGE_THICKNESS = 8
local BRIDGE_OVERLAP = 14
local FLOOR_TOP = 0

-- Two axis-aligned blocks, an L from (x1,z1) to (x2,z2). No yaw, so the
-- span is just Size and Position. Ends overlap both rims.
local function bridge(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local dx = x2 - x1
	local dz = z2 - z1
	if math.abs(dx) < 1 and math.abs(dz) < 1 then
		return
	end
	local color = Color3.fromRGB(126, 122, 116)
	local yCenter = FLOOR_TOP - BRIDGE_THICKNESS / 2
	if math.abs(dx) >= 1 then
		part(
			parent,
			"Bridge",
			Vector3.new(math.abs(dx) + BRIDGE_OVERLAP, BRIDGE_THICKNESS, BRIDGE_WIDTH),
			CFrame.new((x1 + x2) / 2, yCenter, z1),
			color,
			Enum.Material.Cobblestone,
			true
		)
	end
	if math.abs(dz) >= 1 then
		part(
			parent,
			"Bridge",
			Vector3.new(BRIDGE_WIDTH, BRIDGE_THICKNESS, math.abs(dz) + BRIDGE_OVERLAP),
			CFrame.new(x2, yCenter, (z1 + z2) / 2),
			color,
			Enum.Material.Cobblestone,
			true
		)
	end
end

local function island(
	parent: Instance,
	name: string,
	x: number,
	z: number,
	radius: number,
	top: Color3,
	topMaterial: Enum.Material
): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	disc(model, "Ground", x, FLOOR_TOP, z, radius * 2, 8, top, topMaterial, true)
	disc(
		model,
		"Rock",
		x,
		FLOOR_TOP - 8,
		z,
		radius * 2 + 16,
		12,
		Color3.fromRGB(92, 86, 78),
		Enum.Material.Rock,
		true
	)
	return model
end

local function stationPad(parent: Instance, x: number, z: number, color: Color3): Part
	local dx = -x
	local dz = -z
	local distance = math.sqrt(dx * dx + dz * dz)
	local px = x
	local pz = z
	if distance > 1 then
		px = x + dx / distance * 8
		pz = z + dz / distance * 8
	end
	return disc(parent, "Station", px, 0.45, pz, 9, 0.45, color, Enum.Material.Neon, false)
end

local STONE = Color3.fromRGB(138, 136, 130)
local GRASS = Color3.fromRGB(78, 148, 72)

local function buildCrystal(parent: Instance)
	disc(parent, "Pedestal", 0, 2, 0, 22, 2, STONE, Enum.Material.Slate, true)

	-- Rotated blocks, bases on the pedestal, leaning out. Not one tall cylinder.
	local spikes = {
		{ angle = 0, lean = 16, height = 34, thick = 5.5, radius = 2.2 },
		{ angle = 60, lean = 22, height = 28, thick = 4.2, radius = 3.4 },
		{ angle = 120, lean = 14, height = 36, thick = 4.8, radius = 2.6 },
		{ angle = 180, lean = 20, height = 30, thick = 5, radius = 3.2 },
		{ angle = 240, lean = 18, height = 33, thick = 4.4, radius = 2.8 },
		{ angle = 300, lean = 24, height = 26, thick = 4, radius = 3.6 },
	}
	local shardColors = {
		Color3.fromRGB(176, 70, 255),
		Color3.fromRGB(130, 60, 240),
		Color3.fromRGB(210, 110, 255),
		Color3.fromRGB(150, 80, 255),
		Color3.fromRGB(190, 90, 255),
		Color3.fromRGB(120, 50, 220),
	}
	for index, spike in ipairs(spikes) do
		local yaw = math.rad(spike.angle)
		local lean = math.rad(spike.lean)
		local cf = CFrame.new(0, 2, 0)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.new(0, 0, spike.radius)
			* CFrame.Angles(lean, 0, 0)
			* CFrame.new(0, spike.height / 2, 0)
		part(
			parent,
			"CrystalShard",
			Vector3.new(spike.thick, spike.height, spike.thick),
			cf,
			shardColors[index],
			Enum.Material.Neon,
			true
		)
	end

	local crystal = part(
		parent,
		"LumenHeart",
		Vector3.new(6, 24, 6),
		CFrame.new(0, 14, 0),
		Color3.fromRGB(236, 220, 255),
		Enum.Material.Neon,
		true
	)
	part(
		parent,
		"Crack",
		Vector3.new(1.4, 16, 1.4),
		CFrame.new(1.2, 13, 0.4),
		Color3.fromRGB(210, 236, 255),
		Enum.Material.Neon,
		false
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(186, 140, 255)
	light.Range = 48
	light.Brightness = 2
	light.Parent = crystal
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 28)
	billboard.StudsOffset = Vector3.new(0, 16, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = crystal
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(226, 214, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = "Lumen Heart"
	label.Parent = billboard

	local shards = Instance.new("Folder")
	shards.Name = "Shards"
	shards.Parent = parent
	local pieces = {}
	for index = 1, 6 do
		local angle = (index - 1) * (math.pi * 2 / 6)
		local radius = 18 + (index % 3)
		local height = 16
		local shard = part(
			shards,
			"OrbitShard",
			Vector3.new(2.2, 6, 2.2),
			CFrame.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
				* CFrame.Angles(0, -angle, math.rad(18)),
			Color3.fromRGB(186, 130, 255),
			Enum.Material.Neon,
			false
		)
		table.insert(pieces, shard)
	end
	if orbitConnection ~= nil then
		orbitConnection:Disconnect()
	end
	local spin = 0
	print(string.format("[Shardfall] Lumen Heart orbit started (%d shards)", #pieces))
	orbitConnection = RunService.Heartbeat:Connect(function(dt)
		if crystal.Parent == nil then
			if orbitConnection ~= nil then
				orbitConnection:Disconnect()
				orbitConnection = nil
			end
			return
		end
		spin += dt * 0.35
		for index, shard in ipairs(pieces) do
			local angle = spin + (index - 1) * (math.pi * 2 / #pieces)
			local radius = 18 + (index % 3)
			local height = Haven.FLOOR_Y + 15 + math.sin(spin * 1.4 + index) * 4
			shard.CFrame = CFrame.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
				* CFrame.Angles(0, -angle, math.rad(20))
		end
	end)
end

local function buildPlaza(parent: Instance)
	island(parent, "BossPlaza", 0, 0, Haven.PLAZA_RADIUS, STONE, Enum.Material.Cobblestone)
	sign(parent, CFrame.new(0, 5, Haven.PLAZA_RADIUS - 6), "BOSS PLAZA", 16)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(Haven.SPAWN.x, Haven.FLOOR_Y + 0.5, Haven.SPAWN.z)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 0
	spawn.Enabled = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(186, 176, 140)
	spawn.Material = Enum.Material.Cobblestone
	spawn.Parent = parent

	local stand = part(
		parent,
		"Armory",
		Vector3.new(8, 6, 2),
		CFrame.new(Haven.ARMORY.x, 3, Haven.ARMORY.z),
		Color3.fromRGB(92, 78, 64),
		Enum.Material.Wood,
		true
	)
	part(
		parent,
		"Blade",
		Vector3.new(0.6, 5, 1.2),
		stand.CFrame * CFrame.new(0, 1, -1.2),
		Color3.fromRGB(196, 206, 214),
		Enum.Material.Metal,
		false,
		true
	)
	promptOn(stand, "Armory", "Weapons and armor", "armory", nil)
	sign(parent, CFrame.new(Haven.ARMORY.x, 8, Haven.ARMORY.z - 2), "ARMORY", 10)
end

local function buildForge(parent: Instance)
	local place = Haven.district("forge")
	assert(place ~= nil and place.radius ~= nil, "Forge is missing")
	local model = island(
		parent,
		"Forge",
		place.x,
		place.z,
		place.radius,
		Color3.fromRGB(54, 52, 58),
		Enum.Material.Slate
	)
	local hall = part(
		model,
		"Hall",
		Vector3.new(28, 16, 22),
		CFrame.new(place.x - 6, 8, place.z - 4),
		Color3.fromRGB(42, 40, 46),
		Enum.Material.Slate,
		true
	)
	part(
		model,
		"Roof",
		Vector3.new(30, 3, 24),
		hall.CFrame * CFrame.new(0, 9, 0),
		Color3.fromRGB(32, 30, 34),
		Enum.Material.Basalt,
		true,
		true
	)
	for index, offset in ipairs({ -8, 8 }) do
		part(
			model,
			"Chimney",
			Vector3.new(4, 10, 4),
			hall.CFrame * CFrame.new(offset, 14, -4),
			Color3.fromRGB(36, 34, 38),
			Enum.Material.Slate,
			true,
			true
		).Name = "Chimney"
			.. tostring(index)
	end
	local forge = stationPad(model, place.x, place.z, Color3.fromRGB(255, 120, 36))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 40)
	light.Range = 22
	light.Brightness = 1.5
	light.Parent = forge
	promptOn(forge, "Forge", "Craft, upgrade, reroll", "craft", nil)
	sign(model, CFrame.new(place.x, 8, place.z + 8), "FORGE", 12)
end

local function buildMarket(parent: Instance)
	local place = Haven.district("market")
	assert(place ~= nil and place.radius ~= nil, "Market is missing")
	local model =
		island(parent, "Market", place.x, place.z, place.radius, GRASS, Enum.Material.Grass)
	local awnings = {
		{ x = -10, z = -6, color = { 230, 80, 120 } },
		{ x = 10, z = -6, color = { 40, 180, 170 } },
		{ x = -10, z = 8, color = { 240, 180, 50 } },
		{ x = 10, z = 8, color = { 150, 80, 210 } },
	}
	for index, stall in ipairs(awnings) do
		local sx = place.x + stall.x
		local sz = place.z + stall.z
		part(
			model,
			"Stall" .. tostring(index),
			Vector3.new(8, 5, 6),
			CFrame.new(sx, 2.5, sz),
			Color3.fromRGB(120, 84, 58),
			Enum.Material.Wood,
			true
		)
		part(
			model,
			"Awning" .. tostring(index),
			Vector3.new(9, 0.6, 7),
			CFrame.new(sx, 5.4, sz),
			rgb(stall.color),
			Enum.Material.SmoothPlastic,
			false
		)
	end
	local shop = stationPad(model, place.x, place.z, Color3.fromRGB(255, 196, 80))
	promptOn(shop, "Coming Soon", "Daily shop", "soon", place.message)
	sign(model, CFrame.new(place.x, 8, place.z - place.radius + 6), "MARKET", 12)
end

local function buildGuild(parent: Instance)
	local place = Haven.district("guild")
	assert(place ~= nil and place.radius ~= nil, "Guild is missing")
	local model =
		island(parent, "GuildHall", place.x, place.z, place.radius, GRASS, Enum.Material.Grass)
	local hall = part(
		model,
		"Hall",
		Vector3.new(26, 18, 20),
		CFrame.new(place.x, 9, place.z - 4),
		Color3.fromRGB(226, 220, 206),
		Enum.Material.Limestone,
		true
	)
	part(
		model,
		"Roof",
		Vector3.new(28, 4, 22),
		hall.CFrame * CFrame.new(0, 11, 0),
		Color3.fromRGB(78, 112, 176),
		Enum.Material.Slate,
		true,
		true
	)
	part(
		model,
		"Door",
		Vector3.new(6, 8, 1),
		hall.CFrame * CFrame.new(0, -4, 10.5),
		Color3.fromRGB(64, 52, 40),
		Enum.Material.Wood,
		true,
		true
	)
	local closed = stationPad(model, place.x, place.z, Color3.fromRGB(180, 180, 190))
	promptOn(closed, "Coming Soon", "Guild Hall", "soon", place.message)
	sign(model, CFrame.new(place.x, 12, place.z + 12), "COMING SOON", 14)
end

local function buildGarden(parent: Instance)
	local place = Haven.district("garden")
	assert(place ~= nil and place.radius ~= nil, "Garden is missing")
	local model =
		island(parent, "PetGarden", place.x, place.z, place.radius, GRASS, Enum.Material.Grass)
	disc(
		model,
		"Pond",
		place.x + 6,
		0.35,
		place.z + 4,
		16,
		0.4,
		Color3.fromRGB(70, 160, 210),
		Enum.Material.Glass,
		false
	)
	local trees = { { -12, -6 }, { 4, -12 }, { -8, 10 } }
	for index, spot in ipairs(trees) do
		local tx = place.x + spot[1]
		local tz = place.z + spot[2]
		part(
			model,
			"Trunk",
			Vector3.new(2, 7, 2),
			CFrame.new(tx, 3.5, tz),
			Color3.fromRGB(110, 78, 52),
			Enum.Material.Wood,
			true
		)
		ball(
			model,
			"Canopy" .. tostring(index),
			tx,
			8,
			tz,
			8,
			Color3.fromRGB(240, 140, 180),
			Enum.Material.Grass
		)
	end
	local pets = stationPad(model, place.x, place.z, Color3.fromRGB(255, 150, 196))
	promptOn(pets, "Pets", "Companions", "pets", nil)
	sign(model, CFrame.new(place.x, 8, place.z - 10), "PET GARDEN", 14)
end

local function buildObservatory(parent: Instance)
	local place = Haven.district("observatory")
	assert(place ~= nil and place.radius ~= nil, "Observatory is missing")
	local model =
		island(parent, "Observatory", place.x, place.z, place.radius, STONE, Enum.Material.Slate)
	part(
		model,
		"Drum",
		Vector3.new(22, 12, 22),
		CFrame.new(place.x, 6, place.z),
		Color3.fromRGB(150, 156, 168),
		Enum.Material.Limestone,
		true
	)
	ball(model, "Dome", place.x, 14, place.z, 20, Color3.fromRGB(96, 124, 186), Enum.Material.Glass)
	part(
		model,
		"Scope",
		Vector3.new(2, 2, 10),
		CFrame.new(place.x + 4, 16, place.z) * CFrame.Angles(0, 0, math.rad(-28)),
		Color3.fromRGB(60, 64, 72),
		Enum.Material.Metal,
		false
	)
	local closed = stationPad(model, place.x, place.z, Color3.fromRGB(120, 160, 220))
	promptOn(closed, "Coming Soon", "Observatory", "soon", place.message)
	sign(model, CFrame.new(place.x, 8, place.z - 8), "COMING SOON", 12)
end

local function buildPortals(parent: Instance)
	local shelf = Instance.new("Model")
	shelf.Name = "RealmArches"
	shelf.Parent = parent
	part(
		shelf,
		"Ground",
		Vector3.new(390, 2, 52),
		CFrame.new(0, -1, 228),
		GRASS,
		Enum.Material.Grass,
		true
	)
	part(
		shelf,
		"Rock",
		Vector3.new(410, 10, 68),
		CFrame.new(0, -8, 228),
		Color3.fromRGB(92, 86, 78),
		Enum.Material.Rock,
		true
	)
	for _, portal in ipairs(Haven.PORTALS) do
		local color = rgb(portal.color :: { number })
		local arch = Instance.new("Model")
		arch.Name = portal.id
		arch.Parent = shelf
		part(
			arch,
			"PillarL",
			Vector3.new(3.5, 18, 3.5),
			CFrame.new(portal.x - 7, 9, portal.z),
			STONE,
			Enum.Material.Slate,
			true
		)
		part(
			arch,
			"PillarR",
			Vector3.new(3.5, 18, 3.5),
			CFrame.new(portal.x + 7, 9, portal.z),
			STONE,
			Enum.Material.Slate,
			true
		)
		part(
			arch,
			"Lintel",
			Vector3.new(18, 3, 4),
			CFrame.new(portal.x, 19.5, portal.z),
			STONE,
			Enum.Material.Slate,
			true
		)
		local fill = part(
			arch,
			"Glow",
			Vector3.new(10, 14, 0.8),
			CFrame.new(portal.x, 9, portal.z),
			color,
			Enum.Material.Neon,
			false
		)
		fill.CanTouch = portal.open == true
		if portal.open == true then
			fill.Name = "EnterPad"
			fill:SetAttribute("EnterDungeon", portal.dungeonId or Dungeons.ROOTVAULT_ID)
			promptOn(fill, "Enter", portal.name, "rootvault", nil)
		else
			part(
				arch,
				"Seal",
				Vector3.new(10, 1.4, 1.4),
				CFrame.new(portal.x, 9, portal.z),
				Color3.fromRGB(36, 34, 40),
				Enum.Material.Metal,
				true
			)
			promptOn(fill, "Coming Soon", portal.name, "soon", portal.message)
		end
		sign(arch, CFrame.new(portal.x, 23, portal.z), string.upper(portal.name), 16)
	end
end

local function link(
	parent: Instance,
	x1: number,
	z1: number,
	r1: number,
	x2: number,
	z2: number,
	r2: number
)
	local ax, az = approach(x1, z1, x2, z2, r1)
	local bx, bz = approach(x2, z2, x1, z1, r2)
	bridge(parent, ax, az, bx, bz)
end

local function buildBridges(parent: Instance)
	local market = Haven.district("market")
	local forge = Haven.district("forge")
	local guild = Haven.district("guild")
	local garden = Haven.district("garden")
	local observatory = Haven.district("observatory")
	assert(market ~= nil and market.radius ~= nil, "Market is missing")
	assert(forge ~= nil and forge.radius ~= nil, "Forge is missing")
	assert(guild ~= nil and guild.radius ~= nil, "Guild is missing")
	assert(garden ~= nil and garden.radius ~= nil, "Garden is missing")
	assert(observatory ~= nil and observatory.radius ~= nil, "Observatory is missing")
	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = parent
	link(bridges, 0, 0, Haven.PLAZA_RADIUS, market.x, market.z, market.radius)
	link(bridges, market.x, market.z, market.radius, forge.x, forge.z, forge.radius)
	link(bridges, 0, 0, Haven.PLAZA_RADIUS, guild.x, guild.z, guild.radius)
	link(bridges, 0, 0, Haven.PLAZA_RADIUS, garden.x, garden.z, garden.radius)
	link(bridges, 0, 0, Haven.PLAZA_RADIUS, observatory.x, observatory.z, observatory.radius)
	link(bridges, 0, 0, Haven.PLAZA_RADIUS, 0, 228, 26)
end

local function buildRocks(parent: Instance)
	local rocks = {
		{ -70, 8, -80, 10 },
		{ 90, 14, -40, 8 },
		{ -40, 6, 140, 7 },
		{ 230, 10, 20, 9 },
	}
	for index, rock in ipairs(rocks) do
		ball(
			parent,
			"Floater" .. tostring(index),
			rock[1],
			rock[2],
			rock[3],
			rock[4],
			Color3.fromRGB(110, 104, 96),
			Enum.Material.Rock
		)
	end
end

local function clearDefaultPlace()
	local plate = workspace:FindFirstChild("Baseplate")
	if plate ~= nil then
		pcall(function()
			plate:Destroy()
		end)
		if plate.Parent ~= nil and plate:IsA("BasePart") then
			pcall(function()
				plate.Anchored = true
				plate.CanCollide = false
				plate.Transparency = 1
			end)
			print("[Shardfall] Default Baseplate could not be destroyed; it was hidden")
		else
			print("[Shardfall] Default Baseplate removed")
		end
	end

	local doomed = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") and descendant.Name ~= "HubSpawn" then
			table.insert(doomed, descendant)
		end
	end
	for _, spawn in ipairs(doomed) do
		pcall(function()
			spawn:Destroy()
		end)
		if spawn.Parent ~= nil and spawn:IsA("SpawnLocation") then
			pcall(function()
				spawn.Enabled = false
				spawn.CanCollide = false
				spawn.Transparency = 1
			end)
		end
	end
	if #doomed > 0 then
		print(string.format("[Shardfall] Removed %d default SpawnLocation", #doomed))
	end
end

function HavenBuilder.build(parent: Instance): number
	-- Persistent before parenting, and a direct Workspace child. Kevin's
	-- Explorer showed Camera, Terrain, and Baseplate, with no Haven.
	if parent:IsA("Model") then
		parent.Parent = nil
		parent.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		parent.Parent = workspace
	end

	clearDefaultPlace()
	buildPlaza(parent)
	buildCrystal(parent)
	buildForge(parent)
	buildMarket(parent)
	buildGuild(parent)
	buildGarden(parent)
	buildObservatory(parent)
	buildPortals(parent)
	buildBridges(parent)
	buildRocks(parent)
	clearDefaultPlace()

	local count = 0
	local prompts = 0
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		elseif descendant:IsA("ProximityPrompt") then
			prompts += 1
			local action = descendant:GetAttribute("HavenAction")
			descendant.Triggered:Connect(function(player)
				print(
					string.format(
						"[Shardfall] Server saw prompt %s from %s",
						tostring(action),
						player.Name
					)
				)
			end)
		end
	end
	print(
		string.format(
			"[Shardfall] Haven built under %s at floor y=%d (%d prompts)",
			parent.Name,
			Haven.FLOOR_Y,
			prompts
		)
	)
	return count
end

function HavenBuilder.bindRootvault(callback: (Player) -> ())
	local haven = workspace:FindFirstChild("Haven")
	if haven == nil then
		warn("[Shardfall] Haven model missing; Verdant prompt not bound")
		return
	end
	local bound = 0
	for _, descendant in ipairs(haven:GetDescendants()) do
		if
			descendant:IsA("ProximityPrompt")
			and descendant:GetAttribute("HavenAction") == "rootvault"
		then
			bound += 1
			descendant.Triggered:Connect(function(player)
				print("[Shardfall] Server rootvault prompt from", player.Name)
				callback(player)
			end)
		end
	end
	print(string.format("[Shardfall] Rootvault prompts bound: %d", bound))
end

return HavenBuilder
