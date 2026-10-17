--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ItemBases = require("../src/ReplicatedStorage/Shared/ItemBases")
local PetRoster = require("../src/ReplicatedStorage/Shared/PetRoster")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")

describe("PetRoster", function()
	it("lists three useful companions and no cute stand-in", function()
		expect(#PetRoster.STARTER).toEqual(3)
		expect(PetRoster.effect("shardjaw")).toEqual("collect")
		expect(PetRoster.effect("thorn_lantern")).toEqual("ping")
		expect(PetRoster.effect("glass_kestrel")).toEqual("flash")
		expect(PetRoster.get("moss_hare")).toBeNil()
		local pool = Pools.get("verdant_pets")
		assert(pool ~= nil)
		local have = {}
		for _, entry in ipairs(pool.entries) do
			have[entry.templateId] = entry
		end
		for _, row in ipairs(PetRoster.STARTER) do
			local entry = have[row.id]
			assert(entry ~= nil)
			expect(entry.name).toEqual(row.name)
			expect(entry.rarity).toEqual(row.rarity)
			local base = ItemBases.get(row.id)
			assert(base ~= nil)
			expect(base.kind).toEqual("Pet")
			expect(base.name).toEqual(row.name)
		end
	end)

	it("reads the equipped template and ignores a missing pet", function()
		expect(PetRoster.equippedEffect(nil)).toBeNil()
		expect(PetRoster.equippedEffect({
			equipped = { pet = "pet-1" },
			pets = { ["pet-1"] = { templateId = "glass_kestrel", kind = "Pet" } },
		})).toEqual("flash")
		expect(PetRoster.equippedEffect({
			equipped = { pet = "missing" },
			pets = {},
		})).toBeNil()
	end)
end)
