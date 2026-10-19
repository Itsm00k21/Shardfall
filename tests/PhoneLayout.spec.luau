--!strict

--[[
	Phone layout. The rects are the ones the HUD already places.
	A pair fails when the boxes share a pixel. Touching edges pass.
	A zero-size rect is skipped.

	Counters, the tracker, the action bar, the bag sheet, and the
	echo chip stay inside UiTheme.safeMargin. The gold banner uses
	BannerFit's 8px lane, so it may sit at y = 8 and only has to
	stay inside the viewport.

	The equip prompt and the heavy chip may share the short
	landscape bar. That pair is not asserted here.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local BannerFit = require("../src/ReplicatedStorage/Shared/BannerFit")
local EchoChip = require("../src/ReplicatedStorage/Shared/EchoChip")
local HeavyChip = require("../src/ReplicatedStorage/Shared/HeavyChip")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local ShellLayout = require("../src/ReplicatedStorage/Shared/ShellLayout")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

type Rect = { x: number, y: number, w: number, h: number }
type Named = { name: string, box: Rect, inset: number }

local VIEWS = {
	{ 1280, 720 },
	{ 844, 390 },
	{ 390, 844 },
	{ 800, 380 },
}

local FILTERS = { "Rarity  Legendary", "Type  weapon", "New  On", "Sort  power" }

local function loadTracker()
	local layoutToken = { Name = "HudLayout" }
	local bannerToken = { Name = "BannerFit" }
	local themeToken = { Name = "UiTheme" }
	local shared = {
		WaitForChild = function(_self, name)
			if name == "HudLayout" then
				return layoutToken
			end
			if name == "BannerFit" then
				return bannerToken
			end
			if name == "UiTheme" then
				return themeToken
			end
			error("missing " .. tostring(name), 2)
		end,
	}
	local replicated = {
		WaitForChild = function(_self, name)
			if name == "Shared" then
				return shared
			end
			error("missing " .. tostring(name), 2)
		end,
	}
	local source =
		fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau")
	local bytecode = luau.compile(source, { debugLevel = 2 })
	local chunk = luau.load(bytecode, {
		debugName = "StarterGoalHud",
		environment = {
			assert = assert,
			error = error,
			ipairs = ipairs,
			next = next,
			pairs = pairs,
			pcall = pcall,
			print = print,
			select = select,
			tonumber = tonumber,
			tostring = tostring,
			type = type,
			typeof = typeof,
			warn = warn,
			math = math,
			string = string,
			table = table,
			require = function(module)
				if module == layoutToken then
					return HudLayout
				end
				if module == bannerToken then
					return BannerFit
				end
				if module == themeToken then
					return UiTheme
				end
				error("unexpected require", 2)
			end,
			game = {
				GetService = function(_game, name)
					if name == "ReplicatedStorage" then
						return replicated
					end
					error("no service " .. tostring(name), 2)
				end,
			},
		},
	})
	return chunk()
end

local StarterGoalHud = loadTracker()

local function show(box: Rect): string
	return string.format("(%d,%d,%d,%d)", box.x, box.y, box.w, box.h)
end

local function live(box: Rect): boolean
	return box.w > 0 and box.h > 0
end

local function hits(a: Rect, b: Rect): boolean
	if not live(a) or not live(b) then
		return false
	end
	return HudLayout.overlaps(a, b)
end

local function contains(outer: Rect, inner: Rect): boolean
	if not live(inner) then
		return true
	end
	if inner.x < outer.x or inner.y < outer.y then
		return false
	end
	if inner.x + inner.w > outer.x + outer.w then
		return false
	end
	if inner.y + inner.h > outer.y + outer.h then
		return false
	end
	return true
end

local function inside(box: Rect, vx: number, vy: number, inset: number): boolean
	if not live(box) then
		return true
	end
	if box.x < inset or box.y < inset then
		return false
	end
	if box.x + box.w > vx - inset + 0.01 then
		return false
	end
	if box.y + box.h > vy - inset + 0.01 then
		return false
	end
	return true
end

local function assertClear(rows: { Named })
	for left = 1, #rows do
		for right = left + 1, #rows do
			local a = rows[left]
			local b = rows[right]
			if hits(a.box, b.box) then
				error(a.name .. " overlaps " .. b.name .. " " .. show(a.box) .. " " .. show(b.box), 2)
			end
		end
	end
end

local function assertInsets(rows: { Named }, vx: number, vy: number)
	for _, row in ipairs(rows) do
		if not inside(row.box, vx, vy, row.inset) then
			error(row.name .. " leaves inset " .. tostring(row.inset) .. " " .. show(row.box), 2)
		end
	end
end

local function add(rows: { Named }, name: string, box: Rect, inset: number)
	table.insert(rows, { name = name, box = box, inset = inset })
end

describe("PhoneLayout", function()
	it("keeps the shell, banner, tracker, and bar apart", function()
		local margin = UiTheme.safeMargin()
		expect(margin).toEqual(16)
		for _, view in ipairs(VIEWS) do
			local vx = view[1]
			local vy = view[2]
			local phone = HudLayout.breakpoint(vx, vy) == "phone"
			local place = ActionSlots.placement(vx, vy, phone)
			expect(place.columns).toEqual(if phone then 4 else 8)
			expect(place.rows).toEqual(if phone then 2 else 1)
			local bar = HudLayout.actionCluster(vx, vy)
			expect(bar.x).toEqual(place.x)
			expect(bar.y).toEqual(place.y)
			expect(bar.w).toEqual(place.w)
			expect(bar.h).toEqual(place.h)

			local scales = {
				{ 1, 14 },
				{ 1.4, 20 },
			}
			for _, scale in ipairs(scales) do
				local rows: { Named } = {}
				add(rows, "health", HudLayout.health(margin, vx), margin)
				add(rows, "pills", HudLayout.pills(vx, margin), margin)
				add(rows, "banner", BannerFit.fit(vx, vy, scale[1]), 0)
				add(rows, "echo", EchoChip.place(vx, vy), margin)
				add(rows, "toast", HudLayout.toastHost(vx, margin), margin)
				add(rows, "tracker", StarterGoalHud.place(vx, vy, 3, scale[2]), margin)
				add(rows, "bar", bar, margin)
				if phone then
					add(rows, "heavy", HeavyChip.place(vx, vy), margin)
				end
				assertClear(rows)
				assertInsets(rows, vx, vy)
			end

			local tracker = StarterGoalHud.place(vx, vy, 3, 14)
			local grown = StarterGoalHud.place(vx, vy, 3, 20)
			expect(tracker.collapsed == true).toBeFalse()
			expect(grown.collapsed == true).toBeFalse()
			expect(grown.h).toEqual(3 * StarterGoalHud.lineHeight(20) + 8)
		end

		local desktop = StarterGoalHud.place(1280, 720, 3, 14)
		expect(desktop.x).toEqual(88)
		expect(desktop.y).toEqual(80)
	end)

	it("keeps the bag sheet off the action bar", function()
		local margin = UiTheme.safeMargin()
		for _, view in ipairs(VIEWS) do
			local vx = view[1]
			local vy = view[2]
			local phone = HudLayout.breakpoint(vx, vy) == "phone"
			local size = ShellLayout.inventory(vx, vy, phone)
			local pet = ShellLayout.petRect()
			local bag: Rect = {
				x = if phone then margin else 16,
				y = if phone then margin else pet.y + pet.h + 8,
				w = size.w,
				h = size.h,
			}
			local bar = HudLayout.actionCluster(vx, vy)
			expect(hits(bag, bar)).toBeFalse()
			expect(inside(bag, vx, vy, margin)).toBeTrue()
			expect(bag.w).toBeGreaterThan(0)
			expect(bag.h).toBeGreaterThan(0)

			local chrome = HudLayout.bagChrome(bag.w, bag.h)
			local panel = { x = 0, y = 0, w = bag.w, h = bag.h }
			local parts = { chrome.header, chrome.tabs, chrome.filters, chrome.body }
			for index, part in ipairs(parts) do
				expect(contains(panel, part)).toBeTrue()
				for other = index + 1, #parts do
					expect(hits(part, parts[other])).toBeFalse()
				end
			end

			local grid = HudLayout.cardGrid(chrome.body.w, chrome.body.h, 8)
			expect(grid.cellH).toBeGreaterThan(227)
			local card = HudLayout.bagCard(grid.cellW, grid.cellH)
			local cell = { x = 0, y = 0, w = grid.cellW, h = grid.cellH }
			local innards = { card.icon, card.name, card.tip, card.lock, card.equip, card.badge }
			for index, part in ipairs(innards) do
				expect(contains(cell, part)).toBeTrue()
				for other = index + 1, #innards do
					expect(hits(part, innards[other])).toBeFalse()
				end
			end
		end
	end)

	it("scrolls the bag filter row on a 390 px phone instead of clipping it", function()
		local labels = { "Rarity  All", "Type  All", "New", "Sort  power" }
		-- 390x844 hub body is 264 wide; the list row is 248 after padding.
		local bar = HudLayout.filterBar(248, labels)
		expect(bar.scrolls).toBeTrue()
		expect(bar.canvasW).toEqual(HudLayout.filterRow(labels).width)
		expect(bar.height).toEqual(UiTheme.TOUCH + HudLayout.FILTER_BAR_GAP)
		-- Every chip, New included, sits fully inside the scroll canvas.
		for _, chip in ipairs(HudLayout.filterRow(labels).chips) do
			expect(chip.x + chip.w <= bar.canvasW).toBeTrue()
			expect(chip.h + 4 <= bar.height).toBeTrue()
		end
		expect(HudLayout.filterBar(900, labels).scrolls).toBeFalse()
		expect(HudLayout.filterBar(0 / 0, labels).scrolls).toBeTrue()
		local hub = require("@lune/fs").readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		expect(string.find(hub, "UiTheme.TOUCH + HudLayout.FILTER_BAR_GAP", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Enum.ScrollingDirection.X", 1, true) ~= nil).toBeTrue()
	end)

	it("keeps bag filter chips and inventory marks apart", function()
		local row = HudLayout.filterRow(FILTERS)
		expect(#row.chips).toEqual(#FILTERS)
		local cursor = 0
		for index, chip in ipairs(row.chips) do
			expect(chip.w).toEqual(HudLayout.chipWidth(FILTERS[index]))
			expect(chip.w >= UiTheme.TOUCH).toBeTrue()
			expect(chip.x).toEqual(cursor)
			expect(chip.h).toEqual(UiTheme.TOUCH)
			cursor += chip.w + UiTheme.PAD
			for other = index + 1, #row.chips do
				expect(hits(chip, row.chips[other])).toBeFalse()
			end
		end

		local sizes = {
			{ 100, 120 },
			{ 112, 128 },
		}
		for _, size in ipairs(sizes) do
			local cell = { x = 0, y = 0, w = size[1], h = size[2] }
			local card = HudLayout.inventoryCard(size[1], size[2])
			expect(contains(cell, card.name)).toBeTrue()
			expect(contains(cell, card.marks)).toBeTrue()
			expect(hits(card.name, card.marks)).toBeFalse()
			expect(card.name.y + card.name.h <= card.marks.y).toBeTrue()
		end
	end)

	it("reads bag geometry from HudLayout", function()
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local bag =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/InventoryHud.luau")
		expect(string.find(hub, "HudLayout.bagCard", 1, true)).toBeGreaterThan(0)
		expect(string.find(hub, "HudLayout.chipWidth", 1, true)).toBeGreaterThan(0)
		expect(string.find(bag, "HudLayout.bagChrome", 1, true)).toBeGreaterThan(0)
		expect(string.find(bag, "HudLayout.inventoryCard", 1, true)).toBeGreaterThan(0)
	end)

	it("keeps the intro card and goal line off the counters and the bar", function()
		local margin = UiTheme.safeMargin()
		for _, view in ipairs(VIEWS) do
			local vx = view[1]
			local vy = view[2]
			local layout = HudLayout.onboard(vx, vy)
			local health = HudLayout.health(margin, vx)
			local pills = HudLayout.pills(vx, margin)
			local bar = HudLayout.actionCluster(vx, vy)
			local rows: { Named } = {}
			add(rows, "card", layout.card, 8)
			add(rows, "tracker", layout.tracker, 8)
			add(rows, "health", health, 0)
			add(rows, "pills", pills, 0)
			add(rows, "bar", bar, 0)
			assertClear(rows)
			expect(inside(layout.card, vx, vy, margin)).toBeTrue()
			expect(inside(layout.tracker, vx, vy, margin)).toBeTrue()
			local card = layout.card
			for _, button in ipairs({ layout.continueButton, layout.skip }) do
				expect(button.w >= UiTheme.TOUCH).toBeTrue()
				expect(button.h >= UiTheme.TOUCH).toBeTrue()
				expect(button.x >= 0 and button.y >= 0).toBeTrue()
				expect(button.x + button.w <= card.w).toBeTrue()
				expect(button.y + button.h <= card.h).toBeTrue()
			end
			expect(hits(layout.continueButton, layout.skip)).toBeFalse()
		end
		local onboard =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/OnboardHud.luau")
		expect(string.find(onboard, "HudLayout.onboard", 1, true) ~= nil).toBeTrue()
	end)
end)
