--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Raids = require("../src/ReplicatedStorage/Shared/Raids")

describe("Raids", function()
	it("checks roles and scales a solo fight down", function()
		expect(Raids.roleOk("warden", "tank")).toEqual(true)
		expect(Raids.roleOk("tidecaller", "tank")).toEqual(false)
		expect(Raids.roleOk("frostblade", "flex")).toEqual(true)
		local hp, damage = Raids.combatScale("normal", 1, false)
		expect(hp < 1).toEqual(true)
		expect(damage < 1).toEqual(true)
		local full = Raids.combatScale("normal", 8, true)
		expect(full).toEqual(1.35)
	end)

	it("locks a boss for the week and raises the next drop chance", function()
		local data = {
			chests = { Rare = 0, Epic = 0 },
			raidMarks = 0,
			raidMarksEarned = 0,
			raidMarkWeek = -1,
		}
		local paid, dropped, locked = Raids.applyClear(data, "twins", "story", 0, 0.99)
		expect(paid).toEqual(25)
		expect(dropped).toEqual(false)
		expect(locked).toEqual(false)
		expect(data.raidPity.twins_story or data.raidPity["twins:story"]).toEqual(1)
		local again, droppedAgain, lockedAgain = Raids.applyClear(data, "twins", "story", 10, 0)
		expect(again).toEqual(25)
		expect(droppedAgain).toEqual(false)
		expect(lockedAgain).toEqual(true)
		expect(data.raidPity["twins:story"]).toEqual(1)
		local _, hit = Raids.applyClear(data, "sapwell", "story", 10, 0)
		expect(hit).toEqual(true)
		expect(data.chests.Rare).toEqual(1)
		expect(data.raidStory).toEqual(true)
		data.raidMarks = 80
		expect(Raids.buy(data, "rare_chest")).toEqual(true)
		expect(data.raidMarks).toEqual(0)
	end)
end)
