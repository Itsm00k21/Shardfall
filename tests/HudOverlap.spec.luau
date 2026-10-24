--!strict

--[[
	[Ghost] Oct 24 (Kevin's Studio shot): the Goals panel sat on the Dev
	button and the '›' chip covered its label. This spec places every
	HudLayout-placed element on each view, touch and mouse, and fails on
	any pairwise intersection that is not in ALLOWED below (each allowance
	says why). New HUD rects belong in rectsFor so they are checked too.
]]

local fs = require("@lune/fs")
local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local DevTools = require("../src/ReplicatedStorage/Shared/DevTools")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")
local GuiFake = require("./GuiFake")

type Rect = { x: number, y: number, w: number, h: number }
type Named = { name: string, rect: Rect }

local VIEWS = {
	{ 1024, 600 },
	{ 1024, 500 },
	{ 1280, 720 },
	{ 1366, 768 },
	{ 1512, 820 },
	{ 1920, 1080 },
	{ 390, 844 },
	{ 844, 390 },
}

local world = GuiFake.world()
local StarterGoalHud = world.load("StarterGoalHud")

local function rectsFor(vx: number, vy: number, touch: boolean): { Named }
	local margin = UiTheme.safeMargin()
	local list: { Named } = {}
	local function add(name: string, box: Rect?)
		if box ~= nil and box.w > 0 and box.h > 0 then
			table.insert(
				list,
				{ name = name, rect = { x = box.x, y = box.y, w = box.w, h = box.h } }
			)
		end
	end
	local column = HudLayout.topRight(vx, margin)
	local fit = HudLayout.railFit(vy, margin, HudLayout.RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH, vx)
	local onboard = HudLayout.onboard(vx, vy, touch, 4)
	local phone = HudLayout.breakpoint(vx, vy) == "phone"
	local spot = ActionSlots.placement(vx, vy, touch or phone or vx < 700 or vy < 500)
	local chrome = ActionSlots.chrome(spot)
	local devButton = DevTools.layout(vx, vy, margin)

	add("portrait", HudLayout.portrait(margin))
	add("health", HudLayout.health(margin, vx))
	add("pills", column.pills)
	add("dev", column.dev)
	add("devButton", devButton)
	add("rail", { x = fit.x, y = fit.y, w = fit.w, h = fit.h })
	if not touch then
		add("railTips", HudLayout.railTips(vx, vy, margin))
	end
	add("toastHost", HudLayout.toastHost(vx, margin))
	add("equipPrompt", HudLayout.equipPrompt(vx, margin))
	add("bar", { x = spot.x, y = spot.y, w = spot.w, h = spot.h })
	add("barTabs", {
		x = spot.x + chrome.strip.x,
		y = spot.y + chrome.strip.y,
		w = chrome.strip.w,
		h = chrome.strip.h,
	})
	add("introCard", onboard.card)
	if onboard.foldGoals then
		add("goalsTab", onboard.goalsTab)
	else
		add("goals", onboard.tracker)
	end
	add("character", HudLayout.characterZone(vx, vy))
	add("starterList", StarterGoalHud.place(vx, vy, 3))
	return list
end

local ONBOARD = { introCard = true, goals = true, goalsTab = true }
-- Only the onboarding pieces and the top-right column must stay off the
-- player's character; the older HUD was laid out before this box.
local OFF_CHARACTER = { introCard = true, goals = true, goalsTab = true, pills = true, dev = true }

local function allowed(a: string, b: string, vx: number, vy: number, touch: boolean): string?
	local function pair(x: string, y: string): boolean
		return (a == x and b == y) or (a == y and b == x)
	end
	local phone = HudLayout.breakpoint(vx, vy) == "phone"
	if pair("dev", "devButton") then
		return "same slot: DevTools.layout reads HudLayout.devButton"
	end
	if pair("bar", "barTabs") then
		return "the tab strip is part of the bar"
	end
	if a == "character" or b == "character" then
		local other = if a == "character" then b else a
		if not OFF_CHARACTER[other] then
			return "older HUD, not part of the character check"
		end
		return nil
	end
	if (a == "railTips" and not ONBOARD[b]) or (b == "railTips" and not ONBOARD[a]) then
		return "hover-only tip beside one rail button; draws over older HUD briefly"
	end
	if pair("equipPrompt", "starterList") then
		return "pre-existing: the starter list dodges the equip prompt on phones only (flagged for Havoc)"
	end
	if phone and (pair("equipPrompt", "bar") or pair("equipPrompt", "barTabs")) then
		return "pre-existing 4px phone overlap of the equip prompt and the bar (flagged for Havoc)"
	end
	if (a == "starterList" and ONBOARD[b]) or (b == "starterList" and ONBOARD[a]) then
		return "the starter list hides while the intro card or goals show"
	end
	if phone and (pair("introCard", "toastHost") or pair("introCard", "equipPrompt")) then
		return "phone: toasts are brief and draw under the card; no other room"
	end
	if phone and pair("introCard", "railTips") then
		return "phone-size mouse window: no room right of the tips"
	end
	return nil
end

local function key(name: string): string
	return name
end

describe("HUD overlap: every placed element on every view", function()
	it("finds no intersections outside the allowed list", function()
		local problems = {}
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			for _, touch in ipairs({ false, true }) do
				local rects = rectsFor(vx, vy, touch)
				for i = 1, #rects do
					for j = i + 1, #rects do
						local a, b = rects[i], rects[j]
						if
							HudLayout.overlaps(a.rect, b.rect)
							and allowed(key(a.name), key(b.name), vx, vy, touch) == nil
						then
							table.insert(
								problems,
								string.format(
									"%dx%d %s: %s (%d,%d,%d,%d) x %s (%d,%d,%d,%d)",
									vx,
									vy,
									if touch then "touch" else "mouse",
									a.name,
									a.rect.x,
									a.rect.y,
									a.rect.w,
									a.rect.h,
									b.name,
									b.rect.x,
									b.rect.y,
									b.rect.w,
									b.rect.h
								)
							)
						end
					end
				end
			end
		end
		if #problems > 0 then
			print(table.concat(problems, "\n"))
		end
		expect(#problems).toEqual(0)
	end)

	it("covers every element the brief names", function()
		local names = {}
		for _, item in ipairs(rectsFor(1512, 820, false)) do
			names[item.name] = true
		end
		for _, want in ipairs({
			"rail",
			"railTips",
			"pills",
			"dev",
			"goals",
			"introCard",
			"toastHost",
			"equipPrompt",
			"bar",
			"barTabs",
			"starterList",
			"character",
		}) do
			expect(names[want] == true).toBeTrue()
		end
	end)

	it("keeps everything on screen", function()
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			for _, touch in ipairs({ false, true }) do
				for _, item in ipairs(rectsFor(vx, vy, touch)) do
					local box = item.rect
					expect(box.x >= 0 and box.y >= 0).toBeTrue()
					expect(box.x + box.w <= vx and box.y + box.h <= vy).toBeTrue()
				end
			end
		end
	end)
end)

describe("Top-right column", function()
	it("stacks pills, then the Dev slot, then the goals, right-aligned", function()
		local margin = UiTheme.safeMargin()
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			local column = HudLayout.topRight(vx, margin)
			expect(column.dev.y >= column.pills.y + column.pills.h).toBeTrue()
			expect(column.dev.x + column.dev.w).toEqual(vx - margin)
			expect(column.bottom).toEqual(column.dev.y + column.dev.h)
			local onboard = HudLayout.onboard(vx, vy, false, 4)
			local goals = if onboard.foldGoals then onboard.goalsTab else onboard.tracker
			expect(goals.y >= column.bottom + 8).toBeTrue()
			expect(goals.x + goals.w).toEqual(vx - margin)
		end
	end)

	it("reserves the Dev slot on live too, and DevTools reads it", function()
		local button = DevTools.layout(1024, 600, 16)
		local dev = HudLayout.devButton(1024, 16)
		expect(button).toEqual(dev)
		local layout = HudLayout.onboard(1024, 600, false, 4)
		expect(HudLayout.overlaps(layout.tracker, dev)).toBeFalse()
		local source = fs.readFile("src/ReplicatedStorage/Shared/DevTools.luau")
		expect(string.find(source, "HudLayout.devButton(vx, margin)", 1, true) ~= nil).toBeTrue()
	end)

	it("keeps the goals collapse chip off the Dev label (Kevin's 1024x500 shot)", function()
		local layout = HudLayout.onboard(1024, 500, false, 4)
		local panel = layout.tracker
		local chip = { x = panel.x + panel.w - 6 - 28, y = panel.y + 4, w = 28, h = 24 }
		local dev = HudLayout.devButton(1024, 16)
		expect(HudLayout.overlaps(chip, dev)).toBeFalse()
		expect(HudLayout.overlaps(panel, dev)).toBeFalse()
		expect(layout.foldGoals).toEqual(false)
	end)
end)

describe("Hotbar tabs and empty slots", function()
	it("puts Lock and T in one strip flush on the slot row", function()
		for _, view in ipairs(VIEWS) do
			local phone = HudLayout.breakpoint(view[1], view[2]) == "phone"
			local spot = ActionSlots.placement(view[1], view[2], phone)
			local chrome = ActionSlots.chrome(spot)
			expect(chrome.strip.y + chrome.strip.h).toEqual(ActionSlots.TAB_BAND)
			expect(chrome.lock.x).toEqual(chrome.strip.x)
			expect(chrome.roll.x + chrome.roll.w).toEqual(chrome.strip.x + chrome.strip.w)
			expect(chrome.lock.y).toEqual(chrome.strip.y)
			expect(chrome.tip.y + chrome.tip.h <= chrome.strip.y).toBeTrue()
		end
	end)

	it("fades empty slots and keeps the next free one half bright", function()
		local bar = {
			locked = false,
			slots = {
				{ kind = "skill", id = "a" },
				{ kind = "skill", id = "b" },
				{ kind = "empty", id = "" },
				{ kind = "empty", id = "" },
				{ kind = "empty", id = "" },
				{ kind = "empty", id = "" },
				{ kind = "empty", id = "" },
				{ kind = "empty", id = "" },
			},
		}
		expect(ActionSlots.look(bar, 1)).toEqual("filled")
		expect(ActionSlots.look(bar, 3)).toEqual("next")
		expect(ActionSlots.look(bar, 4)).toEqual("empty")
		expect(ActionSlots.look({ slots = {} }, 1)).toEqual("next")
		expect(ActionSlots.FADE.filled).toEqual(0)
		expect(ActionSlots.FADE.next < ActionSlots.FADE.empty).toBeTrue()
		local source =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau")
		expect(string.find(source, "ActionSlots.look(bar, index)", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'tabStrip.Name = "TabStrip"', 1, true) ~= nil).toBeTrue()
	end)
end)
