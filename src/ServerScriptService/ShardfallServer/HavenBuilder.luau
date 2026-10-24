--!strict

--[[
	Builds the Haven blockout from Haven.luau.

	Simple parts, themed colors, and a low count. The crystal's shards orbit
	on a heartbeat. ProximityPrompts carry HavenAction so the client can open
	the existing panel. The Rootvault arch is an EnterPad. While raids are
	closed the Heartwood arch is sealed and its prompt says Heartwood opens later.
	Finder and Practice appear only when LaunchGate.raids is on. It is not
	an EnterPad. Milestone 2 dresses each arch and its name plate. Milestone 3
	puts one shadowless light in each mouth, a quiet emitter under the forge
	rate cap, and a flat court ring. An open mouth pulses. A sealed mouth
	stays dim until someone stands close. Open versus sealed follows
	Haven.gateShownOpen. Global Lighting
	is left on the day cycle. No new sound id.

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
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local SavedWorld = require(ReplicatedStorage.Shared.SavedWorld)
local HavenLife = require(ReplicatedStorage.Shared.HavenLife)
local ShellLayout = require(ReplicatedStorage.Shared.ShellLayout)
local Travel = require(ReplicatedStorage.Shared.Travel)
local VerdantScatter = require(ReplicatedStorage.Shared.VerdantScatter)

local HavenBuilder = {}

local orbitConnection: RBXScriptConnection? = nil
local lifeConnection: RBXScriptConnection? = nil
local gateConnection: RBXScriptConnection? = nil
-- One Story queue per second. The dungeon enter debounce lives in DungeonService.
local heartwoodReadyAt: { [number]: number } = {}
local wavesReadyAt: { [number]: number } = {}
local practiceReadyAt: { [number]: number } = {}

local function rgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

-- One template per class. Repeated dressing clones it instead of building
-- a fresh instance and retyping every default.
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

local TRIM = {
	Flower = true,
	Petals = true,
	Butterflies = true,
	Cloud = true,
	Crate = true,
	AwningStripe = true,
}

-- These stay opaque on every tier. Sky shards and the fall lip used to be
-- trim, so a med budget could drop them with the flowers.
local KEEP_PIECE = {
	Waterfall = true,
	FallLip = true,
	SkyShard = true,
	StarBeam = true,
}

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
	piece:SetAttribute("ShardfallSizeX", piece.Size.X)
	piece:SetAttribute("ShardfallSizeY", piece.Size.Y)
	piece:SetAttribute("ShardfallSizeZ", piece.Size.Z)
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
	gui.Size = UDim2.fromOffset(160, 36)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = ShellLayout.ZONE_MAX_DISTANCE
	gui.DistanceLowerLimit = 0
	gui.DistanceUpperLimit = ShellLayout.ZONE_MAX_DISTANCE
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
	label.BackgroundTransparency = 0.15
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(244, 240, 252)
	label.TextStrokeColor3 = Color3.fromRGB(24, 18, 12)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
end

-- Two-line gate name. Bold ink on a dark plate, readable from the spawn pad.
-- District signs stay on `sign` and die at the zone distance.
local PLATE_INK = Color3.fromRGB(248, 244, 230)
local PLATE_INK_STROKE = Color3.fromRGB(8, 6, 4)
local PLATE_BACK = Color3.fromRGB(10, 8, 12)

local function gatePlate(parent: Instance, cframe: CFrame, title: string, subline: string)
	local anchor = part(
		parent,
		"Sign",
		Vector3.new(0.4, 0.4, 0.4),
		cframe,
		PLATE_BACK,
		Enum.Material.SmoothPlastic,
		false
	)
	anchor.Transparency = 1
	anchor:SetAttribute("HavenLabel", title)
	anchor:SetAttribute("HavenSubline", subline)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(300, 84)
	gui.StudsOffset = Vector3.new(0, 1.4, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = Haven.NAMEPLATE_DISTANCE
	gui.DistanceLowerLimit = 0
	gui.DistanceUpperLimit = Haven.NAMEPLATE_DISTANCE
	gui.Parent = anchor
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = PLATE_BACK
	plate.BackgroundTransparency = 0.05
	plate.BorderSizePixel = 0
	plate.Parent = gui
	local function line(name: string, text: string, y: number, height: number, textSize: number)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, height)
		label.Position = UDim2.fromScale(0, y)
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = textSize
		label.TextColor3 = PLATE_INK
		label.TextStrokeColor3 = PLATE_INK_STROKE
		label.TextStrokeTransparency = 0
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Text = text
		label.Parent = plate
	end
	line("Title", title, 0.04, 0.56, 28)
	line("Subline", subline, 0.56, 0.38, 18)
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
	message: string?,
	district: string?,
	reach: number?
)
	if not LaunchGate.promptOpen(action) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = reach or 18
	prompt.RequiresLineOfSight = false
	prompt.MaxIndicatorDistance = if reach ~= nil then reach + 2 else 24
	prompt:SetAttribute("HavenAction", action)
	if message ~= nil then
		prompt:SetAttribute("HavenMessage", message)
	end
	if type(district) == "string" then
		prompt:SetAttribute("HavenDistrict", district)
	end
	prompt.Parent = host
end

-- Keep overlapping faces this far apart. Coplanar tops flicker in Studio.
local SEAM = 0.08
local BRIDGE_WIDTH = 14
local BRIDGE_THICKNESS = 4
local FLOOR_TOP = 0
local TONGUE = 6
-- Square the rim bridge treats as its near floor. The court slab is larger.
local RIM_HALF = 8

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

-- Deck stops at each rim and sits Haven.LAYER above the island floor so the
-- cobble overlay does not share that top. A tongue tucks under the floor,
-- lower by SEAM, so the overlap still holds a foot.
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
	-- Darker cobble deck over the lighter island floor. Same top Y flickers
	-- along the walk toward the crystal, so the overlay sits up by LAYER.
	oriented(parent, "Landing", deckAX, deckAZ, deckBX, deckBZ, FLOOR_TOP + Haven.LAYER)
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
	-- The skirt hangs 8 studs under the walk and sticks out 8 studs past the rim.
	-- A solid skirt is a ledge the default jump cannot climb, and the hub
	-- rescue does not fire until the player is far below the island. The rock
	-- stays visible. Walking off the rim falls through it.
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
		false
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
		Enum.Material.SmoothPlastic,
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
		Color3.fromRGB(132, 96, 168),
		Color3.fromRGB(112, 88, 156),
		Color3.fromRGB(148, 110, 170),
		Color3.fromRGB(120, 96, 160),
		Color3.fromRGB(138, 104, 166),
		Color3.fromRGB(104, 84, 148),
	}
	for index, spike in ipairs(spikes) do
		local yaw = math.rad(spike.angle)
		local lean = math.rad(spike.lean)
		local cf = CFrame.new(0, 2, 0)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.new(0, 0, spike.radius)
			* CFrame.Angles(lean, 0, 0)
			* CFrame.new(0, spike.height / 2, 0)
		local shard = part(
			parent,
			"CrystalShard",
			Vector3.new(spike.thick, spike.height, spike.thick),
			cf,
			shardColors[index],
			Enum.Material.Glass,
			true
		)
		shard.Transparency = 0.18
	end

	local crystal = part(
		parent,
		"LumenHeart",
		Vector3.new(8, 42, 8),
		CFrame.new(0, 24 - SEAM, 0),
		Color3.fromRGB(186, 168, 204),
		Enum.Material.Glass,
		true
	)
	crystal.Transparency = 0.15
	crystal:SetAttribute("ShardfallKeep", true)
	local core = part(
		parent,
		"LumenCore",
		Vector3.new(1.8, 5.5, 1.8),
		CFrame.new(0, 22, 0),
		Color3.fromRGB(255, 214, 164),
		Enum.Material.Neon,
		false
	)
	core:SetAttribute("ShardfallKeep", true)
	local coreLight = Instance.new("PointLight")
	coreLight.Name = "PointLight"
	coreLight.Color = Color3.fromRGB(255, 206, 150)
	coreLight.Range = 14
	coreLight.Brightness = 0.55
	coreLight.Shadows = false
	coreLight.Parent = core
	local crack = part(
		parent,
		"Crack",
		Vector3.new(1.6, 28, 1.6),
		CFrame.new(1.4, 22, 0.6),
		Color3.fromRGB(176, 196, 214),
		Enum.Material.Glass,
		false
	)
	crack.Transparency = 0.35
	local beamColors = {
		Color3.fromRGB(176, 164, 196),
		Color3.fromRGB(150, 132, 184),
		Color3.fromRGB(196, 180, 164),
		Color3.fromRGB(140, 124, 176),
	}
	for index, beamColor in ipairs(beamColors) do
		local yaw = (index - 1) * (math.pi / 2)
		local height = 36
		local cf = CFrame.new(0, 10, 0)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(math.rad(22), 0, 0)
			* CFrame.new(0, height / 2, 0)
		local beam = part(
			parent,
			"LightBeam",
			Vector3.new(1.1, height, 1.1),
			cf,
			beamColor,
			Enum.Material.Glass,
			false
		)
		beam.Transparency = 0.45
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(186, 160, 210)
	light.Range = 18
	light.Brightness = 0.28
	light.Shadows = false
	light.Parent = crystal
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 28)
	billboard.StudsOffset = Vector3.new(0, 26, 0)
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
			Vector3.new(3.4, 14, 3.4),
			CFrame.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
				* CFrame.Angles(0, -angle, math.rad(18)),
			Color3.fromRGB(150, 130, 176),
			Enum.Material.Glass,
			false
		)
		shard.Transparency = 0.22
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
	local spawnY = Haven.FLOOR_Y + 1 - (1 + SEAM) / 2
	spawn.CFrame = CFrame.lookAt(
		Vector3.new(Haven.SPAWN.x, spawnY, Haven.SPAWN.z),
		Vector3.new(Haven.SPAWN.lookX, spawnY, Haven.SPAWN.lookZ)
	)
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
		Color3.fromRGB(168, 142, 88),
		Enum.Material.SmoothPlastic,
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
		local chimney = part(
			model,
			"Chimney",
			Vector3.new(4, 10, 4),
			hall.CFrame * CFrame.new(offset, 14, -4),
			Color3.fromRGB(36, 34, 38),
			Enum.Material.Slate,
			true,
			true
		)
		chimney.Name = "Chimney" .. tostring(index)
		local embers = borrow("ParticleEmitter") :: ParticleEmitter
		embers.Name = "embers"
		embers.Rate = 7
		embers.LightEmission = 0.35
		embers.Lifetime = NumberRange.new(0.8, 1.6)
		embers.Speed = NumberRange.new(2, 5)
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 140, 48))
		embers.Parent = chimney
	end
	-- The hall is the dark block. The anvil, basin, and flame sit on the
	-- walk in front of it, on this island model, so they render with the
	-- greybox even when dressing streams or a tier trims cosmetics.
	local function keep(piece: BasePart)
		piece:SetAttribute("ShardfallKeep", true)
		piece.CastShadow = true
	end
	local basin = part(
		model,
		"ForgeBasin",
		Vector3.new(8, 1.4, 6),
		hall.CFrame * CFrame.new(18, -hall.Size.Y / 2 + 0.7, 6),
		Color3.fromRGB(62, 50, 46),
		Enum.Material.Metal,
		false,
		true
	)
	keep(basin)
	local anvil = part(
		model,
		"Anvil",
		Vector3.new(4.8, 2.2, 2.6),
		basin.CFrame * CFrame.new(0, 1.8, 0),
		Color3.fromRGB(206, 210, 216),
		Enum.Material.Metal,
		false,
		true
	)
	keep(anvil)
	local flame = part(
		model,
		"ForgeFlame",
		Vector3.new(3.2, 7, 3.2),
		anvil.CFrame * CFrame.new(0, 4.4, 0.15),
		Color3.fromRGB(255, 132, 36),
		Enum.Material.Neon,
		false,
		true
	)
	keep(flame)
	local fire = Instance.new("PointLight")
	fire.Name = "PointLight"
	fire.Color = flame.Color
	fire.Brightness = 0.9
	fire.Range = 12
	fire.Shadows = false
	fire.Parent = flame
	local sparks = borrow("ParticleEmitter") :: ParticleEmitter
	sparks.Name = "sparks"
	sparks.Rate = 8
	sparks.LightEmission = 0.3
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 170, 64))
	sparks.Parent = flame
	local forge = stationPad(model, place.x, place.z, Color3.fromRGB(255, 120, 36))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 40)
	light.Range = 10
	light.Brightness = 0.4
	light.Parent = forge
	promptOn(forge, "Forge", "Upgrade gear", "craft", nil)
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
	-- The Market Board prompt lives on the rim shop. These stalls stay scenery.
	stationPad(model, place.x, place.z, Color3.fromRGB(255, 196, 80))
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
	promptOn(closed, "Coming Soon", "Guild Hall", "soon", place.message, "guild")
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

-- Court floor abuts the plaza on an edge, so the tops can share a height.
-- A face overlap would flicker. South holds the crescent. East holds the
-- garden walk, which leaves the plaza on its east edge.
local function buildCourt(parent: Instance)
	local court = Instance.new("Model")
	court.Name = "GateCourt"
	court.Parent = parent
	-- South edge sits on the plaza's south edge (z = 52). A shared edge is not an overlap.
	slab(
		court,
		"Ground",
		50,
		FLOOR_TOP,
		101,
		144,
		98,
		8,
		STONE,
		Enum.Material.Cobblestone,
		true
	)
	slab(
		court,
		"Ground",
		100,
		FLOOR_TOP,
		34,
		96,
		36,
		8,
		STONE,
		Enum.Material.Cobblestone,
		true
	)
	for _, portal in ipairs(Haven.PORTALS) do
		local bearing = math.rad(portal.bearing or 0)
		local lit = Haven.gateShownOpen(portal)
		local color = if lit
			then rgb(portal.color :: { number })
			else Color3.fromRGB(90, 90, 96)
		-- Axis-aligned squares. 1.1 stays clear of the next stone; 1.4 would share a top.
		local stone = disc(
			court,
			"Inlay",
			Haven.SPAWN.x + math.sin(bearing) * 8,
			Haven.LAYER,
			Haven.SPAWN.z + math.cos(bearing) * 8,
			1.1,
			0.2,
			color,
			Enum.Material.Neon,
			false
		)
		stone:SetAttribute("GateId", portal.id)
		stone:SetAttribute("GateLit", lit)
	end

	-- West slab shares the plaza's west edge. A bridge from the origin would
	-- cross the forge deck, so the shop stands on this floor instead.
	local shop = Haven.SHOP
	local stall = Instance.new("Model")
	stall.Name = "RimShop"
	stall.Parent = parent
	slab(
		stall,
		"Ground",
		-71,
		FLOOR_TOP,
		0,
		38,
		40,
		8,
		Color3.fromRGB(92, 78, 64),
		Enum.Material.WoodPlanks,
		true
	)
	local board = stationPad(stall, shop.x, shop.z, Color3.fromRGB(255, 196, 80))
	promptOn(board, "Market Board", "Browse and trade", "market", nil)
	sign(stall, CFrame.new(shop.x, 12, shop.z), "Shop")

	local shrine = Haven.SHRINE
	local plinthHeight, plinthCenter = sunk(4, 4)
	local plinth = part(
		parent,
		"Shrine",
		Vector3.new(6, plinthHeight, 6),
		CFrame.new(shrine.x, plinthCenter, shrine.z),
		Color3.fromRGB(126, 122, 116),
		Enum.Material.Slate,
		true
	)
	promptOn(plinth, "Shrine", shrine.message or "Shrine", "soon", shrine.message)
	sign(parent, CFrame.new(shrine.x, 10, shrine.z), "Shrine")

	local stoneHeight, stoneCenter = sunk(5, 5)
	for _, stoneZ in ipairs(Haven.NOVICE.z) do
		part(
			parent,
			"NoviceStone",
			Vector3.new(4, stoneHeight, 4),
			CFrame.new(Haven.NOVICE.x, stoneCenter, stoneZ),
			Color3.fromRGB(120, 120, 124),
			Enum.Material.Slate,
			true
		)
	end
end

-- Light and VFX table from docs/design/DUNGEON_GATE_PLAZA.md. One light,
-- shadows off, range at or under 18, emitter rate at or under 8. Void has
-- no emitter. Open mouths use the Heartwood pulse (0.15 over 3 seconds).
-- A sealed mouth keeps that number and does not play it.
HavenBuilder.RATE_CAP = 8
HavenBuilder.RANGE_CAP = 18
HavenBuilder.EMITTER_CAP = 8
HavenBuilder.APPROACH_STUDS = 12
HavenBuilder.QUIET_STUDS = 96
HavenBuilder.PULSE_PERIOD = 3
HavenBuilder.APPROACH_BOOST = 0.18
HavenBuilder.SEALED_NEAR = 0.12

type GateEmitterSpec = {
	name: string,
	rate: number,
	lifeMin: number,
	lifeMax: number,
	speedMin: number,
	speedMax: number,
	color: { number },
	colorEnd: { number }?,
	host: string,
	rise: boolean?,
	fall: boolean?,
	glow: number?,
	size: number?,
	drag: number?,
}

type GateVfxSpec = {
	brightness: number,
	range: number,
	color: { number },
	pulse: number,
	emitters: { GateEmitterSpec },
}

type GateGlow = {
	sealed: boolean,
	pulse: number,
	restBrightness: number,
	restTransparency: number,
	mouthX: number,
	mouthZ: number,
	light: PointLight,
	fill: BasePart,
	emitters: { ParticleEmitter },
}

type GatePerson = {
	x: number,
	z: number,
	reduced: boolean,
}

export type MouthLook = {
	brightness: number,
	enabled: boolean,
	transparency: number,
	particles: boolean,
}

local GATE_VFX: { [string]: GateVfxSpec } = {
	rootvault = {
		brightness = 0.45,
		range = 16,
		color = { 64, 196, 96 },
		pulse = 0.15,
		emitters = {
			{
				name = "mist",
				rate = 6,
				lifeMin = 1.2,
				lifeMax = 2.0,
				speedMin = 0.35,
				speedMax = 0.9,
				color = { 64, 140, 86 },
				host = "PillarL",
				rise = true,
				glow = 0.15,
				size = 0.55,
				drag = 2,
			},
		},
	},
	heartwood = {
		brightness = 0.35,
		range = 14,
		color = { 214, 140, 64 },
		pulse = 0.15,
		emitters = {
			{
				name = "ash",
				rate = 5,
				lifeMin = 1.4,
				lifeMax = 2.2,
				speedMin = 0.25,
				speedMax = 0.7,
				color = { 70, 68, 66 },
				colorEnd = { 176, 120, 64 },
				host = "Lintel",
				rise = true,
				glow = 0.12,
				size = 0.35,
				drag = 1.5,
			},
		},
	},
	tidecrypt = {
		brightness = 0.4,
		range = 14,
		color = { 36, 96, 140 },
		pulse = 0,
		emitters = {
			{
				name = "sheet",
				rate = 4,
				lifeMin = 1.1,
				lifeMax = 1.8,
				speedMin = 0.2,
				speedMax = 0.55,
				color = { 150, 210, 204 },
				host = "PillarL",
				fall = true,
				glow = 0.2,
				size = 0.4,
				drag = 1,
			},
			{
				name = "sheet",
				rate = 4,
				lifeMin = 1.1,
				lifeMax = 1.8,
				speedMin = 0.2,
				speedMax = 0.55,
				color = { 150, 210, 204 },
				host = "PillarR",
				fall = true,
				glow = 0.2,
				size = 0.4,
				drag = 1,
			},
		},
	},
	ember = {
		brightness = 0.3,
		range = 12,
		color = { 255, 120, 40 },
		pulse = 0,
		emitters = {
			{
				name = "sparks",
				rate = 6,
				lifeMin = 0.3,
				lifeMax = 0.6,
				speedMin = 0.4,
				speedMax = 1.2,
				color = { 255, 140, 48 },
				host = "Seam",
				rise = true,
				glow = 0.35,
				size = 0.2,
				drag = 0.4,
			},
		},
	},
	frost = {
		brightness = 0.4,
		range = 16,
		color = { 186, 228, 255 },
		pulse = 0,
		emitters = {
			{
				name = "wisp",
				rate = 3,
				lifeMin = 2.0,
				lifeMax = 3.2,
				speedMin = 0.05,
				speedMax = 0.2,
				color = { 236, 244, 248 },
				host = "PillarL",
				glow = 0.25,
				size = 0.6,
				drag = 3,
			},
		},
	},
	void = {
		brightness = 0.2,
		range = 10,
		color = { 120, 60, 180 },
		pulse = 0,
		emitters = {},
	},
}

HavenBuilder.GATE_VFX = GATE_VFX

local gateElapsed = 0
local gateEmitterCount = 0
local gateGlows: { GateGlow } = {}
local playersService: any = nil
local dataServiceModule: any = nil
local dataServiceTried = false

function HavenBuilder.mouthLook(
	restBrightness: number,
	restTransparency: number,
	sealed: boolean,
	pulse: number,
	elapsed: number,
	distance: number?,
	reduced: boolean
): MouthLook
	local time = 0
	if type(elapsed) == "number" and elapsed == elapsed then
		time = elapsed
	end
	local near = type(distance) == "number"
		and distance == distance
		and distance <= HavenBuilder.APPROACH_STUDS
	local particles = reduced ~= true
	if sealed then
		if near then
			return {
				brightness = HavenBuilder.SEALED_NEAR,
				enabled = true,
				transparency = math.max(0.6, restTransparency - 0.13),
				particles = particles,
			}
		end
		return {
			brightness = 0,
			enabled = false,
			transparency = restTransparency,
			particles = particles,
		}
	end
	local brightness = restBrightness
	if reduced ~= true and type(pulse) == "number" and pulse > 0 then
		local wave = math.sin(time * (math.pi * 2 / HavenBuilder.PULSE_PERIOD))
		brightness += wave * (pulse / 2)
	end
	local transparency = restTransparency
	if near then
		brightness += HavenBuilder.APPROACH_BOOST
		transparency = math.max(0.12, restTransparency - 0.15)
	end
	if brightness < 0 then
		brightness = 0
	end
	return {
		brightness = brightness,
		enabled = true,
		transparency = transparency,
		particles = particles,
	}
end

-- Same rule as UiMotion.reduced, plus a VFX slider parked at zero.
local function settingsAreQuiet(settings: any): boolean
	if type(settings) ~= "table" then
		return false
	end
	local camera = settings.camera
	if type(camera) == "table" and camera.flash == "reduced" then
		return true
	end
	local graphics = settings.graphics
	if type(graphics) == "table" and type(graphics.vfx) == "number" and graphics.vfx <= 0 then
		return true
	end
	return false
end

local function personIsQuiet(player: any): boolean
	if player == nil then
		return false
	end
	if type(player.GetAttribute) == "function" and player:GetAttribute("ReducedMotion") == true then
		return true
	end
	if not dataServiceTried then
		dataServiceTried = true
		if script ~= nil and script.Parent ~= nil then
			local ok, loaded = pcall(function()
				return require(script.Parent.DataService)
			end)
			if ok then
				dataServiceModule = loaded
			end
		end
	end
	if dataServiceModule == nil or type(dataServiceModule.get) ~= "function" then
		return false
	end
	local ok, profile = pcall(function()
		return dataServiceModule.get(player)
	end)
	if not ok or type(profile) ~= "table" then
		return false
	end
	return settingsAreQuiet(profile.uiSettings)
end

local function samplePeople(): { GatePerson }
	local people: { GatePerson } = {}
	if playersService == nil then
		local ok, service = pcall(function()
			return game:GetService("Players")
		end)
		if not ok or service == nil then
			return people
		end
		playersService = service
	end
	local listed, list = pcall(function()
		return playersService:GetPlayers()
	end)
	if not listed or type(list) ~= "table" then
		return people
	end
	for _, player in ipairs(list) do
		local quiet = false
		local quietOk, value = pcall(personIsQuiet, player)
		if quietOk and value == true then
			quiet = true
		end
		local character = player.Character
		local root: Instance? = nil
		if character ~= nil and type(character.FindFirstChild) == "function" then
			root = character:FindFirstChild("HumanoidRootPart")
		end
		if root ~= nil and root:IsA("BasePart") then
			local position = root.Position
			table.insert(people, {
				x = position.X,
				z = position.Z,
				reduced = quiet,
			})
		end
	end
	return people
end

local function nearestPerson(people: { GatePerson }, x: number, z: number): (number?, boolean)
	local best: number? = nil
	local reduced = false
	for _, person in ipairs(people) do
		local dx = person.x - x
		local dz = person.z - z
		local distance = math.sqrt(dx * dx + dz * dz)
		if best == nil or distance < best then
			best = distance
		end
		if person.reduced == true and distance <= HavenBuilder.QUIET_STUDS then
			reduced = true
		end
	end
	return best, reduced
end

function HavenBuilder.stepGates(dt: number?, people: { GatePerson }?)
	local step = 0
	if type(dt) == "number" and dt == dt then
		step = dt
	end
	gateElapsed += step
	local crowd = people
	if crowd == nil then
		crowd = samplePeople()
	end
	for _, gate in ipairs(gateGlows) do
		if gate.fill.Parent ~= nil then
			local distance, reduced = nearestPerson(crowd, gate.mouthX, gate.mouthZ)
			local look = HavenBuilder.mouthLook(
				gate.restBrightness,
				gate.restTransparency,
				gate.sealed,
				gate.pulse,
				gateElapsed,
				distance,
				reduced
			)
			gate.light.Brightness = look.brightness
			gate.light.Enabled = look.enabled
			gate.light.Shadows = false
			gate.fill.Transparency = look.transparency
			for _, emitter in ipairs(gate.emitters) do
				emitter.Enabled = look.particles
			end
		end
	end
end

local function placeGateEmitter(host: Instance, spec: GateEmitterSpec): ParticleEmitter?
	if gateEmitterCount >= HavenBuilder.EMITTER_CAP then
		return nil
	end
	local rate = spec.rate
	if type(rate) ~= "number" or rate ~= rate or rate <= 0 then
		return nil
	end
	if rate > HavenBuilder.RATE_CAP then
		rate = HavenBuilder.RATE_CAP
	end
	local emitter = borrow("ParticleEmitter") :: ParticleEmitter
	emitter.Name = spec.name
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(spec.lifeMin, spec.lifeMax)
	emitter.Speed = NumberRange.new(spec.speedMin, spec.speedMax)
	emitter.LightEmission = spec.glow or 0.2
	emitter.Drag = spec.drag or 1
	emitter.Size = NumberSequence.new(spec.size or 0.4)
	emitter.Enabled = true
	emitter.LockedToPart = true
	local color = rgb(spec.color)
	if spec.colorEnd ~= nil then
		emitter.Color = ColorSequence.new(color, rgb(spec.colorEnd))
	else
		emitter.Color = ColorSequence.new(color)
	end
	if spec.fall == true then
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Acceleration = Vector3.new(0, -0.45, 0)
	elseif spec.rise == true then
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, 1.1, 0)
	else
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, 0.12, 0)
	end
	emitter.Parent = host
	gateEmitterCount += 1
	return emitter
end

local function bindGateMotion()
	if gateConnection ~= nil then
		gateConnection:Disconnect()
		gateConnection = nil
	end
	gateConnection = RunService.Heartbeat:Connect(function(dt)
		HavenBuilder.stepGates(dt, nil)
	end)
end

local DRESS_MATERIAL: { [string]: Enum.Material } = {
	roots = Enum.Material.Wood,
	bark = Enum.Material.Wood,
	coral = Enum.Material.SmoothPlastic,
	basalt = Enum.Material.Basalt,
	ice = Enum.Material.Ice,
	obsidian = Enum.Material.SmoothPlastic,
}

-- Pivot on the floor so a lean does not lift the base off the court.
local function pierCf(facing: CFrame, x: number, height: number, pitch: number, roll: number): (CFrame, number)
	local sizeY = height + SEAM
	local cf = facing
		* CFrame.new(x, -SEAM, 0)
		* CFrame.Angles(pitch, 0, roll)
		* CFrame.new(0, sizeY / 2, 0)
	return cf, sizeY
end

local function accent(
	arch: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	dress: string
): Part
	local piece = part(arch, name, size, cf, color, material, false)
	piece:SetAttribute("GateDress", dress)
	return piece
end

local function buildPortals(parent: Instance)
	table.clear(gateGlows)
	gateEmitterCount = 0
	gateElapsed = 0
	local shelf = Instance.new("Model")
	shelf.Name = "RealmArches"
	shelf.Parent = parent
	for _, portal in ipairs(Haven.PORTALS) do
		local color = rgb(portal.color :: { number })
		local dress = if type(portal.dress) == "string" then portal.dress else "roots"
		local body = if portal.body ~= nil then rgb(portal.body) else STONE
		local edge = if portal.edge ~= nil then rgb(portal.edge) else body
		local mouth = if portal.glow ~= nil then rgb(portal.glow) else color
		local material = DRESS_MATERIAL[dress] or Enum.Material.Slate
		local leftH = if type(portal.height) == "number" then portal.height else 18
		local rightH = if dress == "ice" then 10 else leftH
		local pitch = if dress == "roots" or dress == "bark" then math.rad(12) else 0
		local roll = if dress == "coral" then math.rad(8) else 0
		local arch = Instance.new("Model")
		arch.Name = portal.id
		arch.Parent = shelf
		arch:SetAttribute("GateDress", dress)
		local open = Haven.gateShownOpen(portal)
		local sealed = not open
		arch:SetAttribute("GateSealed", sealed)
		if type(portal.dungeonId) == "string" then
			arch:SetAttribute("DungeonId", portal.dungeonId)
		end
		-- Mouth faces the pad. Local X is the pier line, local -Z is the walk.
		-- Dressing sits on the piers or behind them, off the lane and the chord.
		local facing = CFrame.lookAt(
			Vector3.new(portal.x, 0, portal.z),
			Vector3.new(Haven.SPAWN.x, 0, Haven.SPAWN.z)
		)
		local function at(x: number, y: number, z: number): CFrame
			return facing * CFrame.new(x, y, z)
		end
		local leftCf, leftSize = pierCf(facing, -5.25, leftH, pitch, -roll)
		local rightCf, rightSize = pierCf(facing, 5.25, rightH, pitch, roll)
		-- PillarL is the player's right as they face the mouth. The next gate is that way.
		local leftPier = part(arch, "PillarL", Vector3.new(2.5, leftSize, 2.5), leftCf, body, material, true)
		local rightColor = body
		local rightMaterial = material
		if dress == "ice" then
			leftPier.Transparency = 0.12
			rightColor = Color3.fromRGB(110, 124, 136)
			rightMaterial = Enum.Material.Slate
		end
		part(arch, "PillarR", Vector3.new(2.5, rightSize, 2.5), rightCf, rightColor, rightMaterial, true)
		local lintelSize = Vector3.new(13, 2.5, 3)
		if dress == "coral" or dress == "ice" then
			lintelSize = Vector3.new(13, 1.2, 2.6)
		elseif dress == "roots" then
			lintelSize = Vector3.new(13, 2.0, 3)
		end
		local lintelY = leftH + lintelSize.Y / 2 + SEAM
		part(arch, "Lintel", lintelSize, at(0, lintelY, 0), body, material, true)
		local glowH = leftH - 4
		local glowY = glowH / 2 + 2
		local fill = part(
			arch,
			"Glow",
			Vector3.new(8, glowH, 0.6),
			at(0, glowY, 0),
			mouth,
			Enum.Material.Neon,
			false
		)
		local restTransparency = if sealed then 0.75 else 0.35
		fill.Transparency = restTransparency
		fill.CanTouch = false
		local vfx = GATE_VFX[portal.id]
		local portalLight = Instance.new("PointLight")
		portalLight.Name = "PointLight"
		portalLight.Shadows = false
		if vfx ~= nil then
			portalLight.Color = rgb(vfx.color)
			portalLight.Range = math.min(vfx.range, HavenBuilder.RANGE_CAP)
			portalLight:SetAttribute("GateBrightness", vfx.brightness)
			portalLight:SetAttribute("GateRange", portalLight.Range)
			portalLight:SetAttribute("GatePulse", vfx.pulse)
			local rest = HavenBuilder.mouthLook(vfx.brightness, restTransparency, sealed, vfx.pulse, 0, nil, false)
			portalLight.Brightness = rest.brightness
			portalLight.Enabled = rest.enabled
		else
			portalLight.Color = color
			portalLight.Brightness = 0
			portalLight.Range = 12
			portalLight.Enabled = false
		end
		portalLight.Parent = fill
		if portal.id == "rootvault" then
			-- The damp shaft is the neon the player reads at noon. One stud wide.
			local shaft = part(
				arch,
				"Shaft",
				Vector3.new(1, 8, 1),
				at(0, glowY, 0),
				mouth,
				Enum.Material.Neon,
				false
			)
			shaft.Transparency = 0.5
			shaft.CastShadow = false
			shaft.CanQuery = false
		end
		local reach = Haven.GATE_REACH
		if portal.id == "rootvault" then
			fill.Name = "EnterPad"
			fill.CanTouch = true
			fill:SetAttribute("EnterDungeon", portal.dungeonId or Dungeons.ROOTVAULT_ID)
			promptOn(fill, "Enter", portal.name, "rootvault", nil, nil, reach)
			promptOn(leftPier, "Waves", "Solo", "waves", nil, nil, Haven.PIER_REACH)
		elseif portal.id == "heartwood" then
			-- Finder and Practice are the raid doors. While raids are off the
			-- sealed mouth says the gate opens later, so walking up does something.
			if LaunchGate.on("raids") then
				promptOn(fill, "Finder", portal.message or portal.name, "heartwood", portal.message, nil, reach)
				promptOn(
					leftPier,
					"Practice",
					"Solo",
					"practice",
					"Practice Grove is the solo path.",
					nil,
					Haven.PIER_REACH
				)
			else
				local later = Haven.gateShownPlate(portal)
				promptOn(fill, later, portal.name, "soon", later, nil, reach)
			end
		else
			promptOn(fill, "Sealed", portal.message or portal.name, "soon", portal.message, nil, reach)
		end
		if sealed then
			part(
				arch,
				"Seal",
				Vector3.new(8, 1.4, 1.4),
				at(0, glowY, 0),
				Color3.fromRGB(36, 34, 40),
				Enum.Material.Metal,
				true
			)
		end
		if dress == "roots" then
			accent(arch, "Root", Vector3.new(1.1, 1.4, 2.8), at(-5.4, 0.7, 2.4), body, material, dress)
			accent(arch, "Root", Vector3.new(1.1, 1.4, 2.8), at(5.4, 0.7, 2.4), body, material, dress)
			accent(arch, "Thorn", Vector3.new(0.45, 1.3, 0.45), at(-3.1, leftH - 0.5, 0.15), edge, material, dress)
			accent(arch, "Thorn", Vector3.new(0.45, 1.3, 0.45), at(3.1, leftH - 0.5, 0.15), edge, material, dress)
		elseif dress == "bark" then
			local char = Color3.fromRGB(36, 28, 22)
			accent(arch, "Bark", Vector3.new(0.35, 8, 1.1), at(-6.15, 8, 1.15), char, material, dress)
			accent(arch, "Bark", Vector3.new(0.35, 8, 1.1), at(6.15, 8, 1.15), char, material, dress)
			accent(
				arch,
				"Crack",
				Vector3.new(7, 0.35, 2.2),
				at(0, lintelY, -0.15),
				edge,
				Enum.Material.Neon,
				dress
			)
		elseif dress == "coral" then
			accent(arch, "Coral", Vector3.new(1.3, 1.1, 1.3), at(-5.2, 7, 1.7), edge, material, dress)
			accent(arch, "Coral", Vector3.new(1.3, 1.1, 1.3), at(5.2, 12, 1.7), body, material, dress)
		elseif dress == "basalt" then
			accent(
				arch,
				"Seam",
				Vector3.new(0.28, 1.5, 0.2),
				at(-2.2, lintelY, -1.55),
				edge,
				Enum.Material.Neon,
				dress
			)
			accent(
				arch,
				"Seam",
				Vector3.new(0.28, 1.5, 0.2),
				at(1.5, lintelY, -1.55),
				edge,
				Enum.Material.Neon,
				dress
			)
		elseif dress == "ice" then
			accent(
				arch,
				"Rubble",
				Vector3.new(2.1, 1.0, 1.4),
				at(5.25, 10.6, 0.7) * CFrame.Angles(0, 0.4, 0.35),
				body,
				Enum.Material.Ice,
				dress
			)
			accent(
				arch,
				"Shard",
				Vector3.new(0.22, leftH - 2, 0.4),
				at(-3.95, leftH / 2, 0),
				edge,
				Enum.Material.Neon,
				dress
			)
		elseif dress == "obsidian" then
			accent(
				arch,
				"Edge",
				Vector3.new(0.2, leftH - 3, 0.45),
				at(-3.95, leftH / 2, 0),
				edge,
				Enum.Material.Neon,
				dress
			)
			accent(
				arch,
				"Edge",
				Vector3.new(0.2, leftH - 3, 0.45),
				at(3.95, leftH / 2, 0),
				edge,
				Enum.Material.Neon,
				dress
			)
			accent(arch, "Edge", Vector3.new(7.2, 0.2, 0.45), at(0, leftH + 0.25, 0), edge, Enum.Material.Neon, dress)
		end
		local glowEmitters: { ParticleEmitter } = {}
		if vfx ~= nil then
			for _, emitterSpec in ipairs(vfx.emitters) do
				local host = arch:FindFirstChild(emitterSpec.host)
				if host == nil or not host:IsA("BasePart") then
					host = fill
				end
				local emitter = placeGateEmitter(host, emitterSpec)
				if emitter ~= nil then
					table.insert(glowEmitters, emitter)
				end
			end
			table.insert(gateGlows, {
				sealed = sealed,
				pulse = vfx.pulse,
				restBrightness = vfx.brightness,
				restTransparency = restTransparency,
				mouthX = fill.CFrame.Position.X,
				mouthZ = fill.CFrame.Position.Z,
				light = portalLight,
				fill = fill,
				emitters = glowEmitters,
			})
		end
		gatePlate(arch, at(0, leftH + lintelSize.Y + 2.6, 0), portal.name, Haven.gateShownPlate(portal))
	end

	-- Flat ring on the court. Lit segments point at open gates. The top
	-- stays on the inlay layer so the walk and the prompts stay clear.
	local ring = Instance.new("Model")
	ring.Name = "CourtRing"
	ring.Parent = parent
	local ringRadius = 36
	local guideCenter = Haven.LAYER - 0.04
	for _, portal in ipairs(Haven.PORTALS) do
		local bearing = math.rad(portal.bearing or 0)
		local lit = Haven.gateShownOpen(portal)
		local dirX = math.sin(bearing)
		local dirZ = math.cos(bearing)
		local color = if lit then rgb(portal.color :: { number }) else Color3.fromRGB(86, 86, 92)
		local function lay(x: number, z: number, size: Vector3)
			local guide = part(
				ring,
				"CourtGuide",
				size,
				CFrame.lookAt(
					Vector3.new(x, guideCenter, z),
					Vector3.new(x + dirX, guideCenter, z + dirZ)
				),
				color,
				Enum.Material.Neon,
				false
			)
			guide.Transparency = if lit then 0.42 else 0.86
			guide.CastShadow = false
			guide.CanQuery = false
			guide:SetAttribute("GateId", portal.id)
			guide:SetAttribute("GateLit", lit)
		end
		lay(
			Haven.SPAWN.x + dirX * ringRadius,
			Haven.SPAWN.z + dirZ * ringRadius,
			Vector3.new(5.2, 0.08, 1.4)
		)
		if lit then
			lay(
				Haven.SPAWN.x + dirX * 26,
				Haven.SPAWN.z + dirZ * 26,
				Vector3.new(1.2, 0.08, 16)
			)
		end
	end
	bindGateMotion()
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
	-- Squares: the walkable face is the full half-extent, not the inscribed circle.
	bridge(bridges, 0, 0, plaza, plaza, forge.x, forge.z, forge.radius, forge.radius, 1)
	bridge(bridges, 0, 0, plaza, plaza, market.x, market.z, market.radius, market.radius, 2)
	bridge(bridges, 0, 0, plaza, plaza, guild.x, guild.z, guild.radius, guild.radius, 3)
	local gardenX, gardenZ = Haven.courtRim(garden.x, garden.z)
	bridge(
		bridges,
		gardenX,
		gardenZ,
		RIM_HALF,
		RIM_HALF,
		garden.x,
		garden.z,
		garden.radius,
		garden.radius,
		4
	)
	local watchX, watchZ = Haven.courtRim(observatory.x, observatory.z)
	bridge(
		bridges,
		watchX,
		watchZ,
		RIM_HALF,
		RIM_HALF,
		observatory.x,
		observatory.z,
		observatory.radius,
		observatory.radius,
		5
	)
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

function HavenBuilder.clearDefaults()
	local hubReady = false
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "HubSpawn" then
			hubReady = true
			break
		end
	end
	if not hubReady then
		warn("[Shardfall] HubSpawn is missing, so the default baseplate stays")
		return
	end
	local plate = workspace:FindFirstChild("Baseplate")
	if plate ~= nil and SavedWorld.shouldClearDefault(plate.Name, plate.ClassName, true) then
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
		if SavedWorld.shouldClearDefault(descendant.Name, descendant.ClassName, true) then
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
	foliage.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	foliage.Parent = parent
	for _, desc in ipairs(VerdantScatter.haven()) do
		local className = if desc.className == "WedgePart" then "WedgePart" else "Part"
		local piece = borrow(className)
		piece.Name = desc.name
		piece.Size = Vector3.new(desc.size[1], desc.size[2], desc.size[3])
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CanQuery = false
		piece.CastShadow = desc.shadow == true and desc.lod ~= "small"
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
		piece:SetAttribute("ShardfallSizeX", piece.Size.X)
		piece:SetAttribute("ShardfallSizeY", piece.Size.Y)
		piece:SetAttribute("ShardfallSizeZ", piece.Size.Z)
		piece.Parent = foliage
		if desc.light then
			local light = Instance.new("PointLight")
			light.Name = "PointLight"
			light.Color = piece.Color
			light.Brightness = 0.4
			light.Range = 8
			light.Shadows = false
			light.Enabled = piece.Name ~= "Lantern"
			light.Parent = piece
			if piece.Name == "Lantern" then
				piece:SetAttribute("ShardfallLantern", true)
			end
		end
		if desc.particle ~= nil then
			local emitter = borrow("ParticleEmitter") :: ParticleEmitter
			emitter.Name = desc.particle
			emitter.Rate = 4
			emitter.LightEmission = 0.2
			emitter.Parent = piece
		end
	end
end

local function puff(parent: Instance, name: string, rate: number, color: Color3)
	local emitter = borrow("ParticleEmitter") :: ParticleEmitter
	emitter.Name = name
	emitter.Rate = rate
	emitter.LightEmission = 0.25
	emitter.Lifetime = NumberRange.new(0.7, 1.6)
	emitter.Speed = NumberRange.new(0.5, 2.5)
	emitter.Color = ColorSequence.new(color)
	emitter.Parent = parent
end

local function maybeSound(parent: Instance, soundId: string, name: string)
	if not HavenLife.audioReady(soundId) then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0.3
	sound.RollOffMaxDistance = 140
	sound.Parent = parent
	sound:Play()
end

local function stampLife(parent: Instance)
	if lifeConnection ~= nil then
		lifeConnection:Disconnect()
		lifeConnection = nil
	end

	local alive = Instance.new("Model")
	alive.Name = "Alive"
	alive.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	alive.Parent = parent

	local skyDrift: { { part: BasePart, drift: number } } = {}

	local function stampPiece(
		host: Instance,
		desc: HavenLife.Piece,
		worldX: number,
		worldZ: number,
		yawDeg: number
	): BasePart
		local className = if desc.className == "WedgePart" then "WedgePart" else "Part"
		local piece = borrow(className)
		piece.Name = desc.name
		piece.Size = Vector3.new(desc.size[1], desc.size[2], desc.size[3])
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CanQuery = false
		piece.CastShadow = desc.lod ~= "small"
		piece.Transparency = desc.transparency
		piece.Color = Color3.fromRGB(desc.color[1], desc.color[2], desc.color[3])
		piece.Material = (Enum.Material :: any)[desc.material]
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		if desc.shape == "Ball" and piece:IsA("Part") then
			(piece :: Part).Shape = Enum.PartType.Ball
		end
		local spun = CFrame.new(worldX, desc.y, worldZ)
			* CFrame.Angles(math.rad(desc.rx), math.rad(yawDeg), math.rad(desc.rz))
		piece.CFrame = spun + Vector3.new(0, Haven.FLOOR_Y, 0)
		piece:SetAttribute("ShardfallLod", desc.lod)
		if TRIM[desc.name] == true then
			piece:SetAttribute("ShardfallTrim", true)
		end
		if KEEP_PIECE[desc.name] == true then
			piece:SetAttribute("ShardfallKeep", true)
		end
		piece:SetAttribute("ShardfallSizeX", piece.Size.X)
		piece:SetAttribute("ShardfallSizeY", piece.Size.Y)
		piece:SetAttribute("ShardfallSizeZ", piece.Size.Z)
		piece.Parent = host
		if desc.light == true then
			local glow = Instance.new("PointLight")
			glow.Name = "PointLight"
			glow.Color = piece.Color
			glow.Brightness = 0.28
			glow.Range = 9
			glow.Shadows = false
			glow.Parent = piece
		end
		if desc.particle ~= nil then
			local rate = 5
			if desc.particle == "mist" then
				rate = 12
			elseif desc.particle == "sparks" then
				rate = 14
			end
			puff(piece, desc.particle, rate, piece.Color)
		end
		return piece
	end

	for _, desc in ipairs(HavenLife.pieces()) do
		local worldX = desc.x
		local worldZ = desc.z
		local yaw = desc.ry
		if desc.drift ~= nil then
			local angle = #skyDrift * (math.pi * 2 / 4)
			worldX = math.cos(angle) * desc.drift
			worldZ = math.sin(angle) * desc.drift
			yaw = math.deg(angle)
		end
		-- Waystones render as direct Haven children. Waterfalls in the Alive
		-- folder did not, so the curtains live on Haven too.
		local host = alive
		if desc.name == "Waterfall" or desc.name == "FallLip" then
			host = parent
		end
		local piece = stampPiece(host, desc, worldX, worldZ, yaw)
		if desc.name == "Waterfall" or desc.name == "FallLip" then
			-- Yaw, then pitch. A single Euler pitch+yaw lays the sheet flat
			-- once the rim is not aligned with the world axes.
			piece.CFrame = CFrame.new(worldX, Haven.FLOOR_Y + desc.y, worldZ)
				* CFrame.Angles(0, math.rad(yaw), 0)
				* CFrame.Angles(math.rad(desc.rx), 0, math.rad(desc.rz))
		end
		if desc.drift ~= nil then
			table.insert(skyDrift, { part = piece, drift = desc.drift })
		end
	end

	type RigPart = { part: BasePart, localCf: CFrame }
	type Mover = {
		kind: string,
		x: number,
		z: number,
		points: { { number } }?,
		radius: number?,
		distance: number,
		parts: { RigPart },
	}
	local movers: { Mover } = {}

	for _, rig in ipairs(HavenLife.rigs()) do
		local model = Instance.new("Model")
		model.Name = rig.name
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		model:SetAttribute("ShardfallKind", rig.kind)
		-- Townsfolk are their own models. Nesting them under Alive left the
		-- bodies out of the client world even while sky shards in Alive showed.
		model.Parent = if rig.kind == "folk" then parent else alive
		local mover: Mover = {
			kind = rig.kind,
			x = rig.x,
			z = rig.z,
			points = rig.points,
			radius = rig.radius,
			distance = 0,
			parts = {},
		}
		for _, desc in ipairs(rig.parts) do
			local piece = stampPiece(model, desc, rig.x + desc.x, rig.z + desc.z, desc.ry)
			if rig.kind == "bird" then
				piece:SetAttribute("ShardfallTrim", true)
			elseif rig.kind == "folk" then
				piece:SetAttribute("ShardfallKeep", true)
			end
			local localCf = CFrame.new(desc.x, desc.y, desc.z)
				* CFrame.Angles(math.rad(desc.rx), math.rad(desc.ry), math.rad(desc.rz))
			table.insert(mover.parts, { part = piece, localCf = localCf })
		end
		table.insert(movers, mover)
	end

	for index, dest in ipairs(Travel.DESTINATIONS) do
		local height = 9 + index * 0.35
		local stone = part(
			parent,
			"Waystone",
			Vector3.new(3.4, height, 3.4),
			CFrame.new(dest.stoneX, height / 2 + 0.25, dest.stoneZ),
			Color3.fromRGB(132, 118, 158),
			Enum.Material.SmoothPlastic,
			false
		)
		stone.CanTouch = true
		stone.CanQuery = true
		stone.CastShadow = true
		stone:SetAttribute("WaystoneId", dest.id)
		stone:SetAttribute("ShardfallKeep", true)
		local crystal = part(
			parent,
			"WaystoneCrystal",
			Vector3.new(2.4, 3.4, 2.4),
			CFrame.new(dest.stoneX, height + 1.6, dest.stoneZ) * CFrame.Angles(0, 0.4, 0.5),
			Color3.fromRGB(214, 196, 150),
			Enum.Material.Glass,
			false
		)
		crystal.Transparency = 0.2
		crystal:SetAttribute("ShardfallKeep", true)
		local glow = Instance.new("PointLight")
		glow.Name = "PointLight"
		glow.Color = Color3.fromRGB(180, 160, 200)
		glow.Brightness = 0.3
		glow.Range = 8
		glow.Shadows = false
		glow.Parent = stone
	end

	maybeSound(alive, HavenLife.AUDIO.hub, "HubAmbience")
	maybeSound(alive, HavenLife.AUDIO.forge, "ForgeAmbience")
	maybeSound(alive, HavenLife.AUDIO.market, "MarketAmbience")
	maybeSound(alive, HavenLife.AUDIO.garden, "GardenAmbience")
	maybeSound(alive, HavenLife.AUDIO.night, "NightAmbience")

	local aliveParts = 0
	for _, descendant in ipairs(alive:GetDescendants()) do
		if descendant:IsA("BasePart") then
			aliveParts += 1
		end
	end
	print(
		string.format(
			"[Shardfall] Haven alive %d parts (%d dressing, %d waystones, budget %d)",
			aliveParts,
			HavenLife.partCount(),
			#Travel.DESTINATIONS,
			HavenLife.BUDGET
		)
	)

	local lanternLights: { PointLight } = {}
	local function collectLanterns()
		table.clear(lanternLights)
		local haven = workspace:FindFirstChild("Haven")
		if haven == nil then
			return
		end
		for _, descendant in ipairs(haven:GetDescendants()) do
			if descendant:GetAttribute("ShardfallLantern") == true then
				local glow = descendant:FindFirstChild("PointLight")
				if glow ~= nil and glow:IsA("PointLight") then
					table.insert(lanternLights, glow :: PointLight)
				end
			end
		end
	end

	local cycleWarned = false
	local function applyCycle(elapsed: number)
		local found, lighting = pcall(function()
			return game:GetService("Lighting")
		end)
		if not found or lighting == nil then
			return
		end
		local ok, err = pcall(function()
			local hour = HavenLife.clock(elapsed)
			local mood = HavenLife.mood(hour)
			local exposure = HavenLife.exposure(hour)
			local target = lighting :: any
			target.ClockTime = hour
			target.Brightness = math.min(mood.brightness, exposure.brightness)
			target.Ambient = Color3.fromRGB(mood.ambient[1], mood.ambient[2], mood.ambient[3])
			target.OutdoorAmbient =
				Color3.fromRGB(mood.outdoor[1], mood.outdoor[2], mood.outdoor[3])
			-- A new Sky with no face ids replaces the default skybox.
			local sky = target:FindFirstChildOfClass("Sky")
			if sky ~= nil then
				sky.SunAngularSize = 10
				sky.StarCount = 3000
				sky.MoonAngularSize = 11
			end
			local lampsOn = HavenLife.lanternsOn(hour)
			for _, glow in ipairs(lanternLights) do
				glow.Enabled = lampsOn
			end
			local bloom = target:FindFirstChild("VerdantBloom")
			if bloom ~= nil then
				if bloom.Intensity > exposure.bloomIntensity then
					bloom.Intensity = exposure.bloomIntensity
				end
				bloom.Size = exposure.bloomSize
				if bloom.Threshold < exposure.bloomThreshold then
					bloom.Threshold = exposure.bloomThreshold
				end
			end
			local rays = target:FindFirstChild("VerdantSunRays")
			if rays ~= nil then
				rays.Intensity = exposure.sunIntensity
				rays.Spread = exposure.sunSpread
			end
		end)
		if not ok and not cycleWarned then
			cycleWarned = true
			warn("[Shardfall] Haven day cycle failed: " .. tostring(err))
		end
	end

	collectLanterns()
	local elapsed = 0
	applyCycle(elapsed)

	local function along(points: { { number } }, distance: number): (number, number, number)
		local total = 0
		local lengths = {}
		for index = 1, #points do
			local from = points[index]
			local to = points[(index % #points) + 1]
			local span = math.sqrt((to[1] - from[1]) ^ 2 + (to[2] - from[2]) ^ 2)
			if span < 0.05 then
				span = 0.05
			end
			lengths[index] = span
			total += span
		end
		local walk = distance % total
		for index = 1, #points do
			local span = lengths[index]
			local from = points[index]
			local to = points[(index % #points) + 1]
			if walk <= span then
				local t = walk / span
				local dx = to[1] - from[1]
				local dz = to[2] - from[2]
				return from[1] + dx * t, from[2] + dz * t, math.atan2(dx, dz)
			end
			walk -= span
		end
		return points[1][1], points[1][2], 0
	end

	lifeConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local spin = elapsed * 0.08
		for index, shard in ipairs(skyDrift) do
			local angle = spin + (index - 1) * (math.pi * 2 / math.max(1, #skyDrift))
			local height = Haven.FLOOR_Y + 78 + math.sin(spin * 2 + index) * 4
			shard.part.CFrame = CFrame.new(
				math.cos(angle) * shard.drift,
				height,
				math.sin(angle) * shard.drift
			) * CFrame.Angles(math.rad(28), angle, math.rad(12))
		end
		for _, mover in ipairs(movers) do
			mover.distance += dt * (if mover.kind == "bird" then 0.7 else 4)
			local px = mover.x
			local pz = mover.z
			local yaw = 0
			local lift = 0
			if mover.kind == "bird" then
				local radius = mover.radius or 14
				px = mover.x + math.cos(mover.distance) * radius
				pz = mover.z + math.sin(mover.distance) * radius
				yaw = mover.distance + math.pi / 2
				lift = 9 + math.sin(mover.distance * 2) * 1.2
			elseif mover.points ~= nil then
				px, pz, yaw = along(mover.points, mover.distance)
			end
			local origin = CFrame.new(px, Haven.FLOOR_Y + lift, pz) * CFrame.Angles(0, yaw, 0)
			for _, item in ipairs(mover.parts) do
				item.part.CFrame = origin * item.localCf
			end
		end
		applyCycle(elapsed)
	end)
end

-- One straw dummy on the plaza's south rim. The post is the only collider.
-- The sign uses the gate plate so it stays readable at noon. No light, no
-- particles, no face, and no board in the lane.
local function buildGrove(parent: Instance)
	local grove = Haven.GROVE
	local model = Instance.new("Model")
	model.Name = "GroveDummy"
	model.Parent = parent
	model:SetAttribute("GroveId", grove.id)

	local pine = Color3.fromRGB(92, 64, 36)
	local straw = Color3.fromRGB(222, 196, 120)
	local moss = Color3.fromRGB(30, 150, 64)
	local backing = Color3.fromRGB(20, 16, 12)
	local x = grove.x
	local z = grove.z

	local postHeight, postCenter = sunk(5, 5)
	local post = part(
		model,
		"Post",
		Vector3.new(1.1, postHeight, 1.1),
		CFrame.new(x, postCenter, z),
		pine,
		Enum.Material.Wood,
		true
	)
	part(
		model,
		"Straw",
		Vector3.new(2, 2.2, 1),
		CFrame.new(x, 3.5, z),
		straw,
		Enum.Material.Fabric,
		false
	)
	ball(model, "Head", x, 4.9, z, 1.2, straw, Enum.Material.Fabric)
	-- North face, toward spawn. The dark plate is what makes the moss read.
	part(
		model,
		"TargetBack",
		Vector3.new(1.7, 1.7, 0.16),
		CFrame.new(x, 3.5, z - 0.58),
		backing,
		Enum.Material.SmoothPlastic,
		false
	)
	part(
		model,
		"Target",
		Vector3.new(1.15, 1.15, 0.12),
		CFrame.new(x, 3.5, z - 0.74),
		moss,
		Enum.Material.SmoothPlastic,
		false
	)
	gatePlate(model, CFrame.new(x, 6.2, z), "Training Grove", "Hit the dummy")
	promptOn(post, "Train", "Training Grove", "grove", "Hit the dummy.", nil, 8)
end

function HavenBuilder.build(parent: Instance): number
	-- Persistent before parenting, and a direct Workspace child. Kevin's
	-- Explorer showed Camera, Terrain, and Baseplate, with no Haven.
	if parent:IsA("Model") then
		parent.Parent = nil
		parent.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		parent.Parent = workspace
	end

	buildPlaza(parent)
	buildCrystal(parent)
	buildForge(parent)
	buildMarket(parent)
	buildGuild(parent)
	buildGarden(parent)
	buildObservatory(parent)
	buildCourt(parent)
	-- Training Grove is parked (0.1). The builder stays; nothing stands in the hub.
	if LaunchGate.on("grove") then
		buildGrove(parent)
	end
	buildPortals(parent)
	buildBridges(parent)
	buildRocks(parent)
	local function guard(label: string, callback: () -> ())
		local ok, err = pcall(callback)
		if not ok then
			warn("[Shardfall] " .. label .. " failed: " .. tostring(err))
		end
	end
	guard("Haven dressing", function()
		dressHaven(parent)
	end)
	guard("Haven life", function()
		stampLife(parent)
	end)

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
				if typeof(player) ~= "Instance" or not player:IsA("Player") then
					return
				end
				if type(action) ~= "string" then
					return
				end
				if (action == "heartwood" or action == "practice") and not LaunchGate.on("raids") then
					return
				end
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local remote = if remotes ~= nil then remotes:FindFirstChild("HavenPrompt") else nil
				if action == "heartwood" then
					local now = os.clock()
					if now < (heartwoodReadyAt[player.UserId] or 0) then
						return
					end
					heartwoodReadyAt[player.UserId] = now + 1
					local queued, result = pcall(function()
						local RaidService = require(script.Parent.RaidService)
						return RaidService.queue(player, "story", "flex")
					end)
					local message = "The Heartwood queue did not start."
					if queued and type(result) == "table" then
						if result.ok == true and type(result.note) == "string" then
							message = result.note
						elseif result.ok == true then
							message = "Joined the Heartwood queue."
						elseif type(result.error) == "string" then
							message = result.error
						end
					end
					if remote ~= nil and remote:IsA("RemoteEvent") then
						remote:FireClient(player, action, message)
					end
					return
				end
				if action == "waves" then
					local now = os.clock()
					if now < (wavesReadyAt[player.UserId] or 0) then
						return
					end
					wavesReadyAt[player.UserId] = now + 1
					local entered, result = pcall(function()
						local DungeonService = require(script.Parent.DungeonService)
						return DungeonService.enter(player, Dungeons.WAVES_ID)
					end)
					if not entered or type(result) ~= "table" or result.ok ~= true then
						local message = "Rootvault Waves did not start."
						if entered and type(result) == "table" and type(result.error) == "string" then
							message = result.error
						end
						if remote ~= nil and remote:IsA("RemoteEvent") then
							remote:FireClient(player, action, message)
						end
					end
					return
				end
				if action == "practice" then
					local now = os.clock()
					if now < (practiceReadyAt[player.UserId] or 0) then
						return
					end
					practiceReadyAt[player.UserId] = now + 1
					local started, result = pcall(function()
						local RaidService = require(script.Parent.RaidService)
						return RaidService.practice(player, 1, 1)
					end)
					local message = "Practice Grove did not start."
					if started and type(result) == "table" then
						if result.ok == true and type(result.note) == "string" then
							message = result.note
						elseif result.ok == true then
							message = "Practice Grove. No loot."
						elseif type(result.error) == "string" then
							message = result.error
						end
					end
					if remote ~= nil and remote:IsA("RemoteEvent") then
						remote:FireClient(player, action, message)
					end
					return
				end
				if descendant:GetAttribute("HavenDistrict") == "guild" then
					local DataService = require(script.Parent.DataService)
					local StarterGoalPay = require(ReplicatedStorage.Shared.StarterGoalPay)
					DataService.mutate(player, function(data)
						StarterGoalPay.grant(data, "guild", { browse = true })
						return nil
					end)
				end
				if remote ~= nil and remote:IsA("RemoteEvent") then
					remote:FireClient(player, action)
				end
			end)
		end
	end
	local waterfalls = 0
	local npcs = 0
	local waystones = 0
	local sizeLine = {}
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name == "Waterfall" then
				waterfalls += 1
			end
			if descendant.Name == "Waystone" then
				waystones += 1
			end
			if
				sizeLine[descendant.Name] == nil
				and (
					descendant.Name == "LumenHeart"
					or descendant.Name == "Waystone"
					or descendant.Name == "Waterfall"
					or descendant.Name == "ForgeFlame"
					or descendant.Name == "SkyShard"
					or descendant.Name == "TownsfolkFlag"
				)
			then
				sizeLine[descendant.Name] = string.format(
					"%s size=%.1f,%.1f,%.1f t=%.2f",
					descendant.Name,
					descendant.Size.X,
					descendant.Size.Y,
					descendant.Size.Z,
					descendant.Transparency
				)
			end
		elseif descendant:IsA("Model") and descendant.Name == "Townsfolk" then
			npcs += 1
		end
	end
	print(
		string.format(
			"[Shardfall] Haven built under %s at floor y=%d (%d parts, %d prompts)",
			parent.Name,
			Haven.FLOOR_Y,
			count,
			prompts
		)
	)
	print(
		string.format(
			"[HavenArt] built %d parts: waterfalls %d, npcs %d, waystones %d; trimmed 0 by tier server",
			count,
			waterfalls,
			npcs,
			waystones
		)
	)
	local function savedSize(name: string): string
		return sizeLine[name] or (name .. " missing")
	end
	print(
		"[HavenArt] server "
			.. savedSize("LumenHeart")
			.. "; "
			.. savedSize("Waystone")
			.. "; "
			.. savedSize("Waterfall")
			.. "; "
			.. savedSize("ForgeFlame")
			.. "; "
			.. savedSize("SkyShard")
			.. "; "
			.. savedSize("TownsfolkFlag")
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
