--!strict

--[[
	[ECHO hook] Studio host for the Phase 3 wave arena.

	present() and handle() return before they build or step unless
	LaunchGate.waveArena and WaveArenaConfig.enabled are both on.
	Loot is committed once, through DataService.mutate, when the run
	settles. There is no Leave. Disconnect is hooked before the profile
	save so a rejoin keeps that loot and does not spawn in the arena.

	The arena modules use require-by-string. init.luau resolves from the
	parent folder (./WaveArena/Child), which matches Lune and the Luau
	init-path rule. WaveArenaSrc in default.project.json mirrors that tree.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(script.Parent.DataService)
local DevAccess = require(ReplicatedStorage.Shared.DevAccess)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local Schema = require(ReplicatedStorage.Shared.Schema)

local WaveArenaHost = {}

local runs: { [Player]: any } = {}
local views: { [Player]: Folder } = {}
local inArena: { [Player]: boolean } = {}
local presented = false

local function sourceRoot(): Instance
	return ServerScriptService:WaitForChild("WaveArenaSrc"):WaitForChild("server")
end

local function modules(): (any, any)
	local server = sourceRoot()
	local arena = require(server:WaitForChild("WaveArena") :: ModuleScript)
	local config = require(ReplicatedStorage.Shared.Config.WaveArenaConfig)
	return arena, config
end

local function sessionModule(): any
	local arena = sourceRoot():WaitForChild("WaveArena")
	return require(arena:WaitForChild("Session") :: ModuleScript)
end

local function lootModule(): any
	local arena = sourceRoot():WaitForChild("WaveArena")
	return require(arena:WaitForChild("Loot") :: ModuleScript)
end

local function open(): boolean
	return LaunchGate.on("waveArena") == true
end

local function options(config: any): any
	return {
		launchGate = LaunchGate,
		config = config,
	}
end

local function occupied(data: any): number
	local held = 0
	if type(data) ~= "table" then
		return 0
	end
	if type(data.inventory) == "table" then
		for _ in pairs(data.inventory) do
			held += 1
		end
	end
	if type(data.pets) == "table" then
		for _ in pairs(data.pets) do
			held += 1
		end
	end
	return held
end

-- Free Bag slots for this session. A missing profile holds every drop as
-- overflow so a full bag cannot delete it.
local function freeBag(player: Player, config: any): number
	local data = DataService.get(player)
	if data == nil then
		return 0
	end
	local free = Schema.inventoryCap(data) - occupied(data)
	if free < 0 then
		free = 0
	end
	local configured = 100
	if type(config) == "table" and type(config.loot) == "table" and type(config.loot.bagSlots) == "number" then
		configured = math.floor(config.loot.bagSlots)
		if configured < 0 then
			configured = 0
		end
	end
	if configured < free then
		return configured
	end
	return free
end

local function colorOf(value: any): Color3
	if typeof(value) ~= "table" then
		return Color3.fromRGB(160, 160, 160)
	end
	return Color3.fromRGB(value[1] or 160, value[2] or 160, value[3] or 160)
end

local function worldFolder(): Folder
	local existing = workspace:FindFirstChild("WaveArenaWorld")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "WaveArenaWorld"
	folder.Parent = workspace
	return folder
end

local function makePart(plan: any, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = if type(plan.name) == "string" then plan.name else "WaveArenaPart"
	part.Anchored = true
	part.CanCollide = plan.canCollide == true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local size = plan.size
	if typeof(size) == "table" then
		part.Size = Vector3.new(size[1] or 4, size[2] or 1, size[3] or 4)
	end
	if plan.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif plan.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	else
		part.Shape = Enum.PartType.Block
	end
	part.Color = colorOf(plan.color)
	local position = plan.position
	local rotation = plan.rotation
	local cf = CFrame.new(0, 0, 0)
	if typeof(position) == "table" then
		cf = CFrame.new(position[1] or 0, position[2] or 0, position[3] or 0)
	end
	if typeof(rotation) == "table" then
		cf = cf * CFrame.Angles(rotation[1] or 0, rotation[2] or 0, rotation[3] or 0)
	end
	part.CFrame = cf
	part.Parent = parent
	return part
end

local function pivot(player: Player, x: number, y: number, z: number)
	local character = player.Character
	if character == nil then
		return
	end
	character:PivotTo(CFrame.new(x, y, z))
end

local function hubReturn(player: Player)
	local hub = workspace:FindFirstChild("HubSpawn", true)
	local character = player.Character
	if character == nil then
		return
	end
	if hub ~= nil and hub:IsA("BasePart") then
		character:PivotTo(hub.CFrame + Vector3.new(0, 4, 0))
		return
	end
	pivot(player, 0, 124, 30)
end

local function syncPlayer(run: any, player: Player)
	local character = player.Character
	local origin = run.origin
	if character == nil or typeof(origin) ~= "table" then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	run.player.x = root.Position.X - origin.x
	run.player.z = root.Position.Z - origin.z
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid.Health <= 0 then
		run.player.hp = 0
	end
end

local function viewOf(player: Player): Folder
	local found = views[player]
	if found ~= nil and found.Parent ~= nil then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = "Fight_" .. tostring(player.UserId)
	folder.Parent = worldFolder()
	views[player] = folder
	return folder
end

local function clearView(player: Player)
	local folder = views[player]
	views[player] = nil
	if folder ~= nil then
		folder:Destroy()
	end
end

local function ensure(folder: Folder, name: string, shape: string, size: Vector3, color: Color3): Part
	local existing = folder:FindFirstChild(name)
	if existing ~= nil and existing:IsA("Part") then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Parent = folder
	return part
end

local function paint(run: any, player: Player, config: any, events: { any })
	local folder = viewOf(player)
	local origin = run.origin
	if typeof(origin) ~= "table" then
		return
	end
	local seen: { [string]: boolean } = {}
	if typeof(run.enemies) == "table" then
		for _, enemy in ipairs(run.enemies) do
			local name = "Enemy_" .. tostring(enemy.uid)
			seen[name] = true
			local profile = config.profile(config, enemy.kind)
			local size = profile.size
			local part = ensure(
				folder,
				name,
				"Block",
				Vector3.new(size[1], size[2], size[3]),
				colorOf(profile.color)
			)
			part.Transparency = if enemy.alive == true then 0 else 1
			part.CFrame = CFrame.new(origin.x + enemy.x, origin.y + size[2] / 2, origin.z + enemy.z)
		end
	end
	if typeof(run.ground) == "table" then
		for _, drop in ipairs(run.ground) do
			local name = "Chip_" .. tostring(drop.uid)
			seen[name] = true
			local chip = ensure(folder, name, "Ball", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(186, 140, 72))
			chip.CFrame = CFrame.new(origin.x + drop.x, origin.y + 0.8, origin.z + drop.z)
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if string.sub(child.Name, 1, 6) == "Enemy_" or string.sub(child.Name, 1, 5) == "Chip_" then
			if seen[child.Name] ~= true then
				child:Destroy()
			end
		end
	end
	for _, event in ipairs(events) do
		if event.kind == "warning" then
			local disc = Instance.new("Part")
			disc.Name = "Warning"
			disc.Anchored = true
			disc.CanCollide = false
			disc.CanQuery = false
			disc.CanTouch = false
			disc.Shape = Enum.PartType.Cylinder
			disc.Color = Color3.fromRGB(180, 40, 40)
			disc.Material = Enum.Material.Neon
			disc.Transparency = 0.35
			local radius = if type(event.radius) == "number" then event.radius else 8
			disc.Size = Vector3.new(0.4, radius * 2, radius * 2)
			disc.CFrame = CFrame.new(origin.x + event.x, origin.y + 0.3, origin.z + event.z)
				* CFrame.Angles(0, 0, math.rad(90))
			disc.Parent = folder
			task.delay(if type(event.seconds) == "number" then event.seconds else 1, function()
				if disc.Parent ~= nil then
					disc:Destroy()
				end
			end)
		elseif event.kind == "hitFlash" then
			local part = folder:FindFirstChild("Enemy_" .. tostring(event.id))
			if part ~= nil and part:IsA("BasePart") then
				local previous = part.Color
				part.Color = Color3.fromRGB(255, 255, 255)
				task.delay(0.08, function()
					if part.Parent ~= nil then
						part.Color = previous
					end
				end)
			end
		elseif event.kind == "deathPuff" then
			local puff = Instance.new("Part")
			puff.Name = "Puff"
			puff.Anchored = true
			puff.CanCollide = false
			puff.CanQuery = false
			puff.CanTouch = false
			puff.Shape = Enum.PartType.Ball
			puff.Color = Color3.fromRGB(210, 206, 196)
			puff.Transparency = 0.3
			puff.Size = Vector3.new(3, 3, 3)
			puff.CFrame = CFrame.new(origin.x + event.x, origin.y + 1.5, origin.z + event.z)
			puff.Parent = folder
			task.delay(0.45, function()
				if puff.Parent ~= nil then
					puff:Destroy()
				end
			end)
		elseif event.kind == "hit" and type(event.damage) == "number" then
			local character = player.Character
			local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid ~= nil then
				humanoid:TakeDamage(event.damage)
			end
		end
	end
end

local function bossView(run: any, config: any): any
	if typeof(run) ~= "table" or typeof(run.enemies) ~= "table" then
		return nil
	end
	local origin = run.origin
	for _, enemy in ipairs(run.enemies) do
		if enemy.kind == "boss" and enemy.alive == true then
			local size = config.boss.size
			return {
				x = origin.x + enemy.x,
				y = origin.y + size[2] / 2,
				z = origin.z + enemy.z,
				size = { size[1], size[2], size[3] },
			}
		end
	end
	return nil
end

local function stateOf(arena: any, run: any, config: any): any
	local hud = if run ~= nil then arena.hud(run, options(config)) else nil
	return {
		ok = true,
		hud = hud,
		boss = if run ~= nil then bossView(run, config) else nil,
		camera = {
			roomPad = config.camera.roomPad,
			minEyeGap = config.camera.minEyeGap,
		},
	}
end

function WaveArenaHost.present()
	if presented or not open() then
		return nil
	end
	local arena, config = modules()
	if config.enabled ~= true then
		return nil
	end
	local folder = worldFolder()
	local built = arena.present({
		launchGate = LaunchGate,
		config = config,
		create = function(plan)
			local part = makePart(plan, folder)
			if type(plan.prompt) == "string" then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "ShardGatePrompt"
				prompt.ObjectText = plan.prompt
				prompt.ActionText = if type(plan.actionText) == "string" then plan.actionText else "Enter"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.Parent = part
				prompt.Triggered:Connect(function(player)
					WaveArenaHost.handle(player, "enter", nil)
				end)
			end
		end,
	})
	if built == nil then
		return nil
	end
	presented = true
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				WaveArenaHost.receive(player)
			end)
		end)
		task.defer(function()
			WaveArenaHost.receive(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	return built
end

local function grant(player: Player, run: any)
	if typeof(run) ~= "table" or typeof(run.grantList) ~= "table" then
		return
	end
	if type(run.receiptId) ~= "string" then
		run.receiptId = tostring(player.UserId)
	end
	local ok, err = DataService.mutate(player, function(data)
		lootModule().commit(data, run)
		return nil
	end)
	if not ok then
		warn("[Shardfall] WaveArena grant:", err)
	end
end

function WaveArenaHost.disconnect(player: Player)
	local run = runs[player]
	runs[player] = nil
	inArena[player] = nil
	clearView(player)
	if run == nil or not open() then
		return
	end
	local arena, config = modules()
	if config.enabled ~= true then
		return
	end
	arena.settle(run, "disconnect", options(config))
	grant(player, run)
end

local function insideArena(position: Vector3, config: any): boolean
	local origin = config.arena.origin
	local dx = position.X - origin.x
	local dz = position.Z - origin.z
	local limit = config.arena.diameter / 2 + 8
	return dx * dx + dz * dz <= limit * limit
end

-- A rejoin has no server in-arena flag. A body still standing in the
-- arena disk is sent home. The client cannot set that flag.
function WaveArenaHost.receive(player: Player)
	if inArena[player] == true or not open() then
		return
	end
	local _, config = modules()
	if config.enabled ~= true then
		return
	end
	local character = player.Character
	if character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") and insideArena(root.Position, config) then
		hubReturn(player)
	end
end

local function finishIfOver(player: Player, run: any)
	if typeof(run) ~= "table" or (run.settled ~= true and run.phase ~= "results") then
		return
	end
	grant(player, run)
	runs[player] = nil
	inArena[player] = nil
	clearView(player)
	hubReturn(player)
end

function WaveArenaHost.handle(player: Player, action: string, payload: any): any
	if not DevAccess.player(player) then
		return { ok = false, error = DevAccess.DENIED }
	end
	if not open() then
		return { ok = false, error = "The wave arena is off." }
	end
	local arena, config = modules()
	if config.enabled ~= true then
		return { ok = false, error = "The wave arena is off." }
	end
	local session = sessionModule()
	-- payload cannot open the arena or claim the player is already inside.
	if not session.remoteOk(true, inArena[player] == true, action) then
		return { ok = false, error = "Unknown arena action." }
	end
	local opts = options(config)
	if action == "state" then
		return stateOf(arena, runs[player], config)
	end
	if action == "enter" then
		opts.receiptId = tostring(player.UserId) .. ":" .. tostring(os.clock())
		opts.bagSlots = freeBag(player, config)
		local run = arena.enter(opts)
		if run == nil then
			return { ok = false, error = "Could not enter the arena." }
		end
		runs[player] = run
		inArena[player] = true
		if session.teleport(open(), inArena[player] == true) ~= "arena" then
			runs[player] = nil
			inArena[player] = nil
			return { ok = false, error = "The wave arena is off." }
		end
		local origin = config.arena.origin
		local stand = config.player.start
		pivot(player, origin.x + stand.x, origin.y + 3, origin.z + stand.z)
		return stateOf(arena, run, config)
	end
	local run = runs[player]
	if action == "step" then
		if run == nil or session.teleport(open(), true) ~= "arena" then
			inArena[player] = nil
			return stateOf(arena, nil, config)
		end
		syncPlayer(run, player)
		local dt = 0.1
		local attack = false
		if typeof(payload) == "table" then
			if type(payload.dt) == "number" then
				dt = payload.dt
			end
			attack = payload.attack == true
		end
		-- Client coordinates are ignored. The server copies the character.
		local updated, events = arena.step(run, dt, { moveX = 0, moveZ = 0, attack = attack }, opts)
		if updated ~= nil then
			runs[player] = updated
			run = updated
		end
		if typeof(events) == "table" and run ~= nil then
			paint(run, player, config, events)
		end
		local state = stateOf(arena, runs[player], config)
		finishIfOver(player, runs[player])
		return state
	end
	if action == "skip" or action == "boss" then
		if run == nil or session.teleport(open(), inArena[player] == true) ~= "arena" then
			return { ok = false, error = "You are not in the arena." }
		end
		local result = arena.dev(action, run, opts)
		if typeof(result) == "table" and result.run ~= nil then
			runs[player] = result.run
			paint(result.run, player, config, {})
			finishIfOver(player, result.run)
		end
		if typeof(result) ~= "table" then
			return { ok = false, error = "Could not do that." }
		end
		result.hud = arena.hud(runs[player], opts)
		result.boss = bossView(runs[player], config)
		return result
	end
	return { ok = false, error = "Unknown arena action." }
end

return WaveArenaHost
