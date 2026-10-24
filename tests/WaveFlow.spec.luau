--!strict

--[[
	Roadmap 3.5. Wave sizes and mixes live in Config/Enemies. The server
	flow stays idle while LaunchGate.enemyTypes is off. The counter is a
	server push. No client HUD file reads it.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Drops = require("../src/ReplicatedStorage/Shared/Drops")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Enemies = require("../src/ReplicatedStorage/Shared/Config/Enemies")
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

local function waveRoster(counts: { number }, mixes: { any }): any
	return {
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
		WAVE_COUNTS = counts,
		WAVE_ORDER = Enemies.WAVE_ORDER,
		WAVE_MIXES = mixes,
		WAVE_GAP = Enemies.WAVE_GAP,
		WAVE_LIFT = Enemies.WAVE_LIFT,
	}
end

local function fullRoster(patch: { [string]: any }?): any
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
		PLATFORM_CAP = Enemies.PLATFORM_CAP,
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

local function copyBoss(): any
	local copy = {}
	for key, value in pairs(Enemies.BOSS) do
		if type(value) == "table" then
			local inner = {}
			for index, part in ipairs(value) do
				inner[index] = part
			end
			copy[key] = inner
		else
			copy[key] = value
		end
	end
	return copy
end

local function shippedMixes(): { any }
	local mixes = {}
	for index, mix in ipairs(Enemies.WAVE_MIXES) do
		mixes[index] = {
			chaser = mix.chaser,
			ranged = mix.ranged,
			tank = mix.tank,
		}
	end
	return mixes
end

type Note = {
	player: any,
	wave: number,
	left: number,
	fields: number,
}

local function watch(): ({ Note }, WaveFlowService.Sink, { WaveFlow.Box })
	local sent: { Note } = {}
	local built: { WaveFlow.Box } = {}
	local sink: WaveFlowService.Sink = {
		player = "hero",
		fire = function(player, payload)
			local fields = 0
			for key in pairs(payload) do
				fields += 1
				expect(key == "wave" or key == "left").toBeTrue()
			end
			table.insert(sent, {
				player = player,
				wave = payload.wave,
				left = payload.left,
				fields = fields,
			})
		end,
		build = function(box)
			table.insert(built, box)
			return box.id
		end,
	}
	return sent, sink, built
end

local function killLiving(run: WaveFlow.Run, sink: WaveFlowService.Sink, times: number)
	for _ = 1, times do
		local boxes = WaveFlow.boxes(run)
		expect(#boxes > 0).toBeTrue()
		local taken = WaveFlowService.hurt(run, boxes[1].id, 100000, sink)
		expect(taken > 0).toBeTrue()
	end
end

describe("Config wave list", function()
	it("keeps the roster flag off and does not boot the flow", function()
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		expect(LaunchGate.on("enemyTypes")).toEqual(false)
		expect(LaunchGate.SHOW.waveFlow).toBeNil()
		expect(WaveFlowService.open()).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		local boot = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(boot, "WaveFlowService", 1, true)).toBeNil()
		expect(string.find(boot, "WaveCounter", 1, true)).toBeNil()
		expect(string.find(dungeon, "WaveFlow", 1, true)).toBeNil()
		expect(string.find(dungeon, "WaveCounter", 1, true)).toBeNil()
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/WaveFlowService.luau")
		local math = fs.readFile("src/ReplicatedStorage/Shared/WaveFlow.luau")
		for _, source in ipairs({ service, math }) do
			expect(string.find(source, "schemaVersion", 1, true)).toBeNil()
			expect(string.find(source, "DataService", 1, true)).toBeNil()
			expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
			expect(string.find(source, "Instance.new", 1, true)).toBeNil()
		end
		expect(string.find(service, 'LaunchGate.on("enemyTypes")', 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "bossEnter", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "bossDown", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "AnalyticsService", 1, true)).toBeNil()
		local analyticsFile = pcall(function()
			fs.readFile("src/ReplicatedStorage/Shared/Analytics.luau")
		end)
		expect(analyticsFile).toEqual(false)
	end)

	it("stores 6, 8, 10, and 12 as mixes of the three types", function()
		expect(Enemies.WAVE_COUNTS).toEqual({ 6, 8, 10, 12 })
		expect(Enemies.WAVE_ORDER).toEqual({ "chaser", "ranged", "tank" })
		expect(#Enemies.WAVE_MIXES).toEqual(4)
		local expected = { 6, 8, 10, 12 }
		for index, count in ipairs(expected) do
			local mix = Enemies.WAVE_MIXES[index]
			local sum = mix.chaser + mix.ranged + mix.tank
			expect(sum).toEqual(count)
			expect(mix.chaser >= 1 and mix.ranged >= 1 and mix.tank >= 1).toBeTrue()
			local plan = WaveFlow.plan(index)
			expect(plan ~= nil).toBeTrue()
			if plan ~= nil then
				expect(#plan).toEqual(count)
				expect(plan[1]).toEqual("chaser")
				expect(plan[mix.chaser]).toEqual("chaser")
				expect(plan[mix.chaser + 1]).toEqual("ranged")
				expect(plan[count]).toEqual("tank")
			end
		end
		expect(WaveFlow.plan(1)).toEqual({ "chaser", "chaser", "chaser", "chaser", "ranged", "tank" })
		expect(WaveFlow.plan(0)).toBeNil()
		expect(WaveFlow.plan(6)).toBeNil()
	end)

	it("stores the wave-5 boss and four adds drawn from the three types", function()
		expect(Enemies.BOSS_WAVE).toEqual(5)
		expect(Enemies.BOSS_ADDS).toEqual(4)
		expect(Enemies.BOSS.id).toEqual("boss")
		expect(Enemies.BOSS.role).toEqual("boss")
		expect(Enemies.BOSS.maxHealth > Enemies.TYPES.tank.maxHealth).toBeTrue()
		expect(Enemies.BOSS.size[2] > Enemies.TYPES.tank.size[2]).toBeTrue()
		expect(Enemies.BOSS.phase2At > 0 and Enemies.BOSS.phase2At <= 1).toBeTrue()
		expect(Enemies.BOSS.damageTaken).toEqual(1)
		local mix = Enemies.BOSS_ADD_MIX
		expect(mix.chaser + mix.ranged + mix.tank).toEqual(4)
		expect(WaveFlow.plan(5)).toEqual({ "boss", "chaser", "chaser", "ranged", "tank" })
		expect(Enemies.validate(fullRoster())).toEqual(true)

		local _, addsErr = Enemies.validate(fullRoster({ BOSS_ADDS = 2 }))
		expect(string.find(addsErr, "BOSS_ADDS", 1, true) ~= nil).toBeTrue()

		local _, waveErr = Enemies.validate(fullRoster({ BOSS_WAVE = 4 }))
		expect(string.find(waveErr, "BOSS_WAVE", 1, true) ~= nil).toBeTrue()

		local shortBoss = copyBoss()
		shortBoss.maxHealth = Enemies.TYPES.tank.maxHealth
		local _, healthErr = Enemies.validate(fullRoster({ BOSS = shortBoss }))
		expect(string.find(healthErr, "boss health", 1, true) ~= nil).toBeTrue()

		local flat = copyBoss()
		flat.phase2At = 0
		local _, phaseErr = Enemies.validate(fullRoster({ BOSS = flat }))
		expect(string.find(phaseErr, "phase2At", 1, true) ~= nil).toBeTrue()

		local _, mixErr = Enemies.validate(fullRoster({
			BOSS_ADD_MIX = { chaser = 2, ranged = 1, tank = 1, boss = 1 },
		}))
		expect(string.find(mixErr, "chaser, ranged, tank", 1, true) ~= nil).toBeTrue()

		local _, sumErr = Enemies.validate(fullRoster({
			BOSS_ADD_MIX = { chaser = 2, ranged = 1 },
		}))
		expect(string.find(sumErr, "add up to 4", 1, true) ~= nil).toBeTrue()

		local catalog = Dungeons.ENEMIES.boss
		expect(catalog ~= nil).toBeTrue()
		expect(catalog.boss).toEqual(true)
		expect(catalog.maxHealth).toEqual(Enemies.BOSS.maxHealth)
		expect(catalog.phase2At).toEqual(Enemies.BOSS.phase2At)
		expect(catalog.damage).toEqual(Enemies.BOSS.damage)
		expect(Dungeons.ENEMIES.chaser.boss).toEqual(false)
		expect(Dungeons.ENEMIES.ranged.boss).toEqual(false)
		expect(Dungeons.ENEMIES.tank.boss).toEqual(false)
		expect(Drops.ENEMIES.boss.role).toEqual("boss")
		expect(Dungeons.waveKinds(5)).toEqual({ "grandmother_gnarl", "vine_crawler", "spore_bat" })
		expect(Schema.VERSION).toEqual(26)
	end)

	it("accepts the shipped list and rejects a broken mix", function()
		local ok, err = Enemies.validate()
		expect(ok).toEqual(true)
		expect(err).toEqual("")

		local crawl = waveRoster({ 2, 4, 6, 8 }, shippedMixes())
		expect(Enemies.validate(crawl)).toEqual(false)

		local missing = shippedMixes()
		missing[1] = { chaser = 5, ranged = 1 }
		expect(Enemies.validate(waveRoster({ 6, 8, 10, 12 }, missing))).toEqual(false)

		local extra = shippedMixes()
		extra[1] = { chaser = 3, ranged = 1, tank = 1, boss = 1 }
		expect(Enemies.validate(waveRoster({ 6, 8, 10, 12 }, extra))).toEqual(false)

		local short = shippedMixes()
		short[4] = { chaser = 6, ranged = 3, tank = 2 }
		expect(Enemies.validate(waveRoster({ 6, 8, 10, 12 }, short))).toEqual(false)
	end)

	it("leaves the live crawl on counts from 2 to 8", function()
		expect(Dungeons.WAVE_BASE_COUNT).toEqual(2)
		expect(Dungeons.WAVE_COUNT_EVERY).toEqual(2)
		expect(Dungeons.WAVE_MAX_COUNT).toEqual(8)
		expect(Dungeons.waveCount(1)).toEqual(2)
		expect(#Dungeons.waveKinds(1)).toEqual(2)
		expect(Dungeons.waveCount(13) <= 8).toBeTrue()
		for wave = 1, 12 do
			for _, kind in ipairs(Dungeons.waveKinds(wave)) do
				expect(kind == "chaser" or kind == "ranged" or kind == "tank").toBeFalse()
			end
		end
	end)
end)

describe("WaveFlowService", function()
	it("does not spawn, hurt, or publish while the flag is off", function()
		local sent, sink = watch()
		local noted = 0
		sink.analytics = function()
			noted += 1
		end
		local started = WaveFlowService.start(sink)
		expect(started).toBeNil()
		expect(#sent).toEqual(0)
		local mathRun = WaveFlow.start()
		expect(mathRun ~= nil).toBeTrue()
		if mathRun == nil then
			return
		end
		local hp = mathRun.members[1].actor.hp
		expect(WaveFlowService.hurt(mathRun, mathRun.members[1].id, 100000, sink)).toEqual(0)
		expect(mathRun.members[1].actor.hp).toEqual(hp)
		expect(WaveFlowService.counter(mathRun)).toBeNil()
		expect(WaveFlowService.publish("hero", mathRun, sink.fire)).toEqual(false)
		expect(#sent).toEqual(0)
		expect(noted).toEqual(0)
		expect(WaveFlow.counter(mathRun).wave).toEqual(1)
		expect(WaveFlow.counter(mathRun).left).toEqual(6)
	end)

	it("starts wave 1 as six gray blocks and publishes wave and left", function()
		withFlag(true, function()
			local sent, sink, built = watch()
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			expect(#built).toEqual(6)
			expect(#sent).toEqual(1)
			expect(sent[1].player).toEqual("hero")
			expect(sent[1].wave).toEqual(1)
			expect(sent[1].left).toEqual(6)
			expect(sent[1].fields).toEqual(2)
			local counter = WaveFlowService.counter(run)
			expect(counter ~= nil).toBeTrue()
			if counter ~= nil then
				expect(counter.wave).toEqual(1)
				expect(counter.left).toEqual(6)
			end
			local chaser = Enemies.TYPES.chaser
			local paint = chaser.color[1]
			expect(built[1].shape).toEqual("block")
			expect(built[1].kind).toEqual("chaser")
			expect(built[1].x).toEqual(0)
			expect(built[1].y).toEqual(Enemies.WAVE_LIFT)
			expect(built[1].z).toEqual(0)
			expect(built[2].x).toEqual(Enemies.WAVE_GAP)
			expect(built[1].color[1]).toEqual(paint)
			expect(built[1].size[2]).toEqual(chaser.size[2])
			expect(built[6].kind).toEqual("tank")
			built[1].color[1] = 0
			expect(Enemies.TYPES.chaser.color[1]).toEqual(paint)
		end)
	end)

	it("drops the count on a kill and ignores a miss", function()
		withFlag(true, function()
			local sent, sink = watch()
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local boxes = WaveFlow.boxes(run)
			local taken = WaveFlowService.hurt(run, boxes[1].id, 100000, sink)
			expect(taken).toEqual(100000 * Enemies.TYPES.chaser.damageTaken)
			local counter = WaveFlowService.counter(run)
			expect(counter ~= nil and counter.wave == 1 and counter.left == 5).toBeTrue()
			expect(#sent).toEqual(2)
			expect(sent[2].wave).toEqual(1)
			expect(sent[2].left).toEqual(5)
			local before = #sent
			expect(WaveFlowService.hurt(run, boxes[1].id, 100000, sink)).toEqual(0)
			expect(WaveFlowService.hurt(run, -1, 100000, sink)).toEqual(0)
			expect(WaveFlowService.counter(run).left).toEqual(5)
			expect(#sent).toEqual(before)
		end)
	end)

	it("uses the tank fraction and keeps the slot until HP is gone", function()
		withFlag(true, function()
			local sent, sink, built = watch()
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local tankId = built[6].id
			local raw = 20
			local taken = WaveFlowService.hurt(run, tankId, raw, sink)
			expect(taken).toBeCloseTo(raw * Enemies.TYPES.tank.damageTaken)
			expect(WaveFlowService.counter(run).left).toEqual(6)
			expect(#sent).toEqual(1)
			expect(#built).toEqual(6)
		end)
	end)

	it("walks 8, then 10, then 12, then the boss wave, and stops with none left", function()
		withFlag(true, function()
			local sent, sink, built = watch()
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			killLiving(run, sink, 6)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 2, left = 8 })
			expect(#built).toEqual(6 + 8)
			killLiving(run, sink, 8)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 3, left = 10 })
			killLiving(run, sink, 10)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 4, left = 12 })
			-- Waves 1-3 are fully built. Wave 4 builds only the alive cap.
			expect(#built).toEqual(6 + 8 + 10 + math.min(12, Enemies.MAX_ALIVE))
			killLiving(run, sink, 12)
			expect(run.clear).toEqual(false)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 5, left = 5 })
			expect(#built).toEqual(6 + 8 + 10 + 12 + 5)
			killLiving(run, sink, 5)
			expect(run.clear).toEqual(true)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 5, left = 0 })
			expect(#built).toEqual(41)
			expect(sent[#sent].wave).toEqual(5)
			expect(sent[#sent].left).toEqual(0)
			expect(#sent).toEqual(1 + 41)
			local stale = WaveFlowService.hurt(run, 1, 100000, sink)
			expect(stale).toEqual(0)
			expect(WaveFlowService.counter(run).left).toEqual(0)
			expect(#sent).toEqual(42)
		end)
	end)

	it("spawns one gray boss and four adds, and notes the hook on enter and down", function()
		withFlag(true, function()
			local sent, sink, built = watch()
			local events = {}
			sink.analytics = function(name, detail)
				local fields = 0
				for key in pairs(detail) do
					fields += 1
					expect(key == "wave" or key == "adds").toBeTrue()
				end
				table.insert(events, {
					name = name,
					wave = detail.wave,
					adds = detail.adds,
					fields = fields,
				})
			end
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			expect(#events).toEqual(0)
			killLiving(run, sink, 6 + 8 + 10 + 12)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 5, left = 5 })
			expect(#events).toEqual(1)
			expect(events[1].name).toEqual(WaveFlowService.BOSS_ENTER)
			expect(events[1].name).toEqual("bossEnter")
			expect(events[1].wave).toEqual(5)
			expect(events[1].adds).toEqual(4)
			expect(events[1].fields).toEqual(2)
			local kinds = {}
			local bossBox = nil
			for _, box in ipairs(built) do
				if box.wave == 5 then
					table.insert(kinds, box.kind)
					if box.kind == "boss" then
						bossBox = box
					end
					expect(box.shape).toEqual("block")
					expect(box.kind == "grandmother_gnarl").toBeFalse()
				end
			end
			expect(kinds).toEqual({ "boss", "chaser", "chaser", "ranged", "tank" })
			expect(bossBox ~= nil).toBeTrue()
			if bossBox == nil then
				return
			end
			expect(bossBox.size[2]).toEqual(Enemies.BOSS.size[2])
			expect(bossBox.size[2] > Enemies.TYPES.tank.size[2]).toBeTrue()
			expect(bossBox.color[1]).toEqual(Enemies.BOSS.color[1])
			expect(bossBox.y).toEqual(Enemies.WAVE_LIFT)
			local paint = Enemies.BOSS.color[1]
			bossBox.color[1] = 0
			expect(Enemies.BOSS.color[1]).toEqual(paint)
			local chip = WaveFlowService.hurt(run, bossBox.id, 10, sink)
			expect(chip).toEqual(10 * Enemies.BOSS.damageTaken)
			expect(WaveFlowService.counter(run).left).toEqual(5)
			expect(#events).toEqual(1)
			expect(run.clear).toEqual(false)
			local taken = WaveFlowService.hurt(run, bossBox.id, 100000, sink)
			expect(taken > 0).toBeTrue()
			expect(#events).toEqual(2)
			expect(events[2].name).toEqual(WaveFlowService.BOSS_DOWN)
			expect(events[2].name).toEqual("bossDown")
			expect(events[2].wave).toEqual(5)
			expect(events[2].fields).toEqual(1)
			expect(run.clear).toEqual(false)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 5, left = 4 })
			killLiving(run, sink, 4)
			expect(run.clear).toEqual(true)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 5, left = 0 })
			expect(#events).toEqual(2)
			expect(sent[#sent].wave).toEqual(5)
			expect(sent[#sent].left).toEqual(0)
			expect(sent[#sent].fields).toEqual(2)
		end)
	end)

	it("declares a server-to-client counter and leaves the client tree alone", function()
		local project = fs.readFile("default.project.json")
		local needle = '"WaveCounter": {\n          "$className": "RemoteEvent"'
		expect(string.find(project, needle, 1, true) ~= nil).toBeTrue()
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/WaveFlowService.luau")
		expect(WaveFlowService.REMOTE).toEqual("WaveCounter")
		expect(string.find(service, "FireClient", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "OnServerEvent", 1, true)).toBeNil()
		expect(string.find(service, "OnServerInvoke", 1, true)).toBeNil()
		for _, path in ipairs(luaFiles("src/StarterPlayer")) do
			local body = fs.readFile(path)
			expect(string.find(body, "WaveCounter", 1, true)).toBeNil()
			expect(string.find(body, "WaveFlow", 1, true)).toBeNil()
			expect(string.find(body, "bossEnter", 1, true)).toBeNil()
			expect(string.find(body, "bossDown", 1, true)).toBeNil()
		end
	end)
end)
