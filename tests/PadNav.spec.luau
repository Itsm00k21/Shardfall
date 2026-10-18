--!strict

--[[
	PadNav is pure. It owns the next index, the deadzone, and which
	D-pad keys count. PadFocus is the client module that calls it.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local PadNav = require("../src/ReplicatedStorage/Shared/PadNav")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local function cursor(count: number, index: number, held: string?)
	return { count = count, index = index, held = held or "" }
end

describe("PadNav", function()
	it("steps to the next visible button on the d-pad and wraps", function()
		expect(PadNav.counts("DPadDown")).toBeTrue()
		expect(PadNav.counts("DPadRight")).toBeTrue()
		expect(PadNav.counts("DPadUp")).toBeTrue()
		expect(PadNav.counts("DPadLeft")).toBeTrue()
		expect(PadNav.counts("ButtonA")).toBeFalse()
		expect(PadNav.counts("ButtonB")).toBeFalse()
		expect(PadNav.counts("ButtonX")).toBeFalse()
		expect(PadNav.counts("ButtonY")).toBeFalse()
		expect(PadNav.counts("ButtonL1")).toBeFalse()
		expect(PadNav.counts("ButtonR1")).toBeFalse()
		expect(PadNav.next(cursor(3, 1), "DPadDown").index).toEqual(2)
		expect(PadNav.next(cursor(3, 2), "DPadRight").index).toEqual(3)
		expect(PadNav.next(cursor(3, 3), "DPadDown").index).toEqual(1)
		expect(PadNav.next(cursor(3, 1), "DPadUp").index).toEqual(3)
		expect(PadNav.next(cursor(3, 2), "DPadLeft").index).toEqual(1)
		expect(PadNav.next(cursor(3, 1), "ButtonA").index).toEqual(1)
		expect(PadNav.next(cursor(3, 1), "ButtonB").index).toEqual(1)
	end)

	it("steps once when the stick leaves the deadzone and ignores a small tilt", function()
		local small = PadNav.next(cursor(4, 2), { x = 0.1, y = 0.2 })
		expect(small.index).toEqual(2)
		expect(small.held).toEqual("")
		local edge = PadNav.next(cursor(4, 2), { x = 0, y = -PadNav.DEADZONE })
		expect(edge.index).toEqual(2)
		expect(edge.held).toEqual("")
		local down = PadNav.next(cursor(4, 2), { x = 0, y = -0.8 })
		expect(down.index).toEqual(3)
		expect(down.held).toEqual("down")
		local held = PadNav.next(cursor(4, down.index, down.held), { x = 0, y = -0.9 })
		expect(held.index).toEqual(down.index)
		expect(held.held).toEqual("down")
		local back = PadNav.next(cursor(4, held.index, held.held), { x = 0, y = 0 })
		expect(back.index).toEqual(held.index)
		expect(back.held).toEqual("")
		local again = PadNav.next(cursor(4, back.index, back.held), { x = 0, y = -0.8 })
		expect(again.index).toEqual(back.index + 1)
		expect(PadNav.next(cursor(4, 1), { x = 0.9, y = 0.1 }).index).toEqual(2)
		expect(PadNav.next(cursor(4, 2), { x = -0.9, y = 0 }).index).toEqual(1)
		expect(PadNav.next(cursor(4, 2), { x = 0, y = 0.9 }).index).toEqual(1)
		expect(PadNav.next(cursor(3, 1), { x = 0, y = 0.9 }).index).toEqual(3)
	end)

	it("ignores a third argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		local plain = PadNav.next(cursor(3, 1), "DPadDown")
		local extra = PadNav.next(cursor(3, 1), "DPadDown", { paid = true })
		local full = PadNav.next(cursor(3, 1), "DPadDown", paid)
		expect(extra.index).toEqual(plain.index)
		expect(full.index).toEqual(plain.index)
		expect(extra.held).toEqual(plain.held)
		local stick = PadNav.next(cursor(3, 1), { x = 0, y = -0.8 }, paid)
		expect(stick.index).toEqual(2)
		expect(PadNav.next(cursor(3, 1), { x = 0.1, y = 0.1 }, paid).index).toEqual(1)
		expect(PadNav.counts("DPadDown", paid)).toBeTrue()
		expect(PadNav.counts("ButtonX", paid)).toBeFalse()
	end)

	it("is required by the client focus module", function()
		local focus = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/PadFocus.luau")
		expect(string.find(focus, 'WaitForChild("PadNav")', 1, true) ~= nil).toBeTrue()
		expect(string.find(focus, "PadNav.counts", 1, true) ~= nil).toBeTrue()
		expect(string.find(focus, "PadNav.next", 1, true) ~= nil).toBeTrue()
		expect(string.find(focus, "PadNav.DEADZONE", 1, true) ~= nil).toBeTrue()
		local source = fs.readFile(HUB)
		expect(string.find(source, 'WaitForChild("PadFocus")', 1, true) ~= nil).toBeTrue()
		local sinkAt = string.find(source, "function hubFn.bindSinkKeys", 1, true)
		local sinkEnd = string.find(source, "function hubFn.setWorldInput", sinkAt :: number, true)
		local sinkBody = string.sub(source, sinkAt :: number, sinkEnd :: number)
		expect(string.find(sinkBody, "Keybinds.sinkNames()", 1, true) ~= nil).toBeTrue()
		expect(string.find(sinkBody, "Enum.KeyCode.ButtonA", 1, true)).toBeNil()
	end)
end)
