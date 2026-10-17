--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidPractice = require("../src/ReplicatedStorage/Shared/RaidPractice")
local RaidPracticeGuard = require("../src/ReplicatedStorage/Shared/RaidPracticeGuard")
local Raids = require("../src/ReplicatedStorage/Shared/Raids")

local ERRORS = RaidPracticeGuard.ERRORS
local CONFIG = RaidPracticeGuard.CONFIG

local function identical(left: any, right: any): boolean
	return left == right
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

local function requiresGuard(source: string): boolean
	if string.find(source, "Shared.RaidPracticeGuard", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidPracticeGuard", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidPracticeGuard", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidPracticeGuard")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('RaidPracticeGuard')", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'require("./RaidPracticeGuard")', 1, true) ~= nil then
		return true
	end
	return false
end

local function refused(ok: boolean, value: any, err: string?)
	expect(ok).toEqual(false)
	expect(value).toBeNil()
	expect(type(err)).toEqual("string")
end

local function fillHits(count: number): { [string]: number }
	local hits = {}
	for index = 1, count do
		hits["m" .. tostring(index)] = 1
	end
	return hits
end

local function allowThrough(count: number): { [string]: boolean }
	local list = {}
	for index = 1, count do
		list["m" .. tostring(index)] = true
	end
	return list
end

describe("RaidPracticeGuard config", function()
	it("pins the placeholder caps and the phase counts", function()
		expect(CONFIG).toEqual({
			phases = 3,
			shardbreakerPhases = 4,
			mechanicCap = 12,
			maxDamage = 100000,
			maxIdLength = 64,
			allowCap = 64,
			maxWing = 32,
		})
	end)

	it("matches the practice boss, difficulty, and phase rules", function()
		expect(RaidPracticeGuard.BOSSES).toEqual(RaidPractice.BOSSES)
		expect(RaidPracticeGuard.DIFFICULTIES).toEqual(RaidPractice.DIFFICULTIES)
		expect(CONFIG.phases).toEqual(RaidPractice.CONFIG.phases)
		expect(CONFIG.shardbreakerPhases).toEqual(RaidPractice.CONFIG.shardbreakerPhases)
		expect(RaidPracticeGuard.DIFFICULTIES.fracture).toBeNil()
		expect(RaidPracticeGuard.DIFFICULTIES.guided).toBeNil()
	end)

	it("freezes the thresholds, the lists, and the errors", function()
		expect(function()
			CONFIG.mechanicCap = 1
		end).toThrow()
		expect(function()
			CONFIG.maxDamage = 1
		end).toThrow()
		expect(function()
			RaidPracticeGuard.BOSSES.twins = false
		end).toThrow()
		expect(function()
			RaidPracticeGuard.DIFFICULTIES.story = false
		end).toThrow()
		expect(function()
			ERRORS.wing = "open"
		end).toThrow()
	end)

	it("has no Robux price and no loot helpers", function()
		local banned = {
			robux = true,
			premium = true,
			productid = true,
			gamepass = true,
			price = true,
		}
		local count = 0
		for key in pairs(CONFIG) do
			count += 1
			expect(banned[string.lower(key)]).toBeNil()
		end
		expect(count).toEqual(7)
		expect(RaidPracticeGuard.fresh).toBeNil()
		expect(RaidPracticeGuard.note).toBeNil()
		expect(RaidPracticeGuard.rewards).toBeNil()
	end)

	it("pins the failure strings", function()
		expect(ERRORS).toEqual({
			wing = "That wing has no grove.",
			boss = "That boss has no grove.",
			difficulty = "That difficulty has no grove.",
			phase = "That phase is not in this grove.",
			mechanic = "That mechanic is unusable.",
			allow = "That mechanic list is unusable.",
			catalog = "That mechanic is not on this boss.",
			cap = "That grove is holding too many mechanics.",
			off = "That mechanic is turned off.",
			state = "That practice record is unusable.",
			enabled = "That mechanic switch is unusable.",
			damage = "That damage amount is unusable.",
			ceiling = "That damage amount is too high.",
			disagree = "Those fields disagree.",
		})
	end)
end)

describe("RaidPracticeGuard wings", function()
	it("maps each live wing onto that row's boss id", function()
		local expected = { "twins", "sapwell", "galecrown", "awakened" }
		expect(#Raids.WINGS).toEqual(4)
		for index, id in ipairs(expected) do
			local ok, bossId, err = RaidPracticeGuard.boss(index)
			expect(ok).toEqual(true)
			expect(err).toBeNil()
			expect(bossId).toEqual(id)
			expect(bossId).toEqual(Raids.WINGS[index].id)
		end
		local ok, bossId, err = RaidPracticeGuard.boss(1.0)
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(bossId).toEqual("twins")
	end)

	it("refuses a wing that is not a row", function()
		local noneOk, noneBoss, noneErr = RaidPracticeGuard.boss(nil)
		expect(noneOk).toEqual(false)
		expect(noneBoss).toBeNil()
		expect(noneErr).toEqual(ERRORS.wing)
		local samples = { 0, -1, 1.5, 5, 33, 1e20, "1", "twins", true, false, {}, "" }
		for _, wing in ipairs(samples) do
			local ok, bossId, err = RaidPracticeGuard.boss(wing)
			expect(ok).toEqual(false)
			expect(bossId).toBeNil()
			expect(err).toEqual(ERRORS.wing)
		end
		local nanOk, nanBoss, nanErr = RaidPracticeGuard.boss(0 / 0)
		expect(nanOk).toEqual(false)
		expect(nanBoss).toBeNil()
		expect(nanErr).toEqual(ERRORS.wing)
		local infOk, infBoss, infErr = RaidPracticeGuard.boss(math.huge)
		expect(infOk).toEqual(false)
		expect(infBoss).toBeNil()
		expect(infErr).toEqual(ERRORS.wing)
	end)
end)

describe("RaidPracticeGuard difficulty and phase", function()
	it("accepts the four difficulties and trims them", function()
		local ok, name, err = RaidPracticeGuard.difficulty(" Story ")
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(name).toEqual("story")
		local hardOk, hard = RaidPracticeGuard.difficulty("HARD")
		expect(hardOk).toEqual(true)
		expect(hard).toEqual("hard")
		local breakOk, breaker = RaidPracticeGuard.difficulty("shardbreaker")
		expect(breakOk).toEqual(true)
		expect(breaker).toEqual("shardbreaker")
	end)

	it("refuses fracture, guided, and a wrong type", function()
		for _, value in ipairs({ "fracture", "guided", "fracture1", "shard-breaker", "", " " }) do
			local ok, name, err = RaidPracticeGuard.difficulty(value)
			expect(ok).toEqual(false)
			expect(name).toBeNil()
			expect(err).toEqual(ERRORS.difficulty)
		end
		local ok, name, err = RaidPracticeGuard.difficulty(1)
		expect(ok).toEqual(false)
		expect(name).toBeNil()
		expect(err).toEqual(ERRORS.difficulty)
	end)

	it("allows phase 4 only on shardbreaker", function()
		local storyOk, storyPhase, storyErr = RaidPracticeGuard.phase("story", 3)
		expect(storyOk).toEqual(true)
		expect(storyErr).toBeNil()
		expect(storyPhase).toEqual(3)
		local deniedOk, denied, deniedErr = RaidPracticeGuard.phase("story", 4)
		expect(deniedOk).toEqual(false)
		expect(denied).toBeNil()
		expect(deniedErr).toEqual(ERRORS.phase)
		local hardOk, hardPhase, hardErr = RaidPracticeGuard.phase(" hard ", 4)
		expect(hardOk).toEqual(false)
		expect(hardPhase).toBeNil()
		expect(hardErr).toEqual(ERRORS.phase)
		local breakOk, breakPhase, breakErr = RaidPracticeGuard.phase(" shardbreaker ", 4)
		expect(breakOk).toEqual(true)
		expect(breakErr).toBeNil()
		expect(breakPhase).toEqual(4)
	end)

	it("refuses a phase that is not an integer in range", function()
		for _, phase in ipairs({ 0, -1, 1.5, 5, "1", true }) do
			local ok, step, err = RaidPracticeGuard.phase("normal", phase)
			expect(ok).toEqual(false)
			expect(step).toBeNil()
			expect(err).toEqual(ERRORS.phase)
		end
		local ok, step, err = RaidPracticeGuard.phase("fracture", 1)
		expect(ok).toEqual(false)
		expect(step).toBeNil()
		expect(err).toEqual(ERRORS.difficulty)
	end)
end)

describe("RaidPracticeGuard start", function()
	it("returns a new opening and does not price it", function()
		local ok, opening, err = RaidPracticeGuard.start(2, " shardbreaker ", 4)
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(opening).toEqual({
			bossId = "sapwell",
			difficulty = "shardbreaker",
			phase = 4,
		})
		expect(opening.cost).toBeNil()
		local againOk, again = RaidPracticeGuard.start(2, "shardbreaker", 4)
		expect(againOk).toEqual(true)
		expect(again).toEqual(opening)
		expect(identical(opening, again)).toEqual(false)
		opening.phase = 1
		expect(again.phase).toEqual(4)
	end)

	it("checks the wing, then the difficulty, then the phase", function()
		local wingOk, wingValue, wingErr = RaidPracticeGuard.start(nil, nil, nil)
		expect(wingOk).toEqual(false)
		expect(wingValue).toBeNil()
		expect(wingErr).toEqual(ERRORS.wing)
		local diffOk, diffValue, diffErr = RaidPracticeGuard.start(1, "fracture", 4)
		expect(diffOk).toEqual(false)
		expect(diffValue).toBeNil()
		expect(diffErr).toEqual(ERRORS.difficulty)
		local phaseOk, phaseValue, phaseErr = RaidPracticeGuard.start(4, "story", 4)
		expect(phaseOk).toEqual(false)
		expect(phaseValue).toBeNil()
		expect(phaseErr).toEqual(ERRORS.phase)
		local ok, opening, err = RaidPracticeGuard.start(4, " hard ", 3)
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(opening).toEqual({
			bossId = "awakened",
			difficulty = "hard",
			phase = 3,
		})
	end)
end)

describe("RaidPracticeGuard mechanics", function()
	it("accepts a flat array, a set, or a list keyed by boss", function()
		local arrayOk, arrayName, arrayErr =
			RaidPracticeGuard.mechanic(" Twins ", " Gust ", { " Gust " }, nil)
		expect(arrayOk).toEqual(true)
		expect(arrayErr).toBeNil()
		expect(arrayName).toEqual("Gust")
		local setOk, setName =
			RaidPracticeGuard.mechanic("sapwell", "pool", { pool = true, drip = false }, nil)
		expect(setOk).toEqual(true)
		expect(setName).toEqual("pool")
		local keyed = {
			twins = { "bond" },
			galecrown = { gust = true },
		}
		local keyOk, keyName, keyErr = RaidPracticeGuard.mechanic("galecrown", "gust", keyed, nil)
		expect(keyOk).toEqual(true)
		expect(keyErr).toBeNil()
		expect(keyName).toEqual("gust")
		local missOk, missName, missErr = RaidPracticeGuard.mechanic("twins", "gust", keyed, nil)
		expect(missOk).toEqual(false)
		expect(missName).toBeNil()
		expect(missErr).toEqual(ERRORS.catalog)
	end)

	it("keeps mechanic ids case-sensitive", function()
		local ok, name, err = RaidPracticeGuard.mechanic("twins", "gust", { "Gust" }, nil)
		expect(ok).toEqual(false)
		expect(name).toBeNil()
		expect(err).toEqual(ERRORS.catalog)
		local keptOk, kept = RaidPracticeGuard.mechanic("twins", "Gust", { "Gust" }, nil)
		expect(keptOk).toEqual(true)
		expect(kept).toEqual("Gust")
	end)

	it("uses the boss table instead of flat keys on that same boss", function()
		local list = {
			twins = { "bond" },
			gust = true,
		}
		local flatOk, flatName, flatErr = RaidPracticeGuard.mechanic("twins", "gust", list, nil)
		expect(flatOk).toEqual(false)
		expect(flatName).toBeNil()
		expect(flatErr).toEqual(ERRORS.catalog)
		local bondOk, bond = RaidPracticeGuard.mechanic("twins", "bond", list, nil)
		expect(bondOk).toEqual(true)
		expect(bond).toEqual("bond")
		local otherOk, other = RaidPracticeGuard.mechanic("sapwell", "gust", list, nil)
		expect(otherOk).toEqual(true)
		expect(other).toEqual("gust")
	end)

	it("refuses an empty list, a broken list, and a bad id", function()
		local emptyOk, emptyName, emptyErr = RaidPracticeGuard.mechanic("twins", "gust", {}, nil)
		expect(emptyOk).toEqual(false)
		expect(emptyName).toBeNil()
		expect(emptyErr).toEqual(ERRORS.catalog)
		local missingOk, missingName, missingErr =
			RaidPracticeGuard.mechanic("twins", "gust", nil, nil)
		expect(missingOk).toEqual(false)
		expect(missingName).toBeNil()
		expect(missingErr).toEqual(ERRORS.allow)
		local brokenOk, brokenName, brokenErr =
			RaidPracticeGuard.mechanic("twins", "gust", { gust = { "x" } }, nil)
		expect(brokenOk).toEqual(false)
		expect(brokenName).toBeNil()
		expect(brokenErr).toEqual(ERRORS.allow)
		local idOk, idName, idErr = RaidPracticeGuard.mechanic("twins", nil, nil, "bad")
		expect(idOk).toEqual(false)
		expect(idName).toBeNil()
		expect(idErr).toEqual(ERRORS.mechanic)
		local bossOk, bossName, bossErr = RaidPracticeGuard.mechanic(1, "gust", { "gust" }, nil)
		expect(bossOk).toEqual(false)
		expect(bossName).toBeNil()
		expect(bossErr).toEqual(ERRORS.boss)
	end)

	it("refuses a list longer than the allow cap", function()
		local list = {}
		for index = 1, CONFIG.allowCap + 1 do
			list[index] = "id" .. tostring(index)
		end
		local ok, name, err = RaidPracticeGuard.mechanic("twins", "id1", list, nil)
		expect(ok).toEqual(false)
		expect(name).toBeNil()
		expect(err).toEqual(ERRORS.allow)
		local exact = {}
		for index = 1, CONFIG.allowCap do
			exact[index] = "id" .. tostring(index)
		end
		local exactOk, exactName = RaidPracticeGuard.mechanic("twins", "id1", exact, nil)
		expect(exactOk).toEqual(true)
		expect(exactName).toEqual("id1")
	end)

	it("caps distinct ids already held on the session", function()
		local hits = fillHits(CONFIG.mechanicCap)
		local allow = allowThrough(CONFIG.mechanicCap + 1)
		local state = {
			bossId = "twins",
			hits = hits,
			mechanics = {},
		}
		local heldOk, heldName, heldErr = RaidPracticeGuard.mechanic("twins", "m1", allow, state)
		expect(heldOk).toEqual(true)
		expect(heldErr).toBeNil()
		expect(heldName).toEqual("m1")
		local capOk, capName, capErr = RaidPracticeGuard.mechanic("twins", "m13", allow, state)
		expect(capOk).toEqual(false)
		expect(capName).toBeNil()
		expect(capErr).toEqual(ERRORS.cap)
		expect(hits.m1).toEqual(1)
		expect(hits.m13).toBeNil()
	end)

	it("refuses a session whose boss does not match", function()
		local ok, name, err = RaidPracticeGuard.mechanic("twins", "gust", { "gust" }, {
			bossId = "sapwell",
		})
		expect(ok).toEqual(false)
		expect(name).toBeNil()
		expect(err).toEqual(ERRORS.disagree)
		local badOk, badName, badErr =
			RaidPracticeGuard.mechanic("twins", "gust", { "gust" }, "nope")
		expect(badOk).toEqual(false)
		expect(badName).toBeNil()
		expect(badErr).toEqual(ERRORS.state)
	end)
end)

describe("RaidPracticeGuard toggle and hits", function()
	it("returns the switch without writing the session", function()
		local mechanics = table.freeze({ gust = true })
		local state = table.freeze({
			bossId = "galecrown",
			mechanics = mechanics,
			hits = table.freeze({}),
		})
		local allow = table.freeze({ "gust", "dive" })
		local ok, switch, err = RaidPracticeGuard.toggle("galecrown", " dive ", false, allow, state)
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(switch).toEqual({
			mechanicId = "dive",
			enabled = false,
		})
		expect(mechanics.gust).toEqual(true)
		expect(state.hits).toEqual({})
	end)

	it("checks the id, then the switch, then the session", function()
		local idOk, idSwitch, idErr = RaidPracticeGuard.toggle("twins", "", "no", nil, "bad")
		expect(idOk).toEqual(false)
		expect(idSwitch).toBeNil()
		expect(idErr).toEqual(ERRORS.mechanic)
		local flagOk, flagSwitch, flagErr =
			RaidPracticeGuard.toggle("twins", "gust", "true", nil, "bad")
		expect(flagOk).toEqual(false)
		expect(flagSwitch).toBeNil()
		expect(flagErr).toEqual(ERRORS.enabled)
		local stateOk, stateSwitch, stateErr =
			RaidPracticeGuard.toggle("twins", "gust", true, { "gust" }, 4)
		expect(stateOk).toEqual(false)
		expect(stateSwitch).toBeNil()
		expect(stateErr).toEqual(ERRORS.state)
	end)

	it("a new id still uses a slot when the switch is turned off", function()
		local allow = allowThrough(CONFIG.mechanicCap + 1)
		local state = {
			bossId = "twins",
			hits = fillHits(CONFIG.mechanicCap),
		}
		local capOk, capSwitch, capErr =
			RaidPracticeGuard.toggle("twins", "m13", false, allow, state)
		expect(capOk).toEqual(false)
		expect(capSwitch).toBeNil()
		expect(capErr).toEqual(ERRORS.cap)
		local ok, switch, err = RaidPracticeGuard.toggle("twins", "m1", false, allow, state)
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(switch.enabled).toEqual(false)
		expect(switch.mechanicId).toEqual("m1")
	end)

	it("refuses a hit when that mechanic is toggled off", function()
		local state = {
			bossId = "galecrown",
			mechanics = { gust = false },
			hits = {},
		}
		local offOk, offName, offErr = RaidPracticeGuard.hit(state, "gust", { "gust" })
		expect(offOk).toEqual(false)
		expect(offName).toBeNil()
		expect(offErr).toEqual(ERRORS.off)
		state.mechanics.gust = true
		local onOk, onName, onErr = RaidPracticeGuard.hit(state, " gust ", { "gust" })
		expect(onOk).toEqual(true)
		expect(onErr).toBeNil()
		expect(onName).toEqual("gust")
		state.mechanics = {}
		local openOk, openName = RaidPracticeGuard.hit(state, "gust", { gust = true })
		expect(openOk).toEqual(true)
		expect(openName).toEqual("gust")
	end)

	it("checks the id, then the record, then the list, then the cap", function()
		local idOk, idName, idErr = RaidPracticeGuard.hit(nil, nil, nil)
		expect(idOk).toEqual(false)
		expect(idName).toBeNil()
		expect(idErr).toEqual(ERRORS.mechanic)
		local stateOk, stateName, stateErr = RaidPracticeGuard.hit(nil, "gust", { "gust" })
		expect(stateOk).toEqual(false)
		expect(stateName).toBeNil()
		expect(stateErr).toEqual(ERRORS.state)
		local allowOk, allowName, allowErr =
			RaidPracticeGuard.hit({ bossId = "twins" }, "gust", nil)
		expect(allowOk).toEqual(false)
		expect(allowName).toBeNil()
		expect(allowErr).toEqual(ERRORS.allow)
		local listOk, listName, listErr = RaidPracticeGuard.hit({ bossId = "twins" }, "gust", {})
		expect(listOk).toEqual(false)
		expect(listName).toBeNil()
		expect(listErr).toEqual(ERRORS.catalog)
		local hidden = {
			bossId = "twins",
			mechanics = { gust = false },
		}
		local hiddenOk, hiddenName, hiddenErr = RaidPracticeGuard.hit(hidden, "gust", {})
		expect(hiddenOk).toEqual(false)
		expect(hiddenName).toBeNil()
		expect(hiddenErr).toEqual(ERRORS.catalog)
		local full = {
			bossId = "twins",
			hits = fillHits(CONFIG.mechanicCap),
		}
		local capOk, capName, capErr =
			RaidPracticeGuard.hit(full, "m13", allowThrough(CONFIG.mechanicCap + 1))
		expect(capOk).toEqual(false)
		expect(capName).toBeNil()
		expect(capErr).toEqual(ERRORS.cap)
	end)

	it("reads the boss from bossId or boss and refuses a clash", function()
		local ok, name, err = RaidPracticeGuard.hit(
			{ boss = " Awakened " },
			"seasons",
			{ "seasons" }
		)
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(name).toEqual("seasons")
		local clashOk, clashName, clashErr = RaidPracticeGuard.hit({
			bossId = "twins",
			boss = "sapwell",
		}, "gust", { "gust" })
		expect(clashOk).toEqual(false)
		expect(clashName).toBeNil()
		expect(clashErr).toEqual(ERRORS.disagree)
	end)
end)

describe("RaidPracticeGuard damage", function()
	it("accepts 0, a fraction, and the ceiling", function()
		local zeroOk, zero, zeroErr = RaidPracticeGuard.damage(0)
		expect(zeroOk).toEqual(true)
		expect(zeroErr).toBeNil()
		expect(zero).toEqual(0)
		local partOk, part = RaidPracticeGuard.damage(0.5)
		expect(partOk).toEqual(true)
		expect(part).toEqual(0.5)
		local topOk, top, topErr = RaidPracticeGuard.damage(CONFIG.maxDamage)
		expect(topOk).toEqual(true)
		expect(topErr).toBeNil()
		expect(top).toEqual(CONFIG.maxDamage)
		local negOk, neg = RaidPracticeGuard.damage(-0)
		expect(negOk).toEqual(true)
		expect(neg).toEqual(0)
	end)

	it("refuses a negative, a non-number, and a value above the ceiling", function()
		local highOk, high, highErr = RaidPracticeGuard.damage(CONFIG.maxDamage + 1)
		expect(highOk).toEqual(false)
		expect(high).toBeNil()
		expect(highErr).toEqual(ERRORS.ceiling)
		local bigOk, big, bigErr = RaidPracticeGuard.damage(1e308)
		expect(bigOk).toEqual(false)
		expect(big).toBeNil()
		expect(bigErr).toEqual(ERRORS.ceiling)
		for _, amount in ipairs({ -1, "10", {}, true, false }) do
			local ok, value, err = RaidPracticeGuard.damage(amount)
			expect(ok).toEqual(false)
			expect(value).toBeNil()
			expect(err).toEqual(ERRORS.damage)
		end
		local nanOk, nanValue, nanErr = RaidPracticeGuard.damage(0 / 0)
		expect(nanOk).toEqual(false)
		expect(nanValue).toBeNil()
		expect(nanErr).toEqual(ERRORS.damage)
		local infOk, infValue, infErr = RaidPracticeGuard.damage(math.huge)
		expect(infOk).toEqual(false)
		expect(infValue).toBeNil()
		expect(infErr).toEqual(ERRORS.damage)
		local lowOk, lowValue, lowErr = RaidPracticeGuard.damage(-math.huge)
		expect(lowOk).toEqual(false)
		expect(lowValue).toBeNil()
		expect(lowErr).toEqual(ERRORS.damage)
	end)
end)

describe("RaidPracticeGuard fuzz", function()
	it("does not throw on garbage", function()
		local called = false
		local function boom()
			called = true
			error("remote called this")
		end
		local huge = string.rep("n", 8000)
		local cycle = { nested = {} }
		cycle.self = cycle
		cycle.nested.fn = boom
		local function check(value: any)
			local bossOk, bossValue, bossErr = RaidPracticeGuard.boss(value)
			refused(bossOk, bossValue, bossErr)
			local diffOk, diffValue, diffErr = RaidPracticeGuard.difficulty(value)
			refused(diffOk, diffValue, diffErr)
			local phaseOk, phaseValue, phaseErr = RaidPracticeGuard.phase(value, value)
			refused(phaseOk, phaseValue, phaseErr)
			local startOk, startValue, startErr = RaidPracticeGuard.start(value, value, value)
			refused(startOk, startValue, startErr)
			local mechanicOk, mechanicValue, mechanicErr =
				RaidPracticeGuard.mechanic(value, value, value, value)
			refused(mechanicOk, mechanicValue, mechanicErr)
			local toggleOk, toggleValue, toggleErr =
				RaidPracticeGuard.toggle(value, value, value, value, value)
			refused(toggleOk, toggleValue, toggleErr)
			local hitOk, hitValue, hitErr = RaidPracticeGuard.hit(value, value, value)
			refused(hitOk, hitValue, hitErr)
			local damageOk, damageValue, damageErr = RaidPracticeGuard.damage(value)
			refused(damageOk, damageValue, damageErr)
		end
		check(nil)
		local samples = {
			0 / 0,
			math.huge,
			-math.huge,
			true,
			false,
			{},
			{ {} },
			cycle,
			boom,
			huge,
			"",
			" ",
			-1,
			"1",
			"fracture",
			"guided",
		}
		for _, value in ipairs(samples) do
			check(value)
		end
		expect(called).toEqual(false)
	end)
end)

describe("RaidPracticeGuard isolation", function()
	it("reads wing rows only and is not required by src", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidPracticeGuard.luau")
		local required = string.find(source, 'require("./Raids")', 1, true)
		expect(required).toBeGreaterThan(0)
		expect(string.find(source, 'require("./RaidPractice")', 1, true)).toBeNil()
		expect(string.find(source, "applyClear", 1, true)).toBeNil()
		expect(string.find(source, "weekNumber", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "DataStoreService", 1, true)).toBeNil()
		expect(string.find(source, "MemoryStoreService", 1, true)).toBeNil()
		expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresGuard(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
