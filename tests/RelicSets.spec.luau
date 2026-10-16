--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local ItemBases = require("../src/ReplicatedStorage/Shared/ItemBases")
local RelicSets = require("../src/ReplicatedStorage/Shared/RelicSets")

local KNOBS = {
	"radius",
	"interval",
	"duration",
	"share",
	"shareOf",
	"cleanses",
	"slow",
	"angle",
	"chill",
	"distance",
	"spread",
}

local POWER = {
	"damage",
	"health",
	"defense",
	"attack",
	"attackSpeed",
	"crit",
	"gold",
	"gems",
	"robux",
	"productId",
}

local EXPECTED = {
	planted_taunt = {
		pieces = 2,
		skillId = "deep_roots",
		radius = 10,
		interval = 6,
	},
	barkskin_share = {
		pieces = 4,
		skillId = "barkskin",
		radius = 12,
		share = 0.08,
		shareOf = "casterMaxHp",
	},
	pool_cleanse = {
		pieces = 2,
		skillId = "healing_pool",
		cleanses = 1,
	},
	ebb_jump = {
		pieces = 4,
		skillId = "ebb_flow",
		radius = 16,
	},
	charge_slow = {
		pieces = 2,
		skillId = "molten_charge",
		slow = 0.2,
		duration = 2,
	},
	guard_cone = {
		pieces = 4,
		skillId = "hammerfall",
		duration = 4,
		angle = 120,
		radius = 8,
	},
	dash_patch = {
		pieces = 2,
		skillId = "glacial_dash",
		duration = 3,
		radius = 4,
		chill = 1,
	},
	shatter_spread = {
		pieces = 4,
		skillId = "shatter",
		chill = 1,
		radius = 8,
	},
	blink_pull = {
		pieces = 2,
		skillId = "blink",
		radius = 8,
		distance = 4,
	},
	unstable_jump = {
		pieces = 4,
		skillId = "hex",
		spread = 1,
		radius = 12,
	},
}

local function classKnown(classId: string, skillId: string): boolean
	local row = Classes.get(classId)
	if row == nil then
		return false
	end
	if row.passive == skillId or row.ultimate.id == skillId then
		return true
	end
	for _, skill in ipairs(row.skills) do
		if skill.id == skillId then
			return true
		end
	end
	return false
end

local function pieceIds(classId: string, count: number): { string }
	local setDef = RelicSets.get(classId)
	expect(setDef ~= nil).toEqual(true)
	if setDef == nil then
		return {}
	end
	local list = {}
	for index = 1, count do
		list[index] = setDef.pieces[index].id
	end
	return list
end

describe("Relic set definitions", function()
	it("defines one 4-piece Verdant set for each class", function()
		expect(RelicSets.PIECE_COUNT).toEqual(4)
		expect(RelicSets.RAID).toEqual("heartwood")
		expect(RelicSets.DIFFICULTY).toEqual("hard")
		expect(RelicSets.SOURCE).toEqual("heartwood_hard")
		expect(RelicSets.SLOTS).toEqual({ "helm", "chest", "legs", "boots" })
		expect(#RelicSets.CLASS_IDS).toEqual(5)
		expect(#Classes.all()).toEqual(5)
		expect(#RelicSets.all()).toEqual(5)

		local seenClass = {}
		for index, row in ipairs(Classes.all()) do
			expect(RelicSets.CLASS_IDS[index]).toEqual(row.id)
			local setDef = RelicSets.get(row.id)
			expect(setDef ~= nil).toEqual(true)
			if setDef == nil then
				return
			end
			expect(RelicSets.all()[index]).toEqual(setDef)
			expect(setDef.classId).toEqual(row.id)
			expect(setDef.id).toEqual("verdant_" .. row.id)
			expect(setDef.source).toEqual(RelicSets.SOURCE)
			expect(#setDef.pieces).toEqual(4)
			expect(#setDef.bonuses).toEqual(2)
			seenClass[row.id] = true

			local seenSlot = {}
			for _, piece in ipairs(setDef.pieces) do
				expect(piece.classId).toEqual(row.id)
				expect(piece.setId).toEqual(setDef.id)
				expect(piece.id).toEqual(setDef.id .. "_" .. piece.slot)
				expect(piece.kind).toEqual("Armor")
				expect(piece.rarity).toEqual("Epic")
				expect(piece.source).toEqual("heartwood_hard")
				expect(RelicSets.piece(piece.id)).toEqual(piece)
				seenSlot[piece.slot] = true
			end
			for _, slot in ipairs(RelicSets.SLOTS) do
				expect(seenSlot[slot]).toEqual(true)
			end
		end
		for _, setDef in ipairs(RelicSets.all()) do
			expect(seenClass[setDef.classId]).toEqual(true)
		end
		expect(RelicSets.get(nil)).toBeNil()
		expect(RelicSets.get("")).toBeNil()
		expect(RelicSets.get("grovewarden")).toBeNil()
		expect(RelicSets.piece(nil)).toBeNil()
		expect(RelicSets.piece("grovewarden_hood")).toBeNil()
	end)

	it("keeps piece, set, and bonus ids unique and off the item catalog", function()
		local ids = {}
		local bonusIds = {}
		local setIds = {}
		for _, setDef in ipairs(RelicSets.all()) do
			expect(setIds[setDef.id]).toBeNil()
			setIds[setDef.id] = true
			expect(ItemBases.get(setDef.id)).toBeNil()
			expect(ids[setDef.id]).toBeNil()
			for _, piece in ipairs(setDef.pieces) do
				expect(ids[piece.id]).toBeNil()
				ids[piece.id] = true
				expect(ItemBases.get(piece.id)).toBeNil()
				expect(piece.robux).toBeNil()
				expect(piece.productId).toBeNil()
			end
			for _, bonus in ipairs(setDef.bonuses) do
				expect(bonusIds[bonus.id]).toBeNil()
				bonusIds[bonus.id] = true
				expect(classKnown(setDef.classId, bonus.skillId)).toEqual(true)
				for _, key in ipairs(POWER) do
					expect(bonus[key]).toBeNil()
				end
			end
		end
		local pieceCount = 0
		for _ in pairs(ids) do
			pieceCount += 1
		end
		expect(pieceCount).toEqual(20)
		local bonusCount = 0
		for _ in pairs(bonusIds) do
			bonusCount += 1
		end
		expect(bonusCount).toEqual(10)
	end)
end)

describe("Equipped piece count", function()
	it("counts 0, 1, 2, 3, and 4 pieces", function()
		local ids = pieceIds("warden", 4)
		expect(RelicSets.count("warden", {})).toEqual(0)
		expect(RelicSets.count("warden", { ids[1] })).toEqual(1)
		expect(RelicSets.count("warden", { ids[1], ids[2] })).toEqual(2)
		expect(RelicSets.count("warden", { ids[1], ids[2], ids[3] })).toEqual(3)
		expect(RelicSets.count("warden", ids)).toEqual(4)

		local items = {}
		for index, id in ipairs(ids) do
			items[index] = { templateId = id }
		end
		expect(RelicSets.count("warden", items)).toEqual(4)
		expect(RelicSets.count("warden", {
			helm = ids[1],
			chest = ids[2],
			legs = ids[3],
			boots = ids[4],
		})).toEqual(4)
		expect(RelicSets.count("warden", {
			armor = {
				helm = ids[1],
				chest = { templateId = ids[2] },
				legs = ids[3],
				boots = ids[4],
			},
			weapon = "uid-weapon",
		})).toEqual(4)
	end)

	it("ignores wrong-class pieces, duplicates, a mismatched slot, nil, and empty input", function()
		local warden = pieceIds("warden", 4)
		local frost = pieceIds("frostblade", 4)
		expect(RelicSets.count("warden", frost)).toEqual(0)
		expect(RelicSets.count("frostblade", frost)).toEqual(4)
		expect(RelicSets.count("warden", { warden[1], frost[1], frost[2], frost[3] })).toEqual(1)
		expect(RelicSets.count("warden", { warden[1], warden[1], warden[1], warden[1] })).toEqual(1)
		expect(RelicSets.count("warden", { warden[1], helm = warden[1] })).toEqual(1)
		expect(RelicSets.count("warden", { helm = warden[4] })).toEqual(0)
		expect(RelicSets.count("warden", { helm = warden[1], chest = warden[4] })).toEqual(1)
		expect(RelicSets.count("warden", { { templateId = warden[1], id = warden[2] } })).toEqual(1)
		expect(RelicSets.count("warden", { armor = { helm = "uid-123", ring = warden[1] } })).toEqual(
			0
		)

		local bag = {
			uid_a = { templateId = warden[1] },
			uid_b = { templateId = warden[2] },
		}
		expect(RelicSets.count("warden", bag)).toEqual(0)

		expect(RelicSets.count(nil, warden)).toEqual(0)
		expect(RelicSets.count("warden", nil)).toEqual(0)
		expect(RelicSets.count("", warden)).toEqual(0)
		expect(RelicSets.count("nope", warden)).toEqual(0)
		expect(RelicSets.count("warden", {})).toEqual(0)
		expect(RelicSets.count("warden", 4)).toEqual(0)
	end)
end)

describe("Active bonuses", function()
	it("turns the 2-piece on at 2 and adds the 4-piece at 4", function()
		for _, setDef in ipairs(RelicSets.all()) do
			local ids = pieceIds(setDef.classId, 4)
			expect(#RelicSets.active(setDef.classId, {})).toEqual(0)
			expect(#RelicSets.active(setDef.classId, { ids[1] })).toEqual(0)
			local two = RelicSets.active(setDef.classId, { ids[1], ids[2] })
			expect(#two).toEqual(1)
			expect(two[1]).toEqual(setDef.bonuses[1])
			expect(two[1].pieces).toEqual(2)
			expect(two[1] == setDef.bonuses[1]).toEqual(true)
			local three = RelicSets.active(setDef.classId, { ids[1], ids[2], ids[3] })
			expect(#three).toEqual(1)
			expect(three[1].id).toEqual(setDef.bonuses[1].id)
			local four = RelicSets.active(setDef.classId, ids)
			expect(#four).toEqual(2)
			expect(four[1].pieces).toEqual(2)
			expect(four[2].pieces).toEqual(4)
			expect(four[1] == setDef.bonuses[1]).toEqual(true)
			expect(four[2] == setDef.bonuses[2]).toEqual(true)
		end

		local warden = pieceIds("warden", 4)
		local frost = pieceIds("frostblade", 4)
		expect(#RelicSets.active("warden", frost)).toEqual(0)
		expect(#RelicSets.active("warden", { warden[1], warden[1] })).toEqual(0)
		expect(#RelicSets.active(nil, warden)).toEqual(0)
		expect(#RelicSets.active("warden", nil)).toEqual(0)
		expect(#RelicSets.active("warden", {})).toEqual(0)

		local frostSet = RelicSets.get("frostblade")
		expect(frostSet ~= nil).toEqual(true)
		if frostSet == nil then
			return
		end
		local spread = RelicSets.active("frostblade", frost)[2]
		expect(spread.id).toEqual("shatter_spread")
		expect(spread.skillId).toEqual("shatter")
		expect(spread.chill).toEqual(1)
		expect(spread.radius).toEqual(8)
	end)

	it("uses the documented bonus numbers and no flat power", function()
		local seen = 0
		for _, setDef in ipairs(RelicSets.all()) do
			for _, bonus in ipairs(setDef.bonuses) do
				local row = EXPECTED[bonus.id]
				expect(row ~= nil).toEqual(true)
				if row == nil then
					return
				end
				seen += 1
				expect(bonus.pieces).toEqual(row.pieces)
				expect(bonus.skillId).toEqual(row.skillId)
				expect(bonus.name ~= "").toEqual(true)
				expect(bonus.note ~= "").toEqual(true)
				for _, key in ipairs(KNOBS) do
					expect(bonus[key]).toEqual(row[key])
				end
				for _, key in ipairs(POWER) do
					expect(bonus[key]).toBeNil()
				end
			end
		end
		expect(seen).toEqual(10)
	end)
end)

describe("Tradeable pieces", function()
	it("recognizes a piece or set id and does not treat bound as the test", function()
		for _, setDef in ipairs(RelicSets.all()) do
			for _, piece in ipairs(setDef.pieces) do
				expect(piece.bound).toEqual(true)
				expect(piece.tradeable).toEqual(false)
				expect(RelicSets.isRelic(piece.id)).toEqual(true)
				expect(RelicSets.isRelic(piece)).toEqual(true)
				expect(RelicSets.isRelic({ templateId = piece.id, bound = true })).toEqual(true)
				expect(RelicSets.isRelic({ id = piece.id })).toEqual(true)
				expect(RelicSets.isRelic({ pieceId = piece.id })).toEqual(true)
				expect(RelicSets.isRelic({ setId = piece.id })).toEqual(true)
			end
			expect(RelicSets.isRelic(setDef.id)).toEqual(true)
			expect(RelicSets.isRelic({ setId = setDef.id })).toEqual(true)
			expect(RelicSets.isRelic({ id = setDef.id })).toEqual(true)
			expect(RelicSets.isRelic({ templateId = setDef.id })).toEqual(true)
			expect(RelicSets.isRelic({ pieceId = setDef.id })).toEqual(true)
		end
		expect(RelicSets.isRelic("iron_sword")).toEqual(false)
		expect(RelicSets.isRelic("grovewarden_hood")).toEqual(false)
		expect(RelicSets.isRelic("warden")).toEqual(false)
		expect(RelicSets.isRelic(nil)).toEqual(false)
		expect(RelicSets.isRelic({ bound = true })).toEqual(false)
		expect(RelicSets.isRelic({ tradeable = false })).toEqual(false)
		expect(RelicSets.isRelic({
			templateId = "starter_sword",
			id = "starter_sword",
			bound = true,
			starter = true,
		})).toEqual(false)
		expect(RelicSets.isRelic({ templateId = "verdant_voidcaster_boots" })).toEqual(true)
		expect(RelicSets.isRelic({ setId = "verdant_tidecaller" })).toEqual(true)
		expect(RelicSets.isRelic({
			templateId = "iron_sword",
			pieceId = "verdant_warden_helm",
		})).toEqual(true)
	end)

	it("stamps a tradeable unbound copy and leaves the input alone", function()
		local drop = { templateId = "verdant_frostblade_helm", name = "Rimewake Hood" }
		local stamped = RelicSets.stamp(drop)
		expect(stamped == drop).toEqual(false)
		expect(drop.bound).toBeNil()
		expect(drop.tradeable).toBeNil()
		expect(stamped.bound).toEqual(false)
		expect(stamped.tradeable).toEqual(true)
		expect(stamped.templateId).toEqual("verdant_frostblade_helm")
		expect(stamped.name).toEqual("Rimewake Hood")
		expect(stamped.setId).toEqual("verdant_frostblade")
		expect(stamped.slot).toEqual("helm")
		expect(stamped.classId).toEqual("frostblade")
		expect(stamped.kind).toEqual("Armor")
		expect(stamped.rarity).toEqual("Epic")
		expect(stamped.source).toEqual("heartwood_hard")

		local catalog = RelicSets.piece("verdant_warden_chest")
		expect(catalog ~= nil).toEqual(true)
		if catalog == nil then
			return
		end
		local copy = RelicSets.stamp(catalog)
		expect(copy == catalog).toEqual(false)
		expect(copy.bound).toEqual(false)
		expect(copy.tradeable).toEqual(true)
		expect(catalog.bound).toEqual(true)
		expect(catalog.tradeable).toEqual(false)
		expect(function()
			catalog.bound = false
		end).toThrow()

		local other = { templateId = "iron_sword", name = "Iron Sword" }
		expect(RelicSets.stamp(other) == other).toEqual(true)
		expect(RelicSets.stamp(nil)).toBeNil()
		expect(RelicSets.stamp("verdant_warden_helm")).toEqual("verdant_warden_helm")

		local starter = {
			templateId = "starter_sword",
			bound = true,
			tradeable = false,
			starter = true,
		}
		expect(RelicSets.stamp(starter) == starter).toEqual(true)
		expect(starter.bound).toEqual(true)
		expect(starter.tradeable).toEqual(false)

		local setOnly = { setId = "verdant_forgeborn", name = "Kilnheart" }
		local marked = RelicSets.stamp(setOnly)
		expect(marked == setOnly).toEqual(false)
		expect(setOnly.bound).toBeNil()
		expect(marked.bound).toEqual(false)
		expect(marked.tradeable).toEqual(true)
		expect(marked.slot).toBeNil()
		expect(marked.name).toEqual("Kilnheart")
	end)
end)

describe("setPct", function()
	it("returns 0 for nil, empty, and junk", function()
		expect(RelicSets.setPct(nil)).toEqual(0)
		expect(RelicSets.setPct({})).toEqual(0)
		expect(RelicSets.setPct(0)).toEqual(0)
		expect(RelicSets.setPct("")).toEqual(0)
		expect(RelicSets.setPct("verdant_warden_helm")).toEqual(0)
		expect(RelicSets.setPct(false)).toEqual(0)
		expect(RelicSets.setPct(true)).toEqual(0)
		expect(RelicSets.setPct({ "iron_sword", "grovewarden_hood" })).toEqual(0)
		expect(RelicSets.setPct({ note = "verdant_warden_helm" })).toEqual(0)
		expect(RelicSets.setPct(0 / 0)).toEqual(0)
		expect(RelicSets.setPct(math.huge)).toEqual(0)
		expect(RelicSets.setPct(-math.huge)).toEqual(0)
	end)

	it("returns 25, 50, 75, and 100 for a partial and a full set", function()
		local ids = pieceIds("forgeborn", 4)
		expect(RelicSets.setPct(1)).toEqual(25)
		expect(RelicSets.setPct(2)).toEqual(50)
		expect(RelicSets.setPct(3)).toEqual(75)
		expect(RelicSets.setPct(4)).toEqual(100)
		expect(RelicSets.setPct(1.9)).toEqual(25)
		expect(RelicSets.setPct(0.2)).toEqual(0)
		expect(RelicSets.setPct({ ids[1] })).toEqual(25)
		expect(RelicSets.setPct({ ids[1], ids[2] })).toEqual(50)
		expect(RelicSets.setPct({ ids[1], ids[2], ids[3] })).toEqual(75)
		expect(RelicSets.setPct(ids)).toEqual(100)
		expect(RelicSets.setPct({ ids[1], ids[1], ids[1], ids[1] })).toEqual(25)

		local bag = {
			uid_a = { templateId = ids[1] },
			uid_b = { templateId = ids[1] },
			uid_c = { templateId = "iron_sword" },
		}
		expect(RelicSets.setPct(bag)).toEqual(25)
		bag.uid_d = { templateId = ids[2] }
		expect(RelicSets.setPct(bag)).toEqual(50)

		local warden = pieceIds("warden", 3)
		local oneFrost = pieceIds("frostblade", 1)
		local mixed = { warden[1], warden[2], warden[3], oneFrost[1] }
		expect(RelicSets.setPct(mixed)).toEqual(75)

		local all = {}
		for _, setDef in ipairs(RelicSets.all()) do
			for _, piece in ipairs(setDef.pieces) do
				table.insert(all, piece.id)
			end
		end
		expect(#all).toEqual(20)
		expect(RelicSets.setPct(all)).toEqual(100)
	end)

	it("clamps to 0-100", function()
		expect(RelicSets.setPct(-1)).toEqual(0)
		expect(RelicSets.setPct(-0.2)).toEqual(0)
		expect(RelicSets.setPct(5)).toEqual(100)
		expect(RelicSets.setPct(8)).toEqual(100)
		expect(RelicSets.setPct(100)).toEqual(100)
		expect(RelicSets.setPct(4.9)).toEqual(100)
		local ids = pieceIds("voidcaster", 4)
		local piled = {}
		for _ = 1, 8 do
			for _, id in ipairs(ids) do
				table.insert(piled, id)
			end
		end
		expect(RelicSets.setPct(piled)).toEqual(100)
	end)
end)
