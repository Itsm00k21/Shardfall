--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidConduct = require("../src/ReplicatedStorage/Shared/RaidConduct")

local ERRORS = RaidConduct.ERRORS

local NEEDED = {
	[0] = 0,
	[1] = 1,
	[2] = 2,
	[3] = 3,
	[4] = 3,
	[5] = 4,
	[6] = 5,
	[7] = 6,
	[8] = 6,
}

local function members(count: number, joinedAt: number?)
	local list = {}
	for id = 1, count do
		local row = { userId = id }
		if joinedAt ~= nil then
			row.joinedAt = joinedAt
		end
		table.insert(list, row)
	end
	return list
end

local function bareMembers(count: number)
	local list = {}
	for id = 1, count do
		table.insert(list, id)
	end
	return list
end

local function yesFrom(firstId: number, lastId: number)
	local votes = {}
	for id = firstId, lastId do
		votes[id] = true
	end
	return votes
end

local function voteRequest(patch: { [string]: any }?)
	local request = {
		now = 120,
		raidStartedAt = 0,
		inCombat = false,
		guided = false,
		initiatorUserId = 1,
		targetUserId = 4,
		reason = "standing still",
		members = members(4, 0),
		votes = yesFrom(1, 3),
		kickDay = 0,
		kickCount = 0,
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			request[key] = value
		end
	end
	return request
end

describe("RaidConduct config", function()
	it("pins the design thresholds", function()
		expect(RaidConduct.CONFIG.warnSeconds).toEqual(60)
		expect(RaidConduct.CONFIG.removeSeconds).toEqual(90)
		expect(RaidConduct.CONFIG.voteLockSeconds).toEqual(120)
		expect(RaidConduct.CONFIG.voteNumerator).toEqual(3)
		expect(RaidConduct.CONFIG.voteDenominator).toEqual(4)
		expect(RaidConduct.CONFIG.kicksPerDay).toEqual(1)
		expect(RaidConduct.CONFIG.daySeconds).toEqual(86400)
		expect(RaidConduct.CONFIG.warnSeconds < RaidConduct.CONFIG.removeSeconds).toEqual(true)
	end)

	it("freezes the thresholds and the idle codes", function()
		expect(function()
			RaidConduct.CONFIG.warnSeconds = 1
		end).toThrow()
		expect(function()
			RaidConduct.IDLE_REASONS.idle = false
		end).toThrow()
		expect(function()
			RaidConduct.ERRORS.guided = "open"
		end).toThrow()
	end)

	it("has no Robux price and no combat power", function()
		local banned =
			{ robux = true, productid = true, damage = true, health = true, attack = true }
		for key in pairs(RaidConduct.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
			expect(type(RaidConduct.CONFIG[key])).toEqual("number")
		end
	end)

	it("counts UTC days from the unix time it is given", function()
		expect(RaidConduct.dayNumber(0)).toEqual(0)
		expect(RaidConduct.dayNumber(86399)).toEqual(0)
		expect(RaidConduct.dayNumber(86400)).toEqual(1)
		expect(RaidConduct.dayNumber(-1)).toBeNil()
		expect(RaidConduct.dayNumber(0 / 0)).toBeNil()
		expect(RaidConduct.dayNumber(math.huge)).toBeNil()
	end)

	it("rounds the vote up so it is never under 3/4", function()
		for size, needed in pairs(NEEDED) do
			expect(RaidConduct.votesNeeded(size)).toEqual(needed)
		end
		expect(RaidConduct.votesNeeded(-4)).toEqual(0)
		expect(RaidConduct.votesNeeded(0 / 0)).toEqual(0)
	end)
end)

describe("RaidConduct AFK", function()
	it("stays quiet before 60 seconds", function()
		expect(RaidConduct.afk({ now = 59.999, lastInputAt = 0, inCutscene = false })).toEqual({
			ok = true,
			state = "ok",
			idleSeconds = 59.999,
			forfeitRewards = false,
			queueBackfill = false,
			keepMarks = true,
		})
	end)

	it("warns at 60 seconds and is still only a warning at 89", function()
		local warning = RaidConduct.afk({ now = 60, lastInputAt = 0, inCutscene = false })
		expect(warning.state).toEqual("warning")
		expect(warning.idleSeconds).toEqual(60)
		expect(warning.forfeitRewards).toEqual(false)
		expect(warning.queueBackfill).toEqual(false)
		expect(warning.keepMarks).toEqual(true)
		expect(RaidConduct.afk({ now = 89.999, lastInputAt = 0, inCutscene = false }).state).toEqual(
			"warning"
		)
	end)

	it("removes at 90 seconds, forfeits rewards, and flags a backfill", function()
		expect(RaidConduct.afk({ now = 90, lastInputAt = 0, inCutscene = false })).toEqual({
			ok = true,
			state = "remove",
			idleSeconds = 90,
			forfeitRewards = true,
			queueBackfill = true,
			keepMarks = false,
		})
		local later = RaidConduct.afk({ now = 200, lastInputAt = 10, inCutscene = false })
		expect(later.state).toEqual("remove")
		expect(later.forfeitRewards).toEqual(true)
		expect(later.queueBackfill).toEqual(true)
		expect(later.keepMarks).toEqual(false)
	end)

	it("pauses outside the idle clock during a cutscene", function()
		expect(RaidConduct.afk({ now = 500, lastInputAt = 0, inCutscene = true })).toEqual({
			ok = true,
			state = "paused",
			idleSeconds = 500,
			forfeitRewards = false,
			queueBackfill = false,
			keepMarks = true,
		})
	end)

	it("does not treat a future input stamp as idle", function()
		expect(RaidConduct.afk({ now = 10, lastInputAt = 40, inCutscene = false })).toEqual({
			ok = true,
			state = "ok",
			idleSeconds = 0,
			forfeitRewards = false,
			queueBackfill = false,
			keepMarks = true,
		})
	end)

	it("refuses a check with no usable time instead of removing anyone", function()
		local missing = RaidConduct.afk(nil)
		expect(missing.ok).toEqual(false)
		expect(missing.state).toEqual("invalid")
		expect(missing.forfeitRewards).toEqual(false)
		expect(missing.queueBackfill).toEqual(false)
		expect(missing.keepMarks).toEqual(true)
		expect(missing.error).toEqual(ERRORS.afkTime)
		expect(RaidConduct.afk({ now = 0 / 0, lastInputAt = 0 }).state).toEqual("invalid")
		expect(RaidConduct.afk({ now = math.huge, lastInputAt = 0 }).state).toEqual("invalid")
		expect(RaidConduct.afk({ now = 90, lastInputAt = 0 / 0 }).forfeitRewards).toEqual(false)
	end)

	it("only an explicit cutscene flag pauses the clock", function()
		local vague = RaidConduct.afk({
			now = 90,
			lastInputAt = 0,
			inCutscene = "yes" :: any,
		})
		expect(vague.state).toEqual("remove")
	end)
end)

describe("RaidConduct vote-kick", function()
	it("spends the daily kick when a vote opens and does not resolve it", function()
		expect(RaidConduct.openVote(voteRequest(nil))).toEqual({
			ok = true,
			passed = false,
			spentKick = true,
			needed = 3,
			yesCount = 0,
			eligible = 3,
			groupSize = 4,
			keepMarks = true,
			dropQueuePriority = false,
			forfeitRewards = false,
			queueBackfill = false,
			kickDay = 0,
			kickCount = 1,
		})
	end)

	it("allows one opened vote per player per UTC day", function()
		local again = RaidConduct.openVote(voteRequest({ kickDay = 0, kickCount = 1 }))
		expect(again.ok).toEqual(false)
		expect(again.spentKick).toEqual(false)
		expect(again.kickCount).toEqual(1)
		expect(again.error).toEqual(ERRORS.daily)

		local nextDay = RaidConduct.openVote(voteRequest({
			now = 86400 + 120,
			kickDay = 0,
			kickCount = 1,
		}))
		expect(nextDay.ok).toEqual(true)
		expect(nextDay.spentKick).toEqual(true)
		expect(nextDay.kickDay).toEqual(1)
		expect(nextDay.kickCount).toEqual(1)
	end)

	it("does not spend a kick when the vote is refused", function()
		local guided = RaidConduct.openVote(voteRequest({ guided = true }))
		expect(guided.ok).toEqual(false)
		expect(guided.spentKick).toEqual(false)
		expect(guided.kickCount).toEqual(0)
		expect(guided.error).toEqual(ERRORS.guided)
		expect(guided.forfeitRewards).toEqual(false)
		expect(guided.queueBackfill).toEqual(false)

		local combat = RaidConduct.openVote(voteRequest({ inCombat = true }))
		expect(combat.error).toEqual(ERRORS.combat)
		expect(combat.spentKick).toEqual(false)

		local early = RaidConduct.openVote(voteRequest({ now = 119.999 }))
		expect(early.error).toEqual(ERRORS.early)
		expect(early.spentKick).toEqual(false)

		local opened = RaidConduct.openVote(voteRequest({ now = 120 }))
		expect(opened.ok).toEqual(true)
	end)

	it("protects a player for 2 minutes after they join", function()
		local fresh = RaidConduct.openVote(voteRequest({
			now = 500,
			members = members(4, 400),
		}))
		expect(fresh.ok).toEqual(false)
		expect(fresh.spentKick).toEqual(false)
		expect(fresh.error).toEqual(ERRORS.joined)

		local ready = RaidConduct.openVote(voteRequest({
			now = 520,
			members = members(4, 400),
		}))
		expect(ready.ok).toEqual(true)
	end)

	it("uses only the raid clock when a member has no join time", function()
		local lateJoin = RaidConduct.openVote(voteRequest({
			now = 500,
			members = bareMembers(4),
		}))
		expect(lateJoin.ok).toEqual(true)
		expect(lateJoin.spentKick).toEqual(true)
	end)

	it("requires a reason and caps its length", function()
		expect(RaidConduct.openVote(voteRequest({ reason = "   " })).error).toEqual(ERRORS.reason)
		expect(RaidConduct.openVote(voteRequest({ reason = 12 })).error).toEqual(ERRORS.reason)
		expect(RaidConduct.openVote(voteRequest({ reason = string.rep("a", 81) })).error).toEqual(
			ERRORS.reasonLong
		)
		local accepted = RaidConduct.openVote(voteRequest({ reason = string.rep("b", 80) }))
		expect(accepted.ok).toEqual(true)
		expect(accepted.spentKick).toEqual(true)
		expect(RaidConduct.openVote(voteRequest({ reason = "   " })).spentKick).toEqual(false)
	end)

	it("rejects a self kick and anyone outside the raid", function()
		expect(RaidConduct.openVote(voteRequest({ targetUserId = 1 })).error).toEqual(
			ERRORS.selfKick
		)
		expect(RaidConduct.openVote(voteRequest({ initiatorUserId = 9 })).error).toEqual(
			ERRORS.initiator
		)
		expect(RaidConduct.openVote(voteRequest({ targetUserId = 9 })).error).toEqual(ERRORS.target)
		expect(RaidConduct.openVote(voteRequest({ initiatorUserId = 0 })).spentKick).toEqual(false)
		expect(RaidConduct.openVote(voteRequest({ targetUserId = 1.5 })).error).toEqual(
			ERRORS.target
		)
	end)

	it("refuses to open a vote a small group can never pass", function()
		local trio = RaidConduct.openVote(voteRequest({
			members = members(3, 0),
			targetUserId = 3,
		}))
		expect(trio.ok).toEqual(false)
		expect(trio.spentKick).toEqual(false)
		expect(trio.needed).toEqual(3)
		expect(trio.eligible).toEqual(2)
		expect(trio.error).toEqual(ERRORS.short)
		expect(trio.kickCount).toEqual(0)
	end)

	it("counts each player once", function()
		local duplicated = RaidConduct.openVote(voteRequest({
			members = { 1, 1, 2, 2, 3, 4, { userId = 4, joinedAt = 0 } },
		}))
		expect(duplicated.ok).toEqual(true)
		expect(duplicated.groupSize).toEqual(4)
		expect(duplicated.needed).toEqual(3)
	end)

	it("does not write the roster it was given", function()
		local roster = table.freeze({
			table.freeze({ userId = 1, joinedAt = 0 }),
			table.freeze({ userId = 2, joinedAt = 0 }),
			table.freeze({ userId = 3, joinedAt = 0 }),
			table.freeze({ userId = 4, joinedAt = 0 }),
		})
		local opened = RaidConduct.openVote(voteRequest({ members = roster }))
		expect(opened.ok).toEqual(true)
		expect(opened.groupSize).toEqual(4)
		expect(roster[1].userId).toEqual(1)
		expect(roster[1].joinedAt).toEqual(0)
		expect(roster[4].userId).toEqual(4)
	end)

	it("fails closed on a corrupt daily counter", function()
		local corrupt = RaidConduct.openVote(voteRequest({ kickCount = 0 / 0 }))
		expect(corrupt.ok).toEqual(false)
		expect(corrupt.spentKick).toEqual(false)
		expect(corrupt.error).toEqual(ERRORS.daily)
	end)

	it("passes a group of 4 only when the other 3 vote yes", function()
		local short = RaidConduct.tally(voteRequest({ votes = yesFrom(1, 2) }))
		expect(short.ok).toEqual(true)
		expect(short.passed).toEqual(false)
		expect(short.yesCount).toEqual(2)
		expect(short.needed).toEqual(3)
		expect(short.spentKick).toEqual(false)
		expect(short.kickCount).toEqual(0)
		expect(short.dropQueuePriority).toEqual(false)
		expect(short.keepMarks).toEqual(true)
		expect(short.forfeitRewards).toEqual(false)
		expect(short.queueBackfill).toEqual(false)

		local passed = RaidConduct.tally(voteRequest(nil))
		expect(passed.passed).toEqual(true)
		expect(passed.yesCount).toEqual(3)
		expect(passed.keepMarks).toEqual(true)
		expect(passed.dropQueuePriority).toEqual(false)
		expect(passed.forfeitRewards).toEqual(false)
		expect(passed.queueBackfill).toEqual(false)
		expect(passed.spentKick).toEqual(false)
	end)

	it("ignores the target, outsiders, and anything that is not a yes", function()
		local votes = yesFrom(1, 2)
		votes[4] = true
		votes[9] = true
		votes[3] = "yes"
		local ignored = RaidConduct.tally(voteRequest({ votes = votes }))
		expect(ignored.passed).toEqual(false)
		expect(ignored.yesCount).toEqual(2)

		local quiet = voteRequest(nil)
		quiet.votes = nil
		local empty = RaidConduct.tally(quiet)
		expect(empty.passed).toEqual(false)
		expect(empty.yesCount).toEqual(0)
	end)

	it("needs 6 yes votes in a group of 8 and 4 in a group of 5", function()
		local eightShort = RaidConduct.tally(voteRequest({
			members = members(8, 0),
			targetUserId = 8,
			votes = yesFrom(1, 5),
		}))
		expect(eightShort.needed).toEqual(6)
		expect(eightShort.yesCount).toEqual(5)
		expect(eightShort.passed).toEqual(false)

		local eight = RaidConduct.tally(voteRequest({
			members = members(8, 0),
			targetUserId = 8,
			votes = yesFrom(1, 6),
		}))
		expect(eight.passed).toEqual(true)
		expect(eight.yesCount).toEqual(6)
		expect(eight.keepMarks).toEqual(true)

		local fiveShort = RaidConduct.tally(voteRequest({
			members = members(5, 0),
			targetUserId = 5,
			votes = yesFrom(1, 3),
		}))
		expect(fiveShort.needed).toEqual(4)
		expect(fiveShort.passed).toEqual(false)
		local five = RaidConduct.tally(voteRequest({
			members = members(5, 0),
			targetUserId = 5,
			votes = yesFrom(1, 4),
		}))
		expect(five.passed).toEqual(true)
	end)

	it("drops queue priority for an idle kick and still keeps Marks", function()
		for _, reason in ipairs({ "idle", "AFK", "  idle  ", "Afk" }) do
			local kicked = RaidConduct.tally(voteRequest({ reason = reason }))
			expect(kicked.passed).toEqual(true)
			expect(kicked.dropQueuePriority).toEqual(true)
			expect(kicked.keepMarks).toEqual(true)
			expect(kicked.forfeitRewards).toEqual(false)
			expect(kicked.queueBackfill).toEqual(false)
		end
		local typed = RaidConduct.tally(voteRequest({ reason = "idle player" }))
		expect(typed.passed).toEqual(true)
		expect(typed.dropQueuePriority).toEqual(false)
		expect(typed.keepMarks).toEqual(true)
	end)

	it("keeps Marks when the reason says the kick was unfair", function()
		local unfair = RaidConduct.tally(voteRequest({ reason = "unfair" }))
		expect(unfair.passed).toEqual(true)
		expect(unfair.keepMarks).toEqual(true)
		expect(unfair.forfeitRewards).toEqual(false)
		expect(unfair.dropQueuePriority).toEqual(false)
	end)

	it("does not drop priority or forfeit when an idle vote falls short", function()
		local short = RaidConduct.tally(voteRequest({
			reason = "idle",
			votes = yesFrom(1, 2),
		}))
		expect(short.passed).toEqual(false)
		expect(short.dropQueuePriority).toEqual(false)
		expect(short.keepMarks).toEqual(true)
		expect(short.forfeitRewards).toEqual(false)
	end)

	it("cannot resolve during combat, a Guided Raid, or the opening window", function()
		expect(RaidConduct.tally(voteRequest({ guided = true })).passed).toEqual(false)
		expect(RaidConduct.tally(voteRequest({ guided = true })).ok).toEqual(false)
		expect(RaidConduct.tally(voteRequest({ guided = true })).dropQueuePriority).toEqual(false)
		expect(RaidConduct.tally(voteRequest({ inCombat = true })).error).toEqual(ERRORS.combat)
		expect(RaidConduct.tally(voteRequest({ now = 30 })).error).toEqual(ERRORS.early)
		local fresh = RaidConduct.tally(voteRequest({
			now = 500,
			reason = "idle",
			members = members(4, 450),
		}))
		expect(fresh.passed).toEqual(false)
		expect(fresh.error).toEqual(ERRORS.joined)
		expect(fresh.dropQueuePriority).toEqual(false)
	end)

	it("does not spend a kick while counting votes", function()
		local counted = RaidConduct.tally(voteRequest({ kickDay = 4, kickCount = 1 }))
		expect(counted.passed).toEqual(true)
		expect(counted.spentKick).toEqual(false)
		expect(counted.kickDay).toEqual(4)
		expect(counted.kickCount).toEqual(1)
	end)

	it("treats a missing raid clock as closed", function()
		local missing = RaidConduct.openVote(nil)
		expect(missing.ok).toEqual(false)
		expect(missing.spentKick).toEqual(false)
		expect(missing.error).toEqual(ERRORS.time)
		expect(RaidConduct.tally(voteRequest({ now = 0 / 0 })).error).toEqual(ERRORS.time)
		expect(RaidConduct.openVote(voteRequest({ raidStartedAt = math.huge })).spentKick).toEqual(
			false
		)
	end)
end)
