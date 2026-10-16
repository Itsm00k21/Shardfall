--!strict

--[[
	Server travel. Every destination is open. The Travel remote checks the
	cooldown, then streams the destination and moves the character.
	BuyTravelPass is a stub and does not set travelPass.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DungeonService = require(script.Parent.DungeonService)
local PolicyCache = require(script.Parent.PolicyCache)
local Travel = require(ReplicatedStorage.Shared.Travel)

local TravelService = {}

local FLASH_LIFE = 0.45

local function playerFromHit(hit: Instance): Player?
	local current: Instance? = hit
	while current ~= nil do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player ~= nil then
				return player
			end
		end
		current = current.Parent
	end
	return nil
end

local function flash(position: Vector3)
	for index = 1, 6 do
		local shard = Instance.new("Part")
		shard.Name = "ShardFlash"
		shard.Size = Vector3.new(0.6, 1.8, 0.4)
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanTouch = false
		shard.CanQuery = false
		shard.CastShadow = false
		shard.Material = Enum.Material.Neon
		shard.Color = Color3.fromRGB(190, 140, 255)
		local angle = (index - 1) * (math.pi * 2 / 6)
		local out = Vector3.new(math.cos(angle) * 3, 1.5 + (index % 2), math.sin(angle) * 3)
		shard.CFrame = CFrame.new(position + out) * CFrame.Angles(0.4, angle, 0.6)
		shard.Parent = workspace
		task.delay(FLASH_LIFE, function()
			shard:Destroy()
		end)
	end
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character == nil then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local anchored = false
	if hrp ~= nil and hrp:IsA("BasePart") then
		anchored = hrp.Anchored
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.Anchored = true
	end
	character:PivotTo(cframe)
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 5)
	end)
	if hrp ~= nil and hrp:IsA("BasePart") then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.Anchored = anchored
	end
end

function TravelService.unlock(player: Player, id: string)
	local data = DataService.get(player)
	if data == nil or Travel.isUnlocked(data, id) then
		return
	end
	DataService.mutate(player, function(profile)
		if not Travel.touch(profile, id) then
			return "already"
		end
		return nil
	end)
end

function TravelService.go(player: Player, id: string): (boolean, string?)
	if DungeonService.isInRun(player) then
		return false, "Leave the Rootvault first."
	end
	if Travel.get(id) == nil then
		return false, "Unknown destination."
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or root == nil or not root:IsA("BasePart") then
		return false, "You are still loading."
	end
	local x, y, z, lookX, lookZ = Travel.arrival(id)
	if x == nil or y == nil or z == nil or lookX == nil or lookZ == nil then
		return false, "Unknown destination."
	end
	local now = os.time()
	local saved, reason = DataService.mutate(player, function(profile)
		return Travel.attempt(profile, id, now)
	end)
	if not saved then
		return false, reason
	end
	local departure = root.Position
	flash(departure)
	teleport(player, CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(lookX, y, lookZ)))
	flash(Vector3.new(x, y + 2, z))
	return true, nil
end

function TravelService.buyPass(player: Player)
	local allowed, reason, code = PolicyCache.allowPaid(player)
	if not allowed then
		return {
			ok = false,
			code = code,
			error = reason,
		}
	end
	return {
		ok = false,
		code = "stub",
		error = Travel.PASS_PITCH,
	}
end

function TravelService.bind()
	local haven = workspace:FindFirstChild("Haven")
	if haven == nil then
		warn("[Shardfall] Haven model missing; waystones not bound")
		return
	end
	local bound = 0
	for _, descendant in ipairs(haven:GetDescendants()) do
		if
			descendant:IsA("BasePart")
			and Travel.shouldBind(descendant.Name, descendant:GetAttribute("WaystoneId"))
		then
			local id = descendant:GetAttribute("WaystoneId") :: string
			bound += 1
			descendant.Touched:Connect(function(hit)
				if not hit:IsA("BasePart") then
					return
				end
				local player = playerFromHit(hit)
				if player == nil then
					return
				end
				TravelService.unlock(player, id)
			end)
		end
	end
	print(string.format("[Shardfall] Waystones bound: %d", bound))
end

return TravelService
