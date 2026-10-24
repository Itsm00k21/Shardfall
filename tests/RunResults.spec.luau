--!strict

--[[
	M12 results payload and Run Again. The flag ships off. Loot on the
	card is the server grant list. A client claim cannot add rewards.
	Many Run Again fires in one frame start one run.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local RunResults = require("../src/ReplicatedStorage/Shared/RunResults")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Session = require("../src/server/WaveArena/Session")
local WaveArena = require("../src/server/WaveArena")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")

local function withResults(run: () -> ())
	local previous = LaunchGate.SHOW.m12Results
	LaunchGate.SHOW.m12Results = true
	RunResults.reset()
	local ok, err = pcall(run)
	LaunchGate.SHOW.m12Results = previous
	RunResults.reset()
	if not ok then
		error(err, 0)
	end
end

local function withHard(run: () -> ())
	local previous = LaunchGate.SHOW.hardMode
	LaunchGate.SHOW.hardMode = true
	local ok, err = pcall(run)
	LaunchGate.SHOW.hardMode = previous
	if not ok then
		error(err, 0)
	end
end

local function arenaConfig(waves: { any }, tokens: { number }): any
	local copy = table.clone(WaveArenaConfig)
	copy.enabled = true
	copy.player = {
		hp = 500,
		damage = 12,
		range = 100,
		interval = 0,
		speed = 0,
		radius = 2,
		start = { x = 0, z = 0 },
	}
	copy.chaser = {
		id = "wave_chaser",
		size = { 3.2, 2.2, 4.2 },
		moveSpeed = 0,
		arrive = 6,
		hp = 12,
		damage = 0,
		attackRange = 0,
		attackInterval = 5,
		windup = 0.5,
		opening = 10,
	}
	copy.waves = waves
	local mix = {}
	for index = 1, #waves do
		mix[index] = { "chaser" }
	end
	copy.mix = mix
	copy.loot = {
		pickupRadius = 12,
		bagSlots = 100,
		overflowCap = 40,
		drops = WaveArenaConfig.loot.drops,
		waveTokens = tokens,
	}
	return copy
end

local function opened(config: any): any
	return {
		launchGate = { waveArena = true },
		config = config,
		ownerId = 42,
		tier = "normal",
		party = 1,
	}
end

local function attack(run: any, options: any, count: number)
	for _ = 1, count do
		if run.phase == "results" then
			return
		end
		WaveArena.step(run, 0.5, { attack = true }, options)
	end
end

local function ended(ownerId: number, receiptId: string, reason: string): any
	return {
		ownerId = ownerId,
		tier = "normal",
		party = 1,
		phase = "results",
		settled = true,
		reason = reason,
		receiptId = receiptId,
		wavesCleared = 2,
		total = 5,
	}
end

local CLAIM = {
	loot = { { id = "client_gold", count = 40, tokens = 500 } },
	tokens = 5000,
	fragments = 80,
	rewards = { gold = 1000 },
	xp = 9999,
	level = 99,
	tier = "normal",
	bestWave = 99,
	bossClear = { granted = true, tokens = 50 },
	grantList = {
		{ kind = "drop", dropId = "client_gold", where = "bag", rarity = "Legendary" },
	},
}

describe("M12 results", function()
	it("validates the config numbers and leaves schema 26", function()
		expect(LaunchGate.SHOW.m12Results).toEqual(false)
		expect(LaunchGate.on("m12Results")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		expect(Schema.template().bestWave).toBeNil()
		local ok, err = RunResults.validate()
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(WaveArenaConfig.results.autoReturn).toEqual(30)
		expect(WaveArenaConfig.results.soloCountdown).toEqual(3)
		expect(WaveArenaConfig.results.runAgainGap).toEqual(1)
		expect(WaveArenaConfig.results.frameMs).toEqual(50)
		expect(WaveArenaConfig.results.hardLevel).toEqual(5)

		local copy = table.clone(WaveArenaConfig.results)
		copy.autoReturn = 10
		local broken, why = RunResults.check(copy)
		expect(broken).toEqual(false)
		expect(why).toEqual("autoReturn")
		copy.autoReturn = 30
		copy.productId = 99
		local robbed, robux = RunResults.check(copy)
		expect(robbed).toEqual(false)
		expect(robux).toEqual("robux")
		expect(RunResults.validate()).toEqual(true)
		expect(WaveArenaConfig.results.autoReturn).toEqual(30)

		expect(Session.remoteOk(false, true, "again")).toEqual(false)
		expect(Session.remoteOk(true, false, "again")).toEqual(true)
		expect(Session.remoteOk(true, true, "leave")).toEqual(false)

		local source = fs.readFile("src/ReplicatedStorage/Shared/RunResults.luau")
		expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
		local gate = fs.readFile("src/ReplicatedStorage/Shared/LaunchGate.luau")
		expect(string.find(gate, "m12Results = false", 1, true) ~= nil).toBeTrue()
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "RunResults.again", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "RunResults.stay", 1, true) ~= nil).toBeTrue()
		local card = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/WaveArena/ResultsCard.luau")
		expect(string.find(card, "m12Results", 1, true)).toBeNil()
	end)

	it("does nothing while the flag is off", function()
		expect(LaunchGate.on("m12Results")).toEqual(false)
		RunResults.reset()
		local data = Schema.template()
		local before = Schema.deepCopy(data)
		local run = ended(42, "off-run", "clear")
		run.grantList = {
			{ kind = "drop", dropId = "shard_chip", rarity = "Common", where = "bag" },
		}
		expect(RunResults.payload(run, data, CLAIM, 1000)).toBeNil()
		local again = RunResults.again(42, run, data, CLAIM, 1000, false)
		expect(again).toEqual({ ok = true, noop = true, started = false })
		local second = RunResults.again(42, run, data, CLAIM, 1000, false)
		expect(second.started).toEqual(false)
		expect(second.runId).toBeNil()
		expect(data).toEqual(before)

		local options = opened(arenaConfig({ { count = 1, kind = "chaser" } }, { 1 }))
		local live = WaveArena.enter(options) :: any
		attack(live, options, 4)
		expect(live.phase).toEqual("results")
		expect(live.card.wavesCleared).toEqual(1)
		expect(live.card.loot.items).toBeNil()
		expect(live.card.newBest).toBeNil()
		expect(live.card.outcome).toBeNil()
		expect(live.card.bossClear).toBeNil()
		expect(Schema.VERSION).toEqual(26)
	end)

	it("sends waves, server loot, and best wave on a clear and on a wipe", function()
		withResults(function()
			local clearOptions = opened(arenaConfig({ { count = 1, kind = "chaser" } }, { 1 }))
			local cleared = WaveArena.enter(clearOptions) :: any
			attack(cleared, clearOptions, 4)
			local clearCard = cleared.card
			expect(clearCard.reason).toEqual("clear")
			expect(clearCard.cleared).toEqual(true)
			expect(clearCard.outcome).toEqual("cleared")
			expect(clearCard.wavesCleared).toEqual(1)
			expect(clearCard.total).toEqual(1)
			expect(clearCard.bestWave).toEqual(1)
			expect(clearCard.newBest).toEqual(true)
			expect(clearCard.kills).toEqual(1)
			expect(clearCard.loot.tokens).toEqual(1)
			expect(clearCard.loot.fragments).toEqual(1)
			expect(clearCard.loot.items).toEqual({
				{
					id = "shard_chip",
					name = "Shard Chip",
					tier = "Common",
					count = 1,
					hardOnly = false,
				},
			})
			expect(type(clearCard.loot.overflow)).toEqual("table")
			expect(type(clearCard.loot.essence)).toEqual("number")
			expect(clearCard.bossClear).toEqual({ granted = false, tokens = 0 })

			local wipeOptions = opened(arenaConfig({
				{ count = 1, kind = "chaser" },
				{ count = 1, kind = "chaser" },
			}, { 1, 1 }))
			local wiped = WaveArena.enter(wipeOptions) :: any
			attack(wiped, wipeOptions, 1)
			expect(wiped.phase).toEqual("fight")
			expect(wiped.wavesCleared).toEqual(1)
			WaveArena.settle(wiped, "wipe", wipeOptions)
			local wipeCard = wiped.card
			expect(wipeCard.reason).toEqual("wipe")
			expect(wipeCard.died).toEqual(true)
			expect(wipeCard.outcome).toEqual("wiped")
			expect(wipeCard.wavesCleared).toEqual(1)
			expect(wipeCard.total).toEqual(2)
			expect(wipeCard.bestWave).toEqual(1)
			expect(wipeCard.newBest).toEqual(false)
			expect(wipeCard.loot.items[1].id).toEqual("shard_chip")
			expect(wipeCard.loot.items[1].count).toEqual(1)
			expect(wipeCard.loot.fragments).toEqual(1)
			expect(Schema.template().bestWave).toBeNil()
			expect(Schema.VERSION).toEqual(26)
		end)
	end)

	it("ignores loot and reward claims from the client", function()
		withResults(function()
			local data = Schema.template()
			local before = Schema.deepCopy(data)
			local run = ended(7, "claim-run", "clear")
			run.wavesCleared = 4
			run.kills = 6
			run.grantList = {
				{ kind = "purse", tokens = 3, wave = 1 },
				{ kind = "drop", dropId = "shard_chip", rarity = "Common", where = "bag", fragments = 1, tokens = 0 },
				{
					kind = "drop",
					dropId = "shard_chip",
					rarity = "Common",
					where = "overflow",
					fragments = 1,
					tokens = 0,
				},
				{ kind = "drop", dropId = "boss_core", rarity = "Common", where = "bag", fragments = 4, tokens = 0 },
			}
			run.earned = {
				tokens = 9999,
				drops = { { id = "client_gold", count = 40 } },
			}
			run.bossGrant = { saved = true, granted = true, tokens = 5 }
			local fields = RunResults.payload(run, data, CLAIM, 1000)
			expect(fields.wavesCleared).toEqual(4)
			expect(fields.bestWave).toEqual(4)
			expect(fields.bestWave).toBeLessThan(99)
			expect(fields.returnAt).toEqual(1030)
			expect(fields.loot).toEqual({
				{
					id = "shard_chip",
					name = "Shard Chip",
					tier = "Common",
					count = 1,
					hardOnly = false,
				},
				{
					id = "boss_core",
					name = "Boss Core",
					tier = "Common",
					count = 1,
					hardOnly = false,
				},
			})
			expect(fields.bossClear).toEqual({ granted = true, tokens = 5 })
			expect(fields.tier).toEqual("normal")
			local started = RunResults.again(7, run, data, CLAIM, 1000, false)
			expect(started.started).toEqual(true)
			expect(started.tier).toEqual("normal")
			expect(started.loot).toBeNil()
			expect(started.tokens).toBeNil()
			expect(data).toEqual(before)
			expect(data.level).toEqual(1)
		end)
	end)

	it("starts one run when Run Again fires many times in one frame", function()
		withResults(function()
			local data = Schema.template()
			local before = Schema.deepCopy(data)
			local run = ended(7, "spam-run", "wipe")
			local started = 0
			local runId = nil
			for _ = 1, 24 do
				local result = RunResults.again(7, run, data, CLAIM, 10, false)
				expect(result.ok).toEqual(true)
				if result.started == true then
					started += 1
					runId = result.runId
				else
					expect(result.duplicate).toEqual(true)
					expect(result.runId).toEqual(runId)
				end
			end
			expect(started).toEqual(1)
			expect(runId).toEqual("m12-7-1")
			local tooSoon = RunResults.again(7, ended(7, "spam-next", "clear"), data, CLAIM, 10.2, false)
			expect(tooSoon.ok).toEqual(false)
			expect(tooSoon.error).toEqual("rate")
			expect(tooSoon.started).toEqual(false)
			expect(tooSoon.runId).toBeNil()
			local same = RunResults.again(7, run, data, CLAIM, 100, false)
			expect(same.started).toEqual(false)
			expect(same.runId).toEqual(runId)
			local later = RunResults.again(7, ended(7, "spam-later", "timeout"), data, CLAIM, 100, false)
			expect(later.started).toEqual(true)
			expect(later.runId).toEqual("m12-7-2")
			expect(later.countdown).toEqual(WaveArenaConfig.results.soloCountdown)
			expect(data).toEqual(before)
		end)
	end)

	it("rejects Run Again from the wrong run, a live run, and a teleport", function()
		withResults(function()
			local data = Schema.template()
			local before = Schema.deepCopy(data)
			local function rejected(result: any, reason: string)
				expect(result.ok).toEqual(false)
				expect(result.started).toEqual(false)
				expect(result.runId).toBeNil()
				expect(result.error).toEqual(reason)
			end
			rejected(RunResults.again(7, nil, data, CLAIM, 40, false), "state")
			rejected(
				RunResults.again(7, {
					ownerId = 7,
					phase = "fight",
					settled = false,
					reason = nil,
					receiptId = "live",
					tier = "normal",
					party = 1,
				}, data, CLAIM, 40, false),
				"state"
			)
			rejected(
				RunResults.again(7, {
					ownerId = 7,
					phase = "results",
					settled = false,
					reason = "clear",
					receiptId = "holding",
					tier = "normal",
					party = 1,
				}, data, CLAIM, 40, false),
				"state"
			)
			rejected(RunResults.again(7, ended(7, "gone", "disconnect"), data, CLAIM, 40, false), "state")
			rejected(RunResults.again(7, ended(8, "theirs", "clear"), data, CLAIM, 40, false), "owner")
			rejected(RunResults.again(7, ended(7, "mid", "wipe"), data, CLAIM, 40, true), "teleport")
			rejected(
				RunResults.again(7, {
					ownerId = 7,
					phase = "results",
					settled = true,
					reason = "clear",
					receiptId = "party",
					tier = "normal",
					party = 3,
				}, data, CLAIM, 40, false),
				"party"
			)
			withHard(function()
				data.level = 4
				local hard = ended(7, "hard-run", "wipe")
				hard.tier = "hard"
				rejected(RunResults.again(7, hard, data, CLAIM, 40, false), "eligible")
				expect(data.level).toEqual(4)
				data.level = before.level
			end)
			rejected(RunResults.again(7, ended(7, "no-profile", "clear"), nil, CLAIM, 40, false), "eligible")
			expect(data).toEqual(before)
		end)
	end)
end)
