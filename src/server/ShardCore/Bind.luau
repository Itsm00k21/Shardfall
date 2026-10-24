--!strict

--[[
	Studio and server entry for Shard Core.

	start() binds GetShardCore, FeedShardCore, and ShardCoreChanged.
	ShardCoreChanged is server to client only. The handlers refuse
	while LaunchGate.shardCore is off, and they do not write a profile
	in that case.
]]

local Rate = require("./Rate")
local Remotes = require("./Remotes")
local Validate = require("./Validate")

local Bind = {}

local buckets: { [string]: Rate.Bucket } = {}
local started = false

local function fail(message: string)
	return { ok = false, error = message }
end

local function isPlayer(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player")
end

function Bind.start()
	if started then
		return
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
	local DataService = require(script.Parent.Parent.DataService)
	local config = require(ReplicatedStorage.Shared.Config.ShardCore)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder == nil then
		warn("[ShardCore] Remotes folder missing")
		return
	end
	local changed = folder:FindFirstChild("ShardCoreChanged")
	local function fire(player: Player, payload: any)
		if changed ~= nil and changed:IsA("RemoteEvent") then
			changed:FireClient(player, payload)
		end
	end
	local function invoke(player: any, action: string, args: { any })
		if not isPlayer(player) then
			return fail(Validate.PROFILE)
		end
		return Remotes.handle({
			action = action,
			userId = player.UserId,
			args = args,
			now = os.clock(),
		}, {
			coreOn = function()
				return LaunchGate.on("shardCore")
			end,
			read = function(userId)
				if userId ~= player.UserId then
					return nil
				end
				return DataService.get(player)
			end,
			mutate = function(userId, mutator)
				if userId ~= player.UserId then
					return false, Validate.PROFILE
				end
				return DataService.mutate(player, mutator)
			end,
			changed = function(userId, payload)
				if userId == player.UserId then
					fire(player, payload)
				end
			end,
			ctx = { config = config },
		}, buckets)
	end
	local function hook(name: string, action: string, arity: number)
		local remote = folder:FindFirstChild(name)
		if remote == nil or not remote:IsA("RemoteFunction") then
			warn("[ShardCore] missing " .. name)
			return
		end
		remote.OnServerInvoke = function(player, a)
			local args = {}
			if arity >= 1 then
				table.insert(args, a)
			end
			return invoke(player, action, args)
		end
	end
	hook("GetShardCore", "GetShardCore", 0)
	hook("FeedShardCore", "FeedShardCore", 1)
	Players.PlayerRemoving:Connect(function(player)
		Rate.forget(buckets, player.UserId)
	end)
	started = true
end

return Bind
