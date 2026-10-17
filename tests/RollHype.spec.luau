--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RollBoard = require("../src/ReplicatedStorage/Shared/RollBoard")
local RollHype = require("../src/ReplicatedStorage/Shared/RollHype")
local RollLoop = require("../src/ReplicatedStorage/Shared/RollLoop")

local ERRORS = RollHype.ERRORS

local function identical(left: any, right: any): boolean
	return left == right
end

local function opened(): any
	local result = RollHype.fresh(nil)
	expect(result.ok).toEqual(true)
	return result.state
end

local function keysOf(value: { [string]: any }): { [string]: boolean }
	local found: { [string]: boolean } = {}
	for key in pairs(value) do
		found[key] = true
	end
	return found
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

local function requiresHype(source: string): boolean
	if string.find(source, "Shared.RollHype", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RollHype", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RollHype", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RollHype")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('RollHype')", 1, true) ~= nil then
		return true
	end
	return false
end

describe("RollHype config", function()
	it("pins the four session milestones", function()
		expect(RollHype.CONFIG.milestones).toEqual({ 10, 25, 50, 100 })
	end)

	it("gives every ladder rarity a longer build-up than the one below it", function()
		local previous = 0
		for index, name in ipairs(Rarities.ORDER) do
			local seconds = RollHype.CONFIG.buildUp[name]
			expect(type(seconds)).toEqual("number")
			expect(seconds).toBeGreaterThan(previous)
			expect(RollHype.tempo(name).tier).toEqual(index)
			expect(RollHype.tempo(name).tier).toEqual(Rarities.INDEX[name])
			previous = seconds
		end
		expect(RollHype.CONFIG.buildUp.Common).toEqual(0.45)
		expect(RollHype.CONFIG.buildUp.Uncommon).toEqual(0.6)
		expect(RollHype.CONFIG.buildUp.Rare).toEqual(0.9)
		expect(RollHype.CONFIG.buildUp.Epic).toEqual(1.2)
		expect(RollHype.CONFIG.buildUp.Legendary).toEqual(1.65)
		expect(RollHype.CONFIG.buildUp.Mythic).toEqual(2.4)
		expect(RollHype.CONFIG.buildUp.Secret).toEqual(3)
	end)

	it("freezes the thresholds and the errors", function()
		expect(function()
			RollHype.CONFIG.milestones = {}
		end).toThrow()
		expect(function()
			RollHype.CONFIG.buildUp.Common = 9
		end).toThrow()
		expect(function()
			RollHype.ERRORS.rarity = "nope"
		end).toThrow()
	end)
end)

describe("RollHype session", function()
	it("starts at zero with no best and no personal best", function()
		local result = RollHype.fresh(nil)
		expect(result.ok).toEqual(true)
		expect(result.state).toEqual({
			rolls = 0,
			streak = 0,
			best = nil,
			personalBest = false,
			allTime = nil,
		})
		expect(RollHype.fresh("").state.allTime).toBeNil()
		expect(identical(result.state, RollHype.fresh(nil).state)).toEqual(false)
	end)

	it("keeps a caller-supplied all-time best and refuses an unknown one", function()
		local kept = RollHype.fresh("Legendary")
		expect(kept.ok).toEqual(true)
		expect(kept.state.allTime).toEqual("Legendary")
		expect(kept.state.rolls).toEqual(0)
		expect(kept.state.personalBest).toEqual(false)

		local bad = RollHype.fresh("epic")
		expect(bad.ok).toEqual(false)
		expect(bad.error).toEqual(ERRORS.allTime)
		expect(bad.state.rolls).toEqual(0)
		expect(bad.state.allTime).toBeNil()
		expect(RollHype.fresh(1).error).toEqual(ERRORS.allTime)
		expect(RollHype.fresh({}).error).toEqual(ERRORS.allTime)
	end)

	it("counts a landed roll and follows RollLoop streak", function()
		local streak = 0
		local state = opened()
		local rolls = 0
		for _, landed in ipairs({ true, true, false, true }) do
			streak = RollLoop.streak(streak, landed)
			local noted = RollHype.note(
				state,
				if landed then { rarity = "Common" } else { landed = false, rarity = "Mythic" }
			)
			expect(noted.ok).toEqual(true)
			expect(noted.state.streak).toEqual(streak)
			if landed then
				rolls += 1
				expect(noted.rarity).toEqual("Common")
			else
				expect(noted.rarity).toBeNil()
				expect(noted.state.best).toEqual("Common")
			end
			expect(noted.state.rolls).toEqual(rolls)
			state = noted.state
		end
		expect(state.streak).toEqual(1)
		expect(state.rolls).toEqual(3)
	end)

	it("tracks the best rarity actually landed", function()
		local state = opened()
		local first = RollHype.note(state, { rarity = "Common" })
		expect(first.raisedBest).toEqual(true)
		expect(first.state.best).toEqual("Common")
		local rare = RollHype.note(first.state, { rarity = "Rare" })
		expect(rare.raisedBest).toEqual(true)
		expect(rare.rarity).toEqual("Rare")
		expect(rare.state.best).toEqual("Rare")
		local back = RollHype.note(rare.state, { rarity = "Uncommon" })
		expect(back.ok).toEqual(true)
		expect(back.raisedBest).toEqual(false)
		expect(back.rarity).toEqual("Uncommon")
		expect(back.state.best).toEqual("Rare")
		expect(back.best).toEqual("Rare")
	end)

	it("flags a strict all-time best and leaves a tie alone", function()
		local state = RollHype.fresh("Rare").state
		local lower = RollHype.note(state, { rarity = "Common" })
		expect(lower.newPersonalBest).toEqual(false)
		expect(lower.state.personalBest).toEqual(false)
		expect(lower.state.allTime).toEqual("Rare")

		local tied = RollHype.note(lower.state, { rarity = "Rare" })
		expect(tied.newPersonalBest).toEqual(false)
		expect(tied.state.personalBest).toEqual(false)
		expect(tied.state.allTime).toEqual("Rare")
		expect(tied.state.best).toEqual("Rare")

		local higher = RollHype.note(tied.state, { rarity = "Epic" })
		expect(higher.newPersonalBest).toEqual(true)
		expect(higher.personalBest).toEqual(true)
		expect(higher.state.personalBest).toEqual(true)
		expect(higher.state.allTime).toEqual("Epic")
		expect(higher.rarity).toEqual("Epic")

		local again = RollHype.note(higher.state, { rarity = "Epic" })
		expect(again.newPersonalBest).toEqual(false)
		expect(again.state.personalBest).toEqual(true)
		expect(again.state.allTime).toEqual("Epic")

		local mythic = RollHype.note(again.state, { rarity = "Mythic" })
		expect(mythic.newPersonalBest).toEqual(true)
		expect(mythic.state.allTime).toEqual("Mythic")
	end)

	it("treats the first landed roll as a personal best when none is on file", function()
		local noted = RollHype.note(opened(), { rarity = "Uncommon" })
		expect(noted.ok).toEqual(true)
		expect(noted.newPersonalBest).toEqual(true)
		expect(noted.state.personalBest).toEqual(true)
		expect(noted.state.allTime).toEqual("Uncommon")
		expect(noted.state.best).toEqual("Uncommon")
	end)

	it("keeps the higher all-time record when the note carries a second one", function()
		local state = RollHype.fresh("Rare").state
		local noted = RollHype.note(state, { rarity = "Epic", allTime = "Legendary" })
		expect(noted.ok).toEqual(true)
		expect(noted.newPersonalBest).toEqual(false)
		expect(noted.state.personalBest).toEqual(false)
		expect(noted.state.best).toEqual("Epic")
		expect(noted.state.allTime).toEqual("Legendary")

		local beaten = RollHype.note(noted.state, { rarity = "Secret", allTime = "Common" })
		expect(beaten.newPersonalBest).toEqual(true)
		expect(beaten.state.allTime).toEqual("Secret")
		expect(beaten.rarity).toEqual("Secret")
	end)

	it("calls out 10, 25, 50, and 100 without naming a rarity", function()
		local state = opened()
		local seen: { [number]: string } = {}
		for _ = 1, 100 do
			local noted = RollHype.note(state, { rarity = "Common", paid = true })
			expect(noted.ok).toEqual(true)
			if noted.milestone ~= nil and noted.callout ~= nil then
				seen[noted.milestone] = noted.callout
				for _, name in ipairs(Rarities.ORDER) do
					expect(string.find(noted.callout, name, 1, true)).toBeNil()
				end
			end
			state = noted.state
		end
		expect(seen).toEqual({
			[10] = "10 rolls",
			[25] = "25 rolls",
			[50] = "50 rolls",
			[100] = "100 rolls",
		})
		local extra = RollHype.note(state, { rarity = "Common" })
		expect(extra.milestone).toBeNil()
		expect(extra.callout).toBeNil()
		expect(extra.state.rolls).toEqual(101)
	end)

	it("does not repeat a milestone on the next roll", function()
		local state = opened()
		for _ = 1, 9 do
			state = RollHype.note(state, { rarity = "Common" }).state
		end
		local tenth = RollHype.note(state, { rarity = "Rare" })
		expect(tenth.milestone).toEqual(10)
		expect(tenth.callout).toEqual("10 rolls")
		expect(tenth.rarity).toEqual("Rare")
		local eleventh = RollHype.note(tenth.state, { rarity = "Rare" })
		expect(eleventh.milestone).toBeNil()
		expect(eleventh.callout).toBeNil()
	end)

	it("uses the same session numbers for a paid roll and a free roll", function()
		local state = RollHype.fresh("Epic").state
		local free = RollHype.note(state, { rarity = "Rare", paid = false })
		local paid = RollHype.note(state, { rarity = "Rare", paid = true })
		local omitted = RollHype.note(state, { rarity = "Rare" })
		expect(paid).toEqual(free)
		expect(omitted).toEqual(free)
		expect(paid.state.rolls).toEqual(1)
		expect(paid.state.streak).toEqual(1)
		expect(paid.rarity).toEqual("Rare")
		expect(paid.newPersonalBest).toEqual(false)
	end)

	it("does not take a rarity from a roll that did not land", function()
		local state = RollHype.note(opened(), { rarity = "Rare" }).state
		local before = {
			rolls = state.rolls,
			streak = state.streak,
			best = state.best,
			personalBest = state.personalBest,
			allTime = state.allTime,
		}
		local missed = RollHype.note(state, { landed = false, rarity = "Secret", paid = true })
		expect(missed.ok).toEqual(true)
		expect(missed.rarity).toBeNil()
		expect(missed.newPersonalBest).toEqual(false)
		expect(missed.raisedBest).toEqual(false)
		expect(missed.milestone).toBeNil()
		expect(missed.state.best).toEqual("Rare")
		expect(missed.state.rolls).toEqual(before.rolls)
		expect(missed.state.streak).toEqual(0)
		expect(missed.state.personalBest).toEqual(before.personalBest)
		expect(missed.state.allTime).toEqual(before.allTime)
		expect(state.streak).toEqual(before.streak)
	end)

	it("refuses an unknown rarity and leaves the session alone", function()
		local state = opened()
		local noted = RollHype.note(state, { rarity = "epic" })
		expect(noted.ok).toEqual(false)
		expect(noted.error).toEqual(ERRORS.rarity)
		expect(noted.rarity).toBeNil()
		expect(noted.state.rolls).toEqual(0)
		expect(noted.state.best).toBeNil()
		expect(state.rolls).toEqual(0)
		expect(RollHype.note(state, { rarity = "" }).error).toEqual(ERRORS.rarity)
		expect(RollHype.note(state, { rarity = "Legendary " }).error).toEqual(ERRORS.rarity)
		expect(RollHype.note(state, { landed = true }).error).toEqual(ERRORS.rarity)
		expect(RollHype.note(state, {}).error).toEqual(ERRORS.rarity)
	end)

	it("refuses a bad note or a bad session without throwing", function()
		local state = opened()
		expect(RollHype.note(nil, { rarity = "Common" }).error).toEqual(ERRORS.state)
		expect(RollHype.note(state, nil).error).toEqual(ERRORS.roll)
		expect(RollHype.note(state, "Epic").error).toEqual(ERRORS.roll)
		expect(RollHype.note(state, { landed = "yes", rarity = "Common" }).error).toEqual(
			ERRORS.roll
		)
		expect(RollHype.note(state, { rarity = "Common", allTime = "nope" }).error).toEqual(
			ERRORS.allTime
		)
		expect(state.rolls).toEqual(0)

		local fraction = {
			rolls = 1.5,
			streak = 1,
			best = "Common",
			personalBest = false,
			allTime = "Common",
		}
		expect(RollHype.note(fraction, { rarity = "Common" }).error).toEqual(ERRORS.state)
		local ahead = {
			rolls = 1,
			streak = 2,
			best = "Common",
			personalBest = true,
			allTime = "Common",
		}
		expect(RollHype.note(ahead, { rarity = "Common" }).error).toEqual(ERRORS.disagree)
		local emptyBest = {
			rolls = 0,
			streak = 0,
			best = "Common",
			personalBest = false,
			allTime = "Common",
		}
		expect(RollHype.note(emptyBest, { rarity = "Common" }).error).toEqual(ERRORS.disagree)
	end)

	it("drops a stuffed near-miss and returns a new table", function()
		local state = opened()
		state.nearMiss = "Mythic"
		state.almost = "Secret"
		local noted = RollHype.note(state, { rarity = "Common" })
		expect(noted.ok).toEqual(true)
		expect(noted.state.nearMiss).toBeNil()
		expect(noted.state.almost).toBeNil()
		expect(noted.nearMiss).toBeNil()
		expect(noted.tease).toBeNil()
		expect(noted.nextRarity).toBeNil()
		expect(state.nearMiss).toEqual("Mythic")
		expect(identical(noted.state, state)).toEqual(false)
		expect(state.rolls).toEqual(0)
		expect(state.best).toBeNil()
	end)

	it("does not write a frozen session", function()
		local state = opened()
		table.freeze(state)
		local noted = RollHype.note(state, { rarity = "Epic", paid = true })
		expect(noted.ok).toEqual(true)
		expect(noted.state.rolls).toEqual(1)
		expect(state.rolls).toEqual(0)
		local again = RollHype.note(noted.state, { rarity = "Epic" })
		expect(again.state).toEqual(RollHype.note(noted.state, { rarity = "Epic" }).state)
	end)
end)

describe("RollHype pity", function()
	it("fills from 0 to 1 using the caller counter and goal", function()
		local empty = RollHype.pity(0, 10)
		expect(empty.ok).toEqual(true)
		expect(empty.fill).toEqual(0)
		expect(empty.fill).toEqual(RollBoard.fill(0, 10))
		local half = RollHype.pity(5, 10)
		expect(half.ok).toEqual(true)
		expect(half.fill).toEqual(0.5)
		expect(half.fill).toEqual(RollBoard.fill(5, 10))
		expect(half.counter).toEqual(5)
		expect(half.goal).toEqual(10)
		local full = RollHype.pity(10, 10)
		expect(full.fill).toEqual(1)
		local over = RollHype.pity(15, 10)
		expect(over.ok).toEqual(true)
		expect(over.fill).toEqual(1)
		expect(over.counter).toEqual(15)
		local fraction = RollHype.pity(1.5, 10)
		expect(fraction.ok).toEqual(true)
		expect(fraction.fill).toEqual(0.15)
		expect(fraction.fill).toEqual(RollBoard.fill(1.5, 10))
	end)

	it("reads one RollMath counter or one explicit bar", function()
		local math = RollHype.pity({
			rollsSinceLegendary = 250,
			pityLegendaryAt = 1000,
			totalRolls = 9000,
		})
		expect(math.ok).toEqual(true)
		expect(math.fill).toEqual(0.25)
		expect(math.counter).toEqual(250)
		expect(math.goal).toEqual(1000)

		local epic = RollHype.pity({ sinceEpic = 40, epicGoal = 100 })
		expect(epic.fill).toEqual(0.4)
		local legendary = RollHype.pity({ sinceLegendary = 100, legendaryGoal = 1000 })
		expect(legendary.fill).toEqual(0.1)
		local plain = RollHype.pity({ since = 1, goal = 4 })
		expect(plain.fill).toEqual(0.25)
		local named = RollHype.pity({ counter = 1, goal = 4 })
		expect(named.fill).toEqual(0.25)
	end)

	it("refuses two counters, a missing goal, and a counter that is not real", function()
		local both = RollHype.pity({
			sinceEpic = 1,
			epicGoal = 100,
			sinceLegendary = 2,
			legendaryGoal = 1000,
		})
		expect(both.ok).toEqual(false)
		expect(both.error).toEqual(ERRORS.which)
		expect(both.fill).toEqual(0)
		expect(both.rarity).toBeNil()

		local mixed = RollHype.pity({ sinceEpic = 1, goal = 100 })
		expect(mixed.error).toEqual(ERRORS.which)

		local noGoal = RollHype.pity(3, nil)
		expect(noGoal.ok).toEqual(false)
		expect(noGoal.error).toEqual(ERRORS.goal)
		expect(noGoal.fill).toEqual(0)
		expect(RollHype.pity({ rollsSinceLegendary = 3 }).error).toEqual(ERRORS.goal)
		expect(RollHype.pity({ totalRolls = 9 }).error).toEqual(ERRORS.goal)
		expect(RollHype.pity(3, 0).error).toEqual(ERRORS.goal)
		expect(RollHype.pity(3, -1).error).toEqual(ERRORS.goal)
		expect(RollHype.pity(3, 0 / 0).error).toEqual(ERRORS.goal)

		local missing = RollHype.pity(nil, 10)
		expect(missing.ok).toEqual(false)
		expect(missing.error).toEqual(ERRORS.counter)
		expect(missing.fill).toEqual(0)
		expect(missing.goal).toEqual(10)
		expect(RollHype.pity(-1, 10).error).toEqual(ERRORS.counter)
		expect(RollHype.pity(0 / 0, 10).error).toEqual(ERRORS.counter)
		expect(RollHype.pity(math.huge, 10).error).toEqual(ERRORS.counter)
		expect(RollHype.pity(math.huge, 10).fill).toEqual(0)
		expect(RollHype.pity("3", 10).error).toEqual(ERRORS.counter)
	end)

	it("returns a new meter and no rarity", function()
		local source = { rollsSinceLegendary = 1, pityLegendaryAt = 4 }
		local row = RollHype.pity(source)
		expect(row.ok).toEqual(true)
		expect(source.rollsSinceLegendary).toEqual(1)
		expect(row.nearMiss).toBeNil()
		expect(row.almost).toBeNil()
		expect(keysOf(row).rarity).toBeNil()
		local again = RollHype.pity(1, 4)
		expect(identical(row, again)).toEqual(false)
		expect(row.fill).toEqual(again.fill)
	end)
end)

describe("RollHype tempo", function()
	it("returns the rolled rarity and a longer build-up higher up the ladder", function()
		local previous = 0
		for _, name in ipairs(Rarities.ORDER) do
			local row = RollHype.tempo(name)
			local paid = RollHype.tempo(name, true)
			local free = RollHype.tempo(name, false)
			expect(row.ok).toEqual(true)
			expect(paid).toEqual(row)
			expect(free).toEqual(row)
			expect(row.rarity).toEqual(name)
			expect(row.tier).toEqual(Rarities.INDEX[name])
			expect(row.buildUp).toBeGreaterThan(previous)
			expect(row.nearMiss).toBeNil()
			previous = row.buildUp
		end
	end)

	it("does not invent a tier for a rarity that is not on the ladder", function()
		local samples: { any } = { "epic", "Legendary ", "", 1, {} }
		for _, rarity in ipairs(samples) do
			local row = RollHype.tempo(rarity, true)
			expect(row.ok).toEqual(false)
			expect(row.error).toEqual(ERRORS.rarity)
			expect(row.rarity).toBeNil()
			expect(row.tier).toBeNil()
			expect(row.buildUp).toBeNil()
		end
		local missing = RollHype.tempo(nil, true)
		expect(missing.ok).toEqual(false)
		expect(missing.error).toEqual(ERRORS.rarity)
		expect(missing.rarity).toBeNil()
		expect(missing.tier).toBeNil()
		expect(missing.buildUp).toBeNil()
	end)
end)

describe("RollHype isolation", function()
	it("is not required by src and does not roll, wait, or read the clock", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RollHype.luau")
		local requires = {}
		for path in string.gmatch(source, 'require%("([^"]+)"%)') do
			table.insert(requires, path)
		end
		expect(requires).toEqual({ "./Rarities" })
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.date", 1, true)).toBeNil()
		expect(string.find(source, "Random", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "DataStore", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresHype(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
