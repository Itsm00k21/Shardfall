--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local BannerFit = require("../src/ReplicatedStorage/Shared/BannerFit")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local ShellLayout = require("../src/ReplicatedStorage/Shared/ShellLayout")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

local PHONES = {
	{ 390, 844 },
	{ 844, 390 },
	{ 800, 380 },
}

local function inside(box: { x: number, y: number, w: number, h: number }, vx: number, vy: number)
	expect(box.x >= 0).toBeTrue()
	expect(box.y >= 0).toBeTrue()
	expect(box.w >= 0).toBeTrue()
	expect(box.h >= 0).toBeTrue()
	expect(box.x + box.w <= vx).toBeTrue()
	expect(box.y + box.h <= vy).toBeTrue()
end

local function aboveToast(box: { x: number, y: number, w: number, h: number }, vx: number)
	local toast = HudLayout.toast(vx, UiTheme.safeMargin())
	expect(box.y + box.h <= toast.y).toBeTrue()
	expect(HudLayout.overlaps(box, toast)).toEqual(false)
end

describe("BannerFit", function()
	it("keeps 16px inside the phone viewports at scale 1", function()
		for _, view in ipairs(PHONES) do
			local vx = view[1]
			local vy = view[2]
			local box = BannerFit.fit(vx, vy, 1)
			expect(box.textSize).toEqual(16)
			expect(box.h).toEqual(16 + UiTheme.PAD * 2)
			expect(box.h >= box.textSize).toBeTrue()
			inside(box, vx, vy)
			aboveToast(box, vx)
		end
		local first = BannerFit.fit(390, 844, 1)
		local second = BannerFit.fit(390, 844, 1)
		expect(first).toEqual(second)
		expect(rawequal(first, second)).toEqual(false)
	end)

	it("paints 22px at scale 1.4 and the height fits that line", function()
		for _, view in ipairs(PHONES) do
			local vx = view[1]
			local vy = view[2]
			local box = BannerFit.fit(vx, vy, 1.4)
			expect(box.textSize).toEqual(22)
			expect(box.textSize).toEqual(math.max(UiTheme.MIN_TEXT, math.floor(16 * 1.4 + 0.5)))
			expect(box.h).toEqual(box.textSize + UiTheme.PAD * 2)
			expect(box.h >= box.textSize).toBeTrue()
			inside(box, vx, vy)
			aboveToast(box, vx)
		end
	end)

	it("treats a missing or bad scale as 1", function()
		local sample = BannerFit.fit(844, 390, 1)
		expect(sample.textSize).toEqual(16)
		expect(BannerFit.fit(844, 390, nil)).toEqual(sample)
		local bad = { "big", 0, -1, 0 / 0, math.huge, -math.huge }
		for _, scale in ipairs(bad) do
			local box = BannerFit.fit(844, 390, scale)
			expect(box.textSize).toEqual(16)
			expect(box).toEqual(sample)
		end
		local again = BannerFit.fit(800, 380, 1)
		expect(BannerFit.fit(800, 380).textSize).toEqual(16)
		expect(again.h).toEqual(16 + UiTheme.PAD * 2)
	end)

	it("ignores paid, a product id, Robux, cost, and skip", function()
		local offer = {
			paid = true,
			productId = "banner_skip",
			robux = 0,
			cost = 0,
			skip = false,
		}
		local plain = BannerFit.fit(390, 844, 1)
		local paid = BannerFit.fit(390, 844, 1, offer)
		expect(paid).toEqual(plain)
		expect(paid.textSize).toEqual(16)
		expect(offer.paid).toEqual(true)
		expect(offer.productId).toEqual("banner_skip")
		expect(offer.robux).toEqual(0)
		expect(offer.cost).toEqual(0)
		expect(offer.skip).toEqual(false)
		local asScale = {
			paid = true,
			productId = "banner_skip",
			robux = 25,
			cost = 10,
			skip = true,
		}
		expect(BannerFit.fit(844, 390, asScale)).toEqual(BannerFit.fit(844, 390, 1))
		expect(asScale.robux).toEqual(25)
		expect(asScale.skip).toEqual(true)
	end)

	it("shortens a tall line so the bottom stops above the toast", function()
		local box = BannerFit.fit(390, 844, 10)
		local toast = HudLayout.toast(390, UiTheme.safeMargin())
		expect(box.textSize).toEqual(math.max(UiTheme.MIN_TEXT, math.floor(16 * 10 + 0.5)))
		expect(box.h < box.textSize + UiTheme.PAD * 2).toBeTrue()
		expect(box.y + box.h <= toast.y).toBeTrue()
		inside(box, 390, 844)
		aboveToast(box, 390)
	end)

	it("keeps setStatus on the same string and the same timer", function()
		local ui = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
		local showAt = string.find(ui, "local function showBanner", 1, true)
		expect(showAt ~= nil).toBeTrue()
		local panelAt = string.find(ui, 'Name = "Panel"', showAt :: number, true)
		expect(panelAt ~= nil).toBeTrue()
		local show = string.sub(ui, showAt :: number, (panelAt :: number) - 1)
		expect(string.find(show, "banner.Text = text", 1, true) ~= nil).toBeTrue()
		expect(string.find(show, 'banner.Visible = text ~= ""', 1, true) ~= nil).toBeTrue()
		expect(string.find(show, "task.delay(ShellLayout.BANNER_SECONDS", 1, true) ~= nil).toBeTrue()
		expect(string.find(show, "COLORS.gold", 1, true) ~= nil).toBeTrue()
		expect(string.find(show, "COLORS.danger", 1, true) ~= nil).toBeTrue()
		expect(string.find(show, "COLORS.ok", 1, true) ~= nil).toBeTrue()
		expect(string.find(show, "applyBannerFit()", 1, true) ~= nil).toBeTrue()

		local statusAt = string.find(ui, "function controller.setStatus", 1, true)
		expect(statusAt ~= nil).toBeTrue()
		local tonicAt = string.find(ui, "local function tonicCount", statusAt :: number, true)
		expect(tonicAt ~= nil).toBeTrue()
		local status = string.sub(ui, statusAt :: number, (tonicAt :: number) - 1)
		expect(string.find(status, "status.Text = text", 1, true) ~= nil).toBeTrue()
		expect(string.find(status, "showBanner(text, kind, hold)", 1, true) ~= nil).toBeTrue()
		expect(string.find(status, "task.delay(ShellLayout.BANNER_SECONDS", 1, true) ~= nil).toBeTrue()
		expect(ShellLayout.BANNER_SECONDS).toEqual(3.5)

		local bannerAt = string.find(ui, 'Name = "ShardfallBanner"', 1, true)
		expect(bannerAt ~= nil).toBeTrue()
		local banner = string.sub(ui, bannerAt :: number, (bannerAt :: number) + 500)
		expect(string.find(banner, "IgnoreGuiInset = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(banner, "IgnoreGuiInset = true", 1, true)).toBeNil()
		expect(string.find(ui, "settings.access.textScale", 1, true) ~= nil).toBeTrue()
		expect(string.find(ui, "BannerFit.fit", 1, true) ~= nil).toBeTrue()
	end)
end)
