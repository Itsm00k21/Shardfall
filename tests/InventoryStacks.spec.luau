--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local InventoryStacks = require("../src/ReplicatedStorage/Shared/InventoryStacks")

local function item(
	uid: string,
	templateId: string,
	name: string,
	kind: string,
	rarity: string,
	traits: { any }?
)
	return {
		uid = uid,
		templateId = templateId,
		name = name,
		kind = kind,
		rarity = rarity,
		traits = traits or {},
	}
end

local function trait(id: string, name: string, display: string)
	return { id = id, name = name, display = display, value = 0.05, unit = "percent" }
end

describe("InventoryStacks", function()
	it("stacks identical items and keeps every uid", function()
		local stacks = InventoryStacks.group({
			{
				item = item("a", "training_pup", "Training Pup", "Pet", "Uncommon"),
				equipped = false,
			},
			{
				item = item("b", "training_pup", "Training Pup", "Pet", "Uncommon"),
				equipped = false,
			},
			{
				item = item("c", "training_pup", "Training Pup", "Pet", "Uncommon"),
				equipped = false,
			},
		})
		expect(#stacks).toEqual(1)
		expect(stacks[1].name).toEqual("Training Pup")
		expect(stacks[1].count).toEqual(3)
		expect(stacks[1].equipped).toBeFalse()
		expect(stacks[1].uids).toEqual({ "a", "b", "c" })
	end)

	it("does not stack gear whose traits differ", function()
		local stacks = InventoryStacks.group({
			{
				item = item("s1", "arc_blade", "Arc Blade", "Weapon", "Rare", {
					trait("lifesteal", "Lifesteal", "4.0%"),
				}),
				equipped = false,
			},
			{
				item = item("s2", "arc_blade", "Arc Blade", "Weapon", "Rare", {
					trait("gold_find", "Gold Find", "8.0%"),
				}),
				equipped = false,
			},
		})
		expect(#stacks).toEqual(2)
		expect(stacks[1].count).toEqual(1)
		expect(stacks[2].count).toEqual(1)
		expect(stacks[1].uids[1] ~= stacks[2].uids[1]).toBeTrue()
	end)

	it("stacks copies that rolled the same traits", function()
		local same = { trait("lifesteal", "Lifesteal", "4.0%") }
		local stacks = InventoryStacks.group({
			{
				item = item("s1", "arc_blade", "Arc Blade", "Weapon", "Rare", same),
				equipped = false,
			},
			{
				item = item("s2", "arc_blade", "Arc Blade", "Weapon", "Rare", same),
				equipped = false,
			},
		})
		expect(#stacks).toEqual(1)
		expect(stacks[1].count).toEqual(2)
		expect(stacks[1].uids).toEqual({ "s1", "s2" })
	end)

	it("pulls the equipped copy out so the bag still shows its name", function()
		local stacks = InventoryStacks.group({
			{
				item = item("e", "wooden_sword", "Wooden Sword", "Weapon", "Common"),
				equipped = true,
			},
			{
				item = item("a", "wooden_sword", "Wooden Sword", "Weapon", "Common"),
				equipped = false,
			},
			{
				item = item("b", "wooden_sword", "Wooden Sword", "Weapon", "Common"),
				equipped = false,
			},
		})
		expect(#stacks).toEqual(2)
		expect(stacks[1].equipped).toBeTrue()
		expect(stacks[1].name).toEqual("Wooden Sword")
		expect(stacks[1].count).toEqual(1)
		expect(stacks[1].uids).toEqual({ "e" })
		expect(stacks[2].equipped).toBeFalse()
		expect(stacks[2].count).toEqual(2)
		expect(stacks[2].uids).toEqual({ "a", "b" })
	end)

	it("names equipped gear only when that id is in the bag", function()
		local empty = InventoryStacks.loadout({
			equipped = { weapon = "missing", pet = nil },
			inventory = {},
			pets = {},
		})
		expect(empty.weapon).toEqual("None")
		expect(empty.pet).toEqual("None")
		expect(empty.bonus).toEqual("None")

		local sword = item("sword", "wooden_sword", "Wooden Sword", "Weapon", "Common")
		local held = InventoryStacks.loadout({
			equipped = { weapon = "sword", pet = nil },
			inventory = { sword = sword },
			pets = {},
		})
		expect(held.weapon).toEqual("Wooden Sword")
		expect(held.pet).toEqual("None")
		expect(held.bonus).toEqual("None")
	end)

	it("does not stack two rolls of the same weapon", function()
		local function rolled(uid: string, damage: number)
			local row = item(uid, "vinewood_sword", "Vinewood Sword", "Weapon", "Common")
			row.stats = { { id = "damage", value = damage } }
			row.quality = damage / 14
			return row
		end
		local stacks = InventoryStacks.group({
			{ item = rolled("a", 10), equipped = false },
			{ item = rolled("b", 13), equipped = false },
		})
		expect(#stacks).toEqual(2)
		expect(stacks[1].quality ~= stacks[2].quality).toBeTrue()
	end)

	it("lists trait bonuses or None", function()
		expect(InventoryStacks.bonusLine({})).toEqual("None")
		expect(InventoryStacks.bonusLine(nil)).toEqual("None")
		expect(InventoryStacks.bonusLine({
			trait("lifesteal", "Lifesteal", "4.0%"),
			trait("gold_find", "Gold Find", "8.0%"),
		})).toEqual("Lifesteal 4.0% · Gold Find 8.0%")

		local blade = item("blade", "arc_blade", "Arc Blade", "Weapon", "Rare", {
			trait("lifesteal", "Lifesteal", "4.0%"),
		})
		local gear = InventoryStacks.loadout({
			equipped = { weapon = "blade" },
			inventory = { blade = blade },
			pets = {},
		})
		expect(gear.weapon).toEqual("Arc Blade")
		expect(gear.bonus).toEqual("Lifesteal 4.0%")
	end)

	it("shows pet quality, pet damage, and a trait on the equipped line", function()
		local stag = item("stag", "fern_stag", "Fern Stag", "Pet", "Rare", {
			trait("bonus_pet_damage", "Bonus Pet Damage", "5.0%"),
		})
		stag.quality = 0.72
		stag.stats = {
			{
				id = "pet_damage",
				name = "Pet Damage",
				value = 8,
				min = 6,
				max = 10,
				unit = "flat",
				roll = 0.5,
			},
		}
		local gear = InventoryStacks.loadout({
			equipped = { pet = "stag" },
			inventory = {},
			pets = { stag = stag },
		})
		expect(gear.pet).toEqual("Fern Stag  72% · Pet Damage 8 · Bonus Pet Damage 5.0%")
		expect(gear.bonus).toEqual("Bonus Pet Damage 5.0%")
	end)

	it("marks stars on the row and picks the strongest duplicate to feed", function()
		local kept = item("kept", "nightbriar", "Nightbriar", "Weapon", "Rare")
		kept.quality = 0.46
		kept.stars = 2
		local weak = item("weak", "nightbriar", "Nightbriar", "Weapon", "Rare")
		weak.quality = 0.2
		local strong = item("strong", "nightbriar", "Nightbriar", "Weapon", "Rare")
		strong.quality = 0.9
		expect(InventoryStacks.rowTitle({
			name = "Nightbriar",
			stars = 2,
			quality = 0.46,
			count = 1,
		})).toEqual("Nightbriar ★2 46%")
		local profile = {
			inventory = { kept = kept, weak = weak, strong = strong },
			pets = {},
		}
		local feeder = InventoryStacks.bestFeeder(profile, "kept")
		assert(feeder ~= nil)
		expect(feeder.uid).toEqual("strong")
		expect(InventoryStacks.bestFeeder(profile, "missing")).toBeNil()
	end)
end)
