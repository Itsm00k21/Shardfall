--!strict

--[[
	A profile load that outlives CallBudget must not claim the session
	lock or rewrite the saved document. The transform runs later, on the
	spawned UpdateAsync, after DataService has already given up on that
	attempt.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CallBudget = require("../src/ReplicatedStorage/Shared/CallBudget")
local MemoryStore = require("../src/ReplicatedStorage/Shared/MemoryStore")
local ProfileLoad = require("../src/ReplicatedStorage/Shared/ProfileLoad")
local Progression = require("../src/ReplicatedStorage/Shared/Progression")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")

local NOW = 1_700_000_000
local TIMEOUT = SessionLock.TIMEOUT_SECONDS
local KEY = "Player_1"
local LAST_SEEN = NOW - Progression.WELCOME_GAP - 10

local function document(): any
	local data = Schema.migrate({
		schemaVersion = Schema.VERSION,
		gold = 80,
		level = 6,
		lastSeen = LAST_SEEN,
		restCharges = 0,
		welcomeCharges = 0,
	})
	expect(data ~= nil).toBeTrue()
	expect(data.lastSeen).toEqual(LAST_SEEN)
	expect(data.gold).toEqual(80)
	expect(data.restCharges).toEqual(0)
	expect(data.welcomeCharges).toEqual(0)
	return {
		Data = data,
		Lock = {
			jobId = "",
			placeId = 0,
			lockedAt = 0,
		},
	}
end

local function read(store: MemoryStore.Store, key: string): any
	local seen = nil
	store:updateAsync(key, function(current)
		seen = current
		return nil
	end)
	return seen
end

describe("Profile load budget", function()
	it("still claims when the attempt token is current", function()
		local store = MemoryStore.new()
		local saved = document()
		store:updateAsync(KEY, function(_current)
			return saved
		end)
		local generation = 1
		local opened = ProfileLoad.open(store, KEY, NOW, "live-server", 0, TIMEOUT, {
			token = generation,
			current = function()
				return generation
			end,
		})
		expect(opened.session).toBeFalse()
		expect(opened.reason).toEqual("claimed")
		expect(opened.data.lastSeen).toEqual(NOW)
		expect(opened.data.restCharges).toEqual(Progression.REST_CHARGES)
		expect(opened.data.welcomeCharges).toEqual(Progression.WELCOME_CHARGES)
		expect(opened.data.gold).toEqual(80)
		local held = read(store, KEY)
		expect(held.Lock.jobId).toEqual("live-server")
		expect(held.Data.lastSeen).toEqual(NOW)
		expect(held.Data.gold).toEqual(80)
	end)

	it("does not claim or rewrite when the attempt token is already stale", function()
		local store = MemoryStore.new()
		local saved = document()
		store:updateAsync(KEY, function(_current)
			return saved
		end)
		local generation = 2
		local opened = ProfileLoad.open(store, KEY, NOW, "late-server", 0, TIMEOUT, {
			token = 1,
			current = function()
				return generation
			end,
		})
		expect(opened.session).toBeFalse()
		expect(opened.data).toBeNil()
		expect(opened.reason).toEqual("abandoned")
		local after = read(store, KEY)
		expect(after.Lock.jobId).toEqual("")
		expect(after.Lock.lockedAt).toEqual(0)
		expect(after.Data.lastSeen).toEqual(LAST_SEEN)
		expect(after.Data.gold).toEqual(80)
		expect(after.Data.restCharges).toEqual(0)
		expect(after.Data.welcomeCharges).toEqual(0)

		local generationNow = 2
		local claimed = ProfileLoad.open(store, KEY, NOW, "next-server", 0, TIMEOUT, {
			token = generationNow,
			current = function()
				return generationNow
			end,
		})
		expect(claimed.reason).toEqual("claimed")
		expect(claimed.data.lastSeen).toEqual(NOW)
		local held = read(store, KEY)
		expect(held.Lock.jobId).toEqual("next-server")
		expect(held.Data.gold).toEqual(80)
	end)

	it("discards a transform that finishes after CallBudget returns", function()
		-- Lune has no Roblox task global. CallBudget.run spawns with it.
		getfenv().task = require("@lune/task")
		local stored = document()
		local generation = 1
		local token = generation
		local ran = false
		local written = nil
		local blocking = {
			persistent = true,
			updateAsync = function(_self, _key, transform)
				while generation == token do
					task.wait(0.05)
				end
				written = transform(stored)
				if written ~= nil then
					stored = written
				end
				ran = true
				return stored
			end,
		}
		local callOk, outcome = CallBudget.run(0.2, function()
			return ProfileLoad.open(blocking, KEY, NOW, "late-server", 0, TIMEOUT, {
				token = token,
				current = function()
					return generation
				end,
			})
		end)
		expect(callOk).toBeFalse()
		expect(outcome).toEqual("timed out")
		generation += 1
		local deadline = os.clock() + 2
		while not ran and os.clock() < deadline do
			task.wait(0.05)
		end
		expect(ran).toBeTrue()
		expect(written).toBeNil()
		expect(stored.Lock.jobId).toEqual("")
		expect(stored.Lock.lockedAt).toEqual(0)
		expect(stored.Data.lastSeen).toEqual(LAST_SEEN)
		expect(stored.Data.gold).toEqual(80)
		expect(stored.Data.restCharges).toEqual(0)
		expect(stored.Data.welcomeCharges).toEqual(0)

		local nextToken = generation
		local claimed = ProfileLoad.open(
			{
				persistent = true,
				updateAsync = function(_self, _key, transform)
					local updated = transform(stored)
					if updated ~= nil then
						stored = updated
					end
					return stored
				end,
			},
			KEY,
			NOW,
			"next-server",
			0,
			TIMEOUT,
			{
				token = nextToken,
				current = function()
					return generation
				end,
			}
		)
		expect(claimed.reason).toEqual("claimed")
		expect(stored.Lock.jobId).toEqual("next-server")
		expect(stored.Data.lastSeen).toEqual(NOW)
		expect(stored.Data.gold).toEqual(80)
		expect(stored.Data.restCharges).toEqual(Progression.REST_CHARGES)
	end)

	it("drops the load token in DataService before the retry can yield", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
		local loadAt = string.find(source, "local function load(player: Player)", 1, true)
		local nextAt = string.find(source, "local function settleRecord", 1, true)
		expect(loadAt ~= nil and nextAt ~= nil and (loadAt :: number) < (nextAt :: number)).toBeTrue()
		local before = string.sub(source, 1, (loadAt :: number) - 1)
		local body = string.sub(source, loadAt :: number, (nextAt :: number) - 1)
		expect(string.find(before, "local generation = 0", 1, true)).toBeNil()
		expect(string.find(body, "local generation = 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "watch", 1, true) ~= nil).toBeTrue()
		local failAt = string.find(body, "if not callOk then", 1, true)
		local sessionAt = string.find(body, "outcome.session == true", 1, true)
		expect(failAt ~= nil and sessionAt ~= nil).toBeTrue()
		local failBody = string.sub(body, failAt :: number, (sessionAt :: number) - 1)
		expect(string.find(failBody, "dropAttempt(token)", 1, true) ~= nil).toBeTrue()
		local fallbackAt = string.find(failBody, "sessionFallback", 1, true)
		local dropAt = string.find(failBody, "dropAttempt(token)", 1, true)
		expect(dropAt ~= nil and fallbackAt ~= nil and (dropAt :: number) < (fallbackAt :: number)).toBeTrue()
		local retryAt = string.find(body, "task.wait(LOAD_RETRY_SECONDS)", 1, true)
		expect(retryAt ~= nil and dropAt ~= nil and (dropAt :: number) < (retryAt :: number)).toBeTrue()
		local successAt = string.find(body, "outcome.data ~= nil", 1, true)
		expect(successAt ~= nil).toBeTrue()
		local successBody = string.sub(body, successAt :: number, (successAt :: number) + 500)
		expect(string.find(successBody, "dropAttempt", 1, true)).toBeNil()
	end)
end)
