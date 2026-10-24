--!strict

--[[
	Studio and server entry for Phase 2 equip.

	start() binds the four remotes. EquipChanged is server to client
	only. The handlers refuse while LaunchGate.equip is off, and they
	do not write a profile in that case.

	devEquipOwned is the Dev Tools button. DebugService already checked
	Studio and the owner. This checks the flag again.
]]

local EquipService = require("./EquipService")
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

local function catalog()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
	return {
		slots = require(ReplicatedStorage.Shared.Config.EquipSlots),
		stats = require(ReplicatedStorage.Shared.Config.EquipStats),
		elements = require(ReplicatedStorage.Shared.Config.Elements),
		classes = require(ReplicatedStorage.Shared.Classes),
		gearConfig = require(ReplicatedStorage.Shared.Config.GearLevels),
		-- Upgrade scale is its own flag. gearLevels is the undecided dupe rule.
		gearEnabled = LaunchGate.on("upgradeScale"),
		-- [ECHO hook] Shard Core perks. Totals calls applyCore only when the flag is on.
		coreConfig = require(ReplicatedStorage.Shared.Config.ShardCore),
		coreEnabled = LaunchGate.on("shardCore"),
		applyCore = require(script.Parent.Parent.ShardCore.Perks).apply,
	}
end

local function lineText(view: any, statId: string): string
	if
		type(view) ~= "table"
		or type(view.stats) ~= "table"
		or type(view.stats.lines) ~= "table"
	then
		return "0"
	end
	for _, line in ipairs(view.stats.lines) do
		if type(line) == "table" and line.id == statId and type(line.text) == "string" then
			return line.text
		end
	end
	return "0"
end

function Bind.devEquipOwned(player: Player): any
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
	local DevTools = require(ReplicatedStorage.Shared.DevTools)
	if not LaunchGate.on("equip") then
		return fail(DevTools.offMessage("equip"))
	end
	local DataService = require(script.Parent.Parent.DataService)
	local ctx = catalog()
	local seated = 0
	local view = nil
	local ok, err = DataService.mutate(player, function(data)
		seated = EquipService.fillOwned(data, ctx)
		view = EquipService.view(data, ctx)
		return nil
	end)
	if not ok or type(view) ~= "table" then
		return fail(err or Validate.UPDATE)
	end
	return {
		ok = true,
		message = string.format(
			"Seated %d. Damage %s, HP %s.",
			seated,
			lineText(view, "damage"),
			lineText(view, "health")
		),
		loadout = view.loadout,
		stats = view.stats,
	}
end

function Bind.start()
	if started then
		return
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
	local DataService = require(script.Parent.Parent.DataService)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder == nil then
		warn("[Equip] Remotes folder missing")
		return
	end
	local changed = folder:FindFirstChild("EquipChanged")
	local function fire(player: Player, payload: any)
		if changed ~= nil and changed:IsA("RemoteEvent") then
			changed:FireClient(player, payload)
		end
	end
	local function invoke(player: any, action: string, args: { any })
		if not isPlayer(player) then
			return fail(Validate.PROFILE)
		end
		local ctx = catalog()
		return Remotes.handle({
			action = action,
			userId = player.UserId,
			args = args,
			now = os.clock(),
		}, {
			equipOn = function()
				return LaunchGate.on("equip")
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
			ctx = ctx,
		}, buckets)
	end
	local function hook(name: string, action: string, arity: number)
		local remote = folder:FindFirstChild(name)
		if remote == nil or not remote:IsA("RemoteFunction") then
			warn("[Equip] missing " .. name)
			return
		end
		remote.OnServerInvoke = function(player, a, b)
			local args = {}
			if arity >= 1 then
				table.insert(args, a)
			end
			if arity >= 2 then
				table.insert(args, b)
			end
			return invoke(player, action, args)
		end
	end
	hook("EquipSlot", "EquipSlot", 2)
	hook("UnequipSlot", "UnequipSlot", 1)
	hook("GetEquip", "GetEquip", 0)
	Players.PlayerRemoving:Connect(function(player)
		Rate.forget(buckets, player.UserId)
	end)
	started = true
end

return Bind
