--!strict

--[[
	E-008. M1 economy invariants.

	RollShard, BuyGoldShop, and UpgradeGear spend inside DataService.mutate.
	This harness calls the same modules in that order. A string or a throw
	from the mutator puts the deep copy back, which is what mutate does.
	Nothing under src/ changes here. A real bug is left out of the run and
	named in a comment above that case.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Currencies = require("../src/ReplicatedStorage/Shared/Currencies")
local Economy = require("../src/ReplicatedStorage/Shared/Economy")
local GoldShop = require("../src/ReplicatedStorage/Shared/GoldShop")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local RollHype = require("../src/ReplicatedStorage/Shared/RollHype")
local RollLoop = require("../src/ReplicatedStorage/Shared/RollLoop")
local RollMath = require("../src/ReplicatedStorage/Shared/RollMath")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local ShardBoard = require("../src/ReplicatedStorage/Shared/ShardBoard")
local StarterGoalPay = require("../src/ReplicatedStorage/Shared/StarterGoalPay")
local UiRouter = require("../src/ReplicatedStorage/Shared/UiRouter")

-- +1 and +2 are flat. From +3 the cost is floor(500 * 1.6 ^ level + 0.5),
-- where level is the upgrade already on the item. +8, +9, and +10 each
-- spend one Gnarl's Seed. These integers are that table.
local FORGE = {
	{ level = 0, gold = 150, seed = 0 },
	{ level = 1, gold = 300, seed = 0 },
	{ level = 2, gold = 1280, seed = 0 },
	{ level = 3, gold = 2048, seed = 0 },
	{ level = 4, gold = 3277, seed = 0 },
	{ level = 5, gold = 5243, seed = 0 },
	{ level = 6, gold = 8389, seed = 0 },
	{ level = 7, gold = 13422, seed = 1 },
	{ level = 8, gold = 21475, seed = 1 },
	{ level = 9, gold = 34360, seed = 1 },
}

local POOL = "verdant_armory"
local BLADE = "blade"

type Stamp = {
	at: number,
	rarity: string,
	quick: boolean,
}

type Call = {
	ok: boolean,
	error: string?,
	item: any?,
	note: string?,
	pity: any?,
}

local serial = 0

local function nextUid(): string
	serial += 1
	return string.format("roll-%d", serial)
end

local function steadyRng(unit: number)
	return {
		nextNumber = function(_self): number
			return unit
		end,
		nextInteger = function(_self, minValue: number, _maxValue: number): number
			return minValue
		end,
	}
end

local function restore(data, backup)
	local keys = {}
	for key in pairs(data) do
		table.insert(keys, key)
	end
	for _, key in ipairs(keys) do
		data[key] = nil
	end
	for key, value in pairs(backup) do
		data[key] = value
	end
end

-- DataService.mutate: backup, run, put the backup back when the mutator
-- returns a reason or throws. The live table keeps its identity.
local function mutate(data, mutator: (any) -> string?): (boolean, string?)
	local backup = Schema.deepCopy(data)
	local ok, result = pcall(mutator, data)
	if not ok or result ~= nil then
		restore(data, backup)
		if not ok then
			return false, "Could not update your profile."
		end
		return false, result
	end
	return true, nil
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

local function fail(message: string): Call
	return { ok = false, error = message }
end

-- RollShard. skip stays false, so this is a Shard Token crack. rng defaults
-- to a common draw so a burst does not depend on chance. ignoreCooldown is
-- only for the inner cracks of RollShards; RollShard leaves it false.
local function rollShard(
	data,
	poolId: any,
	now: number,
	previous: Stamp?,
	rng: any?,
	ignoreCooldown: boolean?
): (Call, Stamp?)
	local pool = poolFromClient(poolId)
	if pool == nil then
		return fail("Unknown shard."), previous
	end
	local settings = Settings.normalize(data.uiSettings)
	local waitFor = RollLoop.gap(
		settings,
		if previous ~= nil then previous.rarity else nil,
		if previous ~= nil then previous.quick else false,
		false
	)
	if ignoreCooldown ~= true and previous ~= nil and now - previous.at < waitFor then
		return fail("Roll cooling down."), previous
	end

	local captured: any = nil
	local draw = if rng ~= nil then rng else steadyRng(0.999)
	local saved, err = mutate(data, function(profile)
		if not Pools.isUnlocked(pool, profile.ascension) then
			return string.format("Reach Ascension %d to roll %s.", pool.ascension, pool.name)
		end
		local usedVoucher = false
		local area = (pool :: any).area
		if type(area) == "string" and type(profile.vouchers) == "table" then
			local stack = profile.vouchers[area]
			if type(stack) == "number" and stack >= 1 then
				profile.vouchers[area] = stack - 1
				usedVoucher = true
			end
		end
		if not usedVoucher then
			local spent, spendError = Currencies.take(profile, Currencies.SHARD)
			if not spent then
				return spendError or "You cannot pay for that crack."
			end
		end
		if Schema.countItems(profile) >= Schema.inventoryCap(profile) then
			return "Inventory is full."
		end
		local luck = RarityConfig.luckFromProfile(profile)
		local counters = {
			sinceEpic = profile.sinceEpic,
			sinceLegendary = profile.sinceLegendary,
		}
		local rarity, _pityTriggered, floor = RarityConfig.pick(pool, luck, counters, draw)
		local entry = RarityConfig.chooseEntry(pool, rarity, draw)
		if type(entry) ~= "table" or type(entry.templateId) ~= "string" then
			return "That shard has nothing to roll."
		end
		local item = RollMath.mint(entry.templateId, {
			uid = nextUid(),
			now = 0,
			poolId = pool.id,
		}, draw)
		Schema.insertItem(profile, item)
		RarityConfig.advance(counters, item.rarity, floor)
		profile.sinceEpic = counters.sinceEpic
		profile.sinceLegendary = counters.sinceLegendary
		profile.shardRolls = math.min(1000000000, (profile.shardRolls or 0) + 1)
		StarterGoalPay.grant(profile, "rolls", nil)
		captured = {
			item = item,
			sinceEpic = profile.sinceEpic,
			sinceLegendary = profile.sinceLegendary,
		}
		return nil
	end)
	if not saved or captured == nil then
		return fail(err or "Could not crack that shard."), previous
	end
	local stamp: Stamp = {
		at = now,
		rarity = if type(captured.item.rarity) == "string" then captured.item.rarity else "",
		quick = false,
	}
	return {
		ok = true,
		item = captured.item,
		pity = {
			sinceEpic = captured.sinceEpic,
			sinceLegendary = captured.sinceLegendary,
			epicAt = RarityConfig.EPIC_PITY,
			legendaryAt = RarityConfig.LEGENDARY_PITY,
		},
	},
		stamp
end

local function buyGold(data, offerId: any): Call
	local reason: string? = nil
	local saved, err = mutate(data, function(profile)
		reason = GoldShop.apply(profile, offerId)
		return reason
	end)
	if not saved then
		local message = if type(reason) == "string" then reason else err
		if type(message) ~= "string" or message == "" then
			message = "Could not buy that."
		end
		return fail(message :: string)
	end
	return { ok = true }
end

local function upgradeGear(data, uid: any): Call
	if type(uid) ~= "string" or uid == "" then
		return fail("Pick a piece of gear.")
	end
	local note = ""
	local saved, err = mutate(data, function(profile)
		local item = profile.inventory[uid]
		local upgraded, why = Economy.upgrade(item, profile)
		if not upgraded then
			return why
		end
		note = why
		return nil
	end)
	if not saved then
		return fail(err or "Could not upgrade that.")
	end
	return { ok = true, note = note }
end

local function aboveZero(data)
	expect(type(data.gold) == "number").toBeTrue()
	expect(data.gold >= 0).toBeTrue()
	expect(type(data.shardTokens) == "number").toBeTrue()
	expect(data.shardTokens >= 0).toBeTrue()
end

local function refuses(data, run: () -> Call)
	local before = Schema.deepCopy(data)
	local result = run()
	expect(result.ok).toEqual(false)
	expect(data).toEqual(before)
	aboveZero(data)
end

local function panelPity(counter: any, goal: any): string
	local meter = RollHype.pity(counter, goal)
	local shown = 0
	local shownGoal = 0
	if meter.ok == true and type(meter.goal) == "number" then
		shown = meter.counter
		shownGoal = meter.goal
	end
	return ShardBoard.pityPlace(280, shown, shownGoal).text
end

local function pityLine(counter: number, goal: number): string
	return string.format("Pity %d/%d", counter, goal)
end

local function arm(data, level: number)
	data.inventory[BLADE] = {
		uid = BLADE,
		name = "Thornblade",
		kind = "Weapon",
		upgrade = level,
	}
end

describe("M1 economy invariants", function()
	it("starts a new profile with 10 Shards", function()
		expect(Schema.VERSION).toEqual(26)
		expect(Schema.STARTER_TOKENS).toEqual(10)
		local template = Schema.template()
		expect(template.shardTokens).toEqual(10)
		expect(template.gold).toEqual(0)
		expect(Schema.snapshot(template).shardTokens).toEqual(10)
		local created, err = Schema.migrate(nil)
		expect(err).toBeNil()
		assert(created ~= nil)
		expect(created.shardTokens).toEqual(10)
		expect(created.schemaVersion).toEqual(26)
		local empty, emptyErr = Schema.migrate({})
		expect(emptyErr).toBeNil()
		assert(empty ~= nil)
		expect(empty.shardTokens).toEqual(10)
		expect(Schema.reconcile({}).shardTokens).toEqual(10)
	end)

	it("keeps Gold and Shards at or above 0 when the same calls repeat", function()
		local data = Schema.template()
		local now = 0
		local last: Stamp? = nil
		local spent = 0
		for _ = 1, 15 do
			local before = Schema.deepCopy(data)
			local result, stamp = rollShard(data, POOL, now, last, nil, false)
			last = stamp
			aboveZero(data)
			if result.ok == true then
				spent += 1
				expect(data.shardTokens).toEqual(Schema.STARTER_TOKENS - spent)
			else
				expect(data).toEqual(before)
			end
		end
		expect(spent).toEqual(1)
		expect(data.shardTokens).toEqual(9)

		for _ = 1, 12 do
			now += 5
			local before = Schema.deepCopy(data)
			local result, stamp = rollShard(data, POOL, now, last, nil, false)
			last = stamp
			aboveZero(data)
			if result.ok == true then
				spent += 1
				expect(data.shardTokens).toEqual(Schema.STARTER_TOKENS - spent)
			else
				expect(data).toEqual(before)
				expect(data.shardTokens).toEqual(0)
			end
		end
		expect(spent).toEqual(Schema.STARTER_TOKENS)
		expect(data.shardTokens).toEqual(0)
		expect(data.gold).toEqual(0)

		local vouchers = Schema.template()
		vouchers.shardTokens = 0
		vouchers.vouchers.armory = 2
		local voucherNow = 0
		local voucherLast: Stamp? = nil
		for index = 1, 4 do
			voucherNow += 5
			local before = Schema.deepCopy(vouchers)
			local result, stamp = rollShard(vouchers, POOL, voucherNow, voucherLast, nil, false)
			voucherLast = stamp
			aboveZero(vouchers)
			expect(vouchers.shardTokens).toEqual(0)
			if index <= 2 then
				expect(result.ok).toEqual(true)
			else
				expect(result.ok).toEqual(false)
				expect(vouchers).toEqual(before)
			end
		end

		local shop = Schema.template()
		shop.gold = 1000
		local bought = 0
		for _ = 1, 40 do
			local before = Schema.deepCopy(shop)
			local result = buyGold(shop, "tonic")
			aboveZero(shop)
			expect(shop.shardTokens).toEqual(10)
			if result.ok == true then
				bought += 1
				expect(shop.gold).toEqual(1000 - bought * 40)
			else
				expect(shop).toEqual(before)
			end
		end
		expect(bought).toEqual(20)
		expect(shop.gold).toEqual(200)

		local forge = Schema.template()
		arm(forge, 0)
		local purse = 0
		for _, row in ipairs(FORGE) do
			purse += row.gold
		end
		forge.gold = purse
		forge.materials.gnarl_seed = 3
		local steps = 0
		for _ = 1, 25 do
			local before = Schema.deepCopy(forge)
			local result = upgradeGear(forge, BLADE)
			aboveZero(forge)
			expect(forge.shardTokens).toEqual(10)
			expect(forge.materials.gnarl_seed >= 0).toBeTrue()
			if result.ok == true then
				steps += 1
			else
				expect(forge).toEqual(before)
			end
		end
		expect(steps).toEqual(10)
		expect(forge.inventory[BLADE].upgrade).toEqual(10)
		expect(forge.gold).toEqual(0)
		expect(forge.materials.gnarl_seed).toEqual(0)

		local mixed = Schema.template()
		mixed.gold = 20000
		mixed.shardTokens = 25
		mixed.materials.gnarl_seed = 3
		arm(mixed, 0)
		local mixedNow = 0
		local mixedLast: Stamp? = nil
		for step = 1, 80 do
			local before = Schema.deepCopy(mixed)
			local result: Call
			local kind = step % 3
			if kind == 1 then
				mixedNow += 5
				local stamp
				result, stamp = rollShard(mixed, POOL, mixedNow, mixedLast, nil, false)
				mixedLast = stamp
			elseif kind == 2 then
				result = buyGold(mixed, if step % 2 == 0 then "bag" else "tonic")
			else
				result = upgradeGear(mixed, BLADE)
			end
			aboveZero(mixed)
			if result.ok ~= true then
				expect(mixed).toEqual(before)
			end
		end
	end)

	it("leaves the profile unchanged when the call is refused", function()
		local broke = Schema.template()
		broke.shardTokens = 0
		broke.gold = 0
		local now = 10
		local last: Stamp? = nil
		refuses(broke, function()
			local result, stamp = rollShard(broke, POOL, now, last, nil, false)
			last = stamp
			return result
		end)

		local cooling = Schema.template()
		local opened, openedStamp = rollShard(cooling, POOL, 0, nil, nil, false)
		expect(opened.ok).toEqual(true)
		expect(cooling.shardTokens).toEqual(9)
		refuses(cooling, function()
			local result, stamp = rollShard(cooling, POOL, 0, openedStamp, nil, false)
			return result
		end)
		expect(cooling.shardTokens).toEqual(9)

		local locked = Schema.template()
		refuses(locked, function()
			local result = rollShard(locked, "sunken_armory", 0, nil, nil, false)
			return result
		end)
		refuses(locked, function()
			local result = rollShard(locked, "not a pool", 0, nil, nil, false)
			return result
		end)
		refuses(locked, function()
			local result = rollShard(locked, 4, 0, nil, nil, false)
			return result
		end)
		expect(locked.shardTokens).toEqual(10)

		local full = Schema.template()
		full.shardTokens = 4
		for index = 1, Schema.inventoryCap(full) do
			local uid = string.format("pad-%d", index)
			full.inventory[uid] = { uid = uid, kind = "Weapon", name = "Pad" }
		end
		refuses(full, function()
			local result = rollShard(full, POOL, 0, nil, nil, false)
			return result
		end)
		expect(full.shardTokens).toEqual(4)

		local shop = Schema.template()
		shop.gold = 39
		refuses(shop, function()
			return buyGold(shop, "tonic")
		end)
		shop.gold = 249
		refuses(shop, function()
			return buyGold(shop, "bag")
		end)
		shop.gold = 5000
		refuses(shop, function()
			return buyGold(shop, "pet")
		end)
		refuses(shop, function()
			return buyGold(shop, "nope")
		end)
		shop.consumables["healing_tonic"] = 20
		refuses(shop, function()
			return buyGold(shop, "tonic")
		end)
		expect(shop.gold).toEqual(5000)
		expect(shop.shardTokens).toEqual(10)

		local gear = Schema.template()
		gear.gold = 50000
		gear.materials.gnarl_seed = 5
		arm(gear, 0)
		refuses(gear, function()
			return upgradeGear(gear, "")
		end)
		refuses(gear, function()
			return upgradeGear(gear, "missing")
		end)
		gear.gold = 149
		refuses(gear, function()
			return upgradeGear(gear, BLADE)
		end)
		expect(gear.inventory[BLADE].upgrade).toEqual(0)
		gear.gold = FORGE[8].gold
		gear.inventory[BLADE].upgrade = 7
		gear.materials.gnarl_seed = 0
		refuses(gear, function()
			return upgradeGear(gear, BLADE)
		end)
		expect(gear.gold).toEqual(FORGE[8].gold)
		expect(gear.inventory[BLADE].upgrade).toEqual(7)
		gear.materials.gnarl_seed = 1
		gear.inventory[BLADE].upgrade = 10
		refuses(gear, function()
			return upgradeGear(gear, BLADE)
		end)
		expect(gear.inventory[BLADE].upgrade).toEqual(10)
		expect(gear.shardTokens).toEqual(10)
	end)

	it("counts pity up and resets it as the Roll panel prints Pity N/N", function()
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		expect(string.find(hub, "RollHype.pity(sinceEpic, RarityConfig.EPIC_PITY)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "ShardBoard.pityPlace(progress.w, counter, goal)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "count.Text = place.text", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(roll, "RarityConfig.advance(counters, item.rarity, floor)", 1, true) ~= nil
		).toBeTrue()
		expect(string.find(roll, "epicAt = RarityConfig.EPIC_PITY", 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "legendaryAt = RarityConfig.LEGENDARY_PITY", 1, true) ~= nil).toBeTrue()

		local data = Schema.template()
		data.shardTokens = RarityConfig.LEGENDARY_PITY
		data.inventoryBonus = RarityConfig.LEGENDARY_PITY
		expect(panelPity(data.sinceEpic, RarityConfig.EPIC_PITY)).toEqual("Pity 0/100")
		local openedSince, openedGoal = UiRouter.legendaryPity(data, nil)
		expect(openedSince).toEqual(0)
		expect(openedGoal).toEqual(RarityConfig.LEGENDARY_PITY)
		expect(panelPity(openedSince, openedGoal)).toEqual("Pity 0/1000")

		local now = 0
		local last: Stamp? = nil
		local draw = steadyRng(0.999)
		for _ = 1, RarityConfig.LEGENDARY_PITY do
			local beforeEpic = data.sinceEpic
			local beforeLegendary = data.sinceLegendary
			expect(panelPity(beforeEpic, RarityConfig.EPIC_PITY)).toEqual(
				pityLine(beforeEpic, RarityConfig.EPIC_PITY)
			)
			expect(panelPity(beforeLegendary, RarityConfig.LEGENDARY_PITY)).toEqual(
				pityLine(beforeLegendary, RarityConfig.LEGENDARY_PITY)
			)
			now += 5
			local result, stamp = rollShard(data, POOL, now, last, draw, false)
			last = stamp
			expect(result.ok).toEqual(true)
			assert(result.item ~= nil)
			aboveZero(data)
			local rank = Rarities.rank(result.item.rarity)
			if beforeLegendary + 1 >= RarityConfig.LEGENDARY_PITY then
				expect(rank >= Rarities.rank("Legendary")).toBeTrue()
			elseif beforeEpic + 1 >= RarityConfig.EPIC_PITY then
				expect(rank >= Rarities.rank("Epic")).toBeTrue()
			end
			if rank >= Rarities.rank("Legendary") then
				expect(data.sinceEpic).toEqual(0)
				expect(data.sinceLegendary).toEqual(0)
			elseif rank >= Rarities.rank("Epic") then
				expect(data.sinceEpic).toEqual(0)
				expect(data.sinceLegendary).toEqual(beforeLegendary + 1)
			else
				expect(data.sinceEpic).toEqual(beforeEpic + 1)
				expect(data.sinceLegendary).toEqual(beforeLegendary + 1)
			end
			local pity = result.pity
			expect(pity.sinceEpic).toEqual(data.sinceEpic)
			expect(pity.sinceLegendary).toEqual(data.sinceLegendary)
			expect(pity.epicAt).toEqual(RarityConfig.EPIC_PITY)
			expect(pity.legendaryAt).toEqual(RarityConfig.LEGENDARY_PITY)
			local since, goal = UiRouter.legendaryPity(data, result)
			expect(since).toEqual(data.sinceLegendary)
			expect(goal).toEqual(RarityConfig.LEGENDARY_PITY)
			expect(panelPity(pity.sinceEpic, pity.epicAt)).toEqual(
				pityLine(data.sinceEpic, RarityConfig.EPIC_PITY)
			)
			expect(panelPity(since, goal)).toEqual(pityLine(data.sinceLegendary, goal))
			expect(data.pity).toEqual({})
			if data.shardRolls == 50 then
				expect(panelPity(data.sinceEpic, RarityConfig.EPIC_PITY)).toEqual("Pity 50/100")
				expect(panelPity(data.sinceLegendary, goal)).toEqual("Pity 50/1000")
			elseif data.shardRolls == 99 then
				expect(panelPity(data.sinceEpic, RarityConfig.EPIC_PITY)).toEqual("Pity 99/100")
			elseif data.shardRolls == 100 then
				expect(panelPity(data.sinceEpic, RarityConfig.EPIC_PITY)).toEqual("Pity 0/100")
				expect(panelPity(data.sinceLegendary, goal)).toEqual("Pity 100/1000")
			elseif data.shardRolls == 999 then
				expect(panelPity(data.sinceEpic, RarityConfig.EPIC_PITY)).toEqual("Pity 99/100")
				expect(panelPity(data.sinceLegendary, goal)).toEqual("Pity 999/1000")
			end
		end
		expect(data.shardTokens).toEqual(0)
		expect(data.shardRolls).toEqual(RarityConfig.LEGENDARY_PITY)
		expect(data.sinceEpic).toEqual(0)
		expect(data.sinceLegendary).toEqual(0)
		expect(panelPity(data.sinceEpic, RarityConfig.EPIC_PITY)).toEqual("Pity 0/100")
		expect(panelPity(data.sinceLegendary, RarityConfig.LEGENDARY_PITY)).toEqual("Pity 0/1000")
		refuses(data, function()
			local result = rollShard(data, POOL, now + 5, last, draw, false)
			return result
		end)

		local secret = Schema.template()
		secret.shardTokens = 1
		secret.sinceEpic = 40
		secret.sinceLegendary = 250
		local dropped, _stamp = rollShard(secret, POOL, 0, nil, steadyRng(0), false)
		expect(dropped.ok).toEqual(true)
		assert(dropped.item ~= nil)
		expect(Rarities.rank(dropped.item.rarity) >= Rarities.rank("Legendary")).toBeTrue()
		expect(secret.sinceEpic).toEqual(0)
		expect(secret.sinceLegendary).toEqual(0)
		expect(panelPity(dropped.pity.sinceEpic, dropped.pity.epicAt)).toEqual("Pity 0/100")
		expect(panelPity(dropped.pity.sinceLegendary, dropped.pity.legendaryAt)).toEqual(
			"Pity 0/1000"
		)
		expect(secret.shardTokens).toEqual(0)
	end)

	it("charges the Forge table and writes that upgrade", function()
		for _, row in ipairs(FORGE) do
			local quoted = math.floor(500 * (1.6 ^ row.level) + 0.5)
			if row.level == 0 then
				quoted = 150
			elseif row.level == 1 then
				quoted = 300
			end
			local seed = if row.level >= 7 then 1 else 0
			expect(quoted).toEqual(row.gold)
			expect(seed).toEqual(row.seed)
			local cost, mats = Economy.upgradeCost(row.level)
			expect(cost).toEqual(row.gold)
			expect(mats).toEqual(row.seed)

			local data = Schema.template()
			data.gold = row.gold
			data.materials.gnarl_seed = row.seed
			arm(data, row.level)
			local result = upgradeGear(data, BLADE)
			expect(result.ok).toEqual(true)
			expect(result.note).toEqual(string.format("Thornblade +%d", row.level + 1))
			expect(data.inventory[BLADE].upgrade).toEqual(row.level + 1)
			expect(data.gold).toEqual(0)
			expect(data.materials.gnarl_seed).toEqual(0)
			expect(data.shardTokens).toEqual(10)
			refuses(data, function()
				return upgradeGear(data, BLADE)
			end)
		end
	end)
end)
