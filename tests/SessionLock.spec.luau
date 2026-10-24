--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")

local TIMEOUT = 100
local NOW = 1_000

describe("SessionLock", function()
	it("claims a key nobody has written", function()
		local document, reason =
			SessionLock.tryClaim(nil, NOW, "server-a", 7, TIMEOUT, { gold = 1 })
		expect(reason).toEqual("claimed")
		assert(document ~= nil)
		expect(document.Lock.jobId).toEqual("server-a")
		expect(document.Lock.placeId).toEqual(7)
		expect(document.Lock.lockedAt).toEqual(NOW)
		expect(document.Data.gold).toEqual(1)
	end)

	it("refuses a fresh lock held by someone else", function()
		local held = {
			Data = { gold = 5 },
			Lock = SessionLock.claim(NOW - 5, "server-a", 7),
		}
		local document, reason =
			SessionLock.tryClaim(held, NOW, "server-b", 7, TIMEOUT, { gold = 0 })
		expect(document).toBeNil()
		expect(reason).toEqual("busy")
		expect(SessionLock.status(held.Lock, NOW, "server-b", TIMEOUT)).toEqual("busy")
		-- The refused call must not rewrite the holder's lock.
		expect(held.Lock.jobId).toEqual("server-a")
		expect(held.Data.gold).toEqual(5)
	end)

	it("lets the owner save and keeps the lock, then release clears it", function()
		local held = {
			Data = { gold = 1 },
			Lock = SessionLock.claim(NOW - 30, "server-a", 7),
		}
		local saved, reason =
			SessionLock.trySave(held, NOW, "server-a", 7, TIMEOUT, { gold = 9 }, false)
		expect(reason).toEqual("saved")
		assert(saved ~= nil)
		expect(saved.Data.gold).toEqual(9)
		expect(saved.Lock.jobId).toEqual("server-a")
		expect(saved.Lock.lockedAt).toEqual(NOW)
		-- Own lock stays writable even when the timestamp is old.
		expect(SessionLock.canWrite(held.Lock, NOW + 100000, "server-a", TIMEOUT)).toBeTrue()

		local released, releaseReason =
			SessionLock.trySave(saved, NOW, "server-a", 7, TIMEOUT, { gold = 9 }, true)
		expect(releaseReason).toEqual("saved")
		assert(released ~= nil)
		expect(released.Lock.jobId).toEqual("")
		expect(SessionLock.status(released.Lock, NOW, "server-b", TIMEOUT)).toEqual("free")
	end)

	it("does not let a stranger overwrite or release an owned profile", function()
		local held = {
			Data = { gold = 4 },
			Lock = SessionLock.claim(NOW, "server-a", 7),
		}
		local document, reason =
			SessionLock.trySave(held, NOW + 1, "server-b", 7, TIMEOUT, { gold = 0 }, true)
		expect(document).toBeNil()
		expect(reason).toEqual("lost")
		expect(held.Data.gold).toEqual(4)
	end)

	it("treats an expired foreign lock as claimable", function()
		local held = {
			Data = { gold = 4 },
			Lock = SessionLock.claim(NOW - TIMEOUT, "server-a", 7),
		}
		expect(SessionLock.status(held.Lock, NOW, "server-b", TIMEOUT)).toEqual("expired")
		local document, reason =
			SessionLock.tryClaim(held, NOW, "server-b", 8, TIMEOUT, { gold = 4 })
		expect(reason).toEqual("claimed")
		assert(document ~= nil)
		expect(document.Lock.jobId).toEqual("server-b")
		expect(document.Lock.placeId).toEqual(8)
	end)

	it("treats a lock one second inside the window as busy", function()
		local lock = SessionLock.claim(NOW - (TIMEOUT - 1), "server-a", 1)
		expect(SessionLock.status(lock, NOW, "server-b", TIMEOUT)).toEqual("busy")
	end)

	it("reports a missing document on save so the caller does not invent data", function()
		local document, reason =
			SessionLock.trySave(nil, NOW, "server-a", 1, TIMEOUT, { gold = 1 }, false)
		expect(document).toBeNil()
		expect(reason).toEqual("missing")
	end)

	it("lets another server claim a lock whose timestamp is not finite", function()
		local nanLock = {
			jobId = "server-a",
			placeId = 7,
			lockedAt = 0 / 0,
		}
		expect(SessionLock.status(nanLock, NOW, "server-a", TIMEOUT)).toEqual("owned")
		expect(SessionLock.status(nanLock, NOW, "server-b", TIMEOUT)).toEqual("expired")
		local hugeLock = {
			jobId = "server-a",
			placeId = 7,
			lockedAt = math.huge,
		}
		expect(SessionLock.status(hugeLock, NOW, "server-a", TIMEOUT)).toEqual("owned")
		expect(SessionLock.status(hugeLock, NOW, "server-b", TIMEOUT)).toEqual("expired")
		local held = {
			Data = { gold = 80 },
			Lock = nanLock,
		}
		local document, reason =
			SessionLock.tryClaim(held, NOW, "server-b", 8, TIMEOUT, { gold = 80 })
		expect(reason).toEqual("claimed")
		assert(document ~= nil)
		expect(document.Lock.jobId).toEqual("server-b")
		expect(document.Data.gold).toEqual(80)
		expect(held.Data.gold).toEqual(80)
		local fresh = SessionLock.claim(NOW, "server-a", 7)
		expect(SessionLock.status(fresh, NOW, "server-b", TIMEOUT)).toEqual("busy")
	end)

	it("releases an owned lock without replacing the stored profile", function()
		local held = {
			Data = { gold = 80 },
			Lock = SessionLock.claim(NOW, "server-a", 7),
		}
		local released, reason = SessionLock.tryRelease(held, "server-a")
		expect(reason).toEqual("released")
		assert(released ~= nil)
		expect(released.Data.gold).toEqual(80)
		expect(released.Lock.jobId).toEqual("")
		expect(held.Data.gold).toEqual(80)
		expect(SessionLock.status(released.Lock, NOW, "server-b", TIMEOUT)).toEqual("free")

		local stranger, strangerReason = SessionLock.tryRelease(held, "server-b")
		expect(stranger).toBeNil()
		expect(strangerReason).toEqual("busy")
		expect(held.Lock.jobId).toEqual("server-a")
		expect(held.Data.gold).toEqual(80)

		local missing, missingReason = SessionLock.tryRelease(nil, "server-a")
		expect(missing).toBeNil()
		expect(missingReason).toEqual("missing")
	end)
end)
