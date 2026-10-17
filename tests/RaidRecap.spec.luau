--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidRecap = require("../src/ReplicatedStorage/Shared/RaidRecap")

local ERRORS = RaidRecap.ERRORS

local function keyList(value: any): { string }
	local keys = {}
	for key in pairs(value) do
		if type(key) == "string" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

local function containsNumber(value: any, target: number, depth: number): boolean
	if depth > 8 then
		return false
	end
	if value == target then
		return true
	end
	if type(value) ~= "table" then
		return false
	end
	for key, child in pairs(value) do
		if containsNumber(key, target, depth + 1) or containsNumber(child, target, depth + 1) then
			return true
		end
	end
	return false
end

local function containsString(value: any, target: string, depth: number): boolean
	if depth > 8 then
		return false
	end
	if value == target then
		return true
	end
	if type(value) ~= "table" then
		return false
	end
	for key, child in pairs(value) do
		if containsString(key, target, depth + 1) or containsString(child, target, depth + 1) then
			return true
		end
	end
	return false
end

describe("RaidRecap config", function()
	it("pins the tip cap and the four mechanic types", function()
		expect(RaidRecap.CONFIG.tipLimit).toEqual(2)
		expect(RaidRecap.MECHANICS).toEqual({ "soak", "interrupt", "stack", "add" })
		expect(RaidRecap.AFK_STATE).toEqual("remove")
		expect(RaidRecap.REMOVALS).toEqual({
			afk = true,
			kick = true,
		})
		expect(RaidRecap.PRESENT_STATES).toEqual({
			ok = true,
			warning = true,
			paused = true,
		})
	end)

	it("pins the placeholder tips, including Galecrown's Gust", function()
		expect(RaidRecap.CONFIG.tips).toEqual({
			twins = {
				soak = "Soak the merged twins with a partner.",
				spread = "Spread out for Briar's Thorn Volley.",
				stack = "Swap tanks before Splinter stacks reach 4.",
			},
			sapwell = {
				pool = "Move Sap Pools to the edge of the arena.",
				add = "Kill Saplings before they grow into Treants.",
				interrupt = "Interrupt Amber Prison to free your ally.",
			},
			galecrown = {
				gust = "Try using Blink on Galecrown's Gust.",
				stack = "Stack with the party for Moonlit Dive.",
				feather = "Stand behind a branch during Feather Storm.",
			},
			awakened = {
				soak = "Soak all four Heartroots at the same time.",
				interrupt = "Interrupt your platform's Heartwood Roar.",
				shield = "Break the Lumen shard before Thorn Wall closes.",
			},
		})
	end)

	it("freezes the thresholds, the tip table, and the errors", function()
		expect(function()
			RaidRecap.CONFIG.tipLimit = 9
		end).toThrow()
		expect(function()
			RaidRecap.CONFIG.tips.galecrown.gust = "no"
		end).toThrow()
		expect(function()
			RaidRecap.MECHANICS[1] = "gust"
		end).toThrow()
		expect(function()
			RaidRecap.ERRORS.removal = "open"
		end).toThrow()
		expect(function()
			RaidRecap.REMOVALS.afk = false
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
		for key in pairs(RaidRecap.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
	end)
end)

describe("RaidRecap panel", function()
	it("states your own damage, healing, deaths, and mechanics handled", function()
		local panel = RaidRecap.panel({
			userId = 1,
			damage = 1200,
			healing = 400,
			deaths = 2,
			mechanics = {
				soak = 6,
				interrupt = 1,
				stack = 2,
				add = 1,
			},
		})
		expect(panel.ok).toEqual(true)
		expect(panel.afk).toEqual(false)
		expect(panel.lines).toEqual({
			"You dealt 1200 damage",
			"You healed 400",
			"You died 2 times",
			"You soaked 6 times",
			"You interrupted 1 time",
			"You stacked 2 times",
			"You killed 1 add",
		})
		expect(panel.damage).toEqual(1200)
		expect(panel.healing).toEqual(400)
		expect(panel.deaths).toEqual(2)
		expect(panel.mechanics).toEqual({
			soak = 6,
			interrupt = 1,
			stack = 2,
			add = 1,
		})
		expect(panel.tips).toEqual({})
	end)

	it("uses the singular line for one of a kind and keeps a zero stat", function()
		local panel = RaidRecap.panel({
			userId = 4,
			deaths = 1,
			mechanics = { add = 1, soak = 0 },
		})
		expect(panel.lines).toEqual({
			"You dealt 0 damage",
			"You healed 0",
			"You died 1 time",
			"You killed 1 add",
		})
	end)

	it("accepts a trimmed mechanic name and omits a zero count", function()
		local panel = RaidRecap.panel({
			userId = 4,
			mechanics = { [" Soak "] = 6, interrupt = 0 },
		})
		expect(panel.lines).toEqual({
			"You dealt 0 damage",
			"You healed 0",
			"You died 0 times",
			"You soaked 6 times",
		})
	end)

	it("picks one or two tips from failures, sorted and capped", function()
		local panel = RaidRecap.panel({
			userId = 3,
			failures = {
				{ bossId = "twins", mechanic = "soak" },
				{ bossId = " Galecrown ", mechanic = " Gust " },
				{ bossId = "sapwell", mechanic = "add" },
			},
		})
		expect(panel.ok).toEqual(true)
		expect(panel.tips).toEqual({
			"Try using Blink on Galecrown's Gust.",
			"Kill Saplings before they grow into Treants.",
		})
	end)

	it("returns one tip when the player failed one known mechanic", function()
		local panel = RaidRecap.panel({
			userId = 3,
			failures = { { bossId = "awakened", mechanic = "interrupt" } },
		})
		expect(panel.tips).toEqual({
			"Interrupt your platform's Heartwood Roar.",
		})
	end)

	it("does not spend a tip slot on a duplicate or a zero count", function()
		local panel = RaidRecap.panel({
			userId = 3,
			failures = {
				{ bossId = "galecrown", mechanic = "gust", count = 0 },
				{ bossId = "galecrown", mechanic = "gust" },
				{ bossId = "galecrown", mechanic = "GUST", count = 2 },
				{ bossId = "sapwell", mechanic = "add" },
				{ bossId = "twins", mechanic = "spread" },
			},
		})
		expect(panel.tips).toEqual({
			"Try using Blink on Galecrown's Gust.",
			"Kill Saplings before they grow into Treants.",
		})
	end)

	it("skips a failure that has no placeholder tip", function()
		local panel = RaidRecap.panel({
			userId = 3,
			failures = {
				{ bossId = "grandmother_gnarl", mechanic = "gust" },
				{ bossId = "galecrown", mechanic = "gust" },
			},
		})
		expect(panel.ok).toEqual(true)
		expect(panel.tips).toEqual({
			"Try using Blink on Galecrown's Gust.",
		})
	end)

	it("still builds the private panel for an AFK removal", function()
		local removal = {
			ok = true,
			state = "remove",
			idleSeconds = 90,
			forfeitRewards = true,
			queueBackfill = true,
			keepMarks = false,
		}
		local panel = RaidRecap.panel({
			userId = 8,
			damage = 50,
			healing = 10,
			deaths = 1,
			mechanics = { soak = 6 },
			failures = { { bossId = "galecrown", mechanic = "gust" } },
			removal = removal,
		})
		expect(panel.ok).toEqual(true)
		expect(panel.afk).toEqual(true)
		expect(panel.lines[1]).toEqual("You dealt 50 damage")
		expect(panel.lines[4]).toEqual("You soaked 6 times")
		expect(panel.tips).toEqual({
			"Try using Blink on Galecrown's Gust.",
		})
		expect(removal.state).toEqual("remove")
		expect(removal.idleSeconds).toEqual(90)
	end)

	it("treats the remove state string as AFK and a warning as still present", function()
		local removed = RaidRecap.panel({
			userId = 8,
			removal = " Remove ",
		})
		local warned = RaidRecap.panel({
			userId = 8,
			removal = { ok = true, state = "warning", idleSeconds = 60 },
		})
		local paused = RaidRecap.panel({
			userId = 8,
			removal = { state = " Paused " },
		})
		expect(removed.afk).toEqual(true)
		expect(warned.afk).toEqual(false)
		expect(paused.afk).toEqual(false)
		expect(RaidRecap.panel({ userId = 8, removal = "kick" }).afk).toEqual(false)
		expect(RaidRecap.panel({ userId = 8 }).afk).toEqual(false)
	end)

	it("refuses a bad stat without echoing it", function()
		local panel = RaidRecap.panel({
			userId = 4,
			damage = -5,
			healing = 99,
		})
		expect(panel.ok).toEqual(false)
		expect(panel.userId).toEqual(4)
		expect(panel.damage).toEqual(0)
		expect(panel.healing).toEqual(0)
		expect(panel.lines).toEqual({})
		expect(panel.error).toEqual(ERRORS.damage)
		expect(RaidRecap.panel({ userId = 4, healing = 1.5 }).error).toEqual(ERRORS.healing)
		expect(RaidRecap.panel({ userId = 4, deaths = "2" }).error).toEqual(ERRORS.deaths)
		expect(RaidRecap.panel({ userId = 4, damage = 0 / 0 }).error).toEqual(ERRORS.damage)
	end)

	it("refuses an unknown mechanic, a bad failure, and a bad removal", function()
		expect(RaidRecap.panel({ userId = 4, mechanics = { soaks = 1 } }).error).toEqual(
			ERRORS.mechanic
		)
		expect(RaidRecap.panel({ userId = 4, mechanics = { [1] = 1 } }).error).toEqual(
			ERRORS.mechanics
		)
		expect(RaidRecap.panel({
			userId = 4,
			mechanics = { soak = 1, [" Soak "] = 2 },
		}).error).toEqual(ERRORS.mechanic)
		expect(RaidRecap.panel({
			userId = 4,
			failures = { { bossId = "galecrown" } },
		}).error).toEqual(ERRORS.failure)
		expect(RaidRecap.panel({
			userId = 4,
			failures = { { bossId = "galecrown", mechanic = "gust", count = -1 } },
		}).error).toEqual(ERRORS.failure)
		expect(RaidRecap.panel({ userId = 4, removal = "idle" }).error).toEqual(ERRORS.removal)
		expect(RaidRecap.panel({
			userId = 4,
			removal = { ok = false, state = "remove" },
		}).error).toEqual(ERRORS.removal)
		expect(RaidRecap.panel({
			userId = 4,
			removal = { ok = true, passed = true, forfeitRewards = false },
		}).error).toEqual(ERRORS.removal)
		expect(RaidRecap.panel("player").error).toEqual(ERRORS.member)
		expect(RaidRecap.panel({ userId = 0 }).userId).toEqual(0)
		expect(RaidRecap.panel({ userId = 0 }).error).toEqual(ERRORS.userId)
	end)
end)

describe("RaidRecap awards and kudos", function()
	local function party()
		return {
			{
				userId = 1,
				damage = 987654,
				healing = 123456,
				deaths = 9,
				mechanics = { soak = 2, interrupt = 1 },
			},
			{
				userId = 2,
				damage = 10,
				healing = 800,
				mechanics = { soak = 6, add = 3 },
				failures = { { bossId = "galecrown", mechanic = "gust" } },
			},
			{
				userId = 3,
				removal = "afk",
				damage = 5000,
				mechanics = { soak = 9, interrupt = 4, add = 8 },
				failures = { { bossId = "sapwell", mechanic = "add" } },
			},
		}
	end

	it("gives one MVP per mechanic and breaks ties by the lower user id", function()
		local view = RaidRecap.publicView({
			{ userId = 8, mechanics = { soak = 4, stack = 1 } },
			{ userId = 3, mechanics = { soak = 4, interrupt = 2 } },
			{ userId = 5, mechanics = { soak = 4, interrupt = 2, add = 0 } },
		}, nil)
		expect(view.ok).toEqual(true)
		expect(view.public.awards).toEqual({
			{ mechanic = "soak", userId = 3 },
			{ mechanic = "interrupt", userId = 3 },
			{ mechanic = "stack", userId = 8 },
		})
	end)

	it("leaves an AFK removal out of MVP even when they handled the most", function()
		local view = RaidRecap.publicView(party(), nil)
		expect(view.public.awards).toEqual({
			{ mechanic = "soak", userId = 2 },
			{ mechanic = "interrupt", userId = 1 },
			{ mechanic = "add", userId = 2 },
		})
	end)

	it("gives no award when nobody eligible handled that mechanic", function()
		local view = RaidRecap.publicView({
			{ userId = 1, removal = { state = "remove" }, mechanics = { soak = 6, add = 1 } },
			{ userId = 2, mechanics = { soak = 0 } },
		}, {})
		expect(view.ok).toEqual(true)
		expect(view.public.awards).toEqual({})
	end)

	it("keeps a vote-kick in MVP", function()
		local view = RaidRecap.publicView({
			{ userId = 2, removal = " Kick ", mechanics = { soak = 3 } },
			{ userId = 7, mechanics = { soak = 1 } },
		}, nil)
		expect(view.public.awards).toEqual({
			{ mechanic = "soak", userId = 2 },
		})
	end)

	it("never puts damage, healing, or anyone else's numbers on the public view", function()
		local members = party()
		local given = RaidRecap.give(members, nil, 1, 2)
		local view = RaidRecap.publicView(members, given.kudos)
		expect(view.ok).toEqual(true)
		expect(keyList(view.public)).toEqual({ "awards", "kudos" })
		expect(keyList(view.public.kudos[1])).toEqual({ "fromUserId", "toUserId" })
		expect(keyList(view.public.awards[1])).toEqual({ "mechanic", "userId" })
		expect(view.panels).toBeNil()
		expect(view.public.damage).toBeNil()
		expect(containsNumber(view.public, 987654, 0)).toEqual(false)
		expect(containsNumber(view.public, 123456, 0)).toEqual(false)
		expect(containsNumber(view.public, 5000, 0)).toEqual(false)
		expect(containsNumber(view.public, 9, 0)).toEqual(false)
		expect(containsNumber(view.public, 6, 0)).toEqual(false)
		expect(containsString(view.public, "You soaked 6 times", 0)).toEqual(false)
		expect(containsString(view.public, "Try using Blink on Galecrown's Gust.", 0)).toEqual(
			false
		)
	end)

	it("lets each present player give one kudos to someone else in the run", function()
		local members = party()
		local first = RaidRecap.give(members, nil, 1, 2)
		expect(first.ok).toEqual(true)
		expect(first.kudos).toEqual({
			{ fromUserId = 1, toUserId = 2 },
		})
		local second = RaidRecap.give(members, first.kudos, 2, 1)
		expect(second.ok).toEqual(true)
		expect(second.kudos).toEqual({
			{ fromUserId = 1, toUserId = 2 },
			{ fromUserId = 2, toUserId = 1 },
		})
		expect(#first.kudos).toEqual(1)
		local again = RaidRecap.give(members, second.kudos, 1, 2)
		expect(again.ok).toEqual(false)
		expect(again.error).toEqual(ERRORS.already)
		expect(again.kudos).toEqual(second.kudos)
		again.kudos[1].extra = true
		expect(second.kudos[1].extra).toBeNil()
	end)

	it("refuses self kudos, outsiders, and AFK givers or receivers", function()
		local members = party()
		local stored = RaidRecap.give(members, nil, 1, 2)
		expect(RaidRecap.give(members, stored.kudos, 1, 1).error).toEqual(ERRORS.selfKudos)
		expect(RaidRecap.give(members, stored.kudos, 9, 2).error).toEqual(ERRORS.absentSelf)
		expect(RaidRecap.give(members, stored.kudos, 1, 9).error).toEqual(ERRORS.absent)
		expect(RaidRecap.give(members, stored.kudos, 3, 1).error).toEqual(ERRORS.afkGive)
		expect(RaidRecap.give(members, stored.kudos, 1, 3).error).toEqual(ERRORS.afkReceive)
		expect(RaidRecap.give(members, stored.kudos, 3, 3).error).toEqual(ERRORS.selfKudos)
		expect(RaidRecap.give(members, stored.kudos, 1.5, 2).error).toEqual(ERRORS.userId)
		expect(#stored.kudos).toEqual(1)
		local paused = {
			{ userId = 1, removal = { state = "paused" } },
			{ userId = 2, removal = { ok = true, state = "warning" } },
		}
		expect(RaidRecap.give(paused, nil, 1, 2).ok).toEqual(true)
	end)

	it("drops a rule-breaking stored kudos and keeps the first legal one", function()
		local members = party()
		local view = RaidRecap.publicView(members, {
			{ fromUserId = 3, toUserId = 1, damage = 987654 },
			{ fromUserId = 1, toUserId = 1 },
			{ fromUserId = 1, toUserId = 2 },
			{ fromUserId = 1, toUserId = 2 },
			{ fromUserId = 2, toUserId = 1, healing = 123456 },
		})
		expect(view.ok).toEqual(true)
		expect(view.public.kudos).toEqual({
			{ fromUserId = 1, toUserId = 2 },
			{ fromUserId = 2, toUserId = 1 },
		})
		expect(containsNumber(view.public, 987654, 0)).toEqual(false)
	end)

	it("fails closed on a malformed kudos list", function()
		local members = party()
		local view = RaidRecap.publicView(members, {
			{ fromUserId = 1, toUserId = 2 },
			{ from = 2, to = 1 },
		})
		expect(view.ok).toEqual(false)
		expect(view.error).toEqual(ERRORS.kudosEntry)
		expect(view.public).toEqual({ kudos = {}, awards = {} })
		expect(RaidRecap.give(members, { { fromUserId = "1", toUserId = 2 } }, 2, 1).error).toEqual(
			ERRORS.kudosEntry
		)
		expect(
			RaidRecap.give(members, { [1] = { fromUserId = 1, toUserId = 2 }, [3] = {} }, 2, 1).error
		).toEqual(ERRORS.kudos)
	end)
end)

describe("RaidRecap recap", function()
	it("returns a private panel per player and a public view with no ranking", function()
		local members = {
			{
				userId = 1,
				damage = 987654,
				healing = 20,
				deaths = 0,
				mechanics = { soak = 6 },
				failures = {
					{ bossId = "twins", mechanic = "soak" },
					{ bossId = "galecrown", mechanic = "gust" },
				},
			},
			{
				userId = 2,
				damage = 5,
				healing = 123456,
				deaths = 2,
				removal = { ok = true, state = "remove" },
				mechanics = { soak = 8, interrupt = 1 },
				failures = { { bossId = "awakened", mechanic = "soak" } },
			},
		}
		local marker = members[1].mechanics
		local view = RaidRecap.recap({
			members = members,
			kudos = { { fromUserId = 1, toUserId = 2 } },
			bossId = "galecrown",
		})
		expect(view.ok).toEqual(true)
		expect(view.panels[1].lines[4]).toEqual("You soaked 6 times")
		expect(view.panels[1].tips).toEqual({
			"Try using Blink on Galecrown's Gust.",
			"Soak the merged twins with a partner.",
		})
		expect(view.panels[1].afk).toEqual(false)
		expect(view.panels[2].afk).toEqual(true)
		expect(view.panels[2].lines[4]).toEqual("You soaked 8 times")
		expect(view.panels[2].tips).toEqual({
			"Soak all four Heartroots at the same time.",
		})
		expect(containsNumber(view.panels[2], 987654, 0)).toEqual(false)
		expect(view.public.kudos).toEqual({})
		expect(view.public.awards).toEqual({
			{ mechanic = "soak", userId = 1 },
		})
		expect(containsNumber(view.public, 987654, 0)).toEqual(false)
		expect(containsNumber(view.public, 123456, 0)).toEqual(false)
		expect(marker.soak).toEqual(6)
		expect(members[1].lines).toBeNil()
	end)

	it("keeps private panels when the kudos list is malformed", function()
		local view = RaidRecap.recap({
			members = { { userId = 1, damage = 15, mechanics = { soak = 2 } } },
			kudos = { { fromUserId = 1 } },
		})
		expect(view.ok).toEqual(false)
		expect(view.error).toEqual(ERRORS.kudosEntry)
		expect(view.public).toEqual({ kudos = {}, awards = {} })
		expect(view.panels[1].ok).toEqual(true)
		expect(view.panels[1].lines[1]).toEqual("You dealt 15 damage")
		expect(view.panels[1].lines[4]).toEqual("You soaked 2 times")
	end)

	it("repeats the same result for the same input", function()
		local run = {
			members = {
				{
					userId = 4,
					damage = 10,
					mechanics = { interrupt = 2, soak = 2 },
					failures = { { bossId = "sapwell", mechanic = "pool" } },
				},
				{
					userId = 2,
					mechanics = { interrupt = 2, soak = 5 },
				},
			},
			kudos = { { fromUserId = 2, toUserId = 4 } },
		}
		expect(RaidRecap.recap(run)).toEqual(RaidRecap.recap(run))
		local view = RaidRecap.recap(run)
		expect(view.public.awards).toEqual({
			{ mechanic = "soak", userId = 2 },
			{ mechanic = "interrupt", userId = 2 },
		})
		expect(view.public.kudos).toEqual({
			{ fromUserId = 2, toUserId = 4 },
		})
		expect(view.panels[4].tips).toEqual({
			"Move Sap Pools to the edge of the arena.",
		})
	end)

	it("refuses a bad roster and does not publish a partial public view", function()
		local view = RaidRecap.recap({
			members = {
				{ userId = 1, mechanics = { soak = 4 } },
				{ userId = 1, mechanics = { soak = 9 } },
			},
		})
		expect(view.ok).toEqual(false)
		expect(view.error).toEqual(ERRORS.duplicate)
		expect(view.panels).toEqual({})
		expect(view.public).toEqual({ kudos = {}, awards = {} })
		expect(RaidRecap.recap(nil).error).toEqual(ERRORS.run)
		expect(RaidRecap.recap({}).error).toEqual(ERRORS.roster)
		expect(RaidRecap.publicView({ { userId = 1 }, { userId = 1 } }, nil).error).toEqual(
			ERRORS.duplicate
		)
		expect(RaidRecap.give({ { userId = "x" } }, nil, 1, 2).error).toEqual(ERRORS.userId)
	end)

	it("does not write into the caller's tables", function()
		local removal = { ok = true, state = "warning" }
		local failures = { { bossId = "galecrown", mechanic = "gust", count = 1 } }
		local kudos = { { fromUserId = 1, toUserId = 2, damage = 987654 } }
		local members = {
			{
				userId = 1,
				damage = 10,
				mechanics = { soak = 1 },
				failures = failures,
				removal = removal,
			},
			{ userId = 2, mechanics = { soak = 2 } },
		}
		local view = RaidRecap.recap({ members = members, kudos = kudos })
		expect(view.ok).toEqual(true)
		expect(view.public.kudos).toEqual({
			{ fromUserId = 1, toUserId = 2 },
		})
		expect(kudos[1].damage).toEqual(987654)
		expect(kudos[1].fromUserId).toEqual(1)
		expect(#kudos).toEqual(1)
		expect(failures[1].count).toEqual(1)
		expect(removal.state).toEqual("warning")
		expect(members[1].mechanics.soak).toEqual(1)
		expect(members[2].afk).toBeNil()
		view.public.kudos[1].fromUserId = 9
		expect(kudos[1].fromUserId).toEqual(1)
	end)
end)
