--!strict

--[[
	T5 hub safety. Island falls still go to HubSpawn. An arena run, and
	only an arena run with LaunchGate.waveArena on, goes back to the arena
	origin instead. The fall-rescue stream is spawned so the heartbeat
	does not wait on it.

	Follow-up on #467: the rescue leaves the root unanchored, an arena
	fall is caught 30 studs under the arena origin, and the Shard Gate
	pad sits inside the plaza.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Haven = require("../src/ReplicatedStorage/Shared/Haven")
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
		expect(string.find(spawned, "HubRescue.recover", 1, true) ~= nil).toBeTrue()
		expect(string.find(spawned, "teleport(player, cframe)", 1, true) ~= nil).toBeTrue()

		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "function WaveArenaHost.inRun", 1, true) ~= nil).toBeTrue()
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
	end)

	it("probe: the hub fall rescue leaves the root unanchored", function()
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		local root = { Anchored = true }
		local function readRoot(): any
			return root
		end

		-- The stream hold anchors the root, then the move throws before
		-- teleport can put the old anchored state back.
		local thrown, throwErr = HubRescue.recover(readRoot, function()
			root.Anchored = true
			error("stream failed")
		end)
		expect(thrown).toEqual(false)
		expect(throwErr ~= nil).toBeTrue()
		expect(root.Anchored).toEqual(false)

		-- teleport saved Anchored == true and wrote that back. The rescue
		-- still ends with the player free to walk.
		root.Anchored = true
		local restored = HubRescue.recover(readRoot, function()
			local anchored = root.Anchored
			root.Anchored = true
			root.Anchored = anchored
		end)
		expect(restored).toEqual(true)
		expect(root.Anchored).toEqual(false)

		local missing = HubRescue.recover(function()
			return nil
		end, function() end)
		expect(missing).toEqual(true)
	end)

	it("rescues an arena fall 30 studs under the arena origin", function()
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		expect(HubRescue.ARENA_DROP).toEqual(30)
		local originY = WaveArenaConfig.arena.origin.y
		local arenaLine = HubRescue.fallLine("arena", Haven.FALL_Y, originY)
		local hubLine = HubRescue.fallLine("hub", Haven.FALL_Y, originY)
		expect(arenaLine).toEqual(originY - 30)
		expect(hubLine).toEqual(Haven.FALL_Y)
		expect(arenaLine > Haven.FALL_Y).toBeTrue()

		local underArena = originY - 31
		expect(underArena > Haven.FALL_Y).toBeTrue()
		expect(HubRescue.pastLine(underArena, arenaLine)).toEqual(true)
		expect(HubRescue.pastLine(underArena, hubLine)).toEqual(false)
		expect(Haven.fellOffHub(underArena)).toEqual(false)

		local onDeck = originY - 10
		expect(HubRescue.pastLine(onDeck, arenaLine)).toEqual(false)
		expect(HubRescue.pastLine(Haven.FALL_Y, hubLine)).toEqual(false)
		expect(HubRescue.pastLine(Haven.FALL_Y - 1, hubLine)).toEqual(true)

		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local rescue = between(dungeon, "local function rescueArena", "local function faultPlayer")
		expect(string.find(rescue, 'HubRescue.fallLine("arena"', 1, true) ~= nil).toBeTrue()
		expect(string.find(rescue, "HubRescue.pastLine", 1, true) ~= nil).toBeTrue()
		expect(string.find(rescue, "Haven.fellOffHub", 1, true)).toBeNil()
		local hub = between(dungeon, "local function tickHub", "local function rescueArena")
		expect(string.find(hub, "Haven.fellOffHub", 1, true) ~= nil).toBeTrue()
	end)

	it("puts the Shard Gate inside the plaza and clear of the Grove post", function()
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(LaunchGate.on("grove")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		local pad = WaveArenaConfig.hubPad.position
		local size = WaveArenaConfig.hubPad.size
		expect(pad.x).toEqual(14)
		expect(pad.y).toEqual(120.5)
		expect(pad.z).toEqual(44)
		local halfX = size[1] / 2
		local halfZ = size[3] / 2
		local corners = {
			{ pad.x - halfX, pad.z - halfZ },
			{ pad.x - halfX, pad.z + halfZ },
			{ pad.x + halfX, pad.z - halfZ },
			{ pad.x + halfX, pad.z + halfZ },
		}
		for _, corner in ipairs(corners) do
			local reach = math.sqrt(corner[1] * corner[1] + corner[2] * corner[2])
			expect(reach < Haven.PLAZA_RADIUS).toBeTrue()
		end
		local grove = Haven.GROVE
		local dx = pad.x - grove.x
		local dz = pad.z - grove.z
		expect(math.sqrt(dx * dx + dz * dz) > 12 + 8).toBeTrue()
	end)
end)
