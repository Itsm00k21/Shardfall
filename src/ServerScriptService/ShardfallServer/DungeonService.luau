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
local TweenService = game:GetService("TweenService")

local Build = require(ReplicatedStorage.Shared.Build)
local ChestConfig = require(ReplicatedStorage.Shared.ChestConfig)
local DevAccess = require(ReplicatedStorage.Shared.DevAccess)
local DungeonConfig = require(ReplicatedStorage.Shared.DungeonConfig)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local ElementGlow = require(ReplicatedStorage.Shared.ElementGlow)
local Economy = require(ReplicatedStorage.Shared.Economy)
local cueModule = ReplicatedStorage.Shared
local CodexCues = require(cueModule.CodexCues)
local CombatFeel = require(ReplicatedStorage.Shared.CombatFeel)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local MeleeConfig = require(ReplicatedStorage.Shared.MeleeConfig)
local Dungeons = require(ReplicatedStorage.Shared.Dungeons)
local HardMode = require(ReplicatedStorage.Shared.HardMode)
local EnemyPerf = require(ReplicatedStorage.Shared.Config.EnemyPerf)
local EnemyPerfHost = require(script.Parent.EnemyPerfHost)
local Haven = require(ReplicatedStorage.Shared.Haven)
local Materials = require(ReplicatedStorage.Shared.Materials)
local ModelFactory = require(ReplicatedStorage.Shared.ModelFactory)
local VerdantLook = require(ReplicatedStorage.Shared.VerdantLook)
local VerdantScatter = require(ReplicatedStorage.Shared.VerdantScatter)
local Loops = require(ReplicatedStorage.Shared.Loops)
local PracticeLoot = require(ReplicatedStorage.Shared.PracticeLoot)
local Progression = require(ReplicatedStorage.Shared.Progression)
local RaidEchoFight = require(ReplicatedStorage.Shared.RaidEchoFight)
local Raids = require(ReplicatedStorage.Shared.Raids)
local DungeonAdvance = require(script.Parent.DungeonAdvance)
local EchoBossClear = require(script.Parent.EchoBossClear)
local EchoRetry = require(script.Parent.EchoRetry)
local WaveFlowService = require(script.Parent.WaveFlowService)
local RunTick = require(script.Parent.RunTick)
local LoopService = require(script.Parent.LoopService)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Rootvault = require(ReplicatedStorage.Shared.Rootvault)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local SavedWorld = require(ReplicatedStorage.Shared.SavedWorld)
local StarterGoalPay = require(ReplicatedStorage.Shared.StarterGoalPay)
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
	dashUntil: number?,
	telegraphUntil: number,
	telegraphColor: string,
	markX: number,
	markZ: number,
	hover: number,
	color: Color3,
	part: BasePart,
	-- Set only while LaunchGate.enemyPerf is on.
	perfClock: EnemyPerf.Clock?,
	perfStuck: boolean?,
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
	-- Sap Mouth puddles: { x, z, untilAt, nextTick }. Cleared with the enemies.
	puddles: { { x: number, z: number, untilAt: number, nextTick: number } }?,
	shrine: string,
	startedAt: number,
	-- Server-minted. Marks for a boss in this run use this id once.
	runId: string,
	practice: boolean,
	raidPlayers: number,
	healerPresent: boolean,
	-- Party Echo. The state table is shared with a backfill. Nil outside Heartwood.
	echoFight: RaidEchoFight.Fight?,
	echo: { stacks: number }?,
	-- True from a Story wipe retry until every party member has streamed
	-- back in. A hit in that window must not wipe or start another retry.
	retrying: boolean?,
	-- tuneRaid moved this member off a wing. No kill mark was written.
	-- They do not hold the shared reset for the room they left.
	echoJumped: boolean?,
	-- M10 pool. Nil while enemyPerf is off, so a live run never allocates it.
	perf: EnemyPerf.Pool?,
	perfOrders: { { kind: string, offset: Vector3, wave: number? } }?,
}

type Restart = {
	at: number,
	dungeonId: string,
}

local runs: { [Player]: Run } = {}
local lastCue: { [Player]: string } = {}
-- Set while a reserved arrival still owns the fresh fight it is about to leave.
-- echoHost skips that player so the next arrival cannot join the temporary fight.
local echoJoinHold: { [Player]: boolean } = {}
local releasingFight: { [RaidEchoFight.Fight]: boolean } = {}
-- userId -> room indexes whose boss copy that player has already dropped.
-- A later room does not count as an earlier clear unless this mark is set.
local echoBossDown: { [RaidEchoFight.Fight]: { [string]: { [number]: boolean } } } = {}
-- Room waiting on the rest of the party. Nil once everyone still in has cleared.
local echoBossOwed: { [RaidEchoFight.Fight]: number } = {}
-- userId already fully revived during this pull. A later copy death does not heal them again.
local echoRevived: { [RaidEchoFight.Fight]: { [string]: boolean } } = {}
local touchAt: { [Player]: number } = {}
local fallAt: { [Player]: number } = {}
local farmOn: { [Player]: boolean } = {}
local farmSince: { [Player]: number } = {}
local restartAt: { [Player]: Restart } = {}
local idleNoted: { [Player]: boolean } = {}
local tickFault: { [Player]: boolean } = {}
local nextEnemyId = 0

local function bindEcho(fight: RaidEchoFight.Fight)
	for member, partyRun in pairs(runs) do
		if partyRun.echoFight == fight then
			partyRun.echo = fight.state
			-- Refresh publishes the echoed max. The bar reads that number.
			CombatService.refresh(member)
		end
	end
end

local function rememberMax(player: Player, run: Run)
	if run.echoFight == nil then
		return
	end
	-- refresh asks the echo hook for max HP from the unbuffed loadout.
	CombatService.refresh(player)
end

local function echoScale(player: Player, amount: number, kind: "healing" | "maxHp"): number
	local run = runs[player]
	local fight = if run ~= nil then run.echoFight else nil
	if fight == nil then
		return amount
	end
	return RaidEchoFight.applyBase(fight, tostring(player.UserId), kind, amount)
end
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

-- The server names the Codex moment. CombatFx already carries fight
-- snapshots, so the cue rides that remote. The client does not send seen.
local function publishCues(player: Player)
	if player.Parent == nil then
		return
	end
	local run = runs[player]
	local enemies = {}
	if run ~= nil then
		for _, enemy in pairs(run.enemies) do
			local x, y, z = 0, 0, 0
			local part = enemy.part
			if part ~= nil and part.Parent ~= nil then
				local position = part.Position
				x = position.X
				y = position.Y
				z = position.Z
			end
			table.insert(enemies, {
				alive = enemy.hp > 0,
				boss = enemy.boss == true,
				color = enemy.telegraphColor,
				untilAt = enemy.telegraphUntil,
				x = x,
				y = y,
				z = z,
			})
		end
	end
	local named = CodexCues.facts({
		profile = DataService.get(player),
		inHaven = run == nil,
		now = os.clock(),
		enemies = enemies,
	})
	local painted = if named.ok == true then CodexCues.paint(named.facts) else nil
	local event
	local signature
	if painted ~= nil and painted.ok == true then
		event = painted.event
		signature = painted.signature
	else
		local blank = CodexCues.cleared()
		event = blank.event
		signature = blank.signature
	end
	if lastCue[player] == signature then
		return
	end
	lastCue[player] = signature
	fx(player, event)
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
		echoStacks = if run.echoFight ~= nil then run.echoFight.state.stacks else 0,
		echoLabel = if run.echoFight ~= nil
			then RaidEchoFight.chip(run.echoFight.state, run.echoFight.difficulty)
			else nil,
	}
end

local function pushRun(player: Player, text: string?)
	fx(player, {
		kind = "run",
		run = publicRun(player),
		text = text,
	})
end

-- Element color from Config, parented only when forEnemy returns a spec.
-- The warm Rim stays the default. Two Highlights on one adornee fight,
-- so the Rim is disabled while the element glow is the one that draws.
local function applyElementGlow(part: BasePart, host: Instance, glow: ElementGlow.Visual)
	local color = Color3.fromRGB(glow.color[1], glow.color[2], glow.color[3])
	local mark = Instance.new("Highlight")
	mark.Name = glow.name
	mark.Adornee = host
	mark.FillColor = color
	mark.OutlineColor = color
	mark.FillTransparency = glow.fillTransparency
	mark.OutlineTransparency = glow.outlineTransparency
	if glow.depthMode == "Occluded" then
		mark.DepthMode = Enum.HighlightDepthMode.Occluded
	else
		mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end
	mark.Parent = host
	local rim = host:FindFirstChild("Rim")
	if rim ~= nil and rim:IsA("Highlight") then
		rim.Enabled = false
	end
	local light = Instance.new("PointLight")
	light.Name = glow.lightName
	light.Color = color
	light.Brightness = glow.lightBrightness
	light.Range = glow.lightRange
	light.Shadows = false
	light.Parent = part
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
		TweenService:Create(
			fill,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(ratio, 1) }
		):Play()
	end
end

local function dropPickup(
	parent: Instance,
	position: Vector3,
	landed: { [string]: number },
	player: Player
)
	local index = 0
	for _, materialId in ipairs(Materials.ORDER) do
		local count = landed[materialId]
		if type(count) ~= "number" or count <= 0 then
			continue
		end
		index += 1
		local rarity = Materials.rarityName(materialId)
		local red, green, blue = Rarities.rgb(rarity)
		local color = Color3.fromRGB(red, green, blue)
		local name = Materials.displayName(materialId)
		local vx, vy, vz = CombatFeel.lootVelocity(index)
		local orb = Instance.new("Part")
		orb.Name = name
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(0.7, 0.7, 0.7)
		orb.Material = Enum.Material.Neon
		orb.Color = color
		orb.Anchored = false
		orb.CanCollide = true
		orb.CanQuery = false
		orb.CanTouch = false
		orb.Position = position + Vector3.new(0, 2.2, 0)
		orb.Parent = parent
		orb.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
		local beam = Instance.new("Part")
		beam.Name = "RarityBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.Material = Enum.Material.Neon
		beam.Color = color
		beam.Size = Vector3.new(0.12, 5, 0.12)
		beam.CFrame = CFrame.new(orb.Position + Vector3.new(0, 2.5, 0))
		beam.Parent = parent
		local born = os.clock()
		local pulled = false
		local follow: RBXScriptConnection? = nil
		follow = RunService.Heartbeat:Connect(function()
			if orb.Parent == nil then
				if beam.Parent ~= nil then
					beam:Destroy()
				end
				if follow ~= nil then
					follow:Disconnect()
				end
				return
			end
			beam.CFrame = CFrame.new(orb.Position + Vector3.new(0, 2.4, 0))
			local age = os.clock() - born
			local character = player.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			if age >= 0.35 and root ~= nil and root:IsA("BasePart") then
				local delta = root.Position - orb.Position
				if delta.Magnitude <= CombatFeel.MAGNET_RANGE then
					pulled = true
					local unit = if delta.Magnitude > 0.05 then delta.Unit else Vector3.yAxis
					orb.AssemblyLinearVelocity = unit * 36
				end
				if delta.Magnitude < 3.5 then
					orb:Destroy()
					beam:Destroy()
					if follow ~= nil then
						follow:Disconnect()
					end
					return
				end
			end
			if age > 6 then
				orb:Destroy()
				beam:Destroy()
				if follow ~= nil then
					follow:Disconnect()
				end
			end
			if pulled and age > 2.5 and orb.Parent ~= nil then
				orb.CanCollide = false
			end
		end)
	end
end

local function enemyBar(part: BasePart, name: string, color: Color3, lift: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShardfallBar"
	gui.Size = UDim2.fromOffset(96, 28)
	gui.StudsOffset = Vector3.new(0, lift, 0)
	gui.AlwaysOnTop = false
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
	run.puddles = nil
	local perfOn = LaunchGate.on("enemyPerf")
	local pool = run.perf
	for _, enemy in pairs(run.enemies) do
		local model = enemy.part.Parent
		local parked = false
		if perfOn and pool ~= nil and model ~= nil and model:IsA("Model") then
			local keep = EnemyPerf.stash(pool, enemy.kind)
			if keep then
				parked = EnemyPerfHost.park(enemy.kind, model)
				if not parked then
					EnemyPerf.unstash(pool, enemy.kind)
				end
			end
		end
		if not parked then
			if model ~= nil and model:IsA("Model") then
				model:Destroy()
			else
				enemy.part:Destroy()
			end
		end
	end
	run.enemies = {}
	if pool ~= nil then
		EnemyPerf.wipe(pool)
	end
	if run.perfOrders ~= nil then
		table.clear(run.perfOrders)
	end
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

-- Solid parts (walls, slopes, props) inside the rig's box, ignoring the
-- floor slab under it, players, and other enemies' rigs.
local function spawnBlocked(rig: Instance, run: Run): boolean
	local boxCFrame: CFrame, boxSize: Vector3
	if rig:IsA("Model") then
		boxCFrame, boxSize = rig:GetBoundingBox()
	elseif rig:IsA("BasePart") then
		boxCFrame, boxSize = rig.CFrame, rig.Size
	else
		return false
	end
	local lift = math.min(1, boxSize.Y * 0.2)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { rig }
	for _, other in pairs(run.enemies) do
		local host = other.part.Parent
		table.insert(ignore, if host ~= nil and host:IsA("Model") then host else other.part)
	end
	for _, member in ipairs(Players:GetPlayers()) do
		if member.Character ~= nil then
			table.insert(ignore, member.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hits = workspace:GetPartBoundsInBox(
		boxCFrame + Vector3.new(0, lift / 2, 0),
		Vector3.new(boxSize.X, math.max(0.5, boxSize.Y - lift), boxSize.Z),
		params
	)
	for _, hit in ipairs(hits) do
		if hit.CanCollide then
			return true
		end
	end
	return false
end

-- Steps a freshly built rig toward the room centre until it is clear.
local function clearSpawn(rig: Instance, run: Run, localX: number, localZ: number)
	local x, z = localX, localZ
	for _ = 1, DungeonConfig.SPAWN_TRIES do
		if not spawnBlocked(rig, run) then
			return
		end
		local nx, nz = DungeonConfig.stepInward(x, z)
		if nx == x and nz == z then
			return
		end
		local shift = Vector3.new(nx - x, 0, nz - z)
		x, z = nx, nz
		if rig:IsA("Model") then
			rig:PivotTo(rig:GetPivot() + shift)
		elseif rig:IsA("BasePart") then
			rig.CFrame += shift
		end
	end
	warn(string.format("[Rootvault] spawn still blocked at %.0f, %.0f", x, z))
end

-- Same living-enemy rule as aliveCount. Spawn runs before that helper.
local function countLiving(run: Run): number
	local count = 0
	for _, enemy in pairs(run.enemies) do
		if enemy.hp > 0 then
			count += 1
		end
	end
	return count
end

local function ensurePerf(run: Run): EnemyPerf.Pool
	local pool = run.perf
	if pool == nil then
		pool = EnemyPerf.newPool()
		pool.alive = countLiving(run)
		run.perf = pool
		run.perfOrders = {}
	end
	return pool
end

local function spawnEnemy(
	run: Run,
	kind: string,
	offset: Vector3,
	wave: number?,
	spawnIndex: number?,
	heldAction: ("fresh" | "reuse")?
): Enemy?
	local definition = Dungeons.enemy(kind)
	if definition == nil then
		return nil
	end
	if definition.boss == true then
		offset = Vector3.new(DungeonConfig.BOSS_SPAWN.x, offset.Y, DungeonConfig.BOSS_SPAWN.z)
	end
	do
		local cx, cz = DungeonConfig.insideFloor(
			offset.X,
			offset.Z,
			definition.size[1] / 2,
			definition.size[3] / 2,
			Dungeons.FLOOR_SIZE / 2
		)
		offset = Vector3.new(cx, offset.Y, cz)
	end
	local claimed: ("fresh" | "reuse")? = nil
	if LaunchGate.on("enemyPerf") then
		if heldAction == "fresh" or heldAction == "reuse" then
			claimed = heldAction
		else
			local action = EnemyPerf.claim(ensurePerf(run), kind)
			if action == "queued" then
				local orders = run.perfOrders
				if orders == nil then
					orders = {}
					run.perfOrders = orders
				end
				table.insert(orders, {
					kind = kind,
					offset = offset,
					wave = wave,
				})
				return nil
			end
			claimed = if action == "reuse" then "reuse" else "fresh"
		end
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
	local part: BasePart
	local reusedPart = if claimed == "reuse" then EnemyPerfHost.take(kind) else nil
	if reusedPart ~= nil then
		part = reusedPart
		local reusedModel = part.Parent
		if reusedModel ~= nil then
			reusedModel.Parent = run.folder
		end
		part.CFrame = rootCFrame
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true
		part.Transparency = 1
		part.Name = display
	else
		local rigOk, rigOrErr = pcall(function()
			return ModelFactory.buildEnemy(run.folder, kind, rootCFrame, size, display)
		end)
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
	end
	local host = part.Parent
	local rigModel = if host ~= nil and host:IsA("Model") then host else nil
	clearSpawn(if rigModel ~= nil then rigModel else part, run, offset.X, offset.Z)
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
	if LaunchGate.on("enemyPerf") and rigModel ~= nil then
		EnemyPerfHost.prepare(rigModel)
	end
	part:SetAttribute(
		"ShardfallName",
		if elite then "Elite " .. definition.name else definition.name
	)
	part:SetAttribute("EnemyId", id)
	part:SetAttribute("ShardfallKind", kind)
	local rimHost = ModelFactory.adorn(part)
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
	local ordinal = if type(spawnIndex) == "number" then spawnIndex else 1
	local glow = ElementGlow.forEnemy(ordinal, LaunchGate.on("elementGlow"))
	if glow ~= nil then
		applyElementGlow(part, rimHost, glow)
		part:SetAttribute("ShardfallElement", glow.elementId)
	end
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
		markX = 0,
		markZ = 0,
		hover = definition.hover,
		color = color,
		part = part,
	}
	paintEnemy(enemy)
	run.enemies[id] = enemy
	if LaunchGate.on("enemyPerf") then
		enemy.perfClock = EnemyPerf.begin(part.Position.X, part.Position.Z, os.clock())
	end
	if enemy.boss and run.echoFight ~= nil then
		local room = run.dungeon.rooms[run.roomIndex]
		local bossId = if room ~= nil then room.id else enemy.kind
		RaidEchoFight.notePull(run.echoFight, bossId)
	end
	if enemy.boss and run.sunbeam == nil then
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

-- Park the rig and, if a spawn was waiting on the cap, bring that one in.
-- The caller already decided this enemy is leaving the field. No loot.
local function perfRetire(run: Run, enemy: Enemy)
	-- A pool created on this call has not counted a corpse (hp already 0).
	local created = run.perf == nil
	local pool = ensurePerf(run)
	if created and enemy.hp <= 0 then
		pool.alive += 1
	end
	local outcome = EnemyPerf.retire(pool, enemy.kind)
	local model = enemy.part.Parent
	local parked = false
	if outcome.keep and model ~= nil and model:IsA("Model") then
		parked = EnemyPerfHost.park(enemy.kind, model)
		if not parked then
			EnemyPerf.unstash(pool, enemy.kind)
		end
	end
	if not parked then
		if model ~= nil and model:IsA("Model") then
			model:Destroy()
		else
			enemy.part:Destroy()
		end
	end
	run.enemies[enemy.id] = nil
	if outcome.nextKind == nil or outcome.nextAction == nil then
		return
	end
	local orders = run.perfOrders
	local order = if orders ~= nil then table.remove(orders, 1) else nil
	if order == nil then
		return
	end
	spawnEnemy(run, order.kind, order.offset, order.wave, nil, outcome.nextAction)
end

-- Biggest-wave stall. Despawn, then respawn on a clear pad. Not a kill.
local function unstickEnemy(run: Run, enemy: Enemy)
	local kind = enemy.kind
	local wave = if run.dungeon.endless == true then run.wave else nil
	local stuckX = enemy.part.Position.X
	local stuckZ = enemy.part.Position.Z
	perfRetire(run, enemy)
	local originX, _, originZ = Dungeons.roomOrigin(run.placeIndex)
	local padX, padZ = EnemyPerf.respawnPad(stuckX - originX, stuckZ - originZ, Dungeons.ENEMY_SPAWNS)
	spawnEnemy(run, kind, Vector3.new(padX, 0, padZ), wave)
end

local function spawnRoom(player: Player, run: Run)
	CombatService.clearShots(player)
	clearEnemies(run)
	run.cleared = false
	local room = run.dungeon.rooms[run.roomIndex]
	if room == nil then
		return
	end
	local bossRoom = run.roomIndex == #run.dungeon.rooms
	-- Elite Fight door: spawn the stray first so it takes the elite buff.
	-- Slot 6 is a side spawn; rooms use 1-3 and slot 8 sits on the portal.
	local strayed = false
	if run.eliteNext and not bossRoom and run.dungeon.id == Dungeons.ROOTVAULT_ID then
		spawnEnemy(run, Dungeons.stray(run.roomIndex), SPAWNS[6])
		strayed = true
	end
	for index, kind in ipairs(room.enemies) do
		local offset = SPAWNS[((index - 1) % #SPAWNS) + 1]
		spawnEnemy(run, kind, offset, nil, index)
	end
	local text = string.format("%s  ·  %s", run.dungeon.name, room.name)
	if bossRoom then
		text ..= ". Slam, then hit the gold weak spot. At half HP, stand in the sunbeam."
	end
	if strayed then
		text ..= ". " .. Dungeons.STRAY_NOTE
	end
	pushRun(player, text)
	publishCues(player)
end

local function spawnWave(player: Player, run: Run)
	CombatService.clearShots(player)
	clearEnemies(run)
	run.cleared = false
	run.advanceAt = nil
	local kinds = Dungeons.waveKinds(run.wave)
	for index, kind in ipairs(kinds) do
		local offset = SPAWNS[((index - 1) % #SPAWNS) + 1]
		spawnEnemy(run, kind, offset, run.wave, index)
	end
	local text = string.format("%s  ·  Wave %d", run.dungeon.name, run.wave)
	if Dungeons.isBossWave(run.wave) then
		text ..= ". Boss wave. Slam, then the sunbeam at half HP."
	end
	text ..= Dungeons.waveNote(run.wave)
	pushRun(player, text)
	publishCues(player)
end

local function storyEcho(run: Run, fight: RaidEchoFight.Fight): boolean
	return run.dungeon.id == Dungeons.HEARTWOOD_ID
		and run.difficulty == "story"
		and run.practice ~= true
		and fight.practice ~= true
end

-- Down before bindEcho. A stack reset can drop a hurt player to 0 HP.
-- That player was not held, and this list must not turn the refresh into a full heal.
local function heldNow(fight: RaidEchoFight.Fight): { Player }
	local pending = {}
	for member, memberRun in pairs(runs) do
		if memberRun.echoFight ~= fight or not storyEcho(memberRun, fight) then
			continue
		end
		if memberRun.resolving == true or memberRun.retrying == true then
			continue
		end
		local hp = CombatService.vitals(member)
		local userId = tostring(member.UserId)
		local row = fight.members[userId]
		if hp <= 0 or (row ~= nil and row.alive ~= true) then
			table.insert(pending, member)
		end
	end
	return pending
end

-- One full revive per pull. A later copy death in that pull does not heal again.
-- Bringing a held member back does not call wipe, so it cannot add a stack.
local function reviveHeld(fight: RaidEchoFight.Fight, pending: { Player })
	local seen = echoRevived[fight]
	for _, member in ipairs(pending) do
		local userId = tostring(member.UserId)
		if seen ~= nil and seen[userId] == true then
			continue
		end
		local memberRun = runs[member]
		if
			memberRun == nil
			or memberRun.echoFight ~= fight
			or not storyEcho(memberRun, fight)
			or memberRun.resolving == true
			or memberRun.retrying == true
		then
			continue
		end
		CombatService.revive(member)
		if runs[member] == memberRun and memberRun.echoFight == fight then
			RaidEchoFight.setAlive(fight, userId, true)
			local marked = echoRevived[fight]
			if marked == nil then
				marked = {}
				echoRevived[fight] = marked
			end
			marked[userId] = true
			seen = marked
		end
	end
end

-- This player's boss copy is down. The mark outlives the room, so a
-- member who already advanced still counts when the next copy dies.
local function noteEchoBoss(fight: RaidEchoFight.Fight, userId: string, roomIndex: number)
	local byUser = echoBossDown[fight]
	if byUser == nil then
		byUser = {}
		echoBossDown[fight] = byUser
	end
	local rooms = byUser[userId]
	if rooms == nil then
		rooms = {}
		byUser[userId] = rooms
	end
	rooms[roomIndex] = true
end

-- A dead boss with no living adds, or a room already marked clear.
-- A living add keeps the Story Echo seat open, so the shared reset
-- waits for the pull. An empty room that has not cleared is still
-- spawning, and that is not a kill.
local function roomBossDown(run: Run): boolean
	local saw = false
	for _, foe in pairs(run.enemies) do
		if foe.hp > 0 then
			return false
		end
		if foe.boss then
			saw = true
		end
	end
	if saw then
		return true
	end
	return run.cleared == true
end

-- Still able to swing. Downed, roster-dead, and resolving members are
-- out. They cannot clear a boss, and waiting on them would never reset.
local function echoUp(fight: RaidEchoFight.Fight, member: Player, memberRun: Run): boolean
	if memberRun.resolving == true then
		return false
	end
	if CombatService.vitals(member) <= 0 then
		return false
	end
	local row = fight.members[tostring(member.UserId)]
	if row ~= nil and row.alive == false then
		return false
	end
	return true
end

-- True after this pull's one full revive. A later down stays at 0.
local function reviveSpent(fight: RaidEchoFight.Fight, userId: string): boolean
	local seen = echoRevived[fight]
	return seen ~= nil and seen[userId] == true
end

local function echoBossReady(fight: RaidEchoFight.Fight, killedRoom: number): boolean
	local marked = echoBossDown[fight]
	local seats: { EchoBossClear.Seat } = {}
	for member, memberRun in pairs(runs) do
		if memberRun.echoFight ~= fight or memberRun.resolving == true then
			continue
		end
		-- A downed player on another wing does not block this boss. A downed
		-- player whose copy is still up does, until they clear, so the one
		-- revive can stand them up. After that revive is spent they stay at
		-- 0 and cannot swing, so the copy must not hold the shared reset.
		local up = echoUp(fight, member, memberRun)
		local copyUp = memberRun.roomIndex == killedRoom and not roomBossDown(memberRun)
		if not up and not copyUp then
			continue
		end
		local userId = tostring(member.UserId)
		if
			not up
			and copyUp
			and CombatService.vitals(member) <= 0
			and reviveSpent(fight, userId)
		then
			continue
		end
		local rooms = if marked ~= nil then marked[userId] else nil
		local didMark = rooms ~= nil and rooms[killedRoom] == true
		-- tuneRaid moved this living member off the room and wrote no mark.
		-- They must not hold the reset for the wing they left.
		if
			EchoBossClear.leftWing(
				killedRoom,
				memberRun.roomIndex,
				didMark,
				memberRun.echoJumped == true
			)
		then
			continue
		end
		table.insert(seats, {
			cleared = EchoBossClear.seatCleared(
				killedRoom,
				memberRun.roomIndex,
				roomBossDown(memberRun),
				didMark,
				memberRun.retrying == true
			),
			retrying = memberRun.retrying == true,
		})
	end
	return EchoBossClear.ready(seats)
end

local function echoStanding(fight: RaidEchoFight.Fight): { Player }
	local standing = {}
	for member, memberRun in pairs(runs) do
		if memberRun.echoFight == fight and echoUp(fight, member, memberRun) then
			table.insert(standing, member)
		end
	end
	return standing
end

-- Only the players who were above 0 before the refresh. A held member
-- stays at 0 until reviveHeld. Landing on 0 here is the max shrink.
local function spareEchoFloor(fight: RaidEchoFight.Fight, standing: { Player })
	for _, member in ipairs(standing) do
		local memberRun = runs[member]
		if
			memberRun ~= nil
			and memberRun.echoFight == fight
			and memberRun.resolving ~= true
			and CombatService.vitals(member) <= 0
		then
			CombatService.spare(member)
		end
	end
end

-- One reset for the whole pull. Held members come back. Standing
-- members the refresh zeroed stay at 1 HP instead of taking the down
-- path: bossKill has already cleared pullStarted, so onPlayerDown
-- would fail the run they just cleared.
local function settleSharedBoss(fight: RaidEchoFight.Fight, actor: Player?)
	echoBossOwed[fight] = nil
	local downed = heldNow(fight)
	local standing = echoStanding(fight)
	RaidEchoFight.bossKill(fight)
	if actor ~= nil then
		local actorRun = runs[actor]
		if actorRun ~= nil and actorRun.echoFight == fight then
			rememberMax(actor, actorRun)
		end
	end
	bindEcho(fight)
	spareEchoFloor(fight, standing)
	reviveHeld(fight, downed)
	-- That revive spent the cap. The next pull starts clean.
	echoRevived[fight] = nil
end

local destroyRun: (Player, Run) -> ()

-- The living players are gone and this was not a wipe retry. Send held
-- members to the hub. depart does not add a stack. Do not grant the clear.
local function sendHeldHome(fight: RaidEchoFight.Fight)
	if releasingFight[fight] == true then
		return
	end
	local pending = {}
	for member, memberRun in pairs(runs) do
		if
			memberRun.echoFight == fight
			and storyEcho(memberRun, fight)
			and memberRun.resolving ~= true
			and memberRun.retrying ~= true
			and CombatService.vitals(member) <= 0
		then
			table.insert(pending, member)
		end
	end
	if #pending == 0 then
		return
	end
	releasingFight[fight] = true
	for _, member in ipairs(pending) do
		local memberRun = runs[member]
		if
			memberRun ~= nil
			and memberRun.echoFight == fight
			and memberRun.resolving ~= true
			and CombatService.vitals(member) <= 0
		then
			memberRun.resolving = true
			restartAt[member] = nil
			pcall(CombatService.revive, member)
			pcall(teleport, member, hubCFrame())
			local dropped, dropErr = pcall(destroyRun, member, memberRun)
			if not dropped then
				runs[member] = nil
				echoJoinHold[member] = nil
				pcall(CombatService.clearShots, member)
				warn(
					"[Shardfall] "
						.. member.Name
						.. " could not leave the ended pull: "
						.. tostring(dropErr)
				)
			end
			pushRun(member, "The pull ended.")
		end
	end
	releasingFight[fight] = nil
end

destroyRun = function(player: Player, run: Run)
	clearEnemies(run)
	run.folder:Destroy()
	local fight = run.echoFight
	run.echoFight = nil
	run.echo = nil
	runs[player] = nil
	echoJoinHold[player] = nil
	pcall(publishCues, player)
	if fight ~= nil then
		local userId = tostring(player.UserId)
		RaidEchoFight.depart(fight, userId)
		local marked = echoBossDown[fight]
		if marked ~= nil then
			marked[userId] = nil
		end
		-- The last member who had not cleared just left. Everyone still
		-- here has already dropped that boss, so the buff ends now.
		local owed = echoBossOwed[fight]
		if owed ~= nil and releasingFight[fight] ~= true then
			local shared = false
			for _, other in pairs(runs) do
				if other.echoFight == fight and other.resolving ~= true then
					shared = true
					break
				end
			end
			if shared and echoBossReady(fight, owed) then
				settleSharedBoss(fight, nil)
			end
		end
		if releasingFight[fight] ~= true then
			local living = false
			local retrying = false
			for member, other in pairs(runs) do
				if other.echoFight == fight and other.resolving ~= true then
					if other.retrying == true then
						retrying = true
					elseif CombatService.vitals(member) > 0 then
						living = true
					end
				end
			end
			-- A wipe retry still owns the party. Anyone left standing keeps
			-- the pull. Held members go home only when the fight is over.
			if not living and not retrying then
				sendHeldHome(fight)
			end
		end
		local sharing = false
		for _, other in pairs(runs) do
			if other.echoFight == fight then
				sharing = true
				break
			end
		end
		if not sharing then
			RaidEchoFight.runEnd(fight)
			echoBossDown[fight] = nil
			echoBossOwed[fight] = nil
			echoRevived[fight] = nil
		end
	end
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
	if not PracticeLoot.pays(run.practice == true) then
		fx(player, { kind = "hint", text = "Practice Grove. No loot." })
		return true
	end
	local profile = DataService.get(player)
	local _, _, goldFind = CombatMath.loadout(profile)
	local bonus = CombatMath.bonusGold(rolled.gold, goldFind)
	local levels = 0
	local xpShown = rolled.xp
	-- Heartwood pays its own raid row. Rootvault and Waves use Config.
	local tokenGrant = rolled.shardTokens
	if run.dungeon.id ~= Dungeons.HEARTWOOD_ID then
		tokenGrant = HardMode.tokens(run.difficulty, rolled.shardTokens)
	end
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
		data.shardTokens += tokenGrant
		local xpGain = rolled.xp
		if run.dungeon.endless ~= true and run.dungeon.id == Dungeons.ROOTVAULT_ID then
			local today = Loops.dayNumber(os.time())
			local mult, day, rare = Loops.firstClear(data.firstClearDay or -1, today)
			data.firstClearDay = day
			xpGain = rolled.xp * mult
			if rare and ChestConfig.dropsOn() and type(data.chests) == "table" then
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
			run.dungeon.id == Dungeons.ROOTVAULT_ID
			and run.dungeon.endless ~= true
			and run.practice ~= true
			and run.difficulty == "normal"
		then
			StarterGoalPay.grant(data, "rootvault", { rootvault = true })
		end
		StarterGoalPay.grant(data, "level", nil)
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
		if tokenGrant > 0 then
			table.insert(bits, string.format("+%d tokens", tokenGrant))
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
			shardTokens = tokenGrant,
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
		for _, enemy in pairs(run.enemies) do
			local bar = enemy.part:FindFirstChild("ShardfallBar")
			if bar ~= nil then
				bar:Destroy()
			end
		end
		local text = Dungeons.defeatLine(run.dungeon)
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
	if PracticeLoot.pays(run.practice == true) then
		LoopService.progress(player, "rooms", 1)
	end
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

-- Living enemies in this room. A party wipe counts players, not this.
local function aliveCount(run: Run): number
	return countLiving(run)
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
	-- A held party member stays at 0 until a boss kill, the run ending, or
	-- the wipe retry. Their swings must not clear the room or add a stack.
	local hp = CombatService.vitals(player)
	if hp <= 0 then
		return false
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
	if run.echoFight ~= nil then
		-- The incoming amount is the unbuffed hit. applyBase stores that
		-- base, so a later wipe does not multiply the already scaled number.
		amount = RaidEchoFight.applyBase(run.echoFight, tostring(player.UserId), "damage", amount)
	end
	enemy.hp -= amount
	if enemy.hp < 0 then
		enemy.hp = 0
	end
	paintEnemy(enemy)
	if enemy.hp > 0 then
		enemy.part:SetAttribute("ShardfallFlinchUntil", now + CombatFeel.FLINCH_SECONDS)
		if LaunchGate.on("enemyPerf") then
			enemy.perfClock = EnemyPerf.begin(enemy.part.Position.X, enemy.part.Position.Z, now)
		end
	end
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
		-- The rig stays as Remains until the wave clears. Drop the element
		-- Highlight now so dead enemies do not pile up toward the 31 cap.
		ElementGlow.detach(ModelFactory.adorn(enemy.part), enemy.part)
		if enemy.boss and run.echoFight ~= nil then
			local fight = run.echoFight
			-- This copy is down. Stacks stay until every member still
			-- able to swing has cleared the same room.
			noteEchoBoss(fight, tostring(player.UserId), run.roomIndex)
			if echoBossReady(fight, run.roomIndex) then
				-- Once, outside the per-player loot mutate. The next boss starts at 0.
				settleSharedBoss(fight, player)
			else
				echoBossOwed[fight] = run.roomIndex
				-- Only held members on this boss. A downed player on another
				-- wing stays down until the pull actually settles.
				local here = {}
				for _, member in ipairs(heldNow(fight)) do
					local memberRun = runs[member]
					if memberRun ~= nil and memberRun.roomIndex == run.roomIndex then
						table.insert(here, member)
					end
				end
				reviveHeld(fight, here)
			end
		end
		-- Manual swings and Auto-Farm both call damageEnemy, so both grant drops.
		-- Practice returns before any of that: no materials, chests, marks, or XP.
		local landed = {}
		local chestBits = {}
		local saved = true
		local saveErr: string? = nil
		if PracticeLoot.pays(run.practice == true) then
			saved, saveErr = DataService.mutate(player, function(data)
				local room = run.dungeon.rooms[run.roomIndex]
				local bossId = if room ~= nil then room.id else "wing"
				landed, chestBits = PracticeLoot.applyKill(data, {
					practice = false,
					enemyKind = enemy.kind,
					boss = enemy.boss == true,
					dungeonId = run.dungeon.id,
					difficulty = run.difficulty,
					roomId = bossId,
					floorChest = Rootvault.difficulty(run.difficulty).chest,
					now = os.time(),
					rng = RollMath.defaultRng(),
					roll = math.random(),
					claim = run.runId .. ":" .. bossId,
				})
				return nil
			end)
		end
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
				-- The line is the material, never the enemy that dropped it.
				dropPickup(run.folder, enemy.part.Position, landed, player)
				local note = Materials.lootHint(bits, enemy.name)
				if note ~= "" then
					fx(player, {
						kind = "hint",
						text = note,
					})
				end
			end
		else
			warn("[Shardfall] Drop failed:", saveErr)
		end
		-- Far Glade daily. Paying kills only, like the drops above.
		if
			PracticeLoot.pays(run.practice == true)
			and table.find(Dungeons.FAR_GLADE, enemy.kind) ~= nil
		then
			LoopService.progress(player, "glade", 1)
		end
		if LaunchGate.on("enemyPerf") then
			perfRetire(run, enemy)
		else
			pcall(ModelFactory.dissolve, enemy.part)
			enemy.part.Name = "Remains"
			enemy.part:SetAttribute("ShardfallName", "")
			enemy.part.Transparency = 1
			local bar = enemy.part:FindFirstChild("ShardfallBar")
			if bar ~= nil then
				bar:Destroy()
			end
		end
		if aliveCount(run) == 0 then
			-- The boss died while an add was still up, so the seat stayed
			-- open. The room is empty now. Ask again, then clear it.
			if not enemy.boss and run.echoFight ~= nil then
				local fight = run.echoFight
				local owed = echoBossOwed[fight]
				if owed == run.roomIndex and echoBossReady(fight, owed) then
					settleSharedBoss(fight, player)
				end
			end
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
				if PracticeLoot.pays(run.practice == true) then
					DataService.mutate(player, function(data)
						PracticeLoot.grantRoom(data, false, os.time())
						return nil
					end)
				end
				beginAdvance(
					player,
					run,
					string.format("Room clear. Next room in %ds.", Dungeons.ADVANCE_SECONDS)
				)
			end
		end
	end
	pcall(publishCues, player)
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
				radius = MeleeConfig.targetRadius(enemy.part.Size.X, enemy.part.Size.Z),
			})
		end
	end
	return views
end

function DungeonService.isInRun(player: Player): boolean
	local run = runs[player]
	return run ~= nil and not run.resolving
end

function DungeonService.holdEchoJoin(player: Player, held: boolean)
	if held then
		echoJoinHold[player] = true
	else
		echoJoinHold[player] = nil
	end
end

function DungeonService.echoParty(player: Player): { difficulty: string, practice: boolean }?
	-- A held arrival still has a fresh fight until backfill. It is not a host.
	if echoJoinHold[player] == true then
		return nil
	end
	local run = runs[player]
	if run == nil or run.resolving or run.echoFight == nil then
		return nil
	end
	if run.dungeon.id ~= Dungeons.HEARTWOOD_ID then
		return nil
	end
	return {
		difficulty = run.difficulty,
		practice = run.practice == true,
	}
end

-- Largest matching Heartwood pull already on this server. Tie-break is the
-- lowest user id. Practice never matches. The id is a Player in `runs`,
-- never a value from teleport data.
function DungeonService.echoHost(player: Player, difficulty: string): Player?
	if type(difficulty) ~= "string" or difficulty == "" then
		return nil
	end
	local best: Player? = nil
	local bestSize = -1
	for other, otherRun in pairs(runs) do
		if other ~= player and echoJoinHold[other] ~= true and otherRun.resolving ~= true then
			local fight = otherRun.echoFight
			if
				fight ~= nil
				and otherRun.dungeon.id == Dungeons.HEARTWOOD_ID
				and otherRun.practice ~= true
				and fight.practice ~= true
				and otherRun.difficulty == difficulty
			then
				local _, size = RaidEchoFight.counts(fight)
				local chosen = best
				local replace = chosen == nil or size > bestSize
				if
					not replace
					and chosen ~= nil
					and size == bestSize
					and other.UserId < chosen.UserId
				then
					replace = true
				end
				if replace then
					best = other
					bestSize = size
				end
			end
		end
	end
	return best
end

function DungeonService.isPractice(player: Player): boolean
	local run = runs[player]
	return run ~= nil and run.practice == true
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

-- Sap Glob landing. One small purple pool per glob; the tick is in tickPuddles.
local puddleCount = 0
local function dropPuddle(run: Run, x: number, z: number, now: number)
	local rule = Dungeons.PUDDLE
	local list = run.puddles or {}
	table.insert(list, { x = x, z = z, untilAt = now + rule.seconds, nextTick = now + rule.every })
	run.puddles = list
	puddleCount += 1
	marker(
		run,
		"SapPuddle" .. tostring(puddleCount % 8),
		Vector3.new(rule.half * 2, 0.15, rule.half * 2),
		Vector3.new(x, 0.25, z),
		Color3.fromRGB(176, 120, 255),
		rule.seconds,
		nil
	)
end

local function tickPuddles(player: Player, run: Run, hrp: BasePart, now: number)
	local list = run.puddles
	if list == nil then
		return
	end
	local rule = Dungeons.PUDDLE
	local keep = {}
	for _, pool in ipairs(list) do
		if Dungeons.puddleDue(pool.nextTick, pool.untilAt, now) then
			pool.nextTick += rule.every
			if
				CombatFeel.insideMarker(hrp.Position.X, hrp.Position.Z, pool.x, pool.z, rule.half)
			then
				CombatService.damagePlayer(
					player,
					rule.damage,
					hrp.Position.X,
					hrp.Position.Y,
					hrp.Position.Z
				)
				if runs[player] == nil then
					return
				end
			end
		end
		if now < pool.untilAt then
			table.insert(keep, pool)
		end
	end
	run.puddles = if #keep > 0 then keep else nil
end

-- Tusk Rush / Hedge Pounce. A short tween onto the red mark; tickEnemy
-- skips movement until it lands so moveEnemy does not fight the tween.
local function lungeEnemy(enemy: Enemy, run: Run, now: number)
	local position = enemy.part.Position
	local endX, endZ = Dungeons.lungeEnd(position.X, position.Z, enemy.markX, enemy.markZ)
	local originX, _, originZ = Dungeons.roomOrigin(run.placeIndex)
	local limit = run.dungeon.floorSize / 2 - 4
	endX = math.clamp(endX, originX - limit, originX + limit)
	endZ = math.clamp(endZ, originZ - limit, originZ + limit)
	local landing = Vector3.new(endX, position.Y, endZ)
	if (landing - position).Magnitude < 0.5 then
		return
	end
	enemy.dashUntil = now + Dungeons.LUNGE_SECONDS
	local facing = CFrame.lookAt(landing, landing + (landing - position).Unit)
	pcall(function()
		TweenService:Create(
			enemy.part,
			TweenInfo.new(Dungeons.LUNGE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = facing }
		):Play()
	end)
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
	if now < (enemy.dashUntil or 0) then
		-- Visual pieces are anchored apart from the root; step them so the
		-- rig rides the lunge tween instead of snapping at the end.
		pcall(ModelFactory.step, enemy.part, now, true)
		return
	end
	moveEnemy(enemy, hrp.Position, dt, run.placeIndex, run.dungeon.floorSize)
	pcall(ModelFactory.step, enemy.part, now, true)
	if
		LaunchGate.on("enemyPerf")
		and run.dungeon.endless == true
		and EnemyPerf.isBiggest(Dungeons.waveCount(run.wave), Dungeons.WAVE_MAX_COUNT)
	then
		local position = enemy.part.Position
		local distance =
			CombatMath.planarDistance(position.X, position.Z, hrp.Position.X, hrp.Position.Z)
		local hold = math.max(2, enemy.range * 0.65)
		local clock = enemy.perfClock
		if clock == nil then
			clock = EnemyPerf.begin(position.X, position.Z, now)
		end
		local nextClock, stalled =
			EnemyPerf.observe(clock, position.X, position.Z, now, distance > hold)
		enemy.perfClock = nextClock
		enemy.perfStuck = stalled
		if stalled then
			return
		end
	end

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
		enemy.telegraphUntil = 0
		pcall(publishCues, player)
		enemy.nextAttack = now + CombatMath.cooldown(enemy.attackSpeed)
		local struck = CombatFeel.insideMarker(
			hrp.Position.X,
			hrp.Position.Z,
			enemy.markX,
			enemy.markZ,
			CombatFeel.MARKER_HALF
		)
		if enemy.style == "projectile" and Dungeons.LOBS[enemy.kind] ~= true then
			CombatService.launchEnemyShot(
				player,
				position,
				hrp.Position,
				enemy.damage,
				enemy.projectileSpeed,
				enemy.range
			)
		else
			if Dungeons.LUNGES[enemy.kind] ~= nil then
				lungeEnemy(enemy, run, now)
			end
			if Dungeons.LOBS[enemy.kind] == true and enemy.kind == Dungeons.PUDDLE.kind then
				dropPuddle(run, enemy.markX, enemy.markZ, now)
			end
			if not struck then
				return
			end
			CombatService.damagePlayer(
				player,
				enemy.damage,
				hrp.Position.X,
				hrp.Position.Y,
				hrp.Position.Z
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
	if distance > (Dungeons.LUNGES[enemy.kind] or enemy.range) then
		return
	end
	local colorName = "red"
	if enemy.boss and enemy.phase >= 3 then
		colorName = "blue"
	elseif (enemy.boss and enemy.phase >= 2) or Dungeons.LOBS[enemy.kind] == true then
		-- Boss phase 2, and the Far Glade lobbers' landing mark.
		colorName = "purple"
	elseif enemy.kind == "thorn_sprite" then
		colorName = "red"
	end
	local cue = CombatFeel.telegraph(colorName, "normal", if enemy.boss then "boss" else nil)
	enemy.telegraphColor = cue.color
	enemy.markX = hrp.Position.X
	enemy.markZ = hrp.Position.Z
	enemy.telegraphUntil = now + cue.seconds
	CombatService.noteTelegraph(player, enemy.telegraphUntil)
	fx(player, {
		kind = "telegraph",
		color = cue.color,
		verb = cue.verb,
		seconds = cue.seconds,
		x = hrp.Position.X,
		y = hrp.Position.Y,
		z = hrp.Position.Z,
	})
	pcall(publishCues, player)
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

local function tickOne(player: Player, run: Run, step: number, now: number)
	if run.resolving or player.Parent == nil then
		return
	end
	local hrp = rootPart(player)
	if hrp == nil then
		return
	end
	if hrp.Position.Y < -40 then
		if (fallAt[player] or 0) <= now then
			fallAt[player] = now + 1
			print("[Shardfall] " .. player.Name .. " fell out of the room; returning to the spawn")
			teleport(player, roomSpawn(run.placeIndex))
		end
		return
	end
	if run.cleared then
		tickAdvance(player, run, now)
		return
	end
	for _, enemy in pairs(run.enemies) do
		if runs[player] == nil or run.resolving then
			break
		end
		tickEnemy(player, run, enemy, hrp, step, now)
	end
	if LaunchGate.on("enemyPerf") and runs[player] ~= nil and not run.resolving and not run.cleared then
		local stuckIds = {}
		for id, enemy in pairs(run.enemies) do
			if enemy.perfStuck == true and enemy.hp > 0 then
				table.insert(stuckIds, id)
			end
		end
		for _, id in ipairs(stuckIds) do
			local enemy = run.enemies[id]
			if enemy ~= nil and enemy.hp > 0 then
				unstickEnemy(run, enemy)
			end
			if runs[player] == nil or run.resolving then
				break
			end
		end
	end
	if runs[player] ~= nil and not run.resolving and not run.cleared then
		tickPuddles(player, run, hrp, now)
	end
	if runs[player] ~= nil and not run.resolving and not run.cleared then
		CombatService.companionTick(player)
		CombatService.autoTick(player)
		farmPath(player, run, hrp)
	end
end

local function tickRestart(player: Player, plan: Restart, now: number)
	if restartAt[player] ~= plan then
		return
	end
	if farmOn[player] ~= true or player.Parent == nil or runs[player] ~= nil then
		restartAt[player] = nil
		return
	end
	if now >= plan.at then
		restartAt[player] = nil
		local result = DungeonService.enter(player, plan.dungeonId)
		if result.ok ~= true then
			pushRun(player, result.error)
		end
	end
end

local function tickHub(player: Player, now: number)
	if runs[player] ~= nil or player.Parent == nil then
		return
	end
	local hrp = rootPart(player)
	if hrp == nil or not Haven.fellOffHub(hrp.Position.Y) then
		return
	end
	if (fallAt[player] or 0) > now then
		return
	end
	fallAt[player] = now + 2
	print("[Shardfall] " .. player.Name .. " fell off Haven; returning to HubSpawn")
	teleport(player, hubCFrame())
end

-- A tick fault destroys the run. It does not call finish or grant,
-- so a half-cleared room cannot pay twice and Practice stays loot-free.
local function faultPlayer(player: Player, err: any)
	local run = runs[player]
	local warnNow, destroy =
		RunTick.fault(tickFault[player] == true, run ~= nil, run ~= nil and run.resolving == true)
	if warnNow then
		tickFault[player] = true
		warn("[Shardfall] " .. player.Name .. " dungeon tick failed: " .. tostring(err))
	end
	if not destroy or run == nil then
		return
	end
	run.resolving = true
	restartAt[player] = nil
	pcall(CombatService.revive, player)
	local dropped, dropErr = pcall(destroyRun, player, run)
	if not dropped then
		runs[player] = nil
		pcall(CombatService.clearShots, player)
		warn("[Shardfall] " .. player.Name .. " dungeon tick cleanup failed: " .. tostring(dropErr))
	end
end

local function onHeartbeat(dt: number)
	local step = math.min(dt, 0.1)
	local now = os.clock()
	-- pcall(fn, args) so one bad run cannot abort the others, and the
	-- hot path does not allocate a closure per player per frame.
	for player, run in pairs(runs) do
		local tickOk, tickErr = pcall(tickOne, player, run, step, now)
		if not tickOk then
			faultPlayer(player, tickErr)
		end
	end
	local pending = {}
	for player, plan in pairs(restartAt) do
		table.insert(pending, { player = player, plan = plan })
	end
	for _, row in ipairs(pending) do
		local restartOk, restartErr = pcall(tickRestart, row.player, row.plan, now)
		if not restartOk then
			faultPlayer(row.player, restartErr)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local hubOk, hubErr = pcall(tickHub, player, now)
		if not hubOk then
			faultPlayer(player, hubErr)
		end
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
	-- Rootvault and Waves. A missing tier joins on Normal. Hard under
	-- Lv 5 is refused here again so a spoofed remote cannot skip the pad.
	local tierId: string? = nil
	if raidMode == nil then
		local accepted, tierWhy = HardMode.accept(profile.level, difficulty)
		if accepted == nil then
			return reject(tierWhy or HardMode.REFUSED)
		end
		tierId = accepted
	end
	if raidMode ~= nil then
		local allowed, why = PracticeLoot.levelGate(profile.level)
		if not allowed then
			return reject(why or string.format("Level %d opens The Heartwood.", raidMode.level))
		end
		if raidMode.id == "normal" and profile.raidStory ~= true then
			return reject("Clear Story once before Normal.")
		end
	end
	if activeFolder == nil then
		return reject("The dungeon world is still loading.")
	end

	local runId = HttpService:GenerateGUID(false)
	local folder = Instance.new("Folder")
	folder.Name = "Run_" .. tostring(player.UserId) .. "_" .. runId:sub(1, 8)
	folder.Parent = activeFolder
	local endless = dungeon.endless == true
	local echoFight: RaidEchoFight.Fight? = nil
	if raidMode ~= nil then
		echoFight = RaidEchoFight.open(raidMode.id, practice == true, tostring(player.UserId))
	end
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
		difficulty = if raidMode ~= nil then raidMode.id else (tierId :: string),
		offer = nil,
		eliteNext = false,
		shrine = "",
		startedAt = os.clock(),
		runId = runId,
		practice = practice == true,
		raidPlayers = 1,
		healerPresent = false,
		echoFight = echoFight,
		echo = if echoFight ~= nil then echoFight.state else nil,
		retrying = false,
	}
	runs[player] = run
	CombatService.refresh(player)
	if echoFight ~= nil then
		rememberMax(player, run)
	end
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
	if run.echoFight ~= nil then
		-- Profile raidEcho is the old permanent stack. This fight starts from wipes.
		RaidEchoFight.setPractice(run.echoFight, run.practice)
	end
	local wing = PracticeLoot.wing(options.wing, #run.dungeon.rooms)
	-- A wing change is not a clear. The seat flag is the only record.
	-- The shared reset reads it and does not treat the old room as held.
	if wing ~= run.roomIndex then
		run.echoJumped = true
	end
	run.roomIndex = wing
	run.placeIndex = wing
	run.advanceAt = nil
	run.offer = nil
	teleport(player, roomSpawn(run.placeIndex))
	spawnRoom(player, run)
	-- Phase and hit points stay on the spawned boss. A client value is ignored.
	PracticeLoot.openedPhase(options.phase, options.hp)
	local room = run.dungeon.rooms[wing]
	pushRun(player, if room ~= nil then room.name else "Heartwood")
	return { ok = true, run = publicRun(player) }
end

function DungeonService.advance(player: Player)
	local run = runs[player]
	if run == nil then
		return reject("You are not in a dungeon.")
	end
	-- Clears cleared, advanceAt, and the door offer before the stream
	-- yield. After it, spawn only if this run is still current.
	local outcome = DungeonAdvance.advance(run, function()
		return runs[player]
	end, function()
		teleport(player, roomSpawn(run.placeIndex))
	end, function(kind: string)
		if kind == "wave" then
			spawnWave(player, run)
		else
			spawnRoom(player, run)
		end
	end)
	if outcome == "spawned" then
		return { ok = true, run = publicRun(player) }
	end
	if outcome == "uncleared" then
		return reject("Clear this room first.")
	end
	if outcome == "last" then
		return reject("That was the last room.")
	end
	return reject("You are not in a dungeon.")
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
	-- Mark ending before the hub stream yields. An advance still inside
	-- RequestStreamAroundAsync must not spawn this run when it resumes.
	run.resolving = true
	pcall(CombatService.revive, player)
	pcall(teleport, player, hubCFrame())
	destroyRun(player, run)
	pushRun(player, "Left the Rootvault.")
	return { ok = true, run = publicRun(player) }
end

function DungeonService.startDailyBoss(player: Player)
	if not LaunchGate.on("pass") then
		return { ok = false, error = "That is closed." }
	end
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
	if not DevAccess.player(player) then
		return reject(DevAccess.DENIED)
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
	return { ok = true, run = publicRun(player), message = "Skipped to the boss room." }
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
		if PracticeLoot.pays(run.practice == true) then
			DataService.mutate(player, function(data)
				PracticeLoot.grantRoom(data, false, os.time())
				data.gold += Rootvault.TREASURE_GOLD
				return nil
			end)
		end
	elseif picked.id == "elite" then
		run.eliteNext = true
	elseif picked.id == "spring" then
		-- Same rule as a skill percent: unbuffed loadout max, then one heal hook.
		local _, vitality = CombatMath.loadout(DataService.get(player))
		local baseMax = vitality.maxHealth
		CombatService.healAmount(player, math.max(1, math.floor(baseMax * 0.3)))
	elseif picked.id == "shrine" then
		run.shrine = Rootvault.shrine(math.random(1, 3))
	elseif picked.id == "shop" then
		if PracticeLoot.pays(run.practice == true) then
			DataService.mutate(player, function(data)
				if (data.shardKeys or 0) < 40 then
					return nil
				end
				data.shardKeys -= 40
				data.chests.Uncommon = (data.chests.Uncommon or 0) + 1
				return nil
			end)
		end
	end
	pushRun(player, picked.note)
	OnboardingService.note(player, "door")
	return DungeonService.advance(player)
end

function DungeonService.setDifficulty(player: Player, tier: any)
	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	-- This player's memory only. A refusal does not write a save or anyone else.
	local accepted, why = HardMode.select(profile.level, tier, player.UserId)
	if accepted == nil then
		return reject(why or HardMode.REFUSED)
	end
	return { ok = true, tier = accepted }
end

local function enterFromPad(player: Player, dungeonId: any)
	local profile = DataService.get(player)
	local level = if profile ~= nil then profile.level else 1
	local tier, why = HardMode.touch(level, player.UserId)
	if tier == nil then
		pushRun(player, why or HardMode.PAD_REFUSED)
		return
	end
	local result = DungeonService.enter(player, dungeonId, tier)
	if result.ok ~= true then
		pushRun(player, result.error)
	end
end

function DungeonService.action(player: Player, action: string, dungeonId: any, extra: any)
	if action == "difficulty" then
		local requested = if type(extra) == "string" then extra else dungeonId
		return DungeonService.setDifficulty(player, requested)
	end
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
				enterFromPad(player, descendant:GetAttribute("EnterDungeon"))
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

local function quietRoom(player: Player, run: Run)
	CombatService.clearShots(player)
	clearEnemies(run)
end

local function pullMember(member: Player, memberRun: Run, fight: RaidEchoFight.Fight)
	CombatService.revive(member)
	RaidEchoFight.setAlive(fight, tostring(member.UserId), true)
	rememberMax(member, memberRun)
	teleport(member, roomSpawn(memberRun.placeIndex))
	if runs[member] ~= memberRun or memberRun.retrying ~= true or memberRun.resolving then
		return
	end
	CombatService.revive(member)
	spawnRoom(member, memberRun)
	local label = RaidEchoFight.chip(fight.state, fight.difficulty)
	local text = if label ~= nil then "Wiped. " .. label .. "." else "Wiped."
	pushRun(member, text)
end

local function retryPull(fight: RaidEchoFight.Fight)
	-- A wipe starts a new pull. The cap does not carry into the retry.
	echoRevived[fight] = nil
	local party = {}
	for member, memberRun in pairs(runs) do
		if memberRun.echoFight == fight and memberRun.resolving ~= true then
			table.insert(party, member)
		end
	end
	for _, member in ipairs(party) do
		local waveRun = WaveFlowService.runFor(member)
		if waveRun ~= nil then
			WaveFlowService.wipe(waveRun)
		end
	end
	-- Every guard goes up before any Destroy or stream yield. A hit on
	-- the next party member cannot wipe while this one is still arming.
	for _, member in ipairs(party) do
		local memberRun = runs[member]
		if memberRun ~= nil and memberRun.resolving ~= true then
			memberRun.retrying = true
		end
	end
	for _, member in ipairs(party) do
		local memberRun = runs[member]
		if memberRun ~= nil and memberRun.retrying == true then
			local quiet, quietErr = pcall(quietRoom, member, memberRun)
			if not quiet then
				warn(
					"[Shardfall] "
						.. member.Name
						.. " retry could not clear the room: "
						.. tostring(quietErr)
				)
			end
		end
	end
	for _, member in ipairs(party) do
		local memberRun = runs[member]
		if memberRun == nil or memberRun.retrying ~= true or memberRun.resolving then
			continue
		end
		local pulled, pullErr = pcall(pullMember, member, memberRun, fight)
		if not pulled then
			warn("[Shardfall] " .. member.Name .. " retry failed: " .. tostring(pullErr))
			-- A push that fails after the boss is back must not spawn a second one.
			if
				runs[member] == memberRun
				and memberRun.retrying == true
				and next(memberRun.enemies) == nil
			then
				pcall(spawnRoom, member, memberRun)
			end
		end
	end
	for _, member in ipairs(party) do
		local memberRun = runs[member]
		if memberRun == nil or runs[member] ~= memberRun or memberRun.retrying ~= true then
			continue
		end
		if memberRun.resolving then
			memberRun.retrying = false
			continue
		end
		pcall(CombatService.revive, member)
		if memberRun.echoFight == fight then
			RaidEchoFight.setAlive(fight, tostring(member.UserId), true)
		end
		memberRun.retrying = false
	end
	bindEcho(fight)
end

function DungeonService.onPlayerDown(player: Player)
	local run = runs[player]
	if run == nil or run.resolving or EchoRetry.blocked(run.retrying == true) then
		return
	end
	-- damagePlayer defers this. A boss kill in that window revives first.
	-- Treating the old down as current would mark a living player dead.
	if CombatService.vitals(player) > 0 then
		return
	end
	local fight = run.echoFight
	if fight ~= nil then
		-- Player life. The enemy counter is a different function and must not decide this.
		RaidEchoFight.setAlive(fight, tostring(player.UserId), false)
		bindEcho(fight)
	end
	local living = 1
	local party = 1
	if fight ~= nil then
		living, party = RaidEchoFight.counts(fight)
	end
	local storyPull = fight ~= nil
		and run.dungeon.id == Dungeons.HEARTWOOD_ID
		and run.difficulty == "story"
		and run.practice ~= true
		and fight.practice ~= true
		and fight.pullStarted == true
		and party >= 1
	local storyRetry = storyPull and living == 0
	local action = EchoRetry.decision(run.retrying == true, storyRetry)
	if action == "retry" and fight ~= nil then
		run.retrying = true
		retryPull(fight)
		return
	end
	if action == "ignore" then
		return
	end
	if EchoRetry.hold(party, living, storyPull) then
		-- Spent the one revive. This down stays at 0 and cannot swing. If
		-- that copy was the last seat on the owed boss, release the shared
		-- reset now. A wipe already returned. This does not heal.
		if fight ~= nil then
			local owed = echoBossOwed[fight]
			if
				owed ~= nil
				and CombatService.vitals(player) <= 0
				and reviveSpent(fight, tostring(player.UserId))
				and echoBossReady(fight, owed)
			then
				settleSharedBoss(fight, nil)
			end
		end
		pushRun(player, "Down. The pull continues.")
		return
	end
	finish(player, false)
end

function DungeonService.backfill(player: Player, host: Player)
	local run = runs[player]
	local hostRun = runs[host]
	if run == nil or hostRun == nil or hostRun.echoFight == nil then
		return reject("No raid party is up.")
	end
	if run.dungeon.id ~= Dungeons.HEARTWOOD_ID or hostRun.dungeon.id ~= Dungeons.HEARTWOOD_ID then
		return reject("Echo is a Heartwood buff.")
	end
	if run.resolving or hostRun.resolving then
		return reject("That fight is already over.")
	end
	if
		run.difficulty ~= hostRun.difficulty
		or (run.practice == true) ~= (hostRun.practice == true)
	then
		return reject("That party is on a different pull.")
	end
	local previous = run.echoFight
	if previous ~= nil and previous ~= hostRun.echoFight then
		RaidEchoFight.depart(previous, tostring(player.UserId))
		local sharing = false
		for _, other in pairs(runs) do
			if other ~= run and other.echoFight == previous then
				sharing = true
				break
			end
		end
		if not sharing then
			RaidEchoFight.runEnd(previous)
		end
	end
	run.echoFight = hostRun.echoFight
	RaidEchoFight.backfill(run.echoFight, tostring(player.UserId))
	run.echo = run.echoFight.state
	rememberMax(player, run)
	bindEcho(run.echoFight)
	local label = RaidEchoFight.chip(run.echoFight.state, run.echoFight.difficulty)
	pushRun(player, if label ~= nil then label else "Joined the pull.")
	return { ok = true, run = publicRun(player) }
end

function DungeonService.start()
	-- No server-wide pad tier. Each player joins on Normal in noteJoin.
	print("[Rootvault] build " .. Build.STAMP .. " spawner=ModelFactory boss=Grandmother Gnarl")
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
		enterFromPad(player, Dungeons.ROOTVAULT_ID)
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
		-- This player joins on Normal. Other players' tiers stay as they are.
		-- Nothing is read from or written to the profile.
		HardMode.noteJoin(player.UserId)
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

	DataService.onChanged(function(player)
		pcall(publishCues, player)
	end)

	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run ~= nil then
			run.resolving = true
			destroyRun(player, run)
		end
		lastCue[player] = nil
		echoJoinHold[player] = nil
		touchAt[player] = nil
		fallAt[player] = nil
		farmOn[player] = nil
		restartAt[player] = nil
		idleNoted[player] = nil
		tickFault[player] = nil
		HardMode.release(player.UserId)
	end)

	RunService.Heartbeat:Connect(onHeartbeat)
end

CombatService.bindEcho(function(player: Player, amount: number): number
	return echoScale(player, amount, "healing")
end, function(player: Player, amount: number): number
	return echoScale(player, amount, "maxHp")
end)

return DungeonService
