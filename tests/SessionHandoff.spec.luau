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

	it("reclaims a returned hop and does not copy gold onto the raid server", function()
		local store = MemoryStore.new()
		local key = "Player_14"
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
			function() end
		)
		expect(result.teleported).toBeTrue()
		local freed = read(store, key)
		expect(freed.Lock.jobId).toEqual("")
		expect(freed.Data.gold).toEqual(40)

		-- TeleportAsync returned, then TeleportInitFailed. The player is still here.
		local again = ProfileLoad.reclaim(store, key, NOW + 6, "server-a", PLACE, TIMEOUT, data)
		expect(again.ok).toBeTrue()
		expect(again.reason).toEqual("claimed")
		expect(ProfileLoad.failedHop(true, true)).toEqual("restore")
		local restored = read(store, key)
		expect(restored.Lock.jobId).toEqual("server-a")
		expect(restored.Data.gold).toEqual(40)
		expect(SessionLock.canWrite(restored.Lock, NOW + 6, "server-a", TIMEOUT)).toBeTrue()

		-- They left during the reclaim. The lock we just took has to be cleared
		-- or the next server waits out the timeout.
		expect(ProfileLoad.failedHop(false, true)).toEqual("release")
		local cleared = ProfileLoad.release(store, key, NOW + 7, "server-a", PLACE, TIMEOUT, data)
		expect(cleared.ok).toBeTrue()
		local openAgain = ProfileLoad.open(store, key, NOW + 8, "server-b", PLACE, TIMEOUT)
		expect(openAgain.reason).toEqual("claimed")
		assert(openAgain.data ~= nil)
		expect(openAgain.data.gold).toEqual(40)
	end)

	it("does not overwrite a raid server that won the lock during a late hop failure", function()
		local store = MemoryStore.new()
		local key = "Player_15"
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
			function() end
		)
		expect(result.teleported).toBeTrue()
		store:updateAsync(key, function(document)
			local written, reason =
				SessionLock.tryClaim(document, NOW + 6, "server-b", PLACE, TIMEOUT, { gold = 99 })
			expect(reason).toEqual("claimed")
			return written
		end)

		local again = ProfileLoad.reclaim(store, key, NOW + 6, "server-a", PLACE, TIMEOUT, data)
		expect(again.ok).toBeFalse()
		expect(again.reason).toEqual("busy")
		expect(ProfileLoad.failedHop(true, false)).toEqual("kick")
		expect(ProfileLoad.failedHop(false, false)).toEqual("drop")
		local after = read(store, key)
		expect(after.Lock.jobId).toEqual("server-b")
		expect(after.Data.gold).toEqual(99)
	end)

	it(
		"keeps a reserved arrival in place and names a second queue without the save error",
		function()
			expect(ProfileLoad.hopOnArrival("", 0)).toBeTrue()
			expect(ProfileLoad.hopOnArrival("reserved-code", 0)).toBeFalse()
			expect(ProfileLoad.hopOnArrival("vip-code", 42)).toBeTrue()
			expect(ProfileLoad.hopOnArrival(nil, 0)).toBeTrue()
			expect(
				string.find(string.lower(ProfileLoad.TELEPORT_ALREADY), "could not save", 1, true)
			).toBeNil()
			expect(
				string.find(
					string.lower(ProfileLoad.TELEPORT_ALREADY),
					"already in progress",
					1,
					true
				) ~= nil
			).toBeTrue()
			expect(string.find(ProfileLoad.HOP_REJOIN, "Rejoin", 1, true) ~= nil).toBeTrue()

			local dataService =
				fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
			expect(string.find(dataService, "TeleportInitFailed", 1, true) ~= nil).toBeTrue()
			expect(string.find(dataService, "ProfileLoad.reclaim", 1, true) ~= nil).toBeTrue()
			expect(string.find(dataService, "ProfileLoad.failedHop", 1, true) ~= nil).toBeTrue()
			expect(string.find(dataService, "ProfileLoad.TELEPORT_ALREADY", 1, true) ~= nil).toBeTrue()
			local settleAt = string.find(dataService, "local function settleRecord", 1, true)
			local releasedLine =
				string.find(dataService, "record.released = released", settleAt, true)
			local loadedLine = string.find(dataService, "record.loaded = loaded", settleAt, true)
			local closingLine = string.find(dataService, "record.closing = false", settleAt, true)
			expect(
				settleAt ~= nil and releasedLine ~= nil and loadedLine ~= nil and closingLine ~= nil
			).toBeTrue()
			expect((releasedLine :: number) < (loadedLine :: number)).toBeTrue()
			expect((loadedLine :: number) < (closingLine :: number)).toBeTrue()
			local hopFn =
				string.find(dataService, "function DataService.releaseForTeleport", 1, true)
			local hopBody = string.sub(dataService, hopFn :: number)
			expect(string.find(hopBody, "record.closing = false", 1, true)).toBeNil()
			local releaseAt =
				string.find(dataService, "function DataService.release(player: Player)", 1, true)
			local disconnectAt = string.find(dataService, "disconnectHop(player)", releaseAt, true)
			local whileAt = string.find(dataService, "while record.closing do", releaseAt, true)
			expect(disconnectAt ~= nil and whileAt ~= nil).toBeTrue()
			expect((disconnectAt :: number) < (whileAt :: number)).toBeTrue()
			local watchAt = string.find(dataService, "local function beginHopWatch", 1, true)
			local teleportCall = string.find(dataService, "teleport()", watchAt, true)
			local waitAt = string.find(dataService, "task.wait()", teleportCall, true)
			local initAt = string.find(dataService, "watch.initFailed", waitAt, true)
			expect(teleportCall ~= nil and waitAt ~= nil and initAt ~= nil).toBeTrue()
			expect((teleportCall :: number) < (waitAt :: number)).toBeTrue()
			expect((waitAt :: number) < (initAt :: number)).toBeTrue()

			local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
			local holdAt = string.find(raid, "DataService.teleportHold", 1, true)
			local reserveCall = string.find(raid, "local code = reservedCode()", 1, true)
			expect(holdAt ~= nil and reserveCall ~= nil).toBeTrue()
			expect((holdAt :: number) < (reserveCall :: number)).toBeTrue()
			expect(string.find(raid, 'hopped == "closing"', 1, true) ~= nil).toBeTrue()
			local receiveAt =
				string.find(raid, "function RaidService.receive(player: Player)", 1, true)
			local receiveBody = string.sub(raid, receiveAt :: number)
			expect(string.find(receiveBody, "ProfileLoad.hopOnArrival", 1, true) ~= nil).toBeTrue()
			expect(string.find(receiveBody, "RaidService.queue", 1, true)).toBeNil()
			expect(string.find(receiveBody, "TeleportAsync", 1, true)).toBeNil()
			expect(string.find(receiveBody, "ReserveServer(", 1, true)).toBeNil()
		end
	)
end)
