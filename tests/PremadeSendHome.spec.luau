--!strict

--[[
	Sending a premade party home has to clear the session lock first.

	The reserved server still owns the profile when the arrival times out
	or the pull fails to start. Teleporting before the release lets the
	plaza load race PlayerRemoving. A busy lock kicks them, and the raid
	gold never lands. releaseForTeleport saves, then teleports. A failed
	save does not teleport.
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
local RAID = "src/ServerScriptService/ShardfallServer/RaidService.luau"

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

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

describe("Premade send home", function()
	it("lets the plaza load raid gold only after the return release", function()
		local store = MemoryStore.new()
		local key = "Player_29"
		local data = claim(store, key, "raid")
		data.gold = 80

		-- The reserved server still holds the lock. The plaza must not load.
		local early = ProfileLoad.open(store, key, NOW + 1, "plaza", PLACE, TIMEOUT)
		expect(early.session).toBeFalse()
		expect(early.data).toBeNil()
		expect(early.reason).toEqual("busy")

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
			NOW + 2,
			"raid",
			PLACE,
			TIMEOUT,
			data,
			function()
				local seen = read(store, key)
				expect(seen.Lock.jobId).toEqual("")
				expect(seen.Data.gold).toEqual(80)
				expect(SessionLock.status(seen.Lock, NOW + 2, "plaza", TIMEOUT)).toEqual("free")
				table.insert(log, "teleport")
			end
		)
		expect(result.teleported).toBeTrue()
		expect(result.reason).toEqual("saved")
		expect(log[1]).toEqual("release")
		expect(log[2]).toEqual("teleport")
		expect(#log).toEqual(2)

		local arrived = ProfileLoad.open(store, key, NOW + 3, "plaza", PLACE, TIMEOUT)
		expect(arrived.session).toBeFalse()
		expect(arrived.reason).toEqual("claimed")
		assert(arrived.data ~= nil, "plaza should claim")
		expect(arrived.data.gold).toEqual(80)

		-- PlayerRemoving on the reserved server must not write over the plaza.
		data.gold = 1
		local late = ProfileLoad.release(store, key, NOW + 4, "raid", PLACE, TIMEOUT, data)
		expect(late.ok).toBeFalse()
		expect(late.reason).toEqual("lost")
		local held = read(store, key)
		expect(held.Lock.jobId).toEqual("plaza")
		expect(held.Data.gold).toEqual(80)
	end)

	it("does not send anyone home when the release fails", function()
		local store = MemoryStore.new()
		local key = "Player_30"
		local data = claim(store, key, "raid")
		local before = read(store, key)
		local originalGold = before.Data.gold
		data.gold = originalGold + 15

		local calls = 0
		local throttled: ProfileLoad.Adapter = {
			updateAsync = function(_self, _key, _transform)
				error("DataStore request was added to queue. Request was throttled.", 0)
			end,
		}
		local result = ProfileLoad.handoff(
			throttled,
			key,
			NOW + 1,
			"raid",
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

		local plaza = ProfileLoad.open(store, key, NOW + 2, "plaza", PLACE, TIMEOUT)
		expect(plaza.reason).toEqual("busy")
		expect(plaza.data).toBeNil()
		local after = read(store, key)
		expect(after.Lock.jobId).toEqual("raid")
		expect(after.Data.gold).toEqual(originalGold)
		expect(SessionLock.status(after.Lock, NOW + 2, "plaza", TIMEOUT)).toEqual("busy")
	end)

	it("releases inside sendHome before the return teleport", function()
		local raid = fs.readFile(RAID)
		local home = between(raid, "local function sendHome", "local function forgetArrival")
		expect(string.find(home, "premadeRecall = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(home, "userId", 1, true)).toBeNil()
		expect(string.find(home, "hostUserId", 1, true)).toBeNil()
		local releaseAt = string.find(home, "DataService.releaseForTeleport", 1, true)
		local teleportAt = string.find(home, "TeleportToPlaceInstance", 1, true)
		expect(
			releaseAt ~= nil
				and teleportAt ~= nil
				and (releaseAt :: number) < (teleportAt :: number)
		).toBeTrue()
		local span = string.sub(home, releaseAt :: number, teleportAt :: number)
		expect(string.find(span, "function()", 1, true) ~= nil).toBeTrue()
		expect(string.find(home, "releasePartyForTeleport", 1, true)).toBeNil()
		expect(Schema.VERSION).toEqual(26)
	end)
end)
