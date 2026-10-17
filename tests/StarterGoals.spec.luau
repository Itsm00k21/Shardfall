--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local StarterGoals = require("../src/ReplicatedStorage/Shared/StarterGoals")

local ERRORS = StarterGoals.ERRORS
local CONFIG = StarterGoals.CONFIG

local function identical(left: any, right: any): boolean
	return left == right
end

local function fresh()
	return StarterGoals.fresh().state
end

local function progress(overrides: { [string]: any }?)
	local row: { [string]: any } = {
		forge = 0,
		rootvault = 0,
		rolls = 0,
		level = 1,
		guild = false,
	}
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			row[key] = value
		end
	end
	return row
end

local function ready(paid: any)
	return progress({
		forge = 1,
		rootvault = 1,
		rolls = 10,
		level = 5,
		guild = true,
		paid = paid,
	})
end

local function blankGranted()
	return {
		forge = false,
		rootvault = false,
		rolls = false,
		level = false,
		guild = false,
	}
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

local function requiresGoals(source: string): boolean
	if string.find(source, "Shared.StarterGoals", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/StarterGoals", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.StarterGoals", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("StarterGoals")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('StarterGoals')", 1, true) ~= nil then
		return true
	end
	return false
end

describe("StarterGoals tracker", function()
	it("shows the first three goals in order", function()
		local opened = StarterGoals.fresh()
		expect(opened.ok).toEqual(true)
		expect(opened.state.returning).toEqual(false)
		expect(opened.state.granted).toEqual(blankGranted())
		expect(identical(opened.state, StarterGoals.fresh().state)).toEqual(false)
		expect(StarterGoals.fresh({}).state).toEqual(opened.state)
		expect(StarterGoals.fresh({ returning = false }).state).toEqual(opened.state)

		expect(StarterGoals.ORDER).toEqual({ "forge", "rootvault", "rolls", "level", "guild" })
		expect(CONFIG.visible).toEqual(3)
		expect(CONFIG.shardKeys).toEqual(10)
		expect(CONFIG.currency).toEqual("shardKeys")
		local texts = {}
		local goals = {}
		for index, id in ipairs(StarterGoals.ORDER) do
			expect(StarterGoals.GOALS[index].id).toEqual(id)
			table.insert(texts, StarterGoals.GOALS[index].text)
			table.insert(goals, StarterGoals.GOALS[index].goal)
		end
		expect(texts).toEqual({
			"Craft your first item at the Forge",
			"Clear Rootvault",
			"Roll 10 shards",
			"Reach Lv 5",
			"Join or browse a guild",
		})
		expect(goals).toEqual({ 1, 1, 10, 5, 1 })

		local state = opened.state
		local counts = progress()
		table.freeze(state)
		table.freeze(state.granted)
		table.freeze(counts)
		local shown = StarterGoals.show(state, counts)
		expect(shown.ok).toEqual(true)
		expect(shown.goals).toEqual({
			{
				id = "forge",
				text = "Craft your first item at the Forge",
				goal = 1,
				progress = 0,
				met = false,
			},
			{
				id = "rootvault",
				text = "Clear Rootvault",
				goal = 1,
				progress = 0,
				met = false,
			},
			{
				id = "rolls",
				text = "Roll 10 shards",
				goal = 10,
				progress = 0,
				met = false,
			},
		})
		expect(#shown.goals).toEqual(3)
		expect(identical(shown.state, state)).toEqual(false)
		expect(identical(shown.goals, StarterGoals.show(state, counts).goals)).toEqual(false)
		expect(identical(shown.goals[1], StarterGoals.GOALS[1])).toEqual(false)
		expect(state.granted).toEqual(blankGranted())
		expect(counts.forge).toEqual(0)
		expect(counts.level).toEqual(1)
	end)

	it("caps the bar at the goal and leaves a hidden goal unpaid", function()
		local state = fresh()
		local counts = progress({
			forge = 4,
			rootvault = 0,
			rolls = 9,
			level = 8,
			guild = true,
		})
		local shown = StarterGoals.show(state, counts)
		expect(shown.goals[1]).toEqual({
			id = "forge",
			text = "Craft your first item at the Forge",
			goal = 1,
			progress = 1,
			met = true,
		})
		expect(shown.goals[2].progress).toEqual(0)
		expect(shown.goals[2].met).toEqual(false)
		expect(shown.goals[3]).toEqual({
			id = "rolls",
			text = "Roll 10 shards",
			goal = 10,
			progress = 9,
			met = false,
		})
		expect(#shown.goals).toEqual(3)

		local hidden = StarterGoals.grant(state, "level", counts)
		expect(hidden.ok).toEqual(true)
		expect(hidden.accepted).toEqual(false)
		expect(hidden.keys).toEqual(0)
		expect(hidden.met).toEqual(true)
		expect(hidden.visible).toEqual(false)
		expect(hidden.payout).toBeNil()
		expect(hidden.state.granted.level).toEqual(false)
		expect(hidden.goals[1].id).toEqual("forge")
		expect(hidden.goals[3].id).toEqual("rolls")
		expect(state.granted.level).toEqual(false)

		local guild = StarterGoals.grant(state, "guild", counts)
		expect(guild.accepted).toEqual(false)
		expect(guild.keys).toEqual(0)
		expect(guild.met).toEqual(true)
		expect(guild.visible).toEqual(false)
		expect(guild.state.granted.guild).toEqual(false)
	end)
end)

describe("StarterGoals grant", function()
	it("pays ten keys once and reveals the next goal", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.granted)
		local counts = progress({ forge = 1, rolls = 100, level = 5 })
		table.freeze(counts)
		local granted = StarterGoals.grant(state, "forge", counts)
		expect(granted.ok).toEqual(true)
		expect(granted.accepted).toEqual(true)
		expect(granted.keys).toEqual(10)
		expect(granted.goal).toEqual("forge")
		expect(granted.met).toEqual(true)
		expect(granted.visible).toEqual(true)
		expect(granted.payout).toEqual({
			currency = "shardKeys",
			amount = 10,
			goal = "forge",
		})
		expect(granted.payout.paid).toBeNil()
		expect(granted.payout.robux).toBeNil()
		expect(granted.state.granted.forge).toEqual(true)
		expect(granted.state.granted.rootvault).toEqual(false)
		expect(granted.state.granted.rolls).toEqual(false)
		expect(granted.state.granted.level).toEqual(false)
		expect(granted.state.granted.guild).toEqual(false)
		expect(granted.goals[1].id).toEqual("rootvault")
		expect(granted.goals[2].id).toEqual("rolls")
		expect(granted.goals[2].progress).toEqual(10)
		expect(granted.goals[2].met).toEqual(true)
		expect(granted.goals[3].id).toEqual("level")
		expect(granted.goals[3].met).toEqual(true)
		expect(granted.goals[3].progress).toEqual(5)
		expect(#granted.goals).toEqual(3)
		expect(state.granted.forge).toEqual(false)
		expect(counts.forge).toEqual(1)
		expect(counts.rolls).toEqual(100)
		expect(identical(granted.state, state)).toEqual(false)
		expect(identical(granted, StarterGoals.grant(state, "forge", counts))).toEqual(false)

		local again = StarterGoals.grant(granted.state, "forge", counts)
		expect(again.ok).toEqual(true)
		expect(again.accepted).toEqual(false)
		expect(again.keys).toEqual(0)
		expect(again.met).toEqual(true)
		expect(again.visible).toEqual(false)
		expect(again.payout).toBeNil()
		expect(again.state.granted.forge).toEqual(true)
		expect(again.state.granted.level).toEqual(false)
		expect(granted.state.granted.level).toEqual(false)

		local revealed = StarterGoals.grant(granted.state, "level", counts)
		expect(revealed.accepted).toEqual(true)
		expect(revealed.keys).toEqual(10)
		expect(revealed.payout.amount).toEqual(10)
		expect(revealed.state.granted.level).toEqual(true)
		expect(revealed.state.granted.forge).toEqual(true)
		expect(revealed.goals[3].id).toEqual("guild")
		expect(granted.state.granted.level).toEqual(false)
	end)

	it("grants a visible goal out of order and does not cascade", function()
		local state = fresh()
		local counts = progress({ rootvault = 1, level = 5, guild = true })
		table.freeze(state)
		table.freeze(state.granted)
		table.freeze(counts)
		local early = StarterGoals.grant(state, "forge", counts)
		expect(early.ok).toEqual(true)
		expect(early.accepted).toEqual(false)
		expect(early.keys).toEqual(0)
		expect(early.met).toEqual(false)
		expect(early.visible).toEqual(true)
		expect(early.payout).toBeNil()
		expect(early.state.granted).toEqual(blankGranted())

		local cleared = StarterGoals.grant(state, "rootvault", counts)
		expect(cleared.accepted).toEqual(true)
		expect(cleared.keys).toEqual(10)
		expect(cleared.state.granted.rootvault).toEqual(true)
		expect(cleared.state.granted.forge).toEqual(false)
		expect(cleared.state.granted.level).toEqual(false)
		expect(cleared.goals[1].id).toEqual("forge")
		expect(cleared.goals[2].id).toEqual("rolls")
		expect(cleared.goals[3].id).toEqual("level")
		expect(cleared.goals[3].met).toEqual(true)
		expect(state.granted.rootvault).toEqual(false)
		expect(counts.rootvault).toEqual(1)
	end)

	it("pays fifty keys across the five goals and then nothing", function()
		local state = fresh()
		local counts = ready(false)
		local paid = 0
		local seen = {}
		for _, id in ipairs(StarterGoals.ORDER) do
			local result = StarterGoals.grant(state, id, counts)
			expect(result.accepted).toEqual(true)
			expect(result.keys).toEqual(10)
			expect(result.payout.currency).toEqual("shardKeys")
			expect(result.payout.amount).toEqual(10)
			expect(result.payout.goal).toEqual(id)
			paid += result.keys
			state = result.state
			table.insert(seen, id)
			local left = 5 - #seen
			local expectCount = left
			if expectCount > 3 then
				expectCount = 3
			end
			expect(#result.goals).toEqual(expectCount)
		end
		expect(paid).toEqual(50)
		expect(state.granted).toEqual({
			forge = true,
			rootvault = true,
			rolls = true,
			level = true,
			guild = true,
		})
		expect(StarterGoals.show(state, counts).goals).toEqual({})

		local again = StarterGoals.grant(state, "guild", ready(true))
		expect(again.ok).toEqual(true)
		expect(again.accepted).toEqual(false)
		expect(again.keys).toEqual(0)
		expect(again.payout).toBeNil()
		expect(again.goals).toEqual({})
		expect(again.state.granted.guild).toEqual(true)

		local dropped = StarterGoals.grant(state, "rolls", progress({ rolls = 0 }))
		expect(dropped.accepted).toEqual(false)
		expect(dropped.keys).toEqual(0)
		expect(dropped.state.granted.rolls).toEqual(true)
	end)

	it("skips a granted goal when choosing the next three", function()
		local state = {
			returning = false,
			granted = {
				forge = false,
				rootvault = false,
				rolls = true,
				level = false,
				guild = false,
			},
		}
		local shown = StarterGoals.show(state, ready(nil))
		expect(shown.ok).toEqual(true)
		expect(shown.goals[1].id).toEqual("forge")
		expect(shown.goals[2].id).toEqual("rootvault")
		expect(shown.goals[3].id).toEqual("level")
		expect(#shown.goals).toEqual(3)

		local guild = StarterGoals.grant(state, "guild", ready(false))
		expect(guild.accepted).toEqual(false)
		expect(guild.visible).toEqual(false)
		expect(guild.keys).toEqual(0)

		local level = StarterGoals.grant(state, "level", ready(false))
		expect(level.accepted).toEqual(true)
		expect(level.keys).toEqual(10)
		expect(level.state.granted.rolls).toEqual(true)
		expect(level.state.granted.level).toEqual(true)
		expect(level.goals[3].id).toEqual("guild")
		expect(state.granted.level).toEqual(false)
	end)
end)

describe("StarterGoals returning", function()
	it("shows nothing and pays nothing", function()
		local opened = StarterGoals.fresh({ returning = true })
		expect(opened.ok).toEqual(true)
		expect(opened.state.returning).toEqual(true)
		expect(opened.state.granted).toEqual(blankGranted())
		local counts = ready(true)
		table.freeze(opened.state)
		table.freeze(opened.state.granted)
		table.freeze(counts)
		local shown = StarterGoals.show(opened.state, counts)
		expect(shown.ok).toEqual(true)
		expect(shown.goals).toEqual({})
		expect(shown.state.returning).toEqual(true)
		expect(identical(shown.state, opened.state)).toEqual(false)

		for _, id in ipairs(StarterGoals.ORDER) do
			local result = StarterGoals.grant(opened.state, id, counts)
			expect(result.ok).toEqual(true)
			expect(result.accepted).toEqual(false)
			expect(result.keys).toEqual(0)
			expect(result.visible).toEqual(false)
			expect(result.met).toEqual(true)
			expect(result.payout).toBeNil()
			expect(result.goals).toEqual({})
			expect(result.state.granted).toEqual(blankGranted())
			expect(result.state.returning).toEqual(true)
		end
		expect(opened.state.granted).toEqual(blankGranted())
		expect(counts.paid).toEqual(true)
	end)
end)

describe("StarterGoals paid", function()
	it("pays the same ten keys for a paid grant and a free grant", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.granted)
		local function counts(paid: any)
			return progress({
				forge = 1,
				rolls = 40,
				paid = paid,
				odds = nil,
			})
		end
		local free = StarterGoals.grant(state, "forge", counts(false))
		local paid = StarterGoals.grant(state, "forge", counts(true))
		local omitted = StarterGoals.grant(state, "forge", counts(nil))
		expect(paid).toEqual(free)
		expect(omitted).toEqual(free)
		expect(paid.keys).toEqual(10)
		expect(paid.payout.amount).toEqual(10)
		expect(paid.payout.paid).toBeNil()
		expect(paid.payout.robux).toBeNil()
		expect(paid.state.granted.forge).toEqual(true)
		expect(state.granted.forge).toEqual(false)

		local short = StarterGoals.grant(state, "rolls", progress({ rolls = 9, paid = true }))
		local shortFree = StarterGoals.grant(state, "rolls", progress({ rolls = 9, paid = false }))
		expect(short).toEqual(shortFree)
		expect(short.accepted).toEqual(false)
		expect(short.keys).toEqual(0)
		expect(short.met).toEqual(false)
		expect(short.visible).toEqual(true)
		expect(short.state.granted.rolls).toEqual(false)

		local shownPaid = StarterGoals.show(state, counts(true))
		local shownFree = StarterGoals.show(state, counts(false))
		expect(shownPaid).toEqual(shownFree)
		expect(shownPaid.goals[1].id).toEqual("forge")
	end)

	it("refuses a paid skip and grants nothing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.granted)
		local function refused(extra: { [string]: any })
			local counts = ready(false)
			for key, value in pairs(extra) do
				counts[key] = value
			end
			table.freeze(counts)
			local result = StarterGoals.grant(state, "forge", counts)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.paid)
			expect(result.accepted).toEqual(false)
			expect(result.keys).toEqual(0)
			expect(result.payout).toBeNil()
			expect(result.goals).toEqual({})
			expect(result.state.granted).toEqual(blankGranted())
			expect(result.userId).toBeNil()
			expect(result.productId).toBeNil()
			local shown = StarterGoals.show(state, counts)
			expect(shown.ok).toEqual(false)
			expect(shown.error).toEqual(ERRORS.paid)
			expect(shown.goals).toEqual({})
		end
		refused({ productId = "skip_goals" })
		refused({ robux = 25 })
		refused({ robux = 0 })
		refused({ cost = 1 })
		refused({ cost = 0 })
		refused({ skip = true })
		refused({ skip = false })
		expect(state.granted).toEqual(blankGranted())
	end)
end)

describe("StarterGoals counts", function()
	it("meets each goal at its own count", function()
		local state = fresh()
		local function met(id: string, counts: { [string]: any }): boolean
			return StarterGoals.grant(state, id, counts).met
		end
		expect(met("forge", progress({ forge = 0 }))).toEqual(false)
		expect(met("forge", progress({ forge = 1 }))).toEqual(true)
		expect(met("rootvault", progress({ rootvault = 0 }))).toEqual(false)
		expect(met("rootvault", progress({ rootvault = 1 }))).toEqual(true)
		expect(met("rolls", progress({ rolls = 9 }))).toEqual(false)
		expect(met("rolls", progress({ rolls = 10 }))).toEqual(true)
		expect(met("level", progress({ level = 4 }))).toEqual(false)
		expect(met("level", progress({ level = 5 }))).toEqual(true)
		expect(met("guild", progress({ guild = false }))).toEqual(false)
		expect(met("guild", progress({ guild = true }))).toEqual(true)

		local rolls = StarterGoals.grant(state, "rolls", progress({ rolls = 10 }))
		expect(rolls.accepted).toEqual(true)
		expect(rolls.keys).toEqual(10)
		expect(rolls.goals[3].id).toEqual("level")
		expect(state.granted.rolls).toEqual(false)

		local earlyLevel = StarterGoals.grant(state, "level", progress({ level = 5, guild = true }))
		expect(earlyLevel.accepted).toEqual(false)
		expect(earlyLevel.keys).toEqual(0)
		expect(earlyLevel.visible).toEqual(false)
	end)
end)

describe("StarterGoals inputs", function()
	it("refuses a bad record, a user id, or a guild id without throwing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.granted)
		local counts = progress()
		expect(StarterGoals.fresh("no").error).toEqual(ERRORS.state)
		expect(StarterGoals.fresh({ returning = "yes" }).error).toEqual(ERRORS.state)
		expect(StarterGoals.fresh({ paid = true }).error).toEqual(ERRORS.state)
		expect(StarterGoals.fresh({ userId = 7 }).error).toEqual(ERRORS.state)
		expect(StarterGoals.show(nil, counts).error).toEqual(ERRORS.state)
		expect(StarterGoals.show(state, nil).error).toEqual(ERRORS.progress)
		expect(StarterGoals.grant(nil, "forge", counts).error).toEqual(ERRORS.state)
		expect(StarterGoals.grant(state, "forge", nil).error).toEqual(ERRORS.progress)
		expect(StarterGoals.grant(state, "haven", counts).error).toEqual(ERRORS.goal)
		expect(StarterGoals.grant(state, 1, counts).error).toEqual(ERRORS.goal)
		expect(StarterGoals.grant(state, "forge", counts).state.granted).toEqual(blankGranted())

		local function refuseId(key: string, value: any)
			local payload = progress({ [key] = value, forge = 1 })
			local granted = StarterGoals.grant(state, "forge", payload)
			expect(granted.ok).toEqual(false)
			expect(granted.error).toEqual(ERRORS.id)
			expect(granted.keys).toEqual(0)
			expect(granted.accepted).toEqual(false)
			expect(granted.goals).toEqual({})
			expect(granted.state.granted.forge).toEqual(false)
			expect(granted[key]).toBeNil()
			local shown = StarterGoals.show(state, payload)
			expect(shown.ok).toEqual(false)
			expect(shown.error).toEqual(ERRORS.id)
			expect(shown.goals).toEqual({})
			expect(shown[key]).toBeNil()
		end
		refuseId("userId", 15)
		refuseId("UserId", 15)
		refuseId("playerId", 15)
		refuseId("PlayerId", 15)
		refuseId("guildId", "grove")
		refuseId("GuildId", "grove")
		expect(state.granted).toEqual(blankGranted())

		expect(StarterGoals.grant(state, "forge", progress({ forge = -1 })).error).toEqual(
			ERRORS.progress
		)
		expect(StarterGoals.grant(state, "forge", progress({ forge = 1.5 })).error).toEqual(
			ERRORS.progress
		)
		expect(StarterGoals.grant(state, "rolls", progress({ rolls = 0 / 0 })).error).toEqual(
			ERRORS.progress
		)
		expect(StarterGoals.grant(state, "level", progress({ level = math.huge })).error).toEqual(
			ERRORS.progress
		)
		expect(StarterGoals.grant(state, "guild", progress({ guild = "grove" })).error).toEqual(
			ERRORS.progress
		)
		expect(StarterGoals.grant(state, "guild", progress({ guild = 1 })).error).toEqual(
			ERRORS.progress
		)
		expect(StarterGoals.show(state, progress({ paid = "yes" })).error).toEqual(ERRORS.progress)
		expect(StarterGoals.show(state, progress({ odds = 1 })).error).toEqual(ERRORS.progress)
		local missing = progress()
		missing.rolls = nil
		expect(StarterGoals.show(state, missing).error).toEqual(ERRORS.progress)

		expect(StarterGoals.grant({
			returning = false,
			granted = {
				forge = false,
				rootvault = false,
				rolls = false,
				level = false,
				guild = false,
				extra = true,
			},
		}, "forge", progress({ forge = 1 })).error).toEqual(ERRORS.state)
		expect(StarterGoals.show({ returning = false }, counts).error).toEqual(ERRORS.state)
		expect(state.granted).toEqual(blankGranted())
	end)

	it("freezes the goal tables", function()
		expect(function()
			StarterGoals.ERRORS.paid = "nope"
		end).toThrow()
		expect(function()
			StarterGoals.CONFIG.shardKeys = 99
		end).toThrow()
		expect(function()
			StarterGoals.CONFIG.visible = 5
		end).toThrow()
		expect(function()
			StarterGoals.ORDER[1] = "guild"
		end).toThrow()
		expect(function()
			StarterGoals.GOALS[1] = { id = "forge", text = "nope", goal = 1 }
		end).toThrow()
		expect(function()
			local row = StarterGoals.GOALS[1]
			row.text = "nope"
		end).toThrow()
	end)
end)

describe("StarterGoals isolation", function()
	it("is required by nothing in src and does not roll, wait, or read the clock", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/StarterGoals.luau")
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "FirstSession", 1, true)).toBeNil()
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
			if requiresGoals(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
