--!strict

--[[
	[Ghost] Oct 24, Kevin's playtest clips. LaunchGate classes is off on
	live, so no class entry point may show: the picker loop ("That is
	closed"), the Hero page's Choose class, Change class, the HUD "Class"
	label, the Hero dot, and the "Choose a class" goal. The intro card
	stays off the rail and never stacks with the starter-goal list, and
	its text is at least UiTheme.MIN_TEXT.
]]

local fs = require("@lune/fs")
local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")
local GuiFake = require("./GuiFake")

local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"

local function noClassProfile()
	return {
		level = 1,
		xp = 0,
		classId = "",
		classXp = {},
		shardTokens = 0,
		gold = 0,
		shardRolls = 0,
		inventory = {},
		pets = {},
		equipped = { armor = {} },
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
		onboardDone = false,
		onboardStep = "class",
	}
end

local function openHero()
	local world = GuiFake.world()
	local MenuHub = world.load("MenuHub")
	local invokes = {}
	local hub = MenuHub.start(world.playerGui, {
		invoke = function(name: string)
			table.insert(invokes, name)
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
		onToast = function() end,
	})
	hub.setProfile(noClassProfile())
	hub.promptClass(true)
	hub.open("hero")
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
	return hub, screen, invokes
end

local function anyText(root: any, needle: string): boolean
	for _, node in ipairs(root:GetDescendants()) do
		if
			(node:IsA("TextLabel") or node:IsA("TextButton"))
			and string.find(node.Text, needle, 1, true) ~= nil
			and node.Visible ~= false
		then
			return true
		end
	end
	return false
end

describe("Classes off: no class entry points", function()
	it("is off on live", function()
		expect(LaunchGate.on("classes")).toEqual(false)
	end)

	it("never opens the class picker and shows neutral Hero copy", function()
		local hub, screen, invokes = openHero()
		expect(hub.hasModal()).toEqual(false)
		expect(hub.current()).toEqual("hero")
		expect(GuiFake.findNamed(screen, "ChooseClass")).toBeNil()
		expect(anyText(screen, "Choose class")).toBeFalse()
		expect(anyText(screen, "Change class")).toBeFalse()
		expect(anyText(screen, "Choose a class to take a kit")).toBeFalse()
		expect(anyText(screen, "No class")).toBeFalse()
		expect(anyText(screen, "Classes open later")).toBeTrue()
		for _, name in ipairs(invokes) do
			expect(name ~= "SetClass").toBeTrue()
		end
	end)

	it("gates every client class prompt on LaunchGate classes", function()
		local hub = fs.readFile(CLIENT .. "MenuHub.luau")
		local start = string.find(hub, "function hubFn.classMissing", 1, true)
		expect(start ~= nil).toBeTrue()
		local body = string.sub(hub, start :: number, (start :: number) + 400)
		expect(string.find(body, 'LaunchGate.on("classes")', 1, true) ~= nil).toBeTrue()
		local shell = fs.readFile(CLIENT .. "HudShell.luau")
		expect(
			string.find(shell, 'if LaunchGate.on("classes") then "Class" else "Hero"', 1, true)
				~= nil
		).toBeTrue()
		expect(string.find(shell, 'classDef == nil and LaunchGate.on("classes")', 1, true) ~= nil).toBeTrue()
	end)

	it("drops the class goal and points the class step at Skip intro", function()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function()
			return { ok = false, error = "That is closed." }
		end)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		expect(anyText(onboard, "Choose a class")).toBeFalse()
		expect(anyText(onboard, "Pick the one that fits")).toBeFalse()
		expect(anyText(onboard, "Classes open later")).toBeTrue()
		expect(GuiFake.findNamed(onboard, "GoalsHeader").Text).toEqual("Goals 0/4")
	end)
end)

describe("Intro card placement and the starter-goal list", function()
	local VIEWS = {
		{ 1024, 600 },
		{ 1024, 768 },
		{ 1280, 720 },
		{ 1482, 669 },
		{ 1512, 820 },
		{ 1920, 1080 },
		{ 844, 390 },
		{ 390, 844 },
	}

	it("keeps the card clear of the rail on every view, touch or not", function()
		local margin = UiTheme.safeMargin()
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			local fit =
				HudLayout.railFit(vy, margin, HudLayout.RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH, vx)
			local rail = { x = fit.x, y = fit.y, w = fit.w, h = fit.h }
			for _, touch in ipairs({ false, true }) do
				local layout = HudLayout.onboard(vx, vy, touch)
				expect(HudLayout.overlaps(layout.card, rail)).toBeFalse()
				expect(HudLayout.overlaps(layout.pill, rail)).toBeFalse()
				expect(layout.card.x >= rail.x + rail.w + 8).toBeTrue()
			end
		end
	end)

	it("sits lower left on a mouse screen, off the toasts, prompt, bar, and centre", function()
		local margin = UiTheme.safeMargin()
		for _, view in ipairs(VIEWS) do
			local vx, vy = view[1], view[2]
			if HudLayout.breakpoint(vx, vy) ~= "phone" then
				local layout = HudLayout.onboard(vx, vy, false)
				local card = layout.card
				local bar = HudLayout.actionCluster(vx, vy)
				expect(HudLayout.overlaps(card, HudLayout.toastHost(vx, margin))).toBeFalse()
				expect(HudLayout.overlaps(card, HudLayout.equipPrompt(vx, margin))).toBeFalse()
				expect(HudLayout.overlaps(card, bar)).toBeFalse()
				expect(HudLayout.overlaps(card, layout.tracker)).toBeFalse()
				expect(card.x + card.w <= vx / 2).toBeTrue()
				expect(card.y + card.h <= bar.y).toBeTrue()
				expect(card.y > vy / 2).toBeTrue()
			end
		end
	end)

	it("hides the starter-goal list while the intro card or its goals show", function()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local StarterGoalHud = world.load("StarterGoalHud")
		expect(StarterGoalHud.isSuppressed()).toBeFalse()
		StarterGoalHud.setSuppressed("onboard", true)
		expect(StarterGoalHud.isSuppressed()).toBeTrue()
		StarterGoalHud.setSuppressed("onboard", false)
		expect(StarterGoalHud.isSuppressed()).toBeFalse()

		local OnboardHud = world.load("OnboardHud")
		local seen = {}
		OnboardHud.onShownChange(function(shown: boolean)
			table.insert(seen, shown)
		end)
		OnboardHud.start(function()
			return { ok = true }
		end)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "open" })
		expect(seen[#seen]).toEqual(true)
		GuiFake.activate(GuiFake.findNamed(world.playerGui, "Skip"))
		expect(seen[#seen]).toEqual(false)

		local client = fs.readFile(CLIENT .. "init.client.luau")
		expect(
			string.find(client, 'StarterGoalHud.setSuppressed("onboard", shown)', 1, true) ~= nil
		).toBeTrue()
	end)

	it("keeps intro, goals, and starter-goal text at the 14px floor or above", function()
		expect(UiTheme.MIN_TEXT >= 14).toBeTrue()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function()
			return { ok = true }
		end)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "swing" })
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		local checked = 0
		for _, node in ipairs(onboard:GetDescendants()) do
			if node:IsA("TextLabel") or node:IsA("TextButton") then
				checked += 1
				expect(node.TextSize >= UiTheme.MIN_TEXT).toBeTrue()
			end
		end
		expect(checked >= 6).toBeTrue()
		local goals = fs.readFile(CLIENT .. "StarterGoalHud.luau")
		expect(string.find(goals, "local BASE_TEXT = UiTheme.MIN_TEXT", 1, true) ~= nil).toBeTrue()
	end)
end)
