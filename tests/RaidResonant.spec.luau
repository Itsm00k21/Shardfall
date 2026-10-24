--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidResonant = require("../src/ReplicatedStorage/Shared/RaidResonant")

local ERRORS = RaidResonant.ERRORS
local REASONS = RaidResonant.REASONS

local function identical(left: any, right: any): boolean
	return left == right
end

local function fresh(): any
	local opened = RaidResonant.fresh()
	expect(opened.ok).toEqual(true)
	return opened.state
end

local function drop(weaponId: string, uid: string, extra: { [string]: any }?): { [string]: any }
	local row: { [string]: any } = {
		weaponId = weaponId,
		resonant = true,
		practice = false,
		uid = uid,
	}
	if extra ~= nil then
		for key, value in pairs(extra) do
			row[key] = value
		end
	end
	return row
end

local function countOf(state: any, weaponId: string): (number, boolean, { string })
	for _, row in ipairs(state.weapons) do
		if row.weaponId == weaponId then
			return row.count, row.unlocked, row.uids
		end
	end
	return 0, false, {}
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

local function mentionsResonant(source: string): boolean
	if string.find(source, "Shared.RaidResonant", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidResonant", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidResonant", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidResonant")', 1, true) ~= nil then
		return true
	end
	return false
end

describe("RaidResonant config", function()
	it("pins the threshold at 3", function()
		expect(RaidResonant.CONFIG.threshold).toEqual(3)
		expect(RaidResonant.CONFIG.maxIdLength).toEqual(64)
	end)

	it("freezes the threshold, the reasons, and the errors", function()
		expect(function()
			RaidResonant.CONFIG.threshold = 1
		end).toThrow()
		expect(function()
			RaidResonant.CONFIG.maxIdLength = 8
		end).toThrow()
		expect(function()
			RaidResonant.REASONS.practice = "grove"
		end).toThrow()
		expect(function()
			RaidResonant.ERRORS.uid = "fine"
		end).toThrow()
	end)

	it("has no Robux price, no craft cost, and no paid skip", function()
		local banned = {
			robux = true,
			premium = true,
			productid = true,
			gamepass = true,
			skip = true,
			price = true,
			marks = true,
			material = true,
			materials = true,
			cost = true,
		}
		for key in pairs(RaidResonant.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
	end)
end)

describe("RaidResonant drops", function()
	it("counts a resonant drop toward that weapon", function()
		local noted = RaidResonant.note(nil, drop("axe", "a1"))
		expect(noted.ok).toEqual(true)
		expect(noted.persist).toEqual(true)
		expect(noted.counted).toEqual(true)
		expect(noted.duplicate).toEqual(false)
		expect(noted.reason).toBeNil()
		expect(noted.error).toBeNil()
		expect(noted.weaponId).toEqual("axe")
		expect(noted.count).toEqual(1)
		expect(noted.unlocked).toEqual(false)
		expect(noted.threshold).toEqual(3)
		expect(noted.state.weapons).toEqual({
			{
				weaponId = "axe",
				count = 1,
				unlocked = false,
				uids = { "a1" },
			},
		})
	end)

	it("unlocks the pattern on the third resonant drop and sticks there", function()
		local state = fresh()
		local first = RaidResonant.note(state, drop("axe", "a1"))
		local second = RaidResonant.note(first.state, drop("axe", "a2"))
		expect(second.ok).toEqual(true)
		expect(second.count).toEqual(2)
		expect(second.unlocked).toEqual(false)
		expect(second.persist).toEqual(true)

		local third = RaidResonant.note(second.state, drop("axe", "a3"))
		expect(third.ok).toEqual(true)
		expect(third.counted).toEqual(true)
		expect(third.persist).toEqual(true)
		expect(third.count).toEqual(3)
		expect(third.unlocked).toEqual(true)
		expect(third.reason).toBeNil()

		local fourth = RaidResonant.note(third.state, drop("axe", "a4"))
		expect(fourth.ok).toEqual(true)
		expect(fourth.counted).toEqual(false)
		expect(fourth.persist).toEqual(false)
		expect(fourth.duplicate).toEqual(false)
		expect(fourth.reason).toEqual(REASONS.capped)
		expect(fourth.count).toEqual(3)
		expect(fourth.unlocked).toEqual(true)
		local count, unlocked, uids = countOf(fourth.state, "axe")
		expect(count).toEqual(3)
		expect(unlocked).toEqual(true)
		expect(uids).toEqual({ "a1", "a2", "a3" })

		local fifth = RaidResonant.note(fourth.state, drop("axe", "a5"))
		expect(fifth.reason).toEqual(REASONS.capped)
		expect(fifth.count).toEqual(3)
		expect(fifth.unlocked).toEqual(true)
		expect(countOf(fifth.state, "axe")).toEqual(3)
	end)

	it("keeps two weapons on their own counts", function()
		local state = fresh()
		local axe = RaidResonant.note(state, drop("axe", "a1"))
		local bow = RaidResonant.note(axe.state, drop("bow", "b1"))
		local axeAgain = RaidResonant.note(bow.state, drop("axe", "a2"))
		expect(axeAgain.state.weapons[1].weaponId).toEqual("axe")
		expect(axeAgain.state.weapons[2].weaponId).toEqual("bow")
		expect(axeAgain.count).toEqual(2)
		expect(axeAgain.unlocked).toEqual(false)
		local bowCount, bowOpen = countOf(axeAgain.state, "bow")
		expect(bowCount).toEqual(1)
		expect(bowOpen).toEqual(false)

		local axeThird = RaidResonant.note(axeAgain.state, drop("axe", "a3"))
		expect(axeThird.unlocked).toEqual(true)
		expect(axeThird.count).toEqual(3)
		local stillBow, bowUnlocked = countOf(axeThird.state, "bow")
		expect(stillBow).toEqual(1)
		expect(bowUnlocked).toEqual(false)
	end)

	it("trims the weapon id and does not fold case", function()
		local first = RaidResonant.note(nil, drop("  axe  ", "a1"))
		expect(first.ok).toEqual(true)
		expect(first.weaponId).toEqual("axe")
		local second = RaidResonant.note(first.state, drop("axe", "a2"))
		expect(second.count).toEqual(2)
		local other = RaidResonant.note(second.state, drop("Axe", "a3"))
		expect(other.counted).toEqual(true)
		expect(other.count).toEqual(1)
		expect(other.unlocked).toEqual(false)
		expect(#other.state.weapons).toEqual(2)
	end)

	it("refuses a missing weapon id", function()
		local state = fresh()
		local noted = RaidResonant.note(state, drop("", "a1"))
		expect(noted.ok).toEqual(false)
		expect(noted.persist).toEqual(false)
		expect(noted.error).toEqual(ERRORS.weapon)
		expect(noted.state.weapons).toEqual({})
		expect(RaidResonant.note(state, drop("   ", "a1")).error).toEqual(ERRORS.weapon)
		expect(RaidResonant.note(state, drop(1 :: any, "a1")).error).toEqual(ERRORS.weapon)
		expect(RaidResonant.note(state, { resonant = true, uid = "a1" }).error).toEqual(
			ERRORS.weapon
		)
		local longId = string.rep("a", 65)
		expect(RaidResonant.note(state, drop(longId, "a1")).error).toEqual(ERRORS.weapon)
	end)

	it("does not count the same uid twice", function()
		local first = RaidResonant.note(nil, drop("axe", "same"))
		local again = RaidResonant.note(first.state, drop("axe", "same"))
		expect(again.ok).toEqual(true)
		expect(again.counted).toEqual(false)
		expect(again.persist).toEqual(false)
		expect(again.duplicate).toEqual(true)
		expect(again.reason).toEqual(REASONS.duplicate)
		expect(again.count).toEqual(1)
		expect(again.unlocked).toEqual(false)
		expect(again.state.weapons[1].uids).toEqual({ "same" })

		local trimmed = RaidResonant.note(first.state, drop("axe", "  same  "))
		expect(trimmed.duplicate).toEqual(true)
		expect(trimmed.count).toEqual(1)
	end)

	it("does not let one uid count toward a second weapon", function()
		local first = RaidResonant.note(nil, drop("axe", "shared"))
		local other = RaidResonant.note(first.state, drop("bow", "shared"))
		expect(other.ok).toEqual(true)
		expect(other.counted).toEqual(false)
		expect(other.duplicate).toEqual(true)
		expect(other.reason).toEqual(REASONS.duplicate)
		expect(other.count).toEqual(0)
		expect(other.unlocked).toEqual(false)
		expect(#other.state.weapons).toEqual(1)
		expect(other.state.weapons[1].weaponId).toEqual("axe")
	end)

	it("refuses a missing uid so a retry cannot double-count", function()
		local state = fresh()
		local missing = RaidResonant.note(state, { weaponId = "axe", resonant = true })
		expect(missing.ok).toEqual(false)
		expect(missing.persist).toEqual(false)
		expect(missing.counted).toEqual(false)
		expect(missing.error).toEqual(ERRORS.uid)
		expect(missing.weaponId).toEqual("axe")
		expect(missing.count).toEqual(0)
		expect(missing.state.weapons).toEqual({})

		local blank = RaidResonant.note(state, drop("axe", "   "))
		expect(blank.error).toEqual(ERRORS.uid)
		expect(blank.persist).toEqual(false)

		local shaped = RaidResonant.note(state, drop("axe", 15 :: any))
		expect(shaped.error).toEqual(ERRORS.uidShape)
		expect(shaped.weaponId).toEqual("axe")

		local longUid = string.rep("u", 65)
		expect(RaidResonant.note(state, drop("axe", longUid)).error).toEqual(ERRORS.uidShape)

		local retry = RaidResonant.note(missing.state, drop("axe", "a1"))
		expect(retry.ok).toEqual(true)
		expect(retry.counted).toEqual(true)
		expect(retry.count).toEqual(1)
		local second = RaidResonant.note(retry.state, drop("axe", "a1"))
		expect(second.duplicate).toEqual(true)
		expect(second.count).toEqual(1)
	end)

	it("ignores a drop that is not resonant", function()
		local state = fresh()
		local cases = {
			drop("axe", "a1", { resonant = false }),
			{ weaponId = "axe", practice = false, uid = "a1" },
			drop("axe", "a1", { resonant = 1 }),
			drop("axe", "a1", { resonant = "true" }),
		}
		for _, row in ipairs(cases) do
			local noted = RaidResonant.note(state, row)
			expect(noted.ok).toEqual(true)
			expect(noted.counted).toEqual(false)
			expect(noted.persist).toEqual(false)
			expect(noted.duplicate).toEqual(false)
			expect(noted.reason).toEqual(REASONS.resonant)
			expect(noted.count).toEqual(0)
			expect(noted.unlocked).toEqual(false)
			expect(noted.state.weapons).toEqual({})
		end
		local later = RaidResonant.note(state, drop("axe", "a1"))
		expect(later.counted).toEqual(true)
		expect(later.count).toEqual(1)
	end)

	it("does not count Practice Grove", function()
		local state = fresh()
		local grove =
			RaidResonant.note(state, drop("axe", "p1", { practice = true, resonant = true }))
		expect(grove.ok).toEqual(true)
		expect(grove.counted).toEqual(false)
		expect(grove.persist).toEqual(false)
		expect(grove.reason).toEqual(REASONS.practice)
		expect(grove.count).toEqual(0)
		expect(grove.unlocked).toEqual(false)
		expect(grove.state.weapons).toEqual({})

		local omitted = RaidResonant.note(nil, { weaponId = "axe", resonant = true, uid = "live" })
		expect(omitted.counted).toEqual(true)
		expect(omitted.count).toEqual(1)

		local live = RaidResonant.note(grove.state, drop("axe", "p1", { practice = false }))
		expect(live.counted).toEqual(true)
		expect(live.count).toEqual(1)
		expect(live.unlocked).toEqual(false)
	end)

	it("reports a replay as a duplicate even when the retry says practice", function()
		local first = RaidResonant.note(nil, drop("axe", "a1"))
		local replay = RaidResonant.note(first.state, drop("axe", "a1", { practice = true }))
		expect(replay.duplicate).toEqual(true)
		expect(replay.reason).toEqual(REASONS.duplicate)
		expect(replay.persist).toEqual(false)
		expect(replay.count).toEqual(1)
		local quiet = RaidResonant.note(first.state, drop("axe", "a1", { resonant = false }))
		expect(quiet.reason).toEqual(REASONS.duplicate)
		expect(quiet.count).toEqual(1)
	end)

	it("refuses a bad practice flag and a bad drop", function()
		local state = fresh()
		expect(RaidResonant.note(state, drop("axe", "a1", { practice = 1 })).error).toEqual(
			ERRORS.practice
		)
		expect(RaidResonant.note(state, drop("axe", "a1", { practice = "true" })).error).toEqual(
			ERRORS.practice
		)
		expect(RaidResonant.note(state, nil).error).toEqual(ERRORS.drop)
		expect(RaidResonant.note(state, "axe").error).toEqual(ERRORS.drop)
		expect(RaidResonant.note(state, 3).error).toEqual(ERRORS.drop)
	end)

	it("ignores extra drop fields and a forged unlock flag", function()
		local noted =
			RaidResonant.note(nil, drop("axe", "a1", { difficulty = "hard", unlocked = true }))
		expect(noted.ok).toEqual(true)
		expect(noted.count).toEqual(1)
		expect(noted.unlocked).toEqual(false)
		expect(noted.state.weapons[1].unlocked).toEqual(false)
	end)

	it("leaves unlock set once the pattern is open", function()
		local state = fresh()
		local current = state
		for index = 1, 3 do
			local noted = RaidResonant.note(current, drop("axe", "u" .. index))
			expect(noted.ok).toEqual(true)
			current = noted.state
		end
		expect(RaidResonant.view(current, "axe").unlocked).toEqual(true)
		local practice = RaidResonant.note(current, drop("axe", "later", { practice = true }))
		expect(practice.unlocked).toEqual(true)
		expect(practice.persist).toEqual(false)
		local quiet = RaidResonant.note(current, drop("axe", "later", { resonant = false }))
		expect(quiet.unlocked).toEqual(true)
		local replay = RaidResonant.note(current, drop("axe", "u1"))
		expect(replay.unlocked).toEqual(true)
		expect(replay.reason).toEqual(REASONS.duplicate)
		local capped = RaidResonant.note(current, drop("axe", "u4"))
		expect(capped.unlocked).toEqual(true)
		expect(capped.reason).toEqual(REASONS.capped)
		expect(capped.count).toEqual(3)
	end)
end)

describe("RaidResonant records", function()
	it("treats a nil record as empty and refuses a broken one", function()
		local opened = RaidResonant.view(nil, nil)
		expect(opened.ok).toEqual(true)
		expect(opened.persist).toEqual(false)
		expect(opened.weapons).toEqual({})
		expect(opened.count).toEqual(0)
		expect(opened.unlocked).toEqual(false)

		local noted = RaidResonant.note({ weapons = nil }, drop("axe", "a1"))
		expect(noted.counted).toEqual(true)

		local broken = {
			{
				weapons = "axe",
			},
			{
				weapons = {
					{
						weaponId = "axe",
						count = 3,
						unlocked = false,
						uids = { "a1", "a2", "a3" },
					},
				},
			},
			{
				weapons = {
					{
						weaponId = "axe",
						count = 1,
						unlocked = true,
						uids = { "a1" },
					},
				},
			},
			{
				weapons = {
					{
						weaponId = "axe",
						count = 4,
						unlocked = true,
						uids = { "a1", "a2", "a3", "a4" },
					},
				},
			},
			{
				weapons = {
					{
						weaponId = " axe ",
						count = 1,
						unlocked = false,
						uids = { "a1" },
					},
				},
			},
			{
				weapons = {
					{
						weaponId = "axe",
						count = 1,
						unlocked = false,
						uids = { " a1 " },
					},
				},
			},
			{
				weapons = {
					{ weaponId = "axe", count = 1, unlocked = false, uids = { "same" } },
					{ weaponId = "bow", count = 1, unlocked = false, uids = { "same" } },
				},
			},
			{
				weapons = {
					{ weaponId = "axe", count = 1, unlocked = false, uids = { "a1" } },
					{ weaponId = "axe", count = 1, unlocked = false, uids = { "a2" } },
				},
			},
			{
				weapons = {
					[1] = { weaponId = "axe", count = 1, unlocked = false, uids = { "a1" } },
					[3] = { weaponId = "bow", count = 1, unlocked = false, uids = { "b1" } },
				},
			},
		}
		for _, state in ipairs(broken) do
			local failed = RaidResonant.note(state, drop("axe", "new"))
			expect(failed.ok).toEqual(false)
			expect(failed.persist).toEqual(false)
			expect(failed.error).toEqual(ERRORS.state)
			expect(failed.state.weapons).toEqual({})
			expect(RaidResonant.view(state, "axe").ok).toEqual(false)
			expect(RaidResonant.view(state, "axe").error).toEqual(ERRORS.state)
		end
		expect(RaidResonant.note(4, drop("axe", "a1")).error).toEqual(ERRORS.state)
		expect(RaidResonant.view("nope", nil).error).toEqual(ERRORS.state)
	end)

	it("reads one weapon and the whole record", function()
		local first = RaidResonant.note(nil, drop("axe", "a1"))
		local second = RaidResonant.note(first.state, drop("bow", "b1"))
		local third = RaidResonant.note(second.state, drop("bow", "b2"))
		local all = RaidResonant.view(third.state, nil)
		expect(all.ok).toEqual(true)
		expect(all.persist).toEqual(false)
		expect(all.weaponId).toBeNil()
		expect(all.threshold).toEqual(3)
		expect(all.weapons).toEqual({
			{ weaponId = "axe", count = 1, unlocked = false, threshold = 3 },
			{ weaponId = "bow", count = 2, unlocked = false, threshold = 3 },
		})

		local one = RaidResonant.view(third.state, "  bow  ")
		expect(one.ok).toEqual(true)
		expect(one.weaponId).toEqual("bow")
		expect(one.count).toEqual(2)
		expect(one.unlocked).toEqual(false)
		expect(#one.weapons).toEqual(2)

		local unseen = RaidResonant.view(third.state, "staff")
		expect(unseen.ok).toEqual(true)
		expect(unseen.count).toEqual(0)
		expect(unseen.unlocked).toEqual(false)
		expect(#unseen.weapons).toEqual(2)
		expect(unseen.persist).toEqual(false)

		expect(RaidResonant.view(third.state, "   ").error).toEqual(ERRORS.weapon)
		expect(RaidResonant.view(third.state, 2).error).toEqual(ERRORS.weapon)
	end)
end)

describe("RaidResonant isolation", function()
	it("returns new tables and does not write the input", function()
		local state = RaidResonant.note(nil, drop("axe", "a1")).state
		local weapons = state.weapons
		local row = weapons[1]
		local uids = row.uids
		table.freeze(uids)
		table.freeze(row)
		table.freeze(weapons)
		table.freeze(state)
		local payload = drop("bow", "  b1  ", { resonant = true })
		table.freeze(payload)
		local noted = RaidResonant.note(state, payload)
		expect(noted.ok).toEqual(true)
		expect(noted.counted).toEqual(true)
		expect(identical(noted.state, state)).toEqual(false)
		expect(identical(noted.state.weapons, weapons)).toEqual(false)
		expect(identical(noted.state.weapons[1], row)).toEqual(false)
		expect(identical(noted.state.weapons[1].uids, uids)).toEqual(false)
		expect(#weapons).toEqual(1)
		expect(row.count).toEqual(1)
		expect(uids[1]).toEqual("a1")
		expect(payload.uid).toEqual("  b1  ")
		noted.state.weapons[1].count = 9
		expect(row.count).toEqual(1)

		local opened = RaidResonant.fresh()
		local again = RaidResonant.fresh()
		expect(identical(opened, again)).toEqual(false)
		expect(identical(opened.state, again.state)).toEqual(false)
		expect(identical(opened.state.weapons, again.state.weapons)).toEqual(false)

		local looked = RaidResonant.view(state, "axe")
		expect(identical(looked.state, state)).toEqual(false)
		expect(identical(looked.state.weapons, weapons)).toEqual(false)
		expect(looked.count).toEqual(1)
		expect(#state.weapons).toEqual(1)
	end)

	it("is not required by src and does not reach a service", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidResonant.luau")
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "docs/content", 1, true)).toBeNil()
		expect(string.find(source, "Crafting", 1, true)).toBeNil()
		expect(string.find(source, "Recipes", 1, true)).toBeNil()
		expect(string.find(source, "RaidMarks", 1, true)).toBeNil()
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
			if
				path ~= "src/ReplicatedStorage/Shared/RaidResonant.luau"
				and mentionsResonant(fs.readFile(path))
			then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
