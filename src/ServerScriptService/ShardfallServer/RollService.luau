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

local CallBudget = require(ReplicatedStorage.Shared.CallBudget)
local DebugTools = require(ReplicatedStorage.Shared.DebugTools)
local DevAccess = require(ReplicatedStorage.Shared.DevAccess)
local DevTools = require(ReplicatedStorage.Shared.DevTools)
local BigRollBeam = require(ReplicatedStorage.Shared.BigRollBeam)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local Currencies = require(ReplicatedStorage.Shared.Currencies)
local Pools = require(ReplicatedStorage.Shared.Pools)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local RollConfig = require(ReplicatedStorage.Shared.RollConfig)
local RollLoop = require(ReplicatedStorage.Shared.RollLoop)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Schema = require(ReplicatedStorage.Shared.Schema)
local SessionGuide = require(ReplicatedStorage.Shared.SessionGuide)
local GearSalvage = require(ReplicatedStorage.Shared.GearSalvage)
local Settings = require(ReplicatedStorage.Shared.Settings)
local StarterGoalPay = require(ReplicatedStorage.Shared.StarterGoalPay)
local DataService = require(script.Parent.DataService)
local PolicyCache = require(script.Parent.PolicyCache)

local RollService = {}

type LastCrack = { at: number, rarity: string, quick: boolean }

local lastRoll: { [number]: LastCrack } = {}
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

function RollService.announceDrop(name: string, shard: string, rarity: string, crossServer: boolean)
	broadcast(name, shard, rarity, crossServer)
	if crossServer then
		publishMythic(name, shard, rarity)
	end
end

function RollService.bindAnnouncements()
	if announcementsBound then
		return
	end
	announcementsBound = true
	-- SubscribeAsync can hang in Studio when API access is off. The budget
	-- returns so boot can continue; mythic announces stay on this server.
	local ok, err = CallBudget.run(CallBudget.DATASTORE_SECONDS, function()
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
	BigRollBeam.forget(player.UserId)
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

-- [ECHO hook] gearLevels. Off: insert as today. On: an exact duplicate
-- spends no Bag slot and feeds Stars (not item.upgrade). ★5 records Essence.
local function gearSpare(data: any): boolean
	if not LaunchGate.on("gearLevels") then
		return false
	end
	local Accept = require(script.Parent.GearLevels.Accept)
	return Accept.spareRoom(data, true)
end

local function gearPlace(data: any, item: any, place: ((any) -> ())?): (any?, string?)
	local insert = place or function(row: any)
		Schema.insertItem(data, row)
	end
	if not LaunchGate.on("gearLevels") then
		insert(item)
		return nil, nil
	end
	local Accept = require(script.Parent.GearLevels.Accept)
	local GearLevels = require(ReplicatedStorage.Shared.Config.GearLevels)
	local Stars = require(ReplicatedStorage.Shared.Stars)
	local landing = Accept.accept(data, item, true, GearLevels, nil, Stars)
	if landing.merged ~= true then
		if Schema.countItems(data) >= Schema.inventoryCap(data) then
			return nil, "Inventory is full."
		end
		insert(landing.item)
	end
	return landing, nil
end

local function attachGear(payload: { [string]: any }, drawn: any)
	if type(drawn) ~= "table" or drawn.merged ~= true then
		return
	end
	payload.oldLevel = drawn.oldLevel
	payload.newLevel = drawn.newLevel
	payload.essence = drawn.essence
	payload.levelText = drawn.levelText
	payload.merged = true
end

-- Lowest pool rarity that is still at or above the guide floor.
-- present() is high to low, so the last match is the cheapest raise.
local function atLeast(pool: any, floorName: string): string?
	local need = Rarities.INDEX[floorName]
	if type(need) ~= "number" then
		return nil
	end
	local best = nil
	for _, name in ipairs(RarityConfig.present(pool)) do
		if Rarities.rank(name) >= need then
			best = name
		end
	end
	return best
end

-- One draw on an already-paid crack: pick a rarity with pity, mint the
-- item, save it and move the counters. The caller has spent the tokens
-- and checked the Bag. guideFloor is the server Rare floor for roll3.
-- Returns the capture, or nil and a reason.
local function drawInto(data: any, pool: any, rng: any, guideFloor: string?): (any?, string?)
	local luck = RarityConfig.luckFromProfile(data)
	-- Legendary pity only. A saved sinceEpic is left untouched.
	local counters = {
		sinceLegendary = data.sinceLegendary,
	}
	local rarity, pityTriggered, floor = RarityConfig.pick(pool, luck, counters, rng)
	if type(guideFloor) == "string" then
		local wanted = SessionGuide.floorRarity(rarity, guideFloor)
		if wanted ~= rarity then
			local raised = atLeast(pool, wanted)
			if type(raised) == "string" then
				rarity = raised
				floor = raised
			end
		end
	end
	local entry = RarityConfig.chooseEntry(pool, rarity, rng)
	if type(entry) ~= "table" or type(entry.templateId) ~= "string" then
		return nil, "That shard has nothing to roll."
	end
	local fillerSeed = rng:nextInteger(1, 2147483646)
	local item = RollMath.mint(entry.templateId, {
		uid = HttpService:GenerateGUID(false),
		now = os.time(),
		poolId = pool.id,
	}, rng)
	-- [ECHO hook] Stage A merges an exact duplicate first. Auto-salvage (#388)
	-- only sees a new drop that Stage A did not merge.
	local arrival = { kept = true, gained = 0 }
	local landing, placeError = gearPlace(data, item, function(row: any)
		arrival = GearSalvage.receive(data, row)
		if arrival.kept ~= false then
			Schema.insertItem(data, row)
		end
	end)
	if placeError ~= nil then
		return nil, placeError
	end
	if type(landing) == "table" and landing.merged == true and type(landing.item) == "table" then
		item = landing.item
	end
	RarityConfig.advance(counters, item.rarity, floor)
	data.sinceLegendary = counters.sinceLegendary
	data.shardRolls = math.min(1000000000, (data.shardRolls or 0) + 1)
	StarterGoalPay.grant(data, "rolls", nil)
	-- The per-pool pity bucket is an old save field. The live counter is
	-- sinceLegendary. Do not increment the bucket.
	local captured = {
		item = item,
		pityTriggered = pityTriggered,
		rarity = item.rarity,
		fillerSeed = fillerSeed,
		luck = luck,
		rollIndex = data.shardRolls,
		sinceLegendary = data.sinceLegendary,
		tracker = StarterGoalPay.tracker(data),
	}
	attachGear(captured, landing)
	if arrival.kept == false then
		captured.autoSalvaged = true
		captured.essenceGained = arrival.gained
	end
	return captured
end

local function shownName(player: Player): string
	local display = player.DisplayName
	if type(display) == "string" and display ~= "" then
		return display
	end
	return player.Name
end

-- Server character only. A missing root falls back to the Crackstone.
local function flatPosition(player: Player): (number?, number?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or root:IsA("BasePart") == false then
		return nil, nil
	end
	return root.Position.X, root.Position.Z
end

-- Flag off returns before any roll is queued. The rarity is the one this
-- server just drew. pool id and the skip flag never pick the tier.
local function considerBigRoll(
	player: Player,
	itemName: any,
	rarity: any,
	count: number,
	epicCount: number,
	quick: boolean
)
	if not LaunchGate.on("bigRollBeam") then
		return
	end
	if type(itemName) ~= "string" or type(rarity) ~= "string" then
		return
	end
	local x, z = flatPosition(player)
	local fact = BigRollBeam.serverRoll({
		userId = player.UserId,
		displayName = shownName(player),
		itemName = itemName,
		rarity = rarity,
		count = count,
		epicCount = epicCount,
		quick = quick,
		x = x,
		z = z,
	})
	if fact == nil then
		return
	end
	BigRollBeam.offer(fact, os.clock())
end

local function noteBigBatch(player: Player, captures: { any })
	if not LaunchGate.on("bigRollBeam") then
		return
	end
	local best = nil
	local count = 0
	local epicCount = 0
	for _, drawn in ipairs(captures) do
		local rarity = drawn.rarity
		if type(rarity) ~= "string" or BigRollBeam.qualifies(rarity) ~= true then
			continue
		end
		count += 1
		if Rarities.rank(rarity) < Rarities.rank("Legendary") then
			epicCount += 1
		end
		if best == nil or Rarities.rank(rarity) > Rarities.rank(best.rarity) then
			best = drawn
		end
	end
	if best == nil or type(best.item) ~= "table" then
		return
	end
	considerBigRoll(player, best.item.name, best.rarity, count, epicCount, true)
end

local function crack(
	player: Player,
	poolId: any,
	currency: string,
	skip: boolean,
	ignoreCooldown: boolean?
)
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
	local settings = Settings.normalize(profile.uiSettings)
	local waitFor = RollLoop.gap(
		settings,
		if previous ~= nil then previous.rarity else nil,
		if previous ~= nil then previous.quick else false,
		quick
	)
	if ignoreCooldown ~= true and previous ~= nil and os.clock() - previous.at < waitFor then
		return reject("Roll cooling down.")
	end

	local captured: any = nil
	local guideFree = false
	local ok, err = DataService.mutate(player, function(data)
		if not Pools.isUnlocked(pool, data.ascension) then
			return string.format("Reach Ascension %d to roll %s.", pool.ascension, pool.name)
		end
		-- Bag room is checked before anything is spent.
		-- [ECHO hook] A full bag can still take an exact duplicate.
		if Schema.countItems(data) >= Schema.inventoryCap(data) then
			if not gearSpare(data) then
				return "Inventory is full."
			end
		end
		-- R2/R3. Free only when the saved step is roll1, roll2, or roll3.
		-- The step moves in this mutate with the item. No client flag.
		local guideClaim = nil
		if currency == Currencies.SHARD then
			guideClaim = SessionGuide.claimFree(data)
		end
		local guideFloor = if guideClaim ~= nil then guideClaim.floor else nil
		-- A dungeon voucher cracks that area once and does not spend a token.
		-- It is an earned clear, so it never pays for a Prism roll.
		-- A guide roll does not spend the voucher either.
		local usedVoucher = false
		if guideClaim == nil and currency == Currencies.SHARD then
			local area = (pool :: any).area
			if type(area) == "string" and type(data.vouchers) == "table" then
				local stack = data.vouchers[area]
				if type(stack) == "number" and stack >= 1 then
					data.vouchers[area] = stack - 1
					usedVoucher = true
				end
			end
		end
		if guideClaim == nil and not usedVoucher then
			local spent, spendError = Currencies.take(data, currency)
			if not spent then
				return spendError or "You cannot pay for that crack."
			end
		end
		local drawn, drawError = drawInto(data, pool, serverRng(), guideFloor)
		if drawn == nil then
			return drawError
		end
		if type(guideFloor) == "string" and Rarities.INDEX[guideFloor] ~= nil then
			if Rarities.rank(drawn.rarity) < Rarities.rank(guideFloor) then
				return "Could not crack that shard."
			end
		end
		if guideClaim ~= nil then
			guideFree = true
		end
		captured = drawn
		return nil
	end)
	if not ok or captured == nil then
		return reject(err or "Could not crack that shard.")
	end
	lastRoll[player.UserId] = {
		at = os.clock(),
		rarity = if type(captured.rarity) == "string" then captured.rarity else "",
		quick = quick,
	}
	local reveal = RarityConfig.reveal(captured.rarity, quick)
	if reveal.announce then
		broadcast(player.Name, captured.item.name, captured.rarity, false)
	end
	if reveal.crossServer then
		publishMythic(player.Name, captured.item.name, captured.rarity)
	end
	local epicCount = if captured.rarity == "Epic" then 1 else 0
	considerBigRoll(player, captured.item.name, captured.rarity, 1, epicCount, quick)
	local result = {
		ok = true,
		item = captured.item,
		rollId = captured.item.uid,
		shardId = captured.item.templateId,
		rarity = captured.rarity,
		rollIndex = captured.rollIndex,
		fillerSeed = captured.fillerSeed,
		luck = captured.luck,
		quick = quick,
		pityTriggered = captured.pityTriggered,
		pity = {
			sinceLegendary = captured.sinceLegendary,
			legendaryAt = RarityConfig.LEGENDARY_PITY,
			shardRolls = captured.rollIndex,
			left = RollConfig.pityLeft(captured.sinceLegendary),
		},
		currency = currency,
		starterGoalTracker = captured.tracker,
	}
	if guideFree then
		result.guideFree = true
	end
	attachGear(result, captured)
	return result
end

function RollService.rollFree(player: Player, poolId: any, skip: any)
	return crack(player, poolId, Currencies.SHARD, skip == true)
end

local function pityView(drawn: any)
	return {
		sinceLegendary = drawn.sinceLegendary,
		legendaryAt = RarityConfig.LEGENDARY_PITY,
		shardRolls = drawn.rollIndex,
		left = RollConfig.pityLeft(drawn.sinceLegendary),
	}
end

-- x10: one press, one discounted charge (RollConfig.cost), ten draws, all
-- inside one profile mutate. The price and the Bag room are checked before
-- anything is spent, and if any draw fails the whole batch rolls back, so
-- the player never pays for cracks that did not land. Vouchers stay for
-- single cracks. The server decides every result here; the client only
-- plays the reveal, and skipping it never changes what was granted.
local function crackBatch(player: Player, poolId: any, total: number)
	local pool = poolFromClient(poolId)
	if pool == nil then
		return reject("Unknown shard.")
	end
	if DataService.get(player) == nil then
		return reject("Profile is still loading.")
	end
	local price = RollConfig.cost(total)
	local captures: { any } = {}
	local ok, err = DataService.mutate(player, function(data)
		if not Pools.isUnlocked(pool, data.ascension) then
			return string.format("Reach Ascension %d to roll %s.", pool.ascension, pool.name)
		end
		local free = Schema.inventoryCap(data) - Schema.countItems(data)
		-- [ECHO hook] Tokens still block. A duplicate does not need a free slot.
		if gearSpare(data) then
			free = math.max(free, total)
		end
		local blocked = RollConfig.batchBlock(data.shardTokens, free, total)
		if blocked ~= nil then
			return blocked
		end
		-- Guide rolls 1-3 are the free single crack. x10 does not spend.
		local note = SessionGuide.batchNotice(data)
		if note ~= nil then
			return note
		end
		data.shardTokens -= price
		local rng = serverRng()
		for _ = 1, total do
			local drawn, drawError = drawInto(data, pool, rng)
			if drawn == nil then
				return drawError or "Could not crack that shard."
			end
			table.insert(captures, drawn)
		end
		return nil
	end)
	if not ok or #captures ~= total then
		local message = if type(err) == "string" then err else "Could not crack that shard."
		if message == SessionGuide.FREE_ROLL_NOTICE then
			return {
				ok = false,
				error = message,
				notice = message,
			}
		end
		return reject(message)
	end
	local items = {}
	local best = 1
	for index, drawn in ipairs(captures) do
		local row = {
			item = drawn.item,
			rollId = drawn.item.uid,
			rarity = drawn.rarity,
			fillerSeed = drawn.fillerSeed,
			pityTriggered = drawn.pityTriggered,
			pity = pityView(drawn),
		}
		attachGear(row, drawn)
		table.insert(items, row)
		if Rarities.rank(drawn.rarity) > Rarities.rank(captures[best].rarity) then
			best = index
		end
		local reveal = RarityConfig.reveal(drawn.rarity, true)
		if reveal.announce then
			broadcast(player.Name, drawn.item.name, drawn.rarity, false)
		end
		if reveal.crossServer then
			publishMythic(player.Name, drawn.item.name, drawn.rarity)
		end
	end
	noteBigBatch(player, captures)
	local last = captures[#captures]
	lastRoll[player.UserId] = {
		at = os.clock(),
		rarity = if type(last.rarity) == "string" then last.rarity else "",
		quick = true,
	}
	local tracker = last.tracker
	return {
		ok = true,
		items = items,
		count = #items,
		best = best,
		cost = price,
		saved = RollConfig.savings(total),
		pity = pityView(last),
		stopped = nil,
		currency = Currencies.SHARD,
		starterGoalTracker = tracker,
	}
end

-- Same clock crack() uses. rollMany used to skip it: x10 never looked,
-- and any other count passes ignoreCooldown into every crack. Two invokes
-- in one moment then spent twice and granted twice.
local function rollCooling(player: Player, quick: boolean): boolean
	local profile = DataService.get(player)
	local previous = lastRoll[player.UserId]
	if profile == nil or previous == nil then
		return false
	end
	local settings = Settings.normalize(profile.uiSettings)
	local waitFor = RollLoop.gap(settings, previous.rarity, previous.quick, quick)
	return os.clock() - previous.at < waitFor
end

-- One request, up to ten cracks. Exactly RollConfig.MULTI_COUNT is the
-- discounted x10 batch above. Any other count cracks one at a time, each
-- spending the way a single Roll does: a voucher covers one, then a Shard
-- Token. A later crack that cannot pay keeps the ones already saved.
function RollService.rollMany(player: Player, poolId: any, count: any)
	local total = count
	if type(total) ~= "number" or total ~= total or total == math.huge then
		return reject("Roll 1 to 10 shards.")
	end
	total = math.floor(total)
	if total < 1 or total > RollConfig.MAX_BATCH then
		return reject("Roll 1 to 10 shards.")
	end
	local quick = total == RollConfig.MULTI_COUNT
	if rollCooling(player, quick) then
		return reject("Roll cooling down.")
	end
	if total == RollConfig.MULTI_COUNT then
		local note = SessionGuide.batchNotice(DataService.get(player))
		if type(note) == "string" then
			return {
				ok = false,
				error = note,
				notice = note,
			}
		end
		return crackBatch(player, poolId, total)
	end
	local items = {}
	local stopped: string? = nil
	local lastPity: any = nil
	local tracker: any = nil
	for _ = 1, total do
		local result = crack(player, poolId, Currencies.SHARD, false, true)
		if type(result) ~= "table" or result.ok ~= true then
			local reason = if type(result) == "table" and type(result.error) == "string"
				then result.error
				else "Could not crack that shard."
			if #items == 0 then
				return if type(result) == "table" then result else reject(reason)
			end
			stopped = reason
			break
		end
		local row = {
			item = result.item,
			rollId = result.rollId,
			rarity = result.rarity,
			fillerSeed = result.fillerSeed,
			pity = result.pity,
		}
		attachGear(row, result)
		table.insert(items, row)
		lastPity = result.pity
		tracker = result.starterGoalTracker
	end
	return {
		ok = true,
		items = items,
		count = #items,
		pity = lastPity,
		stopped = stopped,
		currency = Currencies.SHARD,
		starterGoalTracker = tracker,
	}
end

function RollService.rollPaid(player: Player, poolId: any, skip: any)
	if not LaunchGate.on("paid") then
		return reject("That is closed.")
	end
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
	if not LaunchGate.on("paid") then
		return reject("That is closed.")
	end
	return paidStub(player, Currencies.packPitch())
end

function RollService.buyLuckBoost(player: Player)
	if not LaunchGate.on("paid") then
		return reject("That is closed.")
	end
	if not RarityConfig.PAID_LUCK_ENABLED then
		return reject(RarityConfig.PAID_OFF_MESSAGE)
	end
	local profile = DataService.get(player)
	local active = if profile ~= nil then profile.luckBoost else 0
	return paidStub(player, Currencies.boostPitch(active))
end

function RollService.buyForgeBoost(player: Player)
	if not LaunchGate.on("paid") then
		return reject("That is closed.")
	end
	local profile = DataService.get(player)
	local untilTime = if profile ~= nil then profile.forgeBoostUntil else 0
	return paidStub(player, Currencies.forgeBoostPitch(untilTime, os.time()))
end

function RollService.buyInventoryExpansion(player: Player)
	if not LaunchGate.on("paid") then
		return reject("That is closed.")
	end
	local profile = DataService.get(player)
	local bonus = if profile ~= nil then profile.inventoryBonus else 0
	return paidStub(player, Currencies.inventoryPitch(bonus))
end

-- Owner-only Dev Tools grants. The profile change and its toast line
-- live in DebugTools.grant; a kind whose system is parked is refused
-- with DevTools.offMessage instead of changing a hidden balance.
function RollService.devGrant(player: Player, kind: any)
	if not RunService:IsStudio() then
		return reject("Dev tools only work in Studio.")
	end
	if not DevAccess.player(player) then
		return reject(DevAccess.DENIED)
	end
	if type(kind) ~= "string" then
		return reject("Unknown dev grant.")
	end
	local off = DevTools.blocked("DevGrant", kind)
	if off ~= nil then
		return reject(off)
	end
	if kind == "restrict" then
		local view = PolicyCache.public(player)
		local nextRestricted = view.simulated ~= true
		if not PolicyCache.setSimulatedRestriction(player, nextRestricted) then
			return reject("Dev tools only work in Studio.")
		end
		return {
			ok = true,
			simulated = nextRestricted,
			message = if nextRestricted
				then "Region lock simulated ON (restricted-region rules apply)."
				else "Region lock simulated OFF.",
		}
	end
	local message = ""
	local ok, err = DataService.mutate(player, function(data)
		local applied, text = DebugTools.grant(data, kind, os.time())
		if not applied then
			return text
		end
		message = text
		return nil
	end)
	if not ok then
		return reject(err or "Could not grant that.")
	end
	return { ok = true, message = message }
end

local function pushBigRoll(payload: any)
	local remote = announceRemote()
	if remote == nil or type(payload) ~= "table" then
		return
	end
	remote:FireAllClients(payload)
end

RunService.Heartbeat:Connect(function()
	BigRollBeam.pump(os.clock(), pushBigRoll)
end)

return RollService
