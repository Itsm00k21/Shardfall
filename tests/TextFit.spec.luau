--!strict

--[[
	TextFit is pure and InventoryHud does not run under Lune. The source
	lock reads the bag and checks the text walk, the ShardfallInventory
	name, and that the RenderStepped connection does not call TextFit.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local TextFit = require("../src/ReplicatedStorage/Shared/TextFit")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

local HUD = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/InventoryHud.luau"
local FIT = "src/ReplicatedStorage/Shared/TextFit.luau"

local LOCKED = {
	{ 14, 1, 14 },
	{ 16, 1, 16 },
	{ 22, 1, 22 },
	{ 11, 1, 14 },
	{ 13, 1, 14 },
	{ 14, 1.4, 20 },
	{ 15, 1.4, 21 },
	{ 16, 1.4, 22 },
	{ 22, 1.4, 31 },
	{ 11, 1.4, 15 },
}

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("TextFit", function()
	it("matches the locked sizes", function()
		expect(UiTheme.MIN_TEXT).toEqual(14)
		for _, row in ipairs(LOCKED) do
			expect(TextFit.px(row[1], row[2])).toEqual(row[3])
		end
		expect(TextFit.px(16, nil)).toEqual(16)
		expect(TextFit.px(16, "1.4")).toEqual(16)
		expect(TextFit.px(nil, 1.4)).toEqual(14)
	end)

	it("treats an unusable scale as 1 and an unusable base as 14", function()
		expect(TextFit.px(16, true)).toEqual(16)
		expect(TextFit.px(16, false)).toEqual(16)
		expect(TextFit.px(16, 0 / 0)).toEqual(16)
		expect(TextFit.px(16, math.huge)).toEqual(16)
		expect(TextFit.px(16, -math.huge)).toEqual(16)
		expect(TextFit.px(16, 0)).toEqual(16)
		expect(TextFit.px(16, -1)).toEqual(16)
		expect(TextFit.px(0, 1.4)).toEqual(14)
		expect(TextFit.px(-4, 1.4)).toEqual(14)
		expect(TextFit.px(0 / 0, 1.4)).toEqual(14)
		expect(TextFit.px(math.huge, 1.4)).toEqual(14)
		expect(TextFit.px(true, 1.4)).toEqual(14)
		expect(TextFit.px("16", 1.4)).toEqual(14)
	end)

	it("does not clamp the scale", function()
		expect(TextFit.px(16, 2)).toEqual(32)
		expect(TextFit.px(16, 2, { paid = true })).toEqual(32)
	end)

	it("ignores a third argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(TextFit.px(16, 1.4, { paid = true })).toEqual(22)
		expect(TextFit.px(16, 1.4, paid)).toEqual(22)
		expect(TextFit.px(16, 1.4, true)).toEqual(22)
		expect(TextFit.px(16, nil, paid)).toEqual(16)
		expect(TextFit.px(nil, 1.4, paid)).toEqual(14)
	end)

	it("does not write its arguments", function()
		local base = { n = 16, paid = true }
		local scale = { n = 1.4, paid = false }
		local extra = { paid = true, productId = 0, robux = 0, cost = 0, skip = false }
		table.freeze(base)
		table.freeze(scale)
		table.freeze(extra)
		expect(TextFit.px(base, scale, extra)).toEqual(14)
		expect(TextFit.px(16, 1.4, extra)).toEqual(22)
		expect(TextFit.px(16, scale, extra)).toEqual(16)
		expect(base.n).toEqual(16)
		expect(base.paid).toEqual(true)
		expect(scale.n).toEqual(1.4)
		expect(scale.paid).toEqual(false)
		expect(extra.paid).toEqual(true)
		expect(extra.productId).toEqual(0)
		expect(extra.robux).toEqual(0)
		expect(extra.cost).toEqual(0)
		expect(extra.skip).toEqual(false)
	end)

	it("does not use a clock, rng, or services", function()
		local source = fs.readFile(FIT)
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		expect(string.find(source, "tick(", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
		expect(string.find(source, "UiTheme.MIN_TEXT", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "1.4", 1, true)).toBeNil()
	end)
end)

describe("InventoryHud text scale", function()
	it("walks the bag from TextFit and leaves the spin alone", function()
		local source = fs.readFile(HUD)
		expect(string.find(source, "TextFit.px", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "ShardfallInventory", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "SkipTextScale", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "BaseText", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "GetDescendants", 1, true) ~= nil).toBeTrue()
		local spin =
			between(source, "RunService.RenderStepped:Connect(function()", "local controller = {}")
		expect(string.find(spin, "TextFit", 1, true)).toBeNil()
		expect(string.find(spin, "fitBagText", 1, true)).toBeNil()
		expect(string.find(spin, "gradient.Rotation", 1, true) ~= nil).toBeTrue()
		local profile =
			between(source, "function controller.setProfile", "function controller.toggle")
		expect(string.find(profile, "textScale", 1, true) ~= nil).toBeTrue()
		expect(string.find(profile, "fitBagText()", 1, true) ~= nil).toBeTrue()
		local paint =
			between(source, "render = function()", "for index, tab in ipairs(InventoryView.TABS)")
		expect(string.find(paint, "fitBagText()", 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, "TextFit", 1, true)).toBeNil()
	end)
end)
