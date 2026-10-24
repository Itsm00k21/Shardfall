--!strict

--[[
	Alive cap and gray-box pool. Numbers live in Config/Enemies.
	WaveFlowService queues past the cap and reuses blocks. The flag
	stays off, so boot does not spawn, the HUD is untouched, and the
	save schema stays 26.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Enemies = require("../src/ReplicatedStorage/Shared/Config/Enemies")
local EnemyPool = require("../src/ServerScriptService/ShardfallServer/EnemyPool")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local WaveFlow = require("../src/ReplicatedStorage/Shared/WaveFlow")
local WaveFlowService = require("../src/ServerScriptService/ShardfallServer/WaveFlowService")

local function withFlag(on: boolean, body: () -> ())
	local prior = LaunchGate.SHOW.enemyTypes
	LaunchGate.SHOW.enemyTypes = on
	local ok, err = pcall(body)
	LaunchGate.SHOW.enemyTypes = prior
	if not ok then
		error(err :: any, 0)
	end
end

local function luaFiles(dir: string): { string }
	local found = {}
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			for _, child in ipairs(luaFiles(path)) do
				table.insert(found, child)
			end
		elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
			table.insert(found, path)
		end
	end
	return found
end

local function roster(patch: { [string]: any }?): any
	local source = {
		ORDER = Enemies.ORDER,
		TYPES = Enemies.TYPES,
		SHARED = Enemies.SHARED,
		STEP_MAX = Enemies.STEP_MAX,
		PREVIEW_GAP = Enemies.PREVIEW_GAP,
		PREVIEW_LIFT = Enemies.PREVIEW_LIFT,
		ARENA = {
			minX = Enemies.ARENA.minX,
			maxX = Enemies.ARENA.maxX,
			minZ = Enemies.ARENA.minZ,
			maxZ = Enemies.ARENA.maxZ,
		},
		SHOT_Y = Enemies.SHOT_Y,
		LOS_PAD = Enemies.LOS_PAD,
		WAVE_COUNTS = Enemies.WAVE_COUNTS,
		WAVE_ORDER = Enemies.WAVE_ORDER,
		WAVE_MIXES = Enemies.WAVE_MIXES,
		WAVE_GAP = Enemies.WAVE_GAP,
		WAVE_LIFT = Enemies.WAVE_LIFT,
		MAX_ALIVE = Enemies.MAX_ALIVE,
		PLATFORM_CAP = {
			mobile = Enemies.PLATFORM_CAP.mobile,
		},
		BOSS = Enemies.BOSS,
		BOSS_ADDS = Enemies.BOSS_ADDS,
		BOSS_WAVE = Enemies.BOSS_WAVE,
		BOSS_ADD_MIX = {
			chaser = Enemies.BOSS_ADD_MIX.chaser,
			ranged = Enemies.BOSS_ADD_MIX.ranged,
			tank = Enemies.BOSS_ADD_MIX.tank,
		},
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			source[key] = value
		end
	end
	return source
end

local function fight(run: WaveFlow.Run, sink: WaveFlowService.Sink, cap: number)
	local kills = { 0, 0, 0, 0, 0 }
	local peak = { 0, 0, 0, 0, 0 }
	local opened = {}
	local queued = {}
	local guard = 0
	while run.clear ~= true do
		guard += 1
		expect(guard <= 41).toBeTrue()
		local wave = run.wave
		expect(wave >= 1 and wave <= 5).toBeTrue()
		local boxes = WaveFlow.boxes(run)
		expect(#boxes > 0).toBeTrue()
		expect(#boxes <= cap).toBeTrue()
		if peak[wave] < #boxes then
			peak[wave] = #boxes
		end
		if opened[wave] == nil then
			opened[wave] = WaveFlow.counter(run).left
			queued[wave] = #run.queue
		end
		local stats = WaveFlowService.pool(run)
		expect(stats ~= nil).toBeTrue()
		if stats ~= nil then
			expect(stats.inUse).toEqual(#boxes)
			expect(stats.created <= cap).toBeTrue()
		end
		local taken = WaveFlowService.hurt(run, boxes[1].id, 100000, sink)
		expect(taken > 0).toBeTrue()
		kills[wave] += 1
	end
	expect(kills).toEqual({ 6, 8, 10, 12, 5 })
	expect(opened).toEqual({ 6, 8, 10, 12, 5 })
	expect(peak[4]).toEqual(math.min(12, cap))
	expect(peak[5]).toEqual(math.min(5, cap))
	expect(queued[4]).toEqual(12 - math.min(12, cap))
	expect(queued[5]).toEqual(5 - math.min(5, cap))
	for wave = 1, 5 do
		expect(peak[wave] <= cap).toBeTrue()
	end
	expect(run.clear).toEqual(true)
	expect(WaveFlowService.counter(run)).toEqual({ wave = 5, left = 0 })
	local stats = WaveFlowService.pool(run)
	expect(stats ~= nil).toBeTrue()
	if stats ~= nil then
		expect(stats.created).toEqual(cap)
		expect(stats.inUse).toEqual(0)
		expect(stats.free).toEqual(cap)
	end
	return kills
end

describe("Config enemy cap", function()
	it("stores a max-alive cap and an optional phone cap", function()
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		expect(Enemies.MAX_ALIVE).toEqual(8)
		expect(Enemies.MAX_ALIVE < 12).toBeTrue()
		expect(Enemies.PLATFORM_CAP.mobile).toEqual(4)
		expect(Enemies.PLATFORM_CAP.mobile < 5).toBeTrue()
		expect(Enemies.PLATFORM_CAP.mobile <= Enemies.MAX_ALIVE).toBeTrue()
		expect(Enemies.aliveCap(nil)).toEqual(Enemies.MAX_ALIVE)
		expect(Enemies.aliveCap("desktop")).toEqual(Enemies.MAX_ALIVE)
		expect(Enemies.aliveCap("mobile")).toEqual(Enemies.PLATFORM_CAP.mobile)
		local ok, err = Enemies.validate()
		expect(ok).toEqual(true)
		expect(err).toEqual("")
		expect(Enemies.validate(roster())).toEqual(true)

		local missing = roster()
		missing.MAX_ALIVE = nil
		local _, missingErr = Enemies.validate(missing)
		expect(string.find(missingErr, "MAX_ALIVE", 1, true) ~= nil).toBeTrue()

		local _, zeroErr = Enemies.validate(roster({ MAX_ALIVE = 0 }))
		expect(string.find(zeroErr, "MAX_ALIVE", 1, true) ~= nil).toBeTrue()

		local _, fracErr = Enemies.validate(roster({ MAX_ALIVE = 1.5 }))
		expect(string.find(fracErr, "integer", 1, true) ~= nil).toBeTrue()

		local _, nanErr = Enemies.validate(roster({ MAX_ALIVE = 0 / 0 }))
		expect(string.find(nanErr, "MAX_ALIVE", 1, true) ~= nil).toBeTrue()

		local openCap = roster()
		openCap.PLATFORM_CAP = nil
		expect(Enemies.validate(openCap)).toEqual(true)

		expect(Enemies.validate(roster({
			PLATFORM_CAP = { mobile = 4, desktop = Enemies.MAX_ALIVE, console = 6 },
		}))).toEqual(true)

		local _, highErr = Enemies.validate(roster({
			PLATFORM_CAP = { mobile = Enemies.MAX_ALIVE + 1 },
		}))
		expect(string.find(highErr, "above MAX_ALIVE", 1, true) ~= nil).toBeTrue()

		local _, mobileZero = Enemies.validate(roster({
			PLATFORM_CAP = { mobile = 0 },
		}))
		expect(string.find(mobileZero, "PLATFORM_CAP.mobile", 1, true) ~= nil).toBeTrue()

		local _, keyErr = Enemies.validate(roster({
			PLATFORM_CAP = { phone = 4 },
		}))
		expect(string.find(keyErr, "mobile, desktop, or console", 1, true) ~= nil).toBeTrue()

		local boot = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/WaveFlowService.luau")
		local pool = fs.readFile("src/ServerScriptService/ShardfallServer/EnemyPool.luau")
		expect(string.find(boot, "EnemyPool", 1, true)).toBeNil()
		expect(string.find(boot, "WaveFlowService", 1, true)).toBeNil()
		expect(string.find(service, "Instance.new", 1, true)).toBeNil()
		expect(string.find(pool, ":Destroy()", 1, true)).toBeNil()
		for _, source in ipairs({ service, pool }) do
			expect(string.find(source, "schemaVersion", 1, true)).toBeNil()
			expect(string.find(source, "DataService", 1, true)).toBeNil()
			expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
		end
		for _, path in ipairs(luaFiles("src/StarterPlayer")) do
			local body = fs.readFile(path)
			expect(string.find(body, "EnemyPool", 1, true)).toBeNil()
			expect(string.find(body, "MAX_ALIVE", 1, true)).toBeNil()
		end
		expect(WaveFlowService.start({ platform = "mobile" })).toBeNil()
		expect(WaveFlowService.pool(nil)).toBeNil()
		expect(WaveFlowService.body(nil, 1)).toBeNil()
	end)
end)

describe("EnemyPool", function()
	it("reuses a block and resets health, target, and projectile", function()
		local destroyed = 0
		local pool = EnemyPool.create(function(kind: string)
			return {
				Name = kind,
				health = -1,
				target = "stale",
				projectile = { remaining = 1 },
				Destroy = function()
					destroyed += 1
				end,
			}
		end)
		local first = pool.acquire("chaser")
		local second = pool.acquire("tank")
		expect(first == second).toBeFalse()
		expect(pool.stats().created).toEqual(2)
		expect(pool.stats().inUse).toEqual(2)
		local firstPart = first.part
		local secondPart = second.part
		first.health = 1
		first.target = "hero"
		first.projectile = { remaining = 4 }
		first.part.health = 1
		first.part.target = "hero"
		first.part.projectile = { remaining = 4 }
		second.health = 2
		second.target = "other"
		second.projectile = { remaining = 8 }
		second.part.health = 2
		second.part.target = "other"
		second.part.projectile = { remaining = 8 }
		pool.release(first)
		pool.release(second)
		pool.release(second)
		expect(pool.stats().inUse).toEqual(0)
		expect(pool.stats().free).toEqual(2)
		expect(destroyed).toEqual(0)
		local again = pool.acquire("ranged")
		expect(again == first or again == second).toBeTrue()
		expect(again.part == firstPart or again.part == secondPart).toBeTrue()
		expect(pool.stats().created).toEqual(2)
		expect(again.health).toEqual(Enemies.TYPES.ranged.maxHealth)
		expect(again.target).toBeNil()
		expect(again.projectile).toBeNil()
		expect(again.part.health).toEqual(Enemies.TYPES.ranged.maxHealth)
		expect(again.part.target).toBeNil()
		expect(again.part.projectile).toBeNil()
		expect(again.part.Name).toEqual("ranged")
		expect(destroyed).toEqual(0)
	end)
end)

describe("WaveFlowService enemy cap", function()
	it("reuses the pooled block when a queued enemy spawns", function()
		withFlag(true, function()
			local sink: WaveFlowService.Sink = {
				player = "hero",
				platform = "mobile",
			}
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			expect(run.cap).toEqual(Enemies.PLATFORM_CAP.mobile)
			expect(#WaveFlow.boxes(run)).toEqual(Enemies.PLATFORM_CAP.mobile)
			expect(WaveFlow.counter(run)).toEqual({ wave = 1, left = 6 })
			local box = WaveFlow.boxes(run)[1]
			local body = WaveFlowService.body(run, box.id)
			expect(body ~= nil).toBeTrue()
			if body == nil then
				return
			end
			local part = body.part
			local before = WaveFlowService.pool(run)
			expect(before ~= nil and before.created == Enemies.PLATFORM_CAP.mobile).toBeTrue()
			body.health = 1
			body.target = "stale"
			body.projectile = { remaining = 9 }
			part.health = 1
			part.target = "stale"
			part.projectile = { remaining = 9 }
			local taken = WaveFlowService.hurt(run, box.id, 100000, sink)
			expect(taken > 0).toBeTrue()
			expect(#WaveFlow.boxes(run) <= Enemies.PLATFORM_CAP.mobile).toBeTrue()
			local reused = false
			for _, nextBox in ipairs(WaveFlow.boxes(run)) do
				if WaveFlowService.body(run, nextBox.id) == body then
					reused = true
					expect(nextBox.id ~= box.id).toBeTrue()
					expect(nextBox.kind).toEqual("ranged")
					expect(body.health).toEqual(Enemies.TYPES.ranged.maxHealth)
					expect(body.target).toBeNil()
					expect(body.projectile).toBeNil()
					expect(body.part == part).toBeTrue()
					expect(part.health).toEqual(Enemies.TYPES.ranged.maxHealth)
					expect(part.target).toBeNil()
					expect(part.projectile).toBeNil()
				end
			end
			expect(reused).toBeTrue()
			expect(WaveFlowService.body(run, box.id)).toBeNil()
			local after = WaveFlowService.pool(run)
			expect(after ~= nil and after.created == Enemies.PLATFORM_CAP.mobile).toBeTrue()
		end)
	end)

	it("never exceeds the server cap on wave 4 or the boss wave", function()
		withFlag(true, function()
			local wave5 = {}
			local sink: WaveFlowService.Sink = {
				player = "hero",
				build = function(box)
					if box.wave == 5 then
						table.insert(wave5, box.kind)
					end
				end,
			}
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local cap = Enemies.MAX_ALIVE
			expect(run.cap).toEqual(cap)
			expect(12 > cap).toBeTrue()
			expect(5 <= cap).toBeTrue()
			fight(run, sink, cap)
			expect(wave5).toEqual({ "boss", "chaser", "chaser", "ranged", "tank" })
			expect(Schema.VERSION).toEqual(26)
		end)
	end)

	it("never exceeds the phone cap on wave 4 or the boss wave", function()
		withFlag(true, function()
			local wave5 = {}
			local sink: WaveFlowService.Sink = {
				player = "hero",
				platform = "mobile",
				build = function(box)
					if box.wave == 5 then
						table.insert(wave5, box.kind)
					end
				end,
			}
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local cap = Enemies.PLATFORM_CAP.mobile
			expect(run.cap).toEqual(cap)
			expect(12 > cap).toBeTrue()
			expect(5 > cap).toBeTrue()
			fight(run, sink, cap)
			expect(wave5).toEqual({ "boss", "chaser", "chaser", "ranged", "tank" })
			expect(WaveFlow.counter(run)).toEqual({ wave = 5, left = 0 })
			expect(Schema.VERSION).toEqual(26)
		end)
	end)
end)
