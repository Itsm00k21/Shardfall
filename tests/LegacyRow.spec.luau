--!strict

--[[
	Ui does not run under Lune. The source lock checks the legacy rows
	under the Shardfall ScreenGui: the stats block, the realm line, and
	the odds headings and rows. Salvage stays 52. The banner stays on
	BannerFit. RenderStepped does not set these heights.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local TextFit = require("../src/ReplicatedStorage/Shared/TextFit")

local UI = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau"
local FIT = "src/ReplicatedStorage/Shared/TextFit.luau"

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

local function count(source: string, needle: string): number
	local found = 0
	local at = 1
	while true do
		local nextAt = string.find(source, needle, at, true)
		if nextAt == nil then
			return found
		end
		found += 1
		at = nextAt + #needle
	end
end

local function growsFromPx(block: string)
	expect(string.find(block, 'SetAttribute("BaseHeight"', 1, true) ~= nil).toBeTrue()
	expect(string.find(block, "AutomaticSize = Enum.AutomaticSize.Y", 1, true)).toBeNil()
end

describe("Legacy panel row height", function()
	it("lets stats grow and drops the fixed 36 or 52 in setProfile", function()
		local source = fs.readFile(UI)
		local stats = between(source, 'local stats = new("TextLabel"', "local pityLabel")
		expect(string.find(stats, "AutomaticSize = Enum.AutomaticSize.Y", 1, true) ~= nil).toBeTrue()
		expect(string.find(stats, "TextWrapped = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(stats, 'SetAttribute("BaseHeight"', 1, true)).toBeNil()

		local profile =
			between(source, "function controller.setProfile", "function controller.setPolicy")
		expect(string.find(profile, "UDim2.new(1, 0, 0, 36)", 1, true)).toBeNil()
		expect(string.find(profile, "UDim2.new(1, 0, 0, 52)", 1, true)).toBeNil()
		expect(string.find(profile, "then 36 else 52", 1, true)).toBeNil()
		expect(string.find(profile, "stats.Size", 1, true)).toBeNil()
		expect(string.find(profile, "paid", 1, true)).toBeNil()
	end)

	it("sizes the realm line and the odds lines from TextFit.px", function()
		local source = fs.readFile(UI)
		local walk =
			between(source, "local function fitLegacyText()", "local function paintChips()")
		expect(string.find(walk, 'GetAttribute("BaseHeight")', 1, true) ~= nil).toBeTrue()
		expect(string.find(walk, "TextFit.px(rowBase, bannerScale)", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(walk, "UDim2.new(1, 0, 0, TextFit.px(rowBase, bannerScale))", 1, true)
				~= nil
		).toBeTrue()
		expect(string.find(walk, "paid", 1, true)).toBeNil()
		expect(count(source, "BaseHeight")).toEqual(6)

		local realms =
			between(source, "local function paintRealms()", "local function highestUnlocked")
		local realmName = between(realms, 'local label = new("TextLabel"', 'new("UIListLayout"')
		expect(string.find(realmName, 'label.Name = "RealmName"', 1, true) ~= nil).toBeTrue()
		expect(string.find(realmName, 'SetAttribute("BaseHeight", 18)', 1, true) ~= nil).toBeTrue()
		growsFromPx(realmName)
		expect(string.find(realms, "chip.Size = UDim2.fromOffset(0, 44)", 1, true) ~= nil).toBeTrue()
		expect(string.find(realms, "chip.AutomaticSize = Enum.AutomaticSize.X", 1, true) ~= nil).toBeTrue()
		expect(string.find(realms, "chip.AutomaticSize = Enum.AutomaticSize.Y", 1, true)).toBeNil()
		expect(string.find(realms, 'SetAttribute("BaseHeight"', 1, true) ~= nil).toBeTrue()
		expect(count(realms, 'SetAttribute("BaseHeight"')).toEqual(1)

		local nextRealm = between(source, 'Name = "NextRealm"', "local crack")
		expect(string.find(nextRealm, "TextTruncate = Enum.TextTruncate.AtEnd", 1, true) ~= nil).toBeTrue()
		expect(string.find(nextRealm, 'SetAttribute("BaseHeight", 16)', 1, true) ~= nil).toBeTrue()
		growsFromPx(nextRealm)

		local odds = between(source, "function controller.setOdds", "function controller.showRoll")
		local heading = between(odds, "local function heading", "local function row")
		local row = between(odds, "local function row", "local areaName")
		expect(string.find(heading, 'label.Name = "Heading"', 1, true) ~= nil).toBeTrue()
		expect(string.find(heading, 'SetAttribute("BaseHeight", 16)', 1, true) ~= nil).toBeTrue()
		growsFromPx(heading)
		expect(string.find(row, "TextTruncate = Enum.TextTruncate.AtEnd", 1, true) ~= nil).toBeTrue()
		expect(string.find(row, 'label.Name = "OddsRow"', 1, true) ~= nil).toBeTrue()
		expect(string.find(row, 'SetAttribute("BaseHeight", 16)', 1, true) ~= nil).toBeTrue()
		growsFromPx(row)
		expect(string.find(heading, "paid", 1, true)).toBeNil()
		expect(string.find(row, "paid", 1, true)).toBeNil()

		-- Scale 1.4 text has to fit inside the design height once TextFit scales both.
		expect(TextFit.px(18, 1.4) >= TextFit.px(14, 1.4)).toBeTrue()
		expect(TextFit.px(16, 1.4) >= TextFit.px(12, 1.4)).toBeTrue()
		expect(TextFit.px(16, 1.4) >= TextFit.px(13, 1.4)).toBeTrue()
	end)

	it("leaves the salvage craft row at 52", function()
		local source = fs.readFile(UI)
		local salvage =
			between(source, "for index, item in ipairs(salvageRows)", "local materialOrder")
		expect(string.find(salvage, "UDim2.new(1, 0, 0, 52)", 1, true) ~= nil).toBeTrue()
		expect(string.find(salvage, "BaseHeight", 1, true)).toBeNil()
		expect(string.find(salvage, "AutomaticSize", 1, true)).toBeNil()
		expect(count(source, "UDim2.new(1, 0, 0, 52)")).toEqual(1)
	end)

	it("keeps the banner on BannerFit and the spin off these rows", function()
		local source = fs.readFile(UI)
		expect(string.find(source, "ShardfallBanner", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "BannerFit", 1, true) ~= nil).toBeTrue()
		local walk =
			between(source, "local function fitLegacyText()", "local function paintChips()")
		expect(string.find(walk, "ShardfallBanner", 1, true)).toBeNil()
		expect(string.find(walk, "BannerFit", 1, true)).toBeNil()
		expect(string.find(walk, "screen:GetDescendants()", 1, true) ~= nil).toBeTrue()

		local spin =
			between(source, "RunService.RenderStepped:Connect(function()", "local busy = false")
		expect(string.find(spin, "TextFit", 1, true)).toBeNil()
		expect(string.find(spin, "fitLegacyText", 1, true)).toBeNil()
		expect(string.find(spin, "BaseHeight", 1, true)).toBeNil()
		expect(string.find(spin, "AutomaticSize", 1, true)).toBeNil()
		expect(string.find(spin, "stats.Size", 1, true)).toBeNil()
		expect(string.find(spin, "RealmName", 1, true)).toBeNil()
		expect(string.find(spin, "NextRealm", 1, true)).toBeNil()
		expect(string.find(spin, "OddsRow", 1, true)).toBeNil()
		expect(string.find(spin, "gradient.Rotation", 1, true) ~= nil).toBeTrue()
	end)

	it("leaves TextFit.px(16, 1.4) at 22", function()
		expect(TextFit.px(16, 1.4)).toEqual(22)
		local fit = fs.readFile(FIT)
		expect(
			string.find(
				fit,
				"function TextFit.px(base: any, scale: any, _extra: any?): number",
				1,
				true
			) ~= nil
		).toBeTrue()
		expect(
			string.find(
				fit,
				"return math.max(UiTheme.MIN_TEXT, math.floor(size * factor + 0.5))",
				1,
				true
			) ~= nil
		).toBeTrue()
		expect(string.find(fit, "BaseHeight", 1, true)).toBeNil()
		expect(string.find(fit, "AutomaticSize", 1, true)).toBeNil()
		expect(string.find(fit, "RealmName", 1, true)).toBeNil()
		expect(string.find(fit, "fitLegacyText", 1, true)).toBeNil()
	end)

	it("does not let paid change a row height", function()
		expect(TextFit.px(16, 1.4, { paid = true })).toEqual(22)
		expect(TextFit.px(16, 1.4, { paid = true })).toEqual(TextFit.px(16, 1.4))
		expect(TextFit.px(18, 1.4, { paid = true })).toEqual(TextFit.px(18, 1.4))
		expect(TextFit.px(16, 1, { paid = true })).toEqual(16)
		expect(TextFit.px(18, 1, { paid = true })).toEqual(18)
		local source = fs.readFile(UI)
		local walk =
			between(source, "local function fitLegacyText()", "local function paintChips()")
		expect(string.find(walk, "paid", 1, true)).toBeNil()
		local stats = between(source, 'local stats = new("TextLabel"', "local pityLabel")
		expect(string.find(stats, "paid", 1, true)).toBeNil()
	end)
end)
