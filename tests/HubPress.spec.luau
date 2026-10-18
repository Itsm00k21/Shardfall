--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local HubPress = require("../src/ReplicatedStorage/Shared/HubPress")
local RollBatch = require("../src/ReplicatedStorage/Shared/RollBatch")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local function rightEdge(strip): number
	local edge = 0
	for _, chip in ipairs(strip.chips) do
		local far = chip.x + chip.w
		if far > edge then
			edge = far
		end
	end
	return edge
end

describe("HubPress", function()
	it("keeps each roll control on its own action", function()
		local open = HubPress.blank()
		open.infoOpen = true
		open.rollKind = "gear"
		open.tokens = 0
		local gear, gearEffect = HubPress.press(open, "GearShards")
		expect(gear.infoOpen).toEqual(false)
		expect(gear.rollKind).toEqual("gear")
		expect(gearEffect.rollCount).toEqual(nil)
		expect(gearEffect.handled).toEqual(true)
		local pets, petsEffect = HubPress.press(open, "PetShards")
		expect(pets.infoOpen).toEqual(false)
		expect(pets.rollKind).toEqual("pets")
		expect(petsEffect.rollCount).toEqual(nil)
		local ten, tenEffect = HubPress.press(open, "TimesTen")
		expect(ten.rollKind).toEqual("gear")
		expect(ten.infoOpen).toEqual(true)
		expect(tenEffect.notice).toEqual(RollBatch.NEED)
		expect(tenEffect.rollCount).toEqual(nil)
		local rich = HubPress.blank()
		rich.infoOpen = true
		rich.tokens = 10
		local paid, paidEffect = HubPress.press(rich, "TimesTen", true)
		expect(paid.rollKind).toEqual("gear")
		expect(paid.infoOpen).toEqual(true)
		expect(paidEffect.notice).toEqual(nil)
		expect(paidEffect.rollCount).toEqual(10)
		local quick = HubPress.press(open, "Quick")
		expect(quick.infoOpen).toEqual(true)
		expect(quick.rollKind).toEqual("gear")
		expect(quick.quickOn).toEqual(true)
		local stop = HubPress.press(open, "Stop")
		expect(stop.stopAt).toEqual("Uncommon")
		expect(stop.rollKind).toEqual("gear")
		local auto, autoEffect = HubPress.press(open, "Auto")
		expect(auto.autoOn).toEqual(true)
		expect(auto.focused).toEqual(true)
		expect(autoEffect.rollCount).toEqual(1)
		expect(auto.rollKind).toEqual("gear")
		local junk, junkEffect = HubPress.press(open, "JunkMode")
		expect(junk.autoJunk).toEqual("keep")
		expect(junkEffect.save).toEqual(true)
		expect(junk.rollKind).toEqual("gear")
		local below = HubPress.press(open, "JunkBelow")
		expect(below.junkBelow).toEqual("Uncommon")
		expect(below.infoOpen).toEqual(true)
		local missing, missingEffect = HubPress.press(open, "Meteor")
		expect(missingEffect.handled).toEqual(false)
		expect(missing.rollKind).toEqual("gear")
		expect(open.infoOpen).toEqual(true)
	end)

	it("lights Info instead of Gear while Info is open", function()
		local state = HubPress.blank()
		state.infoOpen = true
		expect(HubPress.lit(state, "Info")).toEqual(true)
		expect(HubPress.lit(state, "GearShards")).toEqual(false)
		expect(HubPress.lit(state, "PetShards")).toEqual(false)
		state.infoOpen = false
		state.rollKind = "pets"
		expect(HubPress.lit(state, "PetShards")).toEqual(true)
		expect(HubPress.lit(state, "GearShards")).toEqual(false)
		state.batching = true
		expect(HubPress.lit(state, "TimesTen")).toEqual(true)
	end)

	it("keeps the last history chip inside the row", function()
		local strip = HubPress.history(320, 10)
		expect(#strip.chips).toEqual(10)
		expect(rightEdge(strip) <= strip.w).toBeTrue()
		expect(strip.chips[10].x + strip.chips[10].w <= strip.w).toBeTrue()
		expect(strip.h > 44).toBeTrue()
		local paid = HubPress.history(320, 10, true)
		expect(paid.w).toEqual(strip.w)
		expect(#paid.chips).toEqual(10)
		local narrow = HubPress.history(80, 10)
		expect(rightEdge(narrow) <= narrow.w).toBeTrue()
		expect(narrow.chips[10].y > 0).toBeTrue()
	end)

	it("names an invisible active frame that covers the panel", function()
		expect(HubPress.blocker(nil)).toEqual(nil)
		expect(HubPress.blocker({
			{
				name = "Backdrop",
				visible = true,
				active = true,
				transparency = 1,
				z = 1,
				modal = true,
				full = true,
			},
		})).toEqual(nil)
		expect(HubPress.blocker({
			{
				name = "Shade",
				visible = true,
				active = true,
				transparency = 1,
				z = 8,
				modal = false,
				full = true,
			},
		})).toEqual("Shade")
	end)

	it("is what the Roll tab buttons call", function()
		local hub = fs.readFile(HUB)
		expect(string.find(hub, "HubPress.press", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "HubPress.lit", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "HubPress.history", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "applyControl(spotId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "applyControl(button.Name)", 1, true) ~= nil).toBeTrue()
		local legacy = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
		expect(string.find(legacy, "HubPress", 1, true)).toBeNil()
	end)
end)
