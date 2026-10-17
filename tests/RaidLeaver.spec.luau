--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidLeaver = require("../src/ReplicatedStorage/Shared/RaidLeaver")

local ERRORS = RaidLeaver.ERRORS

local function blank()
	return {
		leaveDay = 0,
		leaveCount = 0,
		cooldownUntil = 0,
		rejoinUntil = 0,
	}
end

local function from(result)
	return {
		leaveDay = result.leaveDay,
		leaveCount = result.leaveCount,
		cooldownUntil = result.cooldownUntil,
		rejoinUntil = result.rejoinUntil,
	}
end

local function row(patch: { [string]: any }?)
	local record = blank()
	if patch ~= nil then
		for key, value in pairs(patch) do
			record[key] = value
		end
	end
	return record
end

describe("RaidLeaver config", function()
	it("pins the design thresholds", function()
		expect(RaidLeaver.CONFIG.leavesPerDay).toEqual(3)
		expect(RaidLeaver.CONFIG.cooldownSeconds).toEqual(15 * 60)
		expect(RaidLeaver.CONFIG.rejoinSeconds).toEqual(3 * 60)
		expect(RaidLeaver.CONFIG.daySeconds).toEqual(86400)
		expect(RaidLeaver.CONFIG.cooldownSeconds).toEqual(900)
		expect(RaidLeaver.CONFIG.rejoinSeconds).toEqual(180)
	end)

	it("freezes the thresholds, the causes, and the errors", function()
		expect(function()
			RaidLeaver.CONFIG.leavesPerDay = 1
		end).toThrow()
		expect(function()
			RaidLeaver.CAUSES.leave = false
		end).toThrow()
		expect(function()
			RaidLeaver.ERRORS.cooling = "open"
		end).toThrow()
	end)

	it("has no Robux price and no combat power", function()
		local banned =
			{ robux = true, productid = true, damage = true, health = true, attack = true }
		for key in pairs(RaidLeaver.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
			expect(type(RaidLeaver.CONFIG[key])).toEqual("number")
		end
	end)

	it("counts UTC days from the unix time it is given", function()
		expect(RaidLeaver.dayNumber(0)).toEqual(0)
		expect(RaidLeaver.dayNumber(86399)).toEqual(0)
		expect(RaidLeaver.dayNumber(86400)).toEqual(1)
		expect(RaidLeaver.dayNumber(-1)).toBeNil()
		expect(RaidLeaver.dayNumber(0 / 0)).toBeNil()
		expect(RaidLeaver.dayNumber(math.huge)).toBeNil()
	end)
end)

describe("RaidLeaver voluntary leaves", function()
	it("does not cool Finder before the third leave", function()
		local record = blank()
		local last = nil
		for _ = 1, 2 do
			last = RaidLeaver.depart(record, 1000, "leave")
			record = from(last)
		end
		expect(last).toEqual({
			ok = true,
			outcome = "counted",
			counted = true,
			finderBlocked = false,
			cooldownStarted = false,
			leaveDay = 0,
			leaveCount = 2,
			cooldownUntil = 0,
			rejoinUntil = 0,
			remainingSeconds = 0,
			missedWindow = false,
		})
	end)

	it("starts a 15-minute cooldown on the third leave", function()
		local record = row({ leaveCount = 2 })
		expect(RaidLeaver.depart(record, 1000, "leave")).toEqual({
			ok = true,
			outcome = "counted",
			counted = true,
			finderBlocked = true,
			cooldownStarted = true,
			leaveDay = 0,
			leaveCount = 3,
			cooldownUntil = 1900,
			rejoinUntil = 0,
			remainingSeconds = 900,
			missedWindow = false,
		})
	end)

	it("does not add time when they leave again during the cooldown", function()
		local again = RaidLeaver.depart(
			row({
				leaveCount = 3,
				cooldownUntil = 1900,
			}),
			1100,
			"leave"
		)
		expect(again.counted).toEqual(true)
		expect(again.leaveCount).toEqual(4)
		expect(again.cooldownStarted).toEqual(false)
		expect(again.cooldownUntil).toEqual(1900)
		expect(again.finderBlocked).toEqual(true)
		expect(again.remainingSeconds).toEqual(800)
		expect(again.outcome).toEqual("counted")
	end)

	it("starts another 15 minutes after the cooldown has ended", function()
		local later = RaidLeaver.depart(
			row({
				leaveCount = 3,
				cooldownUntil = 1900,
			}),
			1900,
			"leave"
		)
		expect(later.counted).toEqual(true)
		expect(later.leaveCount).toEqual(4)
		expect(later.cooldownStarted).toEqual(true)
		expect(later.cooldownUntil).toEqual(2800)
		expect(later.finderBlocked).toEqual(true)
		expect(later.remainingSeconds).toEqual(900)
	end)

	it("does not block Finder only because the count is already 3", function()
		local open = RaidLeaver.finder(
			row({
				leaveCount = 5,
				cooldownUntil = 1000,
			}),
			1000
		)
		expect(open.ok).toEqual(true)
		expect(open.outcome).toEqual("open")
		expect(open.finderBlocked).toEqual(false)
		expect(open.counted).toEqual(false)
		expect(open.leaveCount).toEqual(5)
		expect(open.cooldownStarted).toEqual(false)
		expect(open.remainingSeconds).toEqual(0)
	end)

	it("resets the count on the next UTC day", function()
		local second = RaidLeaver.depart(row({ leaveCount = 1 }), 86399, "leave")
		expect(second.leaveDay).toEqual(0)
		expect(second.leaveCount).toEqual(2)
		expect(second.finderBlocked).toEqual(false)
		local nextDay = RaidLeaver.depart(from(second), 86400, "leave")
		expect(nextDay.leaveDay).toEqual(1)
		expect(nextDay.leaveCount).toEqual(1)
		expect(nextDay.cooldownStarted).toEqual(false)
		expect(nextDay.finderBlocked).toEqual(false)
		expect(nextDay.cooldownUntil).toEqual(0)
	end)

	it("keeps blocking Finder after midnight until the cooldown ends", function()
		local gate = RaidLeaver.finder(
			row({
				leaveDay = 0,
				leaveCount = 3,
				cooldownUntil = 86900,
			}),
			86400
		)
		expect(gate).toEqual({
			ok = true,
			outcome = "cooling",
			counted = false,
			finderBlocked = true,
			cooldownStarted = false,
			leaveDay = 1,
			leaveCount = 0,
			cooldownUntil = 86900,
			rejoinUntil = 0,
			remainingSeconds = 500,
			missedWindow = false,
			error = ERRORS.cooling,
		})
	end)

	it("counts one leave when they walk away during an open window", function()
		local walked = RaidLeaver.depart(
			row({
				leaveCount = 1,
				rejoinUntil = 1500,
			}),
			1000,
			"leave"
		)
		expect(walked.outcome).toEqual("counted")
		expect(walked.counted).toEqual(true)
		expect(walked.leaveCount).toEqual(2)
		expect(walked.rejoinUntil).toEqual(0)
		expect(walked.cooldownStarted).toEqual(false)
		expect(walked.finderBlocked).toEqual(false)
	end)
end)

describe("RaidLeaver disconnect window", function()
	it("opens a 3-minute window and does not count the disconnect", function()
		expect(RaidLeaver.depart(blank(), 1000, "disconnect")).toEqual({
			ok = true,
			outcome = "window",
			counted = false,
			finderBlocked = false,
			cooldownStarted = false,
			leaveDay = 0,
			leaveCount = 0,
			cooldownUntil = 0,
			rejoinUntil = 1180,
			remainingSeconds = 0,
			missedWindow = false,
		})
	end)

	it("does not extend a window that is already open", function()
		local again = RaidLeaver.depart(row({ rejoinUntil = 1180 }), 1100, "disconnect")
		expect(again.counted).toEqual(false)
		expect(again.outcome).toEqual("window")
		expect(again.rejoinUntil).toEqual(1180)
		expect(again.leaveCount).toEqual(0)
		expect(again.cooldownStarted).toEqual(false)
	end)

	it("keeps the same deadline when the day rolls during the window", function()
		local opened = RaidLeaver.depart(row({ leaveCount = 2 }), 86300, "disconnect")
		expect(opened.leaveDay).toEqual(0)
		expect(opened.leaveCount).toEqual(2)
		expect(opened.counted).toEqual(false)
		expect(opened.rejoinUntil).toEqual(86480)
		local held = RaidLeaver.depart(from(opened), 86410, "disconnect")
		expect(held.counted).toEqual(false)
		expect(held.leaveDay).toEqual(1)
		expect(held.leaveCount).toEqual(0)
		expect(held.rejoinUntil).toEqual(86480)
		expect(held.cooldownStarted).toEqual(false)
	end)

	it("treats a rejoin at the deadline as not a leave", function()
		local back = RaidLeaver.rejoin(row({ rejoinUntil = 1180, leaveCount = 1 }), 1180)
		expect(back).toEqual({
			ok = true,
			outcome = "cleared",
			counted = false,
			finderBlocked = false,
			cooldownStarted = false,
			leaveDay = 0,
			leaveCount = 1,
			cooldownUntil = 0,
			rejoinUntil = 0,
			remainingSeconds = 0,
			missedWindow = false,
		})
	end)

	it("counts a rejoin after the deadline as one leave", function()
		local late = RaidLeaver.rejoin(row({ rejoinUntil = 1180, leaveCount = 1 }), 1181)
		expect(late.ok).toEqual(true)
		expect(late.outcome).toEqual("counted")
		expect(late.counted).toEqual(true)
		expect(late.leaveCount).toEqual(2)
		expect(late.rejoinUntil).toEqual(0)
		expect(late.cooldownStarted).toEqual(false)
		expect(late.finderBlocked).toEqual(false)
	end)

	it("lets them rejoin the same run while Finder is still cooling", function()
		local back = RaidLeaver.rejoin(
			row({
				leaveCount = 3,
				cooldownUntil = 5000,
				rejoinUntil = 1200,
			}),
			1100
		)
		expect(back.outcome).toEqual("cleared")
		expect(back.counted).toEqual(false)
		expect(back.leaveCount).toEqual(3)
		expect(back.cooldownUntil).toEqual(5000)
		expect(back.cooldownStarted).toEqual(false)
		expect(back.rejoinUntil).toEqual(0)
		expect(back.finderBlocked).toEqual(true)
		expect(back.remainingSeconds).toEqual(3900)
	end)

	it("waits out an open window without counting", function()
		local waiting = RaidLeaver.resolve(row({ rejoinUntil = 1180, leaveCount = 2 }), 1180)
		expect(waiting.ok).toEqual(true)
		expect(waiting.outcome).toEqual("window")
		expect(waiting.counted).toEqual(false)
		expect(waiting.leaveCount).toEqual(2)
		expect(waiting.rejoinUntil).toEqual(1180)
		expect(waiting.cooldownStarted).toEqual(false)
		expect(waiting.missedWindow).toEqual(false)
	end)

	it("counts a missed window once", function()
		local missed = RaidLeaver.resolve(row({ rejoinUntil = 1180, leaveCount = 2 }), 1181)
		expect(missed.outcome).toEqual("counted")
		expect(missed.counted).toEqual(true)
		expect(missed.leaveCount).toEqual(3)
		expect(missed.rejoinUntil).toEqual(0)
		expect(missed.cooldownStarted).toEqual(true)
		expect(missed.cooldownUntil).toEqual(2081)
		expect(missed.finderBlocked).toEqual(true)
		expect(missed.remainingSeconds).toEqual(900)
		local again = RaidLeaver.resolve(from(missed), 1182)
		expect(again.outcome).toEqual("ignored")
		expect(again.counted).toEqual(false)
		expect(again.leaveCount).toEqual(3)
		expect(again.cooldownUntil).toEqual(2081)
		expect(again.cooldownStarted).toEqual(false)
	end)

	it("does not extend the cooldown when a later miss lands inside it", function()
		local missed = RaidLeaver.resolve(
			row({
				leaveCount = 3,
				cooldownUntil = 2000,
				rejoinUntil = 100,
			}),
			1500
		)
		expect(missed.counted).toEqual(true)
		expect(missed.leaveCount).toEqual(4)
		expect(missed.cooldownStarted).toEqual(false)
		expect(missed.cooldownUntil).toEqual(2000)
		expect(missed.remainingSeconds).toEqual(500)
		expect(missed.rejoinUntil).toEqual(0)
		expect(missed.finderBlocked).toEqual(true)
	end)

	it("counts the miss on the day resolve runs, not the disconnect day", function()
		local opened = RaidLeaver.depart(row({ leaveCount = 2 }), 86300, "disconnect")
		expect(opened.rejoinUntil).toEqual(86480)
		local missed = RaidLeaver.resolve(from(opened), 86481)
		expect(missed.counted).toEqual(true)
		expect(missed.leaveDay).toEqual(1)
		expect(missed.leaveCount).toEqual(1)
		expect(missed.cooldownStarted).toEqual(false)
		expect(missed.finderBlocked).toEqual(false)
	end)

	it("counts a missed window and opens a new one on the next disconnect", function()
		local nextWindow = RaidLeaver.depart(
			row({
				leaveCount = 1,
				rejoinUntil = 100,
			}),
			200,
			"disconnect"
		)
		expect(nextWindow.outcome).toEqual("window")
		expect(nextWindow.counted).toEqual(true)
		expect(nextWindow.leaveCount).toEqual(2)
		expect(nextWindow.rejoinUntil).toEqual(380)
		expect(nextWindow.cooldownStarted).toEqual(false)
		expect(nextWindow.missedWindow).toEqual(false)
		local stillOpen = RaidLeaver.resolve(from(nextWindow), 380)
		expect(stillOpen.counted).toEqual(false)
		expect(stillOpen.leaveCount).toEqual(2)
		expect(stillOpen.outcome).toEqual("window")
	end)

	it("reaches the cooldown after three missed disconnects", function()
		local record = blank()
		for index = 1, 3 do
			local opened = RaidLeaver.depart(record, 1000 + (index - 1) * 1000, "disconnect")
			expect(opened.counted).toEqual(false)
			expect(opened.leaveCount).toEqual(index - 1)
			local missed = RaidLeaver.resolve(from(opened), opened.rejoinUntil + 1)
			expect(missed.counted).toEqual(true)
			expect(missed.leaveCount).toEqual(index)
			record = from(missed)
		end
		expect(record.leaveCount).toEqual(3)
		expect(record.cooldownUntil).toEqual(4081)
		expect(RaidLeaver.finder(record, 4080).finderBlocked).toEqual(true)
		expect(RaidLeaver.finder(record, 4080).outcome).toEqual("cooling")
		expect(RaidLeaver.finder(record, 4081).finderBlocked).toEqual(false)
		expect(RaidLeaver.finder(record, 4081).outcome).toEqual("open")
	end)

	it("reports a missed window from finder without counting it", function()
		local gate = RaidLeaver.finder(
			row({
				leaveCount = 1,
				rejoinUntil = 50,
			}),
			51
		)
		expect(gate.ok).toEqual(true)
		expect(gate.outcome).toEqual("open")
		expect(gate.counted).toEqual(false)
		expect(gate.missedWindow).toEqual(true)
		expect(gate.leaveCount).toEqual(1)
		expect(gate.rejoinUntil).toEqual(50)
		expect(gate.finderBlocked).toEqual(false)
	end)

	it("reports both a missed window and an active cooldown", function()
		local gate = RaidLeaver.finder(
			row({
				leaveCount = 3,
				cooldownUntil = 2000,
				rejoinUntil = 100,
			}),
			1500
		)
		expect(gate.outcome).toEqual("cooling")
		expect(gate.finderBlocked).toEqual(true)
		expect(gate.missedWindow).toEqual(true)
		expect(gate.counted).toEqual(false)
		expect(gate.remainingSeconds).toEqual(500)
		expect(gate.rejoinUntil).toEqual(100)
		expect(gate.error).toEqual(ERRORS.cooling)
	end)

	it("ignores a rejoin when no window is open", function()
		local quiet = RaidLeaver.rejoin(row({ leaveCount = 2 }), 1000)
		expect(quiet.outcome).toEqual("ignored")
		expect(quiet.counted).toEqual(false)
		expect(quiet.leaveCount).toEqual(2)
		expect(quiet.rejoinUntil).toEqual(0)
		expect(quiet.finderBlocked).toEqual(false)
	end)
end)

describe("RaidLeaver removals that are not leaves", function()
	it("does not count an AFK removal", function()
		local removed = RaidLeaver.depart(
			row({
				leaveCount = 2,
				rejoinUntil = 500,
			}),
			1000,
			"afk"
		)
		expect(removed).toEqual({
			ok = true,
			outcome = "ignored",
			counted = false,
			finderBlocked = false,
			cooldownStarted = false,
			leaveDay = 0,
			leaveCount = 2,
			cooldownUntil = 0,
			rejoinUntil = 0,
			remainingSeconds = 0,
			missedWindow = false,
		})
	end)

	it("does not count a passed vote-kick", function()
		local kicked = RaidLeaver.depart(
			row({
				leaveCount = 2,
				rejoinUntil = 500,
			}),
			1000,
			"kick"
		)
		expect(kicked.outcome).toEqual("ignored")
		expect(kicked.counted).toEqual(false)
		expect(kicked.leaveCount).toEqual(2)
		expect(kicked.rejoinUntil).toEqual(0)
		expect(kicked.cooldownStarted).toEqual(false)
		expect(kicked.finderBlocked).toEqual(false)
	end)

	it("clears an expired disconnect when the removal was AFK or a kick", function()
		for _, cause in ipairs({ "afk", "kick" }) do
			local cleared = RaidLeaver.depart(
				row({
					leaveCount = 2,
					rejoinUntil = 100,
				}),
				1000,
				cause
			)
			expect(cleared.counted).toEqual(false)
			expect(cleared.leaveCount).toEqual(2)
			expect(cleared.rejoinUntil).toEqual(0)
			expect(cleared.cooldownStarted).toEqual(false)
			local later = RaidLeaver.resolve(from(cleared), 1001)
			expect(later.counted).toEqual(false)
			expect(later.leaveCount).toEqual(2)
			expect(later.outcome).toEqual("ignored")
		end
	end)
end)

describe("RaidLeaver records", function()
	it("does not write the record it was given", function()
		local frozen = table.freeze({
			leaveDay = 0,
			leaveCount = 2,
			cooldownUntil = 0,
			rejoinUntil = 400,
		})
		local third = RaidLeaver.depart(frozen, 1000, "leave")
		expect(third.leaveCount).toEqual(3)
		expect(third.cooldownStarted).toEqual(true)
		expect(frozen.leaveCount).toEqual(2)
		expect(frozen.rejoinUntil).toEqual(400)
		expect(frozen.cooldownUntil).toEqual(0)
		local gate = RaidLeaver.finder(frozen, 1000)
		expect(gate.leaveCount).toEqual(2)
		expect(frozen.leaveCount).toEqual(2)
	end)

	it("treats a nil record as a fresh player", function()
		expect(RaidLeaver.depart(nil, 1000, "leave")).toEqual({
			ok = true,
			outcome = "counted",
			counted = true,
			finderBlocked = false,
			cooldownStarted = false,
			leaveDay = 0,
			leaveCount = 1,
			cooldownUntil = 0,
			rejoinUntil = 0,
			remainingSeconds = 0,
			missedWindow = false,
		})
		expect(RaidLeaver.finder(nil, 1000)).toEqual({
			ok = true,
			outcome = "open",
			counted = false,
			finderBlocked = false,
			cooldownStarted = false,
			leaveDay = 0,
			leaveCount = 0,
			cooldownUntil = 0,
			rejoinUntil = 0,
			remainingSeconds = 0,
			missedWindow = false,
		})
	end)

	it("treats a negative count as zero leaves", function()
		local fixed = RaidLeaver.depart(
			row({
				leaveCount = -3,
				cooldownUntil = -10,
				rejoinUntil = -1,
			}),
			1000,
			"leave"
		)
		expect(fixed.ok).toEqual(true)
		expect(fixed.counted).toEqual(true)
		expect(fixed.leaveCount).toEqual(1)
		expect(fixed.cooldownUntil).toEqual(0)
		expect(fixed.rejoinUntil).toEqual(0)
		expect(fixed.finderBlocked).toEqual(false)
		expect(fixed.cooldownStarted).toEqual(false)
	end)

	it("floors a fractional count before it decides the cooldown", function()
		local third = RaidLeaver.depart(row({ leaveCount = 2.9 }), 1000, "leave")
		expect(third.leaveCount).toEqual(3)
		expect(third.cooldownStarted).toEqual(true)
		expect(third.cooldownUntil).toEqual(1900)
		expect(third.finderBlocked).toEqual(true)
	end)

	it("refuses a missing clock instead of counting a leave", function()
		local missing = RaidLeaver.depart(nil, nil :: any, "leave")
		expect(missing.ok).toEqual(false)
		expect(missing.outcome).toEqual("invalid")
		expect(missing.counted).toEqual(false)
		expect(missing.finderBlocked).toEqual(true)
		expect(missing.cooldownStarted).toEqual(false)
		expect(missing.error).toEqual(ERRORS.time)
		local echoed = RaidLeaver.depart(
			row({
				leaveDay = 4,
				leaveCount = 2,
				cooldownUntil = 50,
				rejoinUntil = 10,
			}),
			-5,
			"leave"
		)
		expect(echoed.ok).toEqual(false)
		expect(echoed.counted).toEqual(false)
		expect(echoed.finderBlocked).toEqual(true)
		expect(echoed.leaveDay).toEqual(4)
		expect(echoed.leaveCount).toEqual(2)
		expect(echoed.cooldownUntil).toEqual(50)
		expect(echoed.rejoinUntil).toEqual(10)
		expect(echoed.error).toEqual(ERRORS.time)
		expect(RaidLeaver.finder(blank(), 0 / 0).error).toEqual(ERRORS.time)
		expect(RaidLeaver.finder(blank(), math.huge).finderBlocked).toEqual(true)
		expect(RaidLeaver.resolve(blank(), -1).counted).toEqual(false)
		expect(RaidLeaver.rejoin(blank(), "1000" :: any).ok).toEqual(false)
	end)

	it("refuses an unknown cause instead of forgiving the window", function()
		local bad = RaidLeaver.depart(
			row({
				leaveCount = 2,
				rejoinUntil = 400,
			}),
			1000,
			"vote"
		)
		expect(bad.ok).toEqual(false)
		expect(bad.outcome).toEqual("invalid")
		expect(bad.counted).toEqual(false)
		expect(bad.leaveCount).toEqual(2)
		expect(bad.rejoinUntil).toEqual(400)
		expect(bad.finderBlocked).toEqual(false)
		expect(bad.cooldownStarted).toEqual(false)
		expect(bad.error).toEqual(ERRORS.cause)
		expect(RaidLeaver.depart(row({ leaveCount = 2 }), 1000, "AFK").ok).toEqual(false)
		expect(RaidLeaver.depart(row({ leaveCount = 2 }), 1000, "Leave").counted).toEqual(false)
		expect(RaidLeaver.depart(row({ leaveCount = 2 }), 1000, "").error).toEqual(ERRORS.cause)
		expect(RaidLeaver.depart(row({ leaveCount = 2 }), 1000, nil).counted).toEqual(false)
	end)

	it("fails closed on a corrupt record and does not increment", function()
		local corrupt = RaidLeaver.depart(row({ leaveCount = 0 / 0 }), 1000, "leave")
		expect(corrupt.ok).toEqual(false)
		expect(corrupt.outcome).toEqual("invalid")
		expect(corrupt.counted).toEqual(false)
		expect(corrupt.finderBlocked).toEqual(true)
		expect(corrupt.leaveCount).toEqual(0)
		expect(corrupt.cooldownStarted).toEqual(false)
		expect(corrupt.error).toEqual(ERRORS.record)
		expect(RaidLeaver.finder(row({ cooldownUntil = math.huge }), 1000).ok).toEqual(false)
		expect(RaidLeaver.finder(row({ cooldownUntil = math.huge }), 1000).finderBlocked).toEqual(
			true
		)
		expect(RaidLeaver.finder(4 :: any, 1000).error).toEqual(ERRORS.record)
		expect(RaidLeaver.resolve(row({ rejoinUntil = 0 / 0 }), 1000).counted).toEqual(false)
		expect(RaidLeaver.rejoin(row({ leaveDay = 0 / 0 }), 1000).finderBlocked).toEqual(true)
	end)
end)
