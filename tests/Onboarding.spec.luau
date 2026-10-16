--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Onboarding = require("../src/ReplicatedStorage/Shared/Onboarding")

describe("Onboarding", function()
	it("walks the cold open and pays the same kit on skip", function()
		expect(Onboarding.step("open").text ~= "").toEqual(true)
		expect(Onboarding.next("open")).toEqual("class")
		expect(Onboarding.next("haven")).toBeNil()
		local data = { gold = 10, shardKeys = 0, chests = {}, consumables = {} }
		Onboarding.starter(data)
		expect(data.onboardDone).toEqual(true)
		expect(data.gold).toEqual(260)
		expect(data.chests.Rare).toEqual(1)
		expect(data.consumables.healing_tonic).toEqual(3)
		local goals = Onboarding.goals("dodge")
		expect(goals[1].done).toEqual(true)
		expect(goals[3].id).toEqual("dodge")
		expect(goals[3].done).toEqual(false)
	end)
end)
