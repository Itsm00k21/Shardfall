--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local MemoryStore = require("../src/ReplicatedStorage/Shared/MemoryStore")
local ProfileLoad = require("../src/ReplicatedStorage/Shared/ProfileLoad")
local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")

local KEY = "Player_1"
local NOW = 1_700_000_000

local function read(store: MemoryStore.Store, key: string): any
	local seen = nil
	store:updateAsync(key, function(current)
		seen = current
		return nil
	end)
	return seen
end

describe("Save locks", function()
	it("releases an owned lock and leaves the stored gold", function()
		local store = MemoryStore.new()
		store:updateAsync(KEY, function(_current)
			return {
				Data = { gold = 80 },
				Lock = SessionLock.claim(NOW, "server-a", 7),
			}
		end)
		local released = ProfileLoad.releaseOwned(store, KEY, "server-a")
		expect(released.ok).toEqual(true)
		expect(released.reason).toEqual("released")
		local stored = read(store, KEY)
		expect(stored.Data.gold).toEqual(80)
		expect(stored.Lock.jobId).toEqual("")
		expect(SessionLock.status(stored.Lock, NOW, "server-b", SessionLock.TIMEOUT_SECONDS)).toEqual(
			"free"
		)
	end)

	it("does not let a stranger clear a lock or a missing key invent a profile", function()
		local store = MemoryStore.new()
		store:updateAsync(KEY, function(_current)
			return {
				Data = { gold = 80 },
				Lock = SessionLock.claim(NOW, "server-a", 7),
			}
		end)
		local stranger = ProfileLoad.releaseOwned(store, KEY, "server-b")
		expect(stranger.ok).toEqual(false)
		expect(stranger.reason).toEqual("busy")
		local stored = read(store, KEY)
		expect(stored.Data.gold).toEqual(80)
		expect(stored.Lock.jobId).toEqual("server-a")

		local missing = ProfileLoad.releaseOwned(store, "Player_missing", "server-a")
		expect(missing.ok).toEqual(false)
		expect(missing.reason).toEqual("missing")
		expect(read(store, "Player_missing")).toBeNil()
	end)

	it("restores a mutate only when a later one has not started", function()
		expect(ProfileLoad.mutateShouldRestore(1, 1)).toEqual(true)
		expect(ProfileLoad.mutateShouldRestore(1, 2)).toEqual(false)
	end)

	it("wires the failed load, the shutdown release, and the missing warn", function()
		local dataService = fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
		local failAt = string.find(dataService, "local function failLoad", 1, true)
		local clearAt = string.find(dataService, "clearOwnedLock(record.key)", failAt :: number, true)
		expect(failAt ~= nil and clearAt ~= nil).toBeTrue()
		expect(string.find(dataService, "ProfileLoad.releaseOwned", 1, true) ~= nil).toBeTrue()
		expect(string.find(dataService, "ProfileLoad.mutateShouldRestore", 1, true) ~= nil).toBeTrue()

		local closeAt = string.find(dataService, "game:BindToClose(function()", 1, true)
		local flagAt = string.find(dataService, "shuttingDown = true", closeAt :: number, true)
		local spawnAt = string.find(dataService, "task.spawn(function()", flagAt :: number, true)
		expect(closeAt ~= nil and flagAt ~= nil and spawnAt ~= nil).toBeTrue()
		expect((flagAt :: number) < (spawnAt :: number)).toBeTrue()

		local autosaveAt = string.find(dataService, "local function autosave()", 1, true)
		local skipAt = string.find(dataService, "if shuttingDown then", autosaveAt :: number, true)
		local saveAt = string.find(dataService, "write(record, false)", autosaveAt :: number, true)
		expect(autosaveAt ~= nil and skipAt ~= nil and saveAt ~= nil).toBeTrue()
		expect((skipAt :: number) < (saveAt :: number)).toBeTrue()

		local releaseAt =
			string.find(dataService, "function DataService.release(player: Player)", 1, true)
		local whileAt = string.find(dataService, "while record.closing do", releaseAt :: number, true)
		local breakAt = string.find(dataService, "if shuttingDown then", whileAt :: number, true)
		expect(releaseAt ~= nil and whileAt ~= nil and breakAt ~= nil).toBeTrue()
		expect((whileAt :: number) < (breakAt :: number)).toBeTrue()

		expect(string.find(dataService, 'reason ~= "missing"', 1, true)).toBeNil()
		expect(
			string.find(
				dataService,
				'warn("[Shardfall] Final save failed for", player.Name, reason)',
				releaseAt :: number,
				true
			) ~= nil
		).toBeTrue()
	end)
end)
