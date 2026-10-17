--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RollLoop = require("../src/ReplicatedStorage/Shared/RollLoop")
local RollNear = require("../src/ReplicatedStorage/Shared/RollNear")

local ERRORS = RollNear.ERRORS

local function identical(left: any, right: any): boolean
	return left == right
end

local function mentions(text: string, name: string): boolean
	local startAt = 1
	while true do
		local foundAt = string.find(text, name, startAt, true)
		if foundAt == nil then
			return false
		end
		local before = if foundAt == 1 then "" else string.sub(text, foundAt - 1, foundAt - 1)
		local afterAt = foundAt + #name
		local after = if afterAt > #text then "" else string.sub(text, afterAt, afterAt)
		local beforeOk = before == "" or string.match(before, "%a") == nil
		local afterOk = after == "" or string.match(after, "%a") == nil
		if beforeOk and afterOk then
			return true
		end
		startAt = foundAt + 1
	end
end

local function rarityNames(value: any, found: { [string]: boolean })
	if type(value) == "string" then
		for _, name in ipairs(Rarities.ORDER) do
			if mentions(value, name) then
				found[name] = true
			end
		end
		return
	end
	if type(value) ~= "table" then
		return
	end
	for key, child in pairs(value) do
		rarityNames(key, found)
		rarityNames(child, found)
	end
end

local function namesIn(value: any): { [string]: boolean }
	local found: { [string]: boolean } = {}
	rarityNames(value, found)
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

local function requiresNear(source: string): boolean
	if string.find(source, "Shared.RollNear", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RollNear", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RollNear", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RollNear")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('RollNear')", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'require("./RollNear")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "require('./RollNear')", 1, true) ~= nil then
		return true
	end
	return false
end

describe("RollNear near-miss", function()
	it("flags a land exactly one ladder step under the watched rarity", function()
		for index, watched in ipairs(Rarities.ORDER) do
			if index > 1 then
				local landed = Rarities.ORDER[index - 1]
				local result = RollNear.near({ rarity = landed, watched = watched })
				expect(result.ok).toEqual(true)
				expect(result.nearMiss).toEqual(true)
				expect(result.watchedStep).toEqual(true)
				expect(result.pityShort).toEqual(false)
				expect(result.rarity).toEqual(landed)
				expect(namesIn(result)).toEqual({ [landed] = true })
			end
		end
		local rare = RollNear.near({ rarity = "Rare", watched = "Epic" })
		expect(rare.nearMiss).toEqual(true)
		expect(rare.rarity).toEqual("Rare")
	end)

	it("flags pity when the counter is one short and the land is below that rarity", function()
		local result = RollNear.near({
			rarity = "Rare",
			counter = 99,
			goal = 100,
			pity = "Epic",
		})
		expect(result.ok).toEqual(true)
		expect(result.nearMiss).toEqual(true)
		expect(result.pityShort).toEqual(true)
		expect(result.watchedStep).toEqual(false)
		expect(result.rarity).toEqual("Rare")
		expect(namesIn(result)).toEqual({ Rare = true })

		local legendary = RollNear.near({
			rarity = "Epic",
			counter = 999,
			goal = 1000,
			pity = "Legendary",
		})
		expect(legendary.nearMiss).toEqual(true)
		expect(legendary.pityShort).toEqual(true)
		expect(legendary.rarity).toEqual("Epic")
		expect(namesIn(legendary)).toEqual({ Epic = true })

		local first = RollNear.near({
			rarity = "Common",
			counter = 0,
			goal = 1,
			pity = "Uncommon",
		})
		expect(first.nearMiss).toEqual(true)
		expect(first.rarity).toEqual("Common")
	end)

	it("does not flag a two-step gap or a land at or above the watched rarity", function()
		local gap = RollNear.near({ rarity = "Rare", watched = "Legendary" })
		expect(gap.ok).toEqual(true)
		expect(gap.nearMiss).toEqual(false)
		expect(gap.watchedStep).toEqual(false)
		expect(gap.rarity).toEqual("Rare")
		expect(namesIn(gap)).toEqual({ Rare = true })

		for watchedIndex, watched in ipairs(Rarities.ORDER) do
			for landedIndex, landed in ipairs(Rarities.ORDER) do
				local result = RollNear.near({ rarity = landed, watched = watched })
				local oneStep = landedIndex == watchedIndex - 1
				expect(result.ok).toEqual(true)
				expect(result.watchedStep).toEqual(oneStep)
				expect(result.nearMiss).toEqual(oneStep)
				expect(result.rarity).toEqual(landed)
				if landedIndex >= watchedIndex then
					expect(result.nearMiss).toEqual(false)
				end
				if watchedIndex - landedIndex >= 2 then
					expect(result.nearMiss).toEqual(false)
				end
			end
		end

		local at = RollNear.near({ rarity = "Epic", watched = "Epic" })
		expect(at.nearMiss).toEqual(false)
		expect(at.rarity).toEqual("Epic")
		local above = RollNear.near({ rarity = "Legendary", watched = "Epic" })
		expect(above.nearMiss).toEqual(false)
		expect(above.rarity).toEqual("Legendary")
		local common = RollNear.near({ rarity = "Common", watched = "Common" })
		expect(common.nearMiss).toEqual(false)
		expect(common.rarity).toEqual("Common")
	end)

	it("does not flag pity that is not one short or a land at or above the pity rarity", function()
		local twoShort = RollNear.near({
			rarity = "Rare",
			counter = 98,
			goal = 100,
			pity = "Epic",
		})
		expect(twoShort.nearMiss).toEqual(false)
		expect(twoShort.pityShort).toEqual(false)
		expect(twoShort.rarity).toEqual("Rare")

		local atGoal = RollNear.near({
			rarity = "Rare",
			counter = 100,
			goal = 100,
			pity = "Epic",
		})
		expect(atGoal.nearMiss).toEqual(false)
		expect(atGoal.rarity).toEqual("Rare")

		local landedIt = RollNear.near({
			rarity = "Epic",
			counter = 99,
			goal = 100,
			pity = "Epic",
		})
		expect(landedIt.nearMiss).toEqual(false)
		expect(landedIt.pityShort).toEqual(false)
		expect(landedIt.rarity).toEqual("Epic")

		local above = RollNear.near({
			rarity = "Legendary",
			counter = 99,
			goal = 100,
			pity = "Epic",
		})
		expect(above.nearMiss).toEqual(false)
		expect(above.rarity).toEqual("Legendary")
		expect(namesIn(above)).toEqual({ Legendary = true })

		local nothingBelow = RollNear.near({
			rarity = "Common",
			counter = 0,
			goal = 1,
			pity = "Common",
		})
		expect(nothingBelow.nearMiss).toEqual(false)
		expect(nothingBelow.rarity).toEqual("Common")
	end)

	it("can flag pity without flagging a two-step watched gap", function()
		local result = RollNear.near({
			rarity = "Rare",
			watched = "Legendary",
			counter = 99,
			goal = 100,
			pity = "Legendary",
		})
		expect(result.ok).toEqual(true)
		expect(result.nearMiss).toEqual(true)
		expect(result.watchedStep).toEqual(false)
		expect(result.pityShort).toEqual(true)
		expect(result.rarity).toEqual("Rare")
		expect(namesIn(result)).toEqual({ Rare = true })
	end)

	it("never surfaces a rarity that was not rolled", function()
		local roll = {
			rarity = "Rare",
			watched = "Epic",
			counter = 99,
			goal = 100,
			pity = "Legendary",
			paid = true,
			almost = "Mythic",
			nearMiss = "Secret",
			tease = "Secret",
			nextRarity = "Epic",
			odds = { Legendary = 1 },
		}
		local result = RollNear.near(roll)
		expect(result.ok).toEqual(true)
		expect(result.nearMiss).toEqual(true)
		expect(result.watchedStep).toEqual(true)
		expect(result.pityShort).toEqual(true)
		expect(result.rarity).toEqual("Rare")
		expect(result.rarity).toEqual(roll.rarity)
		expect(namesIn(result)).toEqual({ Rare = true })
		expect(result.almost).toBeNil()
		expect(result.tease).toBeNil()
		expect(result.nextRarity).toBeNil()
		expect(result.odds).toBeNil()
		expect(result.watched).toBeNil()
		expect(result.pity).toBeNil()
		expect(roll.almost).toEqual("Mythic")
		expect(roll.nearMiss).toEqual("Secret")
		expect(roll.odds.Legendary).toEqual(1)

		local noted = RollNear.note({ streak = 4 }, roll)
		expect(noted.ok).toEqual(true)
		expect(noted.rarity).toEqual("Rare")
		expect(noted.nearMiss).toEqual(true)
		expect(namesIn(noted)).toEqual({ Rare = true })
		expect(noted.state.almost).toBeNil()
		expect(noted.milestone).toBeNil()
		expect(noted.callout).toBeNil()

		local missed = RollNear.near({
			landed = false,
			rarity = "Secret",
			watched = "Mythic",
			almost = "Mythic",
		})
		expect(missed.ok).toEqual(true)
		expect(missed.nearMiss).toEqual(false)
		expect(missed.rarity).toBeNil()
		expect(namesIn(missed)).toEqual({})

		local missedNote = RollNear.note({ streak = 4 }, {
			landed = false,
			rarity = "Secret",
			watched = "Epic",
			almost = "Mythic",
		})
		expect(missedNote.rarity).toBeNil()
		expect(missedNote.nearMiss).toEqual(false)
		expect(namesIn(missedNote)).toEqual({})
	end)

	it("uses the same rules for a paid roll and a free roll", function()
		local state = { streak = 3 }
		local function roll(paid: any)
			return {
				rarity = "Rare",
				watched = "Epic",
				counter = 99,
				goal = 100,
				pity = "Legendary",
				paid = paid,
			}
		end
		local free = RollNear.near(roll(false))
		local paid = RollNear.near(roll(true))
		local omitted = RollNear.near(roll(nil))
		expect(paid).toEqual(free)
		expect(omitted).toEqual(free)
		expect(paid.nearMiss).toEqual(true)
		expect(paid.rarity).toEqual("Rare")

		local freeNote = RollNear.note(state, roll(false))
		local paidNote = RollNear.note(state, roll(true))
		local omittedNote = RollNear.note(state, roll(nil))
		expect(paidNote).toEqual(freeNote)
		expect(omittedNote).toEqual(freeNote)
		expect(paidNote.streak).toEqual(4)
		expect(paidNote.rarity).toEqual("Rare")
		expect(state.streak).toEqual(3)

		local quiet = { rarity = "Common", watched = "Legendary", paid = false }
		local quietPaid = { rarity = "Common", watched = "Legendary", paid = true }
		expect(RollNear.near(quietPaid)).toEqual(RollNear.near(quiet))
		expect(RollNear.note(state, quietPaid)).toEqual(RollNear.note(state, quiet))

		local freeMiss = RollNear.note(state, { landed = false, rarity = "Secret", paid = false })
		local paidMiss = RollNear.note(state, { landed = false, rarity = "Secret", paid = true })
		expect(paidMiss).toEqual(freeMiss)
		expect(paidMiss.nearMiss).toEqual(false)
		expect(paidMiss.rarity).toBeNil()
		expect(paidMiss.streak).toEqual(0)
	end)
end)

describe("RollNear streak", function()
	it("starts at zero", function()
		local opened = RollNear.fresh()
		expect(opened.ok).toEqual(true)
		expect(opened.state).toEqual({ streak = 0 })
		expect(identical(opened.state, RollNear.fresh().state)).toEqual(false)
	end)

	it("increments a land and resets a miss, matching RollLoop", function()
		local current = 0
		local state = RollNear.fresh().state
		local samples = { true, true, false, true, true, true, false, false, true }
		for _, landed in ipairs(samples) do
			local expected = RollLoop.streak(current, landed)
			local got = RollNear.streak(state, landed)
			expect(got.ok).toEqual(true)
			expect(got.streak).toEqual(expected)
			expect(got.state.streak).toEqual(expected)
			expect(got.landed).toEqual(landed)
			expect(state.streak).toEqual(current)
			expect(identical(got.state, state)).toEqual(false)
			local noted =
				RollNear.note(state, if landed then { rarity = "Common" } else { landed = false })
			expect(noted.ok).toEqual(true)
			expect(noted.streak).toEqual(expected)
			expect(noted.state.streak).toEqual(expected)
			expect(noted.landed).toEqual(landed)
			if landed then
				expect(noted.rarity).toEqual("Common")
			else
				expect(noted.rarity).toBeNil()
				expect(noted.nearMiss).toEqual(false)
			end
			current = expected
			state = got.state
		end
		expect(state.streak).toEqual(1)
	end)

	it("does not call out 10, 25, 50, or 100", function()
		for _, count in ipairs({ 9, 24, 49, 99 }) do
			local state = { streak = count }
			local noted = RollNear.note(state, { rarity = "Common", paid = true })
			expect(noted.ok).toEqual(true)
			expect(noted.streak).toEqual(count + 1)
			expect(noted.state.streak).toEqual(count + 1)
			expect(noted.milestone).toBeNil()
			expect(noted.callout).toBeNil()
			expect(noted.state.milestone).toBeNil()
			expect(noted.state.callout).toBeNil()
			expect(noted.rarity).toEqual("Common")
			expect(state.streak).toEqual(count)
		end
		expect(RollNear.streak({ streak = 10 }, true).streak).toEqual(11)
		expect(RollNear.streak({ streak = 100 }, false).streak).toEqual(0)
	end)
end)

describe("RollNear inputs", function()
	it("returns a new table and does not write the input", function()
		local state = { streak = 4, nearMiss = "Mythic", almost = "Secret" }
		local roll = {
			rarity = "Uncommon",
			watched = "Rare",
			counter = 9,
			goal = 10,
			pity = "Epic",
			paid = true,
			almost = "Secret",
			odds = 25,
		}
		table.freeze(state)
		table.freeze(roll)
		local noted = RollNear.note(state, roll)
		expect(noted.ok).toEqual(true)
		expect(noted.nearMiss).toEqual(true)
		expect(noted.watchedStep).toEqual(true)
		expect(noted.pityShort).toEqual(true)
		expect(noted.streak).toEqual(5)
		expect(noted.rarity).toEqual("Uncommon")
		expect(namesIn(noted)).toEqual({ Uncommon = true })
		expect(state.streak).toEqual(4)
		expect(state.nearMiss).toEqual("Mythic")
		expect(state.almost).toEqual("Secret")
		expect(roll.rarity).toEqual("Uncommon")
		expect(roll.almost).toEqual("Secret")
		expect(roll.odds).toEqual(25)
		expect(identical(noted.state, state)).toEqual(false)
		expect(identical(noted, roll)).toEqual(false)

		local again = RollNear.near(roll)
		expect(again.rarity).toEqual("Uncommon")
		expect(identical(again, RollNear.near(roll))).toEqual(false)
		expect(roll.watched).toEqual("Rare")

		local held = RollNear.streak(state, false)
		expect(held.streak).toEqual(0)
		expect(state.streak).toEqual(4)
		expect(identical(held.state, state)).toEqual(false)
	end)

	it("refuses a bad note without throwing or moving the streak", function()
		local state = { streak = 2 }
		table.freeze(state)
		expect(RollNear.near(nil).error).toEqual(ERRORS.roll)
		expect(RollNear.near("Epic").error).toEqual(ERRORS.roll)
		expect(RollNear.near({ rarity = "epic" }).error).toEqual(ERRORS.rarity)
		expect(RollNear.near({ rarity = "Epic", watched = "Off" }).error).toEqual(ERRORS.watched)
		expect(RollNear.near({ rarity = "Rare", counter = 1, goal = 2 }).error).toEqual(ERRORS.pity)
		expect(RollNear.near({ rarity = "Rare", goal = 0, counter = 0, pity = "Epic" }).error).toEqual(
			ERRORS.pity
		)
		expect(RollNear.near({ landed = "yes", rarity = "Rare" }).error).toEqual(ERRORS.roll)
		expect(RollNear.near({ rarity = "Rare" }).rarity).toEqual("Rare")
		expect(RollNear.near({ rarity = "Rare" }).nearMiss).toEqual(false)

		local noted = RollNear.note(state, { rarity = "nope", watched = "Epic" })
		expect(noted.ok).toEqual(false)
		expect(noted.error).toEqual(ERRORS.rarity)
		expect(noted.rarity).toBeNil()
		expect(noted.nearMiss).toEqual(false)
		expect(noted.streak).toEqual(2)
		expect(noted.state.streak).toEqual(2)
		expect(state.streak).toEqual(2)
		expect(identical(noted.state, state)).toEqual(false)

		local off = RollNear.note(state, { rarity = "Epic", watched = "Off" })
		expect(off.ok).toEqual(false)
		expect(off.error).toEqual(ERRORS.watched)
		expect(off.streak).toEqual(2)
		expect(off.rarity).toBeNil()
		expect(namesIn(off)).toEqual({})
		expect(RollNear.note(nil, { rarity = "Common" }).error).toEqual(ERRORS.state)
		expect(RollNear.note(state, nil).error).toEqual(ERRORS.roll)
		expect(RollNear.streak(state, "yes").error).toEqual(ERRORS.roll)
		expect(RollNear.streak({ streak = -1 }, true).error).toEqual(ERRORS.state)
		expect(RollNear.streak({ streak = 1.5 }, true).error).toEqual(ERRORS.state)
		expect(state.streak).toEqual(2)
	end)

	it("freezes the error strings", function()
		expect(function()
			RollNear.ERRORS.rarity = "nope"
		end).toThrow()
	end)
end)

describe("RollNear isolation", function()
	it("is required only by the roll route and does not roll, wait, or read the clock", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RollNear.luau")
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
		expect(string.find(source, "MemoryStore", 1, true)).toBeNil()
		expect(string.find(source, "Marketplace", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresNear(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({
			"src/ReplicatedStorage/Shared/UiRouter.luau",
		})
	end)
end)
