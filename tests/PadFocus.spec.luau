--!strict

--[[
	PadFocus is pure and lives on the client. The source lock checks
	that MenuHub parents a UIStroke named PadRing, scrolls through
	PadFocus.canvas, and never calls Activated:Fire.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local PadFocus = require("../src/StarterPlayer/StarterPlayerScripts/ShardfallClient/PadFocus")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local function column(count: number): { any }
	local boxes = {}
	for index = 1, count do
		table.insert(boxes, { x = 0, y = (index - 1) * 40, w = 40, h = 36 })
	end
	return boxes
end

describe("PadFocus", function()
	it("follows focus order up and down and jumps left and right", function()
		expect(PadFocus.direction("DPadDown")).toEqual("down")
		expect(PadFocus.direction("DPadUp")).toEqual("up")
		expect(PadFocus.direction("DPadLeft")).toEqual("left")
		expect(PadFocus.direction("DPadRight")).toEqual("right")
		expect(PadFocus.direction("ButtonA")).toBeNil()
		expect(PadFocus.direction("ButtonB")).toBeNil()
		expect(PadFocus.direction("ButtonX")).toBeNil()
		expect(PadFocus.direction("ButtonY")).toBeNil()
		expect(PadFocus.direction("ButtonL1")).toBeNil()
		expect(PadFocus.direction("ButtonR1")).toBeNil()
		local boxes = column(3)
		expect(PadFocus.step(1, 3, "down", boxes)).toEqual(2)
		expect(PadFocus.step(3, 3, "down", boxes)).toEqual(1)
		expect(PadFocus.step(1, 3, "up", boxes)).toEqual(3)
		expect(PadFocus.step(2, 3, "up", boxes)).toEqual(1)
		boxes[3] = { x = 240, y = 0, w = 40, h = 36 }
		expect(PadFocus.step(1, 3, "right", boxes)).toEqual(3)
		expect(PadFocus.step(3, 3, "left", boxes)).toEqual(1)
		expect(PadFocus.step(1, 3, "down", boxes)).toEqual(2)
		local stacked = column(3)
		expect(PadFocus.step(2, 3, "right", stacked)).toEqual(3)
		expect(PadFocus.step(1, 3, "left", stacked)).toEqual(3)
		expect(PadFocus.step(1, 3, "ButtonA", boxes)).toEqual(1)
	end)

	it("steps once when the stick leaves the deadzone and ignores a small tilt", function()
		local small = PadFocus.stick(0.1, 0.2, "")
		expect(small.direction).toBeNil()
		expect(small.held).toEqual("")
		local edge = PadFocus.stick(0, -PadFocus.DEADZONE, "")
		expect(edge.direction).toBeNil()
		expect(edge.held).toEqual("")
		local down = PadFocus.stick(0, -0.8, "")
		expect(down.direction).toEqual("down")
		expect(down.held).toEqual("down")
		local held = PadFocus.stick(0, -0.9, down.held)
		expect(held.direction).toBeNil()
		expect(held.held).toEqual("down")
		local back = PadFocus.stick(0, 0, held.held)
		expect(back.direction).toBeNil()
		expect(back.held).toEqual("")
		local again = PadFocus.stick(0, -0.8, back.held)
		expect(again.direction).toEqual("down")
		expect(PadFocus.stick(0.9, 0.1, "").direction).toEqual("right")
		expect(PadFocus.stick(-0.9, 0, "").direction).toEqual("left")
		expect(PadFocus.stick(0, 0.9, "").direction).toEqual("up")
	end)

	it("scrolls a row into view and leaves a visible row alone", function()
		local moved = PadFocus.canvas({
			x = 0,
			y = 0,
			w = 200,
			h = 100,
			canvasX = 0,
			canvasY = 0,
		}, {
			x = 0,
			y = 400,
			w = 80,
			h = 40,
		})
		expect(moved ~= nil).toBeTrue()
		expect(moved.x).toEqual(0)
		expect(moved.y).toEqual(340)
		local above = PadFocus.canvas({
			x = 0,
			y = 100,
			w = 200,
			h = 100,
			canvasX = 0,
			canvasY = 80,
		}, {
			x = 0,
			y = 40,
			w = 80,
			h = 40,
		})
		expect(above ~= nil).toBeTrue()
		expect(above.y).toEqual(20)
		expect(PadFocus.canvas({
			x = 0,
			y = 0,
			w = 200,
			h = 100,
			canvasX = 12,
			canvasY = 4,
		}, {
			x = 10,
			y = 10,
			w = 80,
			h = 40,
		})).toBeNil()
	end)

	it("ignores a third argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		local boxes = column(3)
		expect(PadFocus.step(1, 3, "down", boxes, paid)).toEqual(PadFocus.step(1, 3, "down", boxes))
		expect(PadFocus.direction("DPadDown", paid)).toEqual("down")
		expect(PadFocus.direction("ButtonX", paid)).toBeNil()
		local stick = PadFocus.stick(0, -0.8, "", paid)
		expect(stick.direction).toEqual("down")
		expect(PadFocus.stick(0.1, 0.1, "", paid).direction).toBeNil()
		local scrolled = PadFocus.canvas({
			x = 0,
			y = 0,
			w = 200,
			h = 100,
			canvasX = 0,
			canvasY = 0,
		}, {
			x = 0,
			y = 400,
			w = 80,
			h = 40,
		}, paid)
		expect(scrolled.y).toEqual(340)
	end)

	it("parents a UIStroke named PadRing and does not fire Activated", function()
		local source = fs.readFile(HUB)
		expect(string.find(source, 'WaitForChild("PadFocus")', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'WaitForChild("PadNav")', 1, true)).toBeNil()
		expect(string.find(source, "Activated:Fire", 1, true)).toBeNil()
		local nameAt = string.find(source, 'ring.Name = "PadRing"', 1, true)
		expect(nameAt ~= nil).toBeTrue()
		local beforeName = string.sub(source, math.max(1, (nameAt :: number) - 80), nameAt :: number)
		expect(string.find(beforeName, 'Instance.new("UIStroke")', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "Color3.fromRGB(244, 240, 252)", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "Thickness = 4", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "BorderStrokePosition.Inner", 1, true) ~= nil).toBeTrue()
		local listAt = string.find(source, "function hubFn.padList", 1, true)
		local syncAt = string.find(source, "function hubFn.padSync", listAt :: number, true)
		expect(listAt ~= nil and syncAt ~= nil).toBeTrue()
		local listBody = string.sub(source, listAt :: number, syncAt :: number)
		expect(string.find(listBody, "UiRouter.cycle()", 1, true) ~= nil).toBeTrue()
		expect(string.find(listBody, "ClientChrome.TABS", 1, true)).toBeNil()
		local began = string.find(source, "UserInputService.InputBegan:Connect", 1, true)
		local processedAt = string.find(source, "if processed then", began :: number, true)
		expect(began ~= nil and processedAt ~= nil).toBeTrue()
		local beforeProcessed = string.sub(source, began :: number, processedAt :: number)
		expect(string.find(beforeProcessed, "PadFocus.direction", 1, true) ~= nil).toBeTrue()
		expect(string.find(beforeProcessed, 'keyName == "ButtonA"', 1, true) ~= nil).toBeTrue()
		local sinkAt = string.find(source, "function hubFn.bindSinkKeys", 1, true)
		local sinkEnd = string.find(source, "function hubFn.setWorldInput", sinkAt :: number, true)
		local sinkBody = string.sub(source, sinkAt :: number, sinkEnd :: number)
		expect(string.find(sinkBody, "Enum.KeyCode.ButtonA", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "PadFocus.canvas", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "hubFn.pressRoll()", 1, true) ~= nil).toBeTrue()
		local _, activations = string.gsub(source, "rollButton%.Activated:Connect", "")
		local _, begins = string.gsub(source, "rollButton%.InputBegan:Connect", "")
		expect(activations).toEqual(1)
		expect(begins).toEqual(1)
		local _, capture = string.gsub(source, "hubState%.capturing ~= nil and input%.KeyCode == Enum%.KeyCode%.Escape", "")
		expect(capture).toEqual(1)
	end)
end)
