--!strict

--[[
	Builds the Haven blockout from Haven.luau.

	Simple parts, themed colors, and a low count. The crystal's shards orbit
	on a heartbeat. ProximityPrompts carry HavenAction so the client can open
	the existing panel, and the Verdant arch is also an EnterPad for the
	Rootvault.

	StreamingEnabled cannot be set from a script. It lives on Workspace in
	default.project.json. Writing it here used to throw before the first part
	existed, which also skipped the profile load. The hub model is Persistent
	so the islands stay replicated at spawn. Crawl rooms are outside this
	model and stream in when the player is teleported.
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
	collide: boolean
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Anchored = true
	piece.CanCollide = collide
	piece.CanTouch = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Color = color
	piece.Material = material
	piece.Parent = parent
	return piece
end

local function disc(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	z: number,
	diameter: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	local piece = part(
		parent,
		name,
		Vector3.new(thickness, diameter, diameter),
		CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		collide
	)
	piece.Shape = Enum.PartType.Cylinder
	return piece
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

local function bridge(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local dx = x2 - x1
	local dz = z2 - z1
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 2 then
		return
	end
	local mid = Vector3.new((x1 + x2) / 2, 0.4, (z1 + z2) / 2)
	local piece = part(
		parent,
		"Bridge",
		Vector3.new(14, 1, distance),
		CFrame.lookAt(mid, Vector3.new(x2, 0.4, z2)),
		Color3.fromRGB(126, 122, 116),
		Enum.Material.Cobblestone,
		true
	)
	piece.Name = "Bridge"
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
	disc(model, "Ground", x, -1, z, radius * 2, 2, top, topMaterial, true)
	disc(
		model,
		"Rock",
		x,
		-8,
		z,
		radius * 2 + 8,
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
	return disc(parent, "Station", px, 0.4, pz, 8, 0.8, color, Enum.Material.Neon, false)
end

local STONE = Color3.fromRGB(138, 136, 130)
local GRASS = Color3.fromRGB(78, 148, 72)

local function buildCrystal(parent: Instance)
	local pedestal = disc(parent, "Pedestal", 0, 1, 0, 18, 2, STONE, Enum.Material.Slate, true)
	pedestal.Name = "Pedestal"
	local crystal = part(
		parent,
		"LumenHeart",
		Vector3.new(10, Haven.CRYSTAL.height, 10),
		CFrame.new(0, 4 + Haven.CRYSTAL.height / 2, 0) * CFrame.Angles(0, math.rad(18), math.rad(8)),
		Color3.fromRGB(168, 90, 255),
		Enum.Material.Neon,
		true
	)
	local crack = part(
		parent,
		"Crack",
		Vector3.new(2.2, Haven.CRYSTAL.height * 0.72, 2.2),
		crystal.CFrame * CFrame.new(1.5, -2, 0),
		Color3.fromRGB(210, 236, 255),
		Enum.Material.Neon,
		false
	)
	crack.Name = "Crack"
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(186, 140, 255)
	light.Range = 48
	light.Brightness = 2
	light.Parent = crystal
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 28)
	billboard.StudsOffset = Vector3.new(0, Haven.CRYSTAL.height / 2 + 2, 0)
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
		local shard = ball(
			shards,
			"Shard",
			0,
			20,
			0,
			2.4 + (index % 2),
			Color3.fromRGB(186, 120, 255),
			Enum.Material.Neon
		)
		table.insert(pieces, shard)
	end
	if orbitConnection ~= nil then
		orbitConnection:Disconnect()
	end
	local spin = 0
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
			local radius = 16 + (index % 3)
			local height = 16 + math.sin(spin * 1.4 + index) * 3
			shard.CFrame = CFrame.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		end
	end)
end

local function buildPlaza(parent: Instance)
	island(parent, "BossPlaza", 0, 0, Haven.PLAZA_RADIUS, STONE, Enum.Material.Cobblestone)
	sign(parent, CFrame.new(0, 5, Haven.PLAZA_RADIUS - 6), "BOSS PLAZA", 16)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(Haven.SPAWN.x, 0.5, Haven.SPAWN.z)
	spawn.Anchored = true
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
		false
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
		true
	)
	part(
		model,
		"Door",
		Vector3.new(6, 8, 1),
		hall.CFrame * CFrame.new(0, -4, 10.5),
		Color3.fromRGB(64, 52, 40),
		Enum.Material.Wood,
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
		0.3,
		place.z + 4,
		16,
		0.6,
		Color3.fromRGB(70, 160, 210),
		Enum.Material.Glass,
		false
	)
	local trees = { { -12, -6 }, { 4, -12 }, { -8, 10 } }
	for index, spot in ipairs(trees) do
		local tx = place.x + spot[1]
		local tz = place.z + spot[2]
		local trunk = part(
			model,
			"Trunk",
			Vector3.new(7, 1.6, 1.6),
			CFrame.new(tx, 3.5, tz) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(110, 78, 52),
			Enum.Material.Wood,
			true
		)
		trunk.Shape = Enum.PartType.Cylinder
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
	local drum = disc(
		model,
		"Drum",
		place.x,
		6,
		place.z,
		22,
		12,
		Color3.fromRGB(150, 156, 168),
		Enum.Material.Limestone,
		true
	)
	drum.Name = "Drum"
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
			Vector3.new(2, 12, 2),
			CFrame.new(portal.x - 6, 6, portal.z),
			STONE,
			Enum.Material.Slate,
			true
		)
		part(
			arch,
			"PillarR",
			Vector3.new(2, 12, 2),
			CFrame.new(portal.x + 6, 6, portal.z),
			STONE,
			Enum.Material.Slate,
			true
		)
		part(
			arch,
			"Lintel",
			Vector3.new(16, 2, 2),
			CFrame.new(portal.x, 13, portal.z),
			STONE,
			Enum.Material.Slate,
			true
		)
		local fill = part(
			arch,
			"Glow",
			Vector3.new(10, 10, 0.6),
			CFrame.new(portal.x, 6.5, portal.z),
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
				Vector3.new(10, 1.2, 1.2),
				CFrame.new(portal.x, 6.5, portal.z),
				Color3.fromRGB(36, 34, 40),
				Enum.Material.Metal,
				true
			)
			promptOn(fill, "Coming Soon", portal.name, "soon", portal.message)
		end
		sign(arch, CFrame.new(portal.x, 16.5, portal.z), string.upper(portal.name), 14)
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

local function hideForeignSpawns()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") and descendant.Name ~= "HubSpawn" then
			descendant.Enabled = false
			descendant.Transparency = 1
			descendant.CanCollide = false
		end
	end
end

function HavenBuilder.build(parent: Instance): number
	if parent:IsA("Model") then
		parent.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end

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
	hideForeignSpawns()

	local count = 0
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

function HavenBuilder.bindRootvault(callback: (Player) -> ())
	local world = workspace:FindFirstChild("ShardfallWorld")
	if world == nil then
		return
	end
	for _, descendant in ipairs(world:GetDescendants()) do
		if
			descendant:IsA("ProximityPrompt")
			and descendant:GetAttribute("HavenAction") == "rootvault"
		then
			descendant.Triggered:Connect(function(player)
				callback(player)
			end)
		end
	end
end

return HavenBuilder
