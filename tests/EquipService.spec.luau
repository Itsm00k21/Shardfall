--!strict

--[[
	Phase 2 equip, server side. Totals read item.upgrade when gearLevels
	is on. The flag-off path does not scale and does not write a save.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local Elements = require("../src/ReplicatedStorage/Shared/Config/Elements")
local EquipSlots = require("../src/ReplicatedStorage/Shared/Config/EquipSlots")
local EquipStats = require("../src/ReplicatedStorage/Shared/Config/EquipStats")
local GearLevels = require("../src/ReplicatedStorage/Shared/Config/GearLevels")
local Save = require("../src/server/EquipService/Save")
local EquipService = require("../src/server/EquipService/EquipService")
local Remotes = require("../src/server/EquipService/Remotes")
local Validate = require("../src/server/EquipService/Validate")

local function ctx(gearOn: boolean): any
	return {
		slots = EquipSlots,
		stats = EquipStats,
		elements = Elements,
		classes = Classes,
		gearConfig = GearLevels,
		gearEnabled = gearOn,
	}
end

local function weapon(uid: string, upgrade: number?): any
	return {
		uid = uid,
		templateId = "bramble_fang",
		name = "Bramble Fang",
		kind = "Weapon",
		rarity = "Uncommon",
		upgrade = upgrade,
		stats = { { id = "damage", value = 12 } },
	}
end

local function profile(): any
	return {
		gold = 80,
		inventory = {},
		pets = {},
		equipped = { weapon = nil, pet = nil, armor = {}, accessories = {} },
		classId = "warden",
		classXp = { warden = 0 },
	}
end

local function stat(view: any, id: string): number
	return view.stats.byId[id]
end

describe("Equip totals", function()
	it("matches the unarmed numbers on an empty loadout", function()
		local view = EquipService.view(profile(), ctx(true))
		expect(stat(view, "damage")).toEqual(5)
		expect(stat(view, "attack_speed")).toEqual(1)
		expect(stat(view, "crit_chance")).toEqual(0.02)
		expect(stat(view, "crit_damage")).toEqual(1.5)
		expect(stat(view, "health")).toEqual(100)
		expect(view.loadout.weapon).toEqual("")
		expect(view.slots[1].level).toBeNil()
	end)

	it("scales the saved stat by the forge upgrade and not by a new level", function()
		local data = profile()
		local item = weapon("w1", 0)
		item.damage = 999
		item.robux = true
		data.inventory.w1 = item
		local ok, reason, view = EquipService.equip(data, "weapon", "w1", ctx(true))
		expect(ok).toEqual(true)
		expect(reason).toBeNil()
		expect(stat(view, "damage")).toEqual(12)
		expect(view.slots[1].level).toEqual(0)
		item.upgrade = 1
		view = EquipService.view(data, ctx(true))
		expect(stat(view, "damage")).toBeCloseTo(12 * 1.08)
		expect(view.slots[1].level).toEqual(1)
		item.upgrade = 2
		view = EquipService.view(data, ctx(false))
		expect(stat(view, "damage")).toEqual(12)
		expect(view.slots[1].level).toEqual(2)
		expect(item.level).toBeNil()
		expect(item.stats[1].value).toEqual(12)
		expect(data.gold).toEqual(80)
		expect(data.equipped.weapon).toBeNil()
	end)

	it("applies the element after the upgrade and adds flat luck once", function()
		local data = profile()
		local item = weapon("w1", 1)
		item.element = "ember"
		data.inventory.w1 = item
		EquipService.equip(data, "weapon", "w1", ctx(true))
		local view = EquipService.view(data, ctx(true))
		expect(stat(view, "damage")).toBeCloseTo(12 * 1.08 * 1.1)
		local voided = weapon("w2", 1)
		voided.element = "void"
		voided.stats = { { id = "attack_speed", value = 1 } }
		data.inventory.w2 = voided
		EquipService.equip(data, "weapon", "w2", ctx(true))
		view = EquipService.view(data, ctx(true))
		expect(stat(view, "attack_speed")).toBeCloseTo(1 * 1.08 * 1.1)
		expect(stat(view, "luck")).toEqual(1)
	end)
end)

describe("Equip rules", function()
	it("refuses a bad slot, a missing item, a bad kind, and a second copy", function()
		local data = profile()
		data.inventory.w1 = weapon("w1", 0)
		data.inventory.helm = {
			uid = "helm",
			templateId = "helm",
			name = "Helm",
			kind = "Armor",
			rarity = "Common",
			stats = { { id = "health", value = 20 } },
		}
		expect(EquipService.equip(data, "nope", "w1", ctx(false))).toEqual(false)
		expect(select(2, EquipService.equip(data, "weapon", "missing", ctx(false)))).toEqual(Validate.MISSING)
		expect(select(2, EquipService.equip(data, "weapon", "helm", ctx(false)))).toEqual(Validate.FIT)
		local ok = EquipService.equip(data, "weapon", "w1", ctx(false))
		expect(ok).toEqual(true)
		expect(select(2, EquipService.equip(data, "skill1", "thorn_bash", ctx(false)))).toBeNil()
		expect(select(2, EquipService.equip(data, "skill2", "thorn_bash", ctx(false)))).toEqual(Validate.DUPLICATE)
		expect(select(2, EquipService.equip(data, "skill2", "heart_grove", ctx(false)))).toEqual(Validate.SKILL)
		local _, _, view = EquipService.equip(data, "skill2", "rootgrasp", ctx(false))
		expect(view.loadout.skill2).toEqual("rootgrasp")
		expect(view.slots[5].locked).toEqual(true)
		expect(data.equipped.weapon).toBeNil()
		expect(data.gold).toEqual(80)
	end)

	it("unequips one slot and seats owned gear without granting", function()
		local data = profile()
		data.inventory.w1 = weapon("w1", 3)
		data.inventory.zarmor = {
			uid = "zarmor",
			kind = "Armor",
			templateId = "bark_mail",
			name = "Bark Mail",
			rarity = "Common",
			stats = { { id = "health", value = 20 } },
		}
		data.pets.pet = {
			uid = "pet",
			kind = "Pet",
			templateId = "rift_hound",
			name = "Rift Hound",
			rarity = "Rare",
			stats = { { id = "pet_damage", value = 4 } },
		}
		data.equipped.weapon = "leave-me"
		local seated = EquipService.fillOwned(data, ctx(true))
		expect(seated).toEqual(5)
		expect(data.equipLoadout.weapon).toEqual("w1")
		expect(data.equipLoadout.armor).toEqual("zarmor")
		expect(data.equipLoadout.pet).toEqual("pet")
		expect(data.equipLoadout.skill1).toEqual("thorn_bash")
		expect(data.equipped.weapon).toEqual("leave-me")
		expect(data.inventory.w1.upgrade).toEqual(3)
		local _, _, view = EquipService.unequip(data, "weapon", ctx(true))
		expect(view.loadout.weapon).toEqual("")
		expect(view.removed).toEqual("w1")
		expect(stat(view, "damage")).toEqual(5)
		expect(stat(view, "health")).toEqual(120)
		expect(select(2, EquipService.unequip(data, "weapon", ctx(true)))).toEqual(Validate.EMPTY)
	end)

	it("migrates the loadout on a copy", function()
		local raw = {
			gold = 3,
			equipped = { weapon = "keep" },
			inventory = { w1 = weapon("w1", 2) },
			equipLoadout = { weapon = "w1", armor = "gone" },
		}
		local copy, err = Save.migrate(raw, ctx(false))
		expect(err).toBeNil()
		expect(raw.equipLoadout.armor).toEqual("gone")
		expect(copy.equipLoadout.weapon).toEqual("w1")
		expect(copy.equipLoadout.armor).toEqual("")
		expect(copy.gold).toEqual(3)
		expect(copy.equipped.weapon).toEqual("keep")
		expect(copy.inventory.w1.upgrade).toEqual(2)
		expect(copy.inventory.w1.level).toBeNil()
		copy.gold = 0
		expect(raw.gold).toEqual(3)
	end)
end)

describe("Equip remotes", function()
	local function handle(request: any, deps: any, buckets: any)
		return Remotes.handle(request, deps, buckets)
	end

	it("does not read or write while equip is off", function()
		local result = handle({
			action = "EquipSlot",
			userId = 1,
			args = { "weapon", "w1" },
			now = 0,
		}, {
			equipOn = function()
				return false
			end,
			read = function()
				error("read")
			end,
			mutate = function()
				error("mutate")
			end,
			ctx = ctx(false),
		}, {})
		expect(result.ok).toEqual(false)
		expect(result.error).toEqual(Validate.OFF)
	end)

	it("rejects a bad id before mutate and rate-limits the next calls", function()
		local data = profile()
		data.inventory.w1 = weapon("w1", 0)
		local buckets = {}
		local writes = 0
		local deps = {
			equipOn = function()
				return true
			end,
			read = function()
				return data
			end,
			mutate = function(_userId, mutator)
				writes += 1
				local why = mutator(data)
				if why ~= nil then
					return false, why
				end
				return true, nil
			end,
			changed = function() end,
			ctx = ctx(true),
		}
		local bad = handle({
			action = "EquipSlot",
			userId = 4,
			args = { "weapon", "bad id" },
			now = 20,
		}, deps, buckets)
		expect(bad.error).toEqual(Validate.MISSING)
		expect(writes).toEqual(0)
		for _ = 1, 6 do
			local result = handle({ action = "GetEquip", userId = 4, args = {}, now = 20 }, deps, buckets)
			expect(result.ok).toEqual(true)
			expect(result.stats.byId.damage).toEqual(5)
		end
		local slow = handle({ action = "GetEquip", userId = 4, args = {}, now = 20 }, deps, buckets)
		expect(slow.error).toEqual(Validate.SLOW)
		expect(writes).toEqual(0)
	end)

	it("equips through the handler and leaves a junk uid until a real write", function()
		local data = profile()
		data.inventory.w1 = weapon("w1", 1)
		data.equipLoadout = { weapon = "not-owned" }
		local seen = nil
		local deps = {
			equipOn = function()
				return true
			end,
			read = function()
				return data
			end,
			mutate = function(_userId, mutator)
				local why = mutator(data)
				if why ~= nil then
					return false, why
				end
				return true, nil
			end,
			changed = function(_userId, payload)
				seen = payload
			end,
			ctx = ctx(true),
		}
		local looked = handle({ action = "GetEquip", userId = 9, args = {}, now = 1 }, deps, {})
		expect(looked.loadout.weapon).toEqual("")
		expect(data.equipLoadout.weapon).toEqual("not-owned")
		expect(seen).toBeNil()
		local equipped = handle({
			action = "EquipSlot",
			userId = 9,
			args = { "weapon", "w1" },
			now = 1,
		}, deps, {})
		expect(equipped.ok).toEqual(true)
		expect(equipped.loadout.weapon).toEqual("w1")
		expect(equipped.stats.byId.damage).toBeCloseTo(12 * 1.08)
		expect(data.equipLoadout.weapon).toEqual("w1")
		expect(data.equipped.weapon).toBeNil()
		expect(data.gold).toEqual(80)
		expect(seen.loadout.weapon).toEqual("w1")
		expect(seen.oldLevel).toBeNil()
	end)
end)
