--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidGuided = require("../src/ReplicatedStorage/Shared/RaidGuided")
local RaidMarks = require("../src/ReplicatedStorage/Shared/RaidMarks")

local ERRORS = RaidGuided.ERRORS
local REASONS = RaidGuided.REASONS

local function identical(left: any, right: any): boolean
	return left == right
end

local function opened(difficulty: string?, guildId: string?): any
	local result = RaidGuided.open({
		difficulty = difficulty or "hard",
		hostGuildId = guildId or "grove",
	})
	expect(result.ok).toEqual(true)
	expect(result.persist).toEqual(true)
	return result.state
end

local function admit(state: any, userId: number, guildId: string?, seeker: boolean?): any
	local joined = RaidGuided.join(state, {
		userId = userId,
		guildId = guildId,
		seeker = seeker,
	})
	expect(joined.ok).toEqual(true)
	expect(joined.error).toBeNil()
	return joined.state
end

local function swear(state: any, userId: number): any
	local sworn = RaidGuided.oath(state, userId, true)
	expect(sworn.ok).toEqual(true)
	expect(sworn.persist).toEqual(true)
	return sworn.state
end

local function party(hosts: number, seekers: number, guildId: string?): any
	local guild = guildId or "grove"
	local state = opened("hard", guild)
	for index = 1, hosts do
		state = admit(state, index, guild, false)
	end
	for index = 1, seekers do
		state = admit(state, 100 + index, "", true)
	end
	return state
end

local function ready(hosts: number, seekers: number): any
	local state = party(hosts, seekers)
	for _, member in ipairs(state.members) do
		state = swear(state, member.userId)
	end
	return state
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

local function mentionsGuided(source: string): boolean
	if string.find(source, "Shared.RaidGuided", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidGuided", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidGuided", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidGuided")', 1, true) ~= nil then
		return true
	end
	return false
end

describe("RaidGuided config", function()
	it("pins the score, the scale, and the party bounds", function()
		expect(RaidGuided.CONFIG.guideScore).toEqual(1)
		expect(RaidGuided.CONFIG.guidedPointScale).toEqual(2)
		expect(RaidGuided.CONFIG.minParty).toEqual(4)
		expect(RaidGuided.CONFIG.maxParty).toEqual(8)
		expect(RaidGuided.CONFIG.maxIdLength).toEqual(64)
		expect(RaidGuided.DIFFICULTIES.hard).toEqual(true)
		expect(RaidGuided.DIFFICULTIES.shardbreaker).toEqual(true)
		expect(RaidGuided.DIFFICULTIES.story).toBeNil()
		expect(RaidGuided.DIFFICULTIES.guided).toBeNil()
		expect(RaidGuided.REFUSED.story).toEqual(true)
		expect(RaidGuided.REFUSED.normal).toEqual(true)
		expect(RaidGuided.REFUSED.fracture).toEqual(true)
		expect(RaidGuided.REFUSED.practice).toEqual(true)
		expect(RaidGuided.REFUSED.guided).toEqual(true)
	end)

	it("freezes the config, the difficulties, and the errors", function()
		expect(function()
			RaidGuided.CONFIG.guideScore = 9
		end).toThrow()
		expect(function()
			RaidGuided.CONFIG.guidedPointScale = 1
		end).toThrow()
		expect(function()
			RaidGuided.DIFFICULTIES.story = true
		end).toThrow()
		expect(function()
			RaidGuided.REFUSED.hard = true
		end).toThrow()
		expect(function()
			RaidGuided.REASONS.kick = "allow"
		end).toThrow()
		expect(function()
			RaidGuided.ERRORS.kick = "fine"
		end).toThrow()
	end)

	it("has no Robux price and does not scale raid marks", function()
		local banned = {
			robux = true,
			premium = true,
			productid = true,
			gamepass = true,
			skip = true,
			price = true,
			marks = true,
			doublemarks = true,
		}
		for key in pairs(RaidGuided.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
		expect(RaidGuided.CONFIG.doubleMarks).toBeNil()
		expect(RaidMarks.CONFIG.doubleMarks).toEqual(false)
	end)
end)

describe("RaidGuided open", function()
	it("opens a Guided mode on Hard and Shardbreaker", function()
		local hard = RaidGuided.open({
			difficulty = " Hard ",
			hostGuildId = " Grove ",
		})
		expect(hard.ok).toEqual(true)
		expect(hard.persist).toEqual(true)
		expect(hard.error).toBeNil()
		expect(hard.state).toEqual({
			difficulty = "hard",
			hostGuildId = "Grove",
			members = {},
			finished = false,
			guideScore = 0,
			raidXp = 0,
			guidedPoints = 0,
		})

		local mythic = RaidGuided.open({
			difficulty = "SHARDBREAKER",
			hostGuildId = "grove",
		})
		expect(mythic.ok).toEqual(true)
		expect(mythic.state.difficulty).toEqual("shardbreaker")
		expect(identical(hard.state, mythic.state)).toEqual(false)
		expect(identical(hard.state.members, mythic.state.members)).toEqual(false)
	end)

	it("refuses Story, Normal, Fracture, Practice, and Guided", function()
		local refused = {
			"story",
			" Story ",
			"NORMAL",
			"fracture",
			"Fracture 3",
			"fracture-1",
			"practice",
			"Practice",
			"guided",
			"Guided",
			"heroic",
			"",
			"   ",
		}
		for _, difficulty in ipairs(refused) do
			local failed = RaidGuided.open({
				difficulty = difficulty,
				hostGuildId = "grove",
			})
			expect(failed.ok).toEqual(false)
			expect(failed.persist).toEqual(false)
			expect(failed.error).toEqual(ERRORS.difficulty)
			expect(failed.state.difficulty).toEqual("")
			expect(failed.state.members).toEqual({})
		end
		expect(RaidGuided.open({ difficulty = 1, hostGuildId = "grove" }).error).toEqual(
			ERRORS.difficulty
		)
	end)

	it("refuses a practice flag and a guided flag that is not true", function()
		local practice = RaidGuided.open({
			difficulty = "hard",
			hostGuildId = "grove",
			practice = true,
		})
		expect(practice.ok).toEqual(false)
		expect(practice.error).toEqual(ERRORS.practice)
		expect(practice.persist).toEqual(false)

		local wrong = RaidGuided.open({
			difficulty = "hard",
			hostGuildId = "grove",
			practice = "true",
		})
		expect(wrong.error).toEqual(ERRORS.practice)

		local off = RaidGuided.open({
			difficulty = "hard",
			hostGuildId = "grove",
			guided = false,
		})
		expect(off.error).toEqual(ERRORS.difficulty)
		expect(RaidGuided.open("hard").error).toEqual(ERRORS.open)
		expect(RaidGuided.open(nil).error).toEqual(ERRORS.open)
	end)

	it("starts empty and ignores a preloaded roster and a whole-guild size", function()
		local ctx = {
			difficulty = "hard",
			hostGuildId = "grove",
			guildSize = 2,
			members = {
				{ userId = 1, guildId = "grove", seeker = false, oath = true },
			},
			guideScore = 5,
		}
		table.freeze(ctx.members)
		table.freeze(ctx)
		local result = RaidGuided.open(ctx)
		expect(result.ok).toEqual(true)
		expect(result.state.members).toEqual({})
		expect(result.state.guideScore).toEqual(0)
		expect(result.state.guildSize).toBeNil()
		expect(ctx.guideScore).toEqual(5)
		expect(#ctx.members).toEqual(1)
		expect(RaidGuided.open({ difficulty = "hard", hostGuildId = "  " }).error).toEqual(
			ERRORS.guild
		)
		expect(RaidGuided.open({ difficulty = "hard", hostGuildId = 4 }).error).toEqual(
			ERRORS.guild
		)
	end)
end)

describe("RaidGuided roster", function()
	it("adds one host or one seeker per join", function()
		local state = opened()
		local host = RaidGuided.join(state, {
			userId = 1,
			guildId = "grove",
		})
		expect(host.ok).toEqual(true)
		expect(host.persist).toEqual(true)
		expect(host.seeker).toEqual(false)
		expect(host.size).toEqual(1)
		expect(host.hosts).toEqual(1)
		expect(host.seekers).toEqual(0)
		expect(host.state.members).toEqual({
			{ userId = 1, guildId = "grove", seeker = false, oath = false },
		})

		local seeker = RaidGuided.join(host.state, { userId = 9 })
		expect(seeker.ok).toEqual(true)
		expect(seeker.seeker).toEqual(true)
		expect(seeker.state.members[2]).toEqual({
			userId = 9,
			guildId = "",
			seeker = true,
			oath = false,
		})
		expect(#state.members).toEqual(0)
	end)

	it("refuses a batch, a party field, and a second join argument", function()
		local state = opened()
		local batch = RaidGuided.join(state, {
			{ userId = 1, guildId = "grove" },
			{ userId = 2, guildId = "grove" },
		})
		expect(batch.ok).toEqual(false)
		expect(batch.error).toEqual(ERRORS.seeker)
		expect(batch.state.members).toEqual({})

		local withParty = RaidGuided.join(state, {
			userId = 1,
			guildId = "grove",
			companions = { 2 },
		})
		expect(withParty.error).toEqual(ERRORS.seeker)
		expect(RaidGuided.join(state, { userId = 1, guildId = "grove", party = 1 }).error).toEqual(
			ERRORS.seeker
		)
		expect(RaidGuided.join(state, { userId = 1, guildId = "grove", with = { 2 } }).error).toEqual(
			ERRORS.seeker
		)
		local extra = RaidGuided.join(state, { userId = 1, guildId = "grove" }, { userId = 2 })
		expect(extra.error).toEqual(ERRORS.seeker)
		expect(#state.members).toEqual(0)
	end)

	it("keeps guide slots for the host guild and seeker slots for everyone else", function()
		local state = opened("hard", "Grove")
		local claimed = RaidGuided.join(state, {
			userId = 1,
			guildId = "Grove",
			seeker = true,
		})
		expect(claimed.error).toEqual(ERRORS.seeker)
		expect(claimed.state.members).toEqual({})

		local outsider = RaidGuided.join(state, {
			userId = 2,
			guildId = "other",
			seeker = false,
		})
		expect(outsider.error).toEqual(ERRORS.host)

		local otherGuild = RaidGuided.join(state, {
			userId = 3,
			guildId = "other",
		})
		expect(otherGuild.ok).toEqual(true)
		expect(otherGuild.seeker).toEqual(true)
		expect(otherGuild.state.members[1].guildId).toEqual("other")

		local wrongCase = RaidGuided.join(otherGuild.state, {
			userId = 4,
			guildId = "grove",
		})
		expect(wrongCase.seeker).toEqual(true)

		local trimmed = RaidGuided.join(state, {
			userId = 5,
			guildId = " Grove ",
		})
		expect(trimmed.ok).toEqual(true)
		expect(trimmed.seeker).toEqual(false)
		expect(trimmed.state.members[1].guildId).toEqual("Grove")
	end)

	it("uses half of this run, not half of the whole guild", function()
		local four = ready(2, 2)
		local counted = RaidGuided.finish(four, 10)
		expect(counted.ok).toEqual(true)
		expect(counted.counted).toEqual(true)
		expect(counted.guideScore).toEqual(1)

		local state = opened()
		state = admit(state, 1, "grove", false)
		state = admit(state, 2, "grove", false)
		for index = 1, 4 do
			state = admit(state, 100 + index, "", true)
		end
		expect(RaidGuided.view(state).size).toEqual(6)
		local blocked = RaidGuided.join(state, { userId = 105, seeker = true })
		expect(blocked.ok).toEqual(false)
		expect(blocked.error).toEqual(ERRORS.half)
		expect(blocked.reason).toEqual(REASONS.half)
		expect(blocked.size).toEqual(6)
		expect(#state.members).toEqual(6)
	end)

	it("refuses a seeker once the remaining slots cannot restore half", function()
		local seekers = party(0, 4)
		expect(RaidGuided.view(seekers).seekers).toEqual(4)
		local fifth = RaidGuided.join(seekers, { userId = 105, seeker = true })
		expect(fifth.ok).toEqual(false)
		expect(fifth.error).toEqual(ERRORS.half)
		expect(#seekers.members).toEqual(4)

		local odd = party(2, 2)
		local third = RaidGuided.join(odd, { userId = 103, seeker = true })
		expect(third.ok).toEqual(true)
		expect(third.size).toEqual(5)
		expect(third.hosts).toEqual(2)
		local early = RaidGuided.finish(third.state, 10)
		expect(early.ok).toEqual(false)
		expect(early.counted).toEqual(false)
		expect(early.reason).toEqual(REASONS.half)
		expect(early.guideScore).toEqual(0)
		expect(third.state.finished).toEqual(false)
	end)

	it("keeps the party between 4 and 8", function()
		local full = party(4, 4)
		expect(RaidGuided.view(full).size).toEqual(8)
		local ninth = RaidGuided.join(full, { userId = 9, guildId = "grove", seeker = false })
		expect(ninth.ok).toEqual(false)
		expect(ninth.error).toEqual(ERRORS.full)
		expect(#full.members).toEqual(8)

		local short = ready(3, 0)
		local failed = RaidGuided.finish(short, 10)
		expect(failed.reason).toEqual(REASONS.party)
		expect(failed.error).toEqual(ERRORS.party)
		expect(failed.counted).toEqual(false)
		expect(failed.persist).toEqual(false)
		expect(short.finished).toEqual(false)

		local again = RaidGuided.join(party(2, 2), { userId = 1, guildId = "grove" })
		expect(again.error).toEqual(ERRORS.duplicate)
		expect(RaidGuided.join(opened(), { userId = 0 }).error).toEqual(ERRORS.user)
		expect(RaidGuided.join(opened(), { userId = 1.5 }).error).toEqual(ERRORS.user)
		expect(RaidGuided.join(opened(), { userId = "1" }).error).toEqual(ERRORS.user)
		expect(RaidGuided.join(opened(), nil).error).toEqual(ERRORS.player)
	end)
end)

describe("RaidGuided oath and finish", function()
	it("accepts one boolean and ignores an oath smuggled onto the join", function()
		local state = party(2, 2)
		local smuggled = RaidGuided.join(opened(), {
			userId = 1,
			guildId = "grove",
			oath = true,
		})
		expect(smuggled.ok).toEqual(true)
		expect(smuggled.state.members[1].oath).toEqual(false)

		local text = RaidGuided.oath(state, 1, "I swear to teach")
		expect(text.ok).toEqual(false)
		expect(text.error).toEqual(ERRORS.oath)
		expect(text.persist).toEqual(false)
		expect(state.members[1].oath).toEqual(false)

		local phrase = RaidGuided.oath(state, 1, true, "helpful, attentive, willing to teach")
		expect(phrase.error).toEqual(ERRORS.oath)
		expect(state.members[1].oath).toEqual(false)
		expect(RaidGuided.oath(state, 1, 1).error).toEqual(ERRORS.oath)
		expect(RaidGuided.oath(state, 1, nil).error).toEqual(ERRORS.oath)

		local sworn = RaidGuided.oath(state, 1, true)
		expect(sworn.ok).toEqual(true)
		expect(sworn.oath).toEqual(true)
		expect(sworn.accepted).toEqual(1)
		expect(sworn.persist).toEqual(true)
		expect(state.members[1].oath).toEqual(false)
		expect(identical(sworn.state.members[1], state.members[1])).toEqual(false)

		local same = RaidGuided.oath(sworn.state, 1, true)
		expect(same.ok).toEqual(true)
		expect(same.persist).toEqual(false)
		local declined = RaidGuided.oath(sworn.state, 1, false)
		expect(declined.ok).toEqual(true)
		expect(declined.oath).toEqual(false)
		expect(declined.persist).toEqual(true)
	end)

	it("counts a finish only after every current member accepts", function()
		local state = party(2, 2)
		state = swear(state, 1)
		state = swear(state, 2)
		state = swear(state, 101)
		local waiting = RaidGuided.finish(state, 40)
		expect(waiting.ok).toEqual(false)
		expect(waiting.counted).toEqual(false)
		expect(waiting.persist).toEqual(false)
		expect(waiting.reason).toEqual(REASONS.oath)
		expect(waiting.error).toEqual(ERRORS.oath)
		expect(waiting.guideScore).toEqual(0)
		expect(waiting.guidedPoints).toEqual(0)
		expect(waiting.marksMultiplier).toEqual(1)
		expect(state.finished).toEqual(false)
		expect(RaidGuided.view(state).ready).toEqual(false)
		expect(RaidGuided.view(state).accepted).toEqual(3)

		state = swear(state, 102)
		local looked = RaidGuided.view(state)
		expect(looked.ok).toEqual(true)
		expect(looked.persist).toEqual(false)
		expect(looked.ready).toEqual(true)
		expect(looked.finished).toEqual(false)
		expect(looked.half).toEqual(2)
		expect(looked.hosts).toEqual(2)
		expect(looked.seekers).toEqual(2)
		expect(looked.reason).toBeNil()
		expect(looked.marksMultiplier).toEqual(1)

		local counted = RaidGuided.finish(state, 40)
		expect(counted.ok).toEqual(true)
		expect(counted.counted).toEqual(true)
		expect(counted.persist).toEqual(true)
		expect(counted.error).toBeNil()
		expect(counted.reason).toBeNil()
		expect(counted.hostGuildId).toEqual("grove")
		expect(counted.guideScore).toEqual(1)
		expect(counted.guidedPoints).toEqual(80)
		expect(counted.guidedPointScale).toEqual(2)
		expect(counted.raidXp).toEqual(40)
		expect(counted.marksMultiplier).toEqual(1)
		expect(counted.marks).toBeNil()
		expect(counted.state.finished).toEqual(true)
		expect(counted.state.guideScore).toEqual(1)
		expect(counted.state.guidedPoints).toEqual(80)
		expect(counted.state.raidXp).toEqual(40)
		expect(state.finished).toEqual(false)
		expect(state.guideScore).toEqual(0)
	end)

	it("awards the same placeholder score on Shardbreaker and for zero raid XP", function()
		local hard = RaidGuided.finish(ready(4, 4), 7)
		expect(hard.counted).toEqual(true)
		expect(hard.guideScore).toEqual(1)
		expect(hard.guidedPoints).toEqual(14)
		expect(RaidGuided.view(hard.state).size).toEqual(8)
		expect(RaidGuided.view(hard.state).ready).toEqual(false)
		expect(RaidGuided.view(hard.state).reason).toEqual(REASONS.finished)

		local mythic = opened("shardbreaker", "grove")
		mythic = admit(mythic, 1, "grove", false)
		mythic = admit(mythic, 2, "grove", false)
		mythic = admit(mythic, 3, "grove", false)
		mythic = admit(mythic, 101, "", true)
		for _, member in ipairs(mythic.members) do
			mythic = swear(mythic, member.userId)
		end
		local counted = RaidGuided.finish(mythic, 0)
		expect(counted.counted).toEqual(true)
		expect(counted.state.difficulty).toEqual("shardbreaker")
		expect(counted.guideScore).toEqual(1)
		expect(counted.guidedPoints).toEqual(0)
		expect(counted.marksMultiplier).toEqual(1)
	end)

	it("does not count a bad guild raid XP amount or a skip flag", function()
		local state = ready(2, 2)
		table.freeze(state.members)
		table.freeze(state)
		local missing = RaidGuided.finish(state, nil)
		expect(missing.error).toEqual(ERRORS.points)
		expect(missing.counted).toEqual(false)
		for _, amount in ipairs({ -1, 1.5, "40", 0 / 0, math.huge }) do
			local failed = RaidGuided.finish(state, amount)
			expect(failed.ok).toEqual(false)
			expect(failed.counted).toEqual(false)
			expect(failed.persist).toEqual(false)
			expect(failed.error).toEqual(ERRORS.points)
			expect(failed.guideScore).toEqual(0)
			expect(failed.state.finished).toEqual(false)
		end
		local skip = RaidGuided.finish(state, 10, { skipOath = true })
		expect(skip.error).toEqual(ERRORS.finish)
		expect(skip.counted).toEqual(false)
		expect(skip.state.finished).toEqual(false)
		expect(state.finished).toEqual(false)
	end)

	it("returns a zero delta when the same run finishes again", function()
		local first = RaidGuided.finish(ready(3, 2), 11)
		expect(first.counted).toEqual(true)
		expect(first.guidedPoints).toEqual(22)
		table.freeze(first.state.members[1])
		table.freeze(first.state.members)
		table.freeze(first.state)
		local again = RaidGuided.finish(first.state, 99)
		expect(again.ok).toEqual(true)
		expect(again.counted).toEqual(false)
		expect(again.persist).toEqual(false)
		expect(again.reason).toEqual(REASONS.finished)
		expect(again.error).toBeNil()
		expect(again.guideScore).toEqual(0)
		expect(again.guidedPoints).toEqual(0)
		expect(again.raidXp).toEqual(0)
		expect(again.marksMultiplier).toEqual(1)
		expect(again.state.guideScore).toEqual(1)
		expect(again.state.guidedPoints).toEqual(22)
		expect(again.state.raidXp).toEqual(11)
		expect(again.state.finished).toEqual(true)
		expect(identical(again.state, first.state)).toEqual(false)
		expect(first.state.guidedPoints).toEqual(22)
	end)
end)

describe("RaidGuided kick and AFK", function()
	it("refuses a kick for the whole run and does not remove anyone", function()
		local empty = opened()
		local early = RaidGuided.kick(empty, nil)
		expect(early.ok).toEqual(false)
		expect(early.removed).toEqual(false)
		expect(early.kick).toEqual(false)
		expect(early.persist).toEqual(false)
		expect(early.reason).toEqual(REASONS.kick)
		expect(early.error).toEqual(ERRORS.kick)
		expect(#early.state.members).toEqual(0)

		local state = party(2, 2)
		table.freeze(state.members[1])
		table.freeze(state.members)
		table.freeze(state)
		local voted = RaidGuided.kick(state, {
			reason = "afk",
			initiatorUserId = 1,
			votes = { [2] = true },
		})
		expect(voted.error).toEqual(ERRORS.kick)
		expect(voted.removed).toEqual(false)
		expect(#voted.state.members).toEqual(4)
		expect(#state.members).toEqual(4)
		expect(identical(voted.state, state)).toEqual(false)

		local passed = RaidGuided.kick(state, { passed = true, reason = "idle" })
		expect(passed.error).toEqual(ERRORS.kick)
		expect(passed.removed).toEqual(false)

		local done = RaidGuided.finish(ready(2, 2), 5)
		local after = RaidGuided.kick(done.state, { reason = "teaching" })
		expect(after.error).toEqual(ERRORS.kick)
		expect(after.state.finished).toEqual(true)
		expect(#after.state.members).toEqual(4)
		expect(done.state.guideScore).toEqual(1)
	end)

	it("treats an AFK removal as not a kick", function()
		local state = party(3, 2)
		local viaKick = RaidGuided.kick(state, "afk")
		expect(viaKick.ok).toEqual(false)
		expect(viaKick.error).toEqual(ERRORS.afk)
		expect(viaKick.reason).toEqual(REASONS.afk)
		expect(viaKick.removed).toEqual(false)
		expect(viaKick.kick).toEqual(false)
		expect(#state.members).toEqual(5)

		local signal = RaidGuided.kick(state, { state = "remove" })
		expect(signal.error).toEqual(ERRORS.afk)
		expect(#signal.state.members).toEqual(5)

		local dropped = RaidGuided.release(state, 102, "afk")
		expect(dropped.ok).toEqual(true)
		expect(dropped.persist).toEqual(true)
		expect(dropped.removed).toEqual(true)
		expect(dropped.kick).toEqual(false)
		expect(dropped.reason).toEqual(REASONS.afk)
		expect(dropped.error).toBeNil()
		expect(dropped.size).toEqual(4)
		expect(dropped.userId).toEqual(102)
		expect(#state.members).toEqual(5)

		local alias = RaidGuided.release(state, 102, { state = "remove" })
		expect(alias.ok).toEqual(true)
		expect(alias.kick).toEqual(false)
		expect(alias.size).toEqual(4)

		expect(RaidGuided.release(state, 102, "kick").error).toEqual(ERRORS.kick)
		expect(RaidGuided.release(state, 102, "idle").error).toEqual(ERRORS.kick)
		expect(RaidGuided.release(state, 102, "vote").removed).toEqual(false)
		expect(RaidGuided.release(state, 102, { passed = true }).error).toEqual(ERRORS.kick)
		expect(RaidGuided.release(state, 102, "warning").error).toEqual(ERRORS.removal)
		local mixed = RaidGuided.release(state, 102, {
			removal = "afk",
			votes = { [2] = true },
			reason = "idle",
		})
		expect(mixed.ok).toEqual(false)
		expect(mixed.removed).toEqual(false)
		expect(mixed.kick).toEqual(false)
		expect(mixed.error).toEqual(ERRORS.kick)
		local conduct = RaidGuided.release(state, 102, {
			ok = true,
			state = "remove",
			idleSeconds = 90,
			forfeitRewards = true,
			queueBackfill = true,
			keepMarks = false,
			error = nil,
		})
		expect(conduct.ok).toEqual(true)
		expect(conduct.removed).toEqual(true)
		expect(conduct.kick).toEqual(false)
		local warned = RaidGuided.release(state, 102, {
			ok = true,
			state = "warning",
			idleSeconds = 60,
			forfeitRewards = false,
			queueBackfill = false,
			keepMarks = true,
		})
		expect(warned.removed).toEqual(false)
		expect(warned.error).toEqual(ERRORS.removal)
		expect(#state.members).toEqual(5)
	end)

	it("lets the remaining roster finish after an AFK removal", function()
		local state = party(3, 2)
		state = swear(state, 1)
		state = swear(state, 2)
		state = swear(state, 3)
		state = swear(state, 101)
		local blocked = RaidGuided.finish(state, 6)
		expect(blocked.reason).toEqual(REASONS.oath)

		local dropped = RaidGuided.release(state, 102, " AFK ")
		expect(dropped.removed).toEqual(true)
		expect(dropped.kick).toEqual(false)
		local counted = RaidGuided.finish(dropped.state, 6)
		expect(counted.counted).toEqual(true)
		expect(counted.guideScore).toEqual(1)
		expect(counted.guidedPoints).toEqual(12)
		expect(counted.state.finished).toEqual(true)
		expect(#counted.state.members).toEqual(4)
		expect(RaidGuided.view(counted.state).hosts).toEqual(3)

		local late = RaidGuided.release(counted.state, 101, "afk")
		expect(late.ok).toEqual(false)
		expect(late.error).toEqual(ERRORS.finished)
		expect(late.removed).toEqual(false)
		expect(#counted.state.members).toEqual(4)
	end)

	it("blocks the score when an AFK removal drops the run under half", function()
		local state = ready(4, 4)
		local dropped = RaidGuided.release(state, 1, "afk")
		expect(dropped.ok).toEqual(true)
		expect(dropped.kick).toEqual(false)
		expect(dropped.size).toEqual(7)
		expect(dropped.hosts).toEqual(3)
		local failed = RaidGuided.finish(dropped.state, 10)
		expect(failed.ok).toEqual(false)
		expect(failed.counted).toEqual(false)
		expect(failed.persist).toEqual(false)
		expect(failed.reason).toEqual(REASONS.half)
		expect(failed.guideScore).toEqual(0)
		expect(dropped.state.finished).toEqual(false)
		expect(dropped.state.guideScore).toEqual(0)
	end)
end)

describe("RaidGuided isolation", function()
	it("returns new tables and does not write the input", function()
		local state = party(2, 2)
		local members = state.members
		local first = members[1]
		table.freeze(first)
		table.freeze(members)
		table.freeze(state)
		local sworn = RaidGuided.oath(state, 1, true)
		expect(sworn.ok).toEqual(true)
		expect(identical(sworn.state, state)).toEqual(false)
		expect(identical(sworn.state.members, members)).toEqual(false)
		expect(identical(sworn.state.members[1], first)).toEqual(false)
		expect(first.oath).toEqual(false)
		sworn.state.members[1].oath = false
		expect(first.oath).toEqual(false)

		local left = RaidGuided.join(nil, { userId = 1 })
		local right = RaidGuided.view(nil)
		expect(left.error).toEqual(ERRORS.state)
		expect(right.error).toEqual(ERRORS.state)
		expect(identical(left.state, right.state)).toEqual(false)
		expect(left.ok).toEqual(false)
		expect(right.persist).toEqual(false)
	end)

	it("rejects a broken record without throwing", function()
		local broken = {
			4,
			"hard",
			{
				difficulty = "Hard",
				hostGuildId = "grove",
				members = {},
				finished = false,
				guideScore = 0,
				raidXp = 0,
				guidedPoints = 0,
			},
			{
				difficulty = "hard",
				hostGuildId = "grove",
				members = {
					{ userId = 1, guildId = "grove", seeker = false, oath = false },
					{ userId = 1, guildId = "grove", seeker = false, oath = false },
				},
				finished = false,
				guideScore = 0,
				raidXp = 0,
				guidedPoints = 0,
			},
			{
				difficulty = "hard",
				hostGuildId = "grove",
				members = {
					{ userId = 1, guildId = "grove", seeker = true, oath = true },
				},
				finished = false,
				guideScore = 0,
				raidXp = 0,
				guidedPoints = 0,
			},
			{
				difficulty = "hard",
				hostGuildId = "grove",
				members = {},
				finished = true,
				guideScore = 1,
				raidXp = 1,
				guidedPoints = 2,
			},
		}
		for _, state in ipairs(broken) do
			expect(RaidGuided.join(state, { userId = 8, guildId = "grove" }).error).toEqual(
				ERRORS.state
			)
			expect(RaidGuided.finish(state, 10).ok).toEqual(false)
			expect(RaidGuided.finish(state, 10).counted).toEqual(false)
			expect(RaidGuided.kick(state, nil).removed).toEqual(false)
			expect(RaidGuided.view(state).ok).toEqual(false)
		end
	end)

	it("is not required by src and does not reach a service", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidGuided.luau")
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "RaidConduct", 1, true)).toBeNil()
		expect(string.find(source, "RaidFinder", 1, true)).toBeNil()
		expect(string.find(source, "RaidPremade", 1, true)).toBeNil()
		expect(string.find(source, "RaidMarks", 1, true)).toBeNil()
		expect(string.find(source, "doubleMarks", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "DataStoreService", 1, true)).toBeNil()
		expect(string.find(source, "MemoryStoreService", 1, true)).toBeNil()
		expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if
				path ~= "src/ReplicatedStorage/Shared/RaidGuided.luau"
				and mentionsGuided(fs.readFile(path))
			then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
