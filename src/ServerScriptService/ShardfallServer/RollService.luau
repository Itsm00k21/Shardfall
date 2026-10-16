--!strict

--[[
	Server-authoritative shard rolls.

	The client sends a pool id and, when Quick Roll is on, a skip flag.
	This module checks the cooldown, reads luck from the saved profile,
	draws with Random.new, updates pity, and saves the item. The client
	never picks the shard.

	rollFree spends one shard token. rollPaid spends one Prism Token after
	the cached policy check and the paid-luck kill switch. Neither charges
	Robux. buyPrismPack and buyLuckBoost are the Robux stubs.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Currencies = require(ReplicatedStorage.Shared.Currencies)
local Materials = require(ReplicatedStorage.Shared.Materials)
local Pools = require(ReplicatedStorage.Shared.Pools)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Schema = require(ReplicatedStorage.Shared.Schema)
local DataService = require(script.Parent.DataService)
local PolicyCache = require(script.Parent.PolicyCache)

local RollService = {}

local lastRoll: { [number]: number } = {}
local announcementsBound = false

local function reject(message: string)
	return { ok = false, error = message }
end

-- Roblox Random. The outcome never comes from math.random or the client.
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

local function announceRemote(): RemoteEvent?
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder == nil then
		return nil
	end
	local remote = folder:FindFirstChild("RollAnnounce")
	if remote ~= nil and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

local function broadcast(name: string, shard: string, rarity: string, crossServer: boolean)
	local remote = announceRemote()
	if remote == nil then
		return
	end
	remote:FireAllClients({
		text = string.format("%s rolled %s (%s)", name, shard, rarity),
		rarity = rarity,
		crossServer = crossServer,
	})
end

local function publishMythic(name: string, shard: string, rarity: string)
	local ok, err = pcall(function()
		local MessagingService = game:GetService("MessagingService")
		MessagingService:PublishAsync(
			RarityConfig.TOPIC,
			HttpService:JSONEncode({
				jobId = game.JobId,
				name = name,
				shard = shard,
				rarity = rarity,
			})
		)
	end)
	if not ok then
		warn("[Roll] cross-server announce failed: " .. tostring(err))
	end
end

function RollService.bindAnnouncements()
	if announcementsBound then
		return
	end
	announcementsBound = true
	local ok, err = pcall(function()
		local MessagingService = game:GetService("MessagingService")
		MessagingService:SubscribeAsync(RarityConfig.TOPIC, function(message)
			local payload = message.Data
			if type(payload) == "string" then
				local decoded, data = pcall(function()
					return HttpService:JSONDecode(payload)
				end)
				payload = if decoded then data else nil
			end
			if type(payload) ~= "table" then
				return
			end
			if payload.jobId == game.JobId then
				return
			end
			broadcast(
				tostring(payload.name or "Someone"),
				tostring(payload.shard or "a shard"),
				tostring(payload.rarity or "Mythic"),
				true
			)
		end)
	end)
	if not ok then
		warn("[Roll] mythic announce subscribe failed: " .. tostring(err))
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastRoll[player.UserId] = nil
end)

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

local function crack(player: Player, poolId: any, currency: string, skip: boolean)
	local pool = poolFromClient(poolId)
	if pool == nil then
		return reject("Unknown shard.")
	end
	if currency == Currencies.PRISM and not RarityConfig.PAID_LUCK_ENABLED then
		return reject(RarityConfig.PAID_OFF_MESSAGE)
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

	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	local policyOk = false
	local paidAllowed = PolicyCache.allowPaid(player)
	policyOk = paidAllowed == true
	local entitled = RarityConfig.quickEntitled(profile, os.time())
	local quick = skip == true
		and RarityConfig.quickAllowed(policyOk, RarityConfig.PAID_LUCK_ENABLED, entitled)
	local previous = lastRoll[player.UserId]
	local waitFor = RarityConfig.cooldown(quick)
	if previous ~= nil and os.clock() - previous < waitFor then
		return reject("Roll cooling down.")
	end

	local captured: any = nil
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
		local rng = serverRng()
		local luck = RarityConfig.luckFromProfile(data)
		local counters = {
			sinceEpic = data.sinceEpic,
			sinceLegendary = data.sinceLegendary,
		}
		local rarity, pityTriggered, floor = RarityConfig.pick(pool, luck, counters, rng)
		local entry = RarityConfig.chooseEntry(pool, rarity, rng)
		if type(entry) ~= "table" or type(entry.templateId) ~= "string" then
			return "That shard has nothing to roll."
		end
		local fillerSeed = rng:nextInteger(1, 2147483646)
		local item = RollMath.mint(entry.templateId, {
			uid = HttpService:GenerateGUID(false),
			now = os.time(),
			poolId = pool.id,
		}, rng)
		Schema.insertItem(data, item)
		RarityConfig.advance(counters, item.rarity, floor)
		data.sinceEpic = counters.sinceEpic
		data.sinceLegendary = counters.sinceLegendary
		data.shardRolls = math.min(1000000000, (data.shardRolls or 0) + 1)
		local bucket = Schema.pityBucket(data, pool.id)
		if Rarities.isLegendaryOrBetter(item.rarity) then
			bucket.rollsSinceLegendary = 0
		else
			bucket.rollsSinceLegendary += 1
		end
		bucket.totalRolls += 1
		captured = {
			item = item,
			pityTriggered = pityTriggered,
			rarity = item.rarity,
			fillerSeed = fillerSeed,
			luck = luck,
			rollIndex = data.shardRolls,
			sinceEpic = data.sinceEpic,
			sinceLegendary = data.sinceLegendary,
		}
		return nil
	end)
	if not ok or captured == nil then
		return reject(err or "Could not crack that shard.")
	end
	lastRoll[player.UserId] = os.clock()
	local reveal = RarityConfig.reveal(captured.rarity, quick)
	if reveal.announce then
		broadcast(player.Name, captured.item.name, captured.rarity, false)
	end
	if reveal.crossServer then
		publishMythic(player.Name, captured.item.name, captured.rarity)
	end
	return {
		ok = true,
		item = captured.item,
		shardId = captured.item.templateId,
		rarity = captured.rarity,
		rollIndex = captured.rollIndex,
		fillerSeed = captured.fillerSeed,
		luck = captured.luck,
		quick = quick,
		pityTriggered = captured.pityTriggered,
		pity = {
			sinceEpic = captured.sinceEpic,
			sinceLegendary = captured.sinceLegendary,
			epicAt = RarityConfig.EPIC_PITY,
			legendaryAt = RarityConfig.LEGENDARY_PITY,
			shardRolls = captured.rollIndex,
		},
		currency = currency,
	}
end

function RollService.rollFree(player: Player, poolId: any, skip: any)
	return crack(player, poolId, Currencies.SHARD, skip == true)
end

function RollService.rollPaid(player: Player, poolId: any, skip: any)
	return crack(player, poolId, Currencies.PRISM, skip == true)
end

function RollService.setShake(player: Player, enabled: boolean)
	local ok, err = DataService.mutate(player, function(data)
		data.shake = enabled == true
		return nil
	end)
	if not ok then
		return reject(err or "Could not save the shake setting.")
	end
	return { ok = true }
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
	if not RarityConfig.PAID_LUCK_ENABLED then
		return reject(RarityConfig.PAID_OFF_MESSAGE)
	end
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
	if kind == "quick" then
		local ok, err = DataService.mutate(player, function(data)
			data.quickRoll = data.quickRoll ~= true
			return nil
		end)
		if not ok then
			return reject(err or "Could not toggle Quick Roll.")
		end
		return { ok = true }
	end
	if kind == "vip" then
		local ok, err = DataService.mutate(player, function(data)
			data.vip = data.vip ~= true
			return nil
		end)
		if not ok then
			return reject(err or "Could not toggle VIP.")
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
