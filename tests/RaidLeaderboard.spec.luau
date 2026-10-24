--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidConduct = require("../src/ReplicatedStorage/Shared/RaidConduct")
local RaidLeaderboard = require("../src/ReplicatedStorage/Shared/RaidLeaderboard")

local ERRORS = RaidLeaderboard.ERRORS

-- A nil value in a table constructor is dropped, so omitted fields use this.
local OMIT = {}

local function rosterOf(count: number): { number }
	local roster = {}
	for index = 1, count do
		roster[index] = index * 10
	end
	return roster
end

local function clear(overrides: { [string]: any }?): { [string]: any }
	local row: { [string]: any } = {
		runId = 1,
		difficulty = "normal",
		size = 4,
		start = 1000,
		["end"] = 2200,
		roster = rosterOf(4),
		practice = false,
	}
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			if value == OMIT then
				row[key] = nil
			else
				row[key] = value
			end
		end
	end
	return row
end

local function idsOf(board: { entries: { any } }): { any }
	local ids = {}
	for index, entry in ipairs(board.entries) do
		ids[index] = entry.runId
	end
	return ids
end

describe("RaidLeaderboard config", function()
	it("keeps Normal live and pins the top N and the floor", function()
		expect(RaidLeaderboard.CONFIG.topN).toEqual(10)
		expect(RaidLeaderboard.CONFIG.floorSeconds).toEqual(300)
		expect(RaidLeaderboard.CONFIG.minParty).toEqual(4)
		expect(RaidLeaderboard.CONFIG.maxParty).toEqual(8)
		expect(RaidLeaderboard.CONFIG.live).toEqual({ normal = true })
		expect(RaidLeaderboard.DIFFICULTIES).toEqual({
			story = true,
			normal = true,
			hard = true,
			shardbreaker = true,
		})
		expect(RaidLeaderboard.AFK_STATE).toEqual("remove")
		expect(RaidLeaderboard.REMOVALS).toEqual({
			afk = true,
			kick = true,
		})
		expect(RaidLeaderboard.PRESENT_STATES).toEqual({
			ok = true,
			warning = true,
			paused = true,
		})
	end)

	it("freezes the thresholds and the errors", function()
		expect(function()
			RaidLeaderboard.CONFIG.topN = 1
		end).toThrow()
		expect(function()
			RaidLeaderboard.CONFIG.floorSeconds = 1
		end).toThrow()
		expect(function()
			RaidLeaderboard.CONFIG.live.normal = false
		end).toThrow()
		expect(function()
			RaidLeaderboard.DIFFICULTIES.story = false
		end).toThrow()
		expect(function()
			RaidLeaderboard.REMOVALS.afk = false
		end).toThrow()
		expect(function()
			RaidLeaderboard.ERRORS.floor = "open"
		end).toThrow()
	end)

	it("has no Robux price and no combat power", function()
		local banned = {
			robux = true,
			premium = true,
			productid = true,
			gamepass = true,
			damage = true,
			health = true,
			attack = true,
		}
		for key in pairs(RaidLeaderboard.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
	end)
end)

describe("RaidLeaderboard submit", function()
	it("ranks a normal clear and does not write the input", function()
		local row = clear({
			roster = { 40, 10, 30, 20 },
		})
		local roster = row.roster
		table.freeze(row)
		table.freeze(roster)
		local result = RaidLeaderboard.submit(nil, row)
		expect(result.ok).toEqual(true)
		expect(result.accepted).toEqual(true)
		expect(result.duplicate).toEqual(false)
		expect(result.trimmed).toEqual(false)
		expect(result.error).toBeNil()
		expect(result.entry).toEqual({
			runId = 1,
			difficulty = "normal",
			size = 4,
			duration = 1200,
			clearedAt = 2200,
			roster = { 10, 20, 30, 40 },
		})
		expect(result.board.entries).toEqual({ result.entry })
		expect(roster[1]).toEqual(40)
		result.board.entries[1].roster[1] = 999
		expect(result.entry.roster[1]).toEqual(10)

		local empty = RaidLeaderboard.submit({}, clear({ runId = 2 }))
		expect(empty.accepted).toEqual(true)
		local noted = RaidLeaderboard.submit({ note = true }, clear({ runId = 3 }))
		expect(noted.accepted).toEqual(true)
		expect(noted.board.note).toBeNil()

		local aliased = RaidLeaderboard.submit(
			nil,
			clear({
				runId = 4,
				start = OMIT,
				startedAt = 1000,
				["end"] = OMIT,
				endedAt = 2200,
			})
		)
		expect(aliased.entry.duration).toEqual(1200)
		expect(aliased.entry.clearedAt).toEqual(2200)

		local sized = RaidLeaderboard.submit(nil, clear({ size = OMIT }))
		expect(sized.entry.size).toEqual(4)

		local named = RaidLeaderboard.submit(
			nil,
			clear({
				runId = "  heartwood-1  ",
				difficulty = " Normal ",
			})
		)
		expect(named.entry.runId).toEqual("heartwood-1")
		expect(named.entry.difficulty).toEqual("normal")

		local tables = RaidLeaderboard.submit(
			nil,
			clear({
				roster = {
					{ userId = 40, removal = "afk" },
					{ userId = 10 },
					{ userId = 30 },
					{ userId = 20 },
				},
			})
		)
		expect(tables.entry.roster).toEqual({ 10, 20, 30, 40 })
	end)

	it("rejects practice before a disabled or unknown difficulty", function()
		local practice = RaidLeaderboard.submit(
			nil,
			clear({
				practice = true,
				difficulty = "story",
			})
		)
		expect(practice.ok).toEqual(false)
		expect(practice.accepted).toEqual(false)
		expect(practice.error).toEqual(ERRORS.practice)
		expect(practice.board).toEqual({ entries = {} })

		expect(RaidLeaderboard.submit(nil, clear({ practice = "true" })).error).toEqual(
			ERRORS.practiceFlag
		)
		expect(RaidLeaderboard.submit(nil, clear({ practice = OMIT })).accepted).toEqual(true)
		expect(RaidLeaderboard.submit(nil, clear({ difficulty = "story" })).error).toEqual(
			ERRORS.disabled
		)
		expect(RaidLeaderboard.submit(nil, clear({ difficulty = " HARD " })).error).toEqual(
			ERRORS.disabled
		)
		expect(RaidLeaderboard.submit(nil, clear({ difficulty = "shardbreaker" })).error).toEqual(
			ERRORS.disabled
		)
		expect(RaidLeaderboard.submit(nil, clear({ difficulty = "fracture" })).error).toEqual(
			ERRORS.difficulty
		)
		expect(RaidLeaderboard.submit(nil, clear({ difficulty = "guided" })).error).toEqual(
			ERRORS.difficulty
		)
		expect(RaidLeaderboard.submit(nil, clear({ difficulty = "" })).error).toEqual(
			ERRORS.difficulty
		)
	end)

	it("rejects bad times and clears under the floor", function()
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = 2000,
				["end"] = 1000,
			})
		).error).toEqual(ERRORS.time)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = 1000,
				["end"] = 1000,
			})
		).error).toEqual(ERRORS.time)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = 0,
				["end"] = 1000,
				duration = 1001,
			})
		).error).toEqual(ERRORS.time)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = 1000,
				startedAt = 1001,
			})
		).error).toEqual(ERRORS.time)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = OMIT,
				["end"] = OMIT,
			})
		).error).toEqual(ERRORS.time)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = 1000,
				["end"] = OMIT,
				duration = 1200,
			})
		).error).toEqual(ERRORS.time)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = OMIT,
				["end"] = OMIT,
				duration = 0 / 0,
			})
		).error).toEqual(ERRORS.time)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = OMIT,
				["end"] = OMIT,
				duration = math.huge,
			})
		).error).toEqual(ERRORS.time)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				start = 0,
				["end"] = 299,
			})
		).error).toEqual(ERRORS.floor)

		local atFloor = RaidLeaderboard.submit(
			nil,
			clear({
				start = 0,
				["end"] = 300,
			})
		)
		expect(atFloor.accepted).toEqual(true)
		expect(atFloor.entry.duration).toEqual(300)
		expect(atFloor.entry.clearedAt).toEqual(300)

		local durationOnly = RaidLeaderboard.submit(
			nil,
			clear({
				start = OMIT,
				["end"] = OMIT,
				duration = 1000,
			})
		)
		expect(durationOnly.accepted).toEqual(true)
		expect(durationOnly.entry.duration).toEqual(1000)
		expect(durationOnly.entry.clearedAt).toBeNil()

		local ended = RaidLeaderboard.submit(
			nil,
			clear({
				start = OMIT,
				["end"] = 5000,
				duration = 1000,
			})
		)
		expect(ended.entry.duration).toEqual(1000)
		expect(ended.entry.clearedAt).toEqual(5000)
	end)

	it("rejects a bad roster and a party size that does not match", function()
		expect(RaidLeaderboard.submit(nil, clear({ size = 3 })).error).toEqual(ERRORS.size)
		expect(RaidLeaderboard.submit(nil, clear({ size = 9 })).error).toEqual(ERRORS.size)
		expect(RaidLeaderboard.submit(nil, clear({ size = 4.5 })).error).toEqual(ERRORS.size)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				size = 5,
				roster = rosterOf(4),
			})
		).error).toEqual(ERRORS.sizeMatch)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				size = OMIT,
				roster = rosterOf(3),
			})
		).error).toEqual(ERRORS.size)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				roster = { 10, 10, 20, 30 },
			})
		).error).toEqual(ERRORS.duplicate)
		expect(RaidLeaderboard.submit(nil, clear({ roster = { 10, "20", 30, 40 } })).error).toEqual(
			ERRORS.roster
		)
		expect(RaidLeaderboard.submit(nil, "clear").error).toEqual(ERRORS.record)
		expect(RaidLeaderboard.submit(nil, clear({ runId = 0 })).error).toEqual(ERRORS.runId)
		expect(RaidLeaderboard.submit(nil, clear({ runId = "  " })).error).toEqual(ERRORS.runId)
		expect(RaidLeaderboard.submit(nil, clear({ runId = 1.5 })).error).toEqual(ERRORS.runId)
	end)

	it("credits only players who were not removed", function()
		local kicked = RaidLeaderboard.submit(
			nil,
			clear({
				removals = {
					[20] = " AFK ",
					[30] = "kick",
				},
			})
		)
		expect(kicked.accepted).toEqual(true)
		expect(kicked.entry.roster).toEqual({ 10, 40 })
		expect(kicked.entry.size).toEqual(4)

		local listed = RaidLeaderboard.submit(
			nil,
			clear({
				removals = {
					{ userId = 20, removal = " remove " },
					{ userId = 40, cause = "kick" },
				},
			})
		)
		expect(listed.entry.roster).toEqual({ 10, 30 })

		local afk = RaidConduct.afk({
			now = 200,
			lastInputAt = 0,
		})
		expect(afk.state).toEqual("remove")
		local fromConduct = RaidLeaderboard.submit(
			nil,
			clear({
				removals = { [20] = afk },
			})
		)
		expect(fromConduct.entry.roster).toEqual({ 10, 30, 40 })

		local vote = RaidConduct.tally({
			now = 1000,
			raidStartedAt = 0,
			inCombat = false,
			guided = false,
			initiatorUserId = 10,
			targetUserId = 40,
			reason = "afk",
			members = { 10, 20, 30, 40 },
			votes = { [10] = true, [20] = true, [30] = true },
		})
		expect(vote.ok).toEqual(true)
		expect(vote.passed).toEqual(true)
		local fromVote = RaidLeaderboard.submit(
			nil,
			clear({
				removals = { [40] = vote },
			})
		)
		expect(fromVote.entry.roster).toEqual({ 10, 20, 30 })

		local warned = RaidLeaderboard.submit(
			nil,
			clear({
				removals = {
					[20] = { ok = true, state = "warning" },
					[30] = { ok = true, state = "paused" },
					[10] = { ok = true, passed = false },
				},
			})
		)
		expect(warned.entry.roster).toEqual({ 10, 20, 30, 40 })

		local firstUser = RaidLeaderboard.submit(
			nil,
			clear({
				roster = { 1, 2, 3, 4 },
				removals = {
					[1] = { ok = true, state = "remove" },
				},
			})
		)
		expect(firstUser.entry.roster).toEqual({ 2, 3, 4 })

		expect(RaidLeaderboard.submit(nil, clear({ removals = {} })).entry.roster).toEqual({
			10,
			20,
			30,
			40,
		})
	end)

	it("rejects a bad removal and does not keep an empty finish", function()
		local failed = RaidConduct.afk(nil)
		expect(failed.ok).toEqual(false)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				removals = { [20] = failed },
			})
		).error).toEqual(ERRORS.removal)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				removals = { [20] = "leave" },
			})
		).error).toEqual(ERRORS.removal)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				removals = { [20] = "idle" },
			})
		).error).toEqual(ERRORS.removal)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				removals = { [99] = "afk" },
			})
		).error).toEqual(ERRORS.absent)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				removals = { ["20"] = "afk" },
			})
		).error).toEqual(ERRORS.userId)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				removals = {
					{ userId = 20, removal = "afk" },
					{ userId = 20, cause = "kick" },
				},
			})
		).error).toEqual(ERRORS.removalTwice)
		expect(RaidLeaderboard.submit(
			nil,
			clear({
				removals = {
					{ userId = 20, removal = "afk" },
					"kick",
				},
			})
		).error).toEqual(ERRORS.removal)

		local empty = RaidLeaderboard.submit(
			nil,
			clear({
				runId = 7,
				removals = {
					[10] = "afk",
					[20] = "kick",
					[30] = "remove",
					[40] = "kick",
				},
			})
		)
		expect(empty.ok).toEqual(false)
		expect(empty.error).toEqual(ERRORS.empty)
		expect(empty.board.entries).toEqual({})
		local later = RaidLeaderboard.submit(empty.board, clear({ runId = 7 }))
		expect(later.accepted).toEqual(true)
		expect(later.entry.runId).toEqual(7)
	end)

	it("treats the same runId as a no-op", function()
		local first = RaidLeaderboard.submit(nil, clear())
		local board = first.board
		board.entries[1].note = "keep"
		table.freeze(board)
		table.freeze(board.entries)
		table.freeze(board.entries[1])
		table.freeze(board.entries[1].roster)
		local again = RaidLeaderboard.submit(
			board,
			clear({
				practice = true,
				start = 0,
				["end"] = 400,
			})
		)
		expect(again.ok).toEqual(true)
		expect(again.accepted).toEqual(false)
		expect(again.duplicate).toEqual(true)
		expect(again.trimmed).toEqual(false)
		expect(again.entry).toBeNil()
		expect(again.board.entries[1].duration).toEqual(1200)
		expect(again.board.entries[1].note).toBeNil()
		expect(board.entries[1].note).toEqual("keep")
		expect(again.board == board).toEqual(false)

		local otherSize = RaidLeaderboard.submit(
			again.board,
			clear({
				size = 5,
				roster = rosterOf(5),
				start = 0,
				["end"] = 400,
			})
		)
		expect(otherSize.duplicate).toEqual(true)
		expect(#otherSize.board.entries).toEqual(1)
		expect(otherSize.board.entries[1].size).toEqual(4)

		local text = RaidLeaderboard.submit(nil, clear({ runId = "  heartwood-1  " }))
		local retry = RaidLeaderboard.submit(text.board, clear({ runId = "heartwood-1" }))
		expect(retry.duplicate).toEqual(true)

		local numberId = RaidLeaderboard.submit(nil, clear({ runId = 2 }))
		local stringId = RaidLeaderboard.submit(
			numberId.board,
			clear({
				runId = "2",
				start = 0,
				["end"] = 400,
			})
		)
		expect(stringId.accepted).toEqual(true)
		expect(#stringId.board.entries).toEqual(2)
	end)

	it("sorts by duration, then earlier clear, then lower runId, and trims", function()
		local slower = RaidLeaderboard.submit(
			nil,
			clear({
				runId = 3,
				start = 4000,
				["end"] = 5000,
			})
		)
		local earlier = RaidLeaderboard.submit(
			slower.board,
			clear({
				runId = 2,
				start = 3000,
				["end"] = 4000,
			})
		)
		local lower = RaidLeaderboard.submit(
			earlier.board,
			clear({
				runId = 1,
				start = 3000,
				["end"] = 4000,
			})
		)
		expect(idsOf(lower.board)).toEqual({ 1, 2, 3 })

		local untimed = RaidLeaderboard.submit(
			nil,
			clear({
				runId = 1,
				start = OMIT,
				["end"] = OMIT,
				duration = 1000,
			})
		)
		local timed = RaidLeaderboard.submit(
			untimed.board,
			clear({
				runId = 2,
				start = 0,
				["end"] = 1000,
			})
		)
		expect(idsOf(timed.board)).toEqual({ 2, 1 })

		local high = RaidLeaderboard.submit(
			nil,
			clear({
				runId = "2",
				start = OMIT,
				["end"] = OMIT,
				duration = 1000,
			})
		)
		local low = RaidLeaderboard.submit(
			high.board,
			clear({
				runId = "10",
				start = OMIT,
				["end"] = OMIT,
				duration = 1000,
			})
		)
		expect(idsOf(low.board)).toEqual({ "10", "2" })

		local board = nil
		for index = 1, 10 do
			local placed = RaidLeaderboard.submit(
				board,
				clear({
					runId = index,
					start = 100,
					["end"] = 500 + index,
				})
			)
			expect(placed.accepted).toEqual(true)
			board = placed.board
		end
		expect(#board.entries).toEqual(10)

		local slow = RaidLeaderboard.submit(
			board,
			clear({
				runId = 11,
				start = 0,
				["end"] = 5000,
			})
		)
		expect(slow.ok).toEqual(true)
		expect(slow.trimmed).toEqual(true)
		expect(slow.accepted).toEqual(false)
		expect(idsOf(slow.board)).toEqual({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })

		local fast = RaidLeaderboard.submit(
			slow.board,
			clear({
				runId = 11,
				start = 0,
				["end"] = 400,
			})
		)
		expect(fast.accepted).toEqual(true)
		expect(fast.board.entries[1].runId).toEqual(11)
		expect(fast.board.entries[1].duration).toEqual(400)
		expect(#fast.board.entries).toEqual(10)
		expect(fast.board.entries[10].runId).toEqual(9)

		local tied = RaidLeaderboard.submit(
			board,
			clear({
				runId = 12,
				start = 100,
				["end"] = 510,
			})
		)
		expect(tied.trimmed).toEqual(true)
		local sooner = RaidLeaderboard.submit(
			board,
			clear({
				runId = 12,
				start = 0,
				["end"] = 410,
			})
		)
		expect(sooner.accepted).toEqual(true)
		expect(idsOf(sooner.board)).toEqual({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 12 })
	end)

	it("keeps each party size on its own board", function()
		local board = nil
		for index = 1, 10 do
			local placed = RaidLeaderboard.submit(
				board,
				clear({
					runId = index,
					start = 100,
					["end"] = 500 + index,
				})
			)
			board = placed.board
		end
		local five = RaidLeaderboard.submit(
			board,
			clear({
				runId = 50,
				size = 5,
				roster = rosterOf(5),
				start = 0,
				["end"] = 900,
			})
		)
		expect(five.accepted).toEqual(true)
		expect(#five.board.entries).toEqual(11)
		expect(five.board.entries[1].size).toEqual(4)
		expect(five.board.entries[11].size).toEqual(5)
		expect(five.board.entries[11].roster).toEqual({ 10, 20, 30, 40, 50 })
	end)

	it("repeats the same board for the same input", function()
		local row = clear({
			removals = { [20] = "afk" },
		})
		expect(RaidLeaderboard.submit(nil, row)).toEqual(RaidLeaderboard.submit(nil, row))
	end)
end)

describe("RaidLeaderboard personalBest and rankOf", function()
	it("returns the fastest credited clear and that row's rank", function()
		local slow = RaidLeaderboard.submit(
			nil,
			clear({
				runId = 1,
				start = 0,
				["end"] = 2000,
			})
		)
		local fast = RaidLeaderboard.submit(
			slow.board,
			clear({
				runId = 2,
				size = 5,
				roster = rosterOf(5),
				start = 0,
				["end"] = 800,
				removals = { [20] = "kick" },
			})
		)
		local best = RaidLeaderboard.personalBest(fast.board, 10)
		expect(best.ok).toEqual(true)
		expect(best.found).toEqual(true)
		expect(best.entry.runId).toEqual(2)
		expect(best.entry.duration).toEqual(800)
		expect(best.entry.roster).toEqual({ 10, 30, 40, 50 })

		local stayed = RaidLeaderboard.personalBest(fast.board, 20)
		expect(stayed.found).toEqual(true)
		expect(stayed.entry.runId).toEqual(1)
		expect(RaidLeaderboard.personalBest(fast.board, 99).found).toEqual(false)

		local overall = RaidLeaderboard.rankOf(fast.board, 10)
		expect(overall).toEqual({
			ok = true,
			found = true,
			rank = 1,
			difficulty = "normal",
			size = 5,
			entry = best.entry,
		})
		expect(RaidLeaderboard.rankOf(fast.board, 30).rank).toEqual(1)
		expect(RaidLeaderboard.rankOf(fast.board, 10, "normal", 4)).toEqual({
			ok = true,
			found = true,
			rank = 1,
			difficulty = "normal",
			size = 4,
			entry = slow.entry,
		})
		expect(RaidLeaderboard.rankOf(fast.board, 20, "normal", 5).found).toEqual(false)
		expect(RaidLeaderboard.rankOf(fast.board, 50, "normal", 4).found).toEqual(false)
		expect(RaidLeaderboard.rankOf(fast.board, 10, "story", 4).found).toEqual(false)
		expect(RaidLeaderboard.rankOf(fast.board, 10, " Normal ", 4).rank).toEqual(1)

		local shared = RaidLeaderboard.rankOf(slow.board, 40)
		expect(shared.rank).toEqual(1)
		expect(RaidLeaderboard.rankOf(slow.board, 10).rank).toEqual(1)
	end)

	it("refuses a bad board, a bad player, and a half-named key", function()
		expect(RaidLeaderboard.personalBest({ entries = {} }, 0).error).toEqual(ERRORS.userId)
		expect(RaidLeaderboard.rankOf(nil, -1).error).toEqual(ERRORS.userId)
		expect(RaidLeaderboard.personalBest(nil, 10).found).toEqual(false)
		expect(RaidLeaderboard.rankOf({ entries = {} }, 10).found).toEqual(false)

		local bare = {
			{
				runId = 1,
				difficulty = "normal",
				size = 4,
				duration = 500,
				roster = { 10, 20, 30, 40 },
			},
		}
		expect(RaidLeaderboard.submit(bare, clear()).error).toEqual(ERRORS.board)
		expect(RaidLeaderboard.personalBest(bare, 10).error).toEqual(ERRORS.board)
		expect(RaidLeaderboard.submit(5, clear()).board).toEqual({ entries = {} })

		local story = {
			entries = {
				{
					runId = 1,
					difficulty = "story",
					size = 4,
					duration = 100,
					clearedAt = 100,
					roster = { 40, 10, 30, 20 },
				},
			},
		}
		local kept = RaidLeaderboard.personalBest(story, 10)
		expect(kept.found).toEqual(true)
		expect(kept.entry.difficulty).toEqual("story")
		expect(kept.entry.duration).toEqual(100)
		expect(kept.entry.roster).toEqual({ 10, 20, 30, 40 })
		local added = RaidLeaderboard.submit(story, clear({ runId = 2 }))
		expect(added.ok).toEqual(true)
		expect(added.board.entries[1].difficulty).toEqual("normal")
		expect(added.board.entries[2].difficulty).toEqual("story")

		local fracture = {
			entries = {
				{
					runId = 1,
					difficulty = "fracture",
					size = 4,
					duration = 500,
					roster = { 10, 20, 30, 40 },
				},
			},
		}
		expect(RaidLeaderboard.personalBest(fracture, 10).error).toEqual(ERRORS.board)
		expect(RaidLeaderboard.rankOf(story, 10, "normal").error).toEqual(ERRORS.key)
		expect(RaidLeaderboard.rankOf(story, 10, nil, 4).error).toEqual(ERRORS.key)
		expect(RaidLeaderboard.rankOf(story, 10, "fracture", 4).error).toEqual(ERRORS.difficulty)
		expect(RaidLeaderboard.rankOf(story, 10, "normal", 3).error).toEqual(ERRORS.size)

		local duplicate = {
			entries = {
				{
					runId = 1,
					difficulty = "normal",
					size = 4,
					duration = 500,
					roster = { 10, 20, 30, 40 },
				},
				{
					runId = 1,
					difficulty = "normal",
					size = 5,
					duration = 500,
					roster = { 10, 20, 30, 40 },
				},
			},
		}
		expect(RaidLeaderboard.submit(duplicate, clear({ runId = 3 })).error).toEqual(ERRORS.board)
	end)
end)
