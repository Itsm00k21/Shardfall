--!strict

--[[
	A party save that fails after one profile was released has to use
	the reclaim result. Marking that profile loaded lets later loot
	sit in memory until autosave sees a lost lock and kicks. The grant
	never reaches the store.
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

local function read(store: MemoryStore.Store, key: string): any
	local seen = nil
	store:updateAsync(key, function(document)
		seen = document
		return nil
	end)
	return seen
end

local function claim(store: MemoryStore.Store, key: string, jobId: string): any
	local opened = ProfileLoad.open(store, key, NOW, jobId, PLACE, TIMEOUT)
	expect(opened.session).toBeFalse()
	expect(opened.reason).toEqual("claimed")
	assert(opened.data ~= nil, "profile should load")
	return opened.data
end

describe("Party reclaim", function()
	it("drops a plaza loot grant when the released profile was claimed elsewhere", function()
		local store = MemoryStore.new()
		local key = "Player_28"
		local data = claim(store, key, "plaza")
		data.gold = 10
		local released = ProfileLoad.release(store, key, NOW + 1, "plaza", PLACE, TIMEOUT, data)
		expect(released.ok).toBeTrue()

		local raidGold = Schema.deepCopy(data)
		raidGold.gold = 99
		local raid = ProfileLoad.reclaim(store, key, NOW + 2, "raid", PLACE, TIMEOUT, raidGold)
		expect(raid.ok).toBeTrue()

		local again = ProfileLoad.reclaim(store, key, NOW + 3, "plaza", PLACE, TIMEOUT, data)
		expect(again.ok).toBeFalse()
		expect(ProfileLoad.failedHop(true, again.ok == true)).toEqual("kick")

		-- The bug marked this profile loaded and then granted loot.
		-- That write does not own the lock, so the grant is lost.
		data.gold = 500
		local wrote = nil
		local reason = nil
		store:updateAsync(key, function(document)
			wrote, reason = SessionLock.trySave(document, NOW + 4, "plaza", PLACE, TIMEOUT, data, false)
			return wrote
		end)
		expect(reason).toEqual("lost")
		expect(wrote).toBeNil()
		local after = read(store, key)
		expect(after.Lock.jobId).toEqual("raid")
		expect(after.Data.gold).toEqual(99)

		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
		local failAt = string.find(source, "if not result.ok then", 1, true)
		local keptAt = string.find(source, 'return "kept", empty', failAt or 1, true)
		expect(failAt ~= nil and keptAt ~= nil and (failAt :: number) < (keptAt :: number)).toBeTrue()
		local block = string.sub(source, failAt :: number, keptAt :: number)
		expect(string.find(block, "recoverFailedHop(done, doneRecord)", 1, true) ~= nil).toBeTrue()
		expect(string.find(block, "settleRecord(doneRecord, false, true)", 1, true)).toBeNil()
		expect(string.find(block, "settleRecord(waitingRecord, false, true)", 1, true) ~= nil).toBeTrue()
		local autosave = string.find(source, "record.loaded", 1, true)
		expect(string.find(source, "and not record.released", autosave or 1, true) ~= nil).toBeTrue()
		local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
		expect(string.find(raid, "function DataService.releasePartyForTeleport", 1, true)).toBeNil()
	end)
end)
