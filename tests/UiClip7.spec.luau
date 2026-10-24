--!strict

--[[
	[Ghost] Clip 7 (Kevin, Oct 24) UI batch: the Bag (two columns, bigger
	figure, no 1-8 strip, smooth open and close, rarity stars, a real
	"Open full bag" button), intro toasts over the result card, the Goals
	tab count, the hotbar weapon, "Shards" on the card, the Dodge! chip and
	the red line under the topbar.
]]

local fs = require("@lune/fs")
local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local ClientChrome = require("../src/ReplicatedStorage/Shared/ClientChrome")
local CombatFeel = require("../src/ReplicatedStorage/Shared/CombatFeel")
local GearHooks = require("../src/ReplicatedStorage/Shared/GearHooks")
local HeroView = require("../src/ReplicatedStorage/Shared/HeroView")
local HubStyle = require("../src/ReplicatedStorage/Shared/HubStyle")
local Onboarding = require("../src/ReplicatedStorage/Shared/Onboarding")
local UiMotion = require("../src/ReplicatedStorage/Shared/UiMotion")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")
local GuiFake = require("./GuiFake")

local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"

describe("Clip 7 Bag", function()
	it("bagColumns: two columns from 440 wide, preview never over grid or footer", function()
		for _, w in ipairs({ 440, 577, 700, 1000 }) do
			local cols = HubStyle.bagColumns(w, 400, true)
			expect(cols.side).toBeTrue()
			expect(cols.grid.x + cols.grid.w + HubStyle.BAG_GAP).toEqual(cols.preview.x)
			expect(cols.preview.x + cols.preview.w).toEqual(w)
			expect(cols.foot.y).toEqual(cols.grid.y + cols.grid.h)
			expect(cols.foot.x + cols.foot.w <= cols.preview.x).toBeTrue()
			expect(cols.preview.w >= HubStyle.BAG_PREVIEW_MIN).toBeTrue()
			expect(cols.preview.w <= HubStyle.BAG_PREVIEW_MAX).toBeTrue()
		end
	end)

	it("bagColumns: narrow pages stack, and a short one drops the preview", function()
		local tall = HubStyle.bagColumns(300, 600, true)
		expect(tall.side).toBeFalse()
		expect(tall.previewShown).toBeTrue()
		expect(tall.preview.y >= tall.foot.y + tall.foot.h).toBeTrue()
		expect(tall.preview.y + tall.preview.h <= 600).toBeTrue()
		local short = HubStyle.bagColumns(300, 240, true)
		expect(short.previewShown).toBeFalse()
		expect(short.grid.h + short.foot.h).toEqual(240)
		local off = HubStyle.bagColumns(900, 400, false)
		expect(off.previewShown).toBeFalse()
		expect(off.grid.w).toEqual(900)
	end)

	it("wornHeight fills the column and stays between 96 and 420", function()
		expect(HubStyle.wornHeight(326)).toEqual(270)
		expect(HubStyle.wornHeight(900)).toEqual(420)
		expect(HubStyle.wornHeight(50)).toEqual(96)
	end)

	it("frameDistance fits the whole figure in view", function()
		local d = HeroView.frameDistance(5, 2, 0.7, HeroView.WORN_FOV)
		local half = math.tan(math.rad(HeroView.WORN_FOV) / 2)
		-- Visible height at the front face holds the figure with air.
		expect((d - 1) * half * 2 >= 5).toBeTrue()
		expect((d - 1) * half * 2 * 0.7 >= 2).toBeTrue()
		-- A wider view brings the camera closer (bigger figure).
		expect(HeroView.frameDistance(5, 2, 1.2, 40) <= d).toBeTrue()
		expect(HeroView.frameDistance(nil, nil, nil, nil) > 0).toBeTrue()
	end)

	it("open is a 0.18 s fade + scale, close 0.15 s; reduced motion is instant", function()
		expect(UiMotion.hubOpen(false)).toEqual(0.18)
		expect(UiMotion.hubClose(false)).toEqual(UiTheme.MOTION.panel)
		expect(UiMotion.hubClose(false) <= 0.2).toBeTrue()
		expect(UiMotion.hubOpen(true)).toEqual(0)
		expect(UiMotion.hubClose(true)).toEqual(0)
		expect(UiMotion.HUB_OPEN_SCALE < 1).toBeTrue()
	end)

	it("stars take the rarity color; stars still to earn are dimmed", function()
		local epic = { rarity = "Epic", stars = 2, upgrade = 3 }
		local text = GearHooks.levelRich(epic)
		local r, g, b = GearHooks.starColor(epic)
		local tag = string.format("#%02X%02X%02X", r, g, b)
		expect(string.find(text, '<font color="#FFCE60">+3</font>', 1, true) ~= nil).toBeTrue()
		expect(string.find(text, tag .. '">★★</font>', 1, true) ~= nil).toBeTrue()
		expect(string.find(text, 'transparency="0.60">☆☆☆</font>', 1, true) ~= nil).toBeTrue()
		local common = GearHooks.levelRich({ rarity = "Common", stars = 0 })
		expect(string.find(common, "★", 1, true)).toEqual(nil)
		expect(string.find(common, "☆☆☆☆☆", 1, true) ~= nil).toBeTrue()
		local cr, cg, cb = GearHooks.starColor({ rarity = "Common" })
		expect(cr == r and cg == g and cb == b).toBeFalse()
		expect(GearHooks.levelRich(nil)).toEqual("")
	end)

	it("MenuHub wires the columns, the worn frame, the button and the motion", function()
		local source = fs.readFile(CLIENT .. "MenuHub.luau")
		for _, want in ipairs({
			"HubStyle.bagColumns(",
			"HubStyle.wornHeight(",
			"HeroView.frameDistance(",
			'"OpenFullBag"',
			"GearHooks.levelRich(item)",
			"UiMotion.hubOpen(",
			"UiMotion.hubClose(",
			'"OpenVeil"',
		}) do
			expect(string.find(source, want, 1, true) ~= nil).toBeTrue()
		end
		expect(string.find(source, '"Slot" .. tostring(index)', 1, true)).toEqual(nil)
		expect(string.find(source, "bagStage(hubFn.rollRowWidth(), 480)", 1, true)).toEqual(nil)
	end)
end)

describe("Clip 7 intro toasts", function()
	it("hub-only steps go quiet in a dungeon run; dodge still shows", function()
		expect(Onboarding.quietInRun("swing")).toBeTrue()
		expect(Onboarding.quietInRun("open")).toBeTrue()
		expect(Onboarding.quietInRun("dodge")).toBeFalse()
		expect(Onboarding.quietInRun(nil)).toBeFalse()
	end)

	it("the Keep swinging pill folds in a run and comes back in the hub", function()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function()
			return { ok = true }
		end)
		OnboardHud.coverWhen("run", OnboardHud.runQuiet)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "swing" })
		OnboardHud.setCollapsed(true, true)
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		local pill = GuiFake.findNamed(onboard, "IntroPill")
		expect(pill.Visible).toBeTrue()
		expect(OnboardHud.stepId()).toEqual("swing")
		OnboardHud.setInRun(true)
		expect(pill.Visible).toBeFalse()
		OnboardHud.setInRun(false)
		expect(pill.Visible).toBeTrue()
		-- The result card covers it too.
		local cardUp = true
		OnboardHud.coverWhen("clearCard", function()
			return cardUp
		end)
		OnboardHud.setCovered("clearCard", true)
		expect(pill.Visible).toBeFalse()
		cardUp = false
		world.runService.Heartbeat:_emit(0.25)
		expect(pill.Visible).toBeTrue()
		OnboardHud.setCollapsed(false, false)
	end)

	it("No target in range. is short and does not restart on every swing", function()
		local first = CombatFeel.hintPlan("No target in range.", "", -math.huge, 10)
		expect(first.show).toBeTrue()
		expect(first.hold + first.fade <= 1).toBeTrue()
		local again = CombatFeel.hintPlan("No target in range.", "No target in range.", 10, 11)
		expect(again.show).toBeFalse()
		local later = CombatFeel.hintPlan("No target in range.", "No target in range.", 10, 14)
		expect(later.show).toBeTrue()
		local other = CombatFeel.hintPlan("Too far to dodge.", "Too far to dodge.", 10, 10.5)
		expect(other.show).toBeTrue()
		expect(other.hold).toEqual(1.6)
		expect(CombatFeel.hintPlan("", "", 0, 0).show).toBeFalse()
	end)
end)

describe("Clip 7 Goals tab", function()
	local function base(): any
		return {
			covered = false,
			active = false,
			onboardShown = false,
			onboardCollapsed = false,
			onboardHasGoals = false,
			starterDone = 0,
			starterTotal = 0,
			starterFolded = false,
		}
	end

	it("counts the starter list once the intro is off screen", function()
		local world = GuiFake.world()
		local OnboardHud = world.load("OnboardHud")
		local input = base()
		input.starterDone = 1
		input.starterTotal = 2
		local state = OnboardHud.tabState(input)
		expect(state.visible).toBeTrue()
		expect(state.mode).toEqual("starter")
		expect(state.text).toEqual("› Goals 1/2")
		input.starterFolded = true
		expect(OnboardHud.tabState(input).text).toEqual("‹ Goals 1/2")
		input.covered = true
		expect(OnboardHud.tabState(input).visible).toBeFalse()
		-- Intro card up: the starter list hides, so does its tab.
		local up = base()
		up.starterTotal = 2
		up.onboardShown = true
		up.active = true
		expect(OnboardHud.tabState(up).visible).toBeFalse()
		-- No starter list: the old intro tab while intro goals are folded.
		local intro = base()
		intro.active = true
		intro.onboardCollapsed = true
		intro.onboardHasGoals = true
		expect(OnboardHud.tabState(intro).mode).toEqual("onboard")
	end)

	it("stays after Skip intro, updates after a clear, and folds the list", function()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function()
			return { ok = true }
		end)
		local folds = {}
		OnboardHud.onStarterFold(function(folded: boolean)
			table.insert(folds, folded)
		end)
		OnboardHud.setProfile({ onboardDone = true })
		OnboardHud.setStarterGoals(0, 2)
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		local tab = GuiFake.findNamed(onboard, "GoalsTab")
		expect(tab.Visible).toBeTrue()
		expect(tab.Text).toEqual("› Goals 0/2")
		OnboardHud.setStarterGoals(1, 2) -- Rootvault cleared
		expect(tab.Text).toEqual("› Goals 1/2")
		GuiFake.activate(tab)
		expect(folds[1]).toEqual(true)
		expect(tab.Text).toEqual("‹ Goals 1/2")
		GuiFake.activate(tab)
		expect(folds[2]).toEqual(false)
		OnboardHud.setStarterGoals(0, 0)
		expect(tab.Visible).toBeFalse()
	end)

	it("StarterGoalHud.counts matches its rows", function()
		local world = GuiFake.world()
		local StarterGoalHud = world.load("StarterGoalHud")
		local done, total = StarterGoalHud.counts({
			ok = true,
			goals = {
				{ text = "Clear Rootvault", progress = 1, goal = 1 },
				{ text = "Reach Lv 5", progress = 1, goal = 5 },
			},
		})
		expect(done).toEqual(1)
		expect(total).toEqual(2)
		local none, zero = StarterGoalHud.counts(nil)
		expect(none).toEqual(0)
		expect(zero).toEqual(0)
	end)
end)

describe("Clip 7 hotbar, card, Dodge!, red line", function()
	local profile = {
		equipped = { weapon = "w1" },
		inventory = { w1 = { uid = "w1", name = "Nightbriar", rarity = "Rare", kind = "Weapon" } },
	}

	it("an empty slot 1 shows the equipped weapon", function()
		local empty = { locked = false, slots = {} }
		local face = ActionSlots.weaponFace(empty, 1, profile)
		expect(face ~= nil).toBeTrue()
		if face ~= nil then
			expect(face.name).toEqual("Nightbriar")
			expect(face.art).toEqual("ItemWeapon")
			local r, g, b = UiTheme.rarityColor("Rare")
			expect(face.border).toEqual({ r, g, b })
		end
		expect(ActionSlots.weaponFace(empty, 2, profile)).toEqual(nil)
		local filled = { locked = false, slots = { { kind = "consumable", id = "tonic" } } }
		expect(ActionSlots.weaponFace(filled, 1, profile)).toEqual(nil)
		expect(ActionSlots.weaponFace(empty, 1, { equipped = {} })).toEqual(nil)
		local source = fs.readFile(CLIENT .. "ActionBar.luau")
		expect(string.find(source, "ActionSlots.weaponFace(bar, index, profile)", 1, true) ~= nil).toBeTrue()
	end)

	it("the result card says Shards and has its own gui in ClientChrome", function()
		local source = fs.readFile(CLIENT .. "CombatHud.luau")
		expect(string.find(source, "Shard tokens", 1, true)).toEqual(nil)
		expect(string.find(source, '"Shards  %d"', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'resultGui.Name = "ShardfallResult"', 1, true) ~= nil).toBeTrue()
		expect(ClientChrome.shouldClear("ShardfallResult")).toBeTrue()
	end)

	it("the cue edge has no stroke along the top of the screen", function()
		local source = fs.readFile(CLIENT .. "CombatHud.luau")
		expect(string.find(source, '"CueEdge"', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "cueStroke", 1, true)).toEqual(nil)
		local edge = string.match(source, 'cueEdge%.Name = "CueEdge"(.-)local function cueColor')
		expect(edge ~= nil).toBeTrue()
		if edge ~= nil then
			expect(string.find(edge, "UIStroke", 1, true)).toEqual(nil)
		end
	end)
end)
