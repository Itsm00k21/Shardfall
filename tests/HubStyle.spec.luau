--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Economy = require("../src/ReplicatedStorage/Shared/Economy")
local HubStyle = require("../src/ReplicatedStorage/Shared/HubStyle")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local IconAssets = require("../src/ReplicatedStorage/Shared/IconAssets")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local function inside(rect, width, height)
	expect(rect.x >= 0).toBeTrue()
	expect(rect.y >= 0).toBeTrue()
	expect(rect.w > 0).toBeTrue()
	expect(rect.h > 0).toBeTrue()
	expect(rect.x + rect.w <= width).toBeTrue()
	expect(rect.y + rect.h <= height).toBeTrue()
end

describe("HubStyle", function()
	it("gives every class its own crest and falls back for unknown ids", function()
		local Classes = require("../src/ReplicatedStorage/Shared/Classes")
		local seen = {}
		local count = 0
		for _, def in ipairs(Classes.all()) do
			local key = HubStyle.classArt(def.id)
			expect(key ~= nil).toBeTrue()
			expect(string.sub(IconAssets[key :: string] or "", 1, 13)).toEqual("rbxassetid://")
			expect(seen[IconAssets[key :: string]]).toBeNil()
			seen[IconAssets[key :: string]] = true
			count += 1
		end
		expect(count).toEqual(5)
		expect(HubStyle.classArt("")).toBeNil()
		expect(HubStyle.classArt(nil)).toBeNil()
		expect(HubStyle.classArt("nobody")).toBeNil()
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		expect(string.find(hub, "HubStyle.classArt(entry.id)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "HubStyle.classArt(classId)", 1, true) ~= nil).toBeTrue()
	end)

	it("gives the rail's tabs the rail's painted art in the hub column", function()
		for _, id in ipairs({
			"hero",
			"bag",
			"pets",
			"roll",
			"shop",
			"settings",
			"raids",
			"market",
			"pass",
		}) do
			local key = HubStyle.TAB_ART[id]
			expect(string.sub(IconAssets[key] or "", 1, 13)).toEqual("rbxassetid://")
		end
	end)

	it("keeps every Bag pill and the hub title visible on a 390 px phone", function()
		local box = HudLayout.hub(390, 844, UiTheme.safeMargin())
		local bodyW = box.w - 16
		local labelled, compact = 0, 0
		for _, pill in ipairs(HubStyle.pills()) do
			labelled += HudLayout.chipWidth(pill.label) + 24 + 6
			compact += UiTheme.TOUCH + 6
		end
		-- Labelled chips overflow here, so MenuHub switches to icon-only art.
		expect(labelled > bodyW).toBeTrue()
		expect(compact - 6 <= bodyW).toBeTrue()
		-- Title (x 8, width box.w - 16 - 104) ends before the 96 px Close.
		expect(8 + (box.w - 16 - 104) <= box.w - 8 - 96).toBeTrue()
	end)

	it("gives each Bag pill and item kind painted art that exists", function()
		for _, pill in ipairs(HubStyle.pills()) do
			local key = HubStyle.PILL_ART[pill.id]
			expect(key ~= nil).toBeTrue()
			expect(string.sub(IconAssets[key] or "", 1, 13)).toEqual("rbxassetid://")
		end
		local cases = {
			{ { kind = "Weapon" }, "ItemWeapon" },
			{ { kind = "Armor" }, "ItemArmor" },
			{ { kind = "Relic" }, "ItemRelic" },
			{ { kind = "item", relic = true }, "ItemRelic" },
			{ { kind = "Pet" }, "Pets" },
			{ { species = "Mossback" }, "Pets" },
			{ { kind = "Accessory" }, "ItemAccessory" },
			{ { kind = "consumable" }, "ItemConsumable" },
			{ { kind = "item" }, "ItemMisc" },
			{ "junk", "ItemMisc" },
		}
		for _, case in ipairs(cases) do
			local key = HubStyle.itemArt(case[1])
			expect(key).toEqual(case[2])
			expect(string.sub(IconAssets[key] or "", 1, 13)).toEqual("rbxassetid://")
		end
	end)

	it("names the mockup labels and keeps x1 and x10", function()
		expect(HubStyle.CLOSE).toEqual("CLOSE")
		expect(HubStyle.EQUIP).toEqual("EQUIP")
		expect(HubStyle.CRACK_ONE).toEqual("CRACK x1")
		expect(HubStyle.CRACK_TEN).toEqual("CRACK x10")
		expect(HubStyle.CRACK_PET).toEqual("CRACK PET SHARD")
		expect(HubStyle.CURRENCIES).toEqual({ "Gold", "Shards", "Keys", "Mastery" })
		expect(HubStyle.shardCount(1250)).toEqual("Shards  1250")
		expect(HubStyle.shardCount(nil)).toEqual("Shards  0")
		expect(HubStyle.upgradeLabel(0)).toEqual("UPGRADE  " .. tostring(Economy.upgradeCost(0)))
		expect(HubStyle.upgradeLabel(Economy.UPGRADE_MAX)).toEqual("UPGRADE  Max")
		expect(HubStyle.barScale(0.6)).toEqual(0.6)
		expect(HubStyle.barScale(0)).toEqual(0.04)
		expect(HubStyle.petPerk({ ability = "Auto-collect drops" })).toEqual("Auto-collect drops")
		expect(HubStyle.petPerk({ role = "Striker" })).toEqual("Striker")
		expect(HubStyle.petStats({ level = 25, bond = 3, role = "Striker" })[1].label).toEqual(
			"Level"
		)
		expect(HubStyle.inPill({ kind = "Weapon" }, "Weapons")).toBeTrue()
		expect(HubStyle.inPill({ kind = "Weapon" }, "Pets")).toBeFalse()
		expect(HubStyle.inPill({ kind = "Pet" }, "All")).toBeTrue()
		local vest =
			{ kind = "Armor", slot = "chest", weaponType = "sword", name = "Woven Bark Vest" }
		expect(HubStyle.inPill(vest, "Weapons")).toBeFalse()
		expect(HubStyle.inPill(vest, "Armor")).toBeTrue()
		expect(HubStyle.inPill(vest, "Items")).toBeFalse()
		expect(HubStyle.inPill({ kind = "Consumable", name = "Tonic" }, "Items")).toBeTrue()
		expect(HubStyle.inPill({ kind = "Weapon", slot = "chest" }, "Armor")).toBeFalse()
		local before = 150
		local profile = { gold = before }
		expect(HubStyle.upgradeLabel(0)).toEqual("UPGRADE  150")
		expect(profile.gold).toEqual(before)
	end)

	it("puts the pedestal left of the odds and leaves x100 off the row", function()
		local stage = HubStyle.rollStage(800, 360)
		inside(stage.pedestal, stage.w, stage.h)
		inside(stage.odds, stage.w, stage.h)
		inside(stage.row, stage.w, stage.h)
		expect(stage.odds.x >= stage.pedestal.x + stage.pedestal.w).toBeTrue()
		expect(stage.row.y >= stage.pedestal.y + stage.pedestal.h).toBeTrue()
		expect(#stage.buttons).toEqual(4)
		expect(stage.buttons[1].id).toEqual("Roll")
		expect(stage.buttons[1].label).toEqual("CRACK x1")
		expect(stage.buttons[2].id).toEqual("TimesTen")
		expect(stage.buttons[2].label).toEqual("CRACK x10")
		expect(stage.buttons[3].id).toEqual("Auto")
		expect(stage.buttons[4].id).toEqual("Info")
		for _, spot in ipairs(stage.buttons) do
			expect(spot.id ~= "x100").toBeTrue()
			expect(spot.x >= stage.count.w).toBeTrue()
			expect(spot.x + spot.w <= stage.row.w).toBeTrue()
		end
		local paid = HubStyle.rollStage(800, 360, { paid = true, gem = 50 })
		expect(paid.w).toEqual(stage.w)
		expect(paid.buttons[2].label).toEqual(stage.buttons[2].label)
		expect(#paid.buttons).toEqual(4)
	end)

	it("splits the bag and the pets panes and keeps eight slots", function()
		local bag = HubStyle.bagStage(800, 480)
		inside(bag.grid, bag.w, bag.h)
		inside(bag.detail, bag.w, bag.h)
		inside(bag.loadout, bag.w, bag.h)
		expect(bag.detail.x >= bag.grid.x + bag.grid.w).toBeTrue()
		expect(bag.loadout.y >= bag.grid.y + bag.grid.h).toBeTrue()
		expect(bag.slots).toEqual(8)
		local pets = HubStyle.petStage(800, 400)
		inside(pets.list, pets.w, pets.h)
		inside(pets.detail, pets.w, pets.h)
		expect(pets.detail.x >= pets.list.x + pets.list.w).toBeTrue()
		local paid = HubStyle.bagStage(800, 480, true)
		expect(paid.slots).toEqual(bag.slots)
		expect(paid.detail.x).toEqual(bag.detail.x)
		expect(#HubStyle.pills()).toEqual(5)
		expect(HubStyle.pills()[2].label).toEqual("Weapons")
		expect(HubStyle.pills()[2].icon).toEqual("attack")
		expect(HubStyle.capacityLine({ inventory = { a = {} }, pets = {}, inventoryCap = 100 })).toEqual(
			"Capacity: 1/100"
		)
		expect(HubStyle.capacityLine(nil)).toEqual("Capacity: 0/100")
		local gold = 40
		local profile = {
			gold = gold,
			inventory = {
				worn = { uid = "worn", kind = "Weapon", rarity = "Common" },
				better = { uid = "better", kind = "Weapon", rarity = "Rare" },
				relic = { uid = "relic", kind = "Relic", rarity = "Legendary" },
			},
			equipped = { weapon = "worn" },
		}
		expect(HubStyle.bestGear(profile)).toEqual({ "better" })
		expect(HubStyle.bestGear(profile, { paid = true })).toEqual({ "better" })
		expect(profile.gold).toEqual(gold)
		profile.equipped.weapon = "better"
		expect(HubStyle.bestGear(profile)).toEqual({})
	end)

	it("is what MenuHub paints, and the legacy panel is untouched", function()
		local hub = fs.readFile(HUB)
		expect(string.find(hub, "HubStyle.rollStage", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'Name = "Pedestal"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'Name = "OddsBars"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'Name = "CrackRow"', 1, true) ~= nil).toBeTrue()
		-- Clip 7: the Bag's 1-8 strip is gone (Prism BAG spec).
		expect(string.find(hub, 'Name = "Loadout"', 1, true)).toBeNil()
		expect(string.find(hub, "HubStyle.bagColumns", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'Name = "PetDetail"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Crack a Pet Shard", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "HubStyle.CRACK_ONE", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'Name = "Worn"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'Name = "EquipBest"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'Name = "Capacity"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "HubStyle.capacityLine", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "HubStyle.bestGear", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "x100", 1, true)).toBeNil()
		expect(string.find(hub, "Robux", 1, true)).toBeNil()
		local legacy = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
		expect(string.find(legacy, "HubStyle", 1, true)).toBeNil()
		expect(UiTheme.RGB.panel[1]).toEqual(32)
		expect(UiTheme.RGB.close[1]).toEqual(176)
		local doc = fs.readFile("docs/design/UI_STYLE.md")
		expect(string.find(doc, "mockups/mock_roll.jpg", 1, true) ~= nil).toBeTrue()
		expect(string.find(doc, "mockups/mock_bag.jpg", 1, true) ~= nil).toBeTrue()
		expect(string.find(doc, "mockups/mock_pets.jpg", 1, true) ~= nil).toBeTrue()
		expect(string.find(doc, "x100", 1, true) ~= nil).toBeTrue()
	end)
end)
