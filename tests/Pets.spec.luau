--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Pets = require("../src/ReplicatedStorage/Shared/Pets")

describe("Pets", function()
	it("hatches eight roles and refuses to fuse a favorite", function()
		expect(#Pets.SPECIES >= 8).toEqual(true)
		local roles = {}
		for _, row in ipairs(Pets.SPECIES) do
			roles[row.role] = true
		end
		expect(roles.Striker).toEqual(true)
		expect(roles.Guardian).toEqual(true)
		expect(roles.Mender).toEqual(true)
		expect(roles.Gatherer).toEqual(true)
		expect(roles.Hexer).toEqual(true)
		local pet = Pets.hatch(0)
		expect(pet.bond).toEqual(1)
		expect(pet.affinity).toEqual(1)
		expect(pet.favorite).toEqual(false)
		Pets.pet(pet)
		expect(pet.affinity).toEqual(2)
		local copy = Pets.hatch(0)
		copy.favorite = true
		local ok, note = Pets.bond(pet, copy)
		expect(ok).toEqual(false)
		expect(note).toEqual("A favorite cannot be fused.")
		copy.favorite = false
		ok = Pets.bond(pet, copy)
		expect(ok).toEqual(true)
		expect(pet.bond).toEqual(2)
	end)

	it("discovers a hidden combo and caps the list at three", function()
		local found = Pets.combos(
			{ "tide_sprite", "mossback", "bark_owl", "void_moth" },
			"tidecaller",
			false,
			false
		)
		expect(found[1]).toEqual("sprite_tide")
		expect(#found <= 3).toEqual(true)
		local eclipse = Pets.combos({ "bark_owl", "void_moth" }, "", false, false)
		expect(eclipse[1]).toEqual("eclipse")
	end)
end)
