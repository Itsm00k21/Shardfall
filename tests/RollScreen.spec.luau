--!strict

--[[
	RollScreen: Roll A (desktop) and Roll D (phone) layout from Kevin's
	Oct 19 2026 build. Checked at the four research sizes, from a 390x844
	phone to 1920x1080, using the same page box MenuHub.place gives.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local RollConfig = require("../src/ReplicatedStorage/Shared/RollConfig")
local RollScreen = require("../src/ReplicatedStorage/Shared/RollScreen")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

local SIZES = {
	{ 390, 844 },
	{ 844, 390 },
	{ 1280, 720 },
	{ 1920, 1080 },
}

local function page(vx: number, vy: number): (number, number)
	local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
	return math.max(44, box.w - 16), math.max(44, box.h - (UiTheme.HEADER + UiTheme.PAD) - 8)
end

local function inside(rect: any, w: number, h: number): boolean
	return rect.x >= 0 and rect.y >= 0 and rect.x + rect.w <= w and rect.y + rect.h <= h
end

local function overlaps(a: any, b: any): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

describe("RollScreen layout", function()
	it("uses the phone stack on a 390x844 phone and the A row elsewhere", function()
		local pw, ph = page(390, 844)
		expect(RollScreen.isPhone(pw)).toBeTrue()
		expect(RollScreen.layout(pw, ph).phone).toBeTrue()
		for index = 2, #SIZES do
			local w, h = page(SIZES[index][1], SIZES[index][2])
			expect(RollScreen.layout(w, h).phone).toBeFalse()
		end
	end)

	it("keeps every CTA inside the page, apart, and at least touch size", function()
		for _, size in ipairs(SIZES) do
			local w, h = page(size[1], size[2])
			local layout = RollScreen.layout(w, h)
			local spots = { layout.crack, layout.ten, layout.auto }
			if layout.odds ~= nil then
				table.insert(spots, layout.odds)
			end
			for i, a in ipairs(spots) do
				expect(inside(a, w, h)).toBeTrue()
				expect(a.h >= UiTheme.TOUCH).toBeTrue()
				expect(a.w >= UiTheme.TOUCH).toBeTrue()
				for j = i + 1, #spots do
					expect(overlaps(a, spots[j])).toBeFalse()
				end
			end
			expect(inside(layout.meter, w, h)).toBeTrue()
			expect(layout.meter.y + layout.meter.h <= layout.crack.y).toBeTrue()
			expect(layout.reserved).toEqual(h - layout.meter.y)
			-- The reel and list keep room above the reserved bottom.
			expect(h - layout.reserved >= 100).toBeTrue()
		end
	end)

	it("makes CRACK the dominant button", function()
		for _, size in ipairs(SIZES) do
			local w, h = page(size[1], size[2])
			local layout = RollScreen.layout(w, h)
			local crackArea = layout.crack.w * layout.crack.h
			expect(crackArea > layout.ten.w * layout.ten.h).toBeTrue()
			expect(crackArea > layout.auto.w * layout.auto.h).toBeTrue()
		end
	end)

	it("pins the phone stack to the bottom thumb zone with ODDS in the row", function()
		local w, h = page(390, 844)
		local layout = RollScreen.layout(w, h)
		expect(layout.crack.w).toEqual(w - RollConfig.EDGE * 2)
		expect(layout.crack.y < layout.ten.y).toBeTrue()
		expect(layout.ten.y).toEqual(h - RollConfig.EDGE - RollConfig.PHONE_ROW_H)
		expect(layout.odds ~= nil).toBeTrue()
		local odds = layout.odds :: any
		expect(odds.y).toEqual(layout.ten.y)
		expect(odds.x + odds.w).toEqual(w - RollConfig.EDGE)
		-- Two meter lines stack on the phone.
		expect(layout.pity.y > layout.luck.y).toBeTrue()
	end)

	it("puts x10 and AUTO beside CRACK on desktop", function()
		local w, h = page(1920, 1080)
		local layout = RollScreen.layout(w, h)
		expect(layout.odds == nil).toBeTrue()
		expect(layout.ten.y).toEqual(layout.crack.y)
		expect(layout.auto.y).toEqual(layout.crack.y)
		expect(layout.auto.x + layout.auto.w).toEqual(w - RollConfig.EDGE)
		-- The luck milestone is parked, so the pity bar takes the row.
		expect(layout.luck.w <= 1).toBeTrue()
		expect(layout.pity.x).toEqual(0)
		expect(layout.meter.w).toEqual(layout.pity.w)
	end)

	it("falls back safely on bad sizes", function()
		local layout = RollScreen.layout(0 / 0, -5)
		expect(layout.phone).toBeTrue()
		expect(layout.crack.w > 0).toBeTrue()
		expect(RollScreen.layout(math.huge, math.huge).crack.h > 0).toBeTrue()
	end)
end)

describe("RollScreen labels", function()
	it("shows real costs and the AUTO state", function()
		expect(RollScreen.costText(1)).toEqual("1")
		expect(RollScreen.costText(RollConfig.MULTI_COUNT)).toEqual("9")
		expect(RollScreen.autoLabel(false)).toEqual("AUTO")
		expect(RollScreen.autoLabel(true)).toEqual("AUTO ON")
		expect(RollScreen.CRACK_LABEL).toEqual("CRACK x1")
	end)

	it("hides the tenth-crack luck pips while the milestone is parked", function()
		local lit, text = RollScreen.luckPips(17)
		expect(lit).toEqual(0)
		expect(text).toEqual("")
	end)

	it("counts tenth-crack luck pips when the milestone is on", function()
		LaunchGate.SHOW.luckMilestone = true
		local lit, text = RollScreen.luckPips(17)
		local label = RarityConfig.bonusLabel(17)
		local none = RollScreen.luckPips(-3)
		LaunchGate.SHOW.luckMilestone = false
		expect(lit).toEqual(7)
		expect(text).toEqual(label)
		expect(none).toEqual(0)
	end)
end)

describe("Roll A/D wiring in MenuHub", function()
	local hub = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")

	it("pins the CTA row and meters with RollScreen and shows pity text", function()
		expect(string.find(hub, "RollScreen.layout(pageW, pageH)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "RollConfig.pityText(sinceLegendary)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "RollConfig.discountTag()", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "RollScreen.costText(RollConfig.MULTI_COUNT)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "IconAssets.RollCrystal", 1, true) ~= nil).toBeTrue()
	end)

	it("keeps one outline weight on the CTA buttons", function()
		expect(string.find(hub, "stroke.Thickness = UiTheme.STROKE_BOLD", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "detailsStroke.Thickness = UiTheme.STROKE_BOLD", 1, true) ~= nil).toBeTrue()
	end)
end)
