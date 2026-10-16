--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Crafting = require("../src/ReplicatedStorage/Shared/Crafting")
local InventoryView = require("../src/ReplicatedStorage/Shared/InventoryView")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function stat(id: string, value: number)
	return {
		id = id,
		name = "",
		value = value,
		min = 0,
		max = 0,
		unit = "flat",
		roll = 0,
	}
end

local function gear(fields: { [string]: any })
	local item: { [string]: any } = {
		uid = fields.uid,
		templateId = fields.templateId,
		name = fields.name,
		kind = fields.kind,
		rarity = fields.rarity,
		traits = {},
		poolId = if fields.poolId ~= nil then fields.poolId else "verdant_armory",
		obtainedAt = if fields.obtainedAt ~= nil then fields.obtainedAt else 1,
		quality = if fields.quality ~= nil then fields.quality else 0,
		stars = 0,
		sockets = if fields.sockets ~= nil then fields.sockets else 0,
		locked = fields.locked == true,
		favorite = fields.favorite == true,
		stats = if fields.stats ~= nil then fields.stats else {},
	}
	if fields.weaponType ~= nil then
		item.weaponType = fields.weaponType
	end
	if fields.slot ~= nil then
		item.slot = fields.slot
	end
	return item
end

local function put(profile: Schema.ProfileData, fields: { [string]: any })
	Schema.insertItem(profile, gear(fields) :: any)
end

local function ids(rows: { InventoryView.Row }): { string }
	local out = {}
	for _, row in ipairs(rows) do
		table.insert(out, row.id)
	end
	return out
end

local function query(overrides: { [string]: any }?)
	local base = InventoryView.defaultQuery()
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			(base :: any)[key] = value
		end
	end
	return base
end

local function sample(): Schema.ProfileData
	local profile = Schema.template()
	put(profile, {
		uid = "common",
		templateId = "vinewood_sword",
		name = "Vinewood Sword",
		kind = "Weapon",
		rarity = "Common",
		quality = 0.2,
		obtainedAt = 10,
		sockets = 0,
		weaponType = "sword",
		stats = { stat("damage", 8) },
	})
	put(profile, {
		uid = "rare",
		templateId = "hartseeker",
		name = "Hartseeker",
		kind = "Weapon",
		rarity = "Rare",
		quality = 0.9,
		obtainedAt = 30,
		sockets = 2,
		weaponType = "sword",
		stats = { stat("damage", 20), stat("health", 12) },
	})
	put(profile, {
		uid = "dagger",
		templateId = "thorn_dagger",
		name = "Thorn Dagger",
		kind = "Weapon",
		rarity = "Common",
		quality = 0.5,
		obtainedAt = 20,
		sockets = 1,
		weaponType = "dagger",
		locked = true,
	})
	put(profile, {
		uid = "tide",
		templateId = "tideglass_dagger",
		name = "Tideglass Dagger",
		kind = "Weapon",
		rarity = "Uncommon",
		quality = 0.1,
		obtainedAt = 5,
		sockets = 0,
		weaponType = "dagger",
		poolId = "sunken_armory",
	})
	put(profile, {
		uid = "hood",
		templateId = "grovewarden_hood",
		name = "Grovewarden Hood",
		kind = "Armor",
		rarity = "Epic",
		quality = 0.4,
		obtainedAt = 40,
		sockets = 3,
		slot = "helm",
	})
	put(profile, {
		uid = "pup",
		templateId = "training_pup",
		name = "Training Pup",
		kind = "Pet",
		rarity = "Uncommon",
		quality = 0.3,
		obtainedAt = 8,
	})
	Schema.equipItem(profile, profile.inventory.rare)
	return profile
end

describe("InventoryView", function()
	it("filters weapons by rarity, realm, slot, sockets, equipped, locked, and search", function()
		local profile = sample()
		local weapons = InventoryView.query(profile, query(nil))
		expect(ids(weapons)).toEqual({ "rare", "tide", "dagger", "common" })

		local picked = InventoryView.query(
			profile,
			query({
				rarities = { Common = true, Rare = true },
			})
		)
		expect(ids(picked)).toEqual({ "rare", "dagger", "common" })

		local sunken = InventoryView.query(profile, query({ realm = "Sunken Reach" }))
		expect(ids(sunken)).toEqual({ "tide" })
		expect(sunken[1].realm).toEqual("Sunken Reach")
		expect(InventoryView.realmOf(profile.inventory.common)).toEqual("Verdant Wilds")

		local daggers = InventoryView.query(profile, query({ slot = "dagger" }))
		expect(ids(daggers)).toEqual({ "tide", "dagger" })

		local oneSocket = InventoryView.query(profile, query({ sockets = 1 }))
		expect(ids(oneSocket)).toEqual({ "dagger" })
		local roomy = InventoryView.query(
			profile,
			query({
				tab = "armor",
				socketsAtLeast = 3,
			})
		)
		expect(ids(roomy)).toEqual({ "hood" })

		local worn = InventoryView.query(profile, query({ equipped = "equipped" }))
		expect(ids(worn)).toEqual({ "rare" })
		expect(worn[1].equipped).toBeTrue()
		local bag = InventoryView.query(profile, query({ equipped = "unequipped" }))
		expect(ids(bag)).toEqual({ "tide", "dagger", "common" })

		local locked = InventoryView.query(profile, query({ locked = "locked" }))
		expect(ids(locked)).toEqual({ "dagger" })
		expect(locked[1].locked).toBeTrue()
		local open = InventoryView.query(profile, query({ locked = "unlocked" }))
		expect(ids(open)).toEqual({ "rare", "tide", "common" })

		local found = InventoryView.query(profile, query({ search = "ViNe" }))
		expect(ids(found)).toEqual({ "common" })
		expect(InventoryView.query(profile, query({ search = "missing" }))).toEqual({})
	end)

	it("sorts by power, rarity, newest, and name", function()
		local profile = sample()
		expect(ids(InventoryView.query(profile, query({ sort = "power" })))).toEqual({
			"rare",
			"tide",
			"dagger",
			"common",
		})
		expect(ids(InventoryView.query(profile, query({ sort = "rarity" })))).toEqual({
			"rare",
			"tide",
			"dagger",
			"common",
		})
		expect(ids(InventoryView.query(profile, query({ sort = "newest" })))).toEqual({
			"rare",
			"dagger",
			"common",
			"tide",
		})
		expect(ids(InventoryView.query(profile, query({ sort = "name" })))).toEqual({
			"rare",
			"dagger",
			"tide",
			"common",
		})
	end)

	it("keeps pets, materials, scrolls, and boosts on their own tabs", function()
		local profile = sample()
		expect(ids(InventoryView.query(profile, query({ tab = "pets" })))).toEqual({ "pup" })
		expect(ids(InventoryView.query(profile, query({ tab = "accessories" })))).toEqual({})
		expect(InventoryView.emptyText("accessories")).toEqual("No rings, amulets, or charms yet.")

		profile.materials.verdant_bark = 4
		profile.materials.vine = 2
		profile.materials.scroll_thornbound = 1
		profile.consumables[Materials.TONIC_ID] = 3
		profile.luckBoost = 1
		profile.forgeBoostUntil = 100

		local materials = InventoryView.query(profile, query({ tab = "materials", sort = "name" }))
		expect(ids(materials)).toEqual({ "material:vine", "material:verdant_bark" })
		local scrollOnMaterials = false
		for _, row in ipairs(materials) do
			if row.kind == "Scroll" then
				scrollOnMaterials = true
			end
		end
		expect(scrollOnMaterials).toBeFalse()

		local items =
			InventoryView.query(profile, query({ tab = "items", now = 50, sort = "name" }))
		expect(ids(items)).toEqual({
			"boost:forge",
			"consumable:" .. Materials.TONIC_ID,
			"boost:luck",
			"material:scroll_thornbound",
		})
		local cooled =
			InventoryView.query(profile, query({ tab = "items", now = 100, sort = "name" }))
		expect(ids(cooled)).toEqual({
			"consumable:" .. Materials.TONIC_ID,
			"boost:luck",
			"material:scroll_thornbound",
		})
	end)

	it("compares the selected piece against the one in that slot", function()
		local profile = sample()
		local other = InventoryView.counterpart(profile, profile.inventory.common)
		assert(other ~= nil)
		expect(other.uid).toEqual("rare")
		expect(InventoryView.counterpart(profile, profile.inventory.rare)).toBeNil()

		local lines = InventoryView.compare(profile.inventory.common, other)
		expect(#lines >= 2).toBeTrue()
		expect(lines[1].id).toEqual("damage")
		expect(lines[1].yours).toEqual("8")
		expect(lines[1].theirs).toEqual("20")
		expect(lines[1].delta).toEqual("-12")
		expect(lines[2].id).toEqual("health")
		expect(lines[2].yours).toEqual("—")
		expect(lines[2].theirs).toEqual("12")
		expect(InventoryView.statLines(profile.inventory.common)).toEqual({ "Damage  8" })
	end)

	it("salvages a rarity while skipping locked, equipped, and non-gear", function()
		local profile = Schema.template()
		put(profile, {
			uid = "free",
			templateId = "vinewood_sword",
			name = "Vinewood Sword",
			kind = "Weapon",
			rarity = "Common",
			weaponType = "sword",
		})
		put(profile, {
			uid = "held",
			templateId = "thorn_dagger",
			name = "Thorn Dagger",
			kind = "Weapon",
			rarity = "Common",
			weaponType = "dagger",
			locked = true,
		})
		put(profile, {
			uid = "worn",
			templateId = "iron_sword",
			name = "Iron Sword",
			kind = "Weapon",
			rarity = "Common",
			weaponType = "sword",
			poolId = "craft",
		})
		put(profile, {
			uid = "loved",
			templateId = "fernblade",
			name = "Fernblade",
			kind = "Weapon",
			rarity = "Uncommon",
			weaponType = "sword",
			favorite = true,
		})
		put(profile, {
			uid = "pup",
			templateId = "training_pup",
			name = "Training Pup",
			kind = "Pet",
			rarity = "Common",
		})
		Schema.equipItem(profile, profile.inventory.worn)

		expect(InventoryView.salvageBlock(profile, profile.inventory.held)).toEqual(
			"That item is locked."
		)
		expect(InventoryView.salvageBlock(profile, profile.inventory.worn)).toEqual(
			"Unequip it before salvaging."
		)
		expect(InventoryView.salvageBlock(profile, profile.inventory.loved)).toBeNil()
		expect(InventoryView.salvageBlock(profile, profile.pets.pup)).toEqual(
			"Only weapons and armor can be salvaged."
		)
		expect(InventoryView.realmOf(profile.inventory.worn)).toEqual("Verdant Wilds")

		local summary, reason = Crafting.salvageRarity(profile, "Common", 1)
		expect(reason).toBeNil()
		assert(summary ~= nil)
		expect(summary.count).toEqual(1)
		expect(profile.inventory.free).toBeNil()
		expect(profile.inventory.held.name).toEqual("Thorn Dagger")
		expect(profile.inventory.worn.name).toEqual("Iron Sword")
		expect(profile.inventory.loved.favorite).toEqual(true)
		expect(profile.pets.pup.name).toEqual("Training Pup")
		expect(profile.materials.verdant_bark > 0).toBeTrue()

		local loved, lovedReason = Crafting.salvageRarity(profile, "Uncommon", 1)
		expect(lovedReason).toBeNil()
		assert(loved ~= nil)
		expect(loved.count).toEqual(1)
		expect(profile.inventory.loved).toBeNil()

		local _, none = Crafting.salvageRarity(profile, "Common", 1)
		expect(none).toEqual("Nothing of that rarity can be salvaged.")
	end)

	it("lists every chest tier on its own tab", function()
		local chestQuery = InventoryView.defaultQuery()
		chestQuery.tab = "chests"
		local empty = InventoryView.query({}, chestQuery)
		expect(#empty).toEqual(6)
		local profile = Schema.template()
		profile.chests.Rare = 3
		local rows = InventoryView.query(profile, chestQuery)
		expect(#rows).toEqual(6)
		local rare = nil
		for _, row in ipairs(rows) do
			expect(row.kind).toEqual("Chest")
			if row.rarity == "Rare" then
				rare = row
			end
		end
		assert(rare ~= nil)
		expect(rare.count).toEqual(3)
		expect(rare.id).toEqual("chest:Rare")
		chestQuery.search = "myth"
		local found = InventoryView.query(profile, chestQuery)
		expect(#found).toEqual(1)
		expect(found[1].rarity).toEqual("Mythic")
	end)
end)
