--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local NameplateTitles = require("../src/ReplicatedStorage/Shared/NameplateTitles")

local ERRORS = NameplateTitles.ERRORS
local CONFIG = NameplateTitles.CONFIG
local ORDER = NameplateTitles.ORDER
local FIELDS = NameplateTitles.FIELDS

local RESERVED_IDS = {
	"sidestep",
	"reel_light",
	"mythic_hand",
	"heartwood_student",
	"boardwalker",
}
local RESERVED_NAMES = {
	"Sidestep",
	"Reel Light",
	"Mythic Hand",
	"Heartwood Student",
	"Boardwalker",
}

local CATALOG = {
	{ "soft_step", "Soft Step", "Common", 10 },
	{ "room_one", "Room One", "Common", 1 },
	{ "tenth_launch", "Tenth Launch", "Common", 10 },
	{ "one_pull", "One Pull", "Common", 1 },
	{ "first_hatch", "First Hatch", "Common", 1 },
	{ "one_trade", "One Trade", "Common", 1 },
	{ "tonic_made", "Tonic Made", "Common", 1 },
	{ "listed_once", "Listed Once", "Common", 1 },
	{ "vault_walker", "Vault Walker", "Uncommon", 1 },
	{ "skill_hand", "Skill Hand", "Uncommon", 50 },
	{ "tenth_luck", "Tenth Luck", "Uncommon", 1 },
	{ "story_leaf", "Story Leaf", "Uncommon", 1 },
	{ "door_four", "Door Four", "Uncommon", 4 },
	{ "morning_seven", "Morning Seven", "Uncommon", 7 },
	{ "combo_spark", "Combo Spark", "Uncommon", 1 },
	{ "thorn_made", "Thorn Made", "Uncommon", 1 },
	{ "deep_vault", "Deep Vault", "Rare", 1 },
	{ "five_classes", "Five Classes", "Rare", 5 },
	{ "rare_chip", "Rare Chip", "Rare", 1 },
	{ "hundred_pulls", "Hundred Pulls", "Rare", 100 },
	{ "full_stars", "Full Stars", "Rare", 5 },
	{ "full_bond", "Full Bond", "Rare", 5 },
	{ "normal_leaf", "Normal Leaf", "Rare", 1 },
	{ "friend_clear", "Friend Clear", "Rare", 1 },
	{ "night_root", "Night Root", "Epic", 1 },
	{ "pity_ready", "Pity Ready", "Epic", 100 },
	{ "epic_seen", "Epic Seen", "Epic", 1 },
	{ "all_eight", "All Eight", "Epic", 8 },
	{ "four_wings", "Four Wings", "Epic", 4 },
	{ "card_stack", "Card Stack", "Epic", 20 },
	{ "legend_chip", "Legend Chip", "Legendary", 3 },
	{ "gold_ladder", "Gold Ladder", "Legendary", 5 },
	{ "two_depths", "Two Depths", "Legendary", 1 },
	{ "long_count", "Long Count", "Legendary", 1000 },
	{ "full_garden", "Full Garden", "Legendary", 8 },
	{ "capped_pouch", "Capped Pouch", "Legendary", 600 },
	{ "awakened_name", "Awakened Name", "Mythic", 1 },
	{ "mythic_reel", "Mythic Reel", "Mythic", 1 },
	{ "nightglass", "Nightglass", "Mythic", 1 },
	{ "prism_name", "Prism Name", "Mythic", 1000 },
}

local FIELD_OF = {
	soft_step = "perfectDodges",
	room_one = "rooms",
	tenth_launch = "launches",
	one_pull = "cracks",
	first_hatch = "hatches",
	one_trade = "trades",
	tonic_made = "tonics",
	listed_once = "listings",
	vault_walker = "rootvaultNormal",
	skill_hand = "skills",
	tenth_luck = "bonusCracks",
	story_leaf = "storyWings",
	door_four = "party",
	morning_seven = "logins",
	combo_spark = "combos",
	thorn_made = "thorns",
	deep_vault = "rootvaultHard",
	five_classes = "classes",
	hundred_pulls = "cracks",
	full_stars = "affinity",
	full_bond = "bond",
	normal_leaf = "normalWings",
	friend_clear = "friendClears",
	night_root = "rootvaultNightmare",
	pity_ready = "epicPity",
	all_eight = "species",
	four_wings = "wings",
	card_stack = "itemBases",
	two_depths = "sameWing",
	long_count = "legendPity",
	capped_pouch = "raidMarksEarned",
	awakened_name = "awakenedNormal",
	mythic_reel = "mythic",
}

local RUNGS = { "common", "uncommon", "rare", "epic", "legendary" }

local function identical(left: any, right: any): boolean
	return left == right
end

local function fresh()
	return NameplateTitles.fresh().state
end

local function zeros()
	local progress: { [string]: any } = {
		practice = false,
	}
	for _, field in ipairs(FIELDS) do
		progress[field] = 0
	end
	return progress
end

local function atLeast(progress, field: string, amount: number)
	if progress[field] < amount then
		progress[field] = amount
	end
end

local function apply(progress, id: string, amount: number)
	if id == "rare_chip" then
		atLeast(progress, "rare", amount)
	elseif id == "epic_seen" then
		atLeast(progress, "epic", amount)
	elseif id == "legend_chip" then
		atLeast(progress, "legendary", amount)
	elseif id == "mythic_reel" then
		atLeast(progress, "mythic", amount)
	elseif id == "gold_ladder" then
		for index, field in ipairs(RUNGS) do
			if index <= amount then
				atLeast(progress, field, 1)
			end
		end
	elseif id == "full_garden" then
		atLeast(progress, "species", amount)
		atLeast(progress, "affinity", 5)
	elseif id == "nightglass" then
		atLeast(progress, "rootvaultNightmare", amount)
		atLeast(progress, "normalWings", 1)
	elseif id == "prism_name" then
		atLeast(progress, "cracks", amount)
		atLeast(progress, "mythicItems", 1)
	else
		atLeast(progress, FIELD_OF[id], amount)
	end
end

local function meet(id: string, amount: number)
	local progress = zeros()
	apply(progress, id, amount)
	return progress
end

local function meetAll()
	local progress = zeros()
	for _, row in ipairs(CATALOG) do
		apply(progress, row[1], row[4])
	end
	return progress
end

local function paysNothing(result)
	expect(result.keys).toEqual(0)
	expect(result.gold).toEqual(0)
	expect(result.marks).toEqual(0)
	expect(result.stats).toEqual(0)
	expect(result.luck).toEqual(0)
	expect(result.payout).toBeNil()
	expect(result.reward).toBeNil()
	expect(result.robux).toBeNil()
	expect(result.productId).toBeNil()
	expect(result.filter).toBeNil()
	expect(result.blocked).toBeNil()
	expect(result.stat).toBeNil()
	expect(result.damage).toBeNil()
end

local function flag(result, id: string): boolean
	return result.state.unlocked[id] == true
end

local function listed(granted, id: string): boolean
	for _, grantedId in ipairs(granted) do
		if grantedId == id then
			return true
		end
	end
	return false
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

local function requiresTitles(source: string): boolean
	if string.find(source, "Shared.NameplateTitles", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/NameplateTitles", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.NameplateTitles", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("NameplateTitles")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('NameplateTitles')", 1, true) ~= nil then
		return true
	end
	return false
end

describe("NameplateTitles catalog", function()
	it("freezes forty titles and leaves the reserved names out", function()
		local opened = NameplateTitles.fresh()
		expect(opened.ok).toEqual(true)
		expect(opened.error).toBeNil()
		expect(#CONFIG.titles).toEqual(40)
		expect(#ORDER).toEqual(40)
		expect(#CATALOG).toEqual(40)
		expect(identical(CONFIG.titles, NameplateTitles.TITLES)).toEqual(true)
		expect(identical(opened.state, NameplateTitles.fresh().state)).toEqual(false)
		expect(identical(opened.state.unlocked, NameplateTitles.fresh().state.unlocked)).toEqual(
			false
		)
		expect(NameplateTitles.fresh({}).state.unlocked).toEqual(opened.state.unlocked)
		expect(CONFIG.keys).toEqual(0)
		expect(CONFIG.gold).toEqual(0)
		expect(CONFIG.marks).toEqual(0)
		expect(CONFIG.stats).toEqual(0)
		expect(CONFIG.luck).toEqual(0)
		expect(CONFIG.rung).toEqual(1)
		expect(CONFIG.rungs).toEqual(RUNGS)
		expect(CONFIG.also).toEqual({
			full_garden = 5,
			nightglass = 1,
			prism_name = 1,
		})
		expect(NameplateTitles.filter).toBeNil()
		expect(NameplateTitles.equip).toBeNil()
		expect(NameplateTitles.text).toBeNil()

		local rarityTotals = {
			Common = 0,
			Uncommon = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0,
			Mythic = 0,
		}
		local seen = {}
		for index, row in ipairs(CATALOG) do
			local id = row[1]
			local title = CONFIG.titles[index]
			expect(title.id).toEqual(id)
			expect(title.name).toEqual(row[2])
			expect(title.rarity).toEqual(row[3])
			expect(title.count).toEqual(row[4])
			expect(ORDER[index]).toEqual(id)
			expect(CONFIG.counts[id]).toEqual(row[4])
			expect(opened.state.unlocked[id]).toEqual(false)
			expect(seen[id]).toBeNil()
			seen[id] = true
			rarityTotals[row[3]] += 1
		end
		expect(rarityTotals).toEqual({
			Common = 8,
			Uncommon = 8,
			Rare = 8,
			Epic = 6,
			Legendary = 6,
			Mythic = 4,
		})
		local countKeys = 0
		for id in pairs(CONFIG.counts) do
			expect(seen[id]).toEqual(true)
			countKeys += 1
		end
		expect(countKeys).toEqual(40)

		for _, id in ipairs(RESERVED_IDS) do
			expect(CONFIG.counts[id]).toBeNil()
			expect(seen[id]).toBeNil()
			expect(opened.state.unlocked[id]).toBeNil()
		end
		for _, title in ipairs(CONFIG.titles) do
			for _, name in ipairs(RESERVED_NAMES) do
				expect(title.name == name).toEqual(false)
			end
		end
		local fieldKeys = 0
		local fieldSeen = {}
		for _, field in ipairs(FIELDS) do
			expect(fieldSeen[field]).toBeNil()
			fieldSeen[field] = true
			fieldKeys += 1
		end
		expect(fieldKeys).toEqual(38)
		expect(fieldSeen.practice).toBeNil()
	end)
end)

describe("NameplateTitles unlock", function()
	it("unlocks each title at its count and not one below", function()
		for _, row in ipairs(CATALOG) do
			local id = row[1]
			local count = row[4]
			local below = meet(id, count - 1)
			table.freeze(below)
			local missed = NameplateTitles.unlock(fresh(), below)
			expect(missed.ok).toEqual(true)
			expect(flag(missed, id)).toEqual(false)
			expect(listed(missed.granted, id)).toEqual(false)
			expect(missed.error).toBeNil()
			paysNothing(missed)

			local progress = meet(id, count)
			table.freeze(progress)
			local state = fresh()
			table.freeze(state)
			table.freeze(state.unlocked)
			local unlocked = NameplateTitles.unlock(state, progress)
			expect(unlocked.ok).toEqual(true)
			expect(flag(unlocked, id)).toEqual(true)
			expect(listed(unlocked.granted, id)).toEqual(true)
			expect(state.unlocked[id]).toEqual(false)
			expect(identical(unlocked.state, state)).toEqual(false)
			expect(identical(unlocked.state.unlocked, state.unlocked)).toEqual(false)
			expect(identical(unlocked, NameplateTitles.unlock(state, progress))).toEqual(false)
			paysNothing(unlocked)

			local plate = nil
			for _, title in ipairs(unlocked.titles) do
				if title.id == id then
					plate = title
				end
			end
			expect(plate).toEqual({
				id = id,
				name = row[2],
				rarity = row[3],
			})
			plate.name = "rewritten"
			expect(CONFIG.counts[id]).toEqual(count)
			local again = NameplateTitles.nameplate(unlocked.state)
			expect(again.ok).toEqual(true)
			expect(again.granted).toBeNil()
			local painted = nil
			for _, title in ipairs(again.titles) do
				if title.id == id then
					painted = title
				end
			end
			expect(painted.name).toEqual(row[2])
			expect(painted.rarity).toEqual(row[3])
			paysNothing(again)
		end
	end)

	it("keeps a title once it is unlocked, including capped pouch after a week reset", function()
		local state = fresh()
		local filled = zeros()
		filled.raidMarksEarned = 600
		table.freeze(filled)
		local first = NameplateTitles.unlock(state, filled)
		expect(first.ok).toEqual(true)
		expect(first.granted).toEqual({ "capped_pouch" })
		expect(flag(first, "capped_pouch")).toEqual(true)
		expect(flag(first, "soft_step")).toEqual(false)
		paysNothing(first)
		expect(state.unlocked.capped_pouch).toEqual(false)

		table.freeze(first.state)
		table.freeze(first.state.unlocked)
		local reset = zeros()
		reset.raidMarksEarned = 0
		table.freeze(reset)
		local second = NameplateTitles.unlock(first.state, reset)
		expect(second.ok).toEqual(true)
		expect(second.granted).toEqual({})
		expect(flag(second, "capped_pouch")).toEqual(true)
		expect(flag(second, "vault_walker")).toEqual(false)
		expect(first.state.unlocked.capped_pouch).toEqual(true)
		expect(reset.raidMarksEarned).toEqual(0)
		paysNothing(second)
		local shown = NameplateTitles.nameplate(second.state)
		expect(shown.titles).toEqual({
			{
				id = "capped_pouch",
				name = "Capped Pouch",
				rarity = "Legendary",
			},
		})

		local armed = NameplateTitles.unlock(fresh(), meet("pity_ready", 100))
		local cooled = NameplateTitles.unlock(armed.state, zeros())
		expect(cooled.ok).toEqual(true)
		expect(cooled.granted).toEqual({})
		expect(flag(cooled, "pity_ready")).toEqual(true)
		expect(flag(armed, "long_count")).toEqual(false)

		local owned = NameplateTitles.unlock(fresh(), meet("card_stack", 20))
		local sold = meet("card_stack", 19)
		local kept = NameplateTitles.unlock(owned.state, sold)
		expect(kept.granted).toEqual({})
		expect(flag(kept, "card_stack")).toEqual(true)

		local all = NameplateTitles.unlock(fresh(), meetAll())
		expect(#all.granted).toEqual(40)
		expect(all.granted).toEqual(ORDER)
		local quiet = zeros()
		quiet.practice = true
		local still = NameplateTitles.unlock(all.state, quiet)
		expect(still.ok).toEqual(true)
		expect(still.granted).toEqual({})
		expect(still.state.unlocked).toEqual(all.state.unlocked)
		paysNothing(still)
		local dropped = NameplateTitles.unlock(all.state, zeros())
		expect(dropped.granted).toEqual({})
		expect(dropped.state.unlocked).toEqual(all.state.unlocked)
	end)
end)

describe("NameplateTitles compounds", function()
	it("does not treat a shared counter as every title that reads it", function()
		local one = NameplateTitles.unlock(fresh(), meet("one_pull", 1))
		expect(flag(one, "one_pull")).toEqual(true)
		expect(flag(one, "hundred_pulls")).toEqual(false)
		expect(flag(one, "prism_name")).toEqual(false)

		local hundred = NameplateTitles.unlock(fresh(), meet("hundred_pulls", 100))
		expect(flag(hundred, "one_pull")).toEqual(true)
		expect(flag(hundred, "hundred_pulls")).toEqual(true)
		expect(flag(hundred, "prism_name")).toEqual(false)
		expect(hundred.granted).toEqual({ "one_pull", "hundred_pulls" })

		local cracksOnly = zeros()
		cracksOnly.cracks = 1000
		local noItem = NameplateTitles.unlock(fresh(), cracksOnly)
		expect(flag(noItem, "one_pull")).toEqual(true)
		expect(flag(noItem, "hundred_pulls")).toEqual(true)
		expect(flag(noItem, "prism_name")).toEqual(false)

		local both = zeros()
		both.cracks = 1000
		both.mythicItems = 1
		local named = NameplateTitles.unlock(fresh(), both)
		expect(flag(named, "prism_name")).toEqual(true)
		expect(listed(named.granted, "mythic_reel")).toEqual(false)

		local speciesOnly = zeros()
		speciesOnly.species = 8
		local hatched = NameplateTitles.unlock(fresh(), speciesOnly)
		expect(flag(hatched, "all_eight")).toEqual(true)
		expect(flag(hatched, "full_garden")).toEqual(false)
		expect(flag(hatched, "first_hatch")).toEqual(false)

		local manyHatches = zeros()
		manyHatches.hatches = 8
		manyHatches.species = 1
		local oneSpecies = NameplateTitles.unlock(fresh(), manyHatches)
		expect(flag(oneSpecies, "first_hatch")).toEqual(true)
		expect(flag(oneSpecies, "all_eight")).toEqual(false)

		local stars = NameplateTitles.unlock(fresh(), meet("full_stars", 5))
		expect(flag(stars, "full_stars")).toEqual(true)
		expect(flag(stars, "full_bond")).toEqual(false)
		expect(flag(stars, "full_garden")).toEqual(false)
		local bonded = NameplateTitles.unlock(fresh(), meet("full_bond", 5))
		expect(flag(bonded, "full_bond")).toEqual(true)
		expect(flag(bonded, "full_stars")).toEqual(false)

		local gardenShort = zeros()
		gardenShort.species = 8
		gardenShort.affinity = 4
		expect(flag(NameplateTitles.unlock(fresh(), gardenShort), "full_garden")).toEqual(false)
		expect(flag(NameplateTitles.unlock(fresh(), gardenShort), "all_eight")).toEqual(true)
		expect(flag(NameplateTitles.unlock(fresh(), gardenShort), "full_stars")).toEqual(false)

		local nightShort = zeros()
		nightShort.rootvaultNightmare = 1
		local nightmare = NameplateTitles.unlock(fresh(), nightShort)
		expect(flag(nightmare, "night_root")).toEqual(true)
		expect(flag(nightmare, "nightglass")).toEqual(false)
		local wingOnly = zeros()
		wingOnly.normalWings = 1
		local wing = NameplateTitles.unlock(fresh(), wingOnly)
		expect(flag(wing, "normal_leaf")).toEqual(true)
		expect(flag(wing, "nightglass")).toEqual(false)
		local glass = zeros()
		glass.rootvaultNightmare = 1
		glass.normalWings = 1
		local bothClears = NameplateTitles.unlock(fresh(), glass)
		expect(flag(bothClears, "nightglass")).toEqual(true)
		expect(bothClears.granted).toEqual({ "normal_leaf", "night_root", "nightglass" })

		local depths = zeros()
		depths.storyWings = 1
		depths.normalWings = 1
		local split = NameplateTitles.unlock(fresh(), depths)
		expect(flag(split, "story_leaf")).toEqual(true)
		expect(flag(split, "normal_leaf")).toEqual(true)
		expect(flag(split, "two_depths")).toEqual(false)
		local same = zeros()
		same.sameWing = 1
		expect(flag(NameplateTitles.unlock(fresh(), same), "two_depths")).toEqual(true)
		expect(flag(NameplateTitles.unlock(fresh(), same), "story_leaf")).toEqual(false)

		local party = zeros()
		party.party = 5
		expect(flag(NameplateTitles.unlock(fresh(), party), "door_four")).toEqual(true)
		party.party = 3
		expect(flag(NameplateTitles.unlock(fresh(), party), "door_four")).toEqual(false)
	end)

	it("counts a higher roll toward or-better titles and not toward the ladder", function()
		local mythic = zeros()
		mythic.mythic = 1
		local rolled = NameplateTitles.unlock(fresh(), mythic)
		expect(flag(rolled, "rare_chip")).toEqual(true)
		expect(flag(rolled, "epic_seen")).toEqual(true)
		expect(flag(rolled, "mythic_reel")).toEqual(true)
		expect(flag(rolled, "legend_chip")).toEqual(false)
		expect(flag(rolled, "gold_ladder")).toEqual(false)
		expect(rolled.granted).toEqual({ "rare_chip", "epic_seen", "mythic_reel" })

		local mixed = zeros()
		mixed.legendary = 2
		mixed.mythic = 1
		local chip = NameplateTitles.unlock(fresh(), mixed)
		expect(flag(chip, "legend_chip")).toEqual(true)
		expect(flag(chip, "gold_ladder")).toEqual(false)

		local almost = zeros()
		almost.common = 1
		almost.uncommon = 1
		almost.rare = 1
		almost.epic = 1
		almost.mythic = 5
		local ladder = NameplateTitles.unlock(fresh(), almost)
		expect(flag(ladder, "gold_ladder")).toEqual(false)
		expect(flag(ladder, "legend_chip")).toEqual(true)
		almost.legendary = 1
		local climbed = NameplateTitles.unlock(fresh(), almost)
		expect(flag(climbed, "gold_ladder")).toEqual(true)

		local secret = zeros()
		secret.secret = 1
		local refused = NameplateTitles.unlock(fresh(), secret)
		expect(refused.ok).toEqual(false)
		expect(refused.error).toEqual(ERRORS.progress)
		expect(refused.granted).toEqual({})
		expect(flag(refused, "rare_chip")).toEqual(false)
		paysNothing(refused)
	end)
end)

describe("NameplateTitles practice", function()
	it("does not count Practice Grove", function()
		local progress = meetAll()
		progress.practice = true
		progress.paid = true
		table.freeze(progress)
		local state = fresh()
		table.freeze(state)
		table.freeze(state.unlocked)
		local grove = NameplateTitles.unlock(state, progress)
		expect(grove.ok).toEqual(true)
		expect(grove.granted).toEqual({})
		expect(grove.titles).toEqual({})
		expect(grove.state.unlocked).toEqual(state.unlocked)
		paysNothing(grove)
		expect(state.unlocked.soft_step).toEqual(false)
		expect(progress.practice).toEqual(true)

		progress = meetAll()
		local real = NameplateTitles.unlock(fresh(), progress)
		expect(real.ok).toEqual(true)
		expect(#real.granted).toEqual(40)
		expect(real.granted).toEqual(ORDER)
		paysNothing(real)

		local during = meet("soft_step", 10)
		during.practice = true
		local skipped = NameplateTitles.unlock(fresh(), during)
		expect(skipped.granted).toEqual({})
		expect(flag(skipped, "soft_step")).toEqual(false)
		during.practice = false
		expect(flag(NameplateTitles.unlock(fresh(), during), "soft_step")).toEqual(true)
	end)
end)

describe("NameplateTitles paid", function()
	it("does not unlock a title just because the call was paid", function()
		local short = zeros()
		short.paid = true
		table.freeze(short)
		local unpaid = NameplateTitles.unlock(fresh(), short)
		expect(unpaid.ok).toEqual(true)
		expect(unpaid.granted).toEqual({})
		expect(unpaid.titles).toEqual({})
		paysNothing(unpaid)

		local earned = meet("soft_step", 10)
		local paid = NameplateTitles.unlock(
			fresh(),
			(function()
				local copy = meet("soft_step", 10)
				copy.paid = true
				return copy
			end)()
		)
		local free = NameplateTitles.unlock(fresh(), earned)
		local omitted = NameplateTitles.unlock(fresh(), meet("soft_step", 10))
		expect(paid).toEqual(free)
		expect(omitted).toEqual(free)
		expect(flag(paid, "soft_step")).toEqual(true)
		paysNothing(paid)
	end)

	it("refuses a paid skip and grants nothing", function()
		local ready = meet("capped_pouch", 600)
		table.freeze(ready)
		local function refused(extra: { [string]: any })
			local progress = meet("capped_pouch", 600)
			for key, value in pairs(extra) do
				progress[key] = value
			end
			table.freeze(progress)
			local result = NameplateTitles.unlock(fresh(), progress)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.paid)
			expect(result.granted).toEqual({})
			expect(flag(result, "capped_pouch")).toEqual(false)
			expect(result.productId).toBeNil()
			expect(result.robux).toBeNil()
			paysNothing(result)
			expect(ready.raidMarksEarned).toEqual(600)
		end
		refused({ productId = "title_skip" })
		refused({ robux = 25 })
		refused({ robux = 0 })
		refused({ cost = 1 })
		refused({ cost = 0 })
		refused({ skip = true })
		refused({ skip = false })

		local state = fresh()
		state.productId = "title_skip"
		local painted = NameplateTitles.nameplate(state)
		expect(painted.ok).toEqual(false)
		expect(painted.error).toEqual(ERRORS.paid)
		expect(painted.titles).toEqual({})
		expect(painted.productId).toBeNil()
		paysNothing(painted)
	end)
end)

describe("NameplateTitles inputs", function()
	it("refuses a user id or a guild id and does not write the input", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.unlocked)
		local progress = meet("room_one", 1)
		table.freeze(progress)
		expect(NameplateTitles.fresh("no").error).toEqual(ERRORS.state)
		expect(NameplateTitles.fresh({ paid = true }).error).toEqual(ERRORS.state)
		expect(NameplateTitles.fresh({ userId = 7 }).error).toEqual(ERRORS.id)
		expect(NameplateTitles.fresh({ userId = 7 }).state.unlocked.room_one).toEqual(false)
		expect(NameplateTitles.fresh({ userId = 7 }).userId).toBeNil()
		expect(NameplateTitles.fresh({ guildId = "grove" }).error).toEqual(ERRORS.id)
		local both = NameplateTitles.fresh({ userId = 1, productId = "skip" })
		expect(both.error).toEqual(ERRORS.id)
		expect(both.userId).toBeNil()
		expect(both.productId).toBeNil()

		local ranked = meet("room_one", 1)
		ranked.userId = 4
		ranked.productId = "skip"
		table.freeze(ranked)
		local mixed = NameplateTitles.unlock(state, ranked)
		expect(mixed.ok).toEqual(false)
		expect(mixed.error).toEqual(ERRORS.id)
		expect(mixed.granted).toEqual({})
		expect(flag(mixed, "room_one")).toEqual(false)
		expect(mixed.userId).toBeNil()
		expect(mixed.productId).toBeNil()
		expect(ranked.userId).toEqual(4)
		expect(state.unlocked.room_one).toEqual(false)
		paysNothing(mixed)

		local function refuseId(key: string, value: any)
			local body = meet("skill_hand", 50)
			body[key] = value
			local result = NameplateTitles.unlock(state, body)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.id)
			expect(result.granted).toEqual({})
			expect(flag(result, "skill_hand")).toEqual(false)
			expect(result[key]).toBeNil()
			paysNothing(result)
			local saved = fresh()
			saved[key] = value
			local read = NameplateTitles.nameplate(saved)
			expect(read.ok).toEqual(false)
			expect(read.error).toEqual(ERRORS.id)
			expect(read[key]).toBeNil()
			expect(read.titles).toEqual({})
		end
		refuseId("userId", 15)
		refuseId("UserId", 15)
		refuseId("playerId", 15)
		refuseId("PlayerId", 15)
		refuseId("guildId", "haven")
		refuseId("GuildId", "haven")

		local carried = fresh()
		carried.unlocked.guildId = "plaza"
		local hidden = NameplateTitles.unlock(carried, progress)
		expect(hidden.error).toEqual(ERRORS.id)
		expect(hidden.granted).toEqual({})
		expect(hidden.guildId).toBeNil()
		expect(hidden.state.unlocked.guildId).toBeNil()
		expect(carried.unlocked.guildId).toEqual("plaza")
		expect(progress.rooms).toEqual(1)
	end)

	it("refuses a bad record and keeps the previous save", function()
		local state = fresh()
		local earned = NameplateTitles.unlock(state, meet("listed_once", 1))
		table.freeze(earned.state)
		table.freeze(earned.state.unlocked)
		expect(NameplateTitles.unlock(nil, zeros()).error).toEqual(ERRORS.state)
		expect(NameplateTitles.unlock(nil, zeros()).granted).toEqual({})
		expect(NameplateTitles.unlock(earned.state, nil).error).toEqual(ERRORS.progress)
		expect(flag(NameplateTitles.unlock(earned.state, nil), "listed_once")).toEqual(true)
		expect(NameplateTitles.nameplate(nil).error).toEqual(ERRORS.state)

		local function badNumber(field: string, value: any)
			local progress = zeros()
			progress[field] = value
			local result = NameplateTitles.unlock(earned.state, progress)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.progress)
			expect(result.granted).toEqual({})
			expect(flag(result, "listed_once")).toEqual(true)
			expect(earned.state.unlocked.listed_once).toEqual(true)
			paysNothing(result)
		end
		badNumber("rooms", 0 / 0)
		badNumber("rooms", math.huge)
		badNumber("rooms", -math.huge)
		badNumber("rooms", -1)
		badNumber("party", 3.5)
		badNumber("cracks", "100")
		badNumber("practice", "yes")
		badNumber("practice", 1)

		local missing = zeros()
		missing.rooms = nil
		expect(NameplateTitles.unlock(earned.state, missing).error).toEqual(ERRORS.progress)
		local extra = zeros()
		extra.elapsed = 8
		expect(NameplateTitles.unlock(earned.state, extra).error).toEqual(ERRORS.progress)
		expect(NameplateTitles.unlock(earned.state, extra).granted).toEqual({})

		local lied = fresh()
		lied.unlocked.soft_step = "yes"
		expect(NameplateTitles.unlock(lied, zeros()).error).toEqual(ERRORS.state)
		local reserved = fresh()
		reserved.unlocked[RESERVED_IDS[1]] = true
		local smuggled = NameplateTitles.unlock(reserved, meet("soft_step", 10))
		expect(smuggled.ok).toEqual(false)
		expect(smuggled.error).toEqual(ERRORS.state)
		expect(smuggled.granted).toEqual({})
		expect(smuggled.state.unlocked[RESERVED_IDS[1]]).toBeNil()
		expect(reserved.unlocked[RESERVED_IDS[1]]).toEqual(true)

		local huge = zeros()
		huge.rare = 1e308
		huge.epic = 1e308
		local overflow = NameplateTitles.unlock(fresh(), huge)
		expect(overflow.ok).toEqual(false)
		expect(overflow.error).toEqual(ERRORS.progress)
		expect(overflow.granted).toEqual({})
		expect(flag(overflow, "rare_chip")).toEqual(false)
		expect(huge.rare).toEqual(1e308)
		paysNothing(overflow)
	end)

	it("freezes the title tables", function()
		expect(function()
			NameplateTitles.ERRORS.paid = "nope"
		end).toThrow()
		expect(function()
			CONFIG.keys = 10
		end).toThrow()
		expect(function()
			CONFIG.gold = 1
		end).toThrow()
		expect(function()
			CONFIG.marks = 1
		end).toThrow()
		expect(function()
			CONFIG.stats = 1
		end).toThrow()
		expect(function()
			CONFIG.luck = 1
		end).toThrow()
		expect(function()
			CONFIG.rung = 2
		end).toThrow()
		expect(function()
			CONFIG.counts.capped_pouch = 200
		end).toThrow()
		expect(function()
			CONFIG.also.full_garden = 4
		end).toThrow()
		expect(function()
			CONFIG.rungs[1] = "mythic"
		end).toThrow()
		expect(function()
			CONFIG.titles[1] = {}
		end).toThrow()
		expect(function()
			CONFIG.titles[1].count = 9
		end).toThrow()
		expect(function()
			CONFIG.titles[19].sum[1] = "common"
		end).toThrow()
		expect(function()
			ORDER[1] = "room_one"
		end).toThrow()
		expect(function()
			FIELDS[1] = "rooms"
		end).toThrow()
	end)
end)

describe("NameplateTitles isolation", function()
	it("is required by nothing in src and does not roll, wait, or read the clock", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/NameplateTitles.luau")
		local banned = {
			"require(",
			"CombatFeel",
			"Raids",
			"Pets",
			"RarityConfig",
			"Loops",
			"RaidPractice",
			"Rootvault",
			"TextService",
			"math.random",
			"os.time",
			"os.clock",
			"os.date",
			"Random",
			"GetService",
			"DataStore",
			"MemoryStore",
			"Marketplace",
			"task.",
			"DateTime",
			"tick(",
		}
		for _, word in ipairs(banned) do
			expect(string.find(source, word, 1, true)).toBeNil()
		end
		for _, id in ipairs(RESERVED_IDS) do
			expect(string.find(source, id, 1, true)).toBeNil()
		end
		for _, name in ipairs(RESERVED_NAMES) do
			expect(string.find(source, name, 1, true)).toBeNil()
		end
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresTitles(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
