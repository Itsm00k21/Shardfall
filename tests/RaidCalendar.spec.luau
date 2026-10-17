--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidCalendar = require("../src/ReplicatedStorage/Shared/RaidCalendar")

local ERRORS = RaidCalendar.ERRORS
local NOW = 1000

local function clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = clone(child)
	end
	return copy
end

local function freezeDeep(value: any)
	if type(value) ~= "table" then
		return
	end
	for _, child in pairs(value) do
		freezeDeep(child)
	end
	if not table.isfrozen(value) then
		table.freeze(value)
	end
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

local function mentionsCalendar(source: string): boolean
	if string.find(source, "Shared.RaidCalendar", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidCalendar", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidCalendar", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidCalendar")', 1, true) ~= nil then
		return true
	end
	return false
end

local function schedule(state: any, id: any, startsAt: any, guildId: any, now: any): any
	return RaidCalendar.schedule(state, {
		guildId = if guildId == nil then "Grove" else guildId,
		id = id,
		startsAt = startsAt,
	}, if now == nil then NOW else now)
end

local function rsvp(state: any, userId: any, role: any, id: any, now: any, guildId: any): any
	return RaidCalendar.rsvp(state, {
		guildId = if guildId == nil then "Grove" else guildId,
		id = if id == nil then "Night" else id,
		userId = userId,
		role = role,
	}, if now == nil then NOW else now)
end

local function form(state: any, present: any, id: any, now: any, guildId: any): any
	return RaidCalendar.form(state, {
		guildId = if guildId == nil then "Grove" else guildId,
		id = if id == nil then "Night" else id,
		present = present,
	}, if now == nil then NOW else now)
end

local function mustOk(result: any): any
	if result.ok ~= true then
		error(result.error or "expected ok", 2)
	end
	return result
end

describe("RaidCalendar config", function()
	it("pins the roles and the caps", function()
		expect(RaidCalendar.CONFIG.maxEvents).toEqual(8)
		expect(RaidCalendar.CONFIG.maxRoleSlots).toEqual(3)
		expect(RaidCalendar.CONFIG.maxRsvps).toEqual(8)
		expect(RaidCalendar.CONFIG.maxIdLength).toEqual(64)
		expect(RaidCalendar.CONFIG.roles.tank).toEqual(true)
		expect(RaidCalendar.CONFIG.roles.healer).toEqual(true)
		expect(RaidCalendar.CONFIG.roles.dps).toEqual(true)
		expect(RaidCalendar.CONFIG.roles.flex).toEqual(true)
		expect(RaidCalendar.CONFIG.roles.lead).toBeNil()
		expect(RaidCalendar.CONFIG.roles.assistant).toBeNil()
		expect(RaidCalendar.CONFIG.roles.support).toBeNil()
		expect(RaidCalendar.CONFIG.doubleMarks).toBeNil()
		expect(RaidCalendar.CONFIG.tuesdayOffset).toBeNil()
		expect(RaidCalendar.ERRORS.role).toEqual("That role is unusable.")
		expect(RaidCalendar.ERRORS.roleFull).toEqual("That role is full.")
		expect(RaidCalendar.ERRORS.full).toEqual("That raid night list is full.")
		expect(RaidCalendar.ERRORS.rsvpsFull).toEqual("That RSVP list is full.")
		expect(RaidCalendar.ERRORS.missing).toEqual("That raid night is not on the calendar.")
		expect(RaidCalendar.ERRORS.past).toEqual("That raid night is already past.")
		expect(RaidCalendar.ERRORS.present).toEqual("That attendance list is unusable.")
		expect(RaidCalendar.ERRORS.skip).toEqual(
			"The guild calendar has no paid RSVP, extra slot, or skip."
		)
		local left = RaidCalendar.fresh()
		local right = RaidCalendar.fresh()
		expect(left).toEqual({ guilds = {} })
		expect(left == right).toEqual(false)
		local empty = RaidCalendar.view(nil, NOW)
		expect(empty.ok).toEqual(true)
		expect(empty.persist).toEqual(false)
		expect(empty.notice).toEqual(false)
		expect(empty.attended).toEqual({})
		expect(empty.night).toBeNil()
		expect(empty.state).toEqual({ guilds = {} })
		expect(empty.state == left).toEqual(false)
	end)

	it("freezes the config, the roles, and the errors", function()
		expect(function()
			RaidCalendar.CONFIG.maxEvents = 4
		end).toThrow()
		expect(function()
			RaidCalendar.CONFIG.roles.lead = true
		end).toThrow()
		expect(function()
			RaidCalendar.CONFIG.roles.tank = false
		end).toThrow()
		expect(function()
			RaidCalendar.ERRORS.skip = "nope"
		end).toThrow()
	end)

	it("stays pure and unrequired", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidCalendar.luau")
		local _, requires = string.gsub(source, "require%(", "")
		expect(requires).toEqual(0)
		local banned = {
			"math.random",
			"Random.new",
			"os.time",
			"os.clock",
			"os.date",
			"os.",
			"GetService",
			"DataStore",
			"MemoryStore",
			"MarketplaceService",
			"DateTime",
			"tick(",
			"task.wait",
			"require(",
			"RaidFinder",
			"RaidStrategy",
			"RaidLockout",
			"Raids",
			"Schema",
			"RaidService",
			"DungeonService",
			"Keybinds",
			"UiRouter",
			"HttpService",
			"MessagingService",
			"RemoteEvent",
			"FireServer",
			"FireClient",
			"weekKey",
			"doubleMarks",
			"tuesdayOffset",
			"Build.STAMP",
		}
		for _, needle in ipairs(banned) do
			expect(string.find(source, needle, 1, true)).toBeNil()
		end
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if
				path ~= "src/ReplicatedStorage/Shared/RaidCalendar.luau"
				and mentionsCalendar(fs.readFile(path))
			then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)

describe("RaidCalendar schedule", function()
	it("schedules a night and returns a new table", function()
		local request = {
			guildId = "  Grove  ",
			id = "  Night  ",
			startsAt = -0.0,
			userId = 4,
			practice = true,
			difficulty = "hard",
			bossId = "twins",
			loot = 1,
			marks = 9,
			weekKey = 2963,
			guided = true,
		}
		local input = {
			note = "keep",
			guilds = {},
		}
		local before = clone(input)
		freezeDeep(input)
		freezeDeep(request)
		local first = RaidCalendar.schedule(input, request, 0)
		expect(first.ok).toEqual(true)
		expect(first.persist).toEqual(true)
		expect(first.error).toBeNil()
		expect(first.notice).toEqual(false)
		expect(first.attended).toEqual({})
		expect(first.loot).toBeNil()
		expect(first.marks).toBeNil()
		expect(first.rewards).toBeNil()
		expect(first.sent).toBeNil()
		expect(first.state).toEqual({
			guilds = {
				{
					guildId = "Grove",
					nights = {
						{
							id = "Night",
							startsAt = 0,
							rsvps = {},
							formed = false,
							attended = {},
						},
					},
				},
			},
		})
		expect(first.state == input).toEqual(false)
		expect(first.night == first.state.guilds[1].nights[1]).toEqual(true)
		expect(input).toEqual(before)
		expect(first.state.note).toBeNil()
		expect(first.night.userId).toBeNil()
		expect(first.night.loot).toBeNil()

		local moved = schedule(first.state, "Night", NOW, "Grove", 0)
		expect(moved.ok).toEqual(true)
		expect(moved.persist).toEqual(true)
		expect(moved.state.guilds[1].nights[1].startsAt).toEqual(NOW)
		expect(moved.state.guilds[1].nights[1].id).toEqual("Night")
		expect(first.state.guilds[1].nights[1].startsAt).toEqual(0)
		expect(moved.state == first.state).toEqual(false)

		local other = mustOk(schedule(moved.state, "a", NOW))
		local third = mustOk(schedule(other.state, "A", NOW + 5))
		expect(third.state.guilds[1].nights[1].id).toEqual("Night")
		expect(third.state.guilds[1].nights[2].id).toEqual("a")
		expect(third.state.guilds[1].nights[3].id).toEqual("A")

		local same = schedule(third.state, "A", NOW + 5)
		expect(same.ok).toEqual(true)
		expect(same.persist).toEqual(false)
		expect(same.notice).toEqual(false)
		expect(same.state.guilds[1].nights).toEqual(third.state.guilds[1].nights)
		expect(same.state == third.state).toEqual(false)

		local cap = RaidCalendar.CONFIG.maxIdLength
		local fitted = mustOk(schedule(nil, string.rep("n", cap), NOW))
		expect(fitted.state.guilds[1].nights[1].id).toEqual(string.rep("n", cap))
		local atNow = mustOk(schedule(nil, "Edge", NOW))
		expect(atNow.state.guilds[1].nights[1].startsAt).toEqual(NOW)
	end)

	it("refuses a blank id or a bad time", function()
		local state = mustOk(schedule(nil, "keep", NOW + 50)).state
		freezeDeep(state)
		local cases = {
			{ "", NOW, ERRORS.id },
			{ "   ", NOW, ERRORS.id },
			{ 1, NOW, ERRORS.id },
			{ string.rep("n", RaidCalendar.CONFIG.maxIdLength + 1), NOW, ERRORS.id },
			{ "keep", NOW - 1, ERRORS.past },
			{ "new", -1, ERRORS.time },
			{ "new", 1.5, ERRORS.time },
			{ "new", 0 / 0, ERRORS.time },
			{ "new", math.huge, ERRORS.time },
			{ "new", -math.huge, ERRORS.time },
			{ "new", "1000", ERRORS.time },
			{ "new", nil, ERRORS.time },
		}
		for _, case in ipairs(cases) do
			local result = schedule(state, case[1], case[2])
			expect(result.ok).toEqual(false)
			expect(result.persist).toEqual(false)
			expect(result.notice).toEqual(false)
			expect(result.error).toEqual(case[3])
			expect(result.state.guilds[1].nights[1].startsAt).toEqual(NOW + 50)
			expect(#result.state.guilds[1].nights).toEqual(1)
		end
		expect(state.guilds[1].nights[1].id).toEqual("keep")
		local blankGuild = RaidCalendar.schedule(state, {
			guildId = "   ",
			id = "other",
			startsAt = NOW,
			player = { guildId = "Grove", userId = 9 },
		}, NOW)
		expect(blankGuild.ok).toEqual(false)
		expect(blankGuild.error).toEqual(ERRORS.guild)
		expect(#blankGuild.state.guilds[1].nights).toEqual(1)
		local numericGuild = schedule(state, "other", NOW, 12)
		expect(numericGuild.error).toEqual(ERRORS.guild)
		local longGuild = schedule(state, "other", NOW, string.rep("g", 65))
		expect(longGuild.error).toEqual(ERRORS.guild)
		local notTable = RaidCalendar.schedule(state, "Night", NOW)
		expect(notTable.error).toEqual(ERRORS.request)
		expect(notTable.persist).toEqual(false)
	end)

	it("refuses a new night when the guild list is full", function()
		local state = nil
		for index = 1, RaidCalendar.CONFIG.maxEvents do
			local result = mustOk(schedule(state, "N" .. index, NOW + index))
			state = result.state
		end
		expect(#state.guilds[1].nights).toEqual(8)
		local ninth = schedule(state, "N9", NOW + 9)
		expect(ninth.ok).toEqual(false)
		expect(ninth.persist).toEqual(false)
		expect(ninth.error).toEqual(ERRORS.full)
		expect(ninth.night).toBeNil()
		expect(#ninth.state.guilds[1].nights).toEqual(8)
		expect(ninth.state.guilds[1].nights[1].id).toEqual("N1")
		expect(ninth.state.guilds[1].nights[8].id).toEqual("N8")
		expect(state.guilds[1].nights[1].id).toEqual("N1")
		local moved = mustOk(schedule(state, "N1", NOW + 50))
		expect(#moved.state.guilds[1].nights).toEqual(8)
		expect(moved.state.guilds[1].nights[1].id).toEqual("N1")
		expect(moved.state.guilds[1].nights[1].startsAt).toEqual(NOW + 50)
		expect(moved.state.guilds[1].nights[2].id).toEqual("N2")
		local otherGuild = mustOk(schedule(state, "N1", NOW, "grove"))
		expect(#otherGuild.state.guilds).toEqual(2)
		expect(otherGuild.state.guilds[2].guildId).toEqual("grove")
		expect(#otherGuild.state.guilds[2].nights).toEqual(1)
		expect(#otherGuild.state.guilds[1].nights).toEqual(8)
	end)
end)

describe("RaidCalendar rsvp", function()
	it("gives one player one slot and upserts it", function()
		local night = mustOk(schedule(nil, "Night", NOW + 10)).state
		local input = clone(night)
		freezeDeep(night)
		local first = RaidCalendar.rsvp(night, {
			guildId = "Grove",
			id = "  Night  ",
			userId = 1,
			role = "  Tank  ",
			practice = true,
			difficulty = "story",
			bossId = "twins",
			loot = true,
			weekKey = 1,
		}, NOW)
		expect(first.ok).toEqual(true)
		expect(first.persist).toEqual(true)
		expect(first.notice).toEqual(false)
		expect(first.attended).toEqual({})
		expect(first.loot).toBeNil()
		expect(first.marks).toBeNil()
		expect(first.state.guilds[1].nights[1].rsvps).toEqual({
			{ userId = 1, role = "tank" },
		})
		expect(first.state == night).toEqual(false)
		expect(first.state.guilds[1].nights[1].rsvps == night.guilds[1].nights[1].rsvps).toEqual(
			false
		)
		expect(night).toEqual(input)
		expect(first.night.userId).toBeNil()

		local second = mustOk(rsvp(first.state, 2, " Healer "))
		local third = mustOk(rsvp(second.state, 3, "FLEX"))
		expect(third.state.guilds[1].nights[1].rsvps).toEqual({
			{ userId = 1, role = "tank" },
			{ userId = 2, role = "healer" },
			{ userId = 3, role = "flex" },
		})
		local moved = mustOk(rsvp(third.state, 2, "dps"))
		expect(moved.persist).toEqual(true)
		expect(moved.state.guilds[1].nights[1].rsvps).toEqual({
			{ userId = 1, role = "tank" },
			{ userId = 2, role = "dps" },
			{ userId = 3, role = "flex" },
		})
		expect(third.state.guilds[1].nights[1].rsvps[2].role).toEqual("healer")
		expect(#moved.state.guilds[1].nights[1].rsvps).toEqual(3)
		local same = rsvp(moved.state, 2, "dps")
		expect(same.ok).toEqual(true)
		expect(same.persist).toEqual(false)
		expect(same.notice).toEqual(false)
		expect(same.state.guilds[1].nights[1].rsvps).toEqual(moved.state.guilds[1].nights[1].rsvps)
		expect(same.state == moved.state).toEqual(false)
	end)

	it("refuses a bad player id, an unknown role, or a missing night", function()
		local state = mustOk(rsvp(mustOk(schedule(nil, "Night", NOW)).state, 7, "tank")).state
		freezeDeep(state)
		local cases = {
			{ "1", "tank", ERRORS.user },
			{ 0, "tank", ERRORS.user },
			{ -1, "tank", ERRORS.user },
			{ 1.5, "tank", ERRORS.user },
			{ 0 / 0, "tank", ERRORS.user },
			{ math.huge, "tank", ERRORS.user },
			{ nil, "tank", ERRORS.user },
			{ true, "dps", ERRORS.user },
			{ 8, "lead", ERRORS.role },
			{ 8, "assistant", ERRORS.role },
			{ 8, "Raid Lead", ERRORS.role },
			{ 8, "support", ERRORS.role },
			{ 8, "tank healer", ERRORS.role },
			{ 8, "", ERRORS.role },
			{ 8, "   ", ERRORS.role },
			{ 8, 1, ERRORS.role },
			{ 8, nil, ERRORS.role },
		}
		for _, case in ipairs(cases) do
			local result = rsvp(state, case[1], case[2])
			expect(result.ok).toEqual(false)
			expect(result.persist).toEqual(false)
			expect(result.notice).toEqual(false)
			expect(result.error).toEqual(case[3])
			expect(result.state.guilds[1].nights[1].rsvps).toEqual({
				{ userId = 7, role = "tank" },
			})
		end
		local missingRole = rsvp(state, 8, "lead", "Other")
		expect(missingRole.error).toEqual(ERRORS.role)
		local missingUser = rsvp(state, 0, "tank", "Other")
		expect(missingUser.error).toEqual(ERRORS.user)
		local missing = rsvp(state, 8, "dps", "Other")
		expect(missing.ok).toEqual(false)
		expect(missing.error).toEqual(ERRORS.missing)
		expect(missing.night).toBeNil()
		expect(#missing.state.guilds[1].nights).toEqual(1)
		expect(state.guilds[1].nights[1].rsvps[1].userId).toEqual(7)
	end)

	it("refuses a new player and a move when the role is full", function()
		local state = mustOk(schedule(nil, "Night", NOW + 5)).state
		for userId = 1, RaidCalendar.CONFIG.maxRoleSlots do
			state = mustOk(rsvp(state, userId, "tank")).state
		end
		local healer = mustOk(rsvp(state, 4, "healer"))
		state = healer.state
		expect(state.guilds[1].nights[1].rsvps).toEqual({
			{ userId = 1, role = "tank" },
			{ userId = 2, role = "tank" },
			{ userId = 3, role = "tank" },
			{ userId = 4, role = "healer" },
		})
		local blocked = rsvp(state, 5, "tank")
		expect(blocked.ok).toEqual(false)
		expect(blocked.persist).toEqual(false)
		expect(blocked.error).toEqual(ERRORS.roleFull)
		expect(blocked.night.rsvps).toEqual(state.guilds[1].nights[1].rsvps)
		expect(blocked.state.guilds[1].nights[1].rsvps[1].userId).toEqual(1)
		expect(#blocked.state.guilds[1].nights[1].rsvps).toEqual(4)
		local moved = rsvp(state, 4, "TANK")
		expect(moved.ok).toEqual(false)
		expect(moved.persist).toEqual(false)
		expect(moved.error).toEqual(ERRORS.roleFull)
		expect(moved.night.rsvps[4]).toEqual({ userId = 4, role = "healer" })
		expect(moved.state.guilds[1].nights[1].rsvps[1]).toEqual({ userId = 1, role = "tank" })
		expect(moved.state.guilds[1].nights[1].rsvps[2]).toEqual({ userId = 2, role = "tank" })
		expect(moved.state.guilds[1].nights[1].rsvps[3]).toEqual({ userId = 3, role = "tank" })
		expect(state.guilds[1].nights[1].rsvps[4].role).toEqual("healer")
		local opened = mustOk(rsvp(state, 1, "dps"))
		expect(opened.state.guilds[1].nights[1].rsvps[1]).toEqual({ userId = 1, role = "dps" })
		local filled = mustOk(rsvp(opened.state, 5, "tank"))
		expect(filled.state.guilds[1].nights[1].rsvps[5]).toEqual({ userId = 5, role = "tank" })
		expect(filled.state.guilds[1].nights[1].rsvps[1].role).toEqual("dps")
	end)

	it("refuses a new player when the RSVP list is full and keeps the old seats", function()
		local state = mustOk(schedule(nil, "Night", NOW + 5)).state
		local plan = {
			{ 1, "tank" },
			{ 2, "tank" },
			{ 3, "tank" },
			{ 4, "healer" },
			{ 5, "healer" },
			{ 6, "healer" },
			{ 7, "dps" },
			{ 8, "dps" },
		}
		for _, pair in ipairs(plan) do
			state = mustOk(rsvp(state, pair[1], pair[2])).state
		end
		expect(#state.guilds[1].nights[1].rsvps).toEqual(8)
		local flex = rsvp(state, 9, "flex")
		expect(flex.ok).toEqual(false)
		expect(flex.persist).toEqual(false)
		expect(flex.error).toEqual(ERRORS.rsvpsFull)
		expect(flex.state.guilds[1].nights[1].rsvps[1]).toEqual({ userId = 1, role = "tank" })
		expect(#flex.state.guilds[1].nights[1].rsvps).toEqual(8)
		local tank = rsvp(state, 9, "tank")
		expect(tank.error).toEqual(ERRORS.roleFull)
		expect(#tank.state.guilds[1].nights[1].rsvps).toEqual(8)
		local dps = rsvp(state, 9, "dps")
		expect(dps.error).toEqual(ERRORS.rsvpsFull)
		expect(state.guilds[1].nights[1].rsvps[1].userId).toEqual(1)
		local shifted = mustOk(rsvp(state, 8, "flex"))
		expect(shifted.persist).toEqual(true)
		expect(#shifted.state.guilds[1].nights[1].rsvps).toEqual(8)
		expect(shifted.state.guilds[1].nights[1].rsvps[8]).toEqual({ userId = 8, role = "flex" })
		expect(shifted.state.guilds[1].nights[1].rsvps[1].userId).toEqual(1)
		expect(state.guilds[1].nights[1].rsvps[8].role).toEqual("dps")
		local stillFull = rsvp(shifted.state, 9, "dps")
		expect(stillFull.error).toEqual(ERRORS.rsvpsFull)
		expect(#stillFull.state.guilds[1].nights[1].rsvps).toEqual(8)
	end)
end)

describe("RaidCalendar form", function()
	it("records who attended and sets the notice flag once", function()
		local state = mustOk(schedule(nil, "Night", NOW)).state
		state = mustOk(rsvp(state, 1, "tank")).state
		state = mustOk(rsvp(state, 2, "healer")).state
		state = mustOk(rsvp(state, 3, "dps")).state
		local input = clone(state)
		freezeDeep(state)
		local present = { 3, 99, 1 }
		freezeDeep(present)
		local formed = RaidCalendar.form(state, {
			guildId = "Grove",
			id = "Night",
			present = present,
			userId = 50,
			practice = true,
			loot = 1,
			bossId = "twins",
		}, NOW)
		expect(formed.ok).toEqual(true)
		expect(formed.persist).toEqual(true)
		expect(formed.notice).toEqual(true)
		expect(formed.error).toBeNil()
		expect(formed.sent).toBeNil()
		expect(formed.loot).toBeNil()
		expect(formed.attended).toEqual({ 1, 3 })
		expect(formed.night.formed).toEqual(true)
		expect(formed.night.attended).toEqual({ 1, 3 })
		expect(formed.attended == formed.night.attended).toEqual(true)
		expect(formed.night.rsvps[2].userId).toEqual(2)
		expect(state).toEqual(input)
		expect(present[1]).toEqual(3)

		local again = form(formed.state, { 1, 3 })
		expect(again.ok).toEqual(true)
		expect(again.persist).toEqual(false)
		expect(again.notice).toEqual(false)
		expect(again.attended).toEqual({ 1, 3 })
		expect(again.night.formed).toEqual(true)

		local changed = form(formed.state, { 2 })
		expect(changed.ok).toEqual(true)
		expect(changed.persist).toEqual(true)
		expect(changed.notice).toEqual(false)
		expect(changed.attended).toEqual({ 2 })
		expect(formed.state.guilds[1].nights[1].attended).toEqual({ 1, 3 })

		local quiet = mustOk(schedule(nil, "Empty", NOW + 1))
		local nobody = form(quiet.state, {}, "Empty")
		expect(nobody.ok).toEqual(true)
		expect(nobody.notice).toEqual(true)
		expect(nobody.attended).toEqual({})
		expect(nobody.night.formed).toEqual(true)
		expect(nobody.persist).toEqual(true)
	end)

	it("clears attendance when the night moves and can notice again", function()
		local state = mustOk(schedule(nil, "Night", NOW + 10)).state
		state = mustOk(rsvp(state, 4, "flex")).state
		state = mustOk(form(state, { 4 })).state
		expect(state.guilds[1].nights[1].formed).toEqual(true)
		local kept = schedule(state, "Night", NOW + 10)
		expect(kept.ok).toEqual(true)
		expect(kept.persist).toEqual(false)
		expect(kept.night.formed).toEqual(true)
		expect(kept.night.attended).toEqual({ 4 })
		expect(kept.night.rsvps).toEqual({ { userId = 4, role = "flex" } })
		local moved = mustOk(schedule(state, "Night", NOW + 30))
		expect(moved.notice).toEqual(false)
		expect(moved.night.formed).toEqual(false)
		expect(moved.night.attended).toEqual({})
		expect(moved.night.startsAt).toEqual(NOW + 30)
		expect(moved.night.rsvps).toEqual({ { userId = 4, role = "flex" } })
		expect(state.guilds[1].nights[1].formed).toEqual(true)
		local again = form(moved.state, { 4 })
		expect(again.ok).toEqual(true)
		expect(again.notice).toEqual(true)
		expect(again.persist).toEqual(true)
		expect(again.attended).toEqual({ 4 })
	end)

	it("refuses a bad attendance list and a night that is already gone", function()
		local state = mustOk(rsvp(mustOk(schedule(nil, "Night", NOW)).state, 1, "tank")).state
		freezeDeep(state)
		local cases = {
			nil,
			"1",
			{ 1, 1 },
			{ 0 },
			{ -1 },
			{ 1.5 },
			{ 0 / 0 },
			{ math.huge },
			{ true },
			{ 1, "2" },
			{ [1] = 1, [3] = 2 },
		}
		for _, present in ipairs(cases) do
			local result = form(state, present)
			expect(result.ok).toEqual(false)
			expect(result.persist).toEqual(false)
			expect(result.notice).toEqual(false)
			expect(result.attended).toEqual({})
			expect(result.error).toEqual(ERRORS.present)
			expect(result.night).toBeNil()
			expect(result.state.guilds[1].nights[1].formed).toEqual(false)
			expect(result.state.guilds[1].nights[1].rsvps).toEqual({
				{ userId = 1, role = "tank" },
			})
		end
		local missingPresent = form(state, "nope", "Other")
		expect(missingPresent.error).toEqual(ERRORS.present)
		local missing = form(state, { 1 }, "Other")
		expect(missing.ok).toEqual(false)
		expect(missing.error).toEqual(ERRORS.missing)
		expect(missing.notice).toEqual(false)
		expect(missing.attended).toEqual({})
		local late = form(state, { 1 }, "Night", NOW + 1)
		expect(late.ok).toEqual(false)
		expect(late.persist).toEqual(false)
		expect(late.notice).toEqual(false)
		expect(late.error).toEqual(ERRORS.missing)
		expect(#late.state.guilds).toEqual(0)
		expect(state.guilds[1].nights[1].id).toEqual("Night")
	end)
end)

describe("RaidCalendar prune", function()
	it("drops past nights and empty guilds", function()
		local early = mustOk(schedule(nil, "Old", 100, "Grove", 100))
		local both = mustOk(schedule(early.state, "New", 500, "Grove", 100))
		local formed = mustOk(form(both.state, {}, "Old", 100))
		expect(formed.state.guilds[1].nights[1].formed).toEqual(true)
		local seen = RaidCalendar.view(formed.state, 200)
		expect(seen.ok).toEqual(true)
		expect(seen.persist).toEqual(true)
		expect(seen.notice).toEqual(false)
		expect(seen.attended).toEqual({})
		expect(seen.state.guilds[1].nights).toEqual({
			{
				id = "New",
				startsAt = 500,
				rsvps = {},
				formed = false,
				attended = {},
			},
		})
		expect(formed.state.guilds[1].nights[1].id).toEqual("Old")
		local second = RaidCalendar.view(seen.state, 200)
		expect(second.ok).toEqual(true)
		expect(second.persist).toEqual(false)
		expect(#second.state.guilds[1].nights).toEqual(1)
		local edge = RaidCalendar.view(formed.state, 100)
		expect(edge.persist).toEqual(false)
		expect(#edge.state.guilds[1].nights).toEqual(2)
		local gone = RaidCalendar.view(formed.state, 501)
		expect(gone.persist).toEqual(true)
		expect(gone.state).toEqual({ guilds = {} })
		local hollow = RaidCalendar.view({
			guilds = {
				{ guildId = "Grove" },
			},
		}, NOW)
		expect(hollow.ok).toEqual(true)
		expect(hollow.persist).toEqual(true)
		expect(hollow.state).toEqual({ guilds = {} })
		local badClock = RaidCalendar.view(formed.state, 0 / 0)
		expect(badClock.ok).toEqual(false)
		expect(badClock.persist).toEqual(false)
		expect(badClock.error).toEqual(ERRORS.time)
		expect(badClock.notice).toEqual(false)
		expect(#badClock.state.guilds[1].nights).toEqual(2)
		expect(badClock.state.guilds[1].nights[1].id).toEqual("Old")
		local restarted = mustOk(schedule(formed.state, "Old", 800, "Grove", 200))
		expect(#restarted.state.guilds[1].nights).toEqual(2)
		expect(restarted.state.guilds[1].nights[2].id).toEqual("Old")
		expect(restarted.state.guilds[1].nights[2].rsvps).toEqual({})
		expect(restarted.state.guilds[1].nights[2].formed).toEqual(false)
		expect(restarted.state.guilds[1].nights[1].id).toEqual("New")
	end)

	it("does not persist a refusal that also pruned", function()
		local early = mustOk(schedule(nil, "Old", 100, "Grove", 100))
		local night = mustOk(schedule(early.state, "Night", 500, "Grove", 100))
		local state = night.state
		for userId = 1, 3 do
			state = mustOk(rsvp(state, userId, "tank", "Night", 100)).state
		end
		local before = clone(state)
		local refused = rsvp(state, 9, "tank", "Night", 200)
		expect(refused.ok).toEqual(false)
		expect(refused.persist).toEqual(false)
		expect(refused.error).toEqual(ERRORS.roleFull)
		expect(#refused.state.guilds[1].nights).toEqual(1)
		expect(refused.state.guilds[1].nights[1].id).toEqual("Night")
		expect(#refused.state.guilds[1].nights[1].rsvps).toEqual(3)
		expect(refused.state.guilds[1].nights[1].rsvps[1].userId).toEqual(1)
		expect(state).toEqual(before)
		local room = mustOk(schedule(state, "Night", 500, "Grove", 200))
		expect(room.persist).toEqual(true)
		expect(#room.state.guilds[1].nights).toEqual(1)
		expect(room.night.id).toEqual("Night")
		expect(#room.night.rsvps).toEqual(3)
	end)
end)

describe("RaidCalendar guards", function()
	it("refuses a paid RSVP, an extra slot, or a skip", function()
		local state = mustOk(schedule(nil, "Night", NOW)).state
		local names = {
			"skip",
			"waive",
			"waiveLock",
			"waiveLockout",
			"bypass",
			"bypassLock",
			"paid",
			"robux",
			"premium",
			"price",
			"productId",
			"gamePass",
			"force",
			"unlock",
			"skipLock",
			"skipLockout",
			"paidRsvp",
			"extraSlot",
			"buySlot",
			"skipCap",
			"paidSlot",
			"skipPrune",
		}
		for _, name in ipairs(names) do
			local request = {
				guildId = "Grove",
				id = "Night",
				startsAt = NOW + 5,
				userId = 3,
				role = "flex",
				present = { 3 },
			}
			request[name] = false
			local scheduled = RaidCalendar.schedule(nil, request, NOW)
			expect(scheduled.ok).toEqual(false)
			expect(scheduled.persist).toEqual(false)
			expect(scheduled.error).toEqual(ERRORS.skip)
			expect(scheduled.notice).toEqual(false)
			expect(scheduled.state).toEqual({ guilds = {} })
			local seated = RaidCalendar.rsvp(state, request, NOW)
			expect(seated.error).toEqual(ERRORS.skip)
			expect(seated.persist).toEqual(false)
			expect(seated.state.guilds[1].nights[1].rsvps).toEqual({})
			local formed = RaidCalendar.form(state, request, NOW)
			expect(formed.error).toEqual(ERRORS.skip)
			expect(formed.notice).toEqual(false)
			expect(formed.night).toBeNil()
			expect(formed.state.guilds[1].nights[1].formed).toEqual(false)
		end
		local forced = RaidCalendar.schedule(state, {
			guildId = "Grove",
			id = "Extra",
			startsAt = NOW,
			force = false,
		}, NOW)
		expect(forced.error).toEqual(ERRORS.skip)
		expect(#forced.state.guilds[1].nights).toEqual(1)
		local extra = RaidCalendar.schedule(state, {
			guildId = "Grove",
			id = "Extra",
			startsAt = NOW,
		}, NOW, {})
		expect(extra.ok).toEqual(false)
		expect(extra.persist).toEqual(false)
		expect(extra.error).toEqual(ERRORS.skip)
		expect(extra.state).toEqual({ guilds = {} })
		expect(extra.state == state).toEqual(false)
		expect(state.guilds[1].nights[1].id).toEqual("Night")
		local paidOnRecord = RaidCalendar.view({
			guilds = {
				{
					guildId = "Grove",
					paid = true,
					nights = {
						{
							id = "Night",
							startsAt = NOW,
							rsvps = {},
							formed = false,
							attended = {},
							loot = 5,
							robux = 1,
						},
					},
				},
			},
		}, NOW)
		expect(paidOnRecord.ok).toEqual(true)
		expect(paidOnRecord.persist).toEqual(false)
		expect(paidOnRecord.state.guilds[1].paid).toBeNil()
		expect(paidOnRecord.state.guilds[1].nights[1].loot).toBeNil()
		expect(paidOnRecord.state.guilds[1].nights[1].robux).toBeNil()
	end)

	it("refuses a broken record without trimming it", function()
		local function broken(state: any, now: any)
			local result = RaidCalendar.view(state, if now == nil then NOW else now)
			expect(result.ok).toEqual(false)
			expect(result.persist).toEqual(false)
			expect(result.error).toEqual(ERRORS.state)
			expect(result.notice).toEqual(false)
			expect(result.state).toEqual({ guilds = {} })
			expect(result.night).toBeNil()
		end

		local function night(extra: any): any
			local row = {
				id = "Night",
				startsAt = NOW,
				rsvps = {},
				formed = false,
				attended = {},
			}
			if type(extra) == "table" then
				for key, value in pairs(extra) do
					row[key] = value
				end
			end
			return row
		end

		local function book(nights: any, guildId: any): any
			return {
				guilds = {
					{
						guildId = if guildId == nil then "Grove" else guildId,
						nights = nights,
					},
				},
			}
		end

		broken("nope")
		broken(1)
		broken({ guilds = { [1] = { guildId = "Grove", nights = {} }, hole = true } })
		broken({
			guilds = {
				{ guildId = "Grove", nights = {} },
				{ guildId = "Grove", nights = {} },
			},
		})
		broken(book({
			night(nil),
			night({ id = "Night" }),
		}))
		broken(book({
			night({
				rsvps = {
					{ userId = 1, role = "tank" },
					{ userId = 1, role = "dps" },
				},
			}),
		}))
		broken(book({
			night({
				rsvps = {
					{ userId = 1, role = "Tank" },
				},
			}),
		}))
		broken(book({
			night({
				rsvps = {
					{ userId = 1, role = "tank" },
					{ userId = 2, role = "tank" },
					{ userId = 3, role = "tank" },
					{ userId = 4, role = "tank" },
				},
			}),
		}))
		local tooMany = {
			{ userId = 1, role = "tank" },
			{ userId = 2, role = "tank" },
			{ userId = 3, role = "tank" },
			{ userId = 4, role = "healer" },
			{ userId = 5, role = "healer" },
			{ userId = 6, role = "healer" },
			{ userId = 7, role = "dps" },
			{ userId = 8, role = "dps" },
			{ userId = 9, role = "dps" },
		}
		broken(book({ night({ rsvps = tooMany }) }))
		local crowded = {}
		for index = 1, 9 do
			table.insert(crowded, night({ id = "N" .. index }))
		end
		broken(book(crowded))
		broken(book({
			night({
				rsvps = {
					{ userId = 1, role = "tank" },
				},
				formed = true,
				attended = { 9 },
			}),
		}))
		broken(book({
			night({
				rsvps = {
					{ userId = 1, role = "tank" },
					{ userId = 2, role = "healer" },
				},
				formed = true,
				attended = { 2, 1 },
			}),
		}))
		broken(book({
			night({
				rsvps = {
					{ userId = 1, role = "tank" },
				},
				formed = false,
				attended = { 1 },
			}),
		}))
		broken(book({ night({ formed = "yes" }) }))
		broken(book({ night({ id = " Night" }) }))
		broken(book({ night({ startsAt = 0 / 0 }) }))
		broken(book({ night({ startsAt = -1 }) }))
		broken(book({ night({ startsAt = 1.5 }) }))
		broken({
			guilds = {
				{ guildId = " Grove", nights = {} },
			},
		})
		local kept = book({
			night({
				rsvps = {
					{ userId = 1, role = "tank" },
					{ userId = 2, role = "healer" },
				},
				formed = true,
				attended = { 1 },
			}),
		})
		local fine = RaidCalendar.view(kept, NOW)
		expect(fine.ok).toEqual(true)
		expect(fine.persist).toEqual(false)
		expect(fine.state.guilds[1].nights[1].attended).toEqual({ 1 })
		expect(fine.state.guilds[1].nights[1].formed).toEqual(true)
	end)
end)
