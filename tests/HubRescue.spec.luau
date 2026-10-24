--!strict

--[[
	T5 hub safety. Island falls still go to HubSpawn. An arena run, and
	only an arena run with LaunchGate.waveArena on, goes back to the arena
	origin instead. The fall-rescue stream is spawned so the heartbeat
	does not wait on it.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local HubRescue = require("../src/ReplicatedStorage/Shared/HubRescue")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")
local WaveArenaHost = require("../src/ServerScriptService/ShardfallServer/WaveArenaHost")

local function between(source: string, from: string, to: string): string
	local startAt = string.find(source, from, 1, true)
	expect(startAt ~= nil).toBeTrue()
	local finishAt = string.find(source, to, startAt :: number, true)
	expect(finishAt ~= nil).toBeTrue()
	return string.sub(source, startAt :: number, (finishAt :: number) - 1)
end

describe("Hub fall destination", function()
	it("sends a fallen player to the hub unless an arena run has the flag on", function()
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		expect(HubRescue.destination(false, false, false)).toEqual("none")
		expect(HubRescue.destination(false, true, false)).toEqual("none")
		expect(HubRescue.destination(true, true, false)).toEqual("none")
		expect(HubRescue.destination(false, false, true)).toEqual("hub")
		expect(HubRescue.destination(false, true, true)).toEqual("hub")
		expect(HubRescue.destination(true, false, true)).toEqual("hub")
		expect(HubRescue.destination(true, true, true)).toEqual("arena")
	end)

	it("reports an arena run only while the wave arena flag is on", function()
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		local previous = LaunchGate.SHOW.waveArena
		local player = { UserId = 40 }
		WaveArenaHost._seat(player, { receiptId = "t5-fall" })
		local ok, err = pcall(function()
			expect(WaveArenaHost.inRun(player)).toEqual(false)
			LaunchGate.SHOW.waveArena = true
			expect(WaveArenaHost.inRun(player)).toEqual(true)
			WaveArenaHost._seat(player, nil)
			expect(WaveArenaHost.inRun(player)).toEqual(false)
		end)
		WaveArenaHost._seat(player, nil)
		LaunchGate.SHOW.waveArena = previous
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(WaveArenaConfig.enabled).toEqual(false)
		if not ok then
			error(err, 0)
		end
	end)

	it("skips tickHub for an arena run and spawns the fall-rescue stream", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local heart = between(dungeon, "local function onHeartbeat", "local function reject")
		local rescueAt = string.find(heart, "pcall(rescueArena,", 1, true)
		local hubAt = string.find(heart, "pcall(tickHub,", 1, true)
		expect(rescueAt ~= nil).toBeTrue()
		expect(hubAt ~= nil).toBeTrue()
		expect((rescueAt :: number) < (hubAt :: number)).toBeTrue()
		expect(string.find(heart, '== "arena"', 1, true) ~= nil).toBeTrue()
		expect(string.find(heart, "pcall(function", 1, true)).toBeNil()

		local rescue = between(dungeon, "local function rescueArena", "local function faultPlayer")
		expect(string.find(rescue, "arenaCFrame()", 1, true) ~= nil).toBeTrue()
		expect(string.find(rescue, "fallTeleport(player, arenaCFrame())", 1, true) ~= nil).toBeTrue()
		expect(string.find(rescue, "hubCFrame()", 1, true)).toBeNil()

		local hub = between(dungeon, "local function tickHub", "local function rescueArena")
		expect(string.find(hub, '== "arena"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "return", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "fallTeleport(player, hubCFrame())", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "teleport(player, hubCFrame())", 1, true)).toBeNil()

		local spawned = between(dungeon, "local function fallTeleport", "local function arenaRunning")
		expect(string.find(spawned, "task.spawn(function()", 1, true) ~= nil).toBeTrue()
		expect(string.find(spawned, "pcall(teleport, player, cframe)", 1, true) ~= nil).toBeTrue()

		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "function WaveArenaHost.inRun", 1, true) ~= nil).toBeTrue()
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
	end)
end)
