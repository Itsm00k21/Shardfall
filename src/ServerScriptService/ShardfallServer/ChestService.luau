--!strict

--[[
	Server-authoritative chests.

	The client sends a tier and a count. This module checks ownership, spends
	the chest, applies luck from the saved profile, honors pity, and draws
	with Random.new. Duplicates become Shard Dust. Mythic chests wait for
	the player to pick one of three cards the server already rolled.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChestConfig = require(ReplicatedStorage.Shared.ChestConfig)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local DataService = require(script.Parent.DataService)
local PolicyCache = require(script.Parent.PolicyCache)
local RollService = require(script.Parent.RollService)

local ChestService = {}

local function reject(message: string)
	return { ok = false, error = message }
end

local function serverRng()
	local rng = Random.new()
	return {
		nextNumber = function(_self)
			return rng:NextNumber()
		end,
		nextInteger = function(_self, minimum: number, maximum: number)
			return rng:NextInteger(minimum, maximum)
		end,
	}
end

local function uid(): string
	return HttpService:GenerateGUID(false)
end

local function publicChest(result: any)
	if type(result) ~= "table" or result.ok ~= true then
		return nil
	end
	local rows = {}
	for _, drop in ipairs(result.results or {}) do
		table.insert(rows, {
			kind = drop.kind,
			rarity = drop.rarity,
			name = drop.name,
			templateId = drop.templateId,
			uid = drop.uid,
			dust = drop.dust,
			materialId = drop.materialId,
			materialCount = drop.materialCount,
			stars = drop.stars,
			fillerSeed = drop.fillerSeed,
			pity = drop.pity == true,
		})
	end
	return {
		tier = result.tier,
		results = rows,
		pending = result.pending,
		bestIndex = result.bestIndex,
		luck = result.luck,
		seconds = ChestConfig.OPEN_SECONDS[result.tier],
		reelSeconds = ChestConfig.REEL_SECONDS[result.tier],
	}
end

local function announce(player: Player, result: any)
	if type(result) ~= "table" or type(result.announces) ~= "table" then
		return
	end
	for _, row in ipairs(result.announces) do
		RollService.announceDrop(player.Name, row.name, row.rarity, row.crossServer == true)
	end
end

local function finish(player: Player, result: any)
	if type(result) ~= "table" then
		return reject("Could not open that chest.")
	end
	if result.ok ~= true then
		return reject(result.error or "Could not open that chest.")
	end
	announce(player, result)
	return {
		ok = true,
		chest = publicChest(result),
	}
end

function ChestService.open(player: Player, tier: any, count: any)
	if type(tier) ~= "string" or ChestConfig.FLOOR[tier] == nil then
		return reject("Unknown chest.")
	end
	local amount = count
	if type(amount) ~= "number" then
		amount = 1
	end
	local captured = nil
	local ok, err = DataService.mutate(player, function(data)
		captured = ChestConfig.open(data, tier, amount, serverRng(), os.time(), uid)
		if captured.ok ~= true then
			return captured.error or "Could not open that chest."
		end
		return nil
	end)
	if not ok then
		return reject(err or "Could not open that chest.")
	end
	return finish(player, captured)
end

function ChestService.choose(player: Player, index: any)
	if type(index) ~= "number" then
		return reject("Pick one of the three cards.")
	end
	local captured = nil
	local ok, err = DataService.mutate(player, function(data)
		captured = ChestConfig.choose(data, math.floor(index), serverRng(), os.time(), uid)
		if captured.ok ~= true then
			return captured.error or "Could not choose that card."
		end
		return nil
	end)
	if not ok then
		return reject(err or "Could not choose that card.")
	end
	return finish(player, captured)
end

function ChestService.merge(player: Player, tier: any)
	if type(tier) ~= "string" then
		return reject("Unknown chest.")
	end
	local captured = nil
	local ok, err = DataService.mutate(player, function(data)
		local merged, reason = ChestConfig.merge(data, tier)
		if merged == nil then
			return reason or "Could not merge those chests."
		end
		captured = merged
		return nil
	end)
	if not ok or captured == nil then
		return reject(err or "Could not merge those chests.")
	end
	return { ok = true, merge = captured }
end

function ChestService.buy(player: Player, tier: any)
	if type(tier) ~= "string" or not ChestConfig.forSale(tier) then
		return reject("That chest is not sold.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local bought, reason = ChestConfig.buyWithKeys(data, tier)
		if bought == nil then
			return reason or "Could not buy that chest."
		end
		return nil
	end)
	if not ok then
		return reject(err or "Could not buy that chest.")
	end
	return { ok = true, tier = tier }
end

function ChestService.claimLogin(player: Player)
	local captured = nil
	local ok, err = DataService.mutate(player, function(data)
		local granted, reason = ChestConfig.claimLogin(data, os.time())
		if granted == nil then
			return reason or "Could not claim the daily chest."
		end
		captured = granted
		return nil
	end)
	if not ok or captured == nil then
		return reject(err or "Could not claim the daily chest.")
	end
	return { ok = true, granted = captured }
end

function ChestService.buyDust(player: Player, templateId: any)
	if not LaunchGate.on("extraCurrencies") then
		return reject("That is closed.")
	end
	if type(templateId) ~= "string" then
		return reject("Unknown shard.")
	end
	local captured = nil
	local ok, err = DataService.mutate(player, function(data)
		captured = ChestConfig.buyDustShard(data, templateId, serverRng(), os.time(), uid)
		if captured.ok ~= true then
			return captured.error or "Could not buy that shard."
		end
		return nil
	end)
	if not ok then
		return reject(err or "Could not buy that shard.")
	end
	return {
		ok = true,
		name = captured.name,
		rarity = captured.rarity,
	}
end

function ChestService.buyBundle(player: Player)
	if not LaunchGate.on("chests") then
		return reject("That is closed.")
	end
	if not ChestConfig.PAID_CHESTS_ENABLED then
		return reject(ChestConfig.PAID_OFF_MESSAGE)
	end
	local allowed, reason, code = PolicyCache.allowPaid(player)
	if not allowed then
		return {
			ok = false,
			code = code,
			error = reason or ChestConfig.REGION_MESSAGE,
		}
	end
	return {
		ok = false,
		code = "stub",
		error = ChestConfig.bundlePitch(),
	}
end

function ChestService.setOptions(player: Player, mode: any, salvage: any)
	if not LaunchGate.on("chests") then
		return reject("That is closed.")
	end
	if mode ~= "dust" and mode ~= "star" then
		return reject("Duplicates become dust or a star.")
	end
	if type(salvage) ~= "string" then
		return reject("Unknown salvage rarity.")
	end
	local ok, err = DataService.mutate(player, function(data)
		data.chestDuplicates = mode
		data.chestSalvageBelow = salvage
		ChestConfig.ensure(data)
		return nil
	end)
	if not ok then
		return reject(err or "Could not save chest options.")
	end
	return { ok = true }
end

function ChestService.odds(player: Player, tier: any)
	if type(tier) ~= "string" or ChestConfig.FLOOR[tier] == nil then
		return reject("Unknown chest.")
	end
	local data = DataService.get(player)
	local luck = RarityConfig.luckFromProfile(data)
	return {
		ok = true,
		tier = tier,
		luck = luck,
		lines = ChestConfig.oddsLines(tier, luck),
		pity = ChestConfig.pityLine(data),
		seconds = ChestConfig.OPEN_SECONDS[tier],
	}
end

return ChestService
