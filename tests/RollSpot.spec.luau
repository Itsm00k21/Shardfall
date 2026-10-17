--!strict

--[[
	RollSpot is pure and the Roll tab does not run under Lune. The
	source lock checks that MenuHub places the row from this module
	and no longer sizes the three buttons at a third of the page.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RollSpot = require("../src/ReplicatedStorage/Shared/RollSpot")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"
local MODULE = "src/ReplicatedStorage/Shared/RollSpot.luau"

local function same(band, buttons, w: number, h: number)
	expect(band.w).toEqual(w)
	expect(band.h).toEqual(h)
	expect(#band.buttons).toEqual(3)
	for index, button in ipairs(buttons) do
		expect(band.buttons[index]).toEqual(button)
	end
end

local function inside(band)
	for _, button in ipairs(band.buttons) do
		expect(button.x >= 0).toBeTrue()
		expect(button.y >= 0).toBeTrue()
		expect(button.w >= 1).toBeTrue()
		expect(button.h).toEqual(44)
		expect(button.x + button.w <= band.w).toBeTrue()
		expect(button.y + button.h <= band.h).toBeTrue()
	end
	for left = 1, #band.buttons do
		for right = left + 1, #band.buttons do
			local a = band.buttons[left]
			local b = band.buttons[right]
			local clear = a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y
			expect(clear).toBeTrue()
		end
	end
end

describe("RollSpot", function()
	it("gives Pet Shards its own line on a phone row", function()
		local band = RollSpot.place(140)
		same(band, {
			{ id = "GearShards", label = "Gear", x = 0, y = 0, w = 66, h = 44 },
			{ id = "PetShards", label = "Pet Shards", x = 0, y = 52, w = 140, h = 44 },
			{ id = "TimesTen", label = "x10", x = 74, y = 0, w = 66, h = 44 },
		}, 140, 96)
		inside(band)
		local again = RollSpot.place(140)
		expect(again).toEqual(band)
		expect(rawequal(again, band)).toBeFalse()
	end)

	it("shares one line once Gear Shards fits", function()
		local band = RollSpot.place(328)
		same(band, {
			{ id = "GearShards", label = "Gear Shards", x = 0, y = 0, w = 104, h = 44 },
			{ id = "PetShards", label = "Pet Shards", x = 112, y = 0, w = 104, h = 44 },
			{ id = "TimesTen", label = "x10", x = 224, y = 0, w = 104, h = 44 },
		}, 328, 44)
		inside(band)
		local wide = RollSpot.place(431)
		expect(wide.h).toEqual(44)
		expect(wide.buttons[1].label).toEqual("Gear Shards")
		expect(wide.buttons[2].label).toEqual("Pet Shards")
		expect(wide.buttons[2].y).toEqual(0)
		inside(wide)
	end)

	it("keeps a 156px page on two lines", function()
		local band = RollSpot.place(156)
		expect(band.h).toEqual(96)
		expect(band.buttons[2].id).toEqual("PetShards")
		expect(band.buttons[2].label).toEqual("Pet Shards")
		expect(band.buttons[2].w).toEqual(156)
		expect(band.buttons[2].y).toEqual(52)
		expect(band.buttons[1].label).toEqual("Gear")
		inside(band)
	end)

	it("uses the 140px phone band for a missing or bad width", function()
		local phone = RollSpot.place(140)
		expect(RollSpot.place(nil)).toEqual(phone)
		expect(RollSpot.place("140")).toEqual(phone)
		expect(RollSpot.place(true)).toEqual(phone)
		expect(RollSpot.place(0 / 0)).toEqual(phone)
		expect(RollSpot.place(math.huge)).toEqual(phone)
		expect(RollSpot.place(-math.huge)).toEqual(phone)
		expect(RollSpot.place(0)).toEqual(phone)
		expect(RollSpot.place(43)).toEqual(phone)
		expect(RollSpot.place(-20)).toEqual(phone)
		inside(RollSpot.place(nil))
	end)

	it("ignores a second argument, including paid", function()
		expect(RollSpot.place(140, true)).toEqual(RollSpot.place(140))
		expect(RollSpot.place(328, { paid = true, cost = 25, robux = 25 })).toEqual(RollSpot.place(328))
		expect(rawequal(RollSpot.place(140, true), RollSpot.place(140))).toBeFalse()
	end)

	it("is what the roll tab uses for the shard row", function()
		local hub = fs.readFile(HUB)
		local source = fs.readFile(MODULE)
		expect(string.find(hub, "RollSpot.place", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "0.33, -6", 1, true)).toBeNil()
		expect(string.find(source, "Pet Shards", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "Gear Shards", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Crack a Pet Shard", 1, true) ~= nil).toBeTrue()
	end)
end)
