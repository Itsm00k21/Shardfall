--!strict

--[[
	Ui does not run under Lune. The source lock reads the legacy panel
	and checks the text walk, the Shardfall name, and that the
	RenderStepped connection does not call TextFit.
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

local function calledAtEnd(body: string)
	local trimmed = string.gsub(body, "%s+$", "")
	expect(string.match(trimmed, "fitLegacyText%(%)%s+end$") ~= nil).toBeTrue()
end

describe("Legacy panel text scale", function()
	it("keeps TextFit.px(16, 1.4) at 22", function()
		expect(TextFit.px(16, 1.4)).toEqual(22)
		expect(TextFit.px(16, 1.4, { paid = true })).toEqual(22)
		local fit = fs.readFile(FIT)
		expect(string.find(fit, "function TextFit.px", 1, true) ~= nil).toBeTrue()
		expect(string.find(fit, "fitLegacyText", 1, true)).toBeNil()
		expect(string.find(fit, "bannerScale", 1, true)).toBeNil()
		expect(string.find(fit, "1.4", 1, true)).toBeNil()
	end)

	it("walks the Shardfall panel and leaves the spin alone", function()
		local source = fs.readFile(UI)
		expect(string.find(source, "TextFit.px", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "ShardfallBanner", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "BannerFit", 1, true) ~= nil).toBeTrue()
		expect(count(source, "GetDescendants")).toEqual(1)
		expect(string.find(source, "screen:GetDescendants()", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "bannerGui:GetDescendants", 1, true)).toBeNil()

		local walk =
			between(source, "local function fitLegacyText()", "local function paintChips()")
		expect(string.find(walk, "Shardfall", 1, true) ~= nil).toBeTrue()
		expect(string.find(walk, "GetDescendants", 1, true) ~= nil).toBeTrue()
		expect(string.find(walk, "SkipTextScale", 1, true) ~= nil).toBeTrue()
		expect(string.find(walk, "BaseText", 1, true) ~= nil).toBeTrue()
		expect(string.find(walk, "TextFit.px", 1, true) ~= nil).toBeTrue()
		expect(string.find(walk, "bannerScale", 1, true) ~= nil).toBeTrue()
		expect(string.find(walk, "ShardfallBanner", 1, true)).toBeNil()
		expect(string.find(walk, "BannerFit", 1, true)).toBeNil()

		local spin =
			between(source, "RunService.RenderStepped:Connect(function()", "local busy = false")
		expect(string.find(spin, "TextFit", 1, true)).toBeNil()
		expect(string.find(spin, "fitLegacyText", 1, true)).toBeNil()
		expect(string.find(spin, "gradient.Rotation", 1, true) ~= nil).toBeTrue()
	end)

	it("fits at the end of the five paints", function()
		local source = fs.readFile(UI)
		-- The definition line contains this text, plus one call in each of the five paints.
		expect(count(source, "fitLegacyText()")).toEqual(6)
		calledAtEnd(between(source, "local function paintChips()", "local realmRow"))
		calledAtEnd(
			between(
				source,
				"local function renderPity(profile: any)",
				"local function paintRealms()"
			)
		)
		calledAtEnd(
			between(source, "local function paintRealms()", "local function highestUnlocked")
		)
		calledAtEnd(
			between(
				source,
				"local function renderCraft(profile: any)",
				"local function showForgeTab"
			)
		)
		local profile =
			between(source, "function controller.setProfile", "function controller.setPolicy")
		calledAtEnd(profile)
		local scaleAt = string.find(profile, "bannerScale = nextScale", 1, true)
		local fitAt = string.find(profile, "fitLegacyText()", 1, true)
		expect(scaleAt ~= nil).toBeTrue()
		expect(fitAt ~= nil).toBeTrue()
		expect((scaleAt :: number) < (fitAt :: number)).toBeTrue()
		expect(string.find(profile, "applyBannerFit()", 1, true) ~= nil).toBeTrue()
	end)
end)
