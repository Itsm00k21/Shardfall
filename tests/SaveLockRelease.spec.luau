--!strict

--[[
	Studio Stop was kicking the same account with "still open on another
	server" because the session lock was never cleared. These cases are the
	three rules from that bug: a stale same-user lock in Studio can be
	taken, a fresh lock on a live server cannot, and release on close
	clears the lock without touching gold.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local MemoryStore = require("../src/ReplicatedStorage/Shared/MemoryStore")
local ProfileLoad = require("../src/ReplicatedStorage/Shared/ProfileLoad")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")

local USER = 10427235156
local OTHER = 42
local KEY = "Player_" .. tostring(USER)
local NOW = 1_700_000_000
local TIMEOUT = SessionLock.TIMEOUT_SECONDS
local PLACE = 1

local function read(store: MemoryStore.Store, key: string): any
	local seen = nil
	store:updateAsync(key, function(current)
		seen = current
		return nil
	end)
	return seen
end

local function hold(age: number, jobId: string, userId: number?): SessionLock.Lock
	return SessionLock.claim(NOW - age, jobId, PLACE, userId)
end

describe("Save lock release", function()
	it("takes a stale same-user lock in Studio and keeps the gold", function()
		expect(Schema.VERSION).toEqual(26)
		expect(SessionLock.STUDIO_STEAL_SECONDS).toEqual(60)
		expect(LaunchGate.SHOW.saveTools).toEqual(false)
		expect(LaunchGate.on("saveTools")).toEqual(false)

		local stale = hold(60, "studio-old", USER)
		expect(SessionLock.status(stale, NOW, "studio-new", TIMEOUT, USER, true)).toEqual("expired")
		expect(SessionLock.canWrite(stale, NOW, "studio-new", TIMEOUT)).toEqual(false)
		-- One second inside the minute stays busy, and so does someone else.
		local fresh = hold(59, "studio-old", USER)
		expect(SessionLock.status(fresh, NOW, "studio-new", TIMEOUT, USER, true)).toEqual("busy")
		local other = hold(90, "studio-old", OTHER)
		expect(SessionLock.status(other, NOW, "studio-new", TIMEOUT, USER, true)).toEqual("busy")
		-- A legacy lock has no userId. The key is already this player's.
		local legacy = hold(60, "studio-old", nil)
		expect(legacy.userId).toBeNil()
		expect(SessionLock.status(legacy, NOW, "studio-new", TIMEOUT, USER, true)).toEqual(
			"expired"
		)
		-- This server's own lock stays owned, even when the timestamp is old.
		expect(SessionLock.status(stale, NOW, "studio-old", TIMEOUT, USER, true)).toEqual("owned")

		local held = {
			Data = { schemaVersion = 26, gold = 80 },
			Lock = stale,
		}
		local denied, deniedReason =
			SessionLock.trySave(held, NOW, "studio-new", PLACE, TIMEOUT, { gold = 0 }, true)
		expect(denied).toBeNil()
		expect(deniedReason).toEqual("lost")
		expect(held.Data.gold).toEqual(80)
		expect(held.Lock.jobId).toEqual("studio-old")

		local stolen, reason = SessionLock.tryClaim(
			held,
			NOW,
			"studio-new",
			PLACE,
			TIMEOUT,
			{ schemaVersion = 26, gold = 80 },
			USER,
			true
		)
		expect(reason).toEqual("claimed")
		assert(stolen ~= nil)
		expect(stolen.Lock.jobId).toEqual("studio-new")
		expect(stolen.Lock.userId).toEqual(USER)
		expect(stolen.Data.gold).toEqual(80)
		expect(held.Data.gold).toEqual(80)
		expect(held.Lock.jobId).toEqual("studio-old")

		local stranger, strangerReason =
			SessionLock.trySave(stolen, NOW, "server-c", PLACE, TIMEOUT, { gold = 1 }, false)
		expect(stranger).toBeNil()
		expect(strangerReason).toEqual("lost")
		expect(stolen.Data.gold).toEqual(80)

		local store = MemoryStore.new()
		store:updateAsync(KEY, function(_current)
			return {
				Data = { schemaVersion = 26, gold = 80 },
				Lock = hold(SessionLock.STUDIO_STEAL_SECONDS, "studio-old", USER),
			}
		end)
		store:updateAsync(KEY, function(document)
			local written, saveReason =
				SessionLock.trySave(document, NOW, "studio-new", PLACE, TIMEOUT, { gold = 0 }, true)
			expect(written).toBeNil()
			expect(saveReason).toEqual("lost")
			return written
		end)
		expect(read(store, KEY).Data.gold).toEqual(80)
		expect(read(store, KEY).Lock.jobId).toEqual("studio-old")

		local opened =
			ProfileLoad.open(store, KEY, NOW, "studio-new", PLACE, TIMEOUT, nil, USER, true)
		expect(opened.reason).toEqual("claimed")
		expect(opened.session).toEqual(false)
		assert(opened.data ~= nil)
		expect(opened.data.gold).toEqual(80)
		expect(opened.data.schemaVersion).toEqual(26)
		local after = read(store, KEY)
		expect(after.Lock.jobId).toEqual("studio-new")
		expect(after.Lock.userId).toEqual(USER)
		expect(after.Data.gold).toEqual(80)
	end)

	it("keeps a fresh live lock and retries that load across about 30 seconds", function()
		expect(TIMEOUT).toEqual(20 * 60)
		expect(SessionLock.LIVE_BUSY_ATTEMPTS).toEqual(4)
		expect(SessionLock.LIVE_BUSY_WINDOW_SECONDS).toEqual(30)

		local waited = 0
		local pauses = 0
		local attempt = 1
		while SessionLock.liveBusyShouldRetry(attempt) do
			waited += SessionLock.liveBusyPause(attempt)
			pauses += 1
			attempt += 1
		end
		expect(pauses).toEqual(3)
		expect(attempt).toEqual(SessionLock.LIVE_BUSY_ATTEMPTS)
		expect(SessionLock.liveBusyShouldRetry(attempt)).toEqual(false)
		expect(SessionLock.liveBusyPause(attempt)).toEqual(0)
		expect(waited).toEqual(30)

		local fresh = hold(5, "server-a", USER)
		expect(SessionLock.status(fresh, NOW, "server-b", TIMEOUT, USER, false)).toEqual("busy")
		expect(SessionLock.status(fresh, NOW, "server-b", TIMEOUT)).toEqual("busy")
		-- Older than the Studio minute, still inside the live crash timeout.
		local aging = hold(90, "server-a", USER)
		expect(SessionLock.status(aging, NOW, "server-b", TIMEOUT, USER, false)).toEqual("busy")
		expect(SessionLock.status(aging, NOW, "server-b", TIMEOUT, USER, nil)).toEqual("busy")
		local minute = hold(60, "server-a", USER)
		expect(SessionLock.status(minute, NOW, "server-b", TIMEOUT, USER, false)).toEqual("busy")

		local refused, refusedReason = SessionLock.tryClaim(
			{ Data = { gold = 80 }, Lock = fresh },
			NOW,
			"server-b",
			PLACE,
			TIMEOUT,
			{ gold = 0 },
			USER,
			false
		)
		expect(refused).toBeNil()
		expect(refusedReason).toEqual("busy")

		local store = MemoryStore.new()
		store:updateAsync(KEY, function(_current)
			return {
				Data = { schemaVersion = 26, gold = 80 },
				Lock = hold(5, "server-a", USER),
			}
		end)
		local blocked =
			ProfileLoad.open(store, KEY, NOW, "server-b", PLACE, TIMEOUT, nil, USER, false)
		expect(blocked.reason).toEqual("busy")
		expect(blocked.data).toBeNil()
		expect(blocked.session).toEqual(false)
		expect(read(store, KEY).Data.gold).toEqual(80)
		expect(read(store, KEY).Lock.jobId).toEqual("server-a")

		store:updateAsync(KEY, function(document)
			local written, saveReason =
				SessionLock.trySave(document, NOW, "server-b", PLACE, TIMEOUT, { gold = 0 }, false)
			expect(written).toBeNil()
			expect(saveReason).toEqual("lost")
			return written
		end)
		expect(read(store, KEY).Data.gold).toEqual(80)
		expect(read(store, KEY).Lock.jobId).toEqual("server-a")
		expect(read(store, KEY).Lock.lockedAt).toEqual(NOW - 5)
	end)

	it("releases the lock on close and waits for that write before shutdown", function()
		local store = MemoryStore.new()
		local opened =
			ProfileLoad.open(store, KEY, NOW, "server-a", PLACE, TIMEOUT, nil, USER, false)
		expect(opened.reason).toEqual("claimed")
		assert(opened.data ~= nil)
		opened.data.gold = 80
		expect(read(store, KEY).Lock.userId).toEqual(USER)

		local released =
			ProfileLoad.release(store, KEY, NOW + 1, "server-a", PLACE, TIMEOUT, opened.data)
		expect(released.ok).toEqual(true)
		expect(released.reason).toEqual("saved")
		local stored = read(store, KEY)
		expect(stored.Data.gold).toEqual(80)
		expect(stored.Lock.jobId).toEqual("")
		expect(stored.Lock.lockedAt).toEqual(0)
		expect(SessionLock.status(stored.Lock, NOW + 1, "server-b", TIMEOUT)).toEqual("free")

		local late =
			ProfileLoad.release(store, KEY, NOW + 2, "server-a", PLACE, TIMEOUT, { gold = 1 })
		expect(late.ok).toEqual(false)
		expect(late.reason).toEqual("lost")
		expect(read(store, KEY).Data.gold).toEqual(80)
		expect(read(store, KEY).Lock.jobId).toEqual("")

		local again =
			ProfileLoad.open(store, KEY, NOW + 3, "server-b", PLACE, TIMEOUT, nil, USER, true)
		expect(again.reason).toEqual("claimed")
		assert(again.data ~= nil)
		expect(again.data.gold).toEqual(80)
		expect(read(store, KEY).Lock.jobId).toEqual("server-b")
		expect(read(store, KEY).Data.gold).toEqual(80)

		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
		local removingAt =
			string.find(source, "Players.PlayerRemoving:Connect(function(player)", 1, true)
		local removingRelease =
			string.find(source, "DataService.release(player)", removingAt :: number, true)
		expect(removingAt ~= nil and removingRelease ~= nil).toBeTrue()
		expect((removingAt :: number) < (removingRelease :: number)).toBeTrue()

		local closeAt = string.find(source, "game:BindToClose(function()", 1, true)
		local flagAt = string.find(source, "shuttingDown = true", closeAt :: number, true)
		local jobsAt = string.find(source, "releaseJobs", flagAt :: number, true)
		local waitAt =
			string.find(source, "ProfileLoad.shutdownStillWaiting", flagAt :: number, true)
		local openAt = string.find(source, "releasesOpen", flagAt :: number, true)
		expect(
			closeAt ~= nil and flagAt ~= nil and jobsAt ~= nil and waitAt ~= nil and openAt ~= nil
		).toBeTrue()
		expect((flagAt :: number) < (jobsAt :: number)).toBeTrue()
		expect((jobsAt :: number) < (waitAt :: number)).toBeTrue()
		expect((openAt :: number) < (waitAt :: number)).toBeTrue()

		local releaseAt =
			string.find(source, "function DataService.release(player: Player)", 1, true)
		local waitJob =
			string.find(source, "while existing.done ~= true do", releaseAt :: number, true)
		local writeAt = string.find(source, "write(record, true)", releaseAt :: number, true)
		expect(releaseAt ~= nil and waitJob ~= nil and writeAt ~= nil).toBeTrue()
		expect((waitJob :: number) < (writeAt :: number)).toBeTrue()

		local loadAt = string.find(source, "local function load(player: Player)", 1, true)
		local settleAt = string.find(source, "local function settleRecord", 1, true)
		local loadBody = string.sub(source, loadAt :: number, (settleAt :: number) - 1)
		expect(string.find(loadBody, "RunService:IsStudio()", 1, true) ~= nil).toBeTrue()
		expect(string.find(loadBody, "player.UserId", 1, true) ~= nil).toBeTrue()
		expect(string.find(loadBody, "SessionLock.liveBusyShouldRetry(attempt)", 1, true) ~= nil).toBeTrue()
		expect(string.find(loadBody, "SessionLock.liveBusyPause(attempt)", 1, true) ~= nil).toBeTrue()

		local adapter = fs.readFile("src/ServerScriptService/ShardfallServer/StoreAdapter.luau")
		expect(string.find(adapter, "StoreAdapter.STUDIO_LIVE = false", 1, true) ~= nil).toBeTrue()
	end)
end)
