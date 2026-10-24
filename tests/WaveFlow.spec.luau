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
		expect(WaveFlow.plan(5)).toBeNil()
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

	it("walks 8, then 10, then 12, and stops with none left", function()
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
			expect(#built).toEqual(6 + 8 + 10 + 12)
			killLiving(run, sink, 12)
			expect(run.clear).toEqual(true)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 4, left = 0 })
			expect(#built).toEqual(36)
			expect(sent[#sent].wave).toEqual(4)
			expect(sent[#sent].left).toEqual(0)
			expect(#sent).toEqual(1 + 36)
			local stale = WaveFlowService.hurt(run, 1, 100000, sink)
			expect(stale).toEqual(0)
			expect(WaveFlowService.counter(run).left).toEqual(0)
			expect(#sent).toEqual(37)
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
		end
	end)
end)
