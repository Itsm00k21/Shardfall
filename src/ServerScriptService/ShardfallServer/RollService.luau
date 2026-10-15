--!strict

--[[
	Server-authoritative shard rolls.

	rollFree spends one shard token and rolls with RollMath. The client only
	sends a pool id. The item, the pity update, and the token spend happen
	inside DataService.mutate, which rolls back if anything fails.

	rollPaid is a stub. It asks PolicyService whether paid random items are
	restricted for this player, runs that result through PaidRollPolicy, and
	then stops. It does not charge Robux and it does not roll. Wire a real
	developer product here later, after evaluate() returns ok.
]]

local HttpService = game:GetService("HttpService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PaidRollPolicy = require(ReplicatedStorage.Shared.PaidRollPolicy)
local Pools = require(ReplicatedStorage.Shared.Pools)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Schema = require(ReplicatedStorage.Shared.Schema)
local DataService = require(script.Parent.DataService)

local RollService = {}

local function reject(message: string)
	return { ok = false, error = message }
end

local function poolFromClient(poolId: any)
	if type(poolId) ~= "string" or string.match(poolId, "^[%w_]+$") == nil or #poolId > 64 then
		return nil
	end
	local pool = Pools.get(poolId)
	if pool == nil or pool.public ~= true then
		return nil
	end
	return pool
end

function RollService.rollFree(player: Player, poolId: any)
	local pool = poolFromClient(poolId)
	if pool == nil then
		return reject("Unknown shard.")
	end

	local captured: any = nil
	local pityAfter: any = nil
	local ok, err = DataService.mutate(player, function(data)
		if not Pools.isUnlocked(pool, data.ascension) then
			return string.format("Reach Ascension %d to roll %s.", pool.ascension, pool.name)
		end
		if data.shardTokens < 1 then
			return "You need a shard token to crack a shard."
		end
		if Schema.countItems(data) >= Schema.INVENTORY_CAP then
			return "Inventory is full."
		end
		local pity = Schema.pityBucket(data, pool.id)
		local result = RollMath.roll(pool, pity, {
			luck = data.shardLuck,
			-- GenerateGUID does not need HttpService.HttpEnabled.
			uid = HttpService:GenerateGUID(false),
			now = os.time(),
		}, RollMath.defaultRng())
		data.shardTokens -= 1
		Schema.insertItem(data, result.item)
		captured = result
		pityAfter = {
			rollsSinceLegendary = pity.rollsSinceLegendary,
			totalRolls = pity.totalRolls,
			pityLegendaryAt = pool.pityLegendaryAt,
		}
		return nil
	end)
	if not ok or captured == nil then
		return reject(err or "Could not crack that shard.")
	end
	return {
		ok = true,
		item = captured.item,
		pityTriggered = captured.pityTriggered,
		pity = pityAfter,
	}
end

function RollService.rollPaid(player: Player, poolId: any)
	local pool = poolFromClient(poolId)
	if pool == nil then
		return reject("Unknown shard.")
	end

	local profile = DataService.get(player)
	if profile == nil or not Pools.isUnlocked(pool, profile.ascension) then
		return reject(string.format("Reach Ascension %d to roll %s.", pool.ascension, pool.name))
	end

	-- Policy first, always. A failed lookup does not become "allowed".
	-- `pool` is resolved now so a future receipt handler rolls the shard the
	-- player actually asked for. The stub below does not roll it.
	local lookupOk, policyInfo = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local decision = PaidRollPolicy.evaluate(if lookupOk then policyInfo else nil)
	if not decision.ok then
		return {
			ok = false,
			code = decision.code,
			error = decision.error,
		}
	end

	-- Stub: do not prompt a purchase, do not spend tokens, do not roll.
	return {
		ok = false,
		code = "stub",
		error = "Paid shards are not for sale yet.",
	}
end

function RollService.devGrant(player: Player, kind: any)
	if not RunService:IsStudio() then
		return reject("Dev tools only work in Studio.")
	end
	if kind == "tokens" then
		local ok, err = DataService.mutate(player, function(data)
			data.shardTokens = math.min(9999, data.shardTokens + 5)
			return nil
		end)
		if not ok then
			return reject(err or "Could not grant tokens.")
		end
		return { ok = true }
	end
	if kind == "luck" then
		local ok, err = DataService.mutate(player, function(data)
			data.shardLuck = math.min(500, data.shardLuck + 25)
			return nil
		end)
		if not ok then
			return reject(err or "Could not grant luck.")
		end
		return { ok = true }
	end
	if kind == "ascension" then
		local ok, err = DataService.mutate(player, function(data)
			data.ascension = math.min(Pools.MAX_ASCENSION, data.ascension + 1)
			return nil
		end)
		if not ok then
			return reject(err or "Could not raise ascension.")
		end
		return { ok = true }
	end
	return reject("Unknown dev grant.")
end

return RollService
