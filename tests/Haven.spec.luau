--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Haven = require("../src/ReplicatedStorage/Shared/Haven")

describe("Haven", function()
	it("lays the districts and the five realm arches around the plaza", function()
		expect(Haven.district("forge") ~= nil).toBeTrue()
		expect(Haven.district("market") ~= nil).toBeTrue()
		expect(Haven.district("guild") ~= nil).toBeTrue()
		expect(Haven.district("garden") ~= nil).toBeTrue()
		expect(Haven.district("observatory") ~= nil).toBeTrue()
		expect(Haven.ARMORY.station).toEqual("armory")
		expect(Haven.district("forge").station).toEqual("craft")
		expect(Haven.district("garden").station).toEqual("pets")
		expect(#Haven.PORTALS).toEqual(5)
	end)

	it("leaves only Verdant Wilds open into the Rootvault", function()
		local openCount = 0
		for _, portal in ipairs(Haven.PORTALS) do
			if portal.open == true then
				openCount += 1
				expect(portal.id).toEqual("verdant")
				expect(portal.dungeonId).toEqual(Dungeons.ROOTVAULT_ID)
			else
				expect(type(portal.message) == "string").toBeTrue()
			end
		end
		expect(openCount).toEqual(1)
		expect(Haven.portal("sunken").open).toEqual(false)
		expect(Haven.portal("ember").open).toEqual(false)
		expect(Haven.portal("frost").open).toEqual(false)
		expect(Haven.portal("void").open).toEqual(false)
	end)

	it("puts the spawn on the plaza and a 20 to 30 second walk across the hub", function()
		expect(Haven.spawnOnPlaza()).toBeTrue()
		local seconds = Haven.crossingSeconds(Haven.WALK_SPEED)
		expect(seconds >= 20).toBeTrue()
		expect(seconds <= 30).toBeTrue()
	end)

	it("keeps the dungeon rooms beyond the islands", function()
		local _, _, waveZ = Dungeons.roomOrigin(Dungeons.WAVES_ROOM_INDEX)
		local _, _, roomZ = Dungeons.roomOrigin(1)
		local reach = Haven.reach()
		expect(math.abs(waveZ) > reach + 80).toBeTrue()
		expect(math.abs(roomZ) > reach + 80).toBeTrue()
	end)
end)
