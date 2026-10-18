--!strict

--[[
	EchoChip is pure and RaidHud does not run under Lune. The source
	lock reads the chip mount and checks the place call, the safe
	fallback, and that the old (248, 16) offset is gone.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local EchoChip = require("../src/ReplicatedStorage/Shared/EchoChip")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

local RAID = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RaidHud.luau"

local PHONE = { x = 266, y = 136, w = 108, h = 28 }

local LOCKED = {
	{ 390, 844, PHONE },
	{ 844, 390, { x = 700, y = 80, w = 128, h = 28 } },
	{ 800, 380, { x = 656, y = 80, w = 128, h = 28 } },
	{ 1280, 720, { x = 1136, y = 96, w = 128, h = 28 } },
}

local function clear(box: { x: number, y: number, w: number, h: number }, vx: number, vy: number)
	local margin = UiTheme.safeMargin()
	expect(margin).toEqual(16)
	expect(box.x >= margin).toBeTrue()
	expect(box.y >= margin).toBeTrue()
	expect(box.x + box.w <= vx - margin).toBeTrue()
	expect(box.y + box.h <= vy - margin).toBeTrue()
	expect(HudLayout.overlaps(box, HudLayout.portrait(margin))).toBeFalse()
	expect(HudLayout.overlaps(box, HudLayout.health(margin))).toBeFalse()
	expect(HudLayout.overlaps(box, HudLayout.pills(vx, margin))).toBeFalse()
end

describe("EchoChip", function()
	it("matches the locked rects", function()
		for _, row in ipairs(LOCKED) do
			local vx = row[1]
			local vy = row[2]
			local want = row[3]
			local box = EchoChip.place(vx, vy)
			expect(box).toEqual(want)
			clear(box, vx, vy)
		end
		local first = EchoChip.place(390, 844)
		local second = EchoChip.place(390, 844)
		expect(first).toEqual(second)
		expect(rawequal(first, second)).toBeFalse()
	end)

	it("uses 390 by 844 for a missing or bad size", function()
		expect(EchoChip.place(nil, nil)).toEqual(PHONE)
		expect(EchoChip.place(nil, nil)).toEqual(EchoChip.place(390, 844))
		expect(EchoChip.place("390", "844")).toEqual(PHONE)
		expect(EchoChip.place(true, false)).toEqual(PHONE)
		expect(EchoChip.place(0 / 0, 844)).toEqual(PHONE)
		expect(EchoChip.place(390, 0 / 0)).toEqual(PHONE)
		expect(EchoChip.place(math.huge, 844)).toEqual(PHONE)
		expect(EchoChip.place(390, -math.huge)).toEqual(PHONE)
		expect(EchoChip.place(199, 844)).toEqual(PHONE)
		expect(EchoChip.place(390, 199)).toEqual(PHONE)
		expect(EchoChip.place(0, 0)).toEqual(PHONE)
		clear(EchoChip.place(nil, nil), 390, 844)
	end)

	it("keeps a side of 200", function()
		local box = EchoChip.place(200, 200)
		expect(box).toEqual({ x = 56, y = 136, w = 128, h = 28 })
		clear(box, 200, 200)
	end)

	it("ignores a third argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(EchoChip.place(390, 844, paid)).toEqual(PHONE)
		expect(EchoChip.place(390, 844, true)).toEqual(PHONE)
		expect(EchoChip.place(390, 844, { paid = true })).toEqual(PHONE)
		expect(EchoChip.place(844, 390, paid)).toEqual({ x = 700, y = 80, w = 128, h = 28 })
	end)

	it("does not write its arguments", function()
		local x = { paid = true, n = 390 }
		local y = { paid = true, n = 844 }
		local extra = { paid = true, productId = 0, robux = 0, cost = 0, skip = false }
		table.freeze(x)
		table.freeze(y)
		table.freeze(extra)
		expect(EchoChip.place(x, y, extra)).toEqual(PHONE)
		expect(EchoChip.place(390, 844, extra)).toEqual(PHONE)
		expect(x.paid).toEqual(true)
		expect(x.n).toEqual(390)
		expect(y.paid).toEqual(true)
		expect(y.n).toEqual(844)
		expect(extra.paid).toEqual(true)
		expect(extra.productId).toEqual(0)
		expect(extra.robux).toEqual(0)
		expect(extra.cost).toEqual(0)
		expect(extra.skip).toEqual(false)
	end)

	it("does not use a clock, rng, or services", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/EchoChip.luau")
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		expect(string.find(source, "tick(", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
		expect(string.find(source, "UiTheme.safeMargin", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "HudLayout.health", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "HudLayout.pills", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "HudLayout.portrait", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "HudLayout.overlaps", 1, true) ~= nil).toBeTrue()
	end)
end)

describe("RaidHud Echo chip", function()
	it("places the chip from EchoChip and drops the old offset", function()
		local raid = fs.readFile(RAID)
		local nameAt = string.find(raid, 'chip.Name = "EchoChip"', 1, true)
		local placeAt = string.find(raid, "EchoChip.place", 1, true)
		local signalAt = string.find(raid, 'GetPropertyChangedSignal("AbsoluteSize")', 1, true)
		local fallbackAt = string.find(raid, "vx < 200 or vy < 200", 1, true)
		expect(nameAt ~= nil and placeAt ~= nil and signalAt ~= nil and fallbackAt ~= nil).toBeTrue()
		expect((nameAt :: number) < (placeAt :: number)).toBeTrue()
		expect((placeAt :: number) < (signalAt :: number)).toBeTrue()
		expect(string.find(raid, "chip.Position", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "chip.Size", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "390", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "844", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "248, 16", 1, true)).toBeNil()
		expect(string.find(raid, "248,16", 1, true)).toBeNil()
		expect(string.find(raid, "run.echoLabel", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, 'chip.Text = ""', 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "chip.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, 'button("Leave"', 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, 'button("Ready"', 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, 'button("Story"', 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "Color3.fromRGB(120, 186, 96)", 1, true) ~= nil).toBeTrue()
	end)
end)
