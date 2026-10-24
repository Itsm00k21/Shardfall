--!strict

--[[
	Gold upgrades scale at read time. The flag ships off, so combat and
	Item Power stay on the saved stat until it is turned on.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CombatMath = require("../src/ReplicatedStorage/Shared/CombatMath")
local InventoryView = require("../src/ReplicatedStorage/Shared/InventoryView")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local UpgradeScale = require("../src/ReplicatedStorage/Shared/UpgradeScale")

local function withFlag(on: boolean, fn: () -> ())
	local previous = LaunchGate.SHOW.upgradeScale
	LaunchGate.SHOW.upgradeScale = on
	local ok, err = pcall(fn)
	LaunchGate.SHOW.upgradeScale = previous
	if not ok then
		error(err, 0)
	end
end

local function weapon(upgrade: number): any
	return {
		kind = "Weapon",
		name = "Bramble Fang",
		weaponType = "sword",
		upgrade = upgrade,
		rarity = "Uncommon",
		quality = 0.5,
		stars = 1,
		stats = {
			{ id = "damage", value = 12 },
			{ id = "attack_speed", value = 1 },
		},
		traits = {},
	}
end

describe("UpgradeScale", function()
	it("leaves combat, item power, and the preview on the saved stat while the flag is off", function()
		local item = weapon(4)
		withFlag(false, function()
			expect(UpgradeScale.enabled()).toEqual(false)
			expect(UpgradeScale.multiplier(4)).toEqual(1)
			expect(UpgradeScale.apply(12, 4)).toEqual(12)
			expect(CombatMath.offense(item, nil).damage).toEqual(12)
			expect(CombatMath.offense(item, nil).attackSpeed).toEqual(1)
			local vitality = CombatMath.vitality({
				{ upgrade = 4, stats = { { id = "health", value = 20 }, { id = "defense", value = 4 } } },
			})
			expect(vitality.maxHealth).toEqual(120)
			expect(vitality.defense).toEqual(4)
			local bare = InventoryView.powerOf({
				rarity = "Common",
				quality = 0,
				stars = 0,
				upgrade = 4,
			})
			expect(bare).toEqual(InventoryView.powerOf({ rarity = "Common", quality = 0, stars = 0 }))
			local preview = UpgradeScale.preview(item)
			expect(preview.enabled).toEqual(false)
			expect(preview.upgrade).toEqual(4)
			expect(preview.multiplier).toEqual(1)
			expect(preview.lines[1].value).toEqual(12)
			expect(preview.lines[1].base).toEqual(12)
			expect(item.stats[1].value).toEqual(12)
		end)
	end)

	it("scales damage and HP, item power, and the bag preview from config", function()
		local item = weapon(1)
		withFlag(true, function()
			expect(UpgradeScale.multiplier(0, true)).toEqual(1)
			expect(UpgradeScale.multiplier(1)).toBeCloseTo(1.08)
			expect(UpgradeScale.multiplier(10, true)).toBeCloseTo(1.8)
			expect(CombatMath.offense(item, nil).damage).toBeCloseTo(12 * 1.08)
			expect(CombatMath.offense(item, nil).attackSpeed).toEqual(1)
			expect(CombatMath.offense(nil, nil).damage).toEqual(5)
			local vitality = CombatMath.vitality({
				{ upgrade = 1, stats = { { id = "health", value = 20 }, { id = "defense", value = 4 } } },
			})
			expect(vitality.maxHealth).toEqual(math.floor(100 + 20 * 1.08 + 0.5))
			expect(vitality.defense).toEqual(4)
			local plain = InventoryView.powerOf({ rarity = "Common", quality = 0, stars = 0, upgrade = 0 })
			local forged = InventoryView.powerOf({ rarity = "Common", quality = 0, stars = 0, upgrade = 1 })
			expect(forged - plain).toEqual(UpgradeScale.POWER_STEP)
			local preview = UpgradeScale.preview(item)
			expect(preview.enabled).toEqual(true)
			expect(preview.multiplier).toBeCloseTo(1.08)
			expect(preview.lines[1].id).toEqual("damage")
			expect(preview.lines[1].base).toEqual(12)
			expect(preview.lines[1].value).toBeCloseTo(12 * 1.08)
			expect(preview.lines[1].text).toEqual("13")
			expect(item.stats[1].value).toEqual(12)
			expect(item.upgrade).toEqual(1)
		end)
	end)

	it("lets the bag ask for the on-state without flipping the live flag", function()
		local item = weapon(2)
		withFlag(false, function()
			local preview = UpgradeScale.preview(item, true)
			expect(UpgradeScale.enabled()).toEqual(false)
			expect(preview.enabled).toEqual(true)
			expect(preview.upgrade).toEqual(2)
			expect(preview.lines[1].value).toBeCloseTo(12 * 1.16)
			expect(CombatMath.offense(item, nil).damage).toEqual(12)
		end)
	end)
end)
