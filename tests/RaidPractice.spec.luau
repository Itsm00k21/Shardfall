--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidPractice = require("../src/ReplicatedStorage/Shared/RaidPractice")

local ERRORS = RaidPractice.ERRORS

local function identical(left: any, right: any): boolean
	return left == right
end

local function open(
	boss: string?,
	difficulty: string?,
	overrides: { [string]: any }?
): { [string]: any }
	local ctx: { [string]: any } = {
		bossId = boss or "twins",
		difficulty = difficulty or "story",
		unlocked = true,
	}
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			ctx[key] = value
		end
	end
	return ctx
end

local function started(boss: string?, difficulty: string?, overrides: { [string]: any }?): any
	local result = RaidPractice.fresh(open(boss, difficulty, overrides))
	expect(result.ok).toEqual(true)
	return result.state
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

local function requiresPractice(source: string): boolean
	if string.find(source, "Shared.RaidPractice", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidPractice", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidPractice", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidPractice")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('RaidPractice')", 1, true) ~= nil then
		return true
	end
	return false
end

describe("RaidPractice config", function()
	it("pins slow scale, three phases, and four on Shardbreaker", function()
		expect(RaidPractice.CONFIG).toEqual({
			slowScale = 0.75,
			phases = 3,
			shardbreakerPhases = 4,
		})
	end)

	it("names the four bosses and leaves dummies off that list", function()
		expect(RaidPractice.BOSSES).toEqual({
			twins = true,
			sapwell = true,
			galecrown = true,
			awakened = true,
		})
		expect(RaidPractice.BOSSES.dummy).toBeNil()
		expect(RaidPractice.BOSSES.dummies).toBeNil()
		expect(RaidPractice.BOSSES.grandmother).toBeNil()
	end)

	it("names story, normal, hard, and shardbreaker", function()
		expect(RaidPractice.DIFFICULTIES).toEqual({
			story = true,
			normal = true,
			hard = true,
			shardbreaker = true,
		})
		expect(RaidPractice.DIFFICULTIES.fracture).toBeNil()
		expect(RaidPractice.DIFFICULTIES.guided).toBeNil()
	end)

	it("freezes the thresholds, the lists, and the errors", function()
		expect(function()
			RaidPractice.CONFIG.slowScale = 1
		end).toThrow()
		expect(function()
			RaidPractice.CONFIG.phases = 1
		end).toThrow()
		expect(function()
			RaidPractice.CONFIG.shardbreakerPhases = 1
		end).toThrow()
		expect(function()
			RaidPractice.BOSSES.twins = false
		end).toThrow()
		expect(function()
			RaidPractice.DIFFICULTIES.story = false
		end).toThrow()
		expect(function()
			RaidPractice.ERRORS.state = "open"
		end).toThrow()
	end)

	it("has no Robux price", function()
		local banned = {
			robux = true,
			premium = true,
			productid = true,
			gamepass = true,
			price = true,
		}
		local count = 0
		for key in pairs(RaidPractice.CONFIG) do
			count += 1
			expect(banned[string.lower(key)]).toBeNil()
		end
		expect(count).toEqual(3)
	end)
end)

describe("RaidPractice fresh", function()
	it("starts a free sandbox at phase 1", function()
		local ctx = table.freeze({
			bossId = "twins",
			difficulty = "story",
			unlocked = true,
			now = 10,
			userId = 4,
		})
		local startedRun = RaidPractice.fresh(ctx)
		expect(startedRun.ok).toEqual(true)
		expect(startedRun.cost).toEqual(0)
		expect(startedRun.state).toEqual({
			bossId = "twins",
			difficulty = "story",
			phase = 1,
			slow = false,
			dummies = true,
			mechanics = {},
			damage = 0,
			deaths = 0,
			hits = {},
		})
		expect(ctx.now).toEqual(10)
		expect(ctx.userId).toEqual(4)
		expect(RaidPractice.scale(startedRun.state)).toEqual(1)
	end)

	it("returns a new table each call", function()
		local ctx = open()
		local first = RaidPractice.fresh(ctx)
		local second = RaidPractice.fresh(ctx)
		expect(identical(first, second)).toEqual(false)
		expect(identical(first.state, second.state)).toEqual(false)
		expect(identical(first.state.mechanics, second.state.mechanics)).toEqual(false)
		expect(identical(first.state.hits, second.state.hits)).toEqual(false)
		first.state.mechanics.gust = false
		expect(second.state.mechanics.gust).toBeNil()
	end)

	it("accepts every boss on every grove difficulty", function()
		local bosses = { "twins", "sapwell", "galecrown", "awakened" }
		local modes = { "story", "normal", "hard", "shardbreaker" }
		for _, boss in ipairs(bosses) do
			for _, mode in ipairs(modes) do
				local startedRun = RaidPractice.fresh({
					bossId = " " .. boss .. " ",
					difficulty = " " .. mode .. " ",
					unlocked = true,
				})
				expect(startedRun.ok).toEqual(true)
				expect(startedRun.cost).toEqual(0)
				expect(startedRun.state.bossId).toEqual(boss)
				expect(startedRun.state.difficulty).toEqual(mode)
				expect(startedRun.state.phase).toEqual(1)
			end
		end
	end)

	it("accepts the boss alias and a dummy flag", function()
		local startedRun = RaidPractice.fresh({
			boss = " Awakened ",
			bossId = "awakened",
			difficulty = " Hard ",
			unlocked = true,
			dummies = false,
		})
		expect(startedRun.ok).toEqual(true)
		expect(startedRun.state.bossId).toEqual("awakened")
		expect(startedRun.state.difficulty).toEqual("hard")
		expect(startedRun.state.dummies).toEqual(false)
	end)

	it("starts at phase 1 with slow off even if the context says otherwise", function()
		local startedRun = RaidPractice.fresh({
			bossId = "sapwell",
			difficulty = "shardbreaker",
			unlocked = true,
			phase = 4,
			slow = true,
			damage = 9,
			deaths = 2,
		})
		expect(startedRun.ok).toEqual(true)
		expect(startedRun.state.phase).toEqual(1)
		expect(startedRun.state.slow).toEqual(false)
		expect(startedRun.state.damage).toEqual(0)
		expect(startedRun.state.deaths).toEqual(0)
		expect(startedRun.state.mechanics).toEqual({})
		expect(startedRun.state.hits).toEqual({})
	end)

	it("rejects a start it cannot use", function()
		expect(RaidPractice.fresh(nil).error).toEqual(ERRORS.ctx)
		expect(RaidPractice.fresh("twins").error).toEqual(ERRORS.ctx)
		expect(RaidPractice.fresh({}).error).toEqual(ERRORS.boss)
		expect(RaidPractice.fresh({
			bossId = "twins",
		}).error).toEqual(ERRORS.difficulty)
		expect(RaidPractice.fresh({
			bossId = "twins",
			difficulty = "story",
		}).error).toEqual(ERRORS.unlock)
		expect(RaidPractice.fresh({
			bossId = "twins",
			difficulty = "story",
			unlocked = false,
		}).error).toEqual(ERRORS.unlocked)
		expect(RaidPractice.fresh({
			bossId = "twins",
			difficulty = "story",
			unlocked = "true",
		}).error).toEqual(ERRORS.unlock)
		expect(RaidPractice.fresh({
			bossId = "nope",
			difficulty = "fracture",
			unlocked = false,
		}).error).toEqual(ERRORS.boss)
		expect(RaidPractice.fresh({
			bossId = "grandmother",
			difficulty = "story",
			unlocked = true,
		}).error).toEqual(ERRORS.boss)
		expect(RaidPractice.fresh({
			bossId = "dummy",
			difficulty = "story",
			unlocked = true,
		}).error).toEqual(ERRORS.boss)
		expect(RaidPractice.fresh({
			bossId = "twins",
			boss = "sapwell",
			difficulty = "story",
			unlocked = true,
		}).error).toEqual(ERRORS.disagree)
	end)

	it("rejects fracture, guided, and a locked boss without starting", function()
		local names = { "fracture", "guided", "fracture1", "shard-breaker", "" }
		for _, name in ipairs(names) do
			local startedRun = RaidPractice.fresh({
				bossId = "twins",
				difficulty = name,
				unlocked = true,
			})
			expect(startedRun.ok).toEqual(false)
			expect(startedRun.error).toEqual(ERRORS.difficulty)
			expect(startedRun.cost).toEqual(0)
			expect(startedRun.state.bossId).toEqual("")
		end
		local locked = RaidPractice.fresh({
			bossId = "galecrown",
			difficulty = "normal",
			unlocked = false,
			dummies = "yes",
		})
		expect(locked.error).toEqual(ERRORS.unlocked)
		expect(locked.state.bossId).toEqual("")
		expect(locked.cost).toEqual(0)
	end)

	it("rejects a dummy flag that is not true or false", function()
		local startedRun = RaidPractice.fresh({
			bossId = "twins",
			difficulty = "story",
			unlocked = true,
			dummies = "yes",
		})
		expect(startedRun.ok).toEqual(false)
		expect(startedRun.error).toEqual(ERRORS.dummies)
		expect(startedRun.state.dummies).toEqual(true)
		expect(startedRun.state.bossId).toEqual("")
	end)
end)

describe("RaidPractice jump", function()
	it("moves inside the phase cap and keeps the record", function()
		local state = started("galecrown", "normal")
		state = RaidPractice.note(state, { damage = 12.5 }).state
		state = RaidPractice.note(state, { death = true }).state
		state = RaidPractice.note(state, { mechanicId = "Gust" }).state
		state = RaidPractice.toggle(state, "Gust", false).state
		state = RaidPractice.setSlow(state, true).state
		local cap = RaidPractice.CONFIG.phases
		local jumped = RaidPractice.jump(state, cap)
		expect(jumped.ok).toEqual(true)
		expect(jumped.phase).toEqual(cap)
		expect(jumped.state.phase).toEqual(cap)
		expect(jumped.state.bossId).toEqual("galecrown")
		expect(jumped.state.difficulty).toEqual("normal")
		expect(jumped.state.damage).toEqual(12.5)
		expect(jumped.state.deaths).toEqual(1)
		expect(jumped.state.hits).toEqual({ Gust = 1 })
		expect(jumped.state.mechanics).toEqual({ Gust = false })
		expect(jumped.state.slow).toEqual(true)
		expect(jumped.state.dummies).toEqual(true)
		expect(RaidPractice.scale(jumped.state)).toEqual(0.75)
		expect(state.phase).toEqual(1)
		expect(identical(jumped.state, state)).toEqual(false)
		expect(identical(jumped.state.hits, state.hits)).toEqual(false)
		expect(identical(jumped.state.mechanics, state.mechanics)).toEqual(false)
	end)

	it("allows phase 4 only on shardbreaker", function()
		local cap = RaidPractice.CONFIG.shardbreakerPhases
		local breaker = started("awakened", "shardbreaker")
		local opened = RaidPractice.jump(breaker, cap)
		expect(opened.ok).toEqual(true)
		expect(opened.state.phase).toEqual(4)
		expect(RaidPractice.jump(breaker, cap + 1).error).toEqual(ERRORS.phase)
		expect(RaidPractice.jump(breaker, 2.0).phase).toEqual(2)
		local modes = { "story", "normal", "hard" }
		for _, mode in ipairs(modes) do
			local state = started("twins", mode)
			expect(RaidPractice.jump(state, RaidPractice.CONFIG.phases).ok).toEqual(true)
			local refused = RaidPractice.jump(state, cap)
			expect(refused.ok).toEqual(false)
			expect(refused.error).toEqual(ERRORS.phase)
			expect(refused.state.phase).toEqual(1)
			expect(state.phase).toEqual(1)
		end
	end)

	it("rejects a phase that is not an in-range integer and returns a copy", function()
		local state = started()
		state = RaidPractice.note(state, { damage = 4 }).state
		local frozen = table.freeze(state)
		local hits = frozen.hits
		local bad = { 0, -1, 1.5, "2" }
		for _, phase in ipairs(bad) do
			local jumped = RaidPractice.jump(frozen, phase)
			expect(jumped.ok).toEqual(false)
			expect(jumped.error).toEqual(ERRORS.phase)
			expect(jumped.state.damage).toEqual(4)
			expect(jumped.state.phase).toEqual(1)
			expect(identical(jumped.state, frozen)).toEqual(false)
			expect(identical(jumped.state.hits, hits)).toEqual(false)
			expect(frozen.damage).toEqual(4)
			expect(frozen.phase).toEqual(1)
		end
		local missing = RaidPractice.jump(frozen, nil)
		expect(missing.error).toEqual(ERRORS.phase)
		expect(missing.state.damage).toEqual(4)
		local boxed = RaidPractice.jump(frozen, {})
		expect(boxed.error).toEqual(ERRORS.phase)
		expect(frozen.phase).toEqual(1)
	end)

	it("canonicalizes a hand-built record and drops extra keys", function()
		local state = {
			bossId = " Twins ",
			boss = "twins",
			difficulty = " Story ",
			phase = 1,
			userId = 9,
			now = 3,
			damage = 1,
		}
		local jumped = RaidPractice.jump(state, 2)
		expect(jumped.ok).toEqual(true)
		expect(jumped.state).toEqual({
			bossId = "twins",
			difficulty = "story",
			phase = 2,
			slow = false,
			dummies = true,
			mechanics = {},
			damage = 1,
			deaths = 0,
			hits = {},
		})
		expect(state.bossId).toEqual(" Twins ")
		expect(state.userId).toEqual(9)
		expect(state.phase).toEqual(1)
	end)

	it("refuses a stored phase the difficulty cannot hold", function()
		local state = {
			bossId = "twins",
			difficulty = "story",
			phase = 4,
			slow = false,
			dummies = true,
			mechanics = {},
			damage = 8,
			deaths = 1,
			hits = { Gust = 2 },
		}
		local jumped = RaidPractice.jump(state, 1)
		expect(jumped.ok).toEqual(false)
		expect(jumped.error).toEqual(ERRORS.state)
		expect(jumped.state.bossId).toEqual("")
		expect(state.damage).toEqual(8)
		expect(state.phase).toEqual(4)
	end)

	it("keeps dummies false across a jump", function()
		local state = started("sapwell", "hard", { dummies = false })
		local jumped = RaidPractice.jump(state, 1)
		expect(jumped.ok).toEqual(true)
		expect(jumped.state.dummies).toEqual(false)
		expect(identical(jumped.state, state)).toEqual(false)
	end)
end)

describe("RaidPractice slow", function()
	it("selects 0.75 or 1 and no other scale", function()
		local state = started()
		state = RaidPractice.note(state, { damage = 6 }).state
		state = RaidPractice.note(state, { mechanicId = "pool" }).state
		local on = RaidPractice.setSlow(state, true)
		expect(on.ok).toEqual(true)
		expect(on.slow).toEqual(true)
		expect(on.scale).toEqual(RaidPractice.CONFIG.slowScale)
		expect(on.scale).toEqual(0.75)
		expect(RaidPractice.scale(on.state)).toEqual(0.75)
		expect(on.state.damage).toEqual(6)
		expect(on.state.hits).toEqual({ pool = 1 })
		expect(state.slow).toEqual(false)
		expect(state.damage).toEqual(6)
		local off = RaidPractice.setSlow(on.state, false)
		expect(off.ok).toEqual(true)
		expect(off.scale).toEqual(1)
		expect(off.state.slow).toEqual(false)
		expect(off.state.damage).toEqual(6)
		expect(off.state.hits.pool).toEqual(1)
		expect(RaidPractice.scale(off.state)).toEqual(1)
		expect(on.state.slow).toEqual(true)
	end)

	it("rejects a requested scale and returns a copy", function()
		local state = started()
		state = RaidPractice.note(state, { damage = 3 }).state
		local frozen = table.freeze(state)
		local rejected = RaidPractice.setSlow(frozen, 0.5)
		expect(rejected.ok).toEqual(false)
		expect(rejected.error).toEqual(ERRORS.slow)
		expect(rejected.scale).toEqual(1)
		expect(rejected.state.slow).toEqual(false)
		expect(rejected.state.damage).toEqual(3)
		expect(identical(rejected.state, frozen)).toEqual(false)
		expect(frozen.damage).toEqual(3)
		expect(RaidPractice.setSlow(frozen, 1).error).toEqual(ERRORS.slow)
		expect(RaidPractice.setSlow(frozen, "true").error).toEqual(ERRORS.slow)
		expect(RaidPractice.setSlow(frozen, nil).error).toEqual(ERRORS.slow)
	end)

	it("returns 1 when the record does not parse", function()
		expect(RaidPractice.scale(nil)).toEqual(1)
		expect(RaidPractice.scale({})).toEqual(1)
		expect(RaidPractice.scale({ slow = true })).toEqual(1)
		expect(RaidPractice.scale(RaidPractice.fresh(nil).state)).toEqual(1)
	end)
end)

describe("RaidPractice toggle", function()
	it("stores an override and treats a missing id as unset", function()
		local state = started()
		expect(state.mechanics.gust).toBeNil()
		local off = RaidPractice.toggle(state, " gust ", false)
		expect(off.ok).toEqual(true)
		expect(off.mechanicId).toEqual("gust")
		expect(off.enabled).toEqual(false)
		expect(off.state.mechanics).toEqual({ gust = false })
		expect(state.mechanics.gust).toBeNil()
		local on = RaidPractice.toggle(off.state, "Gust", true)
		expect(on.state.mechanics.gust).toEqual(false)
		expect(on.state.mechanics.Gust).toEqual(true)
		expect(off.state.mechanics.Gust).toBeNil()
	end)

	it("does not reset the record", function()
		local state = started("twins", "story", { dummies = false })
		state = RaidPractice.jump(state, 2).state
		state = RaidPractice.setSlow(state, true).state
		state = RaidPractice.note(state, { damage = 5 }).state
		state = RaidPractice.note(state, { death = true }).state
		state = RaidPractice.note(state, { mechanicId = "soak" }).state
		local toggled = RaidPractice.toggle(state, "soak", false)
		expect(toggled.ok).toEqual(true)
		expect(toggled.state.phase).toEqual(2)
		expect(toggled.state.slow).toEqual(true)
		expect(toggled.state.dummies).toEqual(false)
		expect(toggled.state.damage).toEqual(5)
		expect(toggled.state.deaths).toEqual(1)
		expect(toggled.state.hits).toEqual({ soak = 1 })
		expect(toggled.state.mechanics.soak).toEqual(false)
		expect(state.mechanics.soak).toBeNil()
	end)

	it("rejects an empty mechanic or a switch that is not true or false", function()
		local state = started()
		state = RaidPractice.note(state, { damage = 2 }).state
		local frozen = table.freeze(state)
		local empty = RaidPractice.toggle(frozen, "  ", true)
		expect(empty.ok).toEqual(false)
		expect(empty.error).toEqual(ERRORS.mechanic)
		expect(empty.state.damage).toEqual(2)
		expect(empty.state.mechanics).toEqual({})
		expect(RaidPractice.toggle(frozen, "", false).error).toEqual(ERRORS.mechanic)
		expect(RaidPractice.toggle(frozen, 1, true).error).toEqual(ERRORS.mechanic)
		local flag = RaidPractice.toggle(frozen, "gust", "false")
		expect(flag.error).toEqual(ERRORS.enabled)
		expect(flag.state.mechanics).toEqual({})
		expect(RaidPractice.toggle(frozen, "gust", nil).error).toEqual(ERRORS.enabled)
		expect(frozen.damage).toEqual(2)
		expect(identical(empty.state, frozen)).toEqual(false)
	end)
end)

describe("RaidPractice note", function()
	it("adds a non-negative damage amount", function()
		local state = started()
		local first = RaidPractice.note(state, { damage = 10 })
		local second = RaidPractice.note(first.state, { amount = 2.5 })
		local third = RaidPractice.note(second.state, {
			kind = "damage",
			damage = 0,
			amount = 0,
		})
		expect(first.kind).toEqual("damage")
		expect(third.ok).toEqual(true)
		expect(third.state.damage).toEqual(12.5)
		expect(third.damage).toEqual(12.5)
		expect(third.state.deaths).toEqual(0)
		expect(third.state.hits).toEqual({})
		expect(state.damage).toEqual(0)
		expect(identical(third.state, second.state)).toEqual(false)
	end)

	it("adds one death per note and ignores a count", function()
		local state = started()
		local first = RaidPractice.note(state, { death = true })
		local second = RaidPractice.note(first.state, { kind = "death" })
		local third = RaidPractice.note(second.state, { kind = "dead" })
		local fourth = RaidPractice.note(third.state, { death = true, deaths = 5 })
		expect(fourth.ok).toEqual(true)
		expect(fourth.kind).toEqual("death")
		expect(fourth.state.deaths).toEqual(4)
		expect(fourth.deaths).toEqual(4)
		expect(fourth.state.damage).toEqual(0)
		local batch = RaidPractice.note(state, { deaths = 5 })
		expect(batch.ok).toEqual(false)
		expect(batch.error).toEqual(ERRORS.event)
		expect(batch.state.deaths).toEqual(0)
		expect(state.deaths).toEqual(0)
	end)

	it("increments one mechanic hit and still counts a mechanic that is off", function()
		local state = started()
		state = RaidPractice.toggle(state, "Gust", false).state
		local first = RaidPractice.note(state, { mechanicId = " Gust " })
		local second = RaidPractice.note(first.state, { hit = "Gust" })
		local third = RaidPractice.note(second.state, {
			kind = "hit",
			mechanic = "Gust",
			hits = 9,
		})
		expect(first.hits).toEqual(1)
		expect(third.ok).toEqual(true)
		expect(third.kind).toEqual("hit")
		expect(third.mechanicId).toEqual("Gust")
		expect(third.hits).toEqual(3)
		expect(third.state.hits).toEqual({ Gust = 3 })
		expect(third.state.mechanics).toEqual({ Gust = false })
		expect(third.state.deaths).toEqual(0)
		expect(third.state.damage).toEqual(0)
		expect(state.hits).toEqual({})
		local other = RaidPractice.note(third.state, { mechanicId = "soak" })
		expect(other.state.hits).toEqual({ Gust = 3, soak = 1 })
		expect(third.state.hits.soak).toBeNil()
	end)

	it("rejects a bad amount, a mixed note, and an empty hit", function()
		local state = started()
		state = RaidPractice.note(state, { damage = 4 }).state
		local frozen = table.freeze(state)
		local cases = {
			{ { damage = -1 }, ERRORS.damage },
			{ { damage = 0 / 0 }, ERRORS.damage },
			{ { damage = math.huge }, ERRORS.damage },
			{ { damage = "10" }, ERRORS.damage },
			{ { damage = 1, amount = 2 }, ERRORS.disagree },
			{ { damage = 1, death = true }, ERRORS.disagree },
			{ { amount = 0, hit = "gust" }, ERRORS.disagree },
			{ { kind = "damage", death = false, damage = 1 }, ERRORS.disagree },
			{ { kind = "damage", note = "death", damage = 1 }, ERRORS.disagree },
			{ { kind = "wipe" }, ERRORS.kind },
			{ { kind = "damage" }, ERRORS.damage },
			{ { kind = "hit" }, ERRORS.hit },
			{ { kind = "death", death = false }, ERRORS.disagree },
			{ { mechanicId = "a", hit = "b" }, ERRORS.disagree },
			{ { mechanicId = "  " }, ERRORS.mechanic },
			{ { death = false }, ERRORS.death },
			{ {}, ERRORS.event },
			{ nil, ERRORS.event },
			{ "damage", ERRORS.event },
		}
		for _, case in ipairs(cases) do
			local noted = RaidPractice.note(frozen, case[1])
			expect(noted.ok).toEqual(false)
			expect(noted.error).toEqual(case[2])
			expect(noted.state.damage).toEqual(4)
			expect(noted.state.deaths).toEqual(0)
			expect(noted.state.hits).toEqual({})
			expect(identical(noted.state, frozen)).toEqual(false)
		end
		expect(frozen.damage).toEqual(4)
	end)

	it("leaves the previous save in place when the total cannot grow", function()
		local huge = {
			bossId = "twins",
			difficulty = "story",
			phase = 1,
			slow = false,
			dummies = true,
			mechanics = {},
			damage = 1e308,
			deaths = 2 ^ 53,
			hits = { Gust = 2 ^ 53 },
		}
		local damage = RaidPractice.note(huge, { damage = 1e308 })
		expect(damage.ok).toEqual(false)
		expect(damage.error).toEqual(ERRORS.damage)
		expect(damage.state.damage).toEqual(1e308)
		expect(huge.damage).toEqual(1e308)
		local death = RaidPractice.note(huge, { death = true })
		expect(death.ok).toEqual(false)
		expect(death.error).toEqual(ERRORS.death)
		expect(death.state.deaths).toEqual(2 ^ 53)
		local hit = RaidPractice.note(huge, { mechanicId = "Gust" })
		expect(hit.ok).toEqual(false)
		expect(hit.error).toEqual(ERRORS.hit)
		expect(hit.state.hits.Gust).toEqual(2 ^ 53)
		expect(huge.hits.Gust).toEqual(2 ^ 53)
	end)

	it("does not change phase, slow, dummies, or boss", function()
		local state = started("sapwell", "hard", { dummies = false })
		state = RaidPractice.jump(state, 2).state
		state = RaidPractice.setSlow(state, true).state
		state = RaidPractice.toggle(state, "pool", false).state
		local noted = RaidPractice.note(state, { damage = 8 })
		expect(noted.state.phase).toEqual(2)
		expect(noted.state.slow).toEqual(true)
		expect(noted.state.dummies).toEqual(false)
		expect(noted.state.mechanics.pool).toEqual(false)
		expect(noted.state.bossId).toEqual("sapwell")
		expect(noted.state.difficulty).toEqual("hard")
		expect(noted.state.damage).toEqual(8)
	end)

	it("trims a matching pair of mechanic aliases", function()
		local state = started()
		local noted = RaidPractice.note(state, { mechanicId = " pool ", hit = "pool" })
		expect(noted.ok).toEqual(true)
		expect(noted.state.hits).toEqual({ pool = 1 })
	end)
end)

describe("RaidPractice rewards", function()
	it("stays empty after notes", function()
		local state = started("awakened", "shardbreaker")
		state = RaidPractice.jump(state, 4).state
		state = RaidPractice.note(state, { damage = 99 }).state
		state = RaidPractice.note(state, { death = true }).state
		state = RaidPractice.note(state, { mechanicId = "seasons" }).state
		local loot = RaidPractice.rewards(state)
		expect(loot).toEqual({
			ok = true,
			cost = 0,
			clear = false,
			lockout = false,
			leaderboard = false,
			gear = {},
			marks = 0,
			dust = 0,
			materials = {},
			pets = {},
			titles = {},
			cosmetics = {},
		})
		table.insert(loot.gear, "sword")
		loot.materials.sap = 3
		loot.marks = 40
		local again = RaidPractice.rewards(state)
		expect(again.ok).toEqual(true)
		expect(#again.gear).toEqual(0)
		expect(again.materials.sap).toBeNil()
		expect(again.marks).toEqual(0)
		expect(again.dust).toEqual(0)
		expect(again.clear).toEqual(false)
		expect(again.lockout).toEqual(false)
		expect(again.leaderboard).toEqual(false)
		expect(again.cost).toEqual(0)
		expect(#again.pets).toEqual(0)
		expect(#again.titles).toEqual(0)
		expect(#again.cosmetics).toEqual(0)
		expect(identical(loot, again)).toEqual(false)
		expect(identical(loot.gear, again.gear)).toEqual(false)
		expect(identical(loot.materials, again.materials)).toEqual(false)
	end)

	it("stays empty when the record does not parse", function()
		local loot = RaidPractice.rewards(nil)
		expect(loot.ok).toEqual(false)
		expect(loot.error).toEqual(ERRORS.state)
		expect(loot.cost).toEqual(0)
		expect(loot.clear).toEqual(false)
		expect(loot.lockout).toEqual(false)
		expect(loot.leaderboard).toEqual(false)
		expect(loot.marks).toEqual(0)
		expect(loot.dust).toEqual(0)
		expect(#loot.gear).toEqual(0)
		expect(#loot.pets).toEqual(0)
		expect(#loot.titles).toEqual(0)
		expect(#loot.cosmetics).toEqual(0)
	end)
end)

describe("RaidPractice isolation", function()
	it("does not write the tables it was given", function()
		local mechanics = { gust = false }
		local hits = { gust = 2 }
		local state = {
			bossId = "twins",
			difficulty = "story",
			phase = 1,
			slow = false,
			dummies = true,
			mechanics = mechanics,
			damage = 4,
			deaths = 1,
			hits = hits,
		}
		local noted = RaidPractice.note(state, { damage = 1 })
		expect(noted.ok).toEqual(true)
		expect(noted.state.damage).toEqual(5)
		expect(state.damage).toEqual(4)
		expect(mechanics.gust).toEqual(false)
		expect(hits.gust).toEqual(2)
		expect(identical(noted.state.mechanics, mechanics)).toEqual(false)
		expect(identical(noted.state.hits, hits)).toEqual(false)
		noted.state.mechanics.gust = true
		noted.state.hits.gust = 9
		expect(mechanics.gust).toEqual(false)
		expect(hits.gust).toEqual(2)
	end)

	it("is not required by src and does not reach a service", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidPractice.luau")
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresPractice(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
