--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Areas = require("../src/ReplicatedStorage/Shared/Areas")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")

describe("Areas", function()
	it("publishes the starter shard as the only roll area", function()
		local areas = Areas.all()
		expect(#areas).toEqual(1)
		expect(areas[1].id).toEqual("starter")
		expect(areas[1].name).toEqual("Starter Shard")
		expect(areas[1].poolId).toEqual(Pools.STARTER_ID)
		expect(areas[1].pityLegendaryAt).toEqual(50)
		expect(areas[1].summary).toEqual("Weapons, pets, and materials")

		local pool = Pools.get(areas[1].poolId)
		assert(pool ~= nil)
		expect(pool.public).toBeTrue()
		expect(Areas.get("starter").poolId).toEqual(Pools.STARTER_ID)
		expect(Areas.get("missing")).toBeNil()
	end)
end)
