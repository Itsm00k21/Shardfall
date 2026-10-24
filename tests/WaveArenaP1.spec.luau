--!strict

--[[
	Havoc P1. One settlement per run id, and a server wave clock.

	PlayerRemoving before or after the run ends pays once. A failed save
	leaves the id open so the retry pays once. A forged client time step
	cannot speed the wave or the attack cooldown.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Essence = require("../src/ReplicatedStorage/Shared/Config/Essence")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Session = require("../src/server/WaveArena/Session")
local Settle = require("../src/server/WaveArena/Settle")
local WaveArena = require("../src/server/WaveArena")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")

local function fightConfig(): any
	local copy = table.clone(WaveArenaConfig)
	copy.enabled = true
	copy.timeout = 1
	copy.player = {
		hp = 500,
		damage = 12,
		range = 100,
		interval = 0.45,
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
	copy.waves = {
		{ count = 2, kind = "chaser" },
	}
	copy.mix = { { "chaser" }, { "chaser" } }
	copy.loot = {
		pickupRadius = 12,
		bagSlots = 0,
		overflowCap = 40,
		drops = WaveArenaConfig.loot.drops,
		waveTokens = { 1, 5 },
	}
	return copy
end

local function opened(config: any, receiptId: string): any
	return {
		launchGate = { waveArena = true },
		config = config,
		receiptId = receiptId,
	}
end

local function profile(): any
	return {
		shardTokens = 4,
		gearEssence = 7,
		inventory = {},
		pets = {},
		receipts = {},
		ledger = {},
	}
end

local function alive(run: any): number
	local count = 0
	for _, enemy in ipairs(run.enemies) do
		if enemy.alive then
			count += 1
		end
	end
	return count
end

local function heldRun(receiptId: string): (any, any, any)
	local config = fightConfig()
	local options = opened(config, receiptId)
	local run = WaveArena.enter(options) :: any
	WaveArena.step(run, 0.5, { attack = true }, options)
	expect(run.settled).toEqual(false)
	expect(alive(run)).toEqual(1)
	expect(#run.ground).toEqual(1)
	expect(run.earned.fragments).toEqual(0)
	return run, options, config
end

local function rollback(saved: any)
	saved.gearEssence = 7
	saved.shardTokens = 4
	saved.receipts = {}
	saved.ledger = {}
	saved.arenaMail = nil
	-- A failed save reverts the run id with the rest of the profile.
	saved.arenaSettle = nil
end

describe("Wave arena P1 settlement", function()
	it("pays held loot once when PlayerRemoving runs before the run ends", function()
		local run, options = heldRun("p1-before")
		local saved = profile()
		local book = Settle.book()
		local rate = Essence.amount("Common")
		local function save(): boolean
			return true
		end

		local first, grant = Settle.finish(book, saved, run, "disconnect", options, save)
		expect(first).toEqual("paid")
		expect(grant.essence).toEqual(rate)
		expect(run.settled).toEqual(true)
		expect(run.reason).toEqual("disconnect")
		expect(#run.earned.overflow).toEqual(1)
		expect(saved.gearEssence).toEqual(7 + rate)
		expect(saved.shardTokens).toEqual(4)
		expect(saved.arenaMail).toBeNil()
		expect(Settle.done(book, Settle.id(run))).toEqual(true)

		local ended, again = Settle.finish(book, saved, run, "clear", options, save)
		expect(ended).toEqual("again")
		expect(again.essence).toEqual(0)
		expect(again.tokens).toEqual(0)
		expect(saved.gearEssence).toEqual(7 + rate)
		expect(run.earned.fragments).toEqual(1)
	end)

	it("pays held loot once when PlayerRemoving runs after the run ends", function()
		local run, options = heldRun("p1-after")
		local saved = profile()
		local book = Settle.book()
		local rate = Essence.amount("Common")
		local function save(): boolean
			return true
		end

		local ended, grant = Settle.finish(book, saved, run, "clear", options, save)
		expect(ended).toEqual("paid")
		expect(grant.essence).toEqual(rate)
		expect(run.reason).toEqual("clear")
		expect(saved.gearEssence).toEqual(7 + rate)

		local removed, again = Settle.finish(book, saved, run, "disconnect", options, save)
		expect(removed).toEqual("again")
		expect(again.essence).toEqual(0)
		expect(saved.gearEssence).toEqual(7 + rate)
		expect(saved.shardTokens).toEqual(4)
		expect(Settle.done(book, run.receiptId)).toEqual(true)
	end)

	it("pays once on teleport and on shutdown, then ignores PlayerRemoving", function()
		local rate = Essence.amount("Common")
		for _, reason in ipairs({ "teleport", "shutdown" }) do
			local run, options = heldRun("p1-" .. reason)
			local saved = profile()
			local book = Settle.book()
			local function save(): boolean
				return true
			end
			local first, grant = Settle.finish(book, saved, run, reason, options, save)
			expect(first).toEqual("paid")
			expect(grant.essence).toEqual(rate)
			expect(run.reason).toEqual(reason)
			expect(saved.gearEssence).toEqual(7 + rate)
			local removed, again = Settle.finish(book, saved, run, "disconnect", options, save)
			expect(removed).toEqual("again")
			expect(again.essence).toEqual(0)
			expect(saved.gearEssence).toEqual(7 + rate)
			expect(saved.arenaMail).toBeNil()
		end
	end)

	it("retries a failed save once and does not pay a third time", function()
		local run, options = heldRun("p1-retry")
		local saved = profile()
		local book = Settle.book()
		local rate = Essence.amount("Common")
		local fails = 3
		local function failSave(): boolean
			fails -= 1
			rollback(saved)
			return false
		end

		local failed, lost = Settle.finish(book, saved, run, "disconnect", options, failSave)
		expect(failed).toEqual("retry")
		expect(fails).toEqual(0)
		expect(lost.essence).toEqual(rate)
		expect(Settle.done(book, run.receiptId)).toEqual(false)
		expect(saved.gearEssence).toEqual(7)
		expect(saved.shardTokens).toEqual(4)
		expect(next(saved.receipts) == nil).toBeTrue()
		expect(run.settled).toEqual(true)

		local paid = false
		local function okSave(): boolean
			paid = true
			return true
		end
		local retried, grant = Settle.finish(book, saved, run, "disconnect", options, okSave)
		expect(retried).toEqual("paid")
		expect(paid).toEqual(true)
		expect(grant.essence).toEqual(rate)
		expect(saved.gearEssence).toEqual(7 + rate)
		expect(saved.shardTokens).toEqual(4)
		expect(Settle.done(book, run.receiptId)).toEqual(true)

		local third, extra = Settle.finish(book, saved, run, "clear", options, okSave)
		expect(third).toEqual("again")
		expect(extra.essence).toEqual(0)
		expect(saved.gearEssence).toEqual(7 + rate)
	end)

	it("keeps schemaVersion 26 with no arena mail field", function()
		expect(Schema.VERSION).toEqual(26)
		expect(Schema.template().arenaMail).toBeNil()
		expect(WaveArenaConfig.enabled).toEqual(false)
	end)
end)

describe("Wave arena P1 clock", function()
	it("ignores a forged 12x client step", function()
		local config = fightConfig()
		local options = opened(config, "p1-clock")
		local run = WaveArena.enter(options) :: any
		local now = 1000
		for _ = 1, 12 do
			Session.clientStep(run, now, 0.5, { attack = true }, options)
		end
		expect(run.seconds).toBeCloseTo(0.1)
		expect(run.clock).toEqual(now)
		expect(alive(run)).toEqual(1)
		expect(run.phase).toEqual("fight")
		expect(run.settled).toEqual(false)
		expect(run.earned.tokens).toEqual(0)
		expect(run.earned.fragments).toEqual(0)

		Session.clientStep(run, now, 6, { attack = true }, options)
		expect(run.seconds).toBeCloseTo(0.1)
		expect(alive(run)).toEqual(1)

		Session.clientStep(run, now + 0.1, 6, { attack = true }, options)
		expect(run.seconds).toBeCloseTo(0.2)
		expect(run.player.cooldown).toBeCloseTo(0.35)
		expect(alive(run)).toEqual(1)
		expect(run.phase).toEqual("fight")
		expect(run.reason).toBeNil()
	end)

	it("settles from save, teleport, and shutdown without reading client dt", function()
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "payload.dt", 1, true)).toBeNil()
		expect(string.find(host, "session.clock", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "function WaveArenaHost.settle", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "function WaveArenaHost.shutdown", 1, true) ~= nil).toBeTrue()

		local server = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		expect(string.find(server, "DataService.beforeSave", 1, true) ~= nil).toBeTrue()
		expect(string.find(server, "game:BindToClose", 1, true) ~= nil).toBeTrue()
		expect(string.find(server, "WaveArenaHost).shutdown", 1, true) ~= nil).toBeTrue()
		local disconnect = string.find(server, "WaveArenaHost).disconnect", 1, true)
		local release = string.find(server, "DataService.start()", 1, true)
		expect(disconnect ~= nil and release ~= nil and (disconnect :: number) < (release :: number)).toBeTrue()

		local data = fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
		local releaseAt = string.find(data, "function DataService.release(player: Player)", 1, true)
		local beforeLeave = string.find(data, 'runBeforeSave(player, "disconnect")', releaseAt :: number, true)
		local closingWait = string.find(data, "while record.closing do", releaseAt :: number, true)
		expect(beforeLeave ~= nil and closingWait ~= nil and (beforeLeave :: number) < (closingWait :: number)).toBeTrue()
		local teleportAt = string.find(data, "function DataService.releaseForTeleport", 1, true)
		local beforeHop = string.find(data, 'runBeforeSave(player, "teleport")', teleportAt :: number, true)
		local closing = string.find(data, "record.closing = true", teleportAt :: number, true)
		expect(beforeHop ~= nil and closing ~= nil and (beforeHop :: number) < (closing :: number)).toBeTrue()
		expect(string.find(data, "function DataService.save", 1, true) ~= nil).toBeTrue()
		local saveAt = string.find(data, "function DataService.save", 1, true)
		local nextFn = string.find(data, "\nfunction ", (saveAt :: number) + 1, true)
		local saveBody = string.sub(data, saveAt :: number, (nextFn or (saveAt :: number + 1)) - 1)
		expect(string.find(saveBody, "beforeSave", 1, true)).toBeNil()
	end)
end)
