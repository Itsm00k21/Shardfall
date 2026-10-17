--!strict

--[[
	Rootvault, built when the server starts.

	Studio does not need a hand-placed map. HavenBuilder creates the hub.
	This module creates the crawl rooms in Workspace.ShardfallWorld, then
	teleports the player between them. Enemies are anchored part rigs from ModelFactory with a chase-and-swing loop. The boss
	adds a weak spot, then a fog that only the sunbeam saves you from.

	A later realm is a row in Dungeons.luau with a higher ascension. Until
	`implemented` is true, enter() refuses it. Rewards (gold, shard tokens,
	materials, and a chance at an Armory or Pets voucher) are granted here,
	on the server, after the boss dies.

	A cleared room waits ADVANCE_SECONDS, shows that countdown, then teleports
	to the next room. Rootvault Waves is one arena: each wave scales in
	Dungeons.luau, pays on clear, and continues until the player falls.
	Auto-Farm restarts the same dungeon after victory or defeat. With Auto
	Attack it also walks the character toward the nearest enemy.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChestConfig = require(ReplicatedStorage.Shared.ChestConfig)
local Economy = require(ReplicatedStorage.Shared.Economy)
local CombatFeel = require(ReplicatedStorage.Shared.CombatFeel)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Drops = require(ReplicatedStorage.Shared.Drops)
local Dungeons = require(ReplicatedStorage.Shared.Dungeons)
local Haven = require(ReplicatedStorage.Shared.Haven)
local Materials = require(ReplicatedStorage.Shared.Materials)
local ModelFactory = require(ReplicatedStorage.Shared.ModelFactory)
local VerdantLook = require(ReplicatedStorage.Shared.VerdantLook)
local VerdantScatter = require(ReplicatedStorage.Shared.VerdantScatter)
local Loops = require(ReplicatedStorage.Shared.Loops)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Raids = require(ReplicatedStorage.Shared.Raids)
local LoopService = require(script.Parent.LoopService)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Rootvault = require(ReplicatedStorage.Shared.Rootvault)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local SavedWorld = require(ReplicatedStorage.Shared.SavedWorld)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local OnboardingService = require(script.Parent.OnboardingService)
local HavenBuilder = require(script.Parent.HavenBuilder)

local DungeonService = {}

type Enemy = {
	id: string,
	kind: string,
	name: string,
	hp: number,
	maxHp: number,
	damage: number,
	defense: number,
	attackSpeed: number,
	moveSpeed: number,
	range: number,
	style: "melee" | "projectile",
	minDot: number,
	projectileSpeed: number,
	boss: boolean,
	phase: number,
	phase2At: number,
	weakSeconds: number,
	weakUntil: number,
	armoredMultiplier: number,
	fogInterval: number,
	fogDamage: number,
	safeRadius: number,
	nextFog: number,
	nextAttack: number,
	stagger: number,
	stunUntil: number,
	telegraphUntil: number,
	telegraphColor: string,
	hover: number,
	color: Color3,
	part: BasePart,
}

type Run = {
	dungeon: Dungeons.DungeonDef,
	roomIndex: number,
	enemies: { [string]: Enemy },
	cleared: boolean,
	resolving: boolean,
	folder: Folder,
	sunbeam: BasePart?,
	sunbeamIndex: number,
	placeIndex: number,
	wave: number,
	advanceAt: number?,
	advanceShown: number?,
	yielding: boolean?,
	walking: boolean?,
	-- Kill drops collected this run. The clear card lists these with the
	-- room rewards, including Gnarl's Seed from Grandmother Gnarl.
	loot: { [string]: number },
	difficulty: string,
	offer: { any }?,
	eliteNext: boolean,
	shrine: string,
	startedAt: number,
	practice: boolean,
	raidPlayers: number,
	healerPresent: boolean,
	echo: number,
}

type Restart = {
	at: number,
	dungeonId: string,
}

local runs: { [Player]: Run } = {}
local touchAt: { [Player]: number } = {}
local fallAt: { [Player]: number } = {}
local farmOn: { [Player]: boolean } = {}
local farmSince: { [Player]: number } = {}
local restartAt: { [Player]: Restart } = {}
local idleNoted: { [Player]: boolean } = {}
local nextEnemyId = 0
local worldFolder: Folder? = nil
local activeFolder: Folder? = nil

local SPAWNS = {}
for _, spot in ipairs(Dungeons.ENEMY_SPAWNS) do
	table.insert(SPAWNS, Vector3.new(spot.x, 0, spot.z))
end

local function fx(player: Player, payload: { [string]: any })
	if player.Parent == nil then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		return
	end
	local remote = remotes:FindFirstChild("CombatFx")
	if remote ~= nil and remote:IsA("RemoteEvent") then
		remote:FireClient(player, payload)
	end
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp ~= nil and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character == nil then
		return
	end
	local hrp = rootPart(player)
	local anchored = false
	if hrp ~= nil then
		anchored = hrp.Anchored
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		-- Hold still while the destination streams. A free character falls
		-- into the void for the frames before the hub floor arrives.
		hrp.Anchored = true
	end
	-- Always request the stream. Reading StreamingEnabled can fail in the
	-- same contexts that cannot write it, and skipping the request is what
	-- drops the camera into the black gap on the way out of a room.
	pcall(function()
		if hrp ~= nil then
			player.ReplicationFocus = hrp
		end
	end)
	-- Move first. RequestStreamAroundAsync yields for up to 5 seconds, and
	-- the default baseplate can be removed during that wait.
	character:PivotTo(cframe)
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 5)
	end)
	if hrp ~= nil then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.Anchored = anchored
	end
end

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	collide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = collide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function sign(parent: Instance, cframe: CFrame, text: string, width: number)
	local board = makePart(
		"Sign",
		Vector3.new(width, 4, 0.4),
		cframe,
		Color3.fromRGB(48, 36, 28),
		parent,
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
	label.TextColor3 = Color3.fromRGB(226, 214, 170)
	label.Text = text
	label.Parent = gui
end

local function roomCFrame(index: number, localOffset: Vector3): CFrame
	local x, _, z = Dungeons.roomOrigin(index)
	return CFrame.new(x + localOffset.X, localOffset.Y, z + localOffset.Z)
end

local function hubCFrame(): CFrame
	local spawn = Haven.SPAWN
	return CFrame.lookAt(
		Vector3.new(spawn.x, spawn.y, spawn.z),
		Vector3.new(spawn.lookX, spawn.y + 12, spawn.lookZ)
	)
end

local function roomSpawn(index: number): CFrame
	local x, _, z = Dungeons.roomOrigin(index)
	return CFrame.lookAt(Vector3.new(x, 4, z + Dungeons.SPAWN_Z), Vector3.new(x, 3, z + 8))
end

local function buildRoom(
	parent: Folder,
	dungeon: Dungeons.DungeonDef,
	index: number,
	placeIndex: number?
): number
	local room = dungeon.rooms[index]
	local place = if placeIndex ~= nil then placeIndex else index
	local model = Instance.new("Model")
	model.Name = room.id
	-- The waves arena used to stream in after the teleport, so the click
	-- looked like it did nothing while the character fell through the void.
	if place == Dungeons.WAVES_ROOM_INDEX then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	else
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	model.Parent = parent

	local floorColor = if dungeon.endless == true
		then Color3.fromRGB(68, 86, 112)
		elseif index == #dungeon.rooms then Color3.fromRGB(46, 78, 58)
		else Color3.fromRGB(78, 132, 72)
	local center = roomCFrame(place, Vector3.new(0, -0.5, 0))
	local floor = makePart(
		"Floor",
		Vector3.new(dungeon.floorSize, 1, dungeon.floorSize),
		center,
		floorColor,
		model,
		true
	)
	floor.Material = if dungeon.endless == true then Enum.Material.Slate else Enum.Material.Grass
	if dungeon.endless ~= true then
		local path = makePart(
			"Path",
			Vector3.new(Dungeons.CORRIDOR_WIDTH, 0.35, dungeon.floorSize * 0.72),
			roomCFrame(place, Vector3.new(0, 0.2, 0)),
			Color3.fromRGB(112, 86, 52),
			model,
			true
		)
		path.Material = Enum.Material.Ground
		path.CastShadow = false
	end

	local dressing = Instance.new("Model")
	dressing.Name = "Dressing"
	dressing.Parent = model
	local dressMode = if dungeon.endless == true
		then "waves"
		elseif index == #dungeon.rooms then "arena"
		else "wild"
	local placed = 0
	for _, spot in ipairs(VerdantScatter.room(place * 9176 + 13, dungeon.floorSize / 2, dressMode)) do
		local feet = roomCFrame(place, Vector3.new(spot.x, spot.y, spot.z))
		local prop = ModelFactory.place(dressing, spot.kind, feet, spot.yaw, spot.scale)
		if prop == nil then
			warn("[Shardfall] Forest kit missing " .. spot.kind .. " in " .. room.id)
		else
			placed += 1
		end
	end

	local half = dungeon.floorSize / 2
	local wallColor = Color3.fromRGB(34, 58, 40)
	local height = Dungeons.WALL_HEIGHT
	local function wall(name: string, size: Vector3, offset: Vector3)
		local part = makePart(name, size, roomCFrame(place, offset), wallColor, model, true)
		part.CastShadow = false
		return part
	end
	wall("WallNorth", Vector3.new(dungeon.floorSize, height, 1), Vector3.new(0, height / 2, -half))
	wall("WallSouth", Vector3.new(dungeon.floorSize, height, 1), Vector3.new(0, height / 2, half))
	wall("WallWest", Vector3.new(1, height, dungeon.floorSize), Vector3.new(-half, height / 2, 0))
	wall("WallEast", Vector3.new(1, height, dungeon.floorSize), Vector3.new(half, height / 2, 0))
	local ceiling = makePart(
		"Ceiling",
		Vector3.new(dungeon.floorSize, 1, dungeon.floorSize),
		roomCFrame(place, Vector3.new(0, height, 0)),
		Color3.fromRGB(24, 36, 30),
		model,
		true
	)
	ceiling.CastShadow = false
	for _, spec in ipairs(Dungeons.lightLayout(dungeon.floorSize)) do
		local warm = spec.kind == "torch"
		local color = if warm then Color3.fromRGB(255, 168, 86) else Color3.fromRGB(150, 230, 176)
		local host = makePart(
			if warm then "Torch" else "Crystal",
			Vector3.new(1.1, 1.5, 1.1),
			roomCFrame(place, Vector3.new(spec.x, spec.y, spec.z)),
			color,
			model,
			false
		)
		host.Material = Enum.Material.Glass
		host.CastShadow = false
		host.CanTouch = false
		host.CanQuery = false
		local glow = Instance.new("PointLight")
		glow.Name = "PointLight"
		glow.Color = color
		glow.Brightness = if spec.kind == "floor" then 1.15 else 1.35
		glow.Range = if spec.kind == "floor" then 42 else 32
		glow.Shadows = false
		glow.Parent = host
	end

	sign(model, roomCFrame(place, Vector3.new(0, 5, -half + 0.8)), room.name, 16)

	-- The green pad is the door. Touched on the server, and only after the
	-- room's enemies are dead. The panel's Next room button calls the same path.
	local portal = makePart(
		"Portal",
		Vector3.new(7, 0.6, 7),
		roomCFrame(place, Vector3.new(0, 0.4, Dungeons.PORTAL_Z)),
		Color3.fromRGB(72, 180, 110),
		model,
		false
	)
	portal.Material = Enum.Material.Neon
	portal.CanTouch = true
	portal:SetAttribute("RoomIndex", place)
	portal:SetAttribute("DungeonId", dungeon.id)
	sign(model, roomCFrame(place, Vector3.new(0, 3.2, Dungeons.PORTAL_Z)), "NEXT", 6)
	return placed
end

local function purgeSavedWorld()
	-- Rojo leaves every Workspace child in place. A saved ShardfallWorld
	-- or an older hub (the one with "Spawn" and "Dungeon Portals" boards)
	-- draws on top of the hub this server is about to build.
	local removed = 0
	for _, child in ipairs(workspace:GetChildren()) do
		local humanoid = child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") ~= nil
		local isCharacter = child:IsA("Model") and Players:GetPlayerFromCharacter(child) ~= nil
		if SavedWorld.shouldRemove(child.Name, child.ClassName, humanoid == true, isCharacter) then
			print(
				string.format(
					"[Shardfall] removed saved world %s (%s). Rojo does not manage Workspace.",
					child:GetFullName(),
					child.ClassName
				)
			)
			child:Destroy()
			removed += 1
		end
	end
	if removed == 0 then
		print("[Shardfall] no saved Workspace world to remove")
	end
end

local function buildWorld()
	purgeSavedWorld()

	local world = Instance.new("Folder")
	world.Name = "ShardfallWorld"
	world.Parent = workspace
	worldFolder = world
	-- Persistent before the model is parented, and a direct Workspace child
	-- so it shows up next to Terrain instead of inside a folder.
	local hub = Instance.new("Model")
	hub.Name = "Haven"
	hub.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	hub.Parent = workspace
	local built, hubResult = pcall(HavenBuilder.build, hub)
	if built then
		local count = if type(hubResult) == "number" then hubResult else 0
		print(string.format("[Shardfall] Haven hub built (%d parts)", count))
	else
		warn("[Shardfall] Haven hub failed to build: " .. tostring(hubResult))
	end

	local rooms = Instance.new("Folder")
	rooms.Name = "Rooms"
	rooms.Parent = world
	local _, _, roomZ = Dungeons.roomOrigin(1)
	print(string.format("[Shardfall] Rootvault rooms start at z=%.0f", roomZ))
	local dungeon = Dungeons.get(Dungeons.ROOTVAULT_ID)
	assert(dungeon ~= nil, "Rootvault is missing from Dungeons.luau")
	local dressed = 0
	for index = 1, #dungeon.rooms do
		dressed += buildRoom(rooms, dungeon, index)
	end
	local waves = Dungeons.get(Dungeons.WAVES_ID)
	assert(waves ~= nil, "Rootvault Waves is missing from Dungeons.luau")
	dressed += buildRoom(rooms, waves, 1, Dungeons.WAVES_ROOM_INDEX)
	print(string.format("[Shardfall] Rootvault forest kit placed %d models", dressed))

	local active = Instance.new("Folder")
	active.Name = "Active"
	active.Parent = world
	activeFolder = active
end

local function publicRun(player: Player): { [string]: any }
	local profile = DataService.get(player)
	local ascension = if profile ~= nil then profile.ascension else 0
	local note = Dungeons.progressNote(ascension)
	local run = runs[player]
	if run == nil then
		return {
			active = false,
			note = note,
		}
	end
	local room = run.dungeon.rooms[run.roomIndex]
	local remaining = 0
	local boss = false
	local phase = nil
	local stagger = 0
	for _, enemy in pairs(run.enemies) do
		if enemy.hp > 0 then
			remaining += 1
			if enemy.boss then
				boss = true
				phase = enemy.phase
				stagger = enemy.stagger
			end
		end
	end
	local countdown = nil
	if run.advanceAt ~= nil then
		countdown = math.max(0, math.ceil(run.advanceAt - os.clock()))
	end
	local endless = run.dungeon.endless == true
	return {
		active = true,
		dungeonId = run.dungeon.id,
		dungeonName = run.dungeon.name,
		roomName = if endless then "Arena" elseif room ~= nil then room.name else "",
		roomIndex = if endless then run.wave else run.roomIndex,
		roomCount = if endless then 0 else #run.dungeon.rooms,
		remaining = remaining,
		cleared = run.cleared,
		boss = boss,
		phase = phase,
		stagger = stagger,
		staggerMax = CombatFeel.STAGGER_MAX,
		note = note,
		endless = endless,
		wave = if endless then run.wave else nil,
		countdown = countdown,
		difficulty = run.difficulty,
		doors = run.offer,
		shrine = run.shrine,
	}
end

local function pushRun(player: Player, text: string?)
	fx(player, {
		kind = "run",
		run = publicRun(player),
		text = text,
	})
end

local function paintEnemy(enemy: Enemy)
	enemy.part:SetAttribute("ShardfallHp", enemy.hp)
	enemy.part:SetAttribute("ShardfallMax", enemy.maxHp)
	local fill = enemy.part:FindFirstChild("Fill", true)
	if fill ~= nil and fill:IsA("Frame") then
		local ratio = 0
		if enemy.maxHp > 0 then
			ratio = math.clamp(enemy.hp / enemy.maxHp, 0, 1)
		end
		fill.Size = UDim2.fromScale(ratio, 1)
	end
end

local function dropPickup(parent: Instance, position: Vector3, landed: { [string]: number })
	local index = 0
	for _, materialId in ipairs(Materials.ORDER) do
		local count = landed[materialId]
		if type(count) ~= "number" or count <= 0 then
			continue
		end
		index += 1
		local rarity = Materials.rarityName(materialId)
		local red, green, blue = Rarities.rgb(rarity)
		local anchor = Instance.new("Part")
		anchor.Name = Materials.displayName(materialId)
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = position + Vector3.new(0, 2.4 + (index - 1) * 0.9, 0)
		anchor.Parent = parent

		local gui = Instance.new("BillboardGui")
		gui.Name = "DropLabel"
		gui.Size = UDim2.fromOffset(180, 28)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Name = "Material"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = 16
		label.TextColor3 = Color3.fromRGB(red, green, blue)
		label.TextStrokeTransparency = 0.35
		label.Text = string.format("%s x%d", Materials.displayName(materialId), count)
		label.Parent = gui

		task.delay(8, function()
			if anchor.Parent ~= nil then
				anchor:Destroy()
			end
		end)
	end
end

local function enemyBar(part: BasePart, name: string, color: Color3, lift: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShardfallBar"
	gui.Size = UDim2.fromOffset(96, 28)
	gui.StudsOffset = Vector3.new(0, lift, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 14)
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(240, 236, 248)
	label.TextStrokeTransparency = 0.45
	label.Text = name
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 16)
	back.Size = UDim2.new(1, 0, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
end

local function clearEnemies(run: Run)
	for _, enemy in pairs(run.enemies) do
		local model = enemy.part.Parent
		if model ~= nil and model:IsA("Model") then
			model:Destroy()
		else
			enemy.part:Destroy()
		end
	end
	run.enemies = {}
	if run.sunbeam ~= nil then
		run.sunbeam:Destroy()
		run.sunbeam = nil
	end
end

local function placeSunbeam(run: Run)
	local beam = run.sunbeam
	if beam == nil then
		return
	end
	local offset = Dungeons.SUNBEAM_OFFSETS[run.sunbeamIndex]
	if offset == nil then
		run.sunbeamIndex = 1
		offset = Dungeons.SUNBEAM_OFFSETS[1]
	end
	local x, _, z = Dungeons.roomOrigin(run.placeIndex)
	beam.CFrame = CFrame.new(x + offset.x, 0.45, z + offset.z)
end

local function spawnEnemy(run: Run, kind: string, offset: Vector3, wave: number?): Enemy?
	local definition = Dungeons.enemy(kind)
	if definition == nil then
		return nil
	end
	nextEnemyId += 1
	local id = "e" .. tostring(nextEnemyId)
	local size = Vector3.new(definition.size[1], definition.size[2], definition.size[3])
	local color = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
	local y = size.Y / 2 + definition.hover
	local health = definition.maxHealth
	local damage = definition.damage
	if wave ~= nil then
		health, damage =
			Dungeons.waveStats(definition.maxHealth, definition.damage, wave, definition.boss)
	end
	health, damage = Rootvault.scale(run.difficulty, health, damage)
	local fog = definition.fogDamage
	if fog > 0 and wave ~= nil then
		fog = select(2, Dungeons.waveStats(1, fog, wave, definition.boss))
	end
	if fog > 0 then
		fog = select(2, Rootvault.scale(run.difficulty, 0, fog))
	end
	if run.dungeon.id == Dungeons.HEARTWOOD_ID then
		local hpMul, dmgMul = Raids.combatScale(run.difficulty, run.raidPlayers, run.healerPresent)
		health = math.floor(health * hpMul + 0.5)
		damage = math.floor(damage * dmgMul + 0.5)
		if fog > 0 then
			fog = math.floor(fog * dmgMul + 0.5)
		end
	end
	local elite = false
	if run.eliteNext and definition.boss ~= true then
		elite = true
		run.eliteNext = false
		health = math.floor(health * Rootvault.ELITE_HP + 0.5)
		damage = math.floor(damage * Rootvault.ELITE_DAMAGE + 0.5)
	end
	local rootCFrame = roomCFrame(run.placeIndex, Vector3.new(offset.X, y, offset.Z))
	local display = definition.name
	if run.dungeon.id == Dungeons.HEARTWOOD_ID then
		local room = run.dungeon.rooms[run.roomIndex]
		if room ~= nil then
			display = room.name
		end
	end
	local rigOk, rigOrErr = pcall(function()
		return ModelFactory.buildEnemy(run.folder, kind, rootCFrame, size, display)
	end)
	local part: BasePart
	if rigOk and typeof(rigOrErr) == "Instance" and (rigOrErr :: Instance):IsA("BasePart") then
		part = rigOrErr :: BasePart
	else
		local reason = if rigOk then "no recipe" else tostring(rigOrErr)
		warn(string.format("[Rootvault] %s rig failed (%s); anchored marker only", kind, reason))
		-- Small, anchored, and non-colliding. The old fallback was a full-size
		-- Grass block, which is what a failed rig looked like in play.
		part = makePart(display, Vector3.new(1.2, 1.2, 1.2), rootCFrame, color, run.folder, false)
		part.CanTouch = false
		part.CanQuery = true
		part.Massless = true
		part:SetAttribute("ShardfallRigFailed", true)
	end
	local host = part.Parent
	local rigModel = if host ~= nil and host:IsA("Model") then host else nil
	if rigModel ~= nil then
		local pieces = 0
		for _, descendant in ipairs(rigModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				pieces += 1
				if
					descendant.Anchored ~= true
					or descendant.CanCollide == true
					or descendant.CanTouch == true
				then
					warn("[Shardfall] Clamped loose part " .. descendant.Name .. " on " .. kind)
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanTouch = false
				end
			end
		end
		if pieces < 2 then
			warn(string.format("[Rootvault] %s rig has %d parts", kind, pieces))
		end
	end
	part:SetAttribute(
		"ShardfallName",
		if elite then "Elite " .. definition.name else definition.name
	)
	part:SetAttribute("EnemyId", id)
	part:SetAttribute("ShardfallKind", kind)
	local rimHost = if rigModel ~= nil then rigModel else part
	local highlight = Instance.new("Highlight")
	highlight.Name = "Rim"
	highlight.Adornee = rimHost
	highlight.FillColor =
		Color3.fromRGB(Dungeons.RIM.fill[1], Dungeons.RIM.fill[2], Dungeons.RIM.fill[3])
	highlight.FillTransparency = Dungeons.RIM.fillTransparency
	highlight.OutlineColor =
		Color3.fromRGB(Dungeons.RIM.outline[1], Dungeons.RIM.outline[2], Dungeons.RIM.outline[3])
	highlight.OutlineTransparency = Dungeons.RIM.outlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = rimHost
	enemyBar(part, definition.name, color, ModelFactory.barLift(kind))
	local enemy: Enemy = {
		id = id,
		kind = kind,
		name = definition.name,
		hp = health,
		maxHp = health,
		damage = damage,
		defense = definition.defense,
		attackSpeed = definition.attackSpeed,
		moveSpeed = definition.moveSpeed,
		range = definition.range,
		style = definition.style,
		minDot = definition.minDot,
		projectileSpeed = definition.projectileSpeed,
		boss = definition.boss,
		phase = 1,
		phase2At = definition.phase2At,
		weakSeconds = definition.weakSeconds,
		weakUntil = 0,
		armoredMultiplier = definition.armoredMultiplier,
		fogInterval = definition.fogInterval,
		fogDamage = fog,
		safeRadius = definition.safeRadius,
		nextFog = 0,
		nextAttack = os.clock() + 0.8,
		stagger = 0,
		stunUntil = 0,
		telegraphUntil = 0,
		telegraphColor = "red",
		hover = definition.hover,
		color = color,
		part = part,
	}
	paintEnemy(enemy)
	run.enemies[id] = enemy
	if enemy.boss then
		local beam = makePart(
			"Sunbeam",
			Vector3.new(definition.safeRadius * 2, 0.4, definition.safeRadius * 2),
			roomCFrame(run.placeIndex, Vector3.new(0, 0.4, 0)),
			Color3.fromRGB(255, 214, 90),
			run.folder,
			false
		)
		beam.Material = Enum.Material.Neon
		beam.Transparency = 1
		local beamSign = Instance.new("BillboardGui")
		beamSign.Size = UDim2.fromOffset(120, 24)
		beamSign.StudsOffset = Vector3.new(0, 3, 0)
		beamSign.AlwaysOnTop = true
		beamSign.Parent = beam
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = 16
		label.TextColor3 = Color3.fromRGB(255, 236, 160)
		label.Text = "Sunbeam"
		label.Parent = beamSign
		run.sunbeam = beam
		run.sunbeamIndex = 1
		placeSunbeam(run)
	end
	return enemy
end

local function spawnRoom(player: Player, run: Run)
	CombatService.clearShots(player)
	clearEnemies(run)
	run.cleared = false
	local room = run.dungeon.rooms[run.roomIndex]
	if room == nil then
		return
	end
	for index, kind in ipairs(room.enemies) do
		local offset = SPAWNS[((index - 1) % #SPAWNS) + 1]
		spawnEnemy(run, kind, offset)
	end
	local bossRoom = run.roomIndex == #run.dungeon.rooms
	local text = string.format("%s  ·  %s", run.dungeon.name, room.name)
	if bossRoom then
		text ..= ". Slam, then hit the gold weak spot. At half HP, stand in the sunbeam."
	end
	pushRun(player, text)
end

local function spawnWave(player: Player, run: Run)
	CombatService.clearShots(player)
	clearEnemies(run)
	run.cleared = false
	run.advanceAt = nil
	local kinds = Dungeons.waveKinds(run.wave)
	for index, kind in ipairs(kinds) do
		local offset = SPAWNS[((index - 1) % #SPAWNS) + 1]
		spawnEnemy(run, kind, offset, run.wave)
	end
	local text = string.format("%s  ·  Wave %d", run.dungeon.name, run.wave)
	if Dungeons.isBossWave(run.wave) then
		text ..= ". Boss wave. Slam, then the sunbeam at half HP."
	end
	pushRun(player, text)
end

local function destroyRun(player: Player, run: Run)
	clearEnemies(run)
	run.folder:Destroy()
	runs[player] = nil
	CombatService.clearShots(player)
end

local function grant(
	player: Player,
	run: Run,
	rolledOverride: Dungeons.ClearReward?,
	dismissIn: number?
)
	local rolled = rolledOverride
	if rolled == nil then
		rolled = Dungeons.rollClear(run.dungeon, RollMath.defaultRng())
	end
	if rolled == nil then
		return false
	end
	if run.practice == true then
		fx(player, { kind = "hint", text = "Practice Grove. No loot." })
		return true
	end
	local profile = DataService.get(player)
	local _, _, goldFind = CombatMath.loadout(profile)
	local bonus = CombatMath.bonusGold(rolled.gold, goldFind)
	local levels = 0
	local xpShown = rolled.xp
	local ok, err = DataService.mutate(player, function(data)
		local elapsed = 0
		if farmSince[player] ~= nil then
			elapsed = os.clock() - farmSince[player]
		end
		local paid, _, stopFarm =
			Economy.farmPayout(rolled.gold + bonus, farmOn[player] == true, elapsed)
		if stopFarm then
			farmOn[player] = false
		end
		data.gold += paid
		Economy.log(data, "dungeon_clear", "gold", paid, data.gold)
		data.shardTokens += rolled.shardTokens
		local xpGain = rolled.xp
		if run.dungeon.endless ~= true and run.dungeon.id == Dungeons.ROOTVAULT_ID then
			local today = Loops.dayNumber(os.time())
			local mult, day, rare = Loops.firstClear(data.firstClearDay or -1, today)
			data.firstClearDay = day
			xpGain = rolled.xp * mult
			if rare and type(data.chests) == "table" then
				data.chests.Rare = (data.chests.Rare or 0) + 1
			end
			if run.difficulty == "nightmare" then
				local seconds = math.max(1, math.floor(os.clock() - run.startedAt))
				if (data.nightmareBest or 0) == 0 or seconds < data.nightmareBest then
					data.nightmareBest = seconds
				end
			end
		end
		data.passXp = select(1, Loops.passXp(data.passXp or 0, 40))
		xpShown = xpGain
		levels = Progression.addXp(data, xpGain)
		if
			run.dungeon.id == Dungeons.HEARTWOOD_ID
			and run.difficulty == "normal"
			and run.practice ~= true
		then
			local seconds = math.max(1, math.floor(os.clock() - run.startedAt))
			if (data.raidBest or 0) == 0 or seconds < data.raidBest then
				data.raidBest = seconds
			end
		end
		for materialId, count in pairs(rolled.materials) do
			Materials.add(data.materials, materialId, count)
		end
		if rolled.voucher == "armory" or rolled.voucher == "pets" then
			data.vouchers[rolled.voucher] = (data.vouchers[rolled.voucher] or 0) + 1
		end
		if run.dungeon.endless == true then
			-- Boss waves already paid their chest when the boss died.
			if not Dungeons.isBossWave(run.wave) then
				ChestConfig.grantSource(data, "room", os.time())
			end
		else
			ChestConfig.grantSource(data, "clear", os.time())
		end
		return nil
	end)
	if not ok then
		warn("[Shardfall] Rootvault reward failed:", err)
		fx(player, {
			kind = "defeat",
			text = "The clear could not be saved. No rewards were granted.",
		})
		return false
	end
	if run.dungeon.endless ~= true then
		LoopService.progress(player, "rooms", 1)
	end
	if
		run.dungeon.id == Dungeons.HEARTWOOD_ID
		and run.difficulty == "normal"
		and run.practice ~= true
	then
		local seconds = math.max(1, math.floor(os.clock() - run.startedAt))
		require(script.Parent.RaidService).recordTime(player.Name, seconds)
	end
	if run.difficulty == "nightmare" and run.dungeon.endless ~= true then
		local seconds = math.max(1, math.floor(os.clock() - run.startedAt))
		LoopService.recordTime(player.Name, player.UserId, seconds)
	end

	local gained: { [string]: number } = {}
	Materials.merge(gained, rolled.materials)
	Materials.merge(gained, run.loot)
	local lines = {}
	for _, materialId in ipairs(Materials.ORDER) do
		local count = gained[materialId]
		if type(count) == "number" and count > 0 then
			table.insert(lines, {
				name = Materials.displayName(materialId),
				count = count,
			})
		end
	end
	if dismissIn == nil then
		local bits =
			{ string.format("+%d gold", rolled.gold + bonus), string.format("+%d XP", xpShown) }
		if rolled.shardTokens > 0 then
			table.insert(bits, string.format("+%d tokens", rolled.shardTokens))
		end
		fx(player, {
			kind = "hint",
			text = string.format("Wave %d cleared. %s.", run.wave, table.concat(bits, ", ")),
		})
	else
		fx(player, {
			kind = "victory",
			dungeonName = run.dungeon.name,
			gold = rolled.gold,
			bonusGold = bonus,
			shardTokens = rolled.shardTokens,
			xp = xpShown,
			levels = levels,
			materials = lines,
			voucher = rolled.voucher,
			dismissIn = dismissIn,
		})
	end
	return true
end

local function scheduleRestart(player: Player, dungeonId: string, delay: number)
	if farmOn[player] ~= true or player.Parent == nil then
		return
	end
	restartAt[player] = {
		at = os.clock() + delay,
		dungeonId = dungeonId,
	}
end

local function finish(player: Player, victory: boolean)
	local run = runs[player]
	if run == nil or run.resolving then
		return
	end
	run.resolving = true
	local dungeonId = run.dungeon.id
	local endless = run.dungeon.endless == true
	local farming = farmOn[player] == true
	local cardSeconds = if farming
		then Dungeons.FARM_RESTART_SECONDS
		else Dungeons.VICTORY_CARD_SECONDS
	local saved = true
	if victory then
		saved = grant(player, run, nil, cardSeconds)
	else
		local text = if endless
			then "The waves stop when you fall. Rewards from cleared waves are still yours."
			else "The Rootvault pushes you out. Materials from earlier clears are still yours."
		fx(player, {
			kind = "defeat",
			text = text,
			dismissIn = if farming
				then Dungeons.FARM_DEFEAT_SECONDS
				else Dungeons.VICTORY_CARD_SECONDS,
		})
	end
	-- Move onto the hub before the run folder goes away, and only after
	-- teleport() has asked the client to stream that spot.
	CombatService.revive(player)
	teleport(player, hubCFrame())
	destroyRun(player, run)
	local note = "Defeated."
	if victory and saved then
		note = if endless then "Waves ended." else "Rootvault cleared."
	elseif victory then
		note = "Clear did not save."
	end
	pushRun(player, note)
	if farming then
		local delay = if victory
			then Dungeons.FARM_RESTART_SECONDS
			else Dungeons.FARM_DEFEAT_SECONDS
		scheduleRestart(player, dungeonId, delay)
	end
end

local function beginAdvance(player: Player, run: Run, text: string)
	run.cleared = true
	LoopService.progress(player, "rooms", 1)
	if run.dungeon.id == Dungeons.HEARTWOOD_ID and run.roomIndex < #run.dungeon.rooms then
		run.advanceAt = os.clock() + 2
		run.advanceShown = 2
		pushRun(player, text .. " Next wing in 2s.")
		return
	end
	if run.dungeon.endless ~= true and run.roomIndex < #run.dungeon.rooms then
		run.offer = Rootvault.offer(run.roomIndex, #run.dungeon.rooms, math.random(1, 5))
		run.advanceAt = nil
		pushRun(player, text .. " Two doors.")
		if farmOn[player] == true then
			task.delay(1.2, function()
				if runs[player] == run and run.offer ~= nil and run.offer[1] ~= nil then
					DungeonService.chooseDoor(player, run.offer[1].id)
				end
			end)
		end
		return
	end
	run.advanceAt = os.clock() + Dungeons.ADVANCE_SECONDS
	run.advanceShown = Dungeons.ADVANCE_SECONDS
	pushRun(player, text)
end

local function aliveCount(run: Run): number
	local count = 0
	for _, enemy in pairs(run.enemies) do
		if enemy.hp > 0 then
			count += 1
		end
	end
	return count
end

local function clearNamed(folder: Instance, name: string)
	local existing = folder:FindFirstChild(name)
	if existing ~= nil then
		existing:Destroy()
	end
end

local function marker(
	run: Run,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	life: number,
	particle: string?
)
	clearNamed(run.folder, name)
	local part = makePart(name, size, CFrame.new(position), color, run.folder, false)
	part.Material = Enum.Material.Neon
	part.Transparency = if particle ~= nil then 0.72 else 0.35
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if particle ~= nil then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = particle
		emitter.Rate = 14
		emitter.Lifetime = NumberRange.new(0.8, 1.6)
		emitter.Speed = NumberRange.new(0.4, 1.4)
		emitter.LightEmission = 0.8
		emitter.Size = NumberSequence.new(0.8)
		emitter.Color = ColorSequence.new(color)
		emitter.Parent = part
	end
	task.delay(life, function()
		if part.Parent ~= nil then
			part:Destroy()
		end
	end)
end

local function summonSaplings(run: Run)
	clearNamed(run.folder, "Saplings")
	local folder = Instance.new("Folder")
	folder.Name = "Saplings"
	folder.Parent = run.folder
	local marks = VerdantLook.MARKERS
	local offsets = {
		Vector3.new(-10, marks.slam.y, 6),
		Vector3.new(10, marks.slam.y, 4),
		Vector3.new(2, marks.slam.y, -8),
	}
	for index = 1, marks.saplingCount do
		local offset = offsets[index]
		if offset ~= nil then
			local feet = roomCFrame(run.placeIndex, offset)
			ModelFactory.place(folder, marks.sapling, feet, index * 0.6, marks.saplingScale)
		end
	end
end

function DungeonService.damageEnemy(
	player: Player,
	enemyId: string,
	amount: number,
	_crit: boolean,
	heavy: boolean?
)
	local run = runs[player]
	if run == nil or run.resolving then
		return
	end
	local enemy = run.enemies[enemyId]
	if enemy == nil or enemy.hp <= 0 then
		return false
	end
	local now = os.clock()
	if now < enemy.stunUntil then
		amount = math.floor(amount * 1.25 + 0.5)
	end
	if run.shrine == "might" then
		amount = math.floor(amount * 1.15 + 0.5)
	end
	if run.echo > 0 then
		amount = math.floor(amount * (1 + run.echo * 0.05) + 0.5)
	end
	enemy.hp -= amount
	if enemy.hp < 0 then
		enemy.hp = 0
	end
	paintEnemy(enemy)
	pcall(ModelFactory.flash, enemy.part)
	if enemy.hp > 0 then
		if enemy.boss then
			local bar, stunned = CombatFeel.applyStagger(enemy.stagger, heavy == true, true)
			enemy.stagger = bar
			if stunned then
				enemy.stunUntil = now + CombatFeel.STAGGER_STUN
				pushRun(player, "Staggered. The bark splits.")
			end
		else
			enemy.stunUntil = now + CombatFeel.NORMAL_STAGGER
		end
	elseif heavy == true or enemy.boss then
		fx(player, {
			kind = "kill",
			shards = true,
			x = enemy.part.Position.X,
			y = enemy.part.Position.Y + 2,
			z = enemy.part.Position.Z,
		})
	end
	if enemy.boss then
		local phase = if enemy.kind == "grandmother_gnarl"
			then Rootvault.gnarlPhase(enemy.hp, enemy.maxHp)
			else Dungeons.bossPhase(enemy.hp, enemy.maxHp, enemy.phase2At)
		if phase ~= enemy.phase and enemy.hp > 0 then
			enemy.phase = phase
			enemy.weakUntil = 0
			if phase == 2 then
				enemy.nextFog = os.clock() + enemy.fogInterval
				ModelFactory.tintNamed(enemy.part, "Eye", Color3.fromRGB(176, 120, 255))
				if run.sunbeam ~= nil then
					run.sunbeam.Transparency = 0
				end
				placeSunbeam(run)
				summonSaplings(run)
			elseif phase == 3 then
				enemy.attackSpeed = enemy.attackSpeed * 1.25
				ModelFactory.tintNamed(enemy.part, "Eye", Color3.fromRGB(255, 140, 48))
			end
			pushRun(player, Rootvault.phaseNote(phase))
		end
	end
	if enemy.hp <= 0 then
		-- Manual swings and Auto-Farm both call damageEnemy, so both grant drops.
		local landed = {}
		local chestBits = {}
		local saved, saveErr = DataService.mutate(player, function(data)
			landed = Drops.apply(data.materials, enemy.kind, RollMath.defaultRng())
			local drop = ChestConfig.enemyDrop(data, enemy.kind, RollMath.defaultRng())
			if drop ~= nil then
				table.insert(chestBits, drop.label)
			end
			if enemy.boss and run.dungeon.id == Dungeons.HEARTWOOD_ID and run.practice ~= true then
				local room = run.dungeon.rooms[run.roomIndex]
				local bossId = if room ~= nil then room.id else "wing"
				local paid, dropped =
					Raids.applyClear(data, bossId, run.difficulty, os.time(), math.random())
				table.insert(chestBits, string.format("%d Raid Marks", paid))
				if dropped then
					table.insert(chestBits, "raid gear")
				end
			end
			if enemy.boss then
				for _, row in ipairs(ChestConfig.bossKill(data, os.time())) do
					table.insert(chestBits, row.label)
				end
				local floorTier = Rootvault.difficulty(run.difficulty).chest
				if floorTier == "Uncommon" or floorTier == "Rare" then
					data.chests[floorTier] = (data.chests[floorTier] or 0) + 1
					table.insert(chestBits, floorTier .. " chest")
				end
			end
			return nil
		end)
		if saved then
			local bits = {}
			for _, materialId in ipairs(Materials.ORDER) do
				local count = landed[materialId]
				if count ~= nil and count > 0 then
					run.loot[materialId] = (run.loot[materialId] or 0) + count
					table.insert(
						bits,
						string.format("%s x%d", Materials.displayName(materialId), count)
					)
				end
			end
			for _, label in ipairs(chestBits) do
				table.insert(bits, label)
			end
			if #bits > 0 then
				-- The world label is the material, never the enemy that dropped it.
				dropPickup(run.folder, enemy.part.Position, landed)
				fx(player, {
					kind = "hint",
					text = "Picked up " .. table.concat(bits, ", ") .. ".",
				})
			end
		else
			warn("[Shardfall] Drop failed:", saveErr)
		end
		pcall(ModelFactory.dissolve, enemy.part)
		enemy.part.Name = "Remains"
		enemy.part:SetAttribute("ShardfallName", "")
		enemy.part.Transparency = 1
		local bar = enemy.part:FindFirstChild("ShardfallBar")
		if bar ~= nil then
			bar:Destroy()
		end
		if aliveCount(run) == 0 then
			if run.dungeon.endless == true then
				grant(player, run, Dungeons.waveReward(run.wave), nil)
				beginAdvance(
					player,
					run,
					string.format(
						"Wave %d clear. Next wave in %ds.",
						run.wave,
						Dungeons.ADVANCE_SECONDS
					)
				)
			elseif run.roomIndex >= #run.dungeon.rooms then
				finish(player, true)
			else
				DataService.mutate(player, function(data)
					ChestConfig.grantSource(data, "room", os.time())
					return nil
				end)
				beginAdvance(
					player,
					run,
					string.format("Room clear. Next room in %ds.", Dungeons.ADVANCE_SECONDS)
				)
			end
		end
	end
	return enemy.hp <= 0
end

function DungeonService.enemyViews(player: Player): { CombatService.EnemyView }
	local run = runs[player]
	if run == nil then
		return {}
	end
	local now = os.clock()
	local views = {}
	for _, enemy in pairs(run.enemies) do
		if enemy.hp > 0 then
			local position = enemy.part.Position
			table.insert(views, {
				id = enemy.id,
				defense = enemy.defense,
				boss = enemy.boss,
				phase = enemy.phase,
				weak = enemy.boss and enemy.phase == 1 and now < enemy.weakUntil,
				armoredMultiplier = enemy.armoredMultiplier,
				x = position.X,
				y = position.Y,
				z = position.Z,
			})
		end
	end
	return views
end

function DungeonService.isInRun(player: Player): boolean
	local run = runs[player]
	return run ~= nil and not run.resolving
end

local function moveEnemy(
	enemy: Enemy,
	playerPosition: Vector3,
	dt: number,
	roomIndex: number,
	floorSize: number
)
	if
		enemy.part.Anchored ~= true
		or enemy.part.CanCollide == true
		or enemy.part.CanTouch == true
	then
		warn("[Shardfall] Re-anchored loose enemy " .. enemy.name)
		enemy.part.AssemblyLinearVelocity = Vector3.zero
		enemy.part.AssemblyAngularVelocity = Vector3.zero
		enemy.part.Anchored = true
		enemy.part.CanCollide = false
		enemy.part.CanTouch = false
	end
	local position = enemy.part.Position
	local goal = Vector3.new(playerPosition.X, position.Y, playerPosition.Z)
	local offset = goal - position
	local distance = offset.Magnitude
	local hold = math.max(2, enemy.range * 0.65)
	if distance > hold then
		local step = math.min(distance - hold, enemy.moveSpeed * dt)
		local nextPosition = position + offset.Unit * step
		local x, _, z = Dungeons.roomOrigin(roomIndex)
		local limit = floorSize / 2 - 4
		nextPosition = Vector3.new(
			math.clamp(nextPosition.X, x - limit, x + limit),
			position.Y,
			math.clamp(nextPosition.Z, z - limit, z + limit)
		)
		enemy.part.CFrame = CFrame.lookAt(nextPosition, Vector3.new(goal.X, nextPosition.Y, goal.Z))
	else
		enemy.part.CFrame = CFrame.lookAt(position, Vector3.new(goal.X, position.Y, goal.Z))
	end
end

local function tickEnemy(
	player: Player,
	run: Run,
	enemy: Enemy,
	hrp: BasePart,
	dt: number,
	now: number
)
	if enemy.hp <= 0 then
		return
	end
	if now < enemy.stunUntil then
		return
	end
	moveEnemy(enemy, hrp.Position, dt, run.placeIndex, run.dungeon.floorSize)
	pcall(ModelFactory.step, enemy.part, now, true)

	if enemy.boss and enemy.phase == 1 then
		if now < enemy.weakUntil then
			ModelFactory.tintNamed(enemy.part, "WeakSpot", Color3.fromRGB(255, 196, 64))
		else
			ModelFactory.tintNamed(enemy.part, "WeakSpot", nil)
		end
	end

	local strikeDue = enemy.telegraphUntil > 0 and now >= enemy.telegraphUntil
	local fogDue = enemy.boss
		and enemy.phase == 2
		and run.sunbeam ~= nil
		and enemy.fogInterval > 0
		and now >= enemy.nextFog
	local doFog = (Rootvault.sameBeat(fogDue, strikeDue))
	if doFog and run.sunbeam ~= nil then
		local beam = run.sunbeam
		local safe = CombatMath.withinPlanar(
			hrp.Position.X,
			hrp.Position.Z,
			beam.Position.X,
			beam.Position.Z,
			enemy.safeRadius
		)
		local down = false
		if not safe then
			down = CombatService.damagePlayer(
				player,
				enemy.fogDamage,
				hrp.Position.X,
				hrp.Position.Y,
				hrp.Position.Z
			)
		end
		run.sunbeamIndex = (run.sunbeamIndex % #Dungeons.SUNBEAM_OFFSETS) + 1
		placeSunbeam(run)
		local cloud = VerdantLook.MARKERS.spore
		local originX, _, originZ = Dungeons.roomOrigin(run.placeIndex)
		marker(
			run,
			cloud.name,
			Vector3.new(cloud.size[1], cloud.size[2], cloud.size[3]),
			Vector3.new(originX, cloud.y, originZ),
			Color3.fromRGB(cloud.color[1], cloud.color[2], cloud.color[3]),
			math.max(1.2, enemy.fogInterval * 0.85),
			"spores"
		)
		enemy.nextFog = now + enemy.fogInterval
		if down or runs[player] == nil then
			return
		end
	end

	if enemy.telegraphUntil > 0 then
		if now < enemy.telegraphUntil then
			return
		end
		local position = enemy.part.Position
		local endsAt = enemy.telegraphUntil
		enemy.telegraphUntil = 0
		enemy.nextAttack = now + CombatMath.cooldown(enemy.attackSpeed)
		if enemy.style == "projectile" then
			CombatService.launchEnemyShot(
				player,
				position,
				hrp.Position,
				enemy.damage,
				enemy.projectileSpeed,
				enemy.range
			)
		else
			CombatService.damagePlayer(
				player,
				enemy.damage,
				hrp.Position.X,
				hrp.Position.Y,
				hrp.Position.Z,
				endsAt
			)
			if enemy.boss and enemy.phase == 1 and runs[player] ~= nil then
				enemy.weakUntil = os.clock() + enemy.weakSeconds
			end
		end
		return
	end
	if now < enemy.nextAttack then
		return
	end
	local position = enemy.part.Position
	local distance =
		CombatMath.planarDistance(position.X, position.Z, hrp.Position.X, hrp.Position.Z)
	if distance > enemy.range then
		return
	end
	local colorName = "red"
	if enemy.boss and enemy.phase >= 3 then
		colorName = "blue"
	elseif enemy.boss and enemy.phase >= 2 then
		colorName = "purple"
	elseif enemy.kind == "thorn_sprite" then
		colorName = "red"
	end
	local cue = CombatFeel.telegraph(colorName, "normal")
	enemy.telegraphColor = cue.color
	enemy.telegraphUntil = now + cue.seconds
	fx(player, {
		kind = "telegraph",
		color = cue.color,
		verb = cue.verb,
		seconds = cue.seconds,
		endsAt = enemy.telegraphUntil,
		x = hrp.Position.X,
		y = hrp.Position.Y,
		z = hrp.Position.Z,
	})
	marker(
		run,
		"Telegraph",
		Vector3.new(8, 0.2, 8),
		Vector3.new(hrp.Position.X, 0.3, hrp.Position.Z),
		Color3.fromRGB(cue.rgb[1], cue.rgb[2], cue.rgb[3]),
		cue.seconds,
		nil
	)
end

local function tickAdvance(player: Player, run: Run, now: number)
	if not run.cleared or run.resolving or run.advanceAt == nil then
		return
	end
	local left = math.ceil(run.advanceAt - now)
	if left < 0 then
		left = 0
	end
	if left > 0 and left ~= run.advanceShown then
		run.advanceShown = left
		pushRun(player, string.format("Next in %ds.", left))
	end
	if now >= run.advanceAt then
		run.advanceAt = nil
		DungeonService.advance(player)
	end
end

local function farmPath(player: Player, run: Run, hrp: BasePart)
	if farmOn[player] ~= true or not CombatService.autoEnabled(player) then
		return
	end
	local character = hrp.Parent
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if CombatService.isSteering(player) then
		if run.yielding ~= true then
			run.yielding = true
			humanoid:MoveTo(hrp.Position)
		end
		return
	end
	run.yielding = false
	local offense = CombatMath.loadout(DataService.get(player))
	local enemy = CombatMath.nearestInRange(
		hrp.Position.X,
		hrp.Position.Z,
		DungeonService.enemyViews(player),
		10000
	)
	if enemy == nil then
		return
	end
	local near, far = CombatMath.farmBand(offense.style, offense.range)
	local dx = enemy.x - hrp.Position.X
	local dz = enemy.z - hrp.Position.Z
	local distance = math.sqrt(dx * dx + dz * dz)
	local dest: Vector3? = nil
	if distance > far and distance > 0.05 then
		dest = Vector3.new(
			enemy.x - dx / distance * far,
			hrp.Position.Y,
			enemy.z - dz / distance * far
		)
	elseif near > 0 and distance < near and distance > 0.05 then
		local awayX = hrp.Position.X - enemy.x
		local awayZ = hrp.Position.Z - enemy.z
		local away = math.sqrt(awayX * awayX + awayZ * awayZ)
		if away > 0.05 then
			dest = Vector3.new(
				hrp.Position.X + awayX / away * 6,
				hrp.Position.Y,
				hrp.Position.Z + awayZ / away * 6
			)
		end
	end
	if dest ~= nil then
		run.walking = true
		humanoid:MoveTo(dest)
	elseif run.walking == true then
		run.walking = false
		humanoid:MoveTo(hrp.Position)
	end
end

local function onHeartbeat(dt: number)
	local step = math.min(dt, 0.1)
	local now = os.clock()
	for player, run in pairs(runs) do
		if run.resolving or player.Parent == nil then
			continue
		end
		local hrp = rootPart(player)
		if hrp == nil then
			continue
		end
		if hrp.Position.Y < -40 then
			if (fallAt[player] or 0) <= now then
				fallAt[player] = now + 1
				print(
					"[Shardfall] " .. player.Name .. " fell out of the room; returning to the spawn"
				)
				teleport(player, roomSpawn(run.placeIndex))
			end
			continue
		end
		if run.cleared then
			tickAdvance(player, run, now)
			continue
		end
		for _, enemy in pairs(run.enemies) do
			if runs[player] == nil or run.resolving then
				break
			end
			tickEnemy(player, run, enemy, hrp, step, now)
		end
		if runs[player] ~= nil and not run.resolving and not run.cleared then
			CombatService.companionTick(player)
			CombatService.autoTick(player)
			farmPath(player, run, hrp)
		end
	end
	local pending = {}
	for player, plan in pairs(restartAt) do
		table.insert(pending, { player = player, plan = plan })
	end
	for _, row in ipairs(pending) do
		local player = row.player
		local plan = row.plan
		if restartAt[player] ~= plan then
			continue
		end
		if farmOn[player] ~= true or player.Parent == nil or runs[player] ~= nil then
			restartAt[player] = nil
			continue
		end
		if now >= plan.at then
			restartAt[player] = nil
			local result = DungeonService.enter(player, plan.dungeonId)
			if result.ok ~= true then
				pushRun(player, result.error)
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if runs[player] ~= nil or player.Parent == nil then
			continue
		end
		local hrp = rootPart(player)
		if hrp == nil or not Haven.fellOffHub(hrp.Position.Y) then
			continue
		end
		if (fallAt[player] or 0) > now then
			continue
		end
		fallAt[player] = now + 2
		print("[Shardfall] " .. player.Name .. " fell off Haven; returning to HubSpawn")
		teleport(player, hubCFrame())
	end
end

local function reject(message: string)
	return { ok = false, error = message }
end

function DungeonService.setAutoFarm(player: Player, enabled: boolean)
	farmOn[player] = enabled
	if enabled then
		if farmSince[player] == nil then
			farmSince[player] = os.clock()
		end
	else
		restartAt[player] = nil
		farmSince[player] = nil
	end
end

function DungeonService.autoFarmEnabled(player: Player): boolean
	return farmOn[player] == true
end

function DungeonService.enter(player: Player, dungeonId: any, difficulty: any, practice: boolean?)
	restartAt[player] = nil
	if runs[player] ~= nil then
		return reject("You are already in a dungeon. Leave first.")
	end
	if dungeonId == nil then
		dungeonId = Dungeons.ROOTVAULT_ID
	end
	if type(dungeonId) ~= "string" then
		return reject("Unknown dungeon.")
	end
	local dungeon = Dungeons.get(dungeonId)
	if dungeon == nil then
		return reject("Unknown dungeon.")
	end
	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	if not Dungeons.isUnlocked(dungeon, profile.ascension) then
		return reject(
			string.format("Reach Ascension %d to enter %s.", dungeon.ascension, dungeon.name)
		)
	end
	if dungeon.implemented ~= true or #dungeon.rooms == 0 then
		return reject(dungeon.name .. " is not built yet.")
	end
	local raidMode = if dungeon.id == Dungeons.HEARTWOOD_ID
		then Raids.difficulty(difficulty)
		else nil
	if dungeon.id == Dungeons.HEARTWOOD_ID and raidMode == nil then
		return reject("Pick Story or Normal.")
	end
	local diff = Rootvault.difficulty(difficulty)
	if raidMode ~= nil and practice ~= true then
		if (profile.level or 1) < raidMode.level then
			return reject(string.format("Level %d opens The Heartwood.", raidMode.level))
		end
		if raidMode.id == "normal" and profile.raidStory ~= true then
			return reject("Clear Story once before Normal.")
		end
	elseif raidMode == nil and (profile.level or 1) < diff.level then
		return reject(string.format("Level %d opens %s.", diff.level, diff.id))
	end
	if activeFolder == nil then
		return reject("The dungeon world is still loading.")
	end

	local folder = Instance.new("Folder")
	folder.Name = "Run_"
		.. tostring(player.UserId)
		.. "_"
		.. HttpService:GenerateGUID(false):sub(1, 8)
	folder.Parent = activeFolder
	local endless = dungeon.endless == true
	local run: Run = {
		dungeon = dungeon,
		roomIndex = 1,
		enemies = {},
		cleared = false,
		resolving = false,
		folder = folder,
		sunbeam = nil,
		sunbeamIndex = 1,
		placeIndex = if endless then Dungeons.WAVES_ROOM_INDEX else 1,
		wave = if endless then 1 else 0,
		advanceAt = nil,
		advanceShown = nil,
		yielding = false,
		walking = false,
		loot = {},
		difficulty = if raidMode ~= nil then raidMode.id else diff.id,
		offer = nil,
		eliteNext = false,
		shrine = "",
		startedAt = os.clock(),
		practice = practice == true,
		raidPlayers = 1,
		healerPresent = false,
		echo = if raidMode ~= nil and raidMode.id == "story" then profile.raidEcho or 0 else 0,
	}
	runs[player] = run
	CombatService.refresh(player)
	-- Arrive before the rigs exist so nothing simulates at the room while the
	-- character is still streaming in from the hub.
	teleport(player, roomSpawn(run.placeIndex))
	if endless then
		spawnWave(player, run)
	else
		spawnRoom(player, run)
	end
	-- Same payload the Enter Rootvault button's remote returns, so a portal
	-- entry updates the panel instead of leaving that button stale.
	local note = if endless
		then "Entered Rootvault Waves."
		elseif raidMode ~= nil then "Entered The Heartwood."
		else "Entered the Rootvault."
	pushRun(player, note)
	return { ok = true, run = publicRun(player) }
end

function DungeonService.tuneRaid(player: Player, options: any)
	local run = runs[player]
	if run == nil or run.dungeon.id ~= Dungeons.HEARTWOOD_ID or type(options) ~= "table" then
		return reject("The Heartwood is not open.")
	end
	run.practice = options.practice == true
	run.raidPlayers = if type(options.players) == "number" then options.players else 1
	run.healerPresent = options.healer == true
	if type(options.echo) == "number" then
		run.echo = options.echo
	end
	local wing = if type(options.wing) == "number" then math.floor(options.wing) else 1
	if wing < 1 then
		wing = 1
	end
	if wing > #run.dungeon.rooms then
		wing = #run.dungeon.rooms
	end
	run.roomIndex = wing
	run.placeIndex = wing
	run.advanceAt = nil
	run.offer = nil
	teleport(player, roomSpawn(run.placeIndex))
	spawnRoom(player, run)
	local phase = if type(options.phase) == "number" then math.floor(options.phase) else 1
	for _, enemy in pairs(run.enemies) do
		if enemy.boss and phase >= 2 then
			local ratio = if phase >= 3 then Rootvault.PHASE3 else Rootvault.PHASE2
			enemy.hp = math.max(1, math.floor(enemy.maxHp * ratio))
			enemy.phase = phase
		end
	end
	local room = run.dungeon.rooms[wing]
	pushRun(player, if room ~= nil then room.name else "Heartwood")
	return { ok = true, run = publicRun(player) }
end

function DungeonService.advance(player: Player)
	local run = runs[player]
	if run == nil or run.resolving then
		return reject("You are not in a dungeon.")
	end
	if not run.cleared then
		return reject("Clear this room first.")
	end
	run.advanceAt = nil
	if run.dungeon.endless == true then
		run.wave += 1
		teleport(player, roomSpawn(run.placeIndex))
		spawnWave(player, run)
		return { ok = true, run = publicRun(player) }
	end
	if run.roomIndex >= #run.dungeon.rooms then
		return reject("That was the last room.")
	end
	run.roomIndex += 1
	run.placeIndex = run.roomIndex
	teleport(player, roomSpawn(run.placeIndex))
	spawnRoom(player, run)
	return { ok = true, run = publicRun(player) }
end

function DungeonService.leave(player: Player)
	restartAt[player] = nil
	local run = runs[player]
	if run == nil then
		teleport(player, hubCFrame())
		return { ok = true, run = publicRun(player) }
	end
	if run.resolving then
		return { ok = true, run = publicRun(player) }
	end
	CombatService.revive(player)
	teleport(player, hubCFrame())
	destroyRun(player, run)
	pushRun(player, "Left the Rootvault.")
	return { ok = true, run = publicRun(player) }
end

function DungeonService.startDailyBoss(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	if profile.lastDailyBossDay == Loops.dayNumber(os.time()) then
		return reject("The daily Gnarl is already down.")
	end
	if runs[player] ~= nil then
		return reject("Leave the crawl first.")
	end
	local entered = DungeonService.enter(player, Dungeons.ROOTVAULT_ID, "normal")
	if entered.ok ~= true then
		return entered
	end
	local run = runs[player]
	if run == nil then
		return reject("The daily Gnarl did not open.")
	end
	run.roomIndex = #run.dungeon.rooms
	run.placeIndex = run.roomIndex
	run.advanceAt = nil
	teleport(player, roomSpawn(run.placeIndex))
	spawnRoom(player, run)
	pushRun(player, "Daily Gnarl.")
	return { ok = true, run = publicRun(player) }
end

function DungeonService.setBossPhase(player: Player, phase: any)
	if
		runs[player] == nil
		or runs[player].dungeon.id ~= Dungeons.ROOTVAULT_ID
			and runs[player].dungeon.id ~= Dungeons.HEARTWOOD_ID
	then
		local skipped = DungeonService.skipToBoss(player)
		if skipped.ok ~= true then
			return skipped
		end
	end
	local run = runs[player]
	if run == nil then
		return reject("No boss is up.")
	end
	local hasBoss = false
	for _, enemy in pairs(run.enemies) do
		if enemy.boss then
			hasBoss = true
		end
	end
	if not hasBoss then
		local skipped = DungeonService.skipToBoss(player)
		if skipped.ok ~= true then
			return skipped
		end
		run = runs[player]
	end
	if run == nil then
		return reject("No boss is up.")
	end
	local step = if type(phase) == "number" then math.floor(phase) else 2
	for _, enemy in pairs(run.enemies) do
		if enemy.boss then
			local ratio = if step >= 3
				then Rootvault.PHASE3
				elseif step == 2 then Rootvault.PHASE2
				else 1
			enemy.hp = math.max(1, math.floor(enemy.maxHp * ratio))
			enemy.phase = math.clamp(step, 1, 3)
		end
	end
	pushRun(player, "Boss phase " .. tostring(step) .. ".")
	return { ok = true, run = publicRun(player) }
end

function DungeonService.skipToBoss(player: Player)
	if not RunService:IsStudio() then
		return reject("Dev tools only work in Studio.")
	end
	if runs[player] == nil then
		local entered = DungeonService.enter(player, Dungeons.ROOTVAULT_ID)
		if entered.ok ~= true then
			return entered
		end
	end
	local run = runs[player]
	if run == nil or run.resolving then
		return reject("You are not in a dungeon.")
	end
	run.roomIndex = #run.dungeon.rooms
	run.placeIndex = run.roomIndex
	run.advanceAt = nil
	run.wave = 0
	teleport(player, roomSpawn(run.placeIndex))
	spawnRoom(player, run)
	return { ok = true, run = publicRun(player) }
end

function DungeonService.chooseDoor(player: Player, doorId: any)
	local run = runs[player]
	if run == nil or run.offer == nil then
		return reject("No doors are open.")
	end
	local picked = nil
	for _, door in ipairs(run.offer) do
		if door.id == doorId then
			picked = door
		end
	end
	if picked == nil then
		return reject("That door is not open.")
	end
	run.offer = nil
	if picked.id == "treasure" then
		DataService.mutate(player, function(data)
			ChestConfig.grantSource(data, "room", os.time())
			data.gold += 25
			return nil
		end)
	elseif picked.id == "elite" then
		run.eliteNext = true
	elseif picked.id == "spring" then
		local _hp, maxHp = CombatService.vitals(player)
		CombatService.healAmount(player, math.max(1, math.floor(maxHp * 0.3)))
	elseif picked.id == "shrine" then
		run.shrine = Rootvault.shrine(math.random(1, 3))
	elseif picked.id == "shop" then
		DataService.mutate(player, function(data)
			if (data.shardKeys or 0) < 40 then
				return nil
			end
			data.shardKeys -= 40
			data.chests.Uncommon = (data.chests.Uncommon or 0) + 1
			return nil
		end)
	end
	pushRun(player, picked.note)
	OnboardingService.note(player, "door")
	return DungeonService.advance(player)
end

function DungeonService.action(player: Player, action: string, dungeonId: any, extra: any)
	if action == "enter" then
		return DungeonService.enter(player, dungeonId, extra)
	end
	if action == "door" then
		return DungeonService.chooseDoor(player, dungeonId)
	end
	if action == "advance" then
		return DungeonService.advance(player)
	end
	if action == "leave" then
		return DungeonService.leave(player)
	end
	if action == "skip" then
		return DungeonService.skipToBoss(player)
	end
	return reject("Unknown dungeon action.")
end

local function debounce(player: Player): boolean
	local now = os.clock()
	if (touchAt[player] or 0) > now then
		return false
	end
	touchAt[player] = now + 1
	return true
end

local function bindTouchRoot(world: Instance)
	for _, descendant in ipairs(world:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "Portal" then
			descendant.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player == nil or not debounce(player) then
					return
				end
				local run = runs[player]
				if run == nil then
					return
				end
				if descendant:GetAttribute("RoomIndex") ~= run.placeIndex then
					return
				end
				local result = DungeonService.advance(player)
				if result.ok ~= true then
					pushRun(player, result.error)
				end
			end)
		elseif descendant:IsA("BasePart") and descendant.Name == "EnterPad" then
			descendant.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player == nil or not debounce(player) then
					return
				end
				if runs[player] ~= nil then
					return
				end
				local result = DungeonService.enter(player, descendant:GetAttribute("EnterDungeon"))
				if result.ok ~= true then
					pushRun(player, result.error)
				end
			end)
		end
	end
end

local function bindTouches()
	local roots = {}
	if worldFolder ~= nil then
		table.insert(roots, worldFolder)
	end
	local haven = workspace:FindFirstChild("Haven")
	if haven ~= nil then
		table.insert(roots, haven)
	end
	for _, world in ipairs(roots) do
		bindTouchRoot(world)
	end
end

function DungeonService.onPlayerDown(player: Player)
	local run = runs[player]
	if
		run ~= nil
		and run.dungeon.id == Dungeons.HEARTWOOD_ID
		and run.difficulty == "story"
		and run.practice ~= true
	then
		DataService.mutate(player, function(data)
			data.raidEcho = math.min(5, (data.raidEcho or 0) + 1)
			return nil
		end)
	end
	finish(player, false)
end

function DungeonService.start()
	print("[Rootvault] build 140bf33+ spawner=ModelFactory boss=Grandmother Gnarl")
	local litOk, lightResult = pcall(function()
		return VerdantLook.apply(game:GetService("Lighting"))
	end)
	if not litOk then
		warn("[Shardfall] Verdant lighting failed: " .. tostring(lightResult))
	elseif lightResult ~= true then
		warn("[Shardfall] Verdant lighting applied with errors")
	else
		print("[Shardfall] Verdant lighting on")
	end
	buildWorld()
	local hubReady = false
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "HubSpawn" then
			hubReady = true
			break
		end
	end
	if hubReady then
		for _, player in ipairs(Players:GetPlayers()) do
			if runs[player] == nil then
				teleport(player, hubCFrame())
			end
		end
		HavenBuilder.clearDefaults()
	else
		warn("[Shardfall] HubSpawn is missing, so the default baseplate stays")
	end
	bindTouches()
	local TravelService = require(script.Parent.TravelService)
	TravelService.bind()
	HavenBuilder.bindRootvault(function(player)
		if not debounce(player) then
			return
		end
		if runs[player] ~= nil then
			return
		end
		local result = DungeonService.enter(player, Dungeons.ROOTVAULT_ID)
		if result.ok ~= true then
			pushRun(player, result.error)
		end
	end)

	local function watchIdle(player: Player)
		player.Idled:Connect(function(idleTime)
			if type(idleTime) ~= "number" or idleTime < Dungeons.IDLE_NOTE_SECONDS then
				return
			end
			if idleNoted[player] == true then
				return
			end
			idleNoted[player] = true
			warn(
				string.format(
					"[Shardfall] %s has been idle for %d seconds. Roblox kicks near 20 minutes with no input. Stop AFK rewards in this hook before that kick if you need a cutoff.",
					player.Name,
					math.floor(idleTime)
				)
			)
		end)
	end

	local function placeCharacter(player: Player)
		task.defer(function()
			if player.Parent == nil then
				return
			end
			local run = runs[player]
			if run ~= nil and not run.resolving then
				teleport(player, roomSpawn(run.placeIndex))
			else
				teleport(player, hubCFrame())
			end
		end)
	end

	local function hook(player: Player)
		watchIdle(player)
		player.CharacterAdded:Connect(function()
			placeCharacter(player)
		end)
		-- CharacterAdded does not fire for a character already standing
		-- on the default baseplate when this script starts.
		if player.Character ~= nil then
			placeCharacter(player)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run ~= nil then
			destroyRun(player, run)
		end
		touchAt[player] = nil
		fallAt[player] = nil
		farmOn[player] = nil
		restartAt[player] = nil
		idleNoted[player] = nil
	end)

	RunService.Heartbeat:Connect(onHeartbeat)
end

return DungeonService
