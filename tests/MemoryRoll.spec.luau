--!strict

--[[
	The unpublished-Studio path: DataStores are unavailable, so the profile
	lives in MemoryStore. A free roll still has to spend a token, store the
	item, and survive a later read. This is the same adapter DataService
	uses after the DataStore probe fails.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local MemoryStore = require("../src/ReplicatedStorage/Shared/MemoryStore")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local RollMath = require("../src/ReplicatedStorage/Shared/RollMath")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")

local function zeroRng()
	return {
		nextNumber = function()
			return 0
		end,
		nextInteger = function(_self, min: number, _max: number)
			return min
		end,
	}
end

describe("memory-mode roll", function()
	it("cracks a shard, grants dev stats, and reads them back", function()
		local store = MemoryStore.new()
		expect(store.persistent).toBeFalse()

		local key = "Player_1"
		local serverId = "studio-test"
		local now = 1_000
		local timeout = SessionLock.TIMEOUT_SECONDS
		local live = nil

		store:updateAsync(key, function(document)
			local migrated = Schema.migrate(if document ~= nil then document.Data else nil)
			assert(migrated ~= nil, "new profile should migrate")
			local written, reason = SessionLock.tryClaim(
				if type(document) == "table" then document else nil,
				now,
				serverId,
				0,
				timeout,
				Schema.deepCopy(migrated)
			)
			expect(reason).toEqual("claimed")
			live = migrated
			return written
		end)
		assert(live ~= nil, "profile should load from memory")
		expect(live.shardTokens).toEqual(10)
		expect(live.shardLuck).toEqual(0)

		local pool = Pools.get(Pools.DEFAULT_POOL_ID)
		assert(pool ~= nil, "starter pool")
		local pity = Schema.pityBucket(live, pool.id)
		local rolled = RollMath.roll(pool, pity, {
			luck = live.shardLuck,
			uid = "item-1",
			now = now,
		}, zeroRng())
		live.shardTokens -= 1
		Schema.insertItem(live, rolled.item)
		-- Same mutations the Studio dev buttons apply, on the memory profile.
		live.shardTokens += 5
		live.shardLuck += 25

		store:updateAsync(key, function(document)
			local written, reason = SessionLock.trySave(
				document,
				now + 1,
				serverId,
				0,
				timeout,
				Schema.deepCopy(live),
				false
			)
			expect(reason).toEqual("saved")
			return written
		end)

		local saved = nil
		store:updateAsync(key, function(document)
			saved = document
			return nil
		end)
		assert(saved ~= nil, "memory key should still exist")
		expect(saved.Data.shardTokens).toEqual(14)
		expect(saved.Data.shardLuck).toEqual(25)
		expect(saved.Data.inventory["item-1"].templateId).toEqual("vinewood_sword")
		expect(saved.Data.inventory["item-1"].name).toEqual("Vinewood Sword")
		expect(saved.Data.inventory["item-1"].quality).toEqual(0)
		expect(saved.Data.inventory["item-1"].stats[1].value).toEqual(10)
		expect(saved.Data.pity[pool.id].totalRolls).toEqual(1)
		expect(saved.Lock.jobId).toEqual(serverId)
	end)
end)
