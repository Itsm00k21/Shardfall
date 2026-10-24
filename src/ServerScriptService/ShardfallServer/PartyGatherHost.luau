--!strict

--[[
	[ECHO hook] Studio host for the T4 Gate Ring.

	start() returns before it builds unless LaunchGate.parties is on.
	Parts are a gray pad and four discs in front of Rootvault. No
	ProximityPrompt is created. Prompts already inside the prompt-free
	radius are disabled while this host is running, and left alone when
	the flag is off (this module is not required then).

	Party state stays in memory. No profile write and no teleport.
	The wave arena has its own flag. A finished countdown locks the roster
	and prints it. Players stay in the hub.
]]

local studio = game ~= nil and game.GetService ~= nil

local Players: any
local ReplicatedStorage: any
local RunService: any
local ServerScriptService: any
local Workspace: any
local DataService: any
local LaunchGate: any

if studio then
	Players = game:GetService("Players")
	ReplicatedStorage = game:GetService("ReplicatedStorage")
	RunService = game:GetService("RunService")
	ServerScriptService = game:GetService("ServerScriptService")
	Workspace = game:GetService("Workspace")
	DataService = require(script.Parent.DataService)
	LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
else
	Players = {
		PlayerAdded = { Connect = function() end },
		PlayerRemoving = { Connect = function() end },
		GetPlayers = function()
			return {}
		end,
	}
	RunService = {
		Heartbeat = { Connect = function() end },
	}
	LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
	DataService = {
		get = function(_player)
			return nil
		end,
	}
end

local PartyGatherHost = {}

local started = false
local friendOf: { [number]: boolean } = {}
local friendPending: { [number]: boolean } = {}

local function colorOf(color: { number }): Color3
	return Color3.fromRGB(color[1] or 176, color[2] or 168, color[3] or 198)
end

local function makePart(plan: any, parent: Folder): Part
	local part = Instance.new("Part")
	part.Name = if type(plan.name) == "string" then plan.name else "GatherPart"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	local size = plan.size
	if typeof(size) == "table" then
		part.Size = Vector3.new(size[1] or 1, size[2] or 1, size[3] or 1)
	end
	part.Shape = if plan.shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
	part.Color = colorOf(plan.color)
	part.Transparency = if type(plan.transparency) == "number" then plan.transparency else 0
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

local function promptXZ(prompt: Instance): (number?, number?)
	local parent = prompt.Parent
	if parent == nil then
		return nil, nil
	end
	if parent:IsA("Attachment") then
		local world = parent.WorldPosition
		return world.X, world.Z
	end
	if parent:IsA("BasePart") then
		return parent.Position.X, parent.Position.Z
	end
	return nil, nil
end

local function silencePrompts(gather: any, config: any)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			local x, z = promptXZ(descendant)
			if x ~= nil and z ~= nil and gather.inPromptZone(x, z, config) then
				descendant.Enabled = false
			end
		end
	end
end

local function friendStatus(player: Player, leaderId: number): (boolean, boolean)
	if player.UserId == leaderId then
		return true, true
	end
	local cached = friendOf[player.UserId]
	if cached ~= nil then
		return true, cached
	end
	if friendPending[player.UserId] ~= true then
		friendPending[player.UserId] = true
		local userId = player.UserId
		task.spawn(function()
			local ok, result = pcall(function()
				return player:IsFriendsWith(leaderId)
			end)
			friendOf[userId] = ok and result == true
			friendPending[userId] = nil
		end)
	end
	return false, false
end

local function actorOf(player: Player, state: any): any
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local x: number? = nil
	local y: number? = nil
	local z: number? = nil
	if root ~= nil and root:IsA("BasePart") then
		x = root.Position.X
		y = root.Position.Y
		z = root.Position.Z
	end
	local level = 1
	local levelKnown = false
	local profile = DataService.get(player)
	if type(profile) == "table" and type(profile.level) == "number" then
		level = profile.level
		levelKnown = true
	end
	local known = true
	local friend = true
	local lead = state.members[1]
	if state.friendsOnly == true and lead ~= nil and lead.userId ~= player.UserId then
		known, friend = friendStatus(player, lead.userId)
	end
	local name = player.DisplayName
	if type(name) ~= "string" or name == "" then
		name = player.Name
	end
	return {
		userId = player.UserId,
		name = name,
		level = level,
		levelKnown = levelKnown,
		x = x,
		y = y,
		z = z,
		friendKnown = known,
		friendOfLeader = friend,
	}
end

local function paint(parts: { [string]: Part }, view: any, flashes: { [number]: number }, now: number, config: any)
	local disc = config.slot
	for _, slot in ipairs(view.slots) do
		local part = parts["GatherSlot" .. tostring(slot.id)]
		if part ~= nil then
			local color = disc.openColor
			if flashes[slot.id] ~= nil and flashes[slot.id] > now then
				color = disc.refuseColor
			elseif slot.role == "leader" then
				color = disc.leaderColor
			elseif slot.role == "member" then
				color = disc.memberColor
			elseif slot.role == "friends" then
				color = disc.friendsColor
			end
			part.Color = colorOf(color)
			local transparency = 0.15
			if view.phase == "starting" then
				transparency = 0.15 + 0.85 * view.sweep
			elseif view.phase == "gather" and type(view.secondsLeft) == "number" and view.secondsLeft <= 3 then
				transparency = 0.15 + 0.35 * math.abs(math.sin(now * 6))
			end
			part.Transparency = transparency
		end
	end
end

function PartyGatherHost.start(): Folder?
	if started or not studio or not LaunchGate.on("parties") then
		return nil
	end
	local config = require(ReplicatedStorage.Shared.Config.PartyGather)
	local root = ServerScriptService:WaitForChild("WaveArenaSrc"):WaitForChild("server")
	local gather = require(root:WaitForChild("PartyGather"))
	local options = { launchGate = LaunchGate, config = config }
	local plan = gather.plan(options)
	if plan == nil then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "PartyGather"
	folder.Parent = Workspace
	local parts: { [string]: Part } = {}
	for _, piece in ipairs(plan) do
		local part = makePart(piece, folder)
		parts[part.Name] = part
	end
	silencePrompts(gather, config)
	local state = gather.new(config)
	local flashes: { [number]: number } = {}
	local lastSilence = os.clock()
	started = true
	RunService.Heartbeat:Connect(function()
		if not LaunchGate.on("parties") then
			return
		end
		local now = os.clock()
		if now - lastSilence >= 5 then
			lastSilence = now
			silencePrompts(gather, config)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local events = gather.observe(state, actorOf(player, state), now, options)
			for _, event in ipairs(events) do
				if event.kind == "refuse" and type(event.slot) == "number" then
					flashes[event.slot] = now + config.slot.refuseSeconds
				end
			end
		end
		local ticked = gather.tick(state, now, options)
		for _, event in ipairs(ticked) do
			if event.kind == "start" then
				print(string.format(
					"[Shardfall] party gather start n=%d tier=%s mult=%.1f",
					event.n or 0,
					tostring(event.tier),
					event.mult or 1
				))
			end
		end
		local view = gather.view(state, now, options)
		if view ~= nil then
			paint(parts, view, flashes, now, config)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		gather.drop(state, player.UserId, options)
		friendOf[player.UserId] = nil
		friendPending[player.UserId] = nil
	end)
	return folder
end

return PartyGatherHost
