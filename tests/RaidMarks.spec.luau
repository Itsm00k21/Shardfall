--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidMarks = require("../src/ReplicatedStorage/Shared/RaidMarks")

local ERRORS = RaidMarks.ERRORS

-- 1970-01-06 00:00:00 UTC, the first Tuesday. Week key 1.
local FIRST = 432000
local WEEK = 7 * 86400
-- 2026-10-13 00:00:00 UTC, a Tuesday. Week key 2963.
local TUESDAY = 1791849600

local function blank(patch: { [string]: any }?)
	local state = {
		balance = 0,
		weekKey = -1,
		earnedThisWeek = 0,
		bankedCap = 0,
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			state[key] = value
		end
	end
	return state
end

local function from(result)
	return {
		balance = result.balance,
		weekKey = result.weekKey,
		earnedThisWeek = result.earnedThisWeek,
		bankedCap = result.bankedCap,
	}
end

describe("RaidMarks config", function()
	it("pins the weekly cap, the Tuesday clock, and the bank", function()
		expect(RaidMarks.CONFIG.weeklyCap).toEqual(600)
		expect(RaidMarks.CONFIG.bankWeeks).toEqual(3)
		expect(RaidMarks.CONFIG.weekSeconds).toEqual(WEEK)
		expect(RaidMarks.CONFIG.daySeconds).toEqual(86400)
		expect(RaidMarks.CONFIG.tuesdayOffset).toEqual(FIRST)
		expect(RaidMarks.CONFIG.firstTimerNumerator).toEqual(1)
		expect(RaidMarks.CONFIG.firstTimerDenominator).toEqual(10)
		expect(RaidMarks.CONFIG.eventMultiplier).toEqual(2)
		expect(RaidMarks.CONFIG.doubleMarks).toEqual(false)
		expect(RaidMarks.CONFIG.weeklyCap * RaidMarks.CONFIG.bankWeeks).toEqual(1800)
	end)

	it("pins placeholder payouts per difficulty", function()
		expect(RaidMarks.CONFIG.payouts).toEqual({
			story = 25,
			normal = 40,
			hard = 60,
			shardbreaker = 80,
			fracture = 20,
		})
	end)

	it("freezes the thresholds, the payouts, the removals, and the errors", function()
		expect(function()
			RaidMarks.CONFIG.weeklyCap = 1
		end).toThrow()
		expect(function()
			RaidMarks.CONFIG.doubleMarks = true
		end).toThrow()
		expect(function()
			RaidMarks.CONFIG.payouts.story = 1
		end).toThrow()
		expect(function()
			RaidMarks.REMOVALS.afk = false
		end).toThrow()
		expect(function()
			RaidMarks.ERRORS.short = "open"
		end).toThrow()
	end)

	it("has no Robux price and no combat power", function()
		local banned = {
			robux = true,
			premium = true,
			productid = true,
			damage = true,
			health = true,
			attack = true,
		}
		for key in pairs(RaidMarks.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
	end)

	it("names only the AFK removal and the passed vote-kick", function()
		expect(RaidMarks.REMOVALS).toEqual({
			afk = true,
			kick = true,
		})
	end)
end)

describe("RaidMarks week key", function()
	it("starts week 1 at Tuesday 1970-01-06 00:00 UTC", function()
		expect(RaidMarks.weekKey(0)).toEqual(0)
		expect(RaidMarks.weekKey(FIRST - 1)).toEqual(0)
		expect(RaidMarks.weekKey(FIRST)).toEqual(1)
		expect(RaidMarks.weekKey(FIRST + WEEK - 1)).toEqual(1)
		expect(RaidMarks.weekKey(FIRST + WEEK)).toEqual(2)
	end)

	it("puts Tuesday 2026-10-13 00:00 UTC on its own key", function()
		expect(RaidMarks.weekKey(TUESDAY - 1)).toEqual(2962)
		expect(RaidMarks.weekKey(TUESDAY)).toEqual(2963)
		expect(RaidMarks.weekKey(TUESDAY + WEEK)).toEqual(2964)
	end)

	it("rejects a clock that is not unix seconds", function()
		expect(RaidMarks.weekKey(-1)).toBeNil()
		expect(RaidMarks.weekKey(0 / 0)).toBeNil()
		expect(RaidMarks.weekKey(math.huge)).toBeNil()
	end)
end)

describe("RaidMarks payout", function()
	it("pays the placeholder for each difficulty", function()
		local expected = {
			story = 25,
			normal = 40,
			hard = 60,
			shardbreaker = 80,
			fracture = 20,
		}
		for name, amount in pairs(expected) do
			local grant = RaidMarks.payout(name, nil)
			expect(grant.ok).toEqual(true)
			expect(grant.amount).toEqual(amount)
			expect(grant.base).toEqual(amount)
			expect(grant.gross).toEqual(amount)
			expect(grant.keepMarks).toEqual(true)
			expect(grant.forfeited).toEqual(false)
			expect(grant.reclear).toEqual(false)
			expect(grant.multiplier).toEqual(1)
			expect(grant.event).toEqual(false)
		end
	end)

	it("accepts a difficulty name with different case and surrounding spaces", function()
		local grant = RaidMarks.payout(" Normal ", nil)
		expect(grant.ok).toEqual(true)
		expect(grant.difficulty).toEqual("normal")
		expect(grant.amount).toEqual(40)
	end)

	it("refuses a difficulty that has no placeholder", function()
		expect(RaidMarks.payout("mythic", nil)).toEqual({
			ok = false,
			difficulty = "",
			amount = 0,
			base = 0,
			gross = 0,
			firstTimers = 0,
			multiplier = 1,
			event = false,
			locked = false,
			reclear = false,
			keepMarks = false,
			forfeited = false,
			error = ERRORS.difficulty,
		})
		expect(RaidMarks.payout(nil, nil).error).toEqual(ERRORS.difficulty)
	end)

	it("pays a lockout reclear the same Marks as the first clear", function()
		local first = RaidMarks.payout("hard", { locked = false })
		local again = RaidMarks.payout("hard", { locked = true })
		expect(first.amount).toEqual(60)
		expect(again.amount).toEqual(first.amount)
		expect(again.gross).toEqual(first.gross)
		expect(again.reclear).toEqual(true)
		expect(again.locked).toEqual(true)
		expect(again.keepMarks).toEqual(true)
	end)

	it("adds 10% per first-timer and rounds half up", function()
		local one = RaidMarks.payout("story", { firstTimers = 1 })
		expect(one.amount).toEqual(28)
		expect(one.gross).toEqual(28)
		expect(one.base).toEqual(25)
		expect(one.firstTimers).toEqual(1)
		local two = RaidMarks.payout("normal", { firstTimers = 2 })
		expect(two.amount).toEqual(48)
		local three = RaidMarks.payout("story", { firstTimers = 3 })
		expect(three.amount).toEqual(33)
		local eight = RaidMarks.payout("normal", { firstTimers = 8 })
		expect(eight.amount).toEqual(72)
	end)

	it("refuses a fractional or negative first-timer count", function()
		expect(RaidMarks.payout("story", { firstTimers = 1.5 }).error).toEqual(ERRORS.timers)
		expect(RaidMarks.payout("story", { firstTimers = -1 }).error).toEqual(ERRORS.timers)
	end)

	it("pays 0 for an AFK removal and keeps the grant for a passed vote-kick", function()
		local afk = RaidMarks.payout("normal", {
			firstTimers = 1,
			removal = "afk",
			locked = true,
		})
		expect(afk.ok).toEqual(true)
		expect(afk.amount).toEqual(0)
		expect(afk.gross).toEqual(44)
		expect(afk.keepMarks).toEqual(false)
		expect(afk.forfeited).toEqual(true)
		expect(afk.reclear).toEqual(true)
		local kick = RaidMarks.payout("normal", {
			firstTimers = 1,
			removal = "kick",
		})
		expect(kick.amount).toEqual(44)
		expect(kick.keepMarks).toEqual(true)
		expect(kick.forfeited).toEqual(false)
	end)

	it("refuses an unknown removal", function()
		expect(RaidMarks.payout("story", { removal = "AFK" }).error).toEqual(ERRORS.removal)
		expect(RaidMarks.payout("story", { removal = "idle" }).error).toEqual(ERRORS.removal)
		expect(RaidMarks.payout("story", { removal = "leave" }).error).toEqual(ERRORS.removal)
	end)

	it("ignores an event flag while the double-Marks switch is off", function()
		local plain = RaidMarks.payout("shardbreaker", { event = false })
		local night = RaidMarks.payout("shardbreaker", {
			event = true,
			firstTimers = 1,
		})
		local quiet = RaidMarks.payout("shardbreaker", {
			event = false,
			firstTimers = 1,
		})
		expect(plain.amount).toEqual(80)
		expect(night.amount).toEqual(quiet.amount)
		expect(night.amount).toEqual(88)
		expect(night.multiplier).toEqual(1)
		expect(night.event).toEqual(false)
		expect(RaidMarks.CONFIG.doubleMarks).toEqual(false)
		expect(RaidMarks.CONFIG.eventMultiplier).toEqual(2)
	end)

	it("refuses a lockout flag that is not true or false", function()
		expect(RaidMarks.payout("story", { locked = "yes" }).error).toEqual(ERRORS.lock)
		expect(RaidMarks.payout("story", 4).error).toEqual(ERRORS.clear)
	end)

	it("does not write the clear it was given", function()
		local clear = table.freeze({
			firstTimers = 1,
			locked = true,
			removal = "kick",
			event = true,
		})
		local grant = RaidMarks.payout("story", clear)
		expect(grant.amount).toEqual(28)
		expect(clear.firstTimers).toEqual(1)
		expect(clear.removal).toEqual("kick")
	end)
end)

describe("RaidMarks earn", function()
	it("stamps a new profile on this Tuesday without banking the past", function()
		local earned = RaidMarks.earn(25, nil, TUESDAY)
		expect(earned).toEqual({
			ok = true,
			balance = 25,
			weekKey = 2963,
			earnedThisWeek = 25,
			bankedCap = 0,
			granted = 25,
			capped = false,
			room = 575,
			rolled = true,
		})
	end)

	it("stops at 600 in a week that has no bank", function()
		local first = RaidMarks.earn(600, nil, FIRST)
		local second = RaidMarks.earn(40, from(first), FIRST + 10)
		expect(first.granted).toEqual(600)
		expect(first.room).toEqual(0)
		expect(second).toEqual({
			ok = true,
			balance = 600,
			weekKey = 1,
			earnedThisWeek = 600,
			bankedCap = 0,
			granted = 0,
			capped = true,
			room = 0,
			rolled = false,
		})
	end)

	it("grants the remaining room when the clear is larger than the cap", function()
		local state = blank({
			balance = 590,
			weekKey = 1,
			earnedThisWeek = 590,
		})
		expect(RaidMarks.earn(40, state, FIRST)).toEqual({
			ok = true,
			balance = 600,
			weekKey = 1,
			earnedThisWeek = 600,
			bankedCap = 0,
			granted = 10,
			capped = true,
			room = 0,
			rolled = false,
		})
	end)

	it("carries the unused cap into the next Tuesday", function()
		local opened = RaidMarks.earn(100, nil, FIRST)
		local nextWeek = RaidMarks.earn(50, from(opened), FIRST + WEEK)
		expect(nextWeek).toEqual({
			ok = true,
			balance = 150,
			weekKey = 2,
			earnedThisWeek = 50,
			bankedCap = 500,
			granted = 50,
			capped = false,
			room = 1050,
			rolled = true,
		})
	end)

	it("banks a fully idle week and keeps the balance", function()
		local opened = RaidMarks.settle(blank({ balance = 1000 }), FIRST)
		local idle = RaidMarks.settle(from(opened), FIRST + WEEK)
		expect(opened.bankedCap).toEqual(0)
		expect(opened.weekKey).toEqual(1)
		expect(idle).toEqual({
			ok = true,
			balance = 1000,
			weekKey = 2,
			earnedThisWeek = 0,
			bankedCap = 600,
			granted = 0,
			capped = false,
			room = 1200,
			rolled = true,
		})
	end)

	it("accumulates skipped weeks up to 3 and then holds the bank", function()
		local opened = RaidMarks.settle(nil, FIRST)
		local jumped = RaidMarks.settle(from(opened), FIRST + 4 * WEEK)
		expect(opened.weekKey).toEqual(1)
		expect(jumped.weekKey).toEqual(5)
		expect(jumped.bankedCap).toEqual(1800)
		expect(jumped.room).toEqual(2400)
		expect(jumped.earnedThisWeek).toEqual(0)
		local held = RaidMarks.settle(from(jumped), FIRST + 5 * WEEK)
		expect(held.bankedCap).toEqual(1800)
		expect(held.room).toEqual(2400)
		expect(held.weekKey).toEqual(6)
	end)

	it("matches a one-week jump with settling each Tuesday", function()
		local cursor = RaidMarks.settle(nil, FIRST)
		for step = 1, 3 do
			cursor = RaidMarks.settle(from(cursor), FIRST + step * WEEK)
		end
		expect(cursor.bankedCap).toEqual(1800)
		expect(cursor.weekKey).toEqual(4)
		local again = RaidMarks.settle(from(cursor), FIRST + 3 * WEEK)
		expect(again.bankedCap).toEqual(1800)
		expect(again.rolled).toEqual(false)
		expect(again.weekKey).toEqual(4)
	end)

	it("banks the partial leftover across a two-week gap", function()
		local state = blank({
			balance = 100,
			weekKey = 1,
			earnedThisWeek = 100,
			bankedCap = 0,
		})
		local later = RaidMarks.settle(state, FIRST + 2 * WEEK)
		expect(later.ok).toEqual(true)
		expect(later.weekKey).toEqual(3)
		expect(later.bankedCap).toEqual(1100)
		expect(later.room).toEqual(1700)
		expect(later.balance).toEqual(100)
		expect(later.earnedThisWeek).toEqual(0)
	end)

	it("drops the bank after a week that used the whole room", function()
		local state = blank({
			balance = 2400,
			weekKey = 2,
			earnedThisWeek = 2400,
			bankedCap = 1800,
		})
		local later = RaidMarks.settle(state, FIRST + 2 * WEEK)
		expect(later.bankedCap).toEqual(0)
		expect(later.room).toEqual(600)
		expect(later.balance).toEqual(2400)
		expect(later.earnedThisWeek).toEqual(0)
	end)

	it("keeps a full bank when the clear only used this week's 600", function()
		local state = blank({
			balance = 600,
			weekKey = 2,
			earnedThisWeek = 600,
			bankedCap = 1800,
		})
		local later = RaidMarks.earn(0, state, FIRST + 2 * WEEK)
		expect(later.bankedCap).toEqual(1800)
		expect(later.room).toEqual(2400)
	end)

	it("opens the new week at Tuesday 00:00 and not one second earlier", function()
		local state = blank({
			weekKey = 2962,
			earnedThisWeek = 0,
			bankedCap = 0,
		})
		local before = RaidMarks.settle(state, TUESDAY - 1)
		expect(before.weekKey).toEqual(2962)
		expect(before.bankedCap).toEqual(0)
		expect(before.rolled).toEqual(false)
		local at = RaidMarks.settle(state, TUESDAY)
		expect(at.weekKey).toEqual(2963)
		expect(at.bankedCap).toEqual(600)
		expect(at.rolled).toEqual(true)
	end)

	it("refuses a clock behind the stored week and grants nothing", function()
		local state = blank({
			balance = 80,
			weekKey = 2,
			earnedThisWeek = 10,
			bankedCap = 40,
		})
		expect(RaidMarks.earn(5, state, FIRST)).toEqual({
			ok = false,
			balance = 80,
			weekKey = 2,
			earnedThisWeek = 10,
			bankedCap = 40,
			granted = 0,
			capped = false,
			room = 630,
			rolled = false,
			error = ERRORS.clock,
		})
		expect(state.balance).toEqual(80)
	end)

	it("does not roll the week when the amount is unusable", function()
		local state = blank({
			balance = 1,
			weekKey = 1,
			earnedThisWeek = 0,
		})
		local refused = RaidMarks.earn(1.5, state, FIRST + WEEK)
		expect(refused.ok).toEqual(false)
		expect(refused.weekKey).toEqual(1)
		expect(refused.balance).toEqual(1)
		expect(refused.granted).toEqual(0)
		expect(refused.error).toEqual(ERRORS.amount)
		expect(RaidMarks.earn(-1, state, FIRST).error).toEqual(ERRORS.amount)
		expect(RaidMarks.earn("40", state, FIRST).error).toEqual(ERRORS.amount)
	end)

	it("rejects a missing clock and a broken record", function()
		local state = blank({ balance = 5, weekKey = 1 })
		expect(RaidMarks.earn(1, state, -1).error).toEqual(ERRORS.time)
		expect(RaidMarks.earn(1, state, 0 / 0).error).toEqual(ERRORS.time)
		expect(RaidMarks.earn(1, "marks", FIRST)).toEqual({
			ok = false,
			balance = 0,
			weekKey = -1,
			earnedThisWeek = 0,
			bankedCap = 0,
			granted = 0,
			capped = false,
			room = 0,
			rolled = false,
			error = ERRORS.record,
		})
		local broken = blank({ balance = 0 / 0, weekKey = 4 })
		expect(RaidMarks.earn(1, broken, FIRST).error).toEqual(ERRORS.record)
		expect(broken.weekKey).toEqual(4)
	end)

	it("floors stored marks and treats a negative wallet as empty", function()
		local earned = RaidMarks.earn(10, {
			balance = -4,
			weekKey = 1.9,
			earnedThisWeek = -2,
			bankedCap = 1800.9,
		}, FIRST)
		expect(earned.ok).toEqual(true)
		expect(earned.balance).toEqual(10)
		expect(earned.weekKey).toEqual(1)
		expect(earned.earnedThisWeek).toEqual(10)
		expect(earned.bankedCap).toEqual(1800)
		expect(earned.rolled).toEqual(false)
	end)

	it("clamps a stored bank above 3 weeks", function()
		local settled = RaidMarks.settle(
			blank({
				weekKey = 1,
				bankedCap = 5000,
				earnedThisWeek = 0,
			}),
			FIRST
		)
		expect(settled.ok).toEqual(true)
		expect(settled.bankedCap).toEqual(1800)
		expect(settled.room).toEqual(2400)
		expect(settled.rolled).toEqual(false)
	end)

	it("does not write the record it was given", function()
		local frozen = table.freeze({
			balance = 15,
			weekKey = 1,
			earnedThisWeek = 15,
			bankedCap = 0,
			note = "keep",
		})
		local earned = RaidMarks.earn(10, frozen, FIRST + WEEK)
		expect(earned.balance).toEqual(25)
		expect(earned.bankedCap).toEqual(585)
		expect(frozen.balance).toEqual(15)
		expect(frozen.earnedThisWeek).toEqual(15)
		expect(frozen.weekKey).toEqual(1)
		expect(frozen.note).toEqual("keep")
		expect(earned.note).toBeNil()
	end)

	it("lets a caller chain payout into earn, including a reclear and an AFK", function()
		local state = blank({
			balance = 10,
			weekKey = 2963,
			earnedThisWeek = 590,
		})
		local reclear = RaidMarks.payout("normal", {
			locked = true,
			firstTimers = 1,
		})
		expect(reclear.amount).toEqual(44)
		local paid = RaidMarks.earn(reclear.amount, state, TUESDAY + 10)
		expect(paid.granted).toEqual(10)
		expect(paid.capped).toEqual(true)
		expect(paid.balance).toEqual(20)
		local afk = RaidMarks.payout("normal", { removal = "afk" })
		local skipped = RaidMarks.earn(afk.amount, from(paid), TUESDAY + 11)
		expect(afk.amount).toEqual(0)
		expect(skipped.granted).toEqual(0)
		expect(skipped.balance).toEqual(20)
		expect(skipped.capped).toEqual(false)
		local kick = RaidMarks.payout("story", { removal = "kick" })
		local nextWeek = FIRST + WEEK
		local kept = RaidMarks.earn(
			kick.amount,
			blank({
				balance = skipped.balance,
				weekKey = 1,
				earnedThisWeek = 600,
			}),
			nextWeek
		)
		expect(kick.amount).toEqual(25)
		expect(kept.granted).toEqual(25)
		expect(kept.balance).toEqual(45)
		expect(kept.bankedCap).toEqual(0)
	end)
end)

describe("RaidMarks spend", function()
	it("returns the balance after a purchase", function()
		local state = blank({
			balance = 80,
			weekKey = 4,
			earnedThisWeek = 80,
			bankedCap = 20,
		})
		expect(RaidMarks.canSpend(80, state)).toEqual({
			ok = true,
			balance = 0,
			weekKey = 4,
			earnedThisWeek = 80,
			bankedCap = 20,
			spent = 80,
		})
	end)

	it("leaves the balance when the wallet is short", function()
		local state = blank({
			balance = 80,
			weekKey = 4,
			earnedThisWeek = 600,
			bankedCap = 20,
		})
		expect(RaidMarks.canSpend(81, state)).toEqual({
			ok = false,
			balance = 80,
			weekKey = 4,
			earnedThisWeek = 600,
			bankedCap = 20,
			spent = 0,
			error = ERRORS.short,
		})
	end)

	it("treats a zero cost as a purchase of nothing", function()
		local spent = RaidMarks.canSpend(0, blank({ balance = 12, weekKey = 3 }))
		expect(spent.ok).toEqual(true)
		expect(spent.spent).toEqual(0)
		expect(spent.balance).toEqual(12)
		expect(spent.weekKey).toEqual(3)
	end)

	it("does not roll the week and does not read a clock", function()
		local state = blank({
			balance = 100,
			weekKey = 1,
			earnedThisWeek = 100,
			bankedCap = 0,
		})
		local spent = RaidMarks.canSpend(30, state)
		expect(spent.balance).toEqual(70)
		expect(spent.weekKey).toEqual(1)
		expect(spent.earnedThisWeek).toEqual(100)
		expect(spent.bankedCap).toEqual(0)
		local later = RaidMarks.earn(10, from(spent), FIRST + WEEK)
		expect(later.balance).toEqual(80)
		expect(later.bankedCap).toEqual(500)
		expect(later.earnedThisWeek).toEqual(10)
	end)

	it("refuses a bad cost and a broken record", function()
		local state = blank({ balance = 10, weekKey = 2 })
		expect(RaidMarks.canSpend(1.2, state).error).toEqual(ERRORS.cost)
		expect(RaidMarks.canSpend(-5, state).error).toEqual(ERRORS.cost)
		expect(RaidMarks.canSpend(1, "wallet").error).toEqual(ERRORS.record)
		expect(state.balance).toEqual(10)
	end)

	it("does not write the record it was given", function()
		local frozen = table.freeze({
			balance = 50,
			weekKey = 6,
			earnedThisWeek = 50,
			bankedCap = 10,
		})
		local spent = RaidMarks.canSpend(20, frozen)
		expect(spent.balance).toEqual(30)
		expect(frozen.balance).toEqual(50)
		expect(frozen.earnedThisWeek).toEqual(50)
		expect(frozen.bankedCap).toEqual(10)
		local short = RaidMarks.canSpend(51, frozen)
		expect(short.ok).toEqual(false)
		expect(frozen.balance).toEqual(50)
	end)

	it("heals a negative wallet to empty before the check", function()
		local spent = RaidMarks.canSpend(1, {
			balance = -5,
			weekKey = -1,
			earnedThisWeek = 0,
			bankedCap = 0,
		})
		expect(spent.ok).toEqual(false)
		expect(spent.balance).toEqual(0)
		expect(spent.error).toEqual(ERRORS.short)
	end)
end)
