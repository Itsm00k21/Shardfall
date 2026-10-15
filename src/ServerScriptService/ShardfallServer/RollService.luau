--!strict

--[[
	Server-authoritative shard rolls.

	rollFree spends one shard token and rolls with RollMath. The client only
	sends a pool id. The item, the pity update, and the token spend happen
	inside DataService.mutate, which rolls back if anything fails.

	rollPaid spends one Prism Token after the cached policy check. It does
	not charge Robux. buyPrismPack and buyLuckBoost are the Robux stubs:
	they show the numeric offer, then refuse. Wire developer products there
	later, and only after PolicyCache.allowPaid returns true.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Currencies = require(ReplicatedStorage.Shared.Currencies)
local Materials = require(ReplicatedStorage.Shared.Materials)
local Pools = require(ReplicatedStorage.Shared.Pools)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Schema = require(ReplicatedStorage.Shared.Schema)
local DataService = require(script.Parent.DataService)
local PolicyCache = require(script.Parent.PolicyCache)

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

local function crack(player: Player, poolId: any, currency: string)
	local pool = poolFromClient(poolId)
	if pool == nil then
		return reject("Unknown shard.")
	end
	if currency == Currencies.PRISM then
		local allowed, reason, code = PolicyCache.allowPaid(player)
		if not allowed then
			return {
				ok = false,
				code = code,
				error = reason,
			}
		end
	end

	local captured: any = nil
	local pityAfter: any = nil
	local ok, err = DataService.mutate(player, function(data)
		if not Pools.isUnlocked(pool, data.ascension) then
			return string.format("Reach Ascension %d to roll %s.", pool.ascension, pool.name)
		end
		-- A dungeon voucher cracks that area once and does not spend a token.
		-- It is an earned clear, so it never pays for a Prism roll.
		local usedVoucher = false
		if currency == Currencies.SHARD then
			local area = (pool :: any).area
			if type(area) == "string" and type(data.vouchers) == "table" then
				local stack = data.vouchers[area]
				if type(stack) == "number" and stack >= 1 then
					data.vouchers[area] = stack - 1
					usedVoucher = true
				end
			end
		end
		if not usedVoucher then
			local spent, spendError = Currencies.take(data, currency)
			if not spent then
				return spendError or "You cannot pay for that crack."
			end
		end
		if Schema.countItems(data) >= Schema.inventoryCap(data) then
			return "Inventory is full."
		end
		local pity = Schema.pityBucket(data, pool.id)
		local result = RollMath.roll(pool, pity, {
			luck = Currencies.effectiveLuck(data.shardLuck, data.luckBoost),
			-- GenerateGUID does not need HttpService.HttpEnabled.
			uid = HttpService:GenerateGUID(false),
			now = os.time(),
		}, RollMath.defaultRng())
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
		currency = currency,
	}
end

function RollService.rollFree(player: Player, poolId: any)
	return crack(player, poolId, Currencies.SHARD)
end

function RollService.rollPaid(player: Player, poolId: any)
	return crack(player, poolId, Currencies.PRISM)
end

local function paidStub(player: Player, pitch: string)
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
		error = pitch,
	}
end

function RollService.buyPrismPack(player: Player)
	return paidStub(player, Currencies.packPitch())
end

function RollService.buyLuckBoost(player: Player)
	local profile = DataService.get(player)
	local active = if profile ~= nil then profile.luckBoost else 0
	return paidStub(player, Currencies.boostPitch(active))
end

function RollService.buyForgeBoost(player: Player)
	local profile = DataService.get(player)
	local untilTime = if profile ~= nil then profile.forgeBoostUntil else 0
	return paidStub(player, Currencies.forgeBoostPitch(untilTime, os.time()))
end

function RollService.buyInventoryExpansion(player: Player)
	local profile = DataService.get(player)
	local bonus = if profile ~= nil then profile.inventoryBonus else 0
	return paidStub(player, Currencies.inventoryPitch(bonus))
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
	if kind == "prisms" then
		local ok, err = DataService.mutate(player, function(data)
			data.prismTokens = math.min(9999, data.prismTokens + 5)
			return nil
		end)
		if not ok then
			return reject(err or "Could not grant Prism Tokens.")
		end
		return { ok = true }
	end
	if kind == "boost" then
		local ok, err = DataService.mutate(player, function(data)
			data.luckBoost = Currencies.LUCK_BOOST
			return nil
		end)
		if not ok then
			return reject(err or "Could not grant a Luck Boost.")
		end
		return { ok = true }
	end
	if kind == "restrict" then
		local view = PolicyCache.public(player)
		local nextRestricted = view.simulated ~= true
		if not PolicyCache.setSimulatedRestriction(player, nextRestricted) then
			return reject("Dev tools only work in Studio.")
		end
		return { ok = true, simulated = nextRestricted }
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
	if kind == "forgeboost" then
		local ok, err = DataService.mutate(player, function(data)
			data.forgeBoostUntil = os.time() + Currencies.FORGE_BOOST_SECONDS
			return nil
		end)
		if not ok then
			return reject(err or "Could not grant a Forge Boost.")
		end
		return { ok = true }
	end
	if kind == "materials" then
		local ok, err = DataService.mutate(player, function(data)
			local bundle = {
				wood = 8,
				vine = 8,
				spore = 6,
				bark = 4,
				heartwood = 2,
				verdant_bark = 12,
				gnarl_seed = 1,
				scroll_thornbound = 1,
			}
			for materialId, count in pairs(bundle) do
				Materials.add(data.materials, materialId, count)
			end
			return nil
		end)
		if not ok then
			return reject(err or "Could not grant materials.")
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
