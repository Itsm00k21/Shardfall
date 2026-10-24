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

local function offToast(box: { x: number, y: number, w: number, h: number }, vx: number)
	local toast = HudLayout.toast(vx, UiTheme.safeMargin())
	expect(HudLayout.overlaps(box, toast)).toEqual(false)
end

local function railBox(viewportY: number)
	local rail = HudLayout.railFit(
		viewportY,
		UiTheme.safeMargin(),
		HudLayout.RAIL_COUNT,
		UiTheme.TAP,
		UiTheme.TOUCH
	)
	return { x = rail.x, y = rail.y, w = rail.w, h = rail.h }
end

local function toastHost(viewportX: number)
	return HudLayout.toastHost(viewportX, UiTheme.safeMargin())
end

local function equipPrompt(viewportX: number)
	return HudLayout.equipPrompt(viewportX, UiTheme.safeMargin())
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
			offToast(box, vx)
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
			offToast(box, vx)
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

	it("shortens a line that would pass the bottom of the viewport", function()
		local box = BannerFit.fit(390, 844, 40)
		local textSize = math.max(UiTheme.MIN_TEXT, math.floor(16 * 40 + 0.5))
		local line = textSize + UiTheme.PAD * 2
		expect(box.textSize).toEqual(textSize)
		expect(line > 844 - box.y).toBeTrue()
		expect(box.h < line).toBeTrue()
		expect(box.y + box.h).toEqual(844)
		inside(box, 390, 844)
		offToast(box, 390)
		local margin = UiTheme.safeMargin()
		expect(HudLayout.overlaps(box, HudLayout.portrait(margin))).toEqual(false)
		expect(HudLayout.overlaps(box, HudLayout.health(margin))).toEqual(false)
		expect(HudLayout.overlaps(box, railBox(844))).toEqual(false)
	end)

	it("clears the portrait, the HP bar, the rail, the chips, and the hub close", function()
		expect(HudLayout.RAIL_COUNT).toEqual(6)
		local margin = UiTheme.safeMargin()
		for _, view in ipairs(PHONES) do
			local vx = view[1]
			local vy = view[2]
			for _, scale in ipairs({ 1, 1.4 }) do
				local box = BannerFit.fit(vx, vy, scale)
				expect(box.h).toEqual(box.textSize + UiTheme.PAD * 2)
				expect(HudLayout.overlaps(box, HudLayout.portrait(margin))).toEqual(false)
				expect(HudLayout.overlaps(box, HudLayout.health(margin))).toEqual(false)
				expect(HudLayout.overlaps(box, railBox(vy))).toEqual(false)
				expect(HudLayout.overlaps(box, HudLayout.toast(vx, margin))).toEqual(false)
				expect(HudLayout.overlaps(box, toastHost(vx))).toEqual(false)
				expect(HudLayout.overlaps(box, equipPrompt(vx))).toEqual(false)
				expect(HudLayout.overlaps(box, HudLayout.pills(vx, margin))).toEqual(false)
				local hub = HudLayout.hub(vx, vy, margin)
				local close = {
					x = hub.x + hub.w - UiTheme.PAD - UiTheme.TOUCH,
					y = hub.y + UiTheme.PAD,
					w = UiTheme.TOUCH,
					h = UiTheme.TOUCH,
				}
				expect(HudLayout.overlaps(box, close)).toEqual(false)
				inside(box, vx, vy)
				expect(box.x + box.w).toEqual(vx - UiTheme.PAD)
			end
		end
		local health = HudLayout.health(margin)
		for _, view in ipairs({ { 844, 390 }, { 800, 380 } }) do
			for _, scale in ipairs({ 1, 1.4 }) do
				local box = BannerFit.fit(view[1], view[2], scale)
				expect(box.y).toEqual(UiTheme.PAD)
				expect(box.x).toEqual(health.x + health.w + UiTheme.PAD)
			end
		end
		for _, scale in ipairs({ 1, 1.4 }) do
			local box = BannerFit.fit(390, 844, scale)
			local prompt = equipPrompt(390)
			local rail = railBox(844)
			expect(box.y).toEqual(prompt.y + prompt.h + UiTheme.PAD)
			expect(box.x).toEqual(rail.x + rail.w + UiTheme.PAD)
		end
	end)

	it("keeps setStatus on the same string and the same timer", function()
		local ui = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
		local showAt = string.find(ui, "local function showBanner", 1, true)
		expect(showAt ~= nil).toBeTrue()
		local panelAt = string.find(ui, 'Name = "Panel"', showAt :: number, true)
		expect(panelAt ~= nil).toBeTrue()
		local show = string.sub(ui, showAt :: number, (panelAt :: number) - 1)
		expect(string.find(show, 'string.match(text, "^%s*(.-)%s*$")', 1, true) ~= nil).toBeTrue()
		expect(string.find(show, "banner.Text = shown", 1, true) ~= nil).toBeTrue()
		expect(string.find(show, 'banner.Visible = shown ~= ""', 1, true) ~= nil).toBeTrue()
		expect(string.find(show, 'if shown == "" then', 1, true) ~= nil).toBeTrue()
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
		local tokenAt = string.find(ui, "local bannerToken = 0", bannerAt :: number, true)
		expect(tokenAt ~= nil).toBeTrue()
		local banner = string.sub(ui, bannerAt :: number, (tokenAt :: number) - 1)
		expect(string.find(banner, "IgnoreGuiInset = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(banner, "IgnoreGuiInset = true", 1, true)).toBeNil()
		expect(string.find(banner, "CoreUISafeInsets", 1, true) ~= nil).toBeTrue()
		expect(string.find(banner, "TextScaled = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(banner, "TextTruncate = Enum.TextTruncate.AtEnd", 1, true) ~= nil).toBeTrue()
		expect(string.find(ui, "settings.access.textScale", 1, true) ~= nil).toBeTrue()
		expect(string.find(ui, "BannerFit.fit", 1, true) ~= nil).toBeTrue()
		expect(string.find(ui, "banner.TextSize = box.textSize", 1, true) ~= nil).toBeTrue()
	end)

	it("treats a missing, zero, or fractional viewport as a safe rect", function()
		local empty = BannerFit.fit(0, 0, 1)
		inside(empty, 0, 0)
		expect(empty.w).toEqual(0)
		expect(empty.h).toEqual(0)
		expect(empty.textSize).toEqual(16)
		expect(BannerFit.fit(nil, nil, nil)).toEqual(empty)
		expect(BannerFit.fit(0 / 0, math.huge, 1)).toEqual(empty)
		expect(BannerFit.fit(-20, -5, 1)).toEqual(empty)
		local odd = BannerFit.fit(390.9, 844.2, 1)
		expect(odd).toEqual(BannerFit.fit(390, 844, 1))
		inside(odd, 390, 844)
		offToast(odd, 390)
	end)
end)
