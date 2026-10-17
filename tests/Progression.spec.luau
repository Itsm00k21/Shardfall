--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Progression = require("../src/ReplicatedStorage/Shared/Progression")
local SessionRecap =
	require("../src/StarterPlayer/StarterPlayerScripts/ShardfallClient/SessionRecap")

describe("Progression", function()
	it("uses the 1.6 curve and stops at level 20", function()
		expect(Progression.xpToNext(1)).toEqual(100)
		expect(Progression.xpToNext(3)).toEqual(math.floor(100 * (3 ^ 1.6) + 0.5))
		expect(Progression.xpToNext(20)).toEqual(0)
		local data = { level = 19, xp = 0, chests = {} }
		local need = Progression.xpToNext(19)
		Progression.addXp(data, need)
		expect(data.level).toEqual(20)
		expect(data.xp).toEqual(0)
		expect(data.chests.Rare).toEqual(1)
		Progression.addXp(data, 5000)
		expect(data.level).toEqual(20)
	end)

	it("keeps mastery at 0 through the beta cap", function()
		expect(Progression.mastery(2)).toEqual(0)
		expect(Progression.mastery(Progression.CAP)).toEqual(0)
	end)

	it("caps stacked XP boosts at +100% and welcomes a long absence", function()
		expect(Progression.boost({ 1, 1, 0.25 })).toEqual(2)
		local rested = { level = 1, xp = 0, restCharges = 2, welcomeCharges = 2, chests = {} }
		Progression.addXp(rested, 10)
		expect(rested.xp).toEqual(20)
		expect(rested.restCharges).toEqual(1)
		local data = { level = 4, xp = 0, lastSeen = 1, chests = {} }
		local back = Progression.applyReturn(data, Progression.WELCOME_GAP + 10)
		expect(back.welcome).toEqual(true)
		expect(back.rest).toEqual(true)
		expect(data.chests.Rare).toEqual(1)
		expect(Progression.recap(1, 4, 2, 41)).toEqual(
			"This session: +3 levels, 2 Epics, 41% to your Relic Set"
		)
		expect(Progression.unlocked(10)[4]).toEqual("hard")
	end)
end)

describe("Session recap", function()
	it("matches Progression.recap when every clause is plural and present", function()
		local line = SessionRecap.line(1, 4, 2, 41)
		expect(line).toEqual("This session: +3 levels, 2 Epics, 41% to your Relic Set")
		expect(line).toEqual(Progression.recap(1, 4, 2, 41))
		expect(#line <= SessionRecap.MAX_CHARS).toEqual(true)
		expect(string.find(line, "\n", 1, true)).toBeNil()
	end)

	it("uses the same sentence from a recap table and ignores clear-only fields", function()
		expect(SessionRecap.line({
			beforeLevel = 1,
			afterLevel = 4,
			epics = 2,
			setPct = 41,
			levels = 99,
			gold = 10,
		})).toEqual(Progression.recap(1, 4, 2, 41))
	end)

	it("pluralizes a single level and a single Epic", function()
		expect(SessionRecap.line(1, 2, 1, 140)).toEqual(
			"This session: +1 level, 1 Epic, 100% to your Relic Set"
		)
	end)

	it("drops missing and zero clauses", function()
		expect(SessionRecap.line({ beforeLevel = 1, afterLevel = 4 })).toEqual(
			"This session: +3 levels"
		)
		expect(SessionRecap.line({ afterLevel = 6, epics = 2 })).toEqual("This session: 2 Epics")
		expect(SessionRecap.line({ setPct = 41 })).toEqual("This session: 41% to your Relic Set")
		expect(SessionRecap.line({ beforeLevel = 4, afterLevel = 4, epics = 2, setPct = 0 })).toEqual(
			"This session: 2 Epics"
		)
	end)

	it("stays quiet when every supplied field is zero", function()
		expect(SessionRecap.line({ beforeLevel = 4, afterLevel = 4, epics = 0, setPct = 0 })).toEqual(
			"This session: a quiet clear."
		)
		expect(SessionRecap.line(4, 3, -2, -10)).toEqual("This session: a quiet clear.")
	end)

	it("returns an empty string when there is nothing to format", function()
		expect(SessionRecap.line(nil)).toEqual("")
		expect(SessionRecap.line({})).toEqual("")
		expect(SessionRecap.line("nope")).toEqual("")
		expect(SessionRecap.line({ beforeLevel = 1 })).toEqual("")
		expect(SessionRecap.line({ epics = "2", setPct = "41" })).toEqual("")
		local blank = SessionRecap.line(nil)
		expect(string.find(blank, "nil", 1, true)).toBeNil()
	end)

	it("ignores NaN and infinity and floors fractional counts", function()
		expect(SessionRecap.line({
			beforeLevel = 0 / 0,
			afterLevel = 4,
			epics = 2,
			setPct = math.huge,
		})).toEqual("This session: 2 Epics")
		expect(SessionRecap.line(1.9, 4.2, 1.8, 41.9)).toEqual(
			"This session: +3 levels, 1 Epic, 41% to your Relic Set"
		)
	end)

	it("shortens a huge line so it still fits the card", function()
		local line = SessionRecap.line({
			beforeLevel = 0,
			afterLevel = 100000,
			epics = 100000,
			setPct = 250,
		})
		expect(line).toEqual("This session: +9999 levels, 999+ Epics, 100% Relic Set")
		expect(#line <= SessionRecap.MAX_CHARS).toEqual(true)
		expect(string.find(line, "nil", 1, true)).toBeNil()
		expect(string.find(line, "to your", 1, true)).toBeNil()
	end)
end)
