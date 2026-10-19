--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local GearLook = require("../src/ReplicatedStorage/Shared/GearLook")
local PropAssets = require("../src/ReplicatedStorage/Shared/PropAssets")

local function profile(weaponType: string?, helm: boolean, chest: boolean)
	local inventory = {
		w = { uid = "w", kind = "Weapon", weaponType = weaponType },
		h = { uid = "h", kind = "Armor", slot = "helm" },
		c = { uid = "c", kind = "Armor", slot = "chest" },
	}
	return {
		inventory = inventory,
		equipped = {
			weapon = if weaponType ~= nil then "w" else nil,
			armor = { helm = if helm then "h" else nil, chest = if chest then "c" else nil },
			accessories = {},
		},
	}
end

describe("GearLook", function()
	it("shows the crystal set only for what the Bag has equipped", function()
		local full = GearLook.forProfile(profile("sword", true, true))
		expect(full.weapon).toEqual("CrystalSword")
		expect(full.helm).toEqual("CrystalHelm")
		expect(full.chest).toEqual("CrystalChest")
		local bare = GearLook.forProfile(profile(nil, false, false))
		expect(bare.weapon).toBeNil()
		expect(bare.helm).toBeNil()
		expect(bare.chest).toBeNil()
		local staff = GearLook.forProfile(profile("staff", false, false))
		expect(staff.weapon).toEqual("CrystalStaff")
		expect(staff.weaponPose).toEqual("upright")
		expect(staff.weaponGrip).toBeGreaterThan(0.2)
		expect(GearLook.forProfile(profile("sword", false, false)).weaponPose).toEqual("forward")
		for _, hold in pairs(GearLook.HOLDS) do
			expect(PropAssets[hold.kind] ~= nil).toBeTrue()
			expect(hold.grip).toBeGreaterThan(0)
			expect(hold.grip).toBeLessThan(1)
		end
		expect(GearLook.forProfile(nil).weapon).toBeNil()
		for _, kind in ipairs({ "CrystalSword", "CrystalHelm", "CrystalChest" }) do
			expect(PropAssets[kind] ~= nil).toBeTrue()
		end
	end)
	it("ignores an equipped uid that is not in the inventory or sits in the wrong slot", function()
		local data = profile("sword", true, true)
		data.equipped.weapon = "missing"
		data.equipped.armor.helm = "c"
		local look = GearLook.forProfile(data)
		expect(look.weapon).toBeNil()
		expect(look.helm).toBeNil()
		expect(look.chest).toEqual("CrystalChest")
	end)
	it("sizes the blade by type and changes the signature when gear changes", function()
		local dagger = GearLook.forProfile(profile("dagger", false, false))
		local great = GearLook.forProfile(profile("greatsword", false, false))
		expect(great.weaponScale).toBeGreaterThan(dagger.weaponScale)
		expect(GearLook.signature(dagger) == GearLook.signature(great)).toBeFalse()
	end)
	it("fits the helm and chest around the body part on R15 and Rthro sizes", function()
		for _, head in ipairs({ { x = 1.2, y = 1.2, z = 1.2 }, { x = 1.0, y = 1.25, z = 1.05 } }) do
			local size, lift = GearLook.helmFit(head, { x = 1.17, y = 1.8, z = 1.57 })
			expect(size.x).toBeGreaterThan(head.x)
			expect(size.z).toBeGreaterThan(head.z)
			expect(lift.y).toBeGreaterThan(0)
			-- The brim stays below the crown and above the chin.
			local bottom = lift.y - size.y / 2
			expect(bottom).toBeLessThan(head.y / 2)
			expect(bottom).toBeGreaterThan(-head.y / 2)
		end
		for _, torso in ipairs({ { x = 2, y = 1.6, z = 1 }, { x = 1.7, y = 1.9, z = 0.9 } }) do
			local size = GearLook.chestFit(torso, { x = 2, y = 2, z = 1.16 })
			expect(size.x).toBeGreaterThan(torso.x)
			expect(size.x).toBeLessThan(torso.x * 1.2)
			expect(size.z).toBeGreaterThan(torso.z)
		end
	end)
	it("grips the sword near the hilt and scales it with the rig", function()
		local size, gripY = GearLook.swordFit({ x = 0.7, y = 2.5, z = 0.3 }, 3.4, 1)
		expect(size.y).toBeCloseTo(3.4)
		expect(gripY).toBeLessThan(0)
		expect(gripY).toBeGreaterThan(-size.y / 2)
		local big = GearLook.swordFit({ x = 0.7, y = 2.5, z = 0.3 }, 3.4, 1.3)
		expect(big.y).toBeGreaterThan(size.y)
	end)
end)
