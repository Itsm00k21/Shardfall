--!strict

--[[
	RemoteFunctions the test UI calls. Every one of them:

	  1. Rate-limits the player.
	  2. Checks the argument types here, before any service sees them.
	  3. pcalls the service so a bug becomes "Something went wrong." and
	     not a raw error string sent to the client.
	  4. Attaches a fresh profile snapshot on the way out.

	The RemoteFunction instances themselves live in default.project.json
	(ReplicatedStorage.Remotes) so they exist as soon as Rojo syncs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local RateLimiter = require(script.Parent.RateLimiter)
local RollService = require(script.Parent.RollService)
local Pools = require(ReplicatedStorage.Shared.Pools)
local RollMath = require(ReplicatedStorage.Shared.RollMath)

local Remotes = {}

local folder: Folder? = nil

local function remoteFolder(): Folder
	if folder == nil then
		local found = ReplicatedStorage:WaitForChild("Remotes", 15)
		assert(
			found ~= nil and found:IsA("Folder"),
			"ReplicatedStorage.Remotes is missing. Is Rojo synced?"
		)
		folder = found :: Folder
	end
	return folder :: Folder
end

local function functionRemote(name: string): RemoteFunction
	local instance = remoteFolder():WaitForChild(name, 15)
	assert(instance ~= nil and instance:IsA("RemoteFunction"), "Missing RemoteFunction " .. name)
	return instance
end

local function eventRemote(name: string): RemoteEvent
	local instance = remoteFolder():WaitForChild(name, 15)
	assert(instance ~= nil and instance:IsA("RemoteEvent"), "Missing RemoteEvent " .. name)
	return instance
end

function Remotes.pushProfile(player: Player, snapshot: any, saving: boolean)
	if player.Parent == nil then
		return
	end
	eventRemote("ProfileUpdated"):FireClient(player, snapshot, saving)
end

local function respond(player: Player, result: any)
	if type(result) ~= "table" then
		return { ok = false, error = "Something went wrong." }
	end
	result.saving = DataService.isPersistent()
	local snapshot = DataService.snapshot(player)
	if snapshot ~= nil then
		result.profile = snapshot
	end
	return result
end

local function guard(player: Player, action: string, callback: () -> any)
	if type(player) ~= "Instance" or not player:IsA("Player") then
		return { ok = false, error = "Something went wrong." }
	end
	if not RateLimiter.take(player.UserId, action) then
		return { ok = false, error = "Slow down a moment." }
	end
	local ok, result = pcall(callback)
	if not ok then
		warn("[Shardfall] Remote", action, "failed:", result)
		return { ok = false, error = "Something went wrong." }
	end
	return respond(player, result)
end

local function validUid(uid: any): boolean
	return type(uid) == "string"
		and #uid > 0
		and #uid <= 64
		and string.match(uid, "^[%w%-]+$") ~= nil
end

function Remotes.bind()
	functionRemote("GetProfile").OnServerInvoke = function(player)
		return guard(player, "GetProfile", function()
			local data = DataService.waitFor(player, 15)
			if data == nil then
				return { ok = false, error = "Profile is still loading." }
			end
			return { ok = true }
		end)
	end

	functionRemote("GetOdds").OnServerInvoke = function(player, poolId)
		return guard(player, "GetOdds", function()
			if type(poolId) ~= "string" then
				return { ok = false, error = "Unknown shard." }
			end
			local pool = Pools.get(poolId)
			if pool == nil or pool.public ~= true then
				return { ok = false, error = "Unknown shard." }
			end
			local data = DataService.get(player)
			local luck = if data ~= nil then data.shardLuck else 0
			return {
				ok = true,
				odds = RollMath.odds(pool, luck),
			}
		end)
	end

	functionRemote("RollShard").OnServerInvoke = function(player, poolId)
		return guard(player, "RollShard", function()
			return RollService.rollFree(player, poolId)
		end)
	end

	functionRemote("RollPaid").OnServerInvoke = function(player, poolId)
		return guard(player, "RollPaid", function()
			return RollService.rollPaid(player, poolId)
		end)
	end

	functionRemote("EquipItem").OnServerInvoke = function(player, uid)
		return guard(player, "EquipItem", function()
			if not validUid(uid) then
				return { ok = false, error = "You do not have that item." }
			end
			local ok, err = InventoryService.equip(player, uid)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("UnequipItem").OnServerInvoke = function(player, uid)
		return guard(player, "UnequipItem", function()
			if not validUid(uid) then
				return { ok = false, error = "You do not have that item." }
			end
			local ok, err = InventoryService.unequip(player, uid)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("RemoveItem").OnServerInvoke = function(player, uid)
		return guard(player, "RemoveItem", function()
			if not validUid(uid) then
				return { ok = false, error = "You do not have that item." }
			end
			local ok, err, removedName = InventoryService.remove(player, uid)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true, removedName = removedName }
		end)
	end

	functionRemote("DevGrant").OnServerInvoke = function(player, kind)
		return guard(player, "DevGrant", function()
			if type(kind) ~= "string" then
				return { ok = false, error = "Unknown dev grant." }
			end
			return RollService.devGrant(player, kind)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.forget(player.UserId)
	end)
end

return Remotes
