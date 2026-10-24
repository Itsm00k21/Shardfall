--!strict

--[[
	Phase 3 hookups. The arena stays unbuilt while either switch is off.
	The remote is parked, the boot call sits behind the flag, and the
	client require is the one line in init.client.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")
local BossBar = require("../src/StarterPlayer/StarterPlayerScripts/ShardfallClient/WaveArena/BossBar")
local CameraRoom = require("../src/StarterPlayer/StarterPlayerScripts/ShardfallClient/WaveArena/CameraRoom")
local ResultsCard = require("../src/StarterPlayer/StarterPlayerScripts/ShardfallClient/WaveArena/ResultsCard")

describe("Phase 3 arena hooks", function()
	it("keeps both switches off and parks the enter remote", function()
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(WaveArenaConfig.enabled).toEqual(false)
		local project = fs.readFile("default.project.json")
		expect(string.find(project, '"WaveArena"', 1, true) ~= nil).toBeTrue()
		expect(string.find(project, "src/server", 1, true) ~= nil).toBeTrue()
		expect(string.find(project, "src/ReplicatedStorage/Shared", 1, true) ~= nil).toBeTrue()
		local cfg = fs.readFile("src/ReplicatedStorage/Shared/Config/WaveArenaConfig.luau")
		expect(string.find(cfg, "enabled = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(cfg, "diameter = 90", 1, true) ~= nil).toBeTrue()
		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		expect(string.find(remotes, 'WaveArena = "waveArena"', 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, 'functionRemote("WaveArena")', 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, "WaveArenaHost", 1, true) ~= nil).toBeTrue()
		local limiter = fs.readFile("src/ServerScriptService/ShardfallServer/RateLimiter.luau")
		expect(string.find(limiter, "WaveArena = { capacity = 30, perSecond = 24 }", 1, true) ~= nil).toBeTrue()
		local server = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local flag = string.find(server, 'LaunchGate.on("waveArena")', 1, true)
		local present = string.find(server, "WaveArenaHost).present()", 1, true)
		local disconnect = string.find(server, "WaveArenaHost).disconnect", 1, true)
		local release = string.find(server, "DataService.start()", 1, true)
		expect(flag ~= nil and present ~= nil and (flag :: number) < (present :: number)).toBeTrue()
		expect(disconnect ~= nil and release ~= nil and (disconnect :: number) < (release :: number)).toBeTrue()
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "remoteOk", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "session.teleport", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "moveX = 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "bagSlots", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "DataService.get", 1, true) ~= nil).toBeTrue()
		local card = fs.readFile(
			"src/StarterPlayer/StarterPlayerScripts/ShardfallClient/WaveArena/ResultsCard.luau"
		)
		expect(string.find(card, "onLeave", 1, true)).toBeNil()
		expect(string.find(card, '"leave"', 1, true)).toBeNil()
		local client = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		expect(string.find(client, "require(script.WaveArena).start()", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "MenuHub", 1, true) ~= nil).toBeTrue()
	end)

	it("hides the boss bar until the snapshot says it is shown", function()
		expect(BossBar.shown(nil)).toEqual(false)
		expect(BossBar.shown({ boss = { shown = false, ratio = 1 } })).toEqual(false)
		expect(BossBar.ratio({ boss = { shown = true, ratio = 1.4 } })).toEqual(1)
		expect(BossBar.ratio({ boss = { shown = true, ratio = 0.25 } })).toEqual(0.25)
	end)

	it("pushes an eye out of the boss room and lists the results card", function()
		local moved = CameraRoom.correct({ 0, 0, 0 }, { 0, 0, 0 }, { 8, 9, 7 }, 6, 3)
		expect(moved ~= nil).toBeTrue()
		local point = moved :: { number }
		local outside = math.abs(point[1]) > 4 or math.abs(point[2]) > 4.5 or math.abs(point[3]) > 3.5
		expect(outside).toEqual(true)
		local left = CameraRoom.correct({ 40, 10, 0 }, { 0, 0, 0 }, { 8, 9, 7 }, 6, 3)
		expect(left).toEqual({ 40, 10, 0 })
		local lines = ResultsCard.lines({
			cleared = true,
			wavesCleared = 5,
			loot = {
				tokens = 11,
				fragments = 4,
				overflow = { { id = "shard_chip", count = 2 } },
				essence = 2,
			},
		})
		expect(lines[1]).toEqual("Cleared")
		expect(lines[3]).toEqual("Tokens 11")
		expect(lines[5]).toEqual("shard_chip x2")
		expect(lines[6]).toEqual("Essence 2")
	end)
end)
