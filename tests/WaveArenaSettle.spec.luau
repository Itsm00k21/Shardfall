--!strict

--[[
	Settle, auto-collect, and the server session flag.

	A drop is taken once. Disconnect, wipe, and timeout keep that loot.
	Rejoin does not put the player back in the arena. Remotes and the
	teleport read the server switches, not a client payload.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Loot = require("../src/server/WaveArena/Loot")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Session = require("../src/server/WaveArena/Session")
local WaveArena = require("../src/server/WaveArena")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")

local function fightConfig(): any
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
		damage = 1,
		attackRange = 0,
		attackInterval = 5,
		windup = 0.5,
		opening = 10,
	}
	copy.boss = {
		id = "wave_boss",
		size = { 8, 9, 7 },
		moveSpeed = 0,
		arrive = 8,
		adds = 0,
		hp = 12,
		damage = 22,
		attackRange = 100,
		attackRadius = 8,
		attackInterval = 10,
		windup = 1,
		opening = 0,
		deathHold = 1.5,
	}
	copy.waves = {
		{ count = 2, kind = "chaser" },
		{ count = 1, kind = "boss", adds = 0 },
	}
	copy.mix = { { "chaser" }, { "chaser" } }
	copy.loot = {
		pickupRadius = 12,
		bagSlots = 100,
		drops = WaveArenaConfig.loot.drops,
		waveTokens = { 1, 5 },
	}
	return copy
end

local function opened(config: any): any
	return {
		launchGate = { waveArena = true },
		config = config,
		receiptId = "settle-spec",
	}
end

local function profile(): any
	return {
		shardTokens = 4,
		inventory = {},
		pets = {},
		receipts = {},
		arenaMail = {},
		ledger = {},
	}
end

local function findMetric(events: { any }, name: string): any
	for _, event in ipairs(events) do
		if event.kind == "metric" and event.name == name then
			return event
		end
	end
	return nil
end

describe("Wave arena settle", function()
	it("auto-collects ground loot once at the end of a wave", function()
		local config = fightConfig()
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		local _, first = WaveArena.step(run, 0.5, { attack = true }, options)
		expect(findMetric(first, "gateSpent") ~= nil).toBeTrue()
		expect(findMetric(first, "waveClear")).toBeNil()
		expect(#run.ground).toEqual(1)
		expect(run.earned.fragments).toEqual(0)

		local _, second = WaveArena.step(run, 0.5, { attack = true }, options)
		expect(run.wave).toEqual(2)
		expect(#run.ground).toEqual(0)
		expect(run.earned.fragments).toEqual(2)
		expect(run.earned.tokens).toEqual(1)
		expect(findMetric(second, "waveClear") ~= nil).toBeTrue()
		expect(findMetric(second, "waveClear").wave).toEqual(1)
		expect(findMetric(second, "bossEnter") ~= nil).toBeTrue()
		expect(run.enemies[1].kind).toEqual("boss")

		WaveArena.step(run, 0.5, {}, options)
		expect(run.earned.fragments).toEqual(2)
		expect(run.earned.tokens).toEqual(1)

		local saved = profile()
		local done = Session.exit(saved, run, "disconnect", options)
		expect(done.inArena).toEqual(false)
		expect(done.position).toEqual("hub")
		expect(run.reason).toEqual("disconnect")
		expect(saved.shardTokens).toEqual(5)
		expect(saved.arenaMail[1].fragments).toEqual(2)
		local again = Session.exit(saved, run, "wipe", options)
		expect(again.position).toEqual("hub")
		expect(saved.shardTokens).toEqual(5)
		expect(saved.arenaMail[1].count).toEqual(2)
		expect(saved.arenaMail[1].fragments).toEqual(2)
	end)

	it("collects a chip once on wipe and does not pay the uncleared purse", function()
		local config = fightConfig()
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		WaveArena.step(run, 0.5, { attack = true }, options)
		expect(#run.ground).toEqual(1)
		run.player.hp = 0
		local _, wiped = WaveArena.step(run, 0.5, {}, options)
		expect(run.reason).toEqual("wipe")
		expect(run.phase).toEqual("results")
		expect(run.earned.fragments).toEqual(1)
		expect(run.earned.tokens).toEqual(0)
		expect(#run.ground).toEqual(0)
		expect(findMetric(wiped, "run_end").reason).toEqual("wipe")

		local saved = profile()
		Session.exit(saved, run, "wipe", options)
		Session.exit(saved, run, "disconnect", options)
		expect(saved.shardTokens).toEqual(4)
		expect(saved.arenaMail[1].fragments).toEqual(1)
		expect(saved.arenaMail[1].count).toEqual(1)
		expect(saved.arenaMail[1].where).toEqual("bag")
	end)

	it("sends a full bag to the mailbox and does not drop the chip", function()
		local config = fightConfig()
		config.loot.bagSlots = 0
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		WaveArena.step(run, 0.5, { attack = true }, options)
		WaveArena.settle(run, "wipe", options)
		expect(#run.earned.drops).toEqual(0)
		expect(#run.earned.mailbox).toEqual(1)
		expect(run.earned.fragments).toEqual(1)

		local saved = profile()
		local grant = Loot.commit(saved, run, 0)
		expect(grant.mailed).toEqual(1)
		expect(grant.bag).toEqual(0)
		expect(saved.arenaMail[1].where).toEqual("mailbox")
		expect(saved.arenaMail[1].fragments).toEqual(1)
		local repeatGrant = Loot.commit(saved, run, 0)
		expect(repeatGrant.mailed).toEqual(0)
		expect(saved.arenaMail[1].count).toEqual(1)

		local packed = profile()
		for index = 1, 100 do
			packed.inventory["slot" .. tostring(index)] = { uid = "slot" .. tostring(index) }
		end
		local bagRun = {
			receiptId = "bag-full",
			grantList = {
				{
					key = "drop:1",
					kind = "drop",
					dropId = "shard_chip",
					tokens = 0,
					fragments = 3,
					wave = 1,
					where = "bag",
				},
			},
		}
		local flipped = Loot.commit(packed, bagRun, 100)
		expect(flipped.mailed).toEqual(1)
		expect(flipped.bag).toEqual(0)
		expect(packed.arenaMail[1].where).toEqual("mailbox")
		expect(packed.arenaMail[1].fragments).toEqual(3)
		Loot.commit(packed, bagRun, 100)
		expect(packed.arenaMail[1].count).toEqual(1)
	end)

	it("keeps loot once on rejoin and never restores the arena", function()
		local config = fightConfig()
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		WaveArena.step(run, 0.5, { attack = true }, options)
		local saved = profile()
		local left = Session.exit(saved, run, "disconnect", options)
		expect(left.inArena).toEqual(false)
		expect(left.position).toEqual("hub")
		expect(saved.arenaMail[1].fragments).toEqual(1)
		local back = Session.rejoin(saved, run, "arena")
		expect(back.inArena).toEqual(false)
		expect(back.position).toEqual("hub")
		expect(back.stranded).toEqual(false)
		expect(saved.shardTokens).toEqual(4)
		expect(saved.arenaMail[1].fragments).toEqual(1)
		expect(saved.arenaMail[1].count).toEqual(1)
	end)

	it("refuses remotes and the arena teleport unless the server flag is on", function()
		expect(Session.remoteOk(false, true, "enter")).toEqual(false)
		expect(Session.remoteOk(false, true, "step")).toEqual(false)
		expect(Session.teleport(false, true)).toEqual("hub")
		expect(Session.teleport(true, false)).toEqual("hub")
		expect(Session.teleport(true, true)).toEqual("arena")
		expect(Session.remoteOk(true, false, "step")).toEqual(false)
		expect(Session.remoteOk(true, false, "skip")).toEqual(false)
		expect(Session.remoteOk(true, false, "boss")).toEqual(false)
		expect(Session.remoteOk(true, true, "leave")).toEqual(false)
		expect(Session.remoteOk(true, true, "enter")).toEqual(true)
		expect(Session.remoteOk(true, true, "step")).toEqual(true)
		expect(Session.remoteOk(true, false, "state")).toEqual(true)
	end)

	it("ends a long run on timeout and still keeps the chip", function()
		local config = fightConfig()
		config.timeout = 1
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		WaveArena.step(run, 0.5, { attack = true }, options)
		expect(run.phase).toEqual("fight")
		expect(#run.ground).toEqual(1)
		local _, done = WaveArena.step(run, 0.5, {}, options)
		expect(run.reason).toEqual("timeout")
		expect(run.phase).toEqual("results")
		expect(run.earned.fragments).toEqual(1)
		expect(run.earned.tokens).toEqual(0)
		expect(#run.ground).toEqual(0)
		local card = nil
		for _, event in ipairs(done) do
			if event.kind == "results" then
				card = event
			end
		end
		expect(card.reason).toEqual("timeout")
		expect(card.loot.fragments).toEqual(1)
	end)

	it("keeps schemaVersion 26 and copies arena mail", function()
		expect(Schema.VERSION).toEqual(26)
		expect(#Schema.template().arenaMail).toEqual(0)
		local row = {
			id = "shard_chip",
			fragments = 3,
			tokens = 1,
			count = 2,
			where = "mailbox",
			wave = 4,
		}
		local migrated = Schema.migrate({
			schemaVersion = 26,
			gold = 1,
			arenaMail = { row, { id = "" }, "junk" },
		})
		expect(migrated ~= nil).toBeTrue()
		local data = migrated :: any
		expect(data.schemaVersion).toEqual(26)
		expect(data.gold).toEqual(1)
		expect(#data.arenaMail).toEqual(1)
		expect(data.arenaMail[1].id).toEqual("shard_chip")
		expect(data.arenaMail[1].fragments).toEqual(3)
		expect(data.arenaMail[1].where).toEqual("mailbox")
		expect(data.arenaMail[1].count).toEqual(2)
		local snap = Schema.snapshot(data)
		snap.arenaMail[1].fragments = 9
		expect(data.arenaMail[1].fragments).toEqual(3)
		local junk = Schema.migrate({ schemaVersion = 26, gold = 1, arenaMail = "nope" })
		expect(#(junk :: any).arenaMail).toEqual(0)
		expect((junk :: any).schemaVersion).toEqual(26)
	end)
end)
