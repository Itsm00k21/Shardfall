--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidEcho = require("../src/ReplicatedStorage/Shared/RaidEcho")

local ERRORS = RaidEcho.ERRORS

local function identical(left: any, right: any): boolean
	return left == right
end

local function story(overrides: { [string]: any }?): { [string]: any }
	local ctx: { [string]: any } = {
		difficulty = "story",
		practice = false,
		pullStarted = true,
		wholeParty = true,
	}
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			ctx[key] = value
		end
	end
	return ctx
end

describe("RaidEcho config", function()
	it("pins 5 percent per wipe and a 25 percent cap", function()
		expect(RaidEcho.CONFIG.perWipe).toEqual(0.05)
		expect(RaidEcho.CONFIG.cap).toEqual(0.25)
	end)

	it("names the five difficulties and gives Echo to Story only", function()
		expect(RaidEcho.DIFFICULTIES).toEqual({
			story = true,
			normal = true,
			hard = true,
			shardbreaker = true,
			fracture = true,
		})
		expect(RaidEcho.ECHO).toEqual({
			story = true,
		})
	end)

	it("buffs damage, healing, and max HP", function()
		expect(RaidEcho.STATS).toEqual({
			damage = true,
			healing = true,
			maxHp = true,
		})
	end)

	it("freezes the thresholds, the lists, and the errors", function()
		expect(function()
			RaidEcho.CONFIG.perWipe = 1
		end).toThrow()
		expect(function()
			RaidEcho.CONFIG.cap = 1
		end).toThrow()
		expect(function()
			RaidEcho.ECHO.story = false
		end).toThrow()
		expect(function()
			RaidEcho.DIFFICULTIES.normal = false
		end).toThrow()
		expect(function()
			RaidEcho.STATS.damage = false
		end).toThrow()
		expect(function()
			RaidEcho.SKIPS.practice = false
		end).toThrow()
		expect(function()
			RaidEcho.REASONS.kill = false
		end).toThrow()
		expect(function()
			RaidEcho.ERRORS.state = "open"
		end).toThrow()
	end)

	it("has no Robux price", function()
		local banned = {
			robux = true,
			premium = true,
			productid = true,
			gamepass = true,
		}
		for key in pairs(RaidEcho.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
	end)
end)

describe("RaidEcho fresh", function()
	it("starts a run at zero stacks", function()
		expect(RaidEcho.fresh()).toEqual({ stacks = 0 })
	end)

	it("returns a new table each call", function()
		local first = RaidEcho.fresh()
		local second = RaidEcho.fresh()
		expect(identical(first, second)).toEqual(false)
	end)
end)

describe("RaidEcho bonus", function()
	it("is zero before any wipe", function()
		local view = RaidEcho.bonus(nil, "story")
		expect(view.ok).toEqual(true)
		expect(view.bonus).toEqual(0)
		expect(view.stacks).toEqual(0)
		expect(view.active).toEqual(false)
		expect(view.capped).toEqual(false)
		expect(view.difficulty).toEqual("story")
	end)

	it("adds 5 percent per stack up to 25 percent", function()
		local expected = { 0.05, 0.1, 0.15, 0.2, 0.25 }
		for stacks, fraction in ipairs(expected) do
			local view = RaidEcho.bonus({ stacks = stacks }, " Story ")
			expect(view.ok).toEqual(true)
			expect(view.bonus).toBeCloseTo(fraction)
			expect(view.stacks).toEqual(stacks)
			expect(view.active).toEqual(true)
			expect(view.capped).toEqual(stacks == 5)
		end
	end)

	it("holds the cap when the stored count is past five", function()
		local view = RaidEcho.bonus({ stacks = 100 }, "story")
		expect(view.ok).toEqual(true)
		expect(view.bonus).toBeCloseTo(0.25)
		expect(view.stacks).toEqual(100)
		expect(view.capped).toEqual(true)
	end)

	it("pays nothing on Normal, Hard, Shardbreaker, and Fracture", function()
		local names = { "normal", "hard", "shardbreaker", "fracture" }
		for _, name in ipairs(names) do
			local view = RaidEcho.bonus({ stacks = 5 }, " " .. name .. " ")
			expect(view.ok).toEqual(true)
			expect(view.bonus).toEqual(0)
			expect(view.stacks).toEqual(5)
			expect(view.active).toEqual(false)
			expect(view.capped).toEqual(false)
			expect(view.difficulty).toEqual(name)
		end
	end)

	it("treats a missing stack count as zero and drops other keys", function()
		local view = RaidEcho.bonus({}, "story")
		expect(view).toEqual({
			ok = true,
			bonus = 0,
			stacks = 0,
			difficulty = "story",
			active = false,
			capped = false,
		})
	end)

	it("rejects a record or a difficulty it cannot use", function()
		expect(RaidEcho.bonus(1, "story").error).toEqual(ERRORS.state)
		expect(RaidEcho.bonus({ stacks = -1 }, "story").error).toEqual(ERRORS.state)
		expect(RaidEcho.bonus({ stacks = 1.5 }, "story").error).toEqual(ERRORS.state)
		expect(RaidEcho.bonus({ stacks = "1" }, "story").error).toEqual(ERRORS.state)
		expect(RaidEcho.bonus({ stacks = 0 / 0 }, "story").error).toEqual(ERRORS.state)
		expect(RaidEcho.bonus({ stacks = math.huge }, "story").error).toEqual(ERRORS.state)
		expect(RaidEcho.bonus(nil, "guided").error).toEqual(ERRORS.difficulty)
		expect(RaidEcho.bonus(nil, "fracture1").error).toEqual(ERRORS.difficulty)
		expect(RaidEcho.bonus(nil, "").error).toEqual(ERRORS.difficulty)
		expect(RaidEcho.bonus(nil, nil).error).toEqual(ERRORS.difficulty)
		expect(RaidEcho.bonus({ stacks = 2 }, "guided").bonus).toEqual(0)
		expect(RaidEcho.bonus({ stacks = 2 }, "guided").stacks).toEqual(2)
	end)

	it("does not write the record", function()
		local state = table.freeze({ stacks = 2, userId = 9 })
		local view = RaidEcho.bonus(state, "story")
		expect(view.bonus).toBeCloseTo(0.1)
		expect(state.stacks).toEqual(2)
		expect(state.userId).toEqual(9)
	end)
end)

describe("RaidEcho wipe", function()
	it("counts a whole-party death after the pull on Story", function()
		local state = table.freeze({ stacks = 0 })
		local ctx = table.freeze(story())
		local result = RaidEcho.wipe(state, ctx)
		expect(result.ok).toEqual(true)
		expect(result.counted).toEqual(true)
		expect(result.added).toEqual(true)
		expect(result.stacks).toEqual(1)
		expect(result.bonus).toBeCloseTo(0.05)
		expect(result.capped).toEqual(false)
		expect(result.reason).toBeNil()
		expect(result.state).toEqual({ stacks = 1 })
		expect(identical(result.state, state)).toEqual(false)
		expect(state.stacks).toEqual(0)
	end)

	it("does not write the input when the same state is wiped twice", function()
		local state = table.freeze(RaidEcho.fresh())
		local ctx = table.freeze(story())
		local first = RaidEcho.wipe(state, ctx)
		local second = RaidEcho.wipe(state, ctx)
		expect(first.stacks).toEqual(1)
		expect(second.stacks).toEqual(1)
		expect(state.stacks).toEqual(0)
		expect(identical(first.state, second.state)).toEqual(false)
	end)

	it("stacks only when the caller passes the returned state", function()
		local state = RaidEcho.fresh()
		local nextState = state
		for _ = 1, 5 do
			local result = RaidEcho.wipe(nextState, story())
			expect(result.counted).toEqual(true)
			expect(result.added).toEqual(true)
			nextState = result.state
		end
		expect(nextState.stacks).toEqual(5)
		local view = RaidEcho.bonus(nextState, "story")
		expect(view.bonus).toBeCloseTo(0.25)
		expect(view.capped).toEqual(true)
		local sixth = RaidEcho.wipe(nextState, story())
		expect(sixth.ok).toEqual(true)
		expect(sixth.counted).toEqual(true)
		expect(sixth.added).toEqual(false)
		expect(sixth.capped).toEqual(true)
		expect(sixth.stacks).toEqual(5)
		expect(sixth.bonus).toBeCloseTo(0.25)
		expect(sixth.state).toEqual({ stacks = 5 })
	end)

	it("accepts a zero alive count as the whole party", function()
		local result = RaidEcho.wipe(nil, {
			difficulty = "story",
			pullStarted = true,
			alive = 0,
			party = 8,
		})
		expect(result.counted).toEqual(true)
		expect(result.stacks).toEqual(1)
	end)

	it("accepts partyDead, pulled, and practiceGrove aliases", function()
		local counted = RaidEcho.wipe(nil, {
			difficulty = "STORY",
			pulled = true,
			partyDead = true,
			practiceGrove = false,
		})
		expect(counted.counted).toEqual(true)
		expect(counted.stacks).toEqual(1)
		local grove = RaidEcho.wipe({ stacks = 2 }, {
			difficulty = "story",
			pulled = true,
			partyDead = true,
			practiceGrove = true,
		})
		expect(grove.counted).toEqual(false)
		expect(grove.reason).toEqual("practice")
		expect(grove.stacks).toEqual(2)
	end)

	it("ignores a player id and a boss id on the state", function()
		local state = table.freeze({ stacks = 1, userId = 4, bossId = "twins" })
		local result = RaidEcho.wipe(state, story({ bossId = "sapwell", userId = 8 }))
		expect(result.counted).toEqual(true)
		expect(result.state).toEqual({ stacks = 2 })
		expect(state.userId).toEqual(4)
		expect(state.bossId).toEqual("twins")
	end)

	it("does not reset when the boss id changes", function()
		local first = RaidEcho.wipe(nil, story({ bossId = "twins" }))
		local second = RaidEcho.wipe(first.state, story({ bossId = "sapwell" }))
		expect(second.stacks).toEqual(2)
		expect(second.bonus).toBeCloseTo(0.1)
	end)

	it("skips Practice Grove before the pull and the party", function()
		local result = RaidEcho.wipe(nil, {
			difficulty = "normal",
			practice = true,
			pullStarted = false,
			wholeParty = false,
		})
		expect(result.ok).toEqual(true)
		expect(result.counted).toEqual(false)
		expect(result.added).toEqual(false)
		expect(result.reason).toEqual("practice")
		expect(result.stacks).toEqual(0)
		expect(result.bonus).toEqual(0)
	end)

	it("skips a death before the pull, including a full party", function()
		local early = RaidEcho.wipe(nil, {
			difficulty = "story",
			pullStarted = false,
			wholeParty = true,
		})
		expect(early.reason).toEqual("pull")
		expect(early.stacks).toEqual(0)
		local missing = RaidEcho.wipe({ stacks = 1 }, {
			difficulty = "story",
			wholeParty = true,
		})
		expect(missing.reason).toEqual("pull")
		expect(missing.stacks).toEqual(1)
		expect(missing.state).toEqual({ stacks = 1 })
	end)

	it("skips a partial death before a difficulty that never gets Echo", function()
		local result = RaidEcho.wipe({ stacks = 3 }, {
			difficulty = "normal",
			pullStarted = true,
			alive = 1,
			party = 4,
		})
		expect(result.ok).toEqual(true)
		expect(result.reason).toEqual("partial")
		expect(result.stacks).toEqual(3)
		expect(result.bonus).toEqual(0)
	end)

	it("skips a pull that has not started before a partial death", function()
		local result = RaidEcho.wipe(nil, {
			difficulty = "story",
			pullStarted = false,
			wholeParty = false,
		})
		expect(result.reason).toEqual("pull")
	end)

	it("does not stack Normal, Hard, Shardbreaker, or Fracture", function()
		local names = { "normal", "Hard", "shardbreaker", " fracture " }
		for _, name in ipairs(names) do
			local result = RaidEcho.wipe({ stacks = 2 }, story({ difficulty = name }))
			expect(result.ok).toEqual(true)
			expect(result.counted).toEqual(false)
			expect(result.added).toEqual(false)
			expect(result.reason).toEqual("difficulty")
			expect(result.stacks).toEqual(2)
			expect(result.bonus).toEqual(0)
			expect(result.capped).toEqual(false)
			expect(result.state).toEqual({ stacks = 2 })
		end
	end)

	it("keeps a full cap from growing on a later Story wipe", function()
		local result = RaidEcho.wipe({ stacks = 100 }, story())
		expect(result.counted).toEqual(true)
		expect(result.added).toEqual(false)
		expect(result.stacks).toEqual(100)
		expect(result.bonus).toBeCloseTo(0.25)
		expect(result.capped).toEqual(true)
	end)

	it("rejects a wipe it cannot read and still returns a new state", function()
		local badState = RaidEcho.wipe({ stacks = -1 }, story())
		expect(badState.ok).toEqual(false)
		expect(badState.error).toEqual(ERRORS.state)
		expect(badState.state).toEqual({ stacks = 0 })
		local state = table.freeze({ stacks = 4 })
		local badCtx = RaidEcho.wipe(state, nil)
		expect(badCtx.error).toEqual(ERRORS.ctx)
		expect(badCtx.state).toEqual({ stacks = 4 })
		expect(identical(badCtx.state, state)).toEqual(false)
		expect(state.stacks).toEqual(4)
		expect(
			RaidEcho.wipe(state, { difficulty = "guided", pullStarted = true, wholeParty = true }).error
		).toEqual(ERRORS.difficulty)
		expect(RaidEcho.wipe(state, story({ practice = "yes" })).error).toEqual(ERRORS.practice)
		expect(RaidEcho.wipe(state, story({ pullStarted = 1 })).error).toEqual(ERRORS.pull)
		expect(RaidEcho.wipe(state, story({ practice = true, practiceGrove = false })).error).toEqual(
			ERRORS.disagree
		)
		expect(RaidEcho.wipe(state, { difficulty = "story", pullStarted = true }).error).toEqual(
			ERRORS.party
		)
		expect(RaidEcho.wipe(state, story({ wholeParty = false, alive = 0, party = 4 })).error).toEqual(
			ERRORS.disagree
		)
		expect(RaidEcho.wipe(state, {
			difficulty = "story",
			pullStarted = true,
			alive = 0,
			party = 0,
		}).error).toEqual(ERRORS.partySize)
		expect(RaidEcho.wipe(state, {
			difficulty = "story",
			pullStarted = true,
			alive = 2,
			party = 1,
		}).error).toEqual(ERRORS.alive)
		expect(RaidEcho.wipe(state, {
			difficulty = "story",
			pullStarted = true,
			living = 1,
			alive = 0,
			party = 4,
		}).error).toEqual(ERRORS.disagree)
		expect(RaidEcho.wipe(4, story()).error).toEqual(ERRORS.state)
	end)
end)

describe("RaidEcho reset", function()
	it("clears stacks on a boss kill", function()
		local state = table.freeze({ stacks = 4, bossId = "twins" })
		local result = RaidEcho.reset(state, { reason = " boss kill " })
		expect(result.ok).toEqual(true)
		expect(result.reason).toEqual("kill")
		expect(result.cleared).toEqual(true)
		expect(result.previous).toEqual(4)
		expect(result.stacks).toEqual(0)
		expect(result.state).toEqual({ stacks = 0 })
		expect(identical(result.state, state)).toEqual(false)
		expect(state.stacks).toEqual(4)
		expect(RaidEcho.bonus(result.state, "story").bonus).toEqual(0)
	end)

	it("clears stacks when the run ends", function()
		local result = RaidEcho.reset({ stacks = 2 }, "run end")
		expect(result.ok).toEqual(true)
		expect(result.reason).toEqual("end")
		expect(result.cleared).toEqual(true)
		expect(result.state).toEqual({ stacks = 0 })
		local kind = RaidEcho.reset({ stacks = 1 }, { kind = "end" })
		expect(kind.reason).toEqual("end")
		expect(kind.stacks).toEqual(0)
	end)

	it("lets the next pull start from zero", function()
		local wiped = RaidEcho.wipe({ stacks = 3 }, story())
		local cleared = RaidEcho.reset(wiped.state, "kill")
		local again = RaidEcho.wipe(cleared.state, story())
		expect(again.stacks).toEqual(1)
		expect(again.bonus).toBeCloseTo(0.05)
	end)

	it("reports a clear of an already empty run", function()
		local result = RaidEcho.reset(nil, "kill")
		expect(result.ok).toEqual(true)
		expect(result.cleared).toEqual(false)
		expect(result.previous).toEqual(0)
		expect(result.stacks).toEqual(0)
	end)

	it("refuses a wipe or a reset-before-pull as the reason", function()
		local state = table.freeze({ stacks = 3 })
		local wiped = RaidEcho.reset(state, "wipe")
		expect(wiped.ok).toEqual(false)
		expect(wiped.error).toEqual(ERRORS.reason)
		expect(wiped.stacks).toEqual(3)
		expect(wiped.cleared).toEqual(false)
		expect(identical(wiped.state, state)).toEqual(false)
		expect(state.stacks).toEqual(3)
		expect(RaidEcho.reset(state, "reset").error).toEqual(ERRORS.reason)
		expect(RaidEcho.reset(state, { reason = "kill", kind = "end" }).error).toEqual(
			ERRORS.disagree
		)
		expect(RaidEcho.reset(state, nil).error).toEqual(ERRORS.reason)
		expect(RaidEcho.reset(state, {}).error).toEqual(ERRORS.reason)
		expect(RaidEcho.reset({ stacks = "3" }, "kill").error).toEqual(ERRORS.state)
	end)
end)

describe("RaidEcho apply", function()
	it("multiplies damage, healing, and max HP by the same fraction", function()
		local state = table.freeze({ stacks = 2 })
		local damage = RaidEcho.apply({ kind = "damage", value = 100 }, state, "story")
		local healing = RaidEcho.apply({ kind = " heal ", amount = 80 }, state, "story")
		local maxHp = RaidEcho.apply({ name = "max HP", base = 1000 }, state, "story")
		expect(damage.ok).toEqual(true)
		expect(damage.kind).toEqual("damage")
		expect(damage.bonus).toBeCloseTo(0.1)
		expect(damage.multiplier).toBeCloseTo(1.1)
		expect(damage.value).toBeCloseTo(110)
		expect(healing.kind).toEqual("healing")
		expect(healing.value).toBeCloseTo(88)
		expect(maxHp.kind).toEqual("maxHp")
		expect(maxHp.value).toBeCloseTo(1100)
		expect(damage.multiplier).toBeCloseTo(healing.multiplier)
		expect(healing.multiplier).toBeCloseTo(maxHp.multiplier)
		expect(state.stacks).toEqual(2)
	end)

	it("uses the unbuffed number, so a second call compounds", function()
		local once = RaidEcho.apply({ kind = "damage", value = 100 }, { stacks = 1 }, "story")
		local twice = RaidEcho.apply(
			{ kind = "damage", value = once.value },
			{ stacks = 1 },
			"story"
		)
		expect(once.value).toBeCloseTo(105)
		expect(twice.value).toBeCloseTo(110.25)
	end)

	it("reaches plus 25 percent at five stacks and stops there", function()
		local applied = RaidEcho.apply(
			{ stat = "max_health", value = 200 },
			{ stacks = 5 },
			"story"
		)
		expect(applied.ok).toEqual(true)
		expect(applied.kind).toEqual("maxHp")
		expect(applied.bonus).toBeCloseTo(0.25)
		expect(applied.multiplier).toBeCloseTo(1.25)
		expect(applied.value).toBeCloseTo(250)
		expect(applied.capped).toBeNil()
		local past = RaidEcho.apply({ kind = "damage", value = 80 }, { stacks = 9 }, "story")
		expect(past.bonus).toBeCloseTo(0.25)
		expect(past.value).toBeCloseTo(100)
	end)

	it("leaves the number alone when Echo is off", function()
		local names = { "normal", "hard", "shardbreaker", "fracture" }
		for _, name in ipairs(names) do
			local applied = RaidEcho.apply({ kind = "damage", value = 100 }, { stacks = 5 }, name)
			expect(applied.ok).toEqual(true)
			expect(applied.bonus).toEqual(0)
			expect(applied.multiplier).toEqual(1)
			expect(applied.value).toEqual(100)
			expect(applied.difficulty).toEqual(name)
		end
		local fresh = RaidEcho.apply({ kind = "healing", value = 40 }, RaidEcho.fresh(), "story")
		expect(fresh.multiplier).toEqual(1)
		expect(fresh.value).toEqual(40)
	end)

	it("refuses current HP, boss damage, and any other kind", function()
		local stat = table.freeze({ kind = "health", value = 100 })
		local health = RaidEcho.apply(stat, { stacks = 5 }, "story")
		expect(health.ok).toEqual(false)
		expect(health.error).toEqual(ERRORS.kind)
		expect(health.value).toEqual(100)
		expect(stat.value).toEqual(100)
		local refused = { "hp", "currentHp", "bossDamage", "defense", "max" }
		for _, kind in ipairs(refused) do
			local result = RaidEcho.apply({ kind = kind, value = 50 }, { stacks = 5 }, "story")
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.kind)
			expect(result.value).toEqual(50)
		end
	end)

	it("rejects a stat, a record, or a difficulty it cannot use", function()
		expect(RaidEcho.apply(100, { stacks = 1 }, "story").error).toEqual(ERRORS.stat)
		expect(RaidEcho.apply({ kind = "damage" }, { stacks = 1 }, "story").error).toEqual(
			ERRORS.stat
		)
		expect(RaidEcho.apply({ value = 10 }, { stacks = 1 }, "story").error).toEqual(ERRORS.stat)
		expect(RaidEcho.apply({ kind = "damage", value = -1 }, { stacks = 1 }, "story").error).toEqual(
			ERRORS.value
		)
		expect(RaidEcho.apply({ kind = "damage", value = 0 / 0 }, { stacks = 1 }, "story").error).toEqual(
			ERRORS.value
		)
		expect(
			RaidEcho.apply({ kind = "damage", value = math.huge }, { stacks = 1 }, "story").error
		).toEqual(ERRORS.value)
		expect(RaidEcho.apply({
			kind = "damage",
			stat = "healing",
			value = 10,
		}, { stacks = 1 }, "story").error).toEqual(ERRORS.disagree)
		expect(RaidEcho.apply({
			kind = "damage",
			value = 10,
			amount = 11,
		}, { stacks = 1 }, "story").error).toEqual(ERRORS.disagree)
		local badDifficulty = RaidEcho.apply(
			{ kind = "damage", value = 12 },
			{ stacks = 1 },
			"guided"
		)
		expect(badDifficulty.error).toEqual(ERRORS.difficulty)
		expect(badDifficulty.value).toEqual(12)
		expect(RaidEcho.apply({ kind = "damage", value = 12 }, { stacks = -1 }, "story").error).toEqual(
			ERRORS.state
		)
		local zero = RaidEcho.apply({ kind = "maxHp", value = 0 }, { stacks = 5 }, "story")
		expect(zero.ok).toEqual(true)
		expect(zero.value).toEqual(0)
	end)

	it("does not write the stat", function()
		local stat = table.freeze({ kind = "damage", value = 100 })
		local state = table.freeze({ stacks = 1 })
		local applied = RaidEcho.apply(stat, state, "story")
		expect(applied.value).toBeCloseTo(105)
		expect(stat.value).toEqual(100)
		expect(state.stacks).toEqual(1)
	end)
end)
