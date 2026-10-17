--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidLockout = require("../src/ReplicatedStorage/Shared/RaidLockout")
local RaidMarks = require("../src/ReplicatedStorage/Shared/RaidMarks")
local Raids = require("../src/ReplicatedStorage/Shared/Raids")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local ERRORS = RaidLockout.ERRORS
local REASONS = RaidLockout.REASONS

-- 2026-10-13 00:00:00 UTC, a Tuesday. RaidMarks week key 2963.
local TUESDAY = 1791849600
local WEEK = 7 * 86400

local function clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = clone(child)
	end
	return copy
end

local function freezeDeep(value: any)
	if type(value) ~= "table" then
		return
	end
	for _, child in pairs(value) do
		freezeDeep(child)
	end
	if not table.isfrozen(value) then
		table.freeze(value)
	end
end

local function claimOf(boss: string, difficulty: string, id: any, extra: any?): any
	local claim = {
		claimId = id,
		bossId = boss,
		difficulty = difficulty,
	}
	if type(extra) == "table" then
		for key, child in pairs(extra) do
			claim[key] = child
		end
	end
	return claim
end

local function take(state: any, boss: string, difficulty: string, id: any, now: number?): any
	return RaidLockout.claim(state, claimOf(boss, difficulty, id), now or TUESDAY)
end

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

local function mentionsLockout(source: string): boolean
	if string.find(source, "Shared.RaidLockout", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidLockout", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidLockout", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidLockout")', 1, true) ~= nil then
		return true
	end
	return false
end

describe("RaidLockout config", function()
	it("pins the four locks, fracture, and the storage caps", function()
		expect(RaidLockout.CONFIG.maxIdLength).toEqual(64)
		expect(RaidLockout.CONFIG.retainWeeks).toEqual(1)
		expect(RaidLockout.CONFIG.maxClaims).toEqual(256)
		expect(RaidLockout.LOCKED.story).toEqual(true)
		expect(RaidLockout.LOCKED.normal).toEqual(true)
		expect(RaidLockout.LOCKED.hard).toEqual(true)
		expect(RaidLockout.LOCKED.shardbreaker).toEqual(true)
		expect(RaidLockout.LOCKED.fracture).toBeNil()
		expect(RaidLockout.LOCKED.practice).toBeNil()
		expect(RaidLockout.LOCKED.guided).toBeNil()
		expect(RaidLockout.OPEN.fracture).toEqual(true)
		expect(RaidLockout.REFUSED.practice).toEqual(true)
		expect(RaidLockout.REFUSED.guided).toEqual(true)
		expect(RaidLockout.REFUSED.story).toBeNil()
		expect(RaidLockout.REASONS.loot).toEqual("loot")
		expect(RaidLockout.REASONS.lockout).toEqual("lockout")
		expect(RaidLockout.REASONS.fracture).toEqual("fracture")
		expect(RaidLockout.REASONS.practice).toEqual("practice")
		expect(RaidLockout.REASONS.duplicate).toEqual("duplicate")
		expect(RaidLockout.CONFIG.tuesdayOffset).toBeNil()
		expect(RaidLockout.CONFIG.weekSeconds).toBeNil()
		expect(RaidLockout.CONFIG.doubleMarks).toBeNil()
		expect(RaidMarks.CONFIG.doubleMarks).toEqual(false)
		expect(Schema.VERSION).toEqual(23)
	end)

	it("freezes the config, the difficulties, and the errors", function()
		expect(function()
			RaidLockout.CONFIG.retainWeeks = 4
		end).toThrow()
		expect(function()
			RaidLockout.LOCKED.fracture = true
		end).toThrow()
		expect(function()
			RaidLockout.OPEN.story = true
		end).toThrow()
		expect(function()
			RaidLockout.REFUSED.story = true
		end).toThrow()
		expect(function()
			RaidLockout.ERRORS.skip = "nope"
		end).toThrow()
		expect(function()
			RaidLockout.REASONS.loot = "nope"
		end).toThrow()
	end)

	it("reuses RaidMarks.weekKey and does not restate it", function()
		local times = {
			0,
			1,
			TUESDAY - 1,
			TUESDAY - 0.1,
			TUESDAY,
			TUESDAY + 0.1,
			TUESDAY + WEEK,
			TUESDAY + WEEK - 1,
		}
		for _, now in ipairs(times) do
			expect(RaidLockout.weekKey(now)).toEqual(RaidMarks.weekKey(now))
		end
		expect(RaidLockout.weekKey(TUESDAY)).toEqual(2963)
		expect(RaidLockout.weekKey(TUESDAY - 1)).toEqual(2962)
		expect(RaidLockout.weekKey(TUESDAY + WEEK)).toEqual(2964)
		expect(RaidLockout.weekKey(0)).toEqual(0)
		expect(RaidLockout.weekKey(-1)).toBeNil()
		expect(RaidLockout.weekKey(0 / 0)).toBeNil()
		expect(RaidLockout.weekKey(math.huge)).toBeNil()
		expect(Raids.weekNumber(TUESDAY)).toEqual(2962)
		expect(RaidLockout.weekKey(TUESDAY) == Raids.weekNumber(TUESDAY)).toEqual(false)
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidLockout.luau")
		local _, requires = string.gsub(source, "require%(", "")
		expect(requires).toEqual(1)
		expect(string.find(source, 'require("./RaidMarks")', 1, true)).toBeGreaterThan(0)
		expect(string.find(source, "RaidMarks.weekKey", 1, true)).toBeGreaterThan(0)
		local banned = {
			"tuesdayOffset",
			"432000",
			"weekNumber",
			"weekSeconds",
			"Raids",
			"math.random",
			"os.time",
			"os.clock",
			"os.",
			"Random.new",
			"GetService",
			"DataStore",
			"MemoryStore",
			"MarketplaceService",
			"DateTime",
			"tick(",
			"task.wait",
			"doubleMarks",
			"Schema",
			"RaidService",
			"DungeonService",
			"PracticeLoot",
		}
		for _, needle in ipairs(banned) do
			expect(string.find(source, needle, 1, true)).toBeNil()
		end
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if
				path ~= "src/ReplicatedStorage/Shared/RaidLockout.luau"
				and mentionsLockout(fs.readFile(path))
			then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)

describe("RaidLockout claim", function()
	it("locks a boss once per difficulty and returns a new table", function()
		local first = take(nil, "twins", "story", "run-1")
		expect(first.ok).toEqual(true)
		expect(first.persist).toEqual(true)
		expect(first.lootEligible).toEqual(true)
		expect(first.reclearRewards).toEqual(true)
		expect(first.locked).toEqual(true)
		expect(first.reason).toEqual(REASONS.loot)
		expect(first.weekKey).toEqual(2963)
		expect(first.bossId).toEqual("twins")
		expect(first.difficulty).toEqual("story")
		expect(first.claimId).toEqual("run-1")
		expect(first.error).toBeNil()
		expect(first.amount).toBeNil()
		expect(first.marks).toBeNil()
		expect(first.dust).toBeNil()
		expect(first.state.weeks).toEqual({
			{
				weekKey = 2963,
				locks = { "twins:story" },
				claims = { "run-1" },
			},
		})
		local again = take(first.state, "twins", "story", "run-2")
		expect(again.ok).toEqual(true)
		expect(again.persist).toEqual(true)
		expect(again.lootEligible).toEqual(false)
		expect(again.reclearRewards).toEqual(true)
		expect(again.locked).toEqual(true)
		expect(again.reason).toEqual(REASONS.lockout)
		expect(again.state.weeks[1].locks).toEqual({ "twins:story" })
		expect(again.state.weeks[1].claims).toEqual({ "run-1", "run-2" })
		expect(again.state == first.state).toEqual(false)
		expect(again.state.weeks == first.state.weeks).toEqual(false)
		expect(again.state.weeks[1] == first.state.weeks[1]).toEqual(false)
		expect(first.state.weeks[1].claims).toEqual({ "run-1" })
	end)

	it("treats the same claim id as a no-op", function()
		local first = take(nil, "sapwell", "hard", "same")
		local before = clone(first.state)
		local replay = RaidLockout.claim(first.state, {
			claimId = " same ",
			bossId = "galecrown",
			difficulty = "normal",
			practice = true,
			guided = true,
		}, TUESDAY)
		expect(replay.ok).toEqual(true)
		expect(replay.persist).toEqual(false)
		expect(replay.lootEligible).toEqual(false)
		expect(replay.reclearRewards).toEqual(false)
		expect(replay.locked).toEqual(false)
		expect(replay.reason).toEqual(REASONS.duplicate)
		expect(replay.claimId).toEqual("same")
		expect(replay.error).toBeNil()
		expect(replay.state).toEqual(before)
		expect(replay.state == first.state).toEqual(false)
		expect(first.state).toEqual(before)
		local numeric = take(nil, "twins", "story", 7)
		local text = take(numeric.state, "twins", "story", "7")
		expect(text.reason).toEqual(REASONS.lockout)
		expect(text.lootEligible).toEqual(false)
		expect(text.reclearRewards).toEqual(true)
		expect(text.state.weeks[1].claims).toEqual({ 7, "7" })
	end)

	it("locks story, normal, hard, and shardbreaker separately", function()
		local state = nil
		local difficulties = { "story", "normal", "hard", "shardbreaker" }
		for index, difficulty in ipairs(difficulties) do
			local result =
				take(state, " Twins ", " " .. string.upper(difficulty) .. " ", "d-" .. difficulty)
			expect(result.ok).toEqual(true)
			expect(result.reason).toEqual(REASONS.loot)
			expect(result.lootEligible).toEqual(true)
			expect(result.locked).toEqual(true)
			expect(result.bossId).toEqual("twins")
			expect(result.difficulty).toEqual(difficulty)
			expect(result.state.weeks[1].locks[index]).toEqual("twins:" .. difficulty)
			state = result.state
		end
		local reclear = take(state, "twins", "story", "d-again")
		expect(reclear.reason).toEqual(REASONS.lockout)
		expect(reclear.lootEligible).toEqual(false)
		expect(reclear.reclearRewards).toEqual(true)
		expect(#reclear.state.weeks[1].locks).toEqual(4)
		local other = take(reclear.state, "sapwell", "story", "other-boss")
		expect(other.reason).toEqual(REASONS.loot)
		expect(other.state.weeks[1].locks[5]).toEqual("sapwell:story")
	end)

	it("does not lock fracture and still makes the claim id a no-op", function()
		local first = take(nil, "awakened", "fracture", "fx-1")
		expect(first.ok).toEqual(true)
		expect(first.reason).toEqual(REASONS.fracture)
		expect(first.lootEligible).toEqual(true)
		expect(first.reclearRewards).toEqual(true)
		expect(first.locked).toEqual(false)
		expect(first.persist).toEqual(true)
		expect(first.state.weeks[1].locks).toEqual({})
		expect(first.state.weeks[1].claims).toEqual({ "fx-1" })
		local level = take(first.state, "awakened", "Fracture-3", "fx-2")
		expect(level.reason).toEqual(REASONS.fracture)
		expect(level.lootEligible).toEqual(true)
		expect(level.difficulty).toEqual("fracture-3")
		expect(level.state.weeks[1].locks).toEqual({})
		local spaced = take(level.state, "awakened", "fracture 12", "fx-3")
		expect(spaced.reason).toEqual(REASONS.fracture)
		expect(spaced.lootEligible).toEqual(true)
		local under = take(spaced.state, "awakened", "fracture_2", "fx-4")
		expect(under.reason).toEqual(REASONS.fracture)
		local replay = take(under.state, "awakened", "fracture", "fx-1")
		expect(replay.reason).toEqual(REASONS.duplicate)
		expect(replay.lootEligible).toEqual(false)
		expect(replay.reclearRewards).toEqual(false)
		expect(replay.persist).toEqual(false)
		expect(#replay.state.weeks[1].claims).toEqual(4)
		local story = take(replay.state, "awakened", "story", "after-fx")
		expect(story.reason).toEqual(REASONS.loot)
		expect(story.state.weeks[1].locks).toEqual({ "awakened:story" })
		expect(#story.state.weeks[1].claims).toEqual(5)
		expect(take(nil, "twins", "fractured", "nope").error).toEqual(ERRORS.difficulty)
		expect(take(nil, "twins", "fracture-", "nope").error).toEqual(ERRORS.difficulty)
		expect(take(nil, "twins", "practice", "nope").error).toEqual(ERRORS.difficulty)
		expect(take(nil, "twins", "guided", "nope").error).toEqual(ERRORS.difficulty)
		expect(take(nil, "twins", "mythic", "nope").error).toEqual(ERRORS.difficulty)
	end)

	it("never locks and never loots a practice clear", function()
		local practiced = RaidLockout.claim(nil, {
			claimId = "grove",
			bossId = "twins",
			difficulty = "shardbreaker",
			practice = true,
			guided = false,
		}, TUESDAY)
		expect(practiced.ok).toEqual(true)
		expect(practiced.persist).toEqual(false)
		expect(practiced.lootEligible).toEqual(false)
		expect(practiced.reclearRewards).toEqual(false)
		expect(practiced.locked).toEqual(false)
		expect(practiced.reason).toEqual(REASONS.practice)
		expect(practiced.claimId).toEqual("grove")
		expect(practiced.state.weeks).toEqual({})
		local live = take(practiced.state, "twins", "shardbreaker", "grove")
		expect(live.reason).toEqual(REASONS.loot)
		expect(live.lootEligible).toEqual(true)
		expect(live.state.weeks[1].locks).toEqual({ "twins:shardbreaker" })
		local flipped = RaidLockout.claim(live.state, {
			claimId = "grove",
			bossId = "sapwell",
			difficulty = "story",
			practice = true,
		}, TUESDAY)
		expect(flipped.reason).toEqual(REASONS.duplicate)
		expect(flipped.lootEligible).toEqual(false)
		expect(flipped.reclearRewards).toEqual(false)
		expect(flipped.state.weeks[1].locks).toEqual({ "twins:shardbreaker" })
		local badFlag = RaidLockout.claim(nil, {
			claimId = "flag",
			bossId = "twins",
			difficulty = "story",
			practice = "true",
		}, TUESDAY)
		expect(badFlag.ok).toEqual(false)
		expect(badFlag.error).toEqual(ERRORS.practice)
		expect(badFlag.lootEligible).toEqual(false)
		expect(badFlag.persist).toEqual(false)
		expect(badFlag.state.weeks).toEqual({})
		local stored = take(nil, "twins", "story", "kept")
		local junk = RaidLockout.claim(stored.state, {
			claimId = "kept",
			practice = "true",
			difficulty = "mythic",
		}, TUESDAY)
		expect(junk.reason).toEqual(REASONS.duplicate)
		expect(junk.ok).toEqual(true)
	end)

	it("does not let guided, a removal, or a saved skip waive the lock", function()
		local guided = RaidLockout.claim(nil, {
			claimId = "g1",
			bossId = "galecrown",
			difficulty = "hard",
			guided = true,
			removal = "afk",
		}, TUESDAY)
		expect(guided.reason).toEqual(REASONS.loot)
		expect(guided.lootEligible).toEqual(true)
		expect(guided.locked).toEqual(true)
		expect(guided.state.weeks[1].locks).toEqual({ "galecrown:hard" })
		expect(guided.state.weeks[1].guided).toBeNil()
		local plain = RaidLockout.claim(guided.state, {
			claimId = "g2",
			bossId = "galecrown",
			difficulty = "hard",
			guided = false,
			removal = "kick",
		}, TUESDAY)
		expect(plain.reason).toEqual(REASONS.lockout)
		expect(plain.lootEligible).toEqual(false)
		expect(plain.reclearRewards).toEqual(true)
		local badGuided = RaidLockout.claim(nil, {
			claimId = "g3",
			bossId = "galecrown",
			difficulty = "hard",
			guided = "true",
		}, TUESDAY)
		expect(badGuided.error).toEqual(ERRORS.guided)
		expect(badGuided.persist).toEqual(false)
		local sneaky = {
			skip = true,
			paid = true,
			weeks = {
				{
					weekKey = 2963,
					locks = { "twins:normal" },
					claims = { "saved" },
					skip = true,
					paid = true,
				},
			},
		}
		local reclear = take(sneaky, "twins", "normal", "next")
		expect(reclear.reason).toEqual(REASONS.lockout)
		expect(reclear.lootEligible).toEqual(false)
		expect(reclear.reclearRewards).toEqual(true)
		expect(reclear.state.skip).toBeNil()
		expect(reclear.state.paid).toBeNil()
		expect(reclear.state.weeks[1].skip).toBeNil()
		expect(reclear.state.weeks[1].locks).toEqual({ "twins:normal" })
	end)

	it("refuses a paid skip and does not lock", function()
		local fields = {
			"skip",
			"waive",
			"waiveLock",
			"waiveLockout",
			"bypass",
			"bypassLock",
			"paid",
			"robux",
			"premium",
			"price",
			"productId",
			"gamePass",
			"force",
			"unlock",
			"skipLock",
			"skipLockout",
		}
		for _, field in ipairs(fields) do
			local claim = claimOf("twins", "story", "pay")
			claim[field] = false
			local result = RaidLockout.claim(nil, claim, TUESDAY)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.skip)
			expect(result.persist).toEqual(false)
			expect(result.lootEligible).toEqual(false)
			expect(result.locked).toEqual(false)
			expect(result.state.weeks).toEqual({})
		end
		local extra = RaidLockout.claim(nil, claimOf("twins", "story", "pay"), TUESDAY, {
			paid = true,
		})
		expect(extra.error).toEqual(ERRORS.skip)
		expect(extra.persist).toEqual(false)
		expect(extra.state.weeks).toEqual({})
		local broken = { weeks = "nope" }
		expect(RaidLockout.claim(broken, claimOf("twins", "story", "pay"), TUESDAY, false).error).toEqual(
			ERRORS.skip
		)
		local stored = take(nil, "twins", "story", "pay")
		local ridden = RaidLockout.claim(stored.state, {
			claimId = "pay",
			skip = true,
		}, TUESDAY)
		expect(ridden.error).toEqual(ERRORS.skip)
		expect(ridden.reason).toBeNil()
		expect(ridden.persist).toEqual(false)
		expect(stored.state.weeks[1].claims).toEqual({ "pay" })
	end)

	it("prunes old weeks on read and starts the new Tuesday unlocked", function()
		local previous = take(nil, "twins", "story", "old-id", TUESDAY - 1)
		expect(previous.weekKey).toEqual(2962)
		expect(previous.lootEligible).toEqual(true)
		local viewed = RaidLockout.view(previous.state, TUESDAY)
		expect(viewed.ok).toEqual(true)
		expect(viewed.persist).toEqual(true)
		expect(viewed.weekKey).toEqual(2963)
		expect(viewed.error).toBeNil()
		expect(viewed.state.weeks).toEqual({})
		expect(viewed.state == previous.state).toEqual(false)
		expect(previous.state.weeks[1].weekKey).toEqual(2962)
		local rolled = take(previous.state, "twins", "story", "new-id")
		expect(rolled.lootEligible).toEqual(true)
		expect(rolled.reason).toEqual(REASONS.loot)
		expect(rolled.persist).toEqual(true)
		expect(rolled.state.weeks).toEqual({
			{
				weekKey = 2963,
				locks = { "twins:story" },
				claims = { "new-id" },
			},
		})
		local forgotten = take(previous.state, "twins", "story", "old-id")
		expect(forgotten.reason).toEqual(REASONS.loot)
		expect(forgotten.lootEligible).toEqual(true)
		local mixed = {
			weeks = {
				{
					weekKey = 2961,
					locks = { "sapwell:hard" },
					claims = { "ancient" },
				},
				{
					weekKey = 2962,
					locks = { "twins:story" },
					claims = { "last" },
				},
				{
					weekKey = 2963,
					locks = { "twins:hard" },
					claims = { "now" },
				},
			},
		}
		local before = clone(mixed)
		local status = RaidLockout.status(mixed, {
			bossId = "twins",
			difficulty = "story",
			claimId = "now",
		}, TUESDAY)
		expect(status.ok).toEqual(true)
		expect(status.persist).toEqual(true)
		expect(status.locked).toEqual(false)
		expect(status.lootEligible).toEqual(true)
		expect(status.reclearRewards).toEqual(true)
		expect(status.reason).toEqual(REASONS.loot)
		expect(status.claimId).toBeNil()
		expect(status.state.weeks).toEqual({
			{
				weekKey = 2963,
				locks = { "twins:hard" },
				claims = { "now" },
			},
		})
		expect(mixed).toEqual(before)
		local hard = RaidLockout.status(status.state, {
			bossId = " Twins ",
			difficulty = "HARD",
		}, TUESDAY)
		expect(hard.persist).toEqual(false)
		expect(hard.locked).toEqual(true)
		expect(hard.lootEligible).toEqual(false)
		expect(hard.reclearRewards).toEqual(true)
		expect(hard.reason).toEqual(REASONS.lockout)
		expect(hard.claimId).toBeNil()
		expect(hard.state).toEqual(status.state)
		expect(hard.state == status.state).toEqual(false)
		local exact = take(nil, "twins", "normal", "edge", TUESDAY)
		expect(exact.weekKey).toEqual(2963)
		local early = RaidLockout.claim(nil, claimOf("twins", "story", "dawn"), 0)
		expect(early.ok).toEqual(true)
		expect(early.weekKey).toEqual(0)
		expect(early.state.weeks[1].weekKey).toEqual(0)
	end)

	it("refuses a backwards clock and does not grant", function()
		local ahead = {
			weeks = {
				{
					weekKey = 2962,
					locks = {},
					claims = { "older" },
				},
				{
					weekKey = 2964,
					locks = { "twins:story" },
					claims = { "future" },
				},
			},
		}
		local before = clone(ahead)
		freezeDeep(ahead)
		local claimed = take(ahead, "twins", "story", "late")
		local viewed = RaidLockout.view(ahead, TUESDAY)
		local looked = RaidLockout.status(ahead, {
			bossId = "twins",
			difficulty = "normal",
		}, TUESDAY)
		expect(claimed.ok).toEqual(false)
		expect(claimed.error).toEqual(ERRORS.clock)
		expect(claimed.persist).toEqual(false)
		expect(claimed.lootEligible).toEqual(false)
		expect(claimed.reclearRewards).toEqual(false)
		expect(claimed.weekKey).toEqual(2963)
		expect(claimed.state).toEqual(before)
		expect(claimed.state == ahead).toEqual(false)
		expect(viewed.error).toEqual(ERRORS.clock)
		expect(viewed.persist).toEqual(false)
		expect(viewed.state).toEqual(before)
		expect(looked.error).toEqual(ERRORS.clock)
		expect(looked.lootEligible).toEqual(false)
		expect(ahead).toEqual(before)
	end)

	it("refuses a new claim when the week is full", function()
		local state = nil
		for index = 1, RaidLockout.CONFIG.maxClaims do
			local result = take(state, "twins", "story", index)
			expect(result.ok).toEqual(true)
			expect(result.persist).toEqual(true)
			if index == 1 then
				expect(result.reason).toEqual(REASONS.loot)
			else
				expect(result.reason).toEqual(REASONS.lockout)
				expect(result.reclearRewards).toEqual(true)
			end
			state = result.state
		end
		expect(#state.weeks[1].claims).toEqual(256)
		local overflow = take(state, "sapwell", "hard", 257)
		expect(overflow.ok).toEqual(false)
		expect(overflow.error).toEqual(ERRORS.full)
		expect(overflow.persist).toEqual(false)
		expect(overflow.lootEligible).toEqual(false)
		expect(overflow.reclearRewards).toEqual(false)
		expect(overflow.locked).toEqual(false)
		expect(#overflow.state.weeks[1].claims).toEqual(256)
		expect(overflow.state.weeks[1].locks).toEqual({ "twins:story" })
		local replay = take(state, "twins", "story", 1)
		expect(replay.reason).toEqual(REASONS.duplicate)
		expect(replay.ok).toEqual(true)
		expect(#replay.state.weeks[1].claims).toEqual(256)
		local later = take(state, "twins", "story", "next-week", TUESDAY + WEEK)
		expect(later.ok).toEqual(true)
		expect(later.reason).toEqual(REASONS.loot)
		expect(later.lootEligible).toEqual(true)
		expect(later.weekKey).toEqual(2964)
		expect(later.state.weeks).toEqual({
			{
				weekKey = 2964,
				locks = { "twins:story" },
				claims = { "next-week" },
			},
		})
	end)

	it("rejects a bad id, a bad boss, and a bad record without throwing", function()
		local longId = string.rep("a", 65)
		local longBoss = string.rep("b", 65)
		local badIds = { "", "   ", longId, 0, -3, 1.5, 0 / 0, math.huge, true, {}, function() end }
		for _, id in ipairs(badIds) do
			local result = RaidLockout.claim(nil, {
				claimId = id,
				bossId = "twins",
				difficulty = "story",
			}, TUESDAY)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.claimId)
			expect(result.lootEligible).toEqual(false)
			expect(result.persist).toEqual(false)
		end
		local missingId = RaidLockout.claim(nil, {
			bossId = "twins",
			difficulty = "story",
		}, TUESDAY)
		expect(missingId.error).toEqual(ERRORS.claimId)
		expect(missingId.persist).toEqual(false)
		expect(take(nil, "twins:story", "story", "colon").error).toEqual(ERRORS.boss)
		expect(take(nil, "   ", "story", "blank").error).toEqual(ERRORS.boss)
		expect(take(nil, longBoss, "story", "long").error).toEqual(ERRORS.boss)
		expect(RaidLockout.claim(nil, {
			claimId = "boss",
			bossId = 4,
			difficulty = "story",
		}, TUESDAY).error).toEqual(ERRORS.boss)
		local badNow = { "now", 0 / 0, math.huge, -5, {}, true }
		for _, now in ipairs(badNow) do
			local result = RaidLockout.claim(nil, claimOf("twins", "story", "time"), now)
			expect(result.error).toEqual(ERRORS.time)
			expect(result.persist).toEqual(false)
			expect(result.lootEligible).toEqual(false)
			expect(result.weekKey).toEqual(-1)
		end
		local missingNow = RaidLockout.claim(nil, claimOf("twins", "story", "time"))
		expect(missingNow.error).toEqual(ERRORS.time)
		expect(missingNow.weekKey).toEqual(-1)
		local badClaims = { "nope", 4, true, function() end, { "twins" } }
		for _, shape in ipairs(badClaims) do
			local result = RaidLockout.claim(nil, shape, TUESDAY)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.claim)
			expect(result.persist).toEqual(false)
			expect(result.lootEligible).toEqual(false)
		end
		expect(RaidLockout.claim("nope", claimOf("twins", "story", "shape"), TUESDAY).error).toEqual(
			ERRORS.state
		)
		expect(
			RaidLockout.claim({ { weekKey = 2963 } }, claimOf("twins", "story", "shape"), TUESDAY).error
		).toEqual(ERRORS.state)
		expect(RaidLockout.status(nil, "twins", TUESDAY).error).toEqual(ERRORS.query)
		expect(RaidLockout.view(nil, TUESDAY, { paid = true }).error).toEqual(ERRORS.skip)
		local corrupt = {
			{
				weeks = {
					[1] = { weekKey = 2963, locks = {}, claims = {} },
					[3] = { weekKey = 1, locks = {}, claims = {} },
				},
			},
			{ weeks = { { weekKey = 2963, locks = { "Twins:story" }, claims = {} } } },
			{ weeks = { { weekKey = 2963, locks = { "twins:fracture" }, claims = {} } } },
			{ weeks = { { weekKey = 2963, locks = { "twins:story" }, claims = { " same" } } } },
			{
				weeks = {
					{ weekKey = 2963, locks = { "twins:story", "twins:story" }, claims = { "a" } },
				},
			},
			{
				weeks = {
					{ weekKey = 2963, locks = {}, claims = {} },
					{ weekKey = 2963, locks = {}, claims = { "x" } },
				},
			},
			{
				weeks = {
					{ weekKey = 2963, locks = {}, claims = { "dup" } },
					{ weekKey = 2962, locks = {}, claims = { "dup" } },
				},
			},
			{ weeks = { { weekKey = 1.5, locks = {}, claims = {} } } },
			{ weeks = { { weekKey = -1, locks = {}, claims = {} } } },
			{ weeks = { { weekKey = 0 / 0, locks = {}, claims = {} } } },
			{ weeks = { { weekKey = 2963, locks = {}, claims = { true } } } },
			{ weeks = "nope" },
		}
		for _, state in ipairs(corrupt) do
			local result = take(state, "twins", "story", "fresh")
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.state)
			expect(result.persist).toEqual(false)
			expect(result.lootEligible).toEqual(false)
			expect(result.reclearRewards).toEqual(false)
			expect(result.state.weeks).toEqual({})
			expect(RaidLockout.view(state, TUESDAY).error).toEqual(ERRORS.state)
			expect(RaidLockout.view(state, TUESDAY).persist).toEqual(false)
		end
	end)

	it("returns new tables and does not write a frozen input", function()
		local state = take(nil, "twins", "story", "frozen").state
		local claim = claimOf("sapwell", "normal", "next", { guided = true, practice = false })
		local beforeState = clone(state)
		local beforeClaim = clone(claim)
		freezeDeep(state)
		freezeDeep(claim)
		local result = RaidLockout.claim(state, claim, TUESDAY)
		expect(result.ok).toEqual(true)
		expect(result.reason).toEqual(REASONS.loot)
		expect(result.state == state).toEqual(false)
		expect(result.state.weeks == state.weeks).toEqual(false)
		expect(result.state.weeks[1].locks == state.weeks[1].locks).toEqual(false)
		expect(state).toEqual(beforeState)
		expect(claim).toEqual(beforeClaim)
		result.state.weeks[1].locks[1] = "mutated"
		local viewed = RaidLockout.view(state, TUESDAY)
		expect(viewed.state).toEqual(beforeState)
		expect(viewed.persist).toEqual(false)
		local emptyA = RaidLockout.fresh()
		local emptyB = RaidLockout.fresh()
		expect(emptyA).toEqual({ weeks = {} })
		expect(emptyA == emptyB).toEqual(false)
		local opened = RaidLockout.view(nil, TUESDAY)
		expect(opened.ok).toEqual(true)
		expect(opened.persist).toEqual(false)
		expect(opened.weekKey).toEqual(2963)
		expect(opened.state.weeks).toEqual({})
		local looked = RaidLockout.status(nil, {
			bossId = "twins",
			difficulty = "story",
		}, TUESDAY)
		expect(looked.ok).toEqual(true)
		expect(looked.persist).toEqual(false)
		expect(looked.locked).toEqual(false)
		expect(looked.lootEligible).toEqual(true)
		expect(looked.reclearRewards).toEqual(true)
		expect(looked.reason).toEqual(REASONS.loot)
		expect(looked.claimId).toBeNil()
		expect(looked.state.weeks).toEqual({})
		local practice = RaidLockout.status(state, {
			bossId = "twins",
			difficulty = "shardbreaker",
			practice = true,
		}, TUESDAY)
		expect(practice.reason).toEqual(REASONS.practice)
		expect(practice.lootEligible).toEqual(false)
		expect(practice.reclearRewards).toEqual(false)
		expect(practice.persist).toEqual(false)
		expect(practice.state).toEqual(beforeState)
	end)
end)
