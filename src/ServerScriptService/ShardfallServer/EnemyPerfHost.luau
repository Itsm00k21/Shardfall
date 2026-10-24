--!strict

--[[
	Instance side of the M10 enemy pool. DungeonService calls this only
	while LaunchGate.enemyPerf is on. Parked rigs sit in ServerStorage so
	they do not replicate. A reused rig keeps its Humanoid, with the unused
	states turned off.
]]

local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyPerf = require(ReplicatedStorage.Shared.Config.EnemyPerf)

local EnemyPerfHost = {}

local idle: { [string]: { Model } } = {}
local parkedCount = 0
local pile: Folder? = nil

local function pileFolder(): Folder
	local existing = pile
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ShardfallEnemyPool"
	folder.Parent = ServerStorage
	pile = folder
	return folder
end

function EnemyPerfHost.prepare(model: Model)
	local found = model:FindFirstChild("PerfHumanoid")
	local humanoid: Humanoid
	if found ~= nil and found:IsA("Humanoid") then
		humanoid = found
	else
		local created = Instance.new("Humanoid")
		created.Name = "PerfHumanoid"
		created.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		created.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		created.BreakJointsOnDeath = false
		created.RequiresNeck = false
		created.AutoRotate = false
		created.AutomaticScalingEnabled = false
		created.MaxHealth = 100
		created.Health = 100
		created.DisplayName = ""
		created.Parent = model
		humanoid = created
	end
	for _, name in ipairs(EnemyPerf.DISABLED_STATES) do
		local state = (Enum.HumanoidStateType :: any)[name]
		if typeof(state) == "EnumItem" then
			humanoid:SetStateEnabled(state :: Enum.HumanoidStateType, false)
		end
	end
	pcall(function()
		(humanoid :: any).EvaluateStateMachine = false
	end)
end

function EnemyPerfHost.park(kind: string, model: Model): boolean
	local root = model.PrimaryPart
	if root ~= nil then
		local bar = root:FindFirstChild("ShardfallBar")
		if bar ~= nil then
			bar:Destroy()
		end
	end
	local body = model:FindFirstChild("Body")
	if body ~= nil then
		local rim = body:FindFirstChild("Rim")
		if rim ~= nil then
			rim:Destroy()
		end
	end
	if parkedCount >= EnemyPerf.ALIVE_CAP then
		model:Destroy()
		return false
	end
	model.Parent = pileFolder()
	local stack = idle[kind]
	if stack == nil then
		stack = {}
		idle[kind] = stack
	end
	table.insert(stack, model)
	parkedCount += 1
	return true
end

function EnemyPerfHost.take(kind: string): BasePart?
	local stack = idle[kind]
	if stack == nil or #stack == 0 then
		return nil
	end
	local model = table.remove(stack)
	if parkedCount > 0 then
		parkedCount -= 1
	end
	if model == nil then
		return nil
	end
	local root = model.PrimaryPart
	if root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	return root
end

return EnemyPerfHost
