--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidLuck = require("../src/ReplicatedStorage/Shared/RaidLuck")

local ERRORS = RaidLuck.ERRORS

local function identical(left: any, right: any): boolean
	return left == right
end

local function gearClear(difficulty: string)
	return {
		difficulty = difficulty,
		drops = { { kind = "gear" } },
	}
end

describe("RaidLuck config", function()
	it("pins the step and the bonus cap", function()
		expect(RaidLuck.CONFIG.stepPct).toEqual(0.1)
		expect(RaidLuck.CONFIG.maxBonus).toEqual(0.6)
	end)

	it("names the four loot difficulties", function()
		expect(RaidLuck.DIFFICULTIES).toEqual({
			story = true,
			normal = true,
			hard = true,
			shardbreaker = true,
		})
	end)

	it("treats pets, mounts, titles, dyes, cosmetics, and auras as excluded", function()
		expect(RaidLuck.EXCLUDED).toEqual({
			pet = true,
			mount = true,
			title = true,
			dye = true,
			cosmetic = true,
			aura = true,
		})
	end)

	it("freezes the thresholds, the kind lists, and the errors", function()
		expect(function()
			RaidLuck.CONFIG.stepPct = 1
		end).toThrow()
		expect(function()
			RaidLuck.CONFIG.maxBonus = 1
		end).toThrow()
		expect(function()
			RaidLuck.EXCLUDED.pet = false
		end).toThrow()
		expect(function()
			RaidLuck.GEAR.gear = false
		end).toThrow()
		expect(function()
			RaidLuck.ERRORS.state = "open"
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
		for key in pairs(RaidLuck.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
	end)
end)

describe("RaidLuck classify", function()
	it("counts raid gear, Heartshard weapons, and Relic Set pieces", function()
		local drops = {
			"gear",
			" raid ",
			"raid_gear",
			"heartshard",
			"Heartshard Edge",
			"relic",
			"verdant_warden_helm",
			"verdant_warden",
			{ kind = "gear" },
			{ kind = "weapon", heartshard = true },
			{ kind = "weapon", family = "Heartshard" },
			{ kind = "weapon", weaponFamily = "heartshard" },
			{ kind = "weapon", source = "raid" },
			{ kind = "armor", source = "heartwood_hard" },
			{ kind = "accessory", raid = true },
			{ id = "verdant_warden_helm" },
			{ kind = "Armor", id = "verdant_warden_helm" },
			{ setId = "verdant_warden" },
			{ templateId = "heartshard_edge" },
		}
		for _, drop in ipairs(drops) do
			local row = RaidLuck.classify(drop)
			expect(row.ok).toEqual(true)
			expect(row.gear).toEqual(true)
		end
	end)

	it("leaves pets, mounts, titles, dyes, cosmetics, auras, and side drops alone", function()
		local drops = {
			"pet",
			"mount",
			"title",
			"dye",
			"cosmetic",
			"aura",
			"dust",
			"marks",
			"material",
			"shards",
			"token",
			"emblem",
			{ kind = "Pet" },
			{ kind = "mount" },
			{ kind = "title" },
			{ kind = "dye", id = "heartshard_red" },
			{ kind = "cosmetic" },
			{ kind = "aura" },
			{ raidCosmetic = true },
			{ kind = "cosmetic", raidCosmetic = true },
			{ category = "dust" },
		}
		for _, drop in ipairs(drops) do
			local row = RaidLuck.classify(drop)
			expect(row.ok).toEqual(true)
			expect(row.gear).toEqual(false)
		end
	end)

	it("refuses a drop that is not gear and not a known side reward", function()
		local drops = {
			"weapon",
			"chest",
			"heartwood",
			"fracture",
			"",
			"  ",
			1,
			{ kind = "weapon" },
			{ kind = "weapon", source = "rootvault" },
			{ kind = "armor" },
			{ kind = "pet", heartshard = true },
			{ kind = "cosmetic", family = "heartshard" },
			{ kind = "gear", category = "pet" },
			{ kind = "cosmetic", id = "verdant_warden_helm" },
		}
		for _, drop in ipairs(drops) do
			local row = RaidLuck.classify(drop)
			expect(row.ok).toEqual(false)
			expect(row.gear).toEqual(false)
			expect(row.error).toEqual(ERRORS.drop)
		end
		expect(RaidLuck.classify(nil).ok).toEqual(false)
	end)
end)

describe("RaidLuck chance", function()
	it("adds the difficulty bonus and clamps the result to 0..1", function()
		local state = { bonus = { story = 0.1, normal = 0.6 } }
		expect(RaidLuck.chance(0.2, nil, "story")).toEqual({
			ok = true,
			chance = 0.2,
			base = 0.2,
			bonus = 0,
			difficulty = "story",
		})
		expect(RaidLuck.chance(0.2, state, " Story ")).toEqual({
			ok = true,
			chance = 0.3,
			base = 0.2,
			bonus = 0.1,
			difficulty = "story",
		})
		expect(RaidLuck.chance(0.2, state, "normal").chance).toEqual(0.8)
		expect(RaidLuck.chance(0.95, state, "normal").chance).toEqual(1)
		expect(RaidLuck.chance(1.4, nil, "hard").chance).toEqual(1)
		expect(RaidLuck.chance(-1, nil, "hard").chance).toEqual(0)
		expect(RaidLuck.chance(-0.1, state, "normal").chance).toEqual(0.5)
		expect(RaidLuck.chance(0, state, "story").chance).toEqual(0.1)
	end)

	it("reads a stored bonus above the cap as the cap", function()
		local view = RaidLuck.chance(0.2, { bonus = { story = 0.9 } }, "story")
		expect(view.ok).toEqual(true)
		expect(view.bonus).toEqual(0.6)
		expect(view.chance).toEqual(0.8)
	end)

	it("uses only the asked difficulty", function()
		local view = RaidLuck.chance(0.2, { bonus = { story = 0.4 } }, "normal")
		expect(view.ok).toEqual(true)
		expect(view.bonus).toEqual(0)
		expect(view.chance).toEqual(0.2)
	end)

	it("rejects a base, a difficulty, or a record it cannot use", function()
		expect(RaidLuck.chance("0.2", nil, "story").error).toEqual(ERRORS.base)
		expect(RaidLuck.chance(0 / 0, nil, "story").error).toEqual(ERRORS.base)
		expect(RaidLuck.chance(math.huge, nil, "story").error).toEqual(ERRORS.base)
		expect(RaidLuck.chance(nil, nil, "story").error).toEqual(ERRORS.base)
		expect(RaidLuck.chance(0.2, nil, "fracture").error).toEqual(ERRORS.difficulty)
		expect(RaidLuck.chance(0.2, nil, "guided").error).toEqual(ERRORS.difficulty)
		expect(RaidLuck.chance(0.2, nil, "").error).toEqual(ERRORS.difficulty)
		expect(RaidLuck.chance(0.2, nil, nil).error).toEqual(ERRORS.difficulty)
		expect(RaidLuck.chance(0.2, 1, "story").error).toEqual(ERRORS.state)
		expect(RaidLuck.chance(0.2, { bonus = 1 }, "story").error).toEqual(ERRORS.state)
		expect(RaidLuck.chance(0.2, { bonus = { story = -0.1 } }, "story").error).toEqual(
			ERRORS.state
		)
		expect(RaidLuck.chance(0.2, { bonus = { fracture = 0.1 } }, "story").error).toEqual(
			ERRORS.state
		)
		local mixed = { story = 0.1 }
		mixed.Story = 0.2
		expect(RaidLuck.chance(0.2, { bonus = mixed }, "story").error).toEqual(ERRORS.state)
	end)

	it("does not write the record", function()
		local bonus = table.freeze({ story = 0.1 })
		local state = table.freeze({ bonus = bonus })
		local view = RaidLuck.chance(0.2, state, "story")
		expect(view.chance).toEqual(0.3)
		expect(bonus.story).toEqual(0.1)
	end)
end)

describe("RaidLuck settle", function()
	it("adds one step on a loot-eligible clear with no gear", function()
		local settled = RaidLuck.settle(nil, { difficulty = "story" })
		expect(settled).toEqual({
			ok = true,
			state = { bonus = { story = 0.1 } },
			difficulty = "story",
			bonus = 0.1,
			previous = 0,
			added = true,
			reset = false,
			gear = false,
			eligible = true,
			capped = false,
		})
		local again = RaidLuck.settle(settled.state, {
			difficulty = " Story ",
			drops = {},
		})
		expect(again.bonus).toEqual(0.2)
		expect(again.added).toEqual(true)
		expect(settled.state.bonus.story).toEqual(0.1)
	end)

	it("reaches the cap on the sixth dry clear and stays there", function()
		local steps = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6 }
		local state = nil
		for index, bonus in ipairs(steps) do
			local settled = RaidLuck.settle(state, { difficulty = "hard" })
			expect(settled.ok).toEqual(true)
			expect(settled.bonus).toEqual(bonus)
			expect(settled.added).toEqual(true)
			expect(settled.capped).toEqual(index == 6)
			state = settled.state
		end
		local held = RaidLuck.settle(state, { difficulty = "hard" })
		expect(held.bonus).toEqual(0.6)
		expect(held.added).toEqual(false)
		expect(held.capped).toEqual(true)
		expect(held.reset).toEqual(false)
	end)

	it("fills only up to the cap when the stored bonus is already close", function()
		local settled = RaidLuck.settle({ bonus = { shardbreaker = 0.55 } }, {
			difficulty = "shardbreaker",
		})
		expect(settled.ok).toEqual(true)
		expect(settled.bonus).toEqual(0.6)
		expect(settled.previous).toEqual(0.55)
		expect(settled.added).toEqual(true)
		expect(settled.capped).toEqual(true)
	end)

	it("adds for a pet, a mount, a title, a dye, a cosmetic, or dust", function()
		local drops = {
			{ "pet" },
			{ "mount" },
			{ "title" },
			{ "dye" },
			{ "cosmetic" },
			{ "aura" },
			{ { kind = "dye", id = "heartshard_red" } },
			{ "dust", "pet", { kind = "mount" } },
			{ { raidCosmetic = true } },
		}
		for _, list in ipairs(drops) do
			local settled = RaidLuck.settle({ bonus = { normal = 0.2 } }, {
				difficulty = "normal",
				drops = list,
			})
			expect(settled.ok).toEqual(true)
			expect(settled.bonus).toEqual(0.3)
			expect(settled.added).toEqual(true)
			expect(settled.reset).toEqual(false)
			expect(settled.gear).toEqual(false)
		end
	end)

	it("resets that difficulty when gear, a Heartshard, or a relic drops", function()
		local lists = {
			{ "gear" },
			{ { kind = "weapon", heartshard = true } },
			{ { id = "verdant_warden_helm" } },
			{ { kind = "armor", source = "heartwood" } },
			{ "dust", "pet", { kind = "gear" } },
		}
		for _, list in ipairs(lists) do
			local settled = RaidLuck.settle({ bonus = { story = 0.6, normal = 0.4 } }, {
				difficulty = "story",
				drops = list,
			})
			expect(settled.ok).toEqual(true)
			expect(settled.bonus).toEqual(0)
			expect(settled.previous).toEqual(0.6)
			expect(settled.reset).toEqual(true)
			expect(settled.gear).toEqual(true)
			expect(settled.added).toEqual(false)
			expect(settled.capped).toEqual(false)
			expect(settled.state.bonus.normal).toEqual(0.4)
			expect(settled.state.bonus.story).toEqual(0)
		end
	end)

	it("resets a bonus that is already 0", function()
		local settled = RaidLuck.settle(nil, gearClear("normal"))
		expect(settled.ok).toEqual(true)
		expect(settled.bonus).toEqual(0)
		expect(settled.reset).toEqual(true)
		expect(settled.state.bonus.normal).toEqual(0)
	end)

	it("starts again after a reset", function()
		local reset = RaidLuck.settle({ bonus = { hard = 0.6 } }, gearClear("hard"))
		local nextClear = RaidLuck.settle(reset.state, { difficulty = "hard" })
		expect(nextClear.bonus).toEqual(0.1)
		expect(RaidLuck.chance(0.2, nextClear.state, "hard").chance).toEqual(0.3)
	end)

	it("keeps the other difficulties", function()
		local settled = RaidLuck.settle({ bonus = { normal = 0.2 } }, { difficulty = "story" })
		expect(settled.state.bonus.story).toEqual(0.1)
		expect(settled.state.bonus.normal).toEqual(0.2)
		expect(RaidLuck.chance(0.2, settled.state, "normal").chance).toEqual(0.4)
		expect(RaidLuck.chance(0.2, settled.state, "story").chance).toEqual(0.3)
	end)

	it("does not add or reset on a lockout reclear", function()
		local state = { bonus = { story = 0.3, normal = 0.1 } }
		local reclear = RaidLuck.settle(state, {
			difficulty = "story",
			locked = true,
			drops = { { kind = "gear" } },
		})
		expect(reclear.ok).toEqual(true)
		expect(reclear.bonus).toEqual(0.3)
		expect(reclear.added).toEqual(false)
		expect(reclear.reset).toEqual(false)
		expect(reclear.gear).toEqual(false)
		expect(reclear.eligible).toEqual(false)
		expect(reclear.reason).toEqual("lockout")
		expect(state.bonus.story).toEqual(0.3)
	end)

	it("does not add or reset on an AFK removal", function()
		local state = { bonus = { normal = 0.4 } }
		local removed = RaidLuck.settle(state, {
			difficulty = "normal",
			removal = " AFK ",
			drops = { "gear" },
		})
		expect(removed.ok).toEqual(true)
		expect(removed.bonus).toEqual(0.4)
		expect(removed.added).toEqual(false)
		expect(removed.reset).toEqual(false)
		expect(removed.eligible).toEqual(false)
		expect(removed.reason).toEqual("afk")
		expect(state.bonus.normal).toEqual(0.4)
	end)

	it("lets a passed vote-kick settle", function()
		local dry = RaidLuck.settle({ bonus = { story = 0.1 } }, {
			difficulty = "story",
			removal = "kick",
		})
		expect(dry.ok).toEqual(true)
		expect(dry.bonus).toEqual(0.2)
		expect(dry.added).toEqual(true)
		expect(dry.reason).toBeNil()
		local dropped = RaidLuck.settle({ bonus = { story = 0.2 } }, {
			difficulty = "story",
			removal = "kick",
			drops = { "relic" },
		})
		expect(dropped.bonus).toEqual(0)
		expect(dropped.reset).toEqual(true)
	end)

	it("does not add or reset when the clear is not loot-eligible", function()
		local state = { bonus = { hard = 0.5 } }
		local skipped = RaidLuck.settle(state, {
			difficulty = "hard",
			eligible = false,
			drops = { { id = "verdant_warden_helm" } },
		})
		expect(skipped.ok).toEqual(true)
		expect(skipped.bonus).toEqual(0.5)
		expect(skipped.added).toEqual(false)
		expect(skipped.reset).toEqual(false)
		expect(skipped.reason).toEqual("ineligible")
		expect(state.bonus.hard).toEqual(0.5)
	end)

	it("reports AFK ahead of a lockout, and a lockout ahead of an ineligible flag", function()
		local afk = RaidLuck.settle(nil, {
			difficulty = "story",
			removal = "afk",
			locked = true,
			eligible = false,
		})
		expect(afk.reason).toEqual("afk")
		local locked = RaidLuck.settle(nil, {
			difficulty = "story",
			locked = true,
			eligible = false,
		})
		expect(locked.reason).toEqual("lockout")
	end)

	it("pulls a stored bonus down to the cap on a skip", function()
		local settled = RaidLuck.settle({ bonus = { story = 0.9, normal = 0.2 } }, {
			difficulty = "story",
			locked = true,
		})
		expect(settled.ok).toEqual(true)
		expect(settled.bonus).toEqual(0.6)
		expect(settled.previous).toEqual(0.6)
		expect(settled.state.bonus.story).toEqual(0.6)
		expect(settled.state.bonus.normal).toEqual(0.2)
	end)

	it("returns the same result for the same clear", function()
		local outcome = { difficulty = "normal", drops = { "mount" } }
		expect(RaidLuck.settle(nil, outcome)).toEqual(RaidLuck.settle(nil, outcome))
	end)

	it("does not write the record or the drop list", function()
		local bonus = table.freeze({ story = 0.1, normal = 0.2 })
		local state = table.freeze({ bonus = bonus })
		local drops = table.freeze({ "pet" })
		local outcome = table.freeze({
			difficulty = "story",
			drops = drops,
		})
		local settled = RaidLuck.settle(state, outcome)
		expect(settled.ok).toEqual(true)
		expect(settled.state.bonus.story).toEqual(0.2)
		expect(settled.state.bonus.normal).toEqual(0.2)
		expect(bonus.story).toEqual(0.1)
		expect(identical(settled.state, state)).toEqual(false)
		expect(identical(settled.state.bonus, bonus)).toEqual(false)
	end)

	it("refuses a bad clear and leaves the caller's record as it was", function()
		local state = { bonus = { story = 0.2 } }
		local cases = {
			{ nil, ERRORS.outcome },
			{ {}, ERRORS.difficulty },
			{ { difficulty = "fracture" }, ERRORS.difficulty },
			{ { difficulty = "guided" }, ERRORS.difficulty },
			{ { difficulty = "story", locked = "yes" }, ERRORS.lock },
			{ { difficulty = "story", removal = "idle" }, ERRORS.removal },
			{ { difficulty = "story", removal = "leave" }, ERRORS.removal },
			{ { difficulty = "story", eligible = "yes" }, ERRORS.eligible },
			{ { difficulty = "story", drops = "pet" }, ERRORS.drop },
			{ { difficulty = "story", drops = { [1] = "pet", [3] = "pet" } }, ERRORS.drop },
			{ { difficulty = "story", drops = { pet = true } }, ERRORS.drop },
			{ { difficulty = "story", drops = { "chest" } }, ERRORS.drop },
			{ { difficulty = "story", drops = { { kind = "weapon" } } }, ERRORS.drop },
			{
				{ difficulty = "story", removal = "afk", drops = { "chest" } },
				ERRORS.drop,
			},
		}
		for _, case in ipairs(cases) do
			local settled = RaidLuck.settle(state, case[1])
			expect(settled.ok).toEqual(false)
			expect(settled.error).toEqual(case[2])
			expect(settled.added).toEqual(false)
			expect(settled.reset).toEqual(false)
			expect(state.bonus.story).toEqual(0.2)
		end
		local broken = RaidLuck.settle(4, { difficulty = "story" })
		expect(broken.ok).toEqual(false)
		expect(broken.error).toEqual(ERRORS.state)
		expect(broken.state).toEqual({ bonus = {} })
	end)
end)
