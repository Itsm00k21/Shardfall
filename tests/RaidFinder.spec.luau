--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidFinder = require("../src/ReplicatedStorage/Shared/RaidFinder")

local ERRORS = RaidFinder.ERRORS

local function seat(userId: number, role: string, patch: { [string]: any }?): { [string]: any }
	local row: { [string]: any } = {
		userId = userId,
		role = role,
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			row[key] = value
		end
	end
	return row
end

local function roles(list: { string }, patch: { [string]: any }?): { any }
	local members = {}
	for index, role in ipairs(list) do
		members[index] = seat(index, role, patch)
	end
	return members
end

local function proposal(
	difficulty: string,
	members: { any },
	waitingSince: number?
): { [string]: any }
	return {
		difficulty = difficulty,
		waitingSince = waitingSince,
		members = members,
	}
end

local function walk(value: any, banned: { [string]: boolean })
	if type(value) ~= "table" then
		expect(type(value) == "function").toEqual(false)
		return
	end
	for key, child in pairs(value) do
		if type(key) == "string" then
			expect(banned[string.lower(key)]).toBeNil()
		end
		walk(child, banned)
	end
end

describe("RaidFinder config", function()
	it("pins the design thresholds and the placeholder targets", function()
		local config = RaidFinder.CONFIG
		expect(config.minParty).toEqual(4)
		expect(config.maxParty).toEqual(8)
		expect(config.healerWaitSeconds).toEqual(180)
		expect(config.bossDamage).toEqual(1)
		expect(config.healerlessDamage).toEqual(0.85)
		expect(config.bossDamage - config.healerlessDamage).toBeCloseTo(0.15)
		expect(config.healingSpring).toEqual(true)
		expect(config.mentorClears).toEqual(10)
		expect(config.defaultPriority).toEqual(0)
		expect(config.droppedPriority).toEqual(-1)
		expect(config.daySeconds).toEqual(86400)
		expect(config.fillOrder).toEqual({ "tank", "healer", "dps" })
		expect(RaidFinder.WARDEN_ID).toEqual("warden_golem")
		expect(RaidFinder.IDLE_REASONS.idle).toEqual(true)
		expect(RaidFinder.IDLE_REASONS.afk).toEqual(true)
		for size = config.minParty, config.maxParty do
			local row = config.roleTargets[size]
			expect(row.tank + row.healer + row.dps).toEqual(size)
			expect(RaidFinder.hpScale(size)).toEqual(config.hpScale[size])
		end
		expect(config.roleTargets[4]).toEqual({ tank = 1, healer = 1, dps = 2 })
		expect(config.roleTargets[8]).toEqual({ tank = 2, healer = 1, dps = 5 })
		expect(config.hpScale[4]).toEqual(0.5)
		expect(config.hpScale[8]).toEqual(1)
		expect(RaidFinder.hpScale(3)).toBeNil()
		expect(RaidFinder.hpScale(9)).toBeNil()
		expect(RaidFinder.hpScale(4.5)).toBeNil()
	end)

	it("freezes the thresholds, the roles, and the errors", function()
		expect(function()
			RaidFinder.CONFIG.minParty = 1
		end).toThrow()
		expect(function()
			RaidFinder.CONFIG.roleTargets[4].tank = 3
		end).toThrow()
		expect(function()
			RaidFinder.CONFIG.hpScale[4] = 1
		end).toThrow()
		expect(function()
			RaidFinder.CONFIG.fillOrder[1] = "healer"
		end).toThrow()
		expect(function()
			RaidFinder.ROLES.flex = false
		end).toThrow()
		expect(function()
			RaidFinder.DIFFICULTIES.story = false
		end).toThrow()
		expect(function()
			RaidFinder.REFUSED.hard = false
		end).toThrow()
		expect(function()
			RaidFinder.IDLE_REASONS.idle = false
		end).toThrow()
		expect(function()
			RaidFinder.ERRORS.guided = "open"
		end).toThrow()
	end)

	it("has no Robux price and no service handles", function()
		walk(RaidFinder.CONFIG, {
			robux = true,
			productid = true,
			premium = true,
			gamepass = true,
		})
	end)

	it("counts UTC days from the unix time it is given", function()
		expect(RaidFinder.dayNumber(0)).toEqual(0)
		expect(RaidFinder.dayNumber(86399)).toEqual(0)
		expect(RaidFinder.dayNumber(86400)).toEqual(1)
		expect(RaidFinder.dayNumber(-1)).toBeNil()
		expect(RaidFinder.dayNumber(0 / 0)).toBeNil()
		expect(RaidFinder.dayNumber(math.huge)).toBeNil()
	end)
end)

describe("RaidFinder queue", function()
	it("accepts Story and Normal for every role and ignores gear and clears", function()
		local rolesList = { "tank", "healer", "dps", "flex" }
		for _, role in ipairs(rolesList) do
			for _, difficulty in ipairs({ "story", "normal" }) do
				local open = RaidFinder.canQueue({
					difficulty = difficulty,
					role = role,
					gearScore = 0,
					clearCount = 0,
					clears = 0,
					level = 1,
					raidStory = false,
				}, 50)
				expect(open.queued).toEqual(true)
				expect(open.ok).toEqual(true)
				expect(open.gearFiltered).toEqual(false)
				expect(open.clearFiltered).toEqual(false)
				expect(open.finderBlocked).toEqual(false)
			end
		end
		local geared = RaidFinder.canQueue({
			difficulty = " Story ",
			role = " Healer ",
			gearScore = 9000,
			clearCount = 100,
			clears = 100,
		}, 50)
		expect(geared).toEqual({
			ok = true,
			queued = true,
			difficulty = "story",
			role = "healer",
			finderBlocked = false,
			remainingSeconds = 0,
			gearFiltered = false,
			clearFiltered = false,
		})
	end)

	it("refuses Hard, Shardbreaker, and anything else", function()
		local hard = RaidFinder.canQueue({ difficulty = "hard", role = "tank" }, 10)
		expect(hard.ok).toEqual(false)
		expect(hard.queued).toEqual(false)
		expect(hard.finderBlocked).toEqual(false)
		expect(hard.error).toEqual(ERRORS.guided)
		local mythic = RaidFinder.canQueue({ difficulty = " Shardbreaker ", role = "flex" }, 10)
		expect(mythic.error).toEqual(ERRORS.guided)
		expect(RaidFinder.canQueue({ difficulty = "fracture", role = "dps" }, 10).error).toEqual(
			ERRORS.difficulty
		)
		expect(RaidFinder.canQueue({ difficulty = "", role = "dps" }, 10).error).toEqual(
			ERRORS.difficulty
		)
		expect(RaidFinder.canQueue({ difficulty = "story", role = "warden" }, 10).error).toEqual(
			ERRORS.role
		)
	end)

	it("blocks a cooldown that is still in the future and opens on the deadline", function()
		local cooling = RaidFinder.canQueue({
			difficulty = "normal",
			role = "dps",
			cooldownUntil = 10.5,
		}, 10)
		expect(cooling).toEqual({
			ok = true,
			queued = false,
			difficulty = "normal",
			role = "dps",
			finderBlocked = true,
			remainingSeconds = 0.5,
			gearFiltered = false,
			clearFiltered = false,
			error = ERRORS.cooling,
		})
		local opened = RaidFinder.canQueue({
			difficulty = "normal",
			role = "dps",
			cooldownUntil = 10,
		}, 10)
		expect(opened.queued).toEqual(true)
		expect(opened.finderBlocked).toEqual(false)
		local blank = RaidFinder.canQueue({ difficulty = "story", role = "flex" }, 10)
		expect(blank.queued).toEqual(true)
	end)

	it("fails closed on a bad clock and does not write the ticket", function()
		local ticket = table.freeze({
			difficulty = "story",
			role = "tank",
			cooldownUntil = 0,
			gearScore = 1,
		})
		local bad = RaidFinder.canQueue(ticket, 0 / 0)
		expect(bad.ok).toEqual(false)
		expect(bad.finderBlocked).toEqual(true)
		expect(bad.error).toEqual(ERRORS.time)
		expect(RaidFinder.canQueue(ticket, -1).error).toEqual(ERRORS.time)
		expect(RaidFinder.canQueue(nil, 1).error).toEqual(ERRORS.party)
		expect(RaidFinder.canQueue({
			difficulty = "story",
			role = "flex",
			cooldownUntil = 0 / 0,
		}, 1).error).toEqual(ERRORS.cooldown)
	end)

	it("does not filter Story or Normal", function()
		expect(RaidFinder.filters("normal")).toEqual({
			ok = true,
			difficulty = "normal",
			gearScore = false,
			clearCount = false,
		})
		expect(RaidFinder.filters(" story ").gearScore).toEqual(false)
		expect(RaidFinder.filters("hard").error).toEqual(ERRORS.guided)
		expect(RaidFinder.filters("fracture").error).toEqual(ERRORS.difficulty)
	end)
end)

describe("RaidFinder forming", function()
	it("fills flex in order and counts fresh seats and mentors", function()
		local formed = RaidFinder.form({
			difficulty = "story",
			waitingSince = 0,
			members = {
				seat(1, "flex", { fresh = true, clears = 10, mentorOptIn = true }),
				seat(2, "flex"),
				seat(3, "flex", { fresh = true }),
				seat(4, "flex", { clears = 9, mentorOptIn = true }),
			},
		}, 0)
		expect(formed).toEqual({
			ok = true,
			mayStart = true,
			difficulty = "story",
			playerCount = 4,
			hpScale = 0.5,
			bossDamageScale = 1,
			autoScale = false,
			healingSpring = false,
			waitedSeconds = 0,
			healerTimeout = false,
			wardenCount = 0,
			freshCount = 2,
			mentorCount = 1,
			targets = { tank = 1, healer = 1, dps = 2 },
			filled = { tank = 1, healer = 1, dps = 2 },
			seats = {
				{
					userId = 1,
					role = "flex",
					filled = "tank",
					freshShard = true,
					mentor = true,
					priority = 0,
				},
				{
					userId = 2,
					role = "flex",
					filled = "healer",
					freshShard = false,
					mentor = false,
					priority = 0,
				},
				{
					userId = 3,
					role = "flex",
					filled = "dps",
					freshShard = true,
					mentor = false,
					priority = 0,
				},
				{
					userId = 4,
					role = "flex",
					filled = "dps",
					freshShard = false,
					mentor = false,
					priority = 0,
				},
			},
		})
	end)

	it("turns the first flex into the tank when both roles are open", function()
		local early = RaidFinder.form(
			proposal("story", {
				seat(1, "dps"),
				seat(7, "flex"),
				seat(3, "dps"),
				seat(8, "flex"),
			}, 0),
			0
		)
		expect(early.seats[2].filled).toEqual("tank")
		expect(early.seats[2].userId).toEqual(7)
		expect(early.seats[4].filled).toEqual("healer")
		expect(early.seats[4].userId).toEqual(8)
		expect(early.mayStart).toEqual(true)
		expect(early.wardenCount).toEqual(0)
		local only =
			RaidFinder.form(proposal("story", roles({ "dps", "dps", "dps", "flex" }), 0), 180)
		expect(only.seats[4].filled).toEqual("tank")
		expect(only.mayStart).toEqual(true)
		expect(only.autoScale).toEqual(true)
		expect(only.wardenCount).toEqual(0)
		expect(only.bossDamageScale).toEqual(0.85)
		expect(only.healingSpring).toEqual(true)
	end)

	it("uses a flex as the healer once a tank is already queued", function()
		local formed =
			RaidFinder.form(proposal("normal", roles({ "tank", "dps", "dps", "flex" }), 0), 180)
		expect(formed.filled).toEqual({ tank = 1, healer = 1, dps = 2 })
		expect(formed.autoScale).toEqual(false)
		expect(formed.healingSpring).toEqual(false)
		expect(formed.bossDamageScale).toEqual(1)
		expect(formed.mayStart).toEqual(true)
		expect(formed.healerTimeout).toEqual(true)
	end)

	it("waits 180 seconds before a healerless group may start", function()
		local members = roles({ "tank", "dps", "dps", "dps" })
		local waiting = RaidFinder.form(proposal("story", members, 1000), 1179)
		expect(waiting.ok).toEqual(true)
		expect(waiting.mayStart).toEqual(false)
		expect(waiting.autoScale).toEqual(false)
		expect(waiting.healingSpring).toEqual(false)
		expect(waiting.healerTimeout).toEqual(false)
		expect(waiting.bossDamageScale).toEqual(1)
		expect(waiting.waitedSeconds).toEqual(179)
		expect(waiting.wardenCount).toEqual(0)
		local ready = RaidFinder.form(proposal(" Normal ", members, 1000), 1180)
		expect(ready.difficulty).toEqual("normal")
		expect(ready.mayStart).toEqual(true)
		expect(ready.autoScale).toEqual(true)
		expect(ready.healingSpring).toEqual(true)
		expect(ready.healerTimeout).toEqual(true)
		expect(ready.bossDamageScale).toEqual(0.85)
		expect(ready.waitedSeconds).toEqual(180)
		expect(ready.hpScale).toEqual(0.5)
	end)

	it("does not soften damage when a healer is already in the group", function()
		local formed =
			RaidFinder.form(proposal("story", roles({ "tank", "healer", "dps", "dps" }), 0), 500)
		expect(formed.mayStart).toEqual(true)
		expect(formed.autoScale).toEqual(false)
		expect(formed.healingSpring).toEqual(false)
		expect(formed.bossDamageScale).toEqual(1)
		expect(formed.healerTimeout).toEqual(true)
		expect(formed.freshCount).toEqual(0)
	end)

	it("adds a Warden golem per missing tank on Story only", function()
		local story =
			RaidFinder.form(proposal("story", roles({ "healer", "dps", "dps", "dps" }), 0), 0)
		expect(story.mayStart).toEqual(true)
		expect(story.wardenCount).toEqual(1)
		expect(story.autoScale).toEqual(false)
		expect(story.hpScale).toEqual(0.5)
		local normal =
			RaidFinder.form(proposal("normal", roles({ "healer", "dps", "dps", "dps" }), 0), 180)
		expect(normal.mayStart).toEqual(false)
		expect(normal.wardenCount).toEqual(0)
		expect(normal.autoScale).toEqual(false)
		local both =
			RaidFinder.form(proposal("story", roles({ "dps", "dps", "dps", "dps" }), 0), 180)
		expect(both.mayStart).toEqual(true)
		expect(both.wardenCount).toEqual(1)
		expect(both.autoScale).toEqual(true)
		expect(both.healingSpring).toEqual(true)
		local eight = {}
		eight[1] = seat(1, "healer")
		for index = 2, 8 do
			eight[index] = seat(index, "dps")
		end
		local wide = RaidFinder.form(proposal("story", eight, 0), 0)
		expect(wide.playerCount).toEqual(8)
		expect(wide.hpScale).toEqual(1)
		expect(wide.targets).toEqual({ tank = 2, healer = 1, dps = 5 })
		expect(wide.wardenCount).toEqual(2)
		expect(wide.mayStart).toEqual(true)
		local wideNormal = RaidFinder.form(proposal("normal", eight, 0), 0)
		expect(wideNormal.mayStart).toEqual(false)
		expect(wideNormal.wardenCount).toEqual(0)
	end)

	it("still starts when DPS is short and extra tanks keep their role", function()
		local short =
			RaidFinder.form(proposal("story", roles({ "tank", "tank", "healer", "dps" }), 0), 0)
		expect(short.mayStart).toEqual(true)
		expect(short.filled).toEqual({ tank = 2, healer = 1, dps = 1 })
		expect(short.wardenCount).toEqual(0)
		local tanks =
			RaidFinder.form(proposal("normal", roles({ "tank", "tank", "tank", "tank" }), 0), 180)
		expect(tanks.mayStart).toEqual(true)
		expect(tanks.autoScale).toEqual(true)
		expect(tanks.filled.tank).toEqual(4)
		expect(tanks.filled.dps).toEqual(0)
	end)

	it("refuses the wrong size, a bad mode, and a duplicate", function()
		local small = RaidFinder.form(proposal("story", roles({ "flex", "flex", "flex" }), 0), 10)
		expect(small.error).toEqual(ERRORS.size)
		local nine =
			roles({ "flex", "flex", "flex", "flex", "flex", "flex", "flex", "flex", "flex" })
		expect(RaidFinder.form(proposal("story", nine, 0), 10).error).toEqual(ERRORS.size)
		local hard =
			RaidFinder.form(proposal("hard", roles({ "flex", "flex", "flex", "flex" }), 0), 10)
		expect(hard.ok).toEqual(false)
		expect(hard.mayStart).toEqual(false)
		expect(hard.error).toEqual(ERRORS.guided)
		expect(hard.seats).toEqual({})
		expect(
			RaidFinder.form(
				proposal("shardbreaker", roles({ "flex", "flex", "flex", "flex" }), 0),
				10
			).error
		).toEqual(ERRORS.guided)
		local twins = roles({ "flex", "flex", "flex", "flex" })
		twins[2].userId = 1
		local dup = RaidFinder.form(proposal("story", twins, 0), 10)
		expect(dup.ok).toEqual(false)
		expect(dup.error).toEqual(ERRORS.duplicate)
		expect(dup.mayStart).toEqual(false)
	end)

	it("refuses a member who is still on a Finder cooldown", function()
		local members = roles({ "tank", "healer", "dps", "dps" })
		members[4].cooldownUntil = 50
		local blocked = RaidFinder.form(proposal("story", members, 0), 49)
		expect(blocked.ok).toEqual(false)
		expect(blocked.mayStart).toEqual(false)
		expect(blocked.error).toEqual(ERRORS.cooling)
		expect(blocked.seats).toEqual({})
		local open = RaidFinder.form(proposal("story", members, 0), 50)
		expect(open.ok).toEqual(true)
		expect(open.mayStart).toEqual(true)
	end)

	it("treats a missing wait as zero and rejects a clock that moved backwards", function()
		local formed = RaidFinder.form({
			difficulty = "story",
			members = roles({ "dps", "dps", "dps", "dps" }),
		}, 1000)
		expect(formed.waitedSeconds).toEqual(0)
		expect(formed.mayStart).toEqual(false)
		expect(formed.healerTimeout).toEqual(false)
		local ahead =
			RaidFinder.form(proposal("story", roles({ "flex", "flex", "flex", "flex" }), 20), 10)
		expect(ahead.error).toEqual(ERRORS.clock)
		expect(ahead.mayStart).toEqual(false)
	end)

	it("does not write the proposal", function()
		local first = table.freeze({
			userId = 1,
			role = "tank",
			fresh = true,
			clears = 12,
			mentorOptIn = true,
			gearScore = 9000,
			clearCount = 3,
			priority = -1,
		})
		local group = table.freeze({
			difficulty = "story",
			waitingSince = 0,
			members = table.freeze({
				first,
				table.freeze(seat(2, "healer")),
				table.freeze(seat(3, "dps")),
				table.freeze(seat(4, "dps", { fresh = true })),
			}),
		})
		local formed = RaidFinder.form(group, 0)
		expect(formed.ok).toEqual(true)
		expect(formed.mayStart).toEqual(true)
		expect(formed.freshCount).toEqual(2)
		expect(formed.mentorCount).toEqual(1)
		expect(formed.seats[1].filled).toEqual("tank")
		expect(formed.seats[1].freshShard).toEqual(true)
		expect(formed.seats[1].mentor).toEqual(true)
		expect(formed.seats[1].priority).toEqual(-1)
		expect(formed.seats[1].gearScore).toBeNil()
		expect((first :: any).filled).toBeNil()
		expect((first :: any).freshShard).toBeNil()
	end)

	it("rejects a bad member flag without guessing", function()
		local fresh = roles({ "flex", "flex", "flex", "flex" })
		fresh[1].fresh = 1
		expect(RaidFinder.form(proposal("story", fresh, 0), 1).error).toEqual(ERRORS.fresh)
		local opted = roles({ "flex", "flex", "flex", "flex" })
		opted[1].mentorOptIn = "yes"
		expect(RaidFinder.form(proposal("story", opted, 0), 1).error).toEqual(ERRORS.mentor)
		local anon = {}
		for index = 1, 4 do
			anon[index] = { role = "FLEX" }
		end
		local formed = RaidFinder.form(proposal("story", anon, 0), 1)
		expect(formed.ok).toEqual(true)
		expect(formed.seats[1].userId).toBeNil()
		expect(formed.seats[1].role).toEqual("flex")
	end)
end)

describe("RaidFinder mentor and priority", function()
	it("requires 10 clears and an opt-in", function()
		expect(RaidFinder.mentor(10, true)).toEqual({
			ok = true,
			eligible = true,
			clears = 10,
			optedIn = true,
		})
		expect(RaidFinder.mentor(9, true).eligible).toEqual(false)
		expect(RaidFinder.mentor(10, false).eligible).toEqual(false)
		expect(RaidFinder.mentor(10, nil).eligible).toEqual(false)
		expect(RaidFinder.mentor(nil, true).eligible).toEqual(false)
		expect(RaidFinder.mentor(0 / 0, true).ok).toEqual(false)
		expect(RaidFinder.mentor(10, "yes").error).toEqual(ERRORS.mentor)
	end)

	it("drops priority on an idle kick and restores it the next UTC day", function()
		local record = table.freeze({ priority = 4, priorityDay = 0 })
		local rolled = RaidFinder.priority(record, 86400, false)
		expect(rolled).toEqual({
			ok = true,
			priority = 0,
			priorityDay = 1,
			dropped = false,
		})
		expect(record.priority).toEqual(4)
		local dropped = RaidFinder.priority({ priority = 4, priorityDay = 1 }, 90000, true)
		expect(dropped).toEqual({
			ok = true,
			priority = -1,
			priorityDay = 1,
			dropped = true,
		})
		local reason = RaidFinder.priority({ priority = 2, priorityDay = 1 }, 90000, " AFK ")
		expect(reason.priority).toEqual(-1)
		expect(reason.dropped).toEqual(true)
		local kept = RaidFinder.priority({ priority = -1, priorityDay = 1 }, 90000, "unfair")
		expect(kept.priority).toEqual(-1)
		expect(kept.dropped).toEqual(true)
		local again = RaidFinder.priority({ priority = -1, priorityDay = 1 }, 90000, "idle")
		expect(again.priority).toEqual(-1)
		local nextDay = RaidFinder.priority({ priority = -1, priorityDay = 1 }, 86400 * 2, false)
		expect(nextDay).toEqual({
			ok = true,
			priority = 0,
			priorityDay = 2,
			dropped = false,
		})
		local blank = RaidFinder.priority(nil, 0, nil)
		expect(blank).toEqual({
			ok = true,
			priority = 0,
			priorityDay = 0,
			dropped = false,
		})
		local badKick = RaidFinder.priority({ priority = 1, priorityDay = 1 }, 90000, 1)
		expect(badKick.error).toEqual(ERRORS.kick)
		local badTime = RaidFinder.priority({ priority = 1, priorityDay = 1 }, -1, true)
		expect(badTime.error).toEqual(ERRORS.time)
	end)
end)
