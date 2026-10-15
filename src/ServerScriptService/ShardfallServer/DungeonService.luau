--!strict

--[[
	Rootvault, built when the server starts.

	Studio does not need a hand-placed map. This module creates a hub and
	four rooms in Workspace.ShardfallWorld, then teleports the player between
	them. Enemies are anchored parts with a chase-and-swing loop. The boss
	adds a weak spot, then a fog that only the sunbeam saves you from.

	A later realm is a row in Dungeons.luau with a higher ascension. Until
	`implemented` is true, enter() refuses it. Rewards (gold, shard tokens,
	materials, and a chance at an Armory or Pets voucher) are granted here,
	on the server, after the boss dies.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Dungeons = require(ReplicatedStorage.Shared.Dungeons)
local Materials = require(ReplicatedStorage.Shared.Materials)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Schema = require(ReplicatedStorage.Shared.Schema)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)

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
}

local runs: { [Player]: Run } = {}
local touchAt: { [Player]: number } = {}
local nextEnemyId = 0
local worldFolder: Folder? = nil
local activeFolder: Folder? = nil

local SPAWNS = {
	Vector3.new(-8, 0, 8),
	Vector3.new(8, 0, 8),
	Vector3.new(0, 0, 14),
	Vector3.new(-10, 0, 12),
}

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
	character:PivotTo(cframe)
	if hrp ~= nil then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
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
	return CFrame.lookAt(Vector3.new(0, 4, -12), Vector3.new(0, 3, 8))
end

local function roomSpawn(index: number): CFrame
	local x, _, z = Dungeons.roomOrigin(index)
	return CFrame.lookAt(Vector3.new(x, 4, z - 16), Vector3.new(x, 3, z + 8))
end

local function buildRoom(parent: Folder, dungeon: Dungeons.DungeonDef, index: number)
	local room = dungeon.rooms[index]
	local model = Instance.new("Model")
	model.Name = room.id
	model.Parent = parent

	local floorColor = if index == #dungeon.rooms
		then Color3.fromRGB(28, 48, 36)
		else Color3.fromRGB(54, 86, 52)
	local center = roomCFrame(index, Vector3.new(0, -0.5, 0))
	makePart(
		"Floor",
		Vector3.new(dungeon.floorSize, 1, dungeon.floorSize),
		center,
		floorColor,
		model,
		true
	)

	local half = dungeon.floorSize / 2
	local wallColor = Color3.fromRGB(34, 58, 40)
	local height = 7
	makePart(
		"WallNorth",
		Vector3.new(dungeon.floorSize, height, 1),
		roomCFrame(index, Vector3.new(0, height / 2, -half)),
		wallColor,
		model,
		true
	)
	makePart(
		"WallSouth",
		Vector3.new(dungeon.floorSize, height, 1),
		roomCFrame(index, Vector3.new(0, height / 2, half)),
		wallColor,
		model,
		true
	)
	makePart(
		"WallWest",
		Vector3.new(1, height, dungeon.floorSize),
		roomCFrame(index, Vector3.new(-half, height / 2, 0)),
		wallColor,
		model,
		true
	)
	makePart(
		"WallEast",
		Vector3.new(1, height, dungeon.floorSize),
		roomCFrame(index, Vector3.new(half, height / 2, 0)),
		wallColor,
		model,
		true
	)

	sign(model, roomCFrame(index, Vector3.new(0, 5, -half + 0.8)), room.name, 16)

	-- The green pad is the door. Touched on the server, and only after the
	-- room's enemies are dead. The panel's Next room button calls the same path.
	local portal = makePart(
		"Portal",
		Vector3.new(7, 0.6, 7),
		roomCFrame(index, Vector3.new(0, 0.4, 18)),
		Color3.fromRGB(72, 180, 110),
		model,
		false
	)
	portal.Material = Enum.Material.Neon
	portal.CanTouch = true
	portal:SetAttribute("RoomIndex", index)
	portal:SetAttribute("DungeonId", dungeon.id)
	sign(model, roomCFrame(index, Vector3.new(0, 3.2, 18)), "NEXT", 6)
end

local function buildWorld()
	local existing = workspace:FindFirstChild("ShardfallWorld")
	if existing ~= nil then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "ShardfallWorld"
	world.Parent = workspace
	worldFolder = world

	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world
	makePart(
		"Floor",
		Vector3.new(48, 1, 48),
		CFrame.new(0, -0.5, 0),
		Color3.fromRGB(86, 120, 72),
		hub,
		true
	)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, -12)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(196, 176, 120)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = hub

	local pad = makePart(
		"EnterPad",
		Vector3.new(8, 0.6, 8),
		CFrame.new(0, 0.4, 8),
		Color3.fromRGB(255, 196, 64),
		hub,
		false
	)
	pad.Material = Enum.Material.Neon
	pad.CanTouch = true
	pad:SetAttribute("EnterDungeon", Dungeons.ROOTVAULT_ID)
	sign(hub, CFrame.new(0, 4, 8), "ENTER ROOTVAULT", 14)

	local rooms = Instance.new("Folder")
	rooms.Name = "Rooms"
	rooms.Parent = world
	local dungeon = Dungeons.get(Dungeons.ROOTVAULT_ID)
	assert(dungeon ~= nil, "Rootvault is missing from Dungeons.luau")
	for index = 1, #dungeon.rooms do
		buildRoom(rooms, dungeon, index)
	end

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
	for _, enemy in pairs(run.enemies) do
		if enemy.hp > 0 then
			remaining += 1
			if enemy.boss then
				boss = true
				phase = enemy.phase
			end
		end
	end
	return {
		active = true,
		dungeonId = run.dungeon.id,
		dungeonName = run.dungeon.name,
		roomName = if room ~= nil then room.name else "",
		roomIndex = run.roomIndex,
		roomCount = #run.dungeon.rooms,
		remaining = remaining,
		cleared = run.cleared,
		boss = boss,
		phase = phase,
		note = note,
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

local function enemyBar(part: BasePart, name: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShardfallBar"
	gui.Size = UDim2.fromOffset(96, 28)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.6, 0)
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
		enemy.part:Destroy()
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
	local x, _, z = Dungeons.roomOrigin(run.roomIndex)
	beam.CFrame = CFrame.new(x + offset.x, 0.45, z + offset.z)
end

local function spawnEnemy(run: Run, kind: string, offset: Vector3): Enemy?
	local definition = Dungeons.enemy(kind)
	if definition == nil then
		return nil
	end
	nextEnemyId += 1
	local id = "e" .. tostring(nextEnemyId)
	local size = Vector3.new(definition.size[1], definition.size[2], definition.size[3])
	local color = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
	local y = size.Y / 2 + definition.hover
	local part = makePart(
		definition.name,
		size,
		roomCFrame(run.roomIndex, Vector3.new(offset.X, y, offset.Z)),
		color,
		run.folder,
		false
	)
	part.Material = if definition.boss then Enum.Material.Slate else Enum.Material.Grass
	part:SetAttribute("ShardfallName", definition.name)
	part:SetAttribute("EnemyId", id)
	enemyBar(part, definition.name, color)
	local enemy: Enemy = {
		id = id,
		kind = kind,
		name = definition.name,
		hp = definition.maxHealth,
		maxHp = definition.maxHealth,
		damage = definition.damage,
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
		fogDamage = definition.fogDamage,
		safeRadius = definition.safeRadius,
		nextFog = 0,
		nextAttack = os.clock() + 0.8,
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
			roomCFrame(run.roomIndex, Vector3.new(0, 0.4, 0)),
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

local function destroyRun(player: Player, run: Run)
	clearEnemies(run)
	run.folder:Destroy()
	runs[player] = nil
	CombatService.clearShots(player)
end

local function grant(player: Player, run: Run)
	local rolled = Dungeons.rollClear(run.dungeon, RollMath.defaultRng())
	if rolled == nil then
		return false
	end
	local profile = DataService.get(player)
	local _, _, goldFind = CombatMath.loadout(profile)
	local bonus = CombatMath.bonusGold(rolled.gold, goldFind)
	local levels = 0
	local ok, err = DataService.mutate(player, function(data)
		data.gold += rolled.gold + bonus
		data.shardTokens += rolled.shardTokens
		data.xp += rolled.xp
		local gained = 0
		while data.xp >= Schema.xpToNext(data.level) and gained < 25 do
			data.xp -= Schema.xpToNext(data.level)
			data.level += 1
			gained += 1
		end
		levels = gained
		for materialId, count in pairs(rolled.materials) do
			if data.materials[materialId] == nil then
				data.materials[materialId] = 0
			end
			data.materials[materialId] += count
		end
		if rolled.voucher == "armory" or rolled.voucher == "pets" then
			data.vouchers[rolled.voucher] = (data.vouchers[rolled.voucher] or 0) + 1
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

	local lines = {}
	for _, materialId in ipairs(Materials.ORDER) do
		local count = rolled.materials[materialId]
		if count ~= nil and count > 0 then
			table.insert(lines, {
				name = Materials.displayName(materialId),
				count = count,
			})
		end
	end
	fx(player, {
		kind = "victory",
		dungeonName = run.dungeon.name,
		gold = rolled.gold,
		bonusGold = bonus,
		shardTokens = rolled.shardTokens,
		xp = rolled.xp,
		levels = levels,
		materials = lines,
		voucher = rolled.voucher,
	})
	return true
end

local function finish(player: Player, victory: boolean)
	local run = runs[player]
	if run == nil or run.resolving then
		return
	end
	run.resolving = true
	local saved = true
	if victory then
		saved = grant(player, run)
	else
		fx(player, {
			kind = "defeat",
			text = "The Rootvault pushes you out. Materials from earlier clears are still yours.",
		})
	end
	destroyRun(player, run)
	CombatService.revive(player)
	teleport(player, hubCFrame())
	local note = "Defeated."
	if victory and saved then
		note = "Rootvault cleared."
	elseif victory then
		note = "Clear did not save."
	end
	pushRun(player, note)
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

function DungeonService.damageEnemy(player: Player, enemyId: string, amount: number, _crit: boolean)
	local run = runs[player]
	if run == nil or run.resolving then
		return
	end
	local enemy = run.enemies[enemyId]
	if enemy == nil or enemy.hp <= 0 then
		return
	end
	enemy.hp -= amount
	if enemy.hp < 0 then
		enemy.hp = 0
	end
	paintEnemy(enemy)
	if enemy.boss then
		local phase = Dungeons.bossPhase(enemy.hp, enemy.maxHp, enemy.phase2At)
		if phase ~= enemy.phase and phase == 2 and enemy.hp > 0 then
			enemy.phase = 2
			enemy.weakUntil = 0
			enemy.nextFog = os.clock() + enemy.fogInterval
			enemy.part.Color = Color3.fromRGB(96, 48, 140)
			if run.sunbeam ~= nil then
				run.sunbeam.Transparency = 0
			end
			placeSunbeam(run)
			pushRun(player, "Spore fog. Stand in the sunbeam before it pulses.")
		end
	end
	if enemy.hp <= 0 then
		enemy.part.Transparency = 0.55
		local bar = enemy.part:FindFirstChild("ShardfallBar")
		if bar ~= nil then
			bar:Destroy()
		end
		if aliveCount(run) == 0 then
			if run.roomIndex >= #run.dungeon.rooms then
				finish(player, true)
			else
				run.cleared = true
				pushRun(player, "Room clear. Step on the green pad, or press Next room.")
			end
		end
	end
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
	moveEnemy(enemy, hrp.Position, dt, run.roomIndex, run.dungeon.floorSize)

	if enemy.boss and enemy.phase == 1 then
		if now < enemy.weakUntil then
			enemy.part.Color = Color3.fromRGB(255, 196, 64)
		else
			enemy.part.Color = enemy.color
		end
	end

	if enemy.boss and enemy.phase == 2 and run.sunbeam ~= nil and now >= enemy.nextFog then
		local beam = run.sunbeam
		local safe = CombatMath.withinPlanar(
			hrp.Position.X,
			hrp.Position.Z,
			beam.Position.X,
			beam.Position.Z,
			enemy.safeRadius
		)
		if not safe then
			CombatService.damagePlayer(
				player,
				enemy.fogDamage,
				hrp.Position.X,
				hrp.Position.Y,
				hrp.Position.Z
			)
		end
		run.sunbeamIndex = (run.sunbeamIndex % #Dungeons.SUNBEAM_OFFSETS) + 1
		placeSunbeam(run)
		enemy.nextFog = now + enemy.fogInterval
		if runs[player] == nil then
			return
		end
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
			hrp.Position.Z
		)
		if enemy.boss and enemy.phase == 1 and runs[player] ~= nil then
			enemy.weakUntil = os.clock() + enemy.weakSeconds
		end
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
		if hrp == nil or run.cleared then
			continue
		end
		for _, enemy in pairs(run.enemies) do
			if runs[player] == nil or run.resolving then
				break
			end
			tickEnemy(player, run, enemy, hrp, step, now)
		end
	end
end

local function reject(message: string)
	return { ok = false, error = message }
end

function DungeonService.enter(player: Player, dungeonId: any)
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
	if activeFolder == nil then
		return reject("The dungeon world is still loading.")
	end

	local folder = Instance.new("Folder")
	folder.Name = "Run_"
		.. tostring(player.UserId)
		.. "_"
		.. HttpService:GenerateGUID(false):sub(1, 8)
	folder.Parent = activeFolder
	local run: Run = {
		dungeon = dungeon,
		roomIndex = 1,
		enemies = {},
		cleared = false,
		resolving = false,
		folder = folder,
		sunbeam = nil,
		sunbeamIndex = 1,
	}
	runs[player] = run
	CombatService.refresh(player)
	spawnRoom(player, run)
	teleport(player, roomSpawn(1))
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
	if run.roomIndex >= #run.dungeon.rooms then
		return reject("That was the last room.")
	end
	run.roomIndex += 1
	spawnRoom(player, run)
	teleport(player, roomSpawn(run.roomIndex))
	return { ok = true, run = publicRun(player) }
end

function DungeonService.leave(player: Player)
	local run = runs[player]
	if run == nil then
		teleport(player, hubCFrame())
		return { ok = true, run = publicRun(player) }
	end
	if run.resolving then
		return { ok = true, run = publicRun(player) }
	end
	destroyRun(player, run)
	CombatService.revive(player)
	teleport(player, hubCFrame())
	pushRun(player, "Left the Rootvault.")
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
	spawnRoom(player, run)
	teleport(player, roomSpawn(run.roomIndex))
	return { ok = true, run = publicRun(player) }
end

function DungeonService.action(player: Player, action: string, dungeonId: any)
	if action == "enter" then
		return DungeonService.enter(player, dungeonId)
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

local function bindTouches()
	local world = worldFolder
	if world == nil then
		return
	end
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
				if descendant:GetAttribute("RoomIndex") ~= run.roomIndex then
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

function DungeonService.onPlayerDown(player: Player)
	finish(player, false)
end

function DungeonService.start()
	buildWorld()
	bindTouches()

	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if player.Parent == nil then
					return
				end
				local run = runs[player]
				if run ~= nil and not run.resolving then
					teleport(player, roomSpawn(run.roomIndex))
				else
					teleport(player, hubCFrame())
				end
			end)
		end)
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
	end)

	RunService.Heartbeat:Connect(onHeartbeat)
end

return DungeonService
