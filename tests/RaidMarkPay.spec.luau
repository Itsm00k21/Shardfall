--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local Loops = require("../src/ReplicatedStorage/Shared/Loops")
local PracticeLoot = require("../src/ReplicatedStorage/Shared/PracticeLoot")
local RaidMarks = require("../src/ReplicatedStorage/Shared/RaidMarks")
local Raids = require("../src/ReplicatedStorage/Shared/Raids")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local WEEK = 7 * 86400
local FIRST = 5 * 86400
-- 2026-10-13 00:00:00 UTC, a Tuesday.
local TUESDAY = 1791849600

local function profile()
	return {
		chests = { Rare = 0, Epic = 0 },
		raidMarks = 0,
		raidMarksEarned = 0,
		raidMarkWeek = -1,
	}
end

local function pay(data, claim: string, difficulty: string, now: number, extra: any?)
	local request = {
		difficulty = difficulty,
		now = now,
		claim = claim,
	}
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			request[key] = value
		end
	end
	return Raids.payMarks(data, request)
end

local function reload(data)
	local claims = {}
	if type(data.raidMarkClaims) == "table" then
		for index, value in ipairs(data.raidMarkClaims) do
			claims[index] = value
		end
	end
	return {
		raidMarks = data.raidMarks,
		raidMarksEarned = data.raidMarksEarned,
		raidMarkWeek = data.raidMarkWeek,
		raidMarksBank = data.raidMarksBank,
		raidMarkClaims = claims,
		chests = { Rare = 0, Epic = 0 },
	}
end

local function count(source: string, needle: string): number
	local found = 0
	local from = 1
	while true do
		local at = string.find(source, needle, from, true)
		if at == nil then
			break
		end
		found += 1
		from = at + #needle
	end
	return found
end

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

describe("Raid Marks payout", function()
	it("pays one clear once", function()
		local data = profile()
		expect(pay(data, "run-a:twins", "story", FIRST)).toEqual(25)
		expect(data.raidMarks).toEqual(25)
		expect(data.raidMarksEarned).toEqual(25)
		expect(data.raidMarksBank).toEqual(0)
		expect(data.raidMarkWeek).toEqual(RaidMarks.weekKey(FIRST))
	end)

	it("a second grant of that claim pays nothing", function()
		local data = profile()
		expect(pay(data, "run-a:twins", "story", FIRST)).toEqual(25)
		expect(pay(data, "run-a:twins", "story", FIRST + 10)).toEqual(0)
		expect(data.raidMarks).toEqual(25)
		expect(data.raidMarksEarned).toEqual(25)
	end)

	it("a retry cannot raise the grant", function()
		local data = profile()
		expect(pay(data, "run-a:twins", "story", FIRST)).toEqual(25)
		local retry = pay(data, "run-a:twins", "shardbreaker", FIRST, {
			amount = 99999,
			event = true,
			firstTimers = 8,
		})
		expect(retry).toEqual(0)
		expect(data.raidMarks).toEqual(25)
		expect(RaidMarks.CONFIG.doubleMarks).toEqual(false)
	end)

	it("re-entry of the saved claim pays nothing", function()
		local data = profile()
		expect(pay(data, "run-a:twins", "story", FIRST)).toEqual(25)
		local loaded = reload(data)
		expect(pay(loaded, "run-a:twins", "normal", FIRST)).toEqual(0)
		expect(loaded.raidMarks).toEqual(25)
		expect(pay(loaded, "run-b:twins", "story", FIRST)).toEqual(25)
		expect(loaded.raidMarks).toEqual(50)
	end)

	it("uses the payout table instead of a flat 25", function()
		local data = profile()
		expect(pay(data, "run-h:twins", "hard", FIRST)).toEqual(60)
		expect(pay(data, "run-n:twins", " Normal ", FIRST)).toEqual(40)
		expect(pay(data, "run-s:twins", "shardbreaker", FIRST)).toEqual(80)
		expect(data.raidMarks).toEqual(180)
		local capped = profile()
		expect(pay(capped, "run-f:twins", "story", FIRST, { firstTimers = 100 })).toEqual(45)
		expect(pay(capped, "run-g:twins", "story", FIRST, { firstTimers = 1 })).toEqual(28)
	end)

	it("stops at the weekly room", function()
		local data = profile()
		for index = 1, 15 do
			local claim = string.format("cap-%d:twins", index)
			expect(pay(data, claim, "normal", FIRST)).toEqual(40)
		end
		expect(data.raidMarks).toEqual(600)
		expect(data.raidMarksEarned).toEqual(600)
		expect(pay(data, "cap-16:twins", "normal", FIRST)).toEqual(0)
		expect(data.raidMarks).toEqual(600)
		expect(pay(data, "cap-16:twins", "shardbreaker", FIRST, { amount = 80 })).toEqual(0)
		expect(data.raidMarks).toEqual(600)
	end)

	it("pays only the marks still in the room", function()
		local data = profile()
		for index = 1, 14 do
			local claim = string.format("room-%d:twins", index)
			expect(pay(data, claim, "normal", FIRST)).toEqual(40)
		end
		expect(pay(data, "room-story:twins", "story", FIRST)).toEqual(25)
		expect(data.raidMarks).toEqual(585)
		expect(pay(data, "room-rest:twins", "story", FIRST)).toEqual(15)
		expect(data.raidMarks).toEqual(600)
		expect(pay(data, "room-past:twins", "story", FIRST)).toEqual(0)
		expect(data.raidMarks).toEqual(600)
	end)

	it("banks unused room up to 1800 and pays past 600", function()
		local data = profile()
		expect(pay(data, "stamp:twins", "story", FIRST, { removal = "afk" })).toEqual(0)
		expect(data.raidMarks).toEqual(0)
		expect(data.raidMarksBank).toEqual(0)
		local later = FIRST + 4 * WEEK
		expect(pay(data, "jump:twins", "story", later, { removal = "afk" })).toEqual(0)
		expect(data.raidMarksBank).toEqual(1800)
		expect(data.raidMarksEarned).toEqual(0)
		for index = 1, 15 do
			local claim = string.format("bank-%d:twins", index)
			expect(pay(data, claim, "normal", later)).toEqual(40)
		end
		expect(data.raidMarksEarned).toEqual(600)
		expect(data.raidMarksBank).toEqual(1800)
		expect(pay(data, "bank-past:twins", "normal", later)).toEqual(40)
		expect(data.raidMarks).toEqual(640)
		expect(data.raidMarksBank).toEqual(1800)
		local far = FIRST + 14 * WEEK
		expect(pay(data, "far:twins", "story", far, { removal = "afk" })).toEqual(0)
		expect(data.raidMarksBank).toEqual(1800)
		expect(data.raidMarks).toEqual(640)
	end)

	it("practice and a Robux field pay nothing and do not consume the claim", function()
		local grove = profile()
		grove.raidMarks = 7
		expect(pay(grove, "run-p:twins", "normal", FIRST, { practice = true })).toEqual(0)
		expect(grove.raidMarks).toEqual(7)
		expect(grove.raidMarkClaims).toBeNil()
		expect(pay(grove, "run-p:twins", "normal", FIRST)).toEqual(40)
		expect(grove.raidMarks).toEqual(47)

		local bought = profile()
		expect(pay(bought, "run-r:twins", "story", FIRST, {
			productId = 9,
			robux = 100,
			cost = 1,
			skip = true,
		})).toEqual(0)
		expect(bought.raidMarks).toEqual(0)
		expect(bought.raidMarkClaims).toBeNil()
		expect(pay(bought, "run-r:twins", "story", FIRST)).toEqual(25)
	end)

	it("an AFK removal pays nothing and a retry stays unpaid", function()
		local data = profile()
		expect(pay(data, "run-k:twins", "normal", FIRST, { removal = "afk" })).toEqual(0)
		expect(data.raidMarks).toEqual(0)
		expect(pay(data, "run-k:twins", "normal", FIRST)).toEqual(0)
		expect(data.raidMarks).toEqual(0)
		local kicked = profile()
		expect(pay(kicked, "run-v:twins", "story", FIRST, { removal = "kick" })).toEqual(25)
		expect(kicked.raidMarks).toEqual(25)
	end)

	it("a bad clear pays nothing and does not wipe a wallet", function()
		local data = profile()
		data.raidMarks = 12
		data.raidMarksBank = 0
		data.raidMarkWeek = RaidMarks.weekKey(FIRST)
		expect(pay(data, "run-t:twins", "story", -1)).toEqual(0)
		expect(data.raidMarks).toEqual(12)
		expect(data.raidMarkClaims).toBeNil()
		expect(pay(data, "run-t:twins", "story", FIRST)).toEqual(25)
		expect(data.raidMarks).toEqual(37)

		local broken = profile()
		expect(pay(broken, "run-m:twins", "mythic", FIRST)).toEqual(0)
		expect(broken.raidMarks).toEqual(0)
		expect(pay(broken, "run-m:twins", "story", FIRST)).toEqual(0)
		expect(pay(broken, "nope", "story", FIRST)).toEqual(0)
		expect(pay(broken, "run-ok:twins", "story", FIRST, { firstTimers = 1.5 })).toEqual(0)
		expect(pay(broken, "run-ok:twins", "story", FIRST)).toEqual(0)
		expect(broken.raidMarks).toEqual(0)
	end)

	it("a saved claim still pays nothing after the profile is migrated", function()
		local data = profile()
		expect(pay(data, "run-a:twins", "story", FIRST)).toEqual(25)
		data.schemaVersion = Schema.VERSION
		local loaded = Schema.migrate(data)
		expect(loaded.raidMarks).toEqual(25)
		expect(loaded.raidMarksBank).toEqual(0)
		expect(loaded.raidMarkClaims[1]).toEqual("run-a:twins")
		expect(pay(loaded, "run-a:twins", "normal", FIRST, { amount = 40 })).toEqual(0)
		expect(loaded.raidMarks).toEqual(25)
	end)

	it("clamps a stored bank to 1800", function()
		local data = profile()
		data.raidMarksBank = 999999
		data.raidMarkWeek = RaidMarks.weekKey(FIRST)
		data.raidMarksEarned = 0
		expect(pay(data, "run-bloat:twins", "story", FIRST)).toEqual(25)
		expect(data.raidMarksBank).toEqual(1800)
		data.raidMarksEarned = 2400
		expect(pay(data, "run-bloat-2:twins", "shardbreaker", FIRST)).toEqual(0)
		expect(data.raidMarks).toEqual(25)
	end)

	it("keeps the claim list bounded", function()
		local data = profile()
		for index = 1, 70 do
			local claim = string.format("old-%d:twins", index)
			expect(pay(data, claim, "mythic", FIRST)).toEqual(0)
		end
		expect(#data.raidMarkClaims).toEqual(64)
		expect(pay(data, "old-70:twins", "story", FIRST)).toEqual(0)
		expect(#data.raidMarkClaims).toEqual(64)
	end)

	it("leaves the loot lock on the Thursday week", function()
		local data = profile()
		local paid, dropped, locked =
			Raids.applyClear(data, "twins", "story", TUESDAY, 0.99, "run-w:twins")
		expect(paid).toEqual(25)
		expect(dropped).toEqual(false)
		expect(locked).toEqual(false)
		expect(data.raidLock["twins:story"]).toEqual(Raids.weekNumber(TUESDAY))
		expect(data.raidMarkWeek).toEqual(RaidMarks.weekKey(TUESDAY))
		expect(Raids.weekNumber(TUESDAY) ~= RaidMarks.weekKey(TUESDAY)).toBeTrue()
		local again, _, lockedAgain =
			Raids.applyClear(data, "twins", "story", TUESDAY + 10, 0, "run-w:twins")
		expect(again).toEqual(0)
		expect(lockedAgain).toEqual(true)
		expect(data.raidPity["twins:story"]).toEqual(1)
		expect(data.raidMarks).toEqual(25)
		local reclear = Raids.applyClear(data, "twins", "story", TUESDAY + 10, 0, "run-x:twins")
		expect(reclear).toEqual(25)
		expect(data.raidMarks).toEqual(50)
		expect(data.raidPity["twins:story"]).toEqual(1)
	end)

	it("a Heartwood kill pays through that claim and practice does not", function()
		local function kill(practice: boolean, claim: string)
			return {
				practice = practice,
				enemyKind = "grandmother_gnarl",
				boss = true,
				dungeonId = "heartwood",
				difficulty = "story",
				roomId = "awakened",
				floorChest = "Rare",
				now = FIRST,
				rng = {
					nextNumber = function()
						return 0
					end,
					nextInteger = function(_self, min: number, _max: number)
						return min
					end,
				},
				roll = 1,
				claim = claim,
			}
		end
		local live = Schema.template()
		PracticeLoot.applyKill(live, kill(false, "guid-1:awakened"))
		PracticeLoot.applyKill(live, kill(false, "guid-1:awakened"))
		expect(live.raidMarks).toEqual(25)
		PracticeLoot.applyKill(live, kill(false, "guid-2:awakened"))
		expect(live.raidMarks).toEqual(50)

		local grove = Schema.template()
		grove.raidMarks = 7
		local landed, chests = PracticeLoot.applyKill(grove, kill(true, "guid-1:awakened"))
		expect(landed).toEqual({})
		expect(chests).toEqual({})
		expect(grove.raidMarks).toEqual(7)
		expect(grove.raidMarkClaims).toBeNil()
	end)

	it("is the only mark grant and the kill path mints the claim", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/Raids.luau")
		expect(count(source, "RaidMarks.payout(")).toEqual(1)
		expect(count(source, "RaidMarks.earn(")).toEqual(1)
		expect(count(source, "data.raidMarks =")).toEqual(1)
		expect(string.find(source, "MARK_CAP -", 1, true)).toBeNil()
		local clear = between(source, "function Raids.applyClear", "function Raids.buy")
		expect(string.find(clear, "Raids.payMarks", 1, true)).toBeGreaterThan(0)
		expect(string.find(clear, "raidMarks =", 1, true)).toBeNil()

		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local hits = between(
			dungeon,
			"function DungeonService.damageEnemy",
			"function DungeonService.enemyViews"
		)
		expect(string.find(hits, 'claim = run.runId .. ":" .. bossId', 1, true)).toBeGreaterThan(0)
		expect(string.find(hits, "options.claim", 1, true)).toBeNil()
		local enter =
			between(dungeon, "function DungeonService.enter", "function DungeonService.tuneRaid")
		expect(string.find(enter, "runId = runId", 1, true)).toBeGreaterThan(0)
	end)

	it("leaves the paid switches and the schema version alone", function()
		expect(Schema.VERSION).toEqual(25)
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		expect(Loops.PASS_PRODUCT_ID).toEqual(0)
		expect(Loops.ARCHIVE_PRODUCT_ID).toEqual(0)
		expect(RarityConfig.PAID_LUCK_ENABLED).toEqual(false)
		expect(ChestConfig.PAID_CHESTS_ENABLED).toEqual(false)
		expect(RaidMarks.CONFIG.weeklyCap * RaidMarks.CONFIG.bankWeeks).toEqual(1800)
		expect(RaidMarks.CONFIG.doubleMarks).toEqual(false)
	end)
end)
