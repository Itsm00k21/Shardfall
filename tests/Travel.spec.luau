--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Haven = require("../src/ReplicatedStorage/Shared/Haven")
local Travel = require("../src/ReplicatedStorage/Shared/Travel")

local function profile()
	return {
		waystones = {},
		lastTravel = 0,
		travelPass = false,
	}
end

describe("Travel", function()
	it("lists the six stands and leaves spawn open", function()
		expect(#Travel.DESTINATIONS).toEqual(6)
		local names = {}
		for _, dest in ipairs(Travel.DESTINATIONS) do
			table.insert(names, dest.name)
		end
		expect(names).toEqual({
			"Spawn",
			"Forge",
			"Armory Rolls",
			"Pet Rolls",
			"Market",
			"Dungeon Portals",
		})
		local data = profile()
		expect(Travel.isUnlocked(data, "spawn")).toBeTrue()
		expect(Travel.isUnlocked(data, "forge")).toBeTrue()
		expect(Travel.isUnlocked(nil, "portals")).toBeTrue()
		expect(Travel.isUnlocked(data, "missing")).toBeFalse()
		local binds = 0
		for _, dest in ipairs(Travel.DESTINATIONS) do
			expect(Travel.shouldBind("Waystone", dest.id)).toBeTrue()
			expect(Travel.shouldBind("WaystoneCrystal", dest.id)).toBeFalse()
			binds += 1
		end
		expect(binds).toEqual(6)
		local x, y, z = Travel.arrival("spawn")
		expect(x).toEqual(Haven.SPAWN.x)
		expect(y).toEqual(Haven.SPAWN.y)
		expect(z).toEqual(Haven.SPAWN.z)
		local _fx, forgeY = Travel.arrival("forge")
		expect(forgeY).toEqual(Haven.FLOOR_Y + 4)
	end)

	it("leaves every stand open and does not record a touch", function()
		local data = profile()
		for _, dest in ipairs(Travel.DESTINATIONS) do
			expect(Travel.isUnlocked(data, dest.id)).toBeTrue()
			expect(Travel.attempt(data, dest.id, 1000 + dest.x)).toBeNil()
			data.lastTravel = 0
		end
		expect(Travel.touch(data, "forge")).toBeFalse()
		expect(data.waystones.forge).toBeNil()
		expect(Travel.touch(data, "nope")).toBeFalse()
		expect(Travel.touch(nil, "market")).toBeFalse()
	end)

	it("blocks a trip during the cooldown and does not stamp a rejected one", function()
		local data = profile()
		expect(Travel.attempt(data, "forge", 100)).toBeNil()
		expect(data.lastTravel).toEqual(100)
		local cooling = Travel.attempt(data, "market", 105)
		expect(cooling).toEqual("Waystone cooling down (5s).")
		expect(data.lastTravel).toEqual(100)
		expect(Travel.remaining(data, 105) > 0).toBeTrue()

		expect(Travel.attempt(data, "market", 110)).toBeNil()
		expect(data.lastTravel).toEqual(110)
		expect(Travel.remaining(data, 120)).toEqual(0)
	end)

	it("lets a travel pass skip the cooldown without selling the pass", function()
		local data = profile()
		data.lastTravel = 50
		data.travelPass = true
		expect(Travel.passSkipsCooldown(data)).toBeTrue()
		expect(Travel.remaining(data, 51)).toEqual(0)
		expect(Travel.attempt(data, "portals", 51)).toBeNil()
		expect(data.lastTravel).toEqual(51)
		expect(Travel.PASS_PITCH ~= "").toBeTrue()
		expect(Travel.attempt(nil, "spawn", 10)).toEqual("Profile is still loading.")
		expect(Travel.attempt(profile(), "nope", 10)).toEqual("Unknown destination.")
		local skewed = profile()
		skewed.lastTravel = 500
		expect(Travel.remaining(skewed, 100)).toEqual(Travel.COOLDOWN)
	end)
end)
