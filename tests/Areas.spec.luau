--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Areas = require("../src/ReplicatedStorage/Shared/Areas")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")

describe("Areas", function()
	it("offers the armory and the pet area, each with an ascension 0 pool", function()
		local areas = Areas.all()
		expect(#areas).toEqual(2)
		expect(areas[1].id).toEqual("armory")
		expect(areas[1].summary).toEqual("Weapons and armor")
		expect(areas[2].id).toEqual("pets")

		local armory = Areas.pools("armory")[1]
		local pets = Areas.pools("pets")[1]
		expect(armory.id).toEqual(Pools.DEFAULT_POOL_ID)
		expect(armory.ascension).toEqual(0)
		expect(pets.id).toEqual("verdant_pets")
		expect(pets.ascension).toEqual(0)
		expect(Areas.get("armory").name).toEqual("Armory")
	end)
end)
