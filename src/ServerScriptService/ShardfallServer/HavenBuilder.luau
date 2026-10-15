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
local VerdantScatter = require(ReplicatedStorage.Shared.VerdantScatter)

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

-- Billboard, not a SurfaceGui board. A board on the walk was readable as
-- giant letters and could sit where a bridge belonged. This anchor does not
-- collide, and the text stays a fixed screen size.
local function sign(parent: Instance, cframe: CFrame, text: string)
	local anchor = part(
		parent,
		"Sign",
		Vector3.new(0.4, 0.4, 0.4),
		cframe,
		Color3.fromRGB(48, 42, 36),
		Enum.Material.Wood,
		false
	)
	anchor.Transparency = 1
	anchor:SetAttribute("HavenLabel", text)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(math.max(140, #text * 11), 32)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 420
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(236, 226, 190)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
end

-- Far side of an island, past the center, so the label is not on the bridge.
local function labelBehind(parent: Instance, x: number, z: number, reach: number, text: string)
	local distance = math.sqrt(x * x + z * z)
	local bx = x
	local bz = z - reach
	if distance > 1 then
		bx = x + x / distance * reach
		bz = z + z / distance * reach
	end
	sign(parent, CFrame.new(bx, 16, bz), text)
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
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.MaxIndicatorDistance = 24
	prompt:SetAttribute("HavenAction", action)
	if message ~= nil then
		prompt:SetAttribute("HavenMessage", message)
	end
	prompt.Parent = host
end

-- Keep overlapping faces this far apart. Coplanar tops flicker in Studio.
local SEAM = 0.08
local BRIDGE_WIDTH = 14
local BRIDGE_THICKNESS = 4
local FLOOR_TOP = 0
local SHELF_DEPTH = 24
local TONGUE = 6

-- Top stays put. The bottom sinks SEAM into the floor so the contact faces
-- are not coplanar.
local function sunk(top: number, height: number): (number, number)
	local sizeY = height + SEAM
	return sizeY, top - sizeY / 2
end

local function faceDistance(halfX: number, halfZ: number, dirX: number, dirZ: number): number
	local tx = if math.abs(dirX) > 1e-6 then halfX / math.abs(dirX) else math.huge
	local tz = if math.abs(dirZ) > 1e-6 then halfZ / math.abs(dirZ) else math.huge
	return math.min(tx, tz)
end

-- True when the bridge end still cuts the floor rectangle.
local function endHits(
	dirX: number,
	dirZ: number,
	rightX: number,
	rightZ: number,
	distance: number,
	halfX: number,
	halfZ: number,
	width: number
): boolean
	local midX = dirX * distance
	local midZ = dirZ * distance
	local x1 = midX + rightX * (-width / 2)
	local z1 = midZ + rightZ * (-width / 2)
	local x2 = midX + rightX * (width / 2)
	local z2 = midZ + rightZ * (width / 2)
	local dx = x2 - x1
	local dz = z2 - z1
	local t0 = 0
	local t1 = 1
	local function clip(p: number, q: number): boolean
		if math.abs(p) < 1e-9 then
			return q >= 0
		end
		local r = q / p
		if p < 0 then
			if r > t1 then
				return false
			end
			if r > t0 then
				t0 = r
			end
		else
			if r < t0 then
				return false
			end
			if r < t1 then
				t1 = r
			end
		end
		return true
	end
	if not clip(-dx, x1 + halfX) then
		return false
	end
	if not clip(dx, halfX - x1) then
		return false
	end
	if not clip(-dz, z1 + halfZ) then
		return false
	end
	if not clip(dz, halfZ - z1) then
		return false
	end
	return t1 > t0 + 1e-4
end

-- How far from a floor center the full bridge width is clear of that floor.
local function clearance(
	dirX: number,
	dirZ: number,
	halfX: number,
	halfZ: number,
	width: number
): number
	local rightX = -dirZ
	local rightZ = dirX
	local lo = 0
	local hi = math.max(halfX, halfZ) * 2 + width
	for _ = 1, 28 do
		local mid = (lo + hi) / 2
		if endHits(dirX, dirZ, rightX, rightZ, mid, halfX, halfZ, width) then
			lo = mid
		else
			hi = mid
		end
	end
	return hi
end

local function oriented(
	parent: Instance,
	name: string,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	yTop: number
)
	local dx = x2 - x1
	local dz = z2 - z1
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.2 then
		return
	end
	local yCenter = yTop - BRIDGE_THICKNESS / 2
	local cf = CFrame.lookAt(
		Vector3.new((x1 + x2) / 2, yCenter, (z1 + z2) / 2),
		Vector3.new(x2, yCenter, z2)
	)
	part(
		parent,
		name,
		Vector3.new(BRIDGE_WIDTH, BRIDGE_THICKNESS, length),
		cf,
		Color3.fromRGB(126, 122, 116),
		Enum.Material.Cobblestone,
		true
	)
end

-- Flush deck stops at each rim. A tongue tucks under the floor, lower by
-- SEAM, so the overlap still holds a foot and the tops do not flicker.
local function bridge(
	parent: Instance,
	x1: number,
	z1: number,
	halfX1: number,
	halfZ1: number,
	x2: number,
	z2: number,
	halfX2: number,
	halfZ2: number,
	slot: number
)
	local dx = x2 - x1
	local dz = z2 - z1
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1 then
		return
	end
	local dirX = dx / distance
	local dirZ = dz / distance
	local clear1 = clearance(dirX, dirZ, halfX1, halfZ1, BRIDGE_WIDTH)
	local clear2 = clearance(-dirX, -dirZ, halfX2, halfZ2, BRIDGE_WIDTH)
	local face1 = faceDistance(halfX1, halfZ1, dirX, dirZ)
	local face2 = faceDistance(halfX2, halfZ2, -dirX, -dirZ)
	local deckAX = x1 + dirX * clear1
	local deckAZ = z1 + dirZ * clear1
	local deckBX = x2 - dirX * clear2
	local deckBZ = z2 - dirZ * clear2
	oriented(parent, "Landing", deckAX, deckAZ, deckBX, deckBZ, FLOOR_TOP)
	-- Each tongue sits a little lower than the last so two tongues that
	-- cross under the plaza do not share a top either.
	local tongueDrop = SEAM + (slot - 1) * 0.02
	local start1 = math.max(0, face1 - TONGUE)
	local start2 = math.max(0, face2 - TONGUE)
	oriented(
		parent,
		"Bridge",
		x1 + dirX * start1,
		z1 + dirZ * start1,
		x2 - dirX * start2,
		z2 - dirZ * start2,
		FLOOR_TOP - tongueDrop
	)
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
		FLOOR_TOP - 8 - SEAM,
		z,
		radius * 2 + 16,
		12,
		Color3.fromRGB(92, 86, 78),
		Enum.Material.Rock,
		true
	)
	return model
end

local function stationPad(
	parent: Instance,
	x: number,
	z: number,
	color: Color3,
	diameter: number?
): Part
	local dx = -x
	local dz = -z
	local distance = math.sqrt(dx * dx + dz * dz)
	local px = x
	local pz = z
	if distance > 1 then
		px = x + dx / distance * 8
		pz = z + dz / distance * 8
	end
	local size = diameter or 9
	return disc(
		parent,
		"Station",
		px,
		0.45,
		pz,
		size,
		0.45 + SEAM,
		color,
		Enum.Material.Neon,
		false
	)
end

local STONE = Color3.fromRGB(138, 136, 130)
local GRASS = Color3.fromRGB(78, 148, 72)

local function buildCrystal(parent: Instance)
	disc(parent, "Pedestal", 0, 2, 0, 22, 2 + SEAM, STONE, Enum.Material.Slate, true)

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
		CFrame.new(0, 14 - SEAM, 0),
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
	sign(parent, CFrame.new(0, 14, -Haven.PLAZA_RADIUS + 12), "Boss Plaza")
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(12, 1 + SEAM, 12)
	spawn.CFrame = CFrame.new(Haven.SPAWN.x, Haven.FLOOR_Y + 1 - (1 + SEAM) / 2, Haven.SPAWN.z)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 0
	spawn.Enabled = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(186, 176, 140)
	spawn.Material = Enum.Material.Cobblestone
	spawn.Parent = parent

	local armoryHeight, armoryCenter = sunk(6, 6)
	local stand = part(
		parent,
		"Armory",
		Vector3.new(8, armoryHeight, 2),
		CFrame.new(Haven.ARMORY.x, armoryCenter, Haven.ARMORY.z),
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
	local pad = disc(
		parent,
		"Station",
		Haven.ARMORY.x,
		0.45,
		Haven.ARMORY.z + 6,
		12,
		0.45 + SEAM,
		Color3.fromRGB(212, 176, 96),
		Enum.Material.Neon,
		false
	)
	promptOn(pad, "Armory", "Weapons and armor", "armory", nil)
	sign(parent, CFrame.new(Haven.ARMORY.x, 12, Haven.ARMORY.z), "Armory")
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
	local hallHeight, hallCenter = sunk(16, 16)
	local hall = part(
		model,
		"Hall",
		Vector3.new(28, hallHeight, 22),
		CFrame.new(place.x - 6, hallCenter, place.z - 4),
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
	labelBehind(model, place.x, place.z, place.radius * 0.62, "Forge")
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
	local stallHeight, stallCenter = sunk(5, 5)
	for index, stall in ipairs(awnings) do
		local sx = place.x + stall.x
		local sz = place.z + stall.z
		part(
			model,
			"Stall" .. tostring(index),
			Vector3.new(8, stallHeight, 6),
			CFrame.new(sx, stallCenter, sz),
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
	labelBehind(model, place.x, place.z, place.radius * 0.62, "Market")
end

local function buildGuild(parent: Instance)
	local place = Haven.district("guild")
	assert(place ~= nil and place.radius ~= nil, "Guild is missing")
	local model =
		island(parent, "GuildHall", place.x, place.z, place.radius, GRASS, Enum.Material.Grass)
	local hallHeight, hallCenter = sunk(18, 18)
	local hall = part(
		model,
		"Hall",
		Vector3.new(26, hallHeight, 20),
		CFrame.new(place.x, hallCenter, place.z - 4),
		Color3.fromRGB(226, 220, 206),
		Enum.Material.Limestone,
		true
	)
	part(
		model,
		"Roof",
		Vector3.new(28, 4, 22),
		hall.CFrame * CFrame.new(0, 11 + SEAM * 1.5, 0),
		Color3.fromRGB(78, 112, 176),
		Enum.Material.Slate,
		true,
		true
	)
	part(
		model,
		"Door",
		Vector3.new(6, 8, 1),
		hall.CFrame * CFrame.new(0, -4, 10.5 + SEAM),
		Color3.fromRGB(64, 52, 40),
		Enum.Material.Wood,
		true,
		true
	)
	local closed = stationPad(model, place.x, place.z, Color3.fromRGB(180, 180, 190))
	promptOn(closed, "Coming Soon", "Guild Hall", "soon", place.message)
	labelBehind(model, place.x, place.z, place.radius * 0.62, "Guild Hall")
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
		0.35 + SEAM,
		Color3.fromRGB(70, 160, 210),
		Enum.Material.Glass,
		false
	)
	local trunkHeight, trunkCenter = sunk(7, 7)
	local trees = { { -12, -6 }, { 4, -12 }, { -8, 10 } }
	for index, spot in ipairs(trees) do
		local tx = place.x + spot[1]
		local tz = place.z + spot[2]
		part(
			model,
			"Trunk",
			Vector3.new(2, trunkHeight, 2),
			CFrame.new(tx, trunkCenter, tz),
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
	local pets = stationPad(model, place.x, place.z, Color3.fromRGB(255, 150, 196), 12)
	promptOn(pets, "Pets", "Companions", "pets", nil)
	labelBehind(model, place.x, place.z, place.radius * 0.62, "Pet Garden")
end

local function buildObservatory(parent: Instance)
	local place = Haven.district("observatory")
	assert(place ~= nil and place.radius ~= nil, "Observatory is missing")
	local model =
		island(parent, "Observatory", place.x, place.z, place.radius, STONE, Enum.Material.Slate)
	local drumHeight, drumCenter = sunk(12, 12)
	part(
		model,
		"Drum",
		Vector3.new(22, drumHeight, 22),
		CFrame.new(place.x, drumCenter, place.z),
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
	labelBehind(model, place.x, place.z, place.radius * 0.62, "Observatory")
end

-- Center x, center z, and width of the realm shelf. Bridges use the same span.
local function shelfLayout(): (number, number, number)
	local minX = math.huge
	local maxX = -math.huge
	local shelfZ = Haven.PORTALS[1].z
	for _, portal in ipairs(Haven.PORTALS) do
		minX = math.min(minX, portal.x)
		maxX = math.max(maxX, portal.x)
		shelfZ = portal.z
	end
	return 0, shelfZ, (maxX - minX) + 48
end

local function buildPortals(parent: Instance)
	local shelf = Instance.new("Model")
	shelf.Name = "RealmArches"
	shelf.Parent = parent
	local shelfX, shelfZ, width = shelfLayout()
	part(
		shelf,
		"Ground",
		Vector3.new(width, 4, SHELF_DEPTH),
		CFrame.new(shelfX, -2, shelfZ),
		GRASS,
		Enum.Material.Grass,
		true
	)
	part(
		shelf,
		"Rock",
		Vector3.new(width + 16, 10, SHELF_DEPTH + 16),
		CFrame.new(shelfX, -9 - SEAM, shelfZ),
		Color3.fromRGB(92, 86, 78),
		Enum.Material.Rock,
		true
	)
	local pillarHeight, pillarCenter = sunk(18, 18)
	for _, portal in ipairs(Haven.PORTALS) do
		local color = rgb(portal.color :: { number })
		local arch = Instance.new("Model")
		arch.Name = portal.id
		arch.Parent = shelf
		part(
			arch,
			"PillarL",
			Vector3.new(3.5, pillarHeight, 3.5),
			CFrame.new(portal.x - 7, pillarCenter, portal.z),
			STONE,
			Enum.Material.Slate,
			true
		)
		part(
			arch,
			"PillarR",
			Vector3.new(3.5, pillarHeight, 3.5),
			CFrame.new(portal.x + 7, pillarCenter, portal.z),
			STONE,
			Enum.Material.Slate,
			true
		)
		part(
			arch,
			"Lintel",
			Vector3.new(18, 3, 4),
			CFrame.new(portal.x, 19.5 + SEAM, portal.z),
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
				Vector3.new(10 - SEAM * 2, 1.4, 1.4),
				CFrame.new(portal.x, 9, portal.z),
				Color3.fromRGB(36, 34, 40),
				Enum.Material.Metal,
				true
			)
			promptOn(fill, "Coming Soon", portal.name, "soon", portal.message)
		end
		sign(arch, CFrame.new(portal.x, 24, portal.z), portal.name)
	end
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
	local plaza = Haven.PLAZA_RADIUS
	local shelfX, shelfZ, shelfWidth = shelfLayout()
	-- Squares: the walkable face is the full half-extent, not the inscribed circle.
	bridge(bridges, 0, 0, plaza, plaza, forge.x, forge.z, forge.radius, forge.radius, 1)
	bridge(bridges, 0, 0, plaza, plaza, market.x, market.z, market.radius, market.radius, 2)
	bridge(bridges, 0, 0, plaza, plaza, guild.x, guild.z, guild.radius, guild.radius, 3)
	bridge(bridges, 0, 0, plaza, plaza, garden.x, garden.z, garden.radius, garden.radius, 4)
	bridge(
		bridges,
		0,
		0,
		plaza,
		plaza,
		observatory.x,
		observatory.z,
		observatory.radius,
		observatory.radius,
		5
	)
	bridge(bridges, 0, 0, plaza, plaza, shelfX, shelfZ, shelfWidth / 2, SHELF_DEPTH / 2, 6)
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

local function dressHaven(parent: Instance)
	local foliage = Instance.new("Model")
	foliage.Name = "Foliage"
	foliage.Parent = parent
	for _, desc in ipairs(VerdantScatter.haven()) do
		local className = if desc.className == "WedgePart" then "WedgePart" else "Part"
		local piece = Instance.new(className)
		piece.Name = desc.name
		piece.Size = Vector3.new(desc.size[1], desc.size[2], desc.size[3])
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CanQuery = false
		piece.CastShadow = desc.shadow == true
		piece.Transparency = desc.transparency
		piece.Color = Color3.fromRGB(desc.color[1], desc.color[2], desc.color[3])
		piece.Material = (Enum.Material :: any)[desc.material]
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		if desc.shape == "Ball" and piece:IsA("Part") then
			piece.Shape = Enum.PartType.Ball
		end
		local spun = CFrame.new(desc.x, desc.y, desc.z) * CFrame.Angles(desc.rx, desc.ry, desc.rz)
		piece.CFrame = spun + Vector3.new(0, Haven.FLOOR_Y, 0)
		piece:SetAttribute("ShardfallLod", desc.lod)
		piece.Parent = foliage
		if desc.light then
			local light = Instance.new("PointLight")
			light.Color = piece.Color
			light.Brightness = 1.2
			light.Range = 10
			light.Shadows = false
			light.Parent = piece
		end
		if desc.particle ~= nil then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = desc.particle
			emitter.Rate = 4
			emitter.LightEmission = 0.7
			emitter.Parent = piece
		end
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
	dressHaven(parent)
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
