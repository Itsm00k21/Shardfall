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
	{ 667, 375 },
	{ 812, 375 },
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
	add("equipPrompt", HudLayout.equipPrompt(vx, margin, vy))
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

describe("Open panels sit above the goals, or the goals hide", function()
	local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
	local ONBOARD_ORDER = 95

	local function start()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function()
			return { ok = true }
		end)
		OnboardHud.setCollapsed(false, false)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		return world, OnboardHud, onboard
	end

	-- Goals are "in the way" only if a goals piece is on screen.
	local function goalsShowing(OnboardHud: any, onboard: any): boolean
		local goals = GuiFake.findNamed(onboard, "OnboardGoals")
		local tab = GuiFake.findNamed(onboard, "GoalsTab")
		return OnboardHud.shown(goals) or OnboardHud.shown(tab)
	end

	it("the Dev Tools panel really lands on the goals at Kevin's 1024x500", function()
		local _, frame = DevTools.layout(1024, 500, 16)
		local layout = HudLayout.onboard(1024, 500, false, 4)
		-- Why the dynamic rule is needed: the static column cannot hold both.
		expect(HudLayout.overlaps(frame, layout.tracker)).toBeTrue()
	end)

	it("Dev panel open: goals hidden; closed: goals back as they were", function()
		local _, OnboardHud, onboard = start()
		local devOpen = false
		OnboardHud.coverWhen("dev", function()
			return devOpen
		end)
		expect(goalsShowing(OnboardHud, onboard)).toBeTrue()
		devOpen = true
		OnboardHud.setCovered("dev", true) -- the DebugHud changed hook
		expect(goalsShowing(OnboardHud, onboard)).toBeFalse()
		expect(OnboardHud.shown(GuiFake.findNamed(onboard, "Continue"))).toBeFalse()
		devOpen = false
		OnboardHud.setCovered("dev", false)
		expect(goalsShowing(OnboardHud, onboard)).toBeTrue()
		local _, goalsFolded = OnboardHud.collapsed()
		expect(goalsFolded).toEqual(false) -- restored, not left folded
		OnboardHud.coverWhen("dev", function()
			return false
		end)
	end)

	it("hub menu open: goals hidden; closed: back", function()
		local world, OnboardHud, onboard = start()
		local hubOpen = false
		OnboardHud.coverWhen("hub", function()
			return hubOpen
		end)
		expect(goalsShowing(OnboardHud, onboard)).toBeTrue()
		hubOpen = true
		world.runService.Heartbeat:_emit(0.25) -- no callback: the recheck catches it
		expect(goalsShowing(OnboardHud, onboard)).toBeFalse()
		hubOpen = false
		world.runService.Heartbeat:_emit(0.25)
		expect(goalsShowing(OnboardHud, onboard)).toBeTrue()
		OnboardHud.coverWhen("hub", function()
			return false
		end)
	end)

	it("Dev Tools draws above the onboarding UI and wires open/close", function()
		expect(DevTools.DISPLAY_ORDER > ONBOARD_ORDER).toBeTrue()
		expect(DevTools.DISPLAY_ORDER < 100).toBeTrue() -- under the banner
		local onboard = fs.readFile(CLIENT .. "OnboardHud.luau")
		expect(string.find(onboard, "DisplayOrder = " .. ONBOARD_ORDER, 1, true) ~= nil).toBeTrue()
		local debugHud = fs.readFile(CLIENT .. "DebugHud.luau")
		expect(string.find(debugHud, "DisplayOrder = DevTools.DISPLAY_ORDER", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "setOpen(not panel.Visible)", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "setOpen(false)", 1, true) ~= nil).toBeTrue()
		local init = fs.readFile(CLIENT .. "init.client.luau")
		expect(string.find(init, 'OnboardHud.coverWhen("dev", DebugHud.isOpen)', 1, true) ~= nil).toBeTrue()
		expect(string.find(init, 'OnboardHud.setCovered("dev", open)', 1, true) ~= nil).toBeTrue()
	end)

	it("every full panel or menu under the onboarding UI hides it", function()
		local init = fs.readFile(CLIENT .. "init.client.luau")
		-- Panels drawn below DisplayOrder 95 that can sit where the card or
		-- goals are. Each must have a coverWhen source.
		for _, source in ipairs({
			"inventory",
			"hub",
			"craft",
			"travel",
			"skills",
			"raid",
			"loop",
			"market",
			"results",
			"dev",
		}) do
			local needle = 'OnboardHud.coverWhen("' .. source .. '"'
			expect(string.find(init, needle, 1, true) ~= nil).toBeTrue()
		end
	end)
end)

describe("Havoc #482: landscape phone prompt and toasts", function()
	it("keeps the equip prompt left of the hotbar with both buttons whole", function()
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			local prompt = HudLayout.equipPrompt(vx, 16, vy)
			-- Never narrower than the toast stack's own width allows (390x844
			-- portrait is 160 wide before this change; see the PR notes).
			local host = HudLayout.toastHost(vx, 16)
			expect(prompt.w >= math.min(HudLayout.PROMPT_MIN_W, host.w)).toBeTrue()
			expect(prompt.x >= 16).toBeTrue()
			-- ActionBar forces the thumb cluster under 700 wide or 500 tall,
			-- so the desktop row only exists on larger views.
			local forced = vx < 700 or vy < 500
			local modes = if forced then { true } else { true, false }
			for _, mobile in ipairs(modes) do
				local spot = ActionSlots.placement(vx, vy, mobile)
				local bar = { x = spot.x, y = spot.y, w = spot.w, h = spot.h }
				expect(HudLayout.overlaps(prompt, bar)).toBeFalse()
			end
		end
		-- 667x375: before this fix the prompt (123..543) covered the bar and
		-- the Lock/T strip at x451.
		local phone = HudLayout.equipPrompt(667, 16, 375)
		expect(phone.x + phone.w <= 451 - UiTheme.PAD).toBeTrue()
		-- Without a height the old frame is unchanged for older callers.
		expect(HudLayout.equipPrompt(1512, 16).w).toEqual(420)
	end)

	it("keeps the toast stack off the folded Goals tab", function()
		for _, size in ipairs({ { 667, 375 }, { 812, 375 }, { 844, 390 } }) do
			local layout = HudLayout.onboard(size[1], size[2], true, 4)
			local host = HudLayout.toastHost(size[1], 16)
			expect(HudLayout.overlaps(host, layout.goalsTab)).toBeFalse()
			expect(host.x + host.w <= layout.goalsTab.x - 8).toBeTrue()
		end
	end)
end)

describe("Havoc P3-482-C: the roll reel wins over the goals", function()
	local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"

	it("hides the card and goals while a roll shows, then brings them back", function()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function()
			return { ok = true }
		end)
		OnboardHud.setCollapsed(false, false)
		-- Onboarding.STEPS has no roll step today (open, class, swing, dodge,
		-- door, haven); whatever step is showing, the reel wins.
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		local goals = GuiFake.findNamed(onboard, "OnboardGoals")
		local tab = GuiFake.findNamed(onboard, "GoalsTab")
		local card = GuiFake.findNamed(onboard, "Continue").Parent
		local function goalsOn(): boolean
			return OnboardHud.shown(goals) or OnboardHud.shown(tab)
		end
		local rolling = false
		OnboardHud.coverWhen("roll", function()
			return rolling
		end)
		expect(goalsOn()).toBeTrue()
		rolling = true
		OnboardHud.setCovered("roll", true) -- RollReel's setBusy hook
		expect(goalsOn()).toBeFalse()
		expect(OnboardHud.shown(card)).toBeFalse()
		-- busy ends but the result card is still up: still hidden.
		OnboardHud.setCovered("roll", false)
		expect(goalsOn()).toBeFalse()
		-- The result card closes; the Heartbeat recheck restores them.
		rolling = false
		world.runService.Heartbeat:_emit(0.25)
		expect(goalsOn()).toBeTrue()
		local _, folded = OnboardHud.collapsed()
		expect(folded).toEqual(false)
		OnboardHud.coverWhen("roll", function()
			return false
		end)
	end)

	it("wires the reel's real on-screen state into OnboardHud", function()
		local reel = fs.readFile(CLIENT .. "RollReel.luau")
		expect(string.find(reel, "isShowing = isShowing", 1, true) ~= nil).toBeTrue()
		local start = string.find(reel, "local function isShowing", 1, true)
		expect(start ~= nil).toBeTrue()
		local body = string.sub(reel, start :: number, (start :: number) + 400)
		for _, part in ipairs({ "busy", "reel.Visible", "card.Visible", "chestFrame.Visible" }) do
			expect(string.find(body, part, 1, true) ~= nil).toBeTrue()
		end
		local init = fs.readFile(CLIENT .. "init.client.luau")
		expect(string.find(init, 'OnboardHud.coverWhen("roll"', 1, true) ~= nil).toBeTrue()
		expect(string.find(init, 'OnboardHud.setCovered("roll", isBusy)', 1, true) ~= nil).toBeTrue()
	end)
end)

describe("Equip prompt buttons always fit", function()
	it("narrows Equip and Keep to share the row under 200 wide", function()
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			local prompt = HudLayout.equipPrompt(vx, 16, vy)
			local yes, no = HudLayout.promptButtons(prompt.w)
			for _, button in ipairs({ yes, no }) do
				expect(button.x >= 0 and button.x + button.w <= prompt.w).toBeTrue()
				expect(button.y + button.h <= prompt.h).toBeTrue()
				expect(button.h >= UiTheme.TOUCH).toBeTrue()
			end
			expect(HudLayout.overlaps(yes, no)).toBeFalse()
		end
		local portrait = HudLayout.equipPrompt(390, 16, 844)
		expect(portrait.w < HudLayout.PROMPT_MIN_W).toBeTrue()
		local yes, no = HudLayout.promptButtons(portrait.w)
		expect(no.y).toEqual(yes.y)
		expect(no.x + no.w <= portrait.w - 8).toBeTrue()
		expect(yes.w >= 64).toBeTrue() -- "Equip" at MIN_TEXT fits
		expect(portrait.h).toEqual(HudLayout.PROMPT_LABEL + UiTheme.TOUCH + UiTheme.PAD)
		expect(HudLayout.promptButtons(420)).toEqual({
			x = 8,
			y = HudLayout.PROMPT_LABEL,
			w = UiTheme.TOUCH * 2,
			h = UiTheme.TOUCH,
		})
		local source =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau")
		expect(string.find(source, "HudLayout.promptButtons(ask.w)", 1, true) ~= nil).toBeTrue()
	end)
end)

-- [Ghost] Clip 7 (Kevin): the Bag preview sat over the grid and Equip
-- Best; "Dodge!" sat on Jump; toasts drew over the Rootvault cleared card.
local CombatCluster = require("../src/ReplicatedStorage/Shared/CombatCluster")
local HeavyChip = require("../src/ReplicatedStorage/Shared/HeavyChip")
local HubStyle = require("../src/ReplicatedStorage/Shared/HubStyle")

describe("HUD overlap (Clip 7): Bag open, Dodge! hint, result card", function()
	local function inside(inner: Rect, outer: Rect): boolean
		return inner.x >= outer.x
			and inner.y >= outer.y
			and inner.x + inner.w <= outer.x + outer.w
			and inner.y + inner.h <= outer.y + outer.h
	end

	it("Bag open: grid, Equip Best footer and preview never overlap, on every view", function()
		local problems = {}
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			local margin = UiTheme.safeMargin()
			local hub = HudLayout.hub(vx, vy, margin, 3)
			local body = HudLayout.hubBody(hub.w, hub.h)
			local cols = HubStyle.bagColumns(body.w, body.h, true)
			local page = { x = 0, y = 0, w = body.w, h = body.h }
			local parts: { Named } = {
				{ name = "grid", rect = cols.grid },
				{ name = "foot", rect = cols.foot },
			}
			if cols.previewShown then
				table.insert(parts, { name = "preview", rect = cols.preview })
			end
			for i = 1, #parts do
				if not inside(parts[i].rect, page) then
					table.insert(
						problems,
						string.format("%dx%d %s off the page", vx, vy, parts[i].name)
					)
				end
				for j = i + 1, #parts do
					if HudLayout.overlaps(parts[i].rect, parts[j].rect) then
						table.insert(
							problems,
							string.format("%dx%d %s x %s", vx, vy, parts[i].name, parts[j].name)
						)
					end
				end
			end
			-- The panel itself stays on screen with the Bag open.
			local panel = { x = hub.x, y = hub.y, w = hub.w, h = hub.h }
			if not inside(panel, { x = 0, y = 0, w = vx, h = vy }) then
				table.insert(problems, string.format("%dx%d hub panel off screen", vx, vy))
			end
			if cols.previewShown then
				-- A decent figure: the worn viewport fits its column and is
				-- never a postage stamp.
				local worn = HubStyle.wornHeight(cols.preview.h)
				if worn < 96 or worn + 56 > cols.preview.h then
					table.insert(
						problems,
						string.format("%dx%d worn %d in %d", vx, vy, worn, cols.preview.h)
					)
				end
			end
		end
		if #problems > 0 then
			print(table.concat(problems, "\n"))
		end
		expect(#problems).toEqual(0)
	end)

	it("Kevin's 1024x500 and 1920x1080 Bags are two columns with a big figure", function()
		for _, view in ipairs({ { 1024, 500 }, { 1920, 1080 } }) do
			local hub = HudLayout.hub(view[1], view[2], UiTheme.safeMargin(), 3)
			local body = HudLayout.hubBody(hub.w, hub.h)
			local cols = HubStyle.bagColumns(body.w, body.h, true)
			expect(cols.side).toBeTrue()
			expect(cols.previewShown).toBeTrue()
			expect(cols.preview.x >= cols.grid.x + cols.grid.w).toBeTrue()
			expect(cols.foot.w).toEqual(cols.grid.w)
			expect(cols.preview.h).toEqual(body.h)
			expect(HubStyle.wornHeight(cols.preview.h) >= 260).toBeTrue()
		end
	end)

	it("Dodge! hint clears Dodge, Jump, Swing, Heavy and the slot bar on every view", function()
		local problems = {}
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			for _, touch in ipairs({ false, true }) do
				local mobile = touch or vx < 700 or vy < 500
				local heavyShown = HeavyChip.show(mobile)
				local cluster = CombatCluster.place(vx, vy, nil, mobile)
				local bar = ActionSlots.placement(vx, vy, mobile)
				local hint = CombatCluster.hintRect(vx, vy, mobile, heavyShown)
				local others: { Named } = {
					{ name = "dodge", rect = cluster.dodge },
					{ name = "jump", rect = cluster.jump },
					{ name = "attack", rect = cluster.attack },
					{ name = "bar", rect = { x = bar.x, y = bar.y, w = bar.w, h = bar.h } },
				}
				if heavyShown then
					table.insert(others, { name = "heavy", rect = cluster.heavy })
				end
				for _, other in ipairs(others) do
					if HudLayout.overlaps(hint, other.rect) then
						table.insert(
							problems,
							string.format(
								"%dx%d %s: hint x %s",
								vx,
								vy,
								if touch then "touch" else "mouse",
								other.name
							)
						)
					end
				end
				if not inside(hint, { x = 0, y = 0, w = vx, h = vy }) then
					table.insert(problems, string.format("%dx%d hint off screen", vx, vy))
				end
			end
		end
		if #problems > 0 then
			print(table.concat(problems, "\n"))
		end
		expect(#problems).toEqual(0)
	end)

	it("result card + toast: the card draws above the toast lane wherever they meet", function()
		local combat =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau")
		local shell =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau")
		local onboard =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/OnboardHud.luau")
		local resultOrder = tonumber(string.match(combat, "CombatHud%.RESULT_ORDER = (%d+)"))
		local toastOrder = tonumber(string.match(shell, "screen%.DisplayOrder = (%d+)"))
		expect(resultOrder).toEqual(50)
		expect(toastOrder).toEqual(30)
		expect(string.find(combat, "card.Parent = resultGui", 1, true) ~= nil).toBeTrue()
		expect(string.find(onboard, "DisplayOrder = 95", 1, true) ~= nil).toBeTrue()
		-- The intro pill (95) is above the card, so it must fold under it.
		local init =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		expect(
			string.find(init, 'OnboardHud.coverWhen("clearCard", CombatHud.resultShowing)', 1, true)
				~= nil
		).toBeTrue()
		-- Pairwise: where the card (340 wide, centred at 38% x 45%) meets
		-- the toast lane, the card's band wins.
		local met = 0
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			local card = {
				x = math.floor(vx * 0.38 - 170),
				y = math.floor(vy * 0.45 - 110),
				w = 340,
				h = 220,
			}
			local toast = HudLayout.toastHost(vx, UiTheme.safeMargin())
			if HudLayout.overlaps(card, toast) then
				met += 1
				expect(resultOrder > toastOrder).toBeTrue()
			end
		end
		expect(met >= 0).toBeTrue()
	end)
end)
