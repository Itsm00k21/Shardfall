--!strict

--[[
	Phase 0.5 save system. Old fixtures migrate forward, a lock can be
	taken or stolen only when it is free or stale, retries back off, and
	a failed load does not write.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local MemoryStore = require("../src/ReplicatedStorage/Shared/MemoryStore")
local ProfileLoad = require("../src/ReplicatedStorage/Shared/ProfileLoad")
local SaveGuard = require("../src/ReplicatedStorage/Shared/SaveGuard")
local SaveMigrate = require("../src/ReplicatedStorage/Shared/SaveMigrate")
local SaveRetry = require("../src/ReplicatedStorage/Shared/SaveRetry")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")

local KEY = "Player_9"
local NOW = 1_700_000_000
local TIMEOUT = SessionLock.TIMEOUT_SECONDS

local function read(store: MemoryStore.Store, key: string): any
	local seen = nil
	store:updateAsync(key, function(current)
		seen = current
		return nil
	end)
	return seen
end

describe("Phase 0.5 migrations", function()
	it("numbers every step v_n to v_n+1 and stays on schema 26", function()
		expect(Schema.VERSION).toEqual(26)
		expect(SaveMigrate.FLOOR).toEqual(1)
		expect(#Schema.MIGRATIONS).toEqual(Schema.VERSION)
		for index, step in ipairs(Schema.MIGRATIONS) do
			expect(step.to).toEqual(index)
		end
	end)

	it("loads a save with no version as v1 and keeps unknown JSON", function()
		local version, err, versionless = SaveMigrate.versionOf(nil)
		expect(err).toBeNil()
		expect(versionless).toEqual(true)
		expect(version).toEqual(1)

		local saved = {
			gold = 11,
			level = 6,
			futureNote = "keep",
			bad = 0 / 0,
			inventory = {
				sword = {
					uid = "sword",
					templateId = "wooden_sword",
					name = "Old Blade",
					kind = "Weapon",
					offset = function() end,
				},
			},
			pity = {
				starter_shard = { rollsSinceLegendary = 4, totalRolls = 9 },
			},
			receipts = { ["legacy-receipt"] = true },
		}
		local profile, migrateErr = Schema.migrate(saved)
		expect(migrateErr).toBeNil()
		assert(profile ~= nil)
		expect(saved.schemaVersion).toBeNil()
		expect(saved.gold).toEqual(11)
		expect(saved.futureNote).toEqual("keep")
		expect(profile.schemaVersion).toEqual(26)
		expect(profile.gold).toEqual(11)
		expect(profile.level).toEqual(6)
		expect((profile :: any).futureNote).toEqual("keep")
		expect((profile :: any).bad).toBeNil()
		expect(profile.inventory.sword.name).toEqual("Old Blade")
		expect(profile.inventory.sword.templateId).toEqual("wooden_sword")
		expect((profile.inventory.sword :: any).offset).toBeNil()
		expect(profile.pity.starter_shard.totalRolls).toEqual(9)
		expect(profile.receipts["legacy-receipt"]).toEqual(true)
	end)

	it("migrates a v1 fixture forward without dropping gold or the item id", function()
		local old = {
			schemaVersion = 1,
			gold = 15,
			level = 4,
			xp = 2,
			shardTokens = 3,
			inventory = {
				sword = {
					uid = "sword",
					templateId = "wooden_sword",
					name = "Old Blade",
					kind = "Weapon",
				},
			},
		}
		local profile, err = Schema.migrate(old)
		expect(err).toBeNil()
		assert(profile ~= nil)
		expect(old.schemaVersion).toEqual(1)
		expect(old.gold).toEqual(15)
		expect(profile.schemaVersion).toEqual(26)
		expect(profile.gold).toEqual(15)
		expect(profile.level).toEqual(4)
		expect(profile.xp).toEqual(2)
		expect(profile.shardTokens).toEqual(3)
		expect(profile.inventory.sword.templateId).toEqual("wooden_sword")
		expect(type(profile.receipts)).toEqual("table")
		expect(profile.sinceLegendary).toEqual(0)
	end)

	it("runs one step on a copy and leaves the caller's table alone", function()
		local original = { schemaVersion = 0, gold = 3 }
		local copy = Schema.deepCopy(original)
		local version = SaveMigrate.run(copy, 0, false, { Schema.MIGRATIONS[1] })
		expect(version).toEqual(1)
		expect(original.schemaVersion).toEqual(0)
		expect(original.gold).toEqual(3)
		expect(copy.schemaVersion).toEqual(1)
		expect(copy.gold).toEqual(3)
	end)

	it("refuses a newer schema and does not treat NaN as a version", function()
		local _, newer = Schema.migrate({ schemaVersion = 99, gold = 8 })
		expect(newer).toEqual("newer")
		local nanVersion, nanErr = SaveMigrate.versionOf(0 / 0)
		expect(nanVersion).toBeNil()
		expect(nanErr).toEqual("corrupt")
		local _, corrupt = Schema.migrate({ schemaVersion = 0 / 0, gold = 8 })
		expect(corrupt).toEqual("corrupt")
	end)
end)

describe("Phase 0.5 session lock", function()
	it("acquires a free key and refuses a second server", function()
		local first, firstReason =
			SessionLock.tryClaim(nil, NOW, "server-a", 1, TIMEOUT, { gold = 5 })
		expect(firstReason).toEqual("claimed")
		assert(first ~= nil)
		expect(first.Lock.jobId).toEqual("server-a")
		expect(first.Lock.lockedAt).toEqual(NOW)
		expect(first.Data.gold).toEqual(5)

		local second, secondReason =
			SessionLock.tryClaim(first, NOW + 1, "server-b", 1, TIMEOUT, { gold = 0 })
		expect(second).toBeNil()
		expect(secondReason).toEqual("busy")
		expect(first.Data.gold).toEqual(5)
		expect(first.Lock.jobId).toEqual("server-a")
		expect(SaveGuard.alreadyOpen(true)).toEqual(true)
		expect(SaveGuard.alreadyOpen(false)).toEqual(false)
	end)

	it("steals a stale lock and keeps the saved gold", function()
		local held = {
			Data = { gold = 40 },
			Lock = SessionLock.claim(NOW - TIMEOUT, "server-a", 1),
		}
		expect(SessionLock.status(held.Lock, NOW, "server-b", TIMEOUT)).toEqual("expired")
		local stolen, reason =
			SessionLock.tryClaim(held, NOW, "server-b", 1, TIMEOUT, { gold = 40 })
		expect(reason).toEqual("claimed")
		assert(stolen ~= nil)
		expect(stolen.Lock.jobId).toEqual("server-b")
		expect(stolen.Lock.lockedAt).toEqual(NOW)
		expect(stolen.Data.gold).toEqual(40)
		expect(held.Data.gold).toEqual(40)
		expect(held.Lock.jobId).toEqual("server-a")
	end)

	it("does not steal a fresh lock or an owned lock that is old", function()
		local fresh = {
			Data = { gold = 4 },
			Lock = SessionLock.claim(NOW - 5, "server-a", 1),
		}
		expect(SessionLock.status(fresh.Lock, NOW, "server-b", TIMEOUT)).toEqual("busy")
		local denied, reason =
			SessionLock.tryClaim(fresh, NOW, "server-b", 1, TIMEOUT, { gold = 0 })
		expect(denied).toBeNil()
		expect(reason).toEqual("busy")
		expect(fresh.Data.gold).toEqual(4)

		local own = SessionLock.claim(NOW - TIMEOUT - 10, "server-a", 1)
		expect(SessionLock.status(own, NOW, "server-a", TIMEOUT)).toEqual("owned")
		expect(SessionLock.canWrite(own, NOW, "server-a", TIMEOUT)).toEqual(true)
	end)

	it("loads through the store once, then steals only after the timeout", function()
		local store = MemoryStore.new()
		store:updateAsync(KEY, function(_current)
			return {
				Data = { schemaVersion = 26, gold = 40 },
				Lock = SessionLock.claim(NOW - 5, "server-a", 1),
			}
		end)
		local blocked = ProfileLoad.open(store, KEY, NOW, "server-b", 1, TIMEOUT)
		expect(blocked.reason).toEqual("busy")
		expect(blocked.data).toBeNil()
		expect(read(store, KEY).Data.gold).toEqual(40)
		expect(read(store, KEY).Lock.jobId).toEqual("server-a")

		store:updateAsync(KEY, function(current)
			current.Lock = SessionLock.claim(NOW - TIMEOUT, "server-a", 1)
			return current
		end)
		local stolen = ProfileLoad.open(store, KEY, NOW, "server-b", 1, TIMEOUT)
		expect(stolen.reason).toEqual("claimed")
		assert(stolen.data ~= nil)
		expect(stolen.data.gold).toEqual(40)
		local after = read(store, KEY)
		expect(after.Lock.jobId).toEqual("server-b")
		expect(after.Data.gold).toEqual(40)
	end)
end)

describe("Phase 0.5 retry and failed loads", function()
	it("backs off and does not retry a lost lock", function()
		expect(SaveRetry.pauses(1)).toEqual(1)
		expect(SaveRetry.pauses(2)).toEqual(2)
		expect(SaveRetry.pauses(3)).toEqual(4)
		expect(SaveRetry.pauses(4)).toEqual(4)
		expect(SaveRetry.seconds(1, 2)).toEqual(2)
		expect(SaveRetry.seconds(2, 2)).toEqual(4)
		expect(SaveRetry.seconds(3, 2)).toEqual(8)
		expect(SaveRetry.shouldRetry(1, SaveRetry.WRITE_ATTEMPTS, "error")).toEqual(true)
		expect(SaveRetry.shouldRetry(1, SaveRetry.WRITE_ATTEMPTS, "unwritten")).toEqual(true)
		expect(SaveRetry.shouldRetry(1, SaveRetry.WRITE_ATTEMPTS, "lost")).toEqual(false)
		expect(SaveRetry.shouldRetry(1, SaveRetry.WRITE_ATTEMPTS, "missing")).toEqual(false)
		expect(SaveRetry.shouldRetry(SaveRetry.WRITE_ATTEMPTS, SaveRetry.WRITE_ATTEMPTS, "error")).toEqual(
			false
		)
	end)

	it("does not write when the load failed or the store threw", function()
		expect(SaveGuard.refusesWrite(true)).toEqual(true)
		expect(SaveGuard.refusesWrite(false)).toEqual(false)

		local store = MemoryStore.new()
		store:updateAsync(KEY, function(_current)
			return {
				Data = { schemaVersion = 26, gold = 80, inventory = "nope" },
				Lock = SessionLock.cleared(),
			}
		end)
		local corrupt = ProfileLoad.open(store, KEY, NOW, "server-a", 1, TIMEOUT)
		expect(corrupt.reason).toEqual("corrupt")
		expect(corrupt.data).toBeNil()
		expect(corrupt.session).toEqual(false)
		expect(read(store, KEY).Data.gold).toEqual(80)
		expect(read(store, KEY).Data.inventory).toEqual("nope")
		expect(read(store, KEY).Lock.jobId).toEqual("")

		local armed = true
		local inner = store.updateAsync
		function store:updateAsync(key: string, transform: (any) -> any)
			if armed then
				armed = false
				error("datastore down")
			end
			return inner(self, key, transform)
		end
		local thrown = ProfileLoad.open(store, KEY, NOW, "server-a", 1, TIMEOUT)
		expect(thrown.session).toEqual(true)
		expect(thrown.reason).toEqual("session")
		expect(read(store, KEY).Data.gold).toEqual(80)

		local writes = 0
		local function commit(failed: boolean, ephemeral: boolean, gold: number): boolean
			if ephemeral == true or SaveGuard.refusesWrite(failed) then
				return false
			end
			writes += 1
			store:updateAsync(KEY, function(current)
				current.Data.gold = gold
				return current
			end)
			return true
		end
		expect(commit(true, false, 0)).toEqual(false)
		expect(commit(false, true, 0)).toEqual(false)
		expect(writes).toEqual(0)
		expect(read(store, KEY).Data.gold).toEqual(80)
		expect(commit(false, false, 7)).toEqual(true)
		expect(read(store, KEY).Data.gold).toEqual(7)
	end)

	it("wires backoff, the failed-load guard, autosave, and the shutdown flush", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
		expect(string.find(source, "local AUTOSAVE_SECONDS = 60", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "game:BindToClose(function()", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "DataService.release", 1, true) ~= nil).toBeTrue()

		local writeAt = string.find(
			source,
			"local function write(record: Record, releaseLock: boolean)",
			1,
			true
		)
		local saveAt = string.find(source, "function DataService.save(player: Player)", 1, true)
		expect(writeAt ~= nil and saveAt ~= nil and (writeAt :: number) < (saveAt :: number)).toBeTrue()
		local writeBody = string.sub(source, writeAt :: number, (saveAt :: number) - 1)
		local ephemeralAt = string.find(writeBody, "record.ephemeral == true", 1, true)
		local guardAt = string.find(writeBody, "SaveGuard.refusesWrite", 1, true)
		local updateAt = string.find(writeBody, "store:updateAsync", 1, true)
		expect(ephemeralAt ~= nil and guardAt ~= nil and updateAt ~= nil).toBeTrue()
		expect((ephemeralAt :: number) < (guardAt :: number)).toBeTrue()
		expect((guardAt :: number) < (updateAt :: number)).toBeTrue()
		expect(string.find(writeBody, "SaveRetry.shouldRetry", 1, true) ~= nil).toBeTrue()
		expect(string.find(writeBody, '"lost"', 1, true)).toBeNil()

		local loadAt = string.find(source, "local function load(player: Player)", 1, true)
		local settleAt = string.find(source, "local function settleRecord", 1, true)
		local loadBody = string.sub(source, loadAt :: number, (settleAt :: number) - 1)
		local pausesAt = string.find(loadBody, "SaveRetry.pauses(attempt)", 1, true)
		local waitAt = string.find(loadBody, "task.wait(LOAD_RETRY_SECONDS)", 1, true)
		expect(pausesAt ~= nil and waitAt ~= nil and (pausesAt :: number) < (waitAt :: number)).toBeTrue()
		expect(string.find(loadBody, "SaveGuard.alreadyOpen", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(source, "ProfileLoad.maySave(record.loaded, record.ephemeral)", 1, true)
				~= nil
		).toBeTrue()
		expect(string.find(source, "SaveGuard.refusesWrite(record.failed == true)", 1, true) ~= nil).toBeTrue()
	end)
end)
