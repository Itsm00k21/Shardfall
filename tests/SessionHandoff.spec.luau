--!strict

--[[
	The reserved-server hop has to finish its save before TeleportAsync.

	The raid server retries a busy lock five times, then kicks. These cases
	use the same MemoryStore adapter as an unpublished Studio session: the
	release write is visible inside the teleport callback, a throttled write
	never calls teleport, and a later save from the server that released
	does not take the lock back.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local MemoryStore = require("../src/ReplicatedStorage/Shared/MemoryStore")
local ProfileLoad = require("../src/ReplicatedStorage/Shared/ProfileLoad")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")

local NOW = 1_700_000_000
local TIMEOUT = SessionLock.TIMEOUT_SECONDS
local PLACE = 1

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

local function read(store: MemoryStore.Store, key: string): any
	local seen = nil
	store:updateAsync(key, function(document)
		seen = document
		return nil
	end)
	return seen
end

local function claim(store: MemoryStore.Store, key: string): any
	local opened = ProfileLoad.open(store, key, NOW, "server-a", PLACE, TIMEOUT)
	expect(opened.session).toBeFalse()
	expect(opened.reason).toEqual("claimed")
	assert(opened.data ~= nil, "profile should load")
	return opened.data
end

describe("Session handoff", function()
	it("leaves the 20 minute lock and the shutdown budget past the old cutoff", function()
		expect(SessionLock.TIMEOUT_SECONDS).toEqual(20 * 60)
		expect(ProfileLoad.SHUTDOWN_BUDGET_SECONDS).toEqual(30)
		-- A write still running at 25 seconds has to be waited for.
		expect(ProfileLoad.shutdownStillWaiting(1, 25)).toBeTrue()
		expect(ProfileLoad.shutdownStillWaiting(1, 29)).toBeTrue()
		expect(ProfileLoad.shutdownStillWaiting(1, 30)).toBeFalse()
		expect(ProfileLoad.shutdownStillWaiting(0, 1)).toBeFalse()

		local dataService = fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
		expect(string.find(dataService, "local AUTOSAVE_SECONDS = 60", 1, true) ~= nil).toBeTrue()
		expect(string.find(dataService, "os.clock() + 25", 1, true)).toBeNil()
		expect(string.find(dataService, "ProfileLoad.shutdownStillWaiting", 1, true) ~= nil).toBeTrue()
		local releaseAt =
			string.find(dataService, "function DataService.release(player: Player)", 1, true)
		local guardAt = string.find(dataService, "if record.released then", 1, true)
		expect(releaseAt ~= nil and guardAt ~= nil).toBeTrue()
		local writeAt =
			string.find(dataService, "write(record, true)", (guardAt :: number) + 1, true)
		expect(writeAt ~= nil).toBeTrue()
		expect((releaseAt :: number) < (guardAt :: number)).toBeTrue()
		expect((guardAt :: number) < (writeAt :: number)).toBeTrue()

		local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
		local handoffAt = string.find(raid, "DataService.releaseForTeleport", 1, true)
		local teleportAt = string.find(raid, "TeleportService:TeleportAsync", 1, true)
		expect(handoffAt ~= nil and teleportAt ~= nil).toBeTrue()
		expect((handoffAt :: number) < (teleportAt :: number)).toBeTrue()

		local hits = {}
		for _, path in ipairs(luaFiles("src")) do
			local source = fs.readFile(path)
			local _, count = string.gsub(source, ":TeleportAsync", "")
			if count > 0 then
				table.insert(hits, path)
			end
		end
		expect(#hits).toEqual(1)
		expect(hits[1]).toEqual("src/ServerScriptService/ShardfallServer/RaidService.luau")
	end)

	it("clears the lock before teleport and a later save does not take it back", function()
		local store = MemoryStore.new()
		local key = "Player_9"
		local data = claim(store, key)
		data.gold = 40

		local log = {}
		local wrapped: ProfileLoad.Adapter = {
			updateAsync = function(_self, updateKey, transform)
				return store:updateAsync(updateKey, function(document)
					local updated = transform(document)
					if
						type(updated) == "table"
						and type(updated.Lock) == "table"
						and updated.Lock.jobId == ""
					then
						table.insert(log, "release")
					end
					return updated
				end)
			end,
		}

		local result = ProfileLoad.handoff(
			wrapped,
			key,
			NOW + 5,
			"server-a",
			PLACE,
			TIMEOUT,
			data,
			function()
				local seen = read(store, key)
				expect(seen.Lock.jobId).toEqual("")
				expect(seen.Data.gold).toEqual(40)
				expect(SessionLock.status(seen.Lock, NOW + 5, "server-b", TIMEOUT)).toEqual("free")
				table.insert(log, "teleport")
			end
		)
		expect(result.teleported).toBeTrue()
		expect(result.reason).toEqual("saved")
		expect(log[1]).toEqual("release")
		expect(log[2]).toEqual("teleport")
		expect(#log).toEqual(2)

		-- PlayerRemoving on the old server: both a lock-clearing write and a
		-- plain autosave must leave the freed document alone.
		local lateRelease =
			ProfileLoad.release(store, key, NOW + 6, "server-a", PLACE, TIMEOUT, { gold = 1 })
		expect(lateRelease.ok).toBeFalse()
		expect(lateRelease.reason).toEqual("lost")
		store:updateAsync(key, function(document)
			local written, reason = SessionLock.trySave(
				document,
				NOW + 6,
				"server-a",
				PLACE,
				TIMEOUT,
				{ gold = 1 },
				false
			)
			expect(written).toBeNil()
			expect(reason).toEqual("lost")
			return written
		end)
		local freed = read(store, key)
		expect(freed.Data.gold).toEqual(40)
		expect(freed.Lock.jobId).toEqual("")

		local arrived = ProfileLoad.open(store, key, NOW + 7, "server-b", PLACE, TIMEOUT)
		expect(arrived.reason).toEqual("claimed")
		expect(arrived.session).toBeFalse()
		assert(arrived.data ~= nil)
		expect(arrived.data.gold).toEqual(40)

		local stale =
			ProfileLoad.release(store, key, NOW + 8, "server-a", PLACE, TIMEOUT, { gold = 1 })
		expect(stale.ok).toBeFalse()
		expect(stale.reason).toEqual("lost")
		local held = read(store, key)
		expect(held.Lock.jobId).toEqual("server-b")
		expect(held.Data.gold).toEqual(40)
	end)

	it("does not teleport when the save fails and leaves the lock held", function()
		local store = MemoryStore.new()
		local key = "Player_10"
		local data = claim(store, key)
		local before = read(store, key)
		local originalGold = before.Data.gold
		data.gold = originalGold + 12

		local calls = 0
		local throttled: ProfileLoad.Adapter = {
			updateAsync = function(_self, _key, _transform)
				error("DataStore request was added to queue. Request was throttled.", 0)
			end,
		}
		local result = ProfileLoad.handoff(
			throttled,
			key,
			NOW + 5,
			"server-a",
			PLACE,
			TIMEOUT,
			data,
			function()
				calls += 1
			end
		)
		expect(calls).toEqual(0)
		expect(result.teleported).toBeFalse()
		expect(result.reason).toEqual("error")
		expect(string.find(result.error or "", "throttled", 1, true) ~= nil).toBeTrue()

		local after = read(store, key)
		expect(after.Data.gold).toEqual(originalGold)
		expect(after.Lock.jobId).toEqual("server-a")
		expect(SessionLock.status(after.Lock, NOW + 5, "server-b", TIMEOUT)).toEqual("busy")
		-- The owner can still save, because the failed hop did not release.
		local saved, reason = SessionLock.trySave(
			after,
			NOW + 6,
			"server-a",
			PLACE,
			TIMEOUT,
			Schema.deepCopy(data),
			false
		)
		expect(reason).toEqual("saved")
		assert(saved ~= nil)
		expect(saved.Lock.jobId).toEqual("server-a")
		expect(saved.Data.gold).toEqual(originalGold + 12)
	end)

	it("does not teleport when another server already holds the lock", function()
		local store = MemoryStore.new()
		local key = "Player_11"
		local data = claim(store, key)
		data.gold = 4
		store:updateAsync(key, function(document)
			document.Lock = SessionLock.claim(NOW, "server-b", PLACE)
			document.Data.gold = 7
			return document
		end)

		local calls = 0
		local result = ProfileLoad.handoff(
			store,
			key,
			NOW + 1,
			"server-a",
			PLACE,
			TIMEOUT,
			data,
			function()
				calls += 1
			end
		)
		expect(calls).toEqual(0)
		expect(result.teleported).toBeFalse()
		expect(result.reason).toEqual("lost")

		local after = read(store, key)
		expect(after.Lock.jobId).toEqual("server-b")
		expect(after.Data.gold).toEqual(7)
	end)

	it("claims the lock back when teleport throws", function()
		local store = MemoryStore.new()
		local key = "Player_12"
		local data = claim(store, key)
		data.gold = 40

		local result = ProfileLoad.handoff(
			store,
			key,
			NOW + 5,
			"server-a",
			PLACE,
			TIMEOUT,
			data,
			function()
				local seen = read(store, key)
				expect(seen.Lock.jobId).toEqual("")
				expect(seen.Data.gold).toEqual(40)
				error("TeleportAsync failed")
			end
		)
		expect(result.teleported).toBeFalse()
		expect(result.reason).toEqual("teleport")
		local after = read(store, key)
		expect(after.Lock.jobId).toEqual("server-a")
		expect(after.Data.gold).toEqual(40)
		expect(SessionLock.canWrite(after.Lock, NOW + 5, "server-a", TIMEOUT)).toBeTrue()
	end)

	it(
		"does not take the lock back when the raid server claimed it during a failed teleport",
		function()
			local store = MemoryStore.new()
			local key = "Player_13"
			local data = claim(store, key)
			data.gold = 40

			local result = ProfileLoad.handoff(
				store,
				key,
				NOW + 5,
				"server-a",
				PLACE,
				TIMEOUT,
				data,
				function()
					store:updateAsync(key, function(document)
						local written, reason = SessionLock.tryClaim(
							document,
							NOW + 5,
							"server-b",
							PLACE,
							TIMEOUT,
							Schema.deepCopy(document.Data)
						)
						expect(reason).toEqual("claimed")
						return written
					end)
					error("TeleportAsync failed")
				end
			)
			expect(result.teleported).toBeFalse()
			expect(result.reason).toEqual("stolen")
			local after = read(store, key)
			expect(after.Lock.jobId).toEqual("server-b")
			expect(after.Data.gold).toEqual(40)
		end
	)
end)
