--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidMarks = require("../src/ReplicatedStorage/Shared/RaidMarks")
local RaidVault = require("../src/ReplicatedStorage/Shared/RaidVault")

local ERRORS = RaidVault.ERRORS
local REASONS = RaidVault.REASONS

local WEEK = 7 * 86400
local FIRST = 5 * 86400
local TUESDAY = 1791849600

local function identical(left: any, right: any): boolean
	return left == right
end

local function fresh(): any
	local opened = RaidVault.fresh()
	expect(opened.ok).toEqual(true)
	return opened.state
end

local function boss(
	bossId: string,
	difficulty: string,
	extra: { [string]: any }?
): { [string]: any }
	local row: { [string]: any } = {
		bossId = bossId,
		difficulty = difficulty,
	}
	if extra ~= nil then
		for key, value in pairs(extra) do
			row[key] = value
		end
	end
	return row
end

local function earn(state: any, rows: { any }, now: number): any
	local current = state
	for _, row in ipairs(rows) do
		local noted = RaidVault.note(current, row, now)
		expect(noted.ok).toEqual(true)
		expect(noted.counted).toEqual(true)
		current = noted.state
	end
	return current
end

local function heartwood(difficulty: string): { any }
	return {
		boss("twins", difficulty),
		boss("sapwell", difficulty),
		boss("galecrown", difficulty),
		boss("awakened", difficulty),
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

local function mentionsVault(source: string): boolean
	if string.find(source, "Shared.RaidVault", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidVault", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidVault", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidVault")', 1, true) ~= nil then
		return true
	end
	return false
end

describe("RaidVault config", function()
	it("pins the thresholds, the choice counts, and the difficulty rank", function()
		expect(RaidVault.CONFIG.thresholds).toEqual({ 2, 4, 6 })
		expect(RaidVault.CONFIG.choiceCounts).toEqual({ 1, 2, 3 })
		expect(RaidVault.CONFIG.rank).toEqual({
			story = 1,
			normal = 2,
			hard = 3,
			shardbreaker = 4,
		})
		expect(RaidVault.CONFIG.weekSeconds).toEqual(WEEK)
		expect(RaidVault.CONFIG.tuesdayOffset).toEqual(FIRST)
	end)

	it("freezes the thresholds, the reasons, and the errors", function()
		expect(function()
			RaidVault.CONFIG.thresholds[1] = 1
		end).toThrow()
		expect(function()
			RaidVault.CONFIG.choiceCounts[1] = 9
		end).toThrow()
		expect(function()
			RaidVault.CONFIG.rank.story = 9
		end).toThrow()
		expect(function()
			RaidVault.CONFIG.weekSeconds = 1
		end).toThrow()
		expect(function()
			RaidVault.REMOVALS.afk = false
		end).toThrow()
		expect(function()
			RaidVault.REASONS.practice = "grove"
		end).toThrow()
		expect(function()
			RaidVault.ERRORS.closed = "open"
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
		for key in pairs(RaidVault.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
	end)
end)

describe("RaidVault weekKey", function()
	it("matches the Tuesday 00:00 UTC key without loading it from Marks", function()
		local samples = {
			0,
			1,
			FIRST - 1,
			FIRST,
			FIRST + WEEK - 1,
			FIRST + WEEK,
			TUESDAY - 1,
			TUESDAY,
			TUESDAY + 10,
			TUESDAY + WEEK,
			TUESDAY + (2 * WEEK),
		}
		for _, at in ipairs(samples) do
			expect(RaidVault.weekKey(at)).toEqual(RaidMarks.weekKey(at))
		end
		expect(RaidVault.weekKey(TUESDAY - 1)).toEqual(2962)
		expect(RaidVault.weekKey(TUESDAY)).toEqual(2963)
		expect(RaidVault.weekKey(TUESDAY + WEEK)).toEqual(2964)
	end)

	it("rejects a negative, NaN, infinite, or unsafe clock", function()
		expect(RaidVault.weekKey(-1)).toBeNil()
		expect(RaidVault.weekKey(0 / 0)).toBeNil()
		expect(RaidVault.weekKey(math.huge)).toBeNil()
		expect(RaidVault.weekKey(-math.huge)).toBeNil()
		expect(RaidVault.weekKey(1e308)).toBeNil()
		expect(RaidVault.weekKey(2 ^ 53 * WEEK)).toBeNil()
	end)
end)

describe("RaidVault progress", function()
	it("opens 1, 2, and 3 choices at 2, 4, and 6 bosses", function()
		local state = fresh()
		local one = RaidVault.note(state, boss("twins", "normal"), TUESDAY)
		expect(one.ok).toEqual(true)
		expect(one.counted).toEqual(true)
		expect(one.choiceCount).toEqual(0)
		expect(one.slots[1].open).toEqual(false)
		expect(one.slots[2].open).toEqual(false)
		expect(one.slots[3].open).toEqual(false)
		expect(one.persist).toEqual(true)

		local two = earn(one.state, { boss("sapwell", "normal") }, TUESDAY)
		local viewed = RaidVault.view(two, TUESDAY)
		expect(viewed.choiceCount).toEqual(1)
		expect(viewed.slots[1].open).toEqual(true)
		expect(viewed.slots[1].threshold).toEqual(2)
		expect(viewed.slots[1].choiceCount).toEqual(1)
		expect(viewed.slots[1].difficulty).toEqual("normal")
		expect(viewed.slots[1].rank).toEqual(2)
		expect(viewed.slots[2].open).toEqual(false)
		expect(viewed.slots[3].threshold).toEqual(6)
		expect(viewed.slots[3].choiceCount).toEqual(3)

		local four = earn(two, {
			boss("galecrown", "normal"),
			boss("awakened", "normal"),
		}, TUESDAY)
		expect(RaidVault.view(four, TUESDAY).choiceCount).toEqual(2)

		local six = earn(four, {
			boss("choir", "normal"),
			boss("crucible", "normal"),
		}, TUESDAY)
		local full = RaidVault.view(six, TUESDAY)
		expect(full.choiceCount).toEqual(3)
		expect(full.slots[1].difficulty).toEqual("normal")
		expect(full.slots[2].difficulty).toEqual("normal")
		expect(full.slots[3].difficulty).toEqual("normal")
		expect(full.killCount).toEqual(6)

		local more = earn(six, { boss("throne", "normal") }, TUESDAY)
		expect(RaidVault.view(more, TUESDAY).choiceCount).toEqual(3)
		expect(RaidVault.view(more, TUESDAY).killCount).toEqual(7)
	end)

	it("uses the 2nd, 4th, and 6th highest boss as the slot quality", function()
		local rows = {
			boss("twins", "shardbreaker"),
			boss("sapwell", "hard"),
			boss("galecrown", "normal"),
			boss("awakened", "story"),
			boss("choir", "story"),
			boss("crucible", "story"),
		}
		local state = earn(fresh(), rows, TUESDAY)
		local viewed = RaidVault.view(state, TUESDAY)
		expect(viewed.choiceCount).toEqual(3)
		expect(viewed.slots[1].difficulty).toEqual("hard")
		expect(viewed.slots[1].rank).toEqual(3)
		expect(viewed.slots[2].difficulty).toEqual("story")
		expect(viewed.slots[3].difficulty).toEqual("story")
	end)

	it("keeps a lower slot when only some of the top bosses are high", function()
		local rows = {
			boss("twins", "hard"),
			boss("sapwell", "hard"),
			boss("galecrown", "hard"),
			boss("awakened", "story"),
		}
		local viewed = RaidVault.view(earn(fresh(), rows, TUESDAY), TUESDAY)
		expect(viewed.choiceCount).toEqual(2)
		expect(viewed.slots[1].difficulty).toEqual("hard")
		expect(viewed.slots[2].difficulty).toEqual("story")
		expect(viewed.slots[3].open).toEqual(false)
	end)

	it("does not open the third choice on one difficulty of Heartwood", function()
		local viewed = RaidVault.view(earn(fresh(), heartwood("shardbreaker"), TUESDAY), TUESDAY)
		expect(viewed.killCount).toEqual(4)
		expect(viewed.choiceCount).toEqual(2)
		expect(viewed.slots[1].difficulty).toEqual("shardbreaker")
		expect(viewed.slots[2].difficulty).toEqual("shardbreaker")
		expect(viewed.slots[3].open).toEqual(false)
	end)

	it("opens 3 choices when the four Heartwood bosses fall on two difficulties", function()
		local rows = heartwood("shardbreaker")
		for _, row in ipairs(heartwood("hard")) do
			table.insert(rows, row)
		end
		local viewed = RaidVault.view(earn(fresh(), rows, TUESDAY), TUESDAY)
		expect(viewed.killCount).toEqual(8)
		expect(viewed.choiceCount).toEqual(3)
		expect(viewed.slots[1].difficulty).toEqual("shardbreaker")
		expect(viewed.slots[1].rank).toEqual(4)
		expect(viewed.slots[2].difficulty).toEqual("shardbreaker")
		expect(viewed.slots[3].open).toEqual(true)
		expect(viewed.slots[3].difficulty).toEqual("hard")
		expect(viewed.slots[3].rank).toEqual(3)
	end)

	it("trims and lowercases the boss and the difficulty", function()
		local noted = RaidVault.note(nil, boss(" Twins ", " Hard "), TUESDAY)
		expect(noted.ok).toEqual(true)
		expect(noted.state.kills[1].bossId).toEqual("twins")
		expect(noted.state.kills[1].difficulty).toEqual("hard")
		expect(noted.state.kills[1].guided).toEqual(false)
	end)
end)

describe("RaidVault same boss", function()
	it("counts each boss and difficulty once and keeps the earlier row", function()
		local first = RaidVault.note(nil, boss("twins", "story"), TUESDAY)
		expect(first.killCount).toEqual(1)
		local again = RaidVault.note(first.state, boss("twins", "story"), TUESDAY)
		expect(again.ok).toEqual(true)
		expect(again.counted).toEqual(false)
		expect(again.upgraded).toEqual(false)
		expect(again.duplicate).toEqual(true)
		expect(again.reason).toEqual(REASONS.duplicate)
		expect(again.killCount).toEqual(1)
		expect(again.persist).toEqual(false)
		expect(first.state.kills[1].difficulty).toEqual("story")

		local higher =
			RaidVault.note(again.state, boss("twins", "shardbreaker", { guided = true }), TUESDAY)
		expect(higher.ok).toEqual(true)
		expect(higher.counted).toEqual(true)
		expect(higher.upgraded).toEqual(false)
		expect(higher.duplicate).toEqual(false)
		expect(higher.persist).toEqual(true)
		expect(higher.killCount).toEqual(2)
		expect(higher.state.kills[1].difficulty).toEqual("story")
		expect(higher.state.kills[1].guided).toEqual(false)
		expect(higher.state.kills[2].difficulty).toEqual("shardbreaker")
		expect(higher.state.kills[2].guided).toEqual(true)
		expect(again.state.kills[1].difficulty).toEqual("story")

		local lower = RaidVault.note(higher.state, boss("twins", "normal"), TUESDAY)
		expect(lower.counted).toEqual(true)
		expect(lower.upgraded).toEqual(false)
		expect(lower.duplicate).toEqual(false)
		expect(lower.killCount).toEqual(3)
		expect(lower.state.kills[1].difficulty).toEqual("story")

		local sameHigh =
			RaidVault.note(lower.state, boss("twins", "shardbreaker", { guided = false }), TUESDAY)
		expect(sameHigh.duplicate).toEqual(true)
		expect(sameHigh.counted).toEqual(false)
		expect(sameHigh.persist).toEqual(false)
		expect(sameHigh.killCount).toEqual(3)
		expect(sameHigh.state.kills[2].guided).toEqual(true)

		local viewed = RaidVault.view(sameHigh.state, TUESDAY)
		expect(viewed.choiceCount).toEqual(1)
		expect(viewed.slots[1].difficulty).toEqual("normal")
		expect(viewed.slots[2].open).toEqual(false)
	end)

	it("counts the same boss on a second id as a different kill", function()
		local state = earn(fresh(), {
			boss("twins", "story"),
			boss("sapwell", "normal"),
		}, TUESDAY)
		local viewed = RaidVault.view(state, TUESDAY)
		expect(viewed.killCount).toEqual(2)
		expect(viewed.choiceCount).toEqual(1)
		expect(viewed.slots[1].difficulty).toEqual("story")
	end)
end)

describe("RaidVault skips", function()
	it("does not count Practice Grove, an AFK removal, or a vote-kick", function()
		local practice = RaidVault.note(nil, boss("twins", "hard", { practice = true }), TUESDAY)
		expect(practice.ok).toEqual(true)
		expect(practice.counted).toEqual(false)
		expect(practice.reason).toEqual(REASONS.practice)
		expect(practice.killCount).toEqual(0)
		expect(practice.choiceCount).toEqual(0)

		local afk =
			RaidVault.note(practice.state, boss("twins", "hard", { removal = " AFK " }), TUESDAY)
		expect(afk.ok).toEqual(true)
		expect(afk.counted).toEqual(false)
		expect(afk.reason).toEqual(REASONS.afk)
		expect(afk.killCount).toEqual(0)

		local kick =
			RaidVault.note(afk.state, boss("sapwell", "hard", { removal = "kick" }), TUESDAY)
		expect(kick.reason).toEqual(REASONS.kick)
		expect(kick.killCount).toEqual(0)
		expect(#kick.state.kills).toEqual(0)
	end)

	it("counts a Guided kill and keeps the flag", function()
		local noted = RaidVault.note(nil, boss("twins", "hard", { guided = true }), TUESDAY)
		expect(noted.counted).toEqual(true)
		expect(noted.state.kills[1].guided).toEqual(true)
		local same = RaidVault.note(noted.state, boss("twins", "hard", { guided = false }), TUESDAY)
		expect(same.duplicate).toEqual(true)
		expect(same.state.kills[1].guided).toEqual(true)
		local higher = RaidVault.note(noted.state, boss("twins", "shardbreaker"), TUESDAY)
		expect(higher.counted).toEqual(true)
		expect(higher.upgraded).toEqual(false)
		expect(higher.killCount).toEqual(2)
		expect(higher.state.kills[1].guided).toEqual(true)
		expect(higher.state.kills[1].difficulty).toEqual("hard")
		expect(higher.state.kills[2].guided).toEqual(false)
		expect(higher.state.kills[2].difficulty).toEqual("shardbreaker")
	end)

	it("lets practice win when a removal is also set", function()
		local noted = RaidVault.note(
			nil,
			boss("twins", "story", {
				practice = true,
				removal = "afk",
				guided = true,
			}),
			TUESDAY
		)
		expect(noted.reason).toEqual(REASONS.practice)
		expect(noted.killCount).toEqual(0)
	end)

	it("refuses fracture, guided-as-a-difficulty, and an unknown removal", function()
		expect(RaidVault.note(nil, boss("twins", "fracture"), TUESDAY).error).toEqual(
			ERRORS.difficulty
		)
		expect(RaidVault.note(nil, boss("twins", " guided "), TUESDAY).error).toEqual(
			ERRORS.difficulty
		)
		expect(RaidVault.note(nil, boss("twins", "story", { removal = "idle" }), TUESDAY).error).toEqual(
			ERRORS.removal
		)
		expect(RaidVault.note(nil, boss("twins", "story", { removal = "leave" }), TUESDAY).error).toEqual(
			ERRORS.removal
		)
		expect(RaidVault.note(nil, boss("  ", "story"), TUESDAY).error).toEqual(ERRORS.boss)
		expect(RaidVault.note(nil, boss("twins", "story", { practice = "yes" }), TUESDAY).error).toEqual(
			ERRORS.practice
		)
		expect(RaidVault.note(nil, boss("twins", "story", { guided = 1 }), TUESDAY).error).toEqual(
			ERRORS.guided
		)
		expect(RaidVault.note(nil, "twins", TUESDAY).error).toEqual(ERRORS.kill)
		expect(RaidVault.note(nil, nil, TUESDAY).error).toEqual(ERRORS.kill)
	end)
end)

describe("RaidVault reset", function()
	it("opens last week's choices at Tuesday and starts the new week empty", function()
		local earned = earn(fresh(), heartwood("hard"), TUESDAY + 10)
		local opened = RaidVault.view(earned, TUESDAY + WEEK)
		expect(opened.ok).toEqual(true)
		expect(opened.rolled).toEqual(true)
		expect(opened.persist).toEqual(true)
		expect(opened.expired).toEqual(false)
		expect(opened.weekKey).toEqual(2964)
		expect(opened.killCount).toEqual(0)
		expect(opened.choiceCount).toEqual(0)
		expect(opened.vault.earnedWeek).toEqual(2963)
		expect(opened.vault.opensWeek).toEqual(2964)
		expect(opened.vault.expiresWeek).toEqual(2965)
		expect(opened.vault.choiceCount).toEqual(2)
		expect(opened.vault.slots[1].difficulty).toEqual("hard")
		expect(opened.vault.slots[2].difficulty).toEqual("hard")
		expect(opened.vault.offered).toEqual(false)
		expect(opened.vault.picked).toBeNil()
		expect(opened.vault.item).toBeNil()
		expect(earned.weekKey).toEqual(2963)
		expect(#earned.kills).toEqual(4)
	end)

	it("puts a kill at the reset instant on the new week and opens the old Vault", function()
		local earned =
			earn(fresh(), { boss("twins", "normal"), boss("sapwell", "normal") }, TUESDAY + 5)
		local noted = RaidVault.note(earned, boss("galecrown", "story"), TUESDAY + WEEK)
		expect(noted.ok).toEqual(true)
		expect(noted.rolled).toEqual(true)
		expect(noted.counted).toEqual(true)
		expect(noted.weekKey).toEqual(2964)
		expect(noted.killCount).toEqual(1)
		expect(noted.state.kills[1].bossId).toEqual("galecrown")
		expect(noted.vault.choiceCount).toEqual(1)
		expect(noted.vault.slots[1].difficulty).toEqual("normal")
		expect(noted.vault.killCount).toEqual(2)
		expect(#earned.kills).toEqual(2)
	end)

	it("refuses a pick during the earning week", function()
		local earned = earn(fresh(), heartwood("normal"), TUESDAY)
		local early = RaidVault.pick(earned, 1, TUESDAY + 100)
		expect(early.ok).toEqual(false)
		expect(early.error).toEqual(ERRORS.early)
		expect(early.item).toBeNil()
		expect(early.persist).toEqual(false)
		local offered = RaidVault.offer(earned, { { id = "a" }, { id = "b" } }, TUESDAY + 100)
		expect(offered.ok).toEqual(false)
		expect(offered.error).toEqual(ERRORS.early)
	end)

	it("offers the caller's items and lets the player pick one", function()
		local earned = earn(fresh(), {
			boss("twins", "shardbreaker"),
			boss("sapwell", "hard"),
			boss("galecrown", "normal"),
			boss("awakened", "story"),
		}, TUESDAY)
		local items = {
			{ id = "edge", slot = "weapon", difficulty = "hard", stats = { power = 1 } },
			{ id = "helm", slot = "head", difficulty = "story" },
		}
		local offered = RaidVault.offer(earned, items, TUESDAY + WEEK)
		expect(offered.ok).toEqual(true)
		expect(offered.persist).toEqual(true)
		expect(offered.choiceCount).toEqual(2)
		expect(#offered.choices).toEqual(2)
		expect(offered.choices[1].difficulty).toEqual("hard")
		expect(offered.choices[1].slot).toEqual(1)
		expect(offered.choices[1].threshold).toEqual(2)
		expect(offered.choices[1].item.id).toEqual("edge")
		expect(offered.choices[2].difficulty).toEqual("story")
		expect(offered.choices[2].item.id).toEqual("helm")
		expect(identical(offered.choices[1].item, items[1])).toEqual(false)
		items[1].id = "changed"
		items[1].stats.power = 9
		expect(offered.state.vault.choices[1].id).toEqual("edge")
		expect(offered.state.vault.choices[1].stats.power).toEqual(1)
		expect(offered.choices[1].item.id).toEqual("edge")
		expect(offered.choices[1].item.stats.power).toEqual(1)

		local picked = RaidVault.pick(offered.state, 1, TUESDAY + WEEK + 20)
		expect(picked.ok).toEqual(true)
		expect(picked.persist).toEqual(true)
		expect(picked.index).toEqual(1)
		expect(picked.slot).toEqual(1)
		expect(picked.difficulty).toEqual("hard")
		expect(picked.rank).toEqual(3)
		expect(picked.item.id).toEqual("edge")
		expect(identical(picked.item, offered.state.vault.choices[1])).toEqual(false)
		expect(picked.state.vault.picked).toEqual(1)
		expect(offered.state.vault.picked).toBeNil()

		local again = RaidVault.pick(picked.state, 2, TUESDAY + WEEK + 30)
		expect(again.ok).toEqual(false)
		expect(again.error).toEqual(ERRORS.picked)
		expect(again.item).toBeNil()
		expect(again.persist).toEqual(false)
		expect(picked.state.vault.picked).toEqual(1)

		local replaced = RaidVault.offer(picked.state, {
			{ id = "other" },
			{ id = "nope" },
		}, TUESDAY + WEEK + 40)
		expect(replaced.ok).toEqual(false)
		expect(replaced.error).toEqual(ERRORS.picked)
		expect(picked.state.vault.choices[1].id).toEqual("edge")
	end)

	it("locks the first offer so a second offer cannot reroll", function()
		local earned =
			earn(fresh(), { boss("twins", "normal"), boss("sapwell", "normal") }, TUESDAY)
		local first = RaidVault.offer(earned, {
			{ id = "heartshard", difficulty = "normal" },
		}, TUESDAY + WEEK)
		expect(first.ok).toEqual(true)
		expect(first.choices[1].item.id).toEqual("heartshard")
		expect(first.choices[1].difficulty).toEqual("normal")
		local second = RaidVault.offer(first.state, {
			{ id = "sapwell-helm", difficulty = "normal" },
		}, TUESDAY + WEEK + 1)
		expect(second.ok).toEqual(false)
		expect(second.error).toEqual(ERRORS.locked)
		expect(second.persist).toEqual(false)
		expect(second.state.vault.choices[1].id).toEqual("heartshard")
		expect(first.state.vault.choices[1].id).toEqual("heartshard")
		local picked = RaidVault.pick(first.state, 1, TUESDAY + WEEK + 2)
		expect(picked.ok).toEqual(true)
		expect(picked.item.id).toEqual("heartshard")
		expect(picked.difficulty).toEqual("normal")
	end)

	it("refuses an item whose difficulty does not match its slot", function()
		local earned = earn(fresh(), {
			boss("twins", "shardbreaker"),
			boss("sapwell", "hard"),
			boss("galecrown", "normal"),
			boss("awakened", "story"),
		}, TUESDAY)
		local claim = TUESDAY + WEEK
		local swapped = RaidVault.offer(earned, {
			{ id = "edge", difficulty = "story" },
			{ id = "helm", difficulty = "hard" },
		}, claim)
		expect(swapped.ok).toEqual(false)
		expect(swapped.error).toEqual(ERRORS.quality)
		expect(swapped.persist).toEqual(true)
		expect(swapped.state.vault.choices).toBeNil()
		expect(swapped.state.vault.picked).toBeNil()

		local missing = RaidVault.offer(swapped.state, {
			{ id = "edge", quality = 1 },
			{ id = "helm", difficulty = "story" },
		}, claim + 1)
		expect(missing.error).toEqual(ERRORS.quality)
		expect(missing.persist).toEqual(false)
		expect(missing.state.vault.choices).toBeNil()

		local disagree = RaidVault.offer(missing.state, {
			{ id = "edge", difficulty = "hard", quality = "story" },
			{ id = "helm", difficulty = "story" },
		}, claim + 1)
		expect(disagree.error).toEqual(ERRORS.quality)

		local text = RaidVault.offer(missing.state, { "heartshard", "helm" }, claim + 1)
		expect(text.error).toEqual(ERRORS.quality)

		local cycle: any = { id = "edge", difficulty = "hard" }
		cycle.self = cycle
		local looped = RaidVault.offer(missing.state, {
			cycle,
			{ id = "helm", difficulty = "story" },
		}, claim + 1)
		expect(looped.error).toEqual(ERRORS.item)
		expect(looped.state.vault.choices).toBeNil()

		local matched = RaidVault.offer(missing.state, {
			{ id = "edge", difficulty = " Hard " },
			{ id = "helm", quality = "story" },
		}, claim + 1)
		expect(matched.ok).toEqual(true)
		expect(matched.choices[1].difficulty).toEqual("hard")
		expect(matched.choices[2].difficulty).toEqual("story")
		expect(matched.state.vault.choices[1].difficulty).toEqual(" Hard ")

		local crafted = RaidVault.view(
			earn(fresh(), {
				boss("twins", "normal"),
				boss("sapwell", "normal"),
			}, TUESDAY),
			TUESDAY + WEEK
		)
		local tampered = {
			weekKey = crafted.state.weekKey,
			kills = crafted.state.kills,
			vault = {
				earnedWeek = crafted.state.vault.earnedWeek,
				kills = crafted.state.vault.kills,
				choices = { { id = "wrong", difficulty = "story" } },
				picked = nil,
			},
		}
		local denied = RaidVault.pick(tampered, 1, TUESDAY + WEEK)
		expect(denied.ok).toEqual(false)
		expect(denied.error).toEqual(ERRORS.quality)
		expect(denied.item).toBeNil()
		expect(denied.persist).toEqual(false)
		expect(denied.state.vault.picked).toBeNil()
		expect(tampered.vault.picked).toBeNil()
	end)

	it("refuses the wrong number of items and a pick before the offer", function()
		local earned = earn(fresh(), heartwood("normal"), TUESDAY)
		local claim = TUESDAY + WEEK
		local short = RaidVault.offer(earned, { { id = "only" } }, claim)
		expect(short.ok).toEqual(false)
		expect(short.error).toEqual(ERRORS.count)
		expect(short.choiceCount).toEqual(2)
		expect(short.persist).toEqual(true)
		expect(short.state.vault.choices).toBeNil()
		local extra = RaidVault.offer(short.state, { "a", "b", "c" }, claim + 1)
		expect(extra.error).toEqual(ERRORS.count)
		local bad = RaidVault.offer(short.state, { "", "helm" }, claim + 1)
		expect(bad.error).toEqual(ERRORS.item)
		local missing = RaidVault.offer(short.state, "helm", claim + 1)
		expect(missing.error).toEqual(ERRORS.items)
		local earlyPick = RaidVault.pick(short.state, 1, claim + 1)
		expect(earlyPick.error).toEqual(ERRORS.offer)
		expect(earlyPick.item).toBeNil()
	end)

	it("accepts a pick through the last second and expires it on the next Tuesday", function()
		local earned = earn(fresh(), { boss("twins", "hard"), boss("sapwell", "hard") }, TUESDAY)
		local offered = RaidVault.offer(earned, {
			{ id = "keep", difficulty = "hard" },
		}, TUESDAY + WEEK)
		local inTime = RaidVault.pick(offered.state, 1, TUESDAY + (2 * WEEK) - 1)
		expect(inTime.ok).toEqual(true)
		expect(inTime.item.id).toEqual("keep")
		expect(RaidVault.weekKey(TUESDAY + (2 * WEEK) - 1)).toEqual(2964)

		local late = RaidVault.pick(offered.state, 1, TUESDAY + (2 * WEEK))
		expect(late.ok).toEqual(false)
		expect(late.error).toEqual(ERRORS.expired)
		expect(late.expired).toEqual(true)
		expect(late.item).toBeNil()
		expect(late.persist).toEqual(true)
		expect(late.state.vault).toBeNil()
		expect(late.state.weekKey).toEqual(2965)
		expect(offered.state.vault.choices[1].id).toEqual("keep")
	end)

	it("drops an unpicked Vault when the claim week is skipped and does not grant it", function()
		local earned = earn(fresh(), heartwood("shardbreaker"), TUESDAY)
		local skipped = RaidVault.view(earned, TUESDAY + (2 * WEEK))
		expect(skipped.ok).toEqual(true)
		expect(skipped.expired).toEqual(true)
		expect(skipped.persist).toEqual(true)
		expect(skipped.vault).toBeNil()
		expect(skipped.killCount).toEqual(0)
		expect(skipped.weekKey).toEqual(2965)
		local picked = RaidVault.pick(skipped.state, 1, TUESDAY + (2 * WEEK))
		expect(picked.ok).toEqual(false)
		expect(picked.item).toBeNil()
	end)

	it("does not call a one-boss week an expired Vault", function()
		local earned = earn(fresh(), { boss("twins", "hard") }, TUESDAY)
		local nextWeek = RaidVault.view(earned, TUESDAY + WEEK)
		expect(nextWeek.expired).toEqual(false)
		expect(nextWeek.vault).toBeNil()
		expect(nextWeek.error).toBeNil()
		local skipped = RaidVault.view(earned, TUESDAY + (2 * WEEK))
		expect(skipped.expired).toEqual(false)
		expect(skipped.vault).toBeNil()
	end)

	it("expires a claimed-but-unpicked Vault when the next week also opens", function()
		local first = earn(fresh(), { boss("twins", "normal"), boss("sapwell", "normal") }, TUESDAY)
		local opened = RaidVault.view(first, TUESDAY + WEEK)
		expect(opened.vault.choiceCount).toEqual(1)
		local second = earn(opened.state, heartwood("hard"), TUESDAY + WEEK + 5)
		local rolled = RaidVault.view(second, TUESDAY + (2 * WEEK))
		expect(rolled.expired).toEqual(true)
		expect(rolled.vault.choiceCount).toEqual(2)
		expect(rolled.vault.slots[1].difficulty).toEqual("hard")
		expect(rolled.vault.offered).toEqual(false)
	end)

	it("lets the same boss count again in the next week", function()
		local earned = earn(fresh(), { boss("twins", "story"), boss("sapwell", "story") }, TUESDAY)
		local noted = RaidVault.note(earned, boss("twins", "hard"), TUESDAY + WEEK)
		expect(noted.counted).toEqual(true)
		expect(noted.killCount).toEqual(1)
		expect(noted.state.kills[1].difficulty).toEqual("hard")
		expect(noted.vault.killCount).toEqual(2)
	end)
end)

describe("RaidVault guards", function()
	it("rejects a bad clock and does not roll backwards", function()
		local earned =
			earn(fresh(), { boss("twins", "normal"), boss("sapwell", "normal") }, TUESDAY)
		local missing = RaidVault.note(earned, boss("galecrown", "normal"), nil :: any)
		expect(missing.ok).toEqual(false)
		expect(missing.error).toEqual(ERRORS.time)
		expect(missing.persist).toEqual(false)
		expect(#earned.kills).toEqual(2)
		expect(RaidVault.view(earned, 0 / 0).error).toEqual(ERRORS.time)
		expect(RaidVault.view(earned, -5).error).toEqual(ERRORS.time)
		expect(RaidVault.view(earned, math.huge).error).toEqual(ERRORS.time)
		local back = RaidVault.note(earned, boss("galecrown", "normal"), TUESDAY - 1)
		expect(back.ok).toEqual(false)
		expect(back.error).toEqual(ERRORS.clock)
		expect(back.persist).toEqual(false)
		expect(back.state.weekKey).toEqual(2963)
		expect(#back.state.kills).toEqual(2)
		expect(#earned.kills).toEqual(2)
	end)

	it("treats a missing record as a fresh week and refuses a broken one", function()
		local noted = RaidVault.note(nil, boss("twins", "story"), TUESDAY)
		expect(noted.ok).toEqual(true)
		expect(noted.weekKey).toEqual(2963)
		expect(noted.rolled).toEqual(true)
		expect(noted.killCount).toEqual(1)
		expect(RaidVault.note("nope" :: any, boss("twins", "story"), TUESDAY).error).toEqual(
			ERRORS.state
		)
		expect(RaidVault.view({ weekKey = 0 / 0, kills = {} }, TUESDAY).error).toEqual(ERRORS.state)
		expect(RaidVault.view({ weekKey = 1.5, kills = {} }, TUESDAY).error).toEqual(ERRORS.state)
		expect(RaidVault.view({ weekKey = 1e16, kills = {} }, TUESDAY).error).toEqual(ERRORS.state)
		local negative = RaidVault.view({
			weekKey = -50,
			kills = { { bossId = "twins", difficulty = "hard", guided = false } },
		}, TUESDAY)
		expect(negative.ok).toEqual(true)
		expect(negative.killCount).toEqual(0)
		expect(negative.vault).toBeNil()
		expect(RaidVault.view({
			weekKey = 2963,
			kills = {
				{ bossId = "twins", difficulty = "story", guided = false },
				{ bossId = "twins", difficulty = "story", guided = true },
			},
		}, TUESDAY).error).toEqual(ERRORS.state)
		expect(RaidVault.view({
			weekKey = 2963,
			kills = {
				{ bossId = "twins", difficulty = "hard", guided = false },
				{ bossId = "twins", difficulty = "story", guided = true },
			},
		}, TUESDAY).killCount).toEqual(2)
		expect(RaidVault.view({ weekKey = 2963, kills = "nope" }, TUESDAY).error).toEqual(
			ERRORS.state
		)
		expect(RaidVault.view({
			weekKey = 2963,
			kills = { { bossId = "Twins", difficulty = "story" } },
		}, TUESDAY).error).toEqual(ERRORS.state)
		local frozen = table.freeze({})
		local fromFrozen = RaidVault.note(frozen, boss("twins", "story"), TUESDAY)
		expect(fromFrozen.ok).toEqual(true)
		expect(fromFrozen.state.kills[1].bossId).toEqual("twins")
	end)

	it("does not carry kills stored on an unstamped week", function()
		local noted = RaidVault.note({
			weekKey = -1,
			kills = { { bossId = "twins", difficulty = "hard", guided = false } },
		}, boss("sapwell", "story"), TUESDAY)
		expect(noted.ok).toEqual(true)
		expect(noted.killCount).toEqual(1)
		expect(noted.state.kills[1].bossId).toEqual("sapwell")
		expect(noted.vault).toBeNil()
	end)

	it("refuses a pick index that is not an open choice", function()
		local earned =
			earn(fresh(), { boss("twins", "normal"), boss("sapwell", "normal") }, TUESDAY)
		local offered = RaidVault.offer(earned, {
			{ id = "one", difficulty = "normal" },
		}, TUESDAY + WEEK)
		expect(RaidVault.pick(offered.state, 0, TUESDAY + WEEK).error).toEqual(ERRORS.pick)
		expect(RaidVault.pick(offered.state, 2, TUESDAY + WEEK).error).toEqual(ERRORS.pick)
		expect(RaidVault.pick(offered.state, 1.5, TUESDAY + WEEK).error).toEqual(ERRORS.pick)
		expect(RaidVault.pick(offered.state, "1", TUESDAY + WEEK).error).toEqual(ERRORS.pick)
		expect(RaidVault.pick(offered.state, 0 / 0, TUESDAY + WEEK).error).toEqual(ERRORS.pick)
		expect(RaidVault.pick(offered.state, math.huge, TUESDAY + WEEK).error).toEqual(ERRORS.pick)
		expect(RaidVault.pick(offered.state, 1, TUESDAY + WEEK).ok).toEqual(true)
	end)

	it("returns a closed Vault when nothing was earned", function()
		local opened = RaidVault.view(nil, TUESDAY)
		expect(opened.ok).toEqual(true)
		expect(opened.weekKey).toEqual(2963)
		expect(opened.vault).toBeNil()
		local offer = RaidVault.offer(opened.state, { { id = "a" } }, TUESDAY)
		expect(offer.error).toEqual(ERRORS.closed)
		local pick = RaidVault.pick(opened.state, 1, TUESDAY)
		expect(pick.error).toEqual(ERRORS.closed)
		expect(pick.item).toBeNil()
	end)
end)

describe("RaidVault isolation", function()
	it("returns new tables and does not write the input", function()
		local state = earn(fresh(), heartwood("normal"), TUESDAY)
		local kills = state.kills
		local firstKill = kills[1]
		table.freeze(firstKill)
		local noted = RaidVault.note(state, boss("choir", "hard"), TUESDAY)
		expect(noted.ok).toEqual(true)
		expect(identical(noted.state, state)).toEqual(false)
		expect(identical(noted.state.kills, kills)).toEqual(false)
		expect(identical(noted.state.kills[1], firstKill)).toEqual(false)
		expect(#kills).toEqual(4)
		expect(firstKill.difficulty).toEqual("normal")
		expect(#noted.state.kills).toEqual(5)
		noted.state.kills[1].difficulty = "story"
		expect(firstKill.difficulty).toEqual("normal")

		local opened = RaidVault.fresh()
		local again = RaidVault.fresh()
		expect(identical(opened, again)).toEqual(false)
		expect(identical(opened.state, again.state)).toEqual(false)
		expect(identical(opened.state.kills, again.state.kills)).toEqual(false)

		local claim = RaidVault.view(state, TUESDAY + WEEK)
		expect(identical(claim.state, state)).toEqual(false)
		expect(identical(claim.state.vault.kills, state.kills)).toEqual(false)
		expect(#state.kills).toEqual(4)
		expect(state.vault).toBeNil()
	end)

	it("is not required by src and does not reach a service", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidVault.luau")
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "RaidMarks", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "DataStoreService", 1, true)).toBeNil()
		expect(string.find(source, "MemoryStoreService", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if
				path ~= "src/ReplicatedStorage/Shared/RaidVault.luau"
				and mentionsVault(fs.readFile(path))
			then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
