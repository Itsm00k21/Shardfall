--!strict

--[[
	M13 run smoke. One walk of the live loop on cursor/live-build-9721:

	  roll -> equip -> Gate pad -> five wave rows -> wipe -> rejoin -> roll again

	LaunchGate stays as it is shipped. The Phase 2 equip remote is opened
	with a test stub (equipOn), not by writing LaunchGate.SHOW.

	The wave-5 chest from Dungeons.waveReward stays 2. The boss-clear
	grant from the merged reward module adds 5 on top of that, once.
	A rejoin and a wipe do not pay it again. LaunchGate.SHOW is not
	written. Nothing here spends Robux.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local BossClearReward = require("../src/ReplicatedStorage/Shared/BossClearReward")
local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local Config = require("../src/ReplicatedStorage/Shared/Config/Index")
local Currencies = require("../src/ReplicatedStorage/Shared/Currencies")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Elements = require("../src/ReplicatedStorage/Shared/Config/Elements")
local EquipSlots = require("../src/ReplicatedStorage/Shared/Config/EquipSlots")
local EquipStats = require("../src/ReplicatedStorage/Shared/Config/EquipStats")
local GearLevels = require("../src/ReplicatedStorage/Shared/Config/GearLevels")
local GearSalvage = require("../src/ReplicatedStorage/Shared/GearSalvage")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local ResultsGrid = require("../src/ReplicatedStorage/Shared/ResultsGrid")
local RollMath = require("../src/ReplicatedStorage/Shared/RollMath")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local StarterGoalPay = require("../src/ReplicatedStorage/Shared/StarterGoalPay")
local WaveFlow = require("../src/ReplicatedStorage/Shared/WaveFlow")
local WaveFlowService = require("../src/ServerScriptService/ShardfallServer/WaveFlowService")
local Remotes = require("../src/server/EquipService/Remotes")
local Validate = require("../src/server/EquipService/Validate")

local HAVEN = "src/ServerScriptService/ShardfallServer/HavenBuilder.luau"
local DUNGEON = "src/ServerScriptService/ShardfallServer/DungeonService.luau"
local HUD = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau"
local GATE = "src/ReplicatedStorage/Shared/LaunchGate.luau"

local function fixedRng()
	return {
		nextNumber = function()
			return 0
		end,
		nextInteger = function(_self, min: number, _max: number)
			return min
		end,
	}
end

local function equipCtx()
	return {
		slots = EquipSlots,
		stats = EquipStats,
		elements = Elements,
		classes = Classes,
		gearConfig = GearLevels,
		gearEnabled = false,
	}
end

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

local function crack(profile, uid: string)
	local pool = Pools.get(Pools.DEFAULT_POOL_ID)
	assert(pool ~= nil, "verdant armory missing")
	expect(Pools.isUnlocked(pool, profile.ascension)).toEqual(true)
	expect(Currencies.crackBlock(profile.shardTokens, 0)).toBeNil()
	local before = profile.shardTokens
	local prism = profile.prismTokens
	local spent, spendError = Currencies.take(profile, Currencies.SHARD)
	expect(spent).toEqual(true)
	expect(spendError).toBeNil()
	expect(profile.shardTokens).toEqual(before - 1)
	expect(profile.prismTokens).toEqual(prism)

	local rng = fixedRng()
	local counters = { sinceLegendary = profile.sinceLegendary }
	local rarity, _pity, floor =
		RarityConfig.pick(pool, RarityConfig.luckFromProfile(profile), counters, rng)
	local entry = RarityConfig.chooseEntry(pool, rarity, rng)
	expect(type(entry) == "table" and type(entry.templateId) == "string").toBeTrue()
	local item = RollMath.mint(entry.templateId, {
		uid = uid,
		now = 0,
		poolId = pool.id,
	}, rng)
	local arrival = GearSalvage.receive(profile, item)
	expect(arrival.kept).toEqual(true)
	Schema.insertItem(profile, item)
	RarityConfig.advance(counters, item.rarity, floor)
	profile.sinceLegendary = counters.sinceLegendary
	profile.shardRolls = (profile.shardRolls or 0) + 1
	StarterGoalPay.grant(profile, "rolls", nil)
	expect(profile.shardTokens).toEqual(before - 1)
	expect(profile.prismTokens).toEqual(0)
	return item
end

local function slotFor(item): string
	if item.kind == "Weapon" then
		return "weapon"
	end
	if item.kind == "Armor" then
		return "armor"
	end
	return ""
end

local function stillEquipped(profile, item): boolean
	if item.kind == "Weapon" then
		return profile.equipped.weapon == item.uid
	end
	if item.kind == "Armor" then
		local slot = item.slot
		return type(slot) == "string" and profile.equipped.armor[slot] == item.uid
	end
	return false
end

describe("M13 run smoke", function()
	it("walks roll, equip, the gate pad, five live waves, wipe, rejoin, and roll again", function()
		local gateFile = fs.readFile(GATE)
		expect(string.find(gateFile, "equip = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(gateFile, "waveArena = false", 1, true) ~= nil).toBeTrue()
		expect(LaunchGate.on("equip")).toEqual(false)
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(LaunchGate.on("gearSalvage")).toEqual(false)
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		expect(LaunchGate.on("enemyTypes")).toEqual(false)

		local profile = Schema.template()
		expect(profile.schemaVersion).toEqual(26)
		expect(profile.shardTokens).toEqual(Schema.STARTER_TOKENS)
		expect(profile.prismTokens).toEqual(0)
		expect(profile.bossClearRuns).toEqual({})

		-- Roll. One Shard Token. Prism stays at 0.
		local item = crack(profile, "roll-1")
		expect(Schema.findItem(profile, item.uid) ~= nil).toBeTrue()
		expect(profile.shardTokens).toEqual(Schema.STARTER_TOKENS - 1)
		local slotId = slotFor(item)
		expect(slotId ~= "").toBeTrue()

		-- Live bag equip. This is the EquipItem remote. It is not behind the flag.
		expect(Schema.equipItem(profile, item)).toBeNil()
		expect(stillEquipped(profile, item)).toEqual(true)

		-- Phase 2 remote stays closed on the shipped flag, then a test stub
		-- seats the same drop. LaunchGate.SHOW is not written.
		local ctx = equipCtx()
		local buckets = {}
		local function mutate(_userId, mutator)
			local err = mutator(profile)
			if err ~= nil then
				return false, err
			end
			return true, nil
		end
		local closed = Remotes.handle({
			action = "EquipSlot",
			userId = 1,
			args = { slotId, item.uid },
			now = 1,
		}, {
			equipOn = function()
				return LaunchGate.on("equip")
			end,
			read = function()
				return profile
			end,
			mutate = mutate,
			ctx = ctx,
		}, buckets)
		expect(closed.ok).toEqual(false)
		expect(closed.error).toEqual(Validate.OFF)
		expect(profile.equipLoadout[slotId]).toEqual("")

		local seated = Remotes.handle({
			action = "EquipSlot",
			userId = 1,
			args = { slotId, item.uid },
			now = 2,
		}, {
			equipOn = function()
				return true
			end,
			read = function()
				return profile
			end,
			mutate = mutate,
			ctx = ctx,
		}, buckets)
		expect(seated.ok).toEqual(true)
		expect(seated.loadout[slotId]).toEqual(item.uid)
		expect(LaunchGate.on("equip")).toEqual(false)
		expect(profile.shardTokens).toEqual(Schema.STARTER_TOKENS - 1)

		-- Gate pad. The Waves pier calls DungeonService.enter on the waves
		-- dungeon. waveArena is off and does not guard that prompt.
		local haven = fs.readFile(HAVEN)
		expect(string.find(haven, 'promptOn(leftPier, "Waves", "Solo", "waves"', 1, true) ~= nil).toBeTrue()
		local wavesHandler = between(haven, 'if action == "waves" then', 'if action == "practice" then')
		expect(string.find(wavesHandler, "DungeonService.enter(player, Dungeons.WAVES_ID)", 1, true) ~= nil).toBeTrue()
		expect(string.find(wavesHandler, "waveArena", 1, true)).toBeNil()
		expect(string.find(wavesHandler, "LaunchGate", 1, true)).toBeNil()
		local waves = Dungeons.get(Dungeons.WAVES_ID)
		assert(waves ~= nil)
		expect(waves.implemented).toEqual(true)
		expect(waves.endless).toEqual(true)
		expect(Dungeons.isUnlocked(waves, profile.ascension)).toEqual(true)
		expect(LaunchGate.dungeonOpen(Dungeons.WAVES_ID)).toEqual(true)

		-- Five live wave rows. Wave 5 is Gnarl. The sheet says the boss
		-- pays 5; the live reward function pays 2, and the service uses it.
		local paid = 0
		for wave = 1, 5 do
			local kinds = Dungeons.waveKinds(wave)
			expect(#kinds >= 1).toBeTrue()
			paid += Dungeons.waveReward(wave).shardTokens
			if wave < 5 then
				expect(Dungeons.isBossWave(wave)).toEqual(false)
			end
		end
		expect(Dungeons.waveKinds(5)).toEqual({ "grandmother_gnarl", "vine_crawler", "spore_bat" })
		expect(Dungeons.isBossWave(5)).toEqual(true)
		local boss = Dungeons.enemy("grandmother_gnarl")
		assert(boss ~= nil)
		expect(boss.boss).toEqual(true)
		local bossReward = Dungeons.waveReward(5)
		expect(bossReward.shardTokens).toEqual(2)
		expect(paid).toEqual(3)
		local sheet = 0
		for _, row in ipairs(Config.Economy.WAVES) do
			sheet += row.tokens
		end
		expect(sheet).toEqual(Config.Economy.NORMAL_CLEAR_TOKENS)
		expect(Config.Economy.WAVES[5].boss).toEqual(true)
		expect(Config.Economy.WAVES[5].tokens).toEqual(5)
		expect(Config.Economy.BOSS_CLEAR_TOKENS).toEqual(5)
		expect(Config.Economy.bossClearPay()).toEqual(5)
		expect(bossReward.shardTokens).toEqual(2)

		local service = fs.readFile(DUNGEON)
		expect(string.find(service, "grant(player, run, Dungeons.waveReward(run.wave), nil)", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "BossClearReward", 1, true)).toBeNil()
		expect(string.find(service, "Config.Economy", 1, true)).toBeNil()

		-- Results. Endless wave clears publish a hint, not the victory card.
		-- The card reader is still here: gold, tokens, XP, and a loot grid.
		local lines = {}
		for _, materialId in ipairs(Materials.ORDER) do
			local count = bossReward.materials[materialId]
			if type(count) == "number" and count > 0 then
				table.insert(lines, {
					name = Materials.displayName(materialId),
					count = count,
				})
			end
		end
		local tiles = ResultsGrid.merge(lines)
		expect(#tiles).toEqual(2)
		expect(tiles[1].name).toEqual("Verdant Wood")
		expect(tiles[1].count).toEqual(1)
		expect(tiles[2].name).toEqual("Ironbark")
		expect(tiles[2].count).toEqual(1)
		local payload = {
			kind = "victory",
			dungeonName = waves.name,
			gold = bossReward.gold,
			bonusGold = 0,
			shardTokens = bossReward.shardTokens,
			xp = bossReward.xp,
			levels = 0,
			materials = lines,
			voucher = bossReward.voucher,
			dismissIn = Dungeons.VICTORY_CARD_SECONDS,
		}
		expect(payload.dungeonName).toEqual("Rootvault Waves")
		expect(payload.shardTokens).toEqual(2)
		expect(payload.voucher).toBeNil()
		expect(payload.gold).toEqual(bossReward.gold)
		expect(payload.xp).toEqual(bossReward.xp)
		local hud = fs.readFile(HUD)
		expect(string.find(hud, 'payload.kind == "victory"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "Shard tokens  %d", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "ResultsGrid.merge", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "bossClear", 1, true)).toBeNil()
		local hint = string.format(
			"Wave %d cleared. +%d gold, +%d XP, +%d tokens.",
			5,
			bossReward.gold,
			bossReward.xp,
			bossReward.shardTokens
		)
		expect(hint).toEqual(string.format("Wave 5 cleared. +%d gold, +%d XP, +2 tokens.", bossReward.gold, bossReward.xp))
		expect(string.find(service, "Wave %d cleared. %s.", 1, true) ~= nil).toBeTrue()

		-- Wipe. Defeat does not grant and does not take tokens back.
		local beforeWipe = profile.shardTokens
		expect(Dungeons.defeatLine(waves)).toEqual(
			"The waves stop when you fall. Rewards from cleared waves are still yours."
		)
		local finish = between(
			service,
			"local function finish(player: Player, victory: boolean)",
			"local function beginAdvance"
		)
		local grantAt = string.find(finish, "saved = grant(", 1, true)
		local defeatAt = string.find(finish, 'kind = "defeat"', 1, true)
		assert(grantAt ~= nil and defeatAt ~= nil)
		expect(grantAt < defeatAt).toBeTrue()
		local defeat = string.sub(finish, defeatAt, #finish)
		expect(string.find(defeat, "grant(", 1, true)).toBeNil()
		expect(string.find(defeat, "shardTokens", 1, true)).toBeNil()
		expect(profile.shardTokens).toEqual(beforeWipe)

		-- Rejoin before any boss grant. The save keeps the wallet and the
		-- equipped drop. The run list is empty, so nothing was paid.
		local rejoined = Schema.migrate(Schema.deepCopy(profile))
		assert(rejoined ~= nil)
		expect(rejoined.schemaVersion).toEqual(26)
		expect(rejoined.shardTokens).toEqual(beforeWipe)
		expect(rejoined.prismTokens).toEqual(0)
		expect(rejoined.bossClearRuns).toEqual({})
		expect(Schema.findItem(rejoined, item.uid) ~= nil).toBeTrue()
		expect(stillEquipped(rejoined, item)).toEqual(true)

		-- Roll again. This spends a starter token, not a boss-clear grant.
		local again = crack(rejoined, "roll-2")
		expect(again.uid).toEqual("roll-2")
		expect(rejoined.shardTokens).toEqual(Schema.STARTER_TOKENS - 2)
		expect(stillEquipped(rejoined, item)).toEqual(true)
		expect(LaunchGate.on("equip")).toEqual(false)
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(LaunchGate.on("enemyTypes")).toEqual(false)
	end)

	it("pays 5 boss-clear tokens once on top of the wave-5 reward of 2", function()
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		expect(LaunchGate.on("enemyTypes")).toEqual(false)
		expect(WaveFlowService.open()).toEqual(false)
		expect(WaveFlowService.start({
			player = "hero",
			profile = Schema.template(),
			persist = function()
				return true
			end,
		})).toBeNil()

		local wavePay = Dungeons.waveReward(5).shardTokens
		expect(wavePay).toEqual(2)
		expect(Config.Economy.BOSS_CLEAR_TOKENS).toEqual(5)
		expect(Config.Economy.bossClearPay()).toEqual(5)

		local run = WaveFlow.start()
		assert(run ~= nil)
		local guard = 0
		while run.clear ~= true and guard < 80 do
			local boxes = WaveFlow.boxes(run)
			expect(#boxes > 0).toBeTrue()
			expect(WaveFlow.hurt(run, boxes[1].id, 100000) > 0).toBeTrue()
			guard += 1
		end
		expect(run.clear).toEqual(true)
		expect(run.wave).toEqual(5)
		expect(run.rewarded).toEqual(false)

		local profile = Schema.template()
		local before = profile.shardTokens
		profile.shardTokens += wavePay
		expect(profile.shardTokens).toEqual(before + 2)

		local disk = {}
		local persistCalls = 0
		local paid = BossClearReward.commit(profile, run.id, function(data)
			persistCalls += 1
			disk[1] = Schema.deepCopy(data)
			return true
		end)
		expect(persistCalls).toEqual(1)
		expect(paid.granted).toEqual(true)
		expect(paid.already).toEqual(false)
		expect(paid.saved).toEqual(true)
		expect(paid.tokens).toEqual(5)
		expect(profile.shardTokens).toEqual(before + 2 + 5)
		expect(BossClearReward.seen(profile, run.id)).toEqual(true)
		expect(BossClearReward.card(paid)).toEqual({ granted = true, tokens = 5 })

		local secondCalls = 0
		local second = BossClearReward.commit(profile, run.id, function()
			secondCalls += 1
			return true
		end)
		expect(secondCalls).toEqual(0)
		expect(second.granted).toEqual(false)
		expect(second.already).toEqual(true)
		expect(second.tokens).toEqual(0)
		expect(profile.shardTokens).toEqual(before + 2 + 5)
		expect(BossClearReward.card(second)).toEqual({ granted = false, tokens = 0 })

		local wiped = BossClearReward.wipe(profile, run.id)
		expect(wiped.granted).toEqual(false)
		expect(wiped.tokens).toEqual(0)
		expect(profile.shardTokens).toEqual(before + 2 + 5)
		expect(BossClearReward.seen(profile, run.id)).toEqual(true)

		local rejoined = Schema.migrate(disk[1])
		assert(rejoined ~= nil)
		expect(rejoined.schemaVersion).toEqual(26)
		expect(rejoined.shardTokens).toEqual(before + 2 + 5)
		expect(BossClearReward.seen(rejoined, run.id)).toEqual(true)
		local rejoinCalls = 0
		local replay = BossClearReward.commit(rejoined, run.id, function()
			rejoinCalls += 1
			return true
		end)
		expect(rejoinCalls).toEqual(0)
		expect(replay.granted).toEqual(false)
		expect(replay.already).toEqual(true)
		expect(replay.tokens).toEqual(0)
		expect(rejoined.shardTokens).toEqual(before + 2 + 5)
		local rejoinWipe = BossClearReward.wipe(rejoined, run.id)
		expect(rejoinWipe.granted).toEqual(false)
		expect(rejoinWipe.tokens).toEqual(0)
		expect(rejoined.shardTokens).toEqual(before + 2 + 5)
		expect(BossClearReward.seen(rejoined, run.id)).toEqual(true)

		local early = Schema.template()
		local earlyBefore = early.shardTokens
		early.shardTokens += Dungeons.waveReward(5).shardTokens
		local earlyWipe = BossClearReward.wipe(early, "run-9")
		expect(earlyWipe.granted).toEqual(false)
		expect(earlyWipe.tokens).toEqual(0)
		expect(early.shardTokens).toEqual(earlyBefore + 2)
		expect(BossClearReward.seen(early, "run-9")).toEqual(false)

		local spent, spendError = Currencies.take(rejoined, Currencies.SHARD)
		expect(spent).toEqual(true)
		expect(spendError).toBeNil()
		expect(rejoined.shardTokens).toEqual(before + 2 + 5 - 1)
		expect(rejoined.prismTokens).toEqual(0)
		local afterRoll = BossClearReward.commit(rejoined, run.id, function()
			return true
		end)
		expect(afterRoll.granted).toEqual(false)
		expect(afterRoll.already).toEqual(true)
		expect(rejoined.shardTokens).toEqual(before + 2 + 5 - 1)
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		expect(LaunchGate.on("enemyTypes")).toEqual(false)
	end)
end)
