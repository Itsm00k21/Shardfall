--!strict

--[[
	E-011 wide recheck. Locks the playtest checks that pass at
	1024x768 and 1280x720. The 1280 forge row stays in
	docs/hooks/E-011-wide-recheck.md. This file does not assert it.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local BagBoard = require("../src/ReplicatedStorage/Shared/BagBoard")
local BannerFit = require("../src/ReplicatedStorage/Shared/BannerFit")
local CombatCluster = require("../src/ReplicatedStorage/Shared/CombatCluster")
local CombatFeel = require("../src/ReplicatedStorage/Shared/CombatFeel")
local CombatMath = require("../src/ReplicatedStorage/Shared/CombatMath")
local GoldShop = require("../src/ReplicatedStorage/Shared/GoldShop")
local HeavyChip = require("../src/ReplicatedStorage/Shared/HeavyChip")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Loops = require("../src/ReplicatedStorage/Shared/Loops")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local ShellLayout = require("../src/ReplicatedStorage/Shared/ShellLayout")
local ShardBoard = require("../src/ReplicatedStorage/Shared/ShardBoard")
local UiRouter = require("../src/ReplicatedStorage/Shared/UiRouter")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")
local GuiFake = require("./GuiFake")

local VIEWS = {
	{ 1024, 768, "tablet" },
	{ 1280, 720, "console" },
}

local RAIL = { "Hero", "Bag", "Pets", "Roll", "Shop", "Settings" }

local PARKED = {
	"raids",
	"trading",
	"market",
	"pass",
	"petEvolution",
	"bossPets",
	"forgeSalvage",
	"forgeCraft",
	"chests",
	"paid",
}

type Rect = { x: number, y: number, w: number, h: number }

local function hits(a: Rect, b: Rect): boolean
	if a.w <= 0 or a.h <= 0 or b.w <= 0 or b.h <= 0 then
		return false
	end
	return HudLayout.overlaps(a, b)
end

local function inside(box: Rect, vx: number, vy: number, inset: number): boolean
	return box.x >= inset - 0.01
		and box.y >= inset - 0.01
		and box.x + box.w <= vx - inset + 0.01
		and box.y + box.h <= vy - inset + 0.01
end

local function onScreen(box: Rect, vx: number, vy: number): boolean
	return box.x >= -0.01
		and box.y >= -0.01
		and box.x + box.w <= vx + 0.01
		and box.y + box.h <= vy + 0.01
end

local function tap(box: Rect): boolean
	return box.w >= UiTheme.TOUCH and box.h >= UiTheme.TOUCH
end

local function railOf(vx: number, vy: number): Rect
	local fit = HudLayout.railFit(
		vy,
		UiTheme.safeMargin(),
		HudLayout.RAIL_COUNT,
		UiTheme.TAP,
		UiTheme.TOUCH,
		vx
	)
	return { x = fit.x, y = fit.y, w = fit.w, h = fit.h }
end

local function liveBody(vx: number, vy: number): Rect
	local hub = HudLayout.hub(vx, vy, UiTheme.safeMargin())
	local headerH = UiTheme.HEADER + UiTheme.PAD
	return {
		x = hub.x + 8,
		y = hub.y + headerH,
		w = math.max(44, hub.w - 16),
		h = math.max(44, hub.h - headerH - 8),
	}
end

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

local function profile()
	local data = Schema.template()
	data.classId = "warden"
	data.gold = 40
	data.inventory = {
		sword = {
			uid = "sword",
			name = "Practice Blade",
			rarity = "Rare",
			kind = "Weapon",
		},
	}
	data.uiSettings = Settings.default()
	return data
end

local function boxOf(node): Rect
	local pos = node.AbsolutePosition
	local size = node.AbsoluteSize
	return { x = pos.X, y = pos.Y, w = size.X, h = size.Y }
end

local function shownText(root): { string }
	local lines = {}
	local function walk(node, shown: boolean)
		local nextShown = shown
		if node:IsA("GuiObject") and node.Visible == false then
			nextShown = false
		end
		if node:IsA("LayerCollector") and node.Enabled == false then
			nextShown = false
		end
		if nextShown and (node:IsA("TextLabel") or node:IsA("TextButton")) then
			local text = tostring(node.Text)
			if text ~= "" then
				table.insert(lines, text)
			end
		end
		for _, child in ipairs(node:GetChildren()) do
			walk(child, nextShown)
		end
	end
	walk(root, true)
	return lines
end

local function hasText(lines: { string }, needle: string): boolean
	for _, line in ipairs(lines) do
		if string.find(line, needle, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function rowClears(sheet: Rect, blockers: { Rect }, rowH: number): boolean
	local limit = sheet.y + sheet.h - rowH
	local y = sheet.y
	while y <= limit + 0.01 do
		local row: Rect = { x = sheet.x, y = y, w = sheet.w, h = rowH }
		local clear = true
		for _, block in ipairs(blockers) do
			if hits(row, block) then
				clear = false
				break
			end
		end
		if clear then
			return true
		end
		y += 1
	end
	return false
end

local function boot(vx: number, vy: number)
	local world = GuiFake.world()
	world.playerGui.Parent = world.player
	local HudShell = world.load("HudShell")
	local MenuHub = world.load("MenuHub")
	local OnboardHud = world.load("OnboardHud")
	local ActionBar = world.load("ActionBar")
	local shell = HudShell.start(world.playerGui, {
		onHero = function() end,
		onBag = function() end,
		onRoll = function() end,
		onPets = function() end,
		onShop = function() end,
		onSettings = function() end,
	})
	local hud = GuiFake.findNamed(world.playerGui, "ShardfallHud")
	local railGui = GuiFake.findNamed(world.playerGui, "ShardfallRail")
	hud.AbsoluteSize = { X = vx, Y = vy }
	railGui.AbsoluteSize = { X = vx, Y = vy }
	hud:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	railGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	shell.setProfile(profile())
	OnboardHud.start(function()
		return { ok = true }
	end)
	local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
	onboard.AbsoluteSize = { X = vx, Y = vy }
	onboard:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	local fresh = Schema.template()
	fresh.onboardDone = false
	OnboardHud.setProfile(fresh)
	ActionBar.start(world.playerGui, {
		invoke = function()
			return { ok = true }
		end,
		menuOpen = function()
			return false
		end,
		onDodge = function() end,
		onLight = function() end,
		onHeavy = function() end,
		onSkill = function() end,
		onToast = function() end,
		onResult = function() end,
		onRoll = function() end,
		mobile = function()
			return false
		end,
	})
	local actions = GuiFake.findNamed(world.playerGui, "ShardfallActions")
	actions.AbsoluteSize = { X = vx, Y = vy }
	actions:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	local hub = MenuHub.start(world.playerGui, {
		invoke = function(name: string)
			if name == "EquipItem" then
				local nextProfile = profile()
				nextProfile.equipped = { weapon = "sword" }
				return { ok = true, profile = nextProfile }
			end
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
	})
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
	screen.AbsoluteSize = { X = vx, Y = vy }
	screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	hub.setProfile(profile())
	return {
		hud = hud,
		railGui = railGui,
		onboard = onboard,
		actions = actions,
		hub = hub,
		screen = screen,
	}
end

describe("Wide recheck", function()
	it("keeps schema 26, starter shards, product ids, and the parked switches", function()
		expect(Schema.VERSION).toEqual(26)
		expect(Schema.STARTER_TOKENS).toEqual(10)
		local fresh = Schema.template()
		expect(fresh.schemaVersion).toEqual(26)
		expect(fresh.shardTokens).toEqual(10)
		expect(Loops.PASS_PRODUCT_ID).toEqual(0)
		expect(Loops.ARCHIVE_PRODUCT_ID).toEqual(0)
		for _, id in ipairs(PARKED) do
			expect(LaunchGate.on(id)).toBeFalse()
		end
		expect(CombatFeel.CHARGE_HOLD).toEqual(0.35)
		local offense = CombatMath.loadout(fresh)
		expect(CombatMath.hitsMelee(0, 0, 0, -1, 0, -4, offense.range, offense.minDot)).toBeTrue()
		expect(CombatMath.hitsMelee(0, 0, 0, -1, 0, 4, offense.range, offense.minDot)).toBeFalse()
		local offers = GoldShop.offers()
		expect(#offers).toEqual(2)
		expect(offers[1].id).toEqual("tonic")
		expect(offers[1].label).toEqual("Healing Tonic")
		expect(offers[2].id).toEqual("bag")
		expect(offers[2].label).toEqual("Bag slot")
		expect(HeavyChip.show(false)).toBeFalse()
	end)

	it("keeps the wide shell tappable and clear of the rail", function()
		local margin = UiTheme.safeMargin()
		expect(margin).toEqual(16)
		for _, view in ipairs(VIEWS) do
			local vx = view[1]
			local vy = view[2]
			expect(HudLayout.breakpoint(vx, vy)).toEqual(view[3])
			expect(HudLayout.breakpoint(vx, vy) == "phone").toBeFalse()
			local portrait = HudLayout.portrait(margin)
			local health = HudLayout.health(margin, vx)
			local pills = HudLayout.pills(vx, margin)
			local rail = railOf(vx, vy)
			local hub = HudLayout.hub(vx, vy, margin)
			local body = liveBody(vx, vy)
			local bar = HudLayout.actionCluster(vx, vy)
			local place = ActionSlots.placement(vx, vy, false)
			local tracker = StarterGoalHud.place(vx, vy, 3, 14)
			local cluster = CombatCluster.place(vx, vy, nil, false)
			local sheet = ShellLayout.menuRect(vx, vy)
			expect(bar.x).toEqual(place.x)
			expect(bar.y).toEqual(place.y)
			expect(place.columns).toEqual(8)
			expect(place.rows).toEqual(1)
			expect(place.slot >= UiTheme.TOUCH).toBeTrue()
			expect(hits(portrait, health)).toBeFalse()
			expect(hits(portrait, pills)).toBeFalse()
			expect(hits(health, pills)).toBeFalse()
			expect(hits(rail, portrait)).toBeFalse()
			expect(hits(rail, health)).toBeFalse()
			expect(hits(rail, tracker)).toBeFalse()
			expect(hits(rail, bar)).toBeFalse()
			expect(hits(tracker, portrait)).toBeFalse()
			expect(hits(tracker, health)).toBeFalse()
			expect(hits(tracker, bar)).toBeFalse()
			expect(hits(tracker, pills)).toBeFalse()
			expect(hits(hub, rail)).toBeFalse()
			expect(hits(body, rail)).toBeFalse()
			expect(inside(portrait, vx, vy, margin)).toBeTrue()
			expect(inside(health, vx, vy, margin)).toBeTrue()
			expect(inside(pills, vx, vy, margin)).toBeTrue()
			expect(inside(rail, vx, vy, margin)).toBeTrue()
			expect(onScreen(rail, vx, vy)).toBeTrue()
			expect(rail.w >= UiTheme.TOUCH).toBeTrue()
			expect(onScreen(bar, vx, vy)).toBeTrue()
			expect(hits(sheet, health)).toBeFalse()
			local buttons = { cluster.attack, cluster.dodge, cluster.jump }
			for index, button in ipairs(buttons) do
				expect(tap(button)).toBeTrue()
				expect(onScreen(button, vx, vy)).toBeTrue()
				expect(hits(button, bar)).toBeFalse()
				expect(hits(button, rail)).toBeFalse()
				expect(hits(button, portrait)).toBeFalse()
				expect(hits(button, health)).toBeFalse()
				expect(hits(button, tracker)).toBeFalse()
				expect(hits(button, sheet)).toBeFalse()
				for other = index + 1, #buttons do
					expect(hits(button, buttons[other])).toBeFalse()
				end
			end
			local layout = HudLayout.onboard(vx, vy)
			expect(inside(layout.card, vx, vy, margin)).toBeTrue()
			expect(tap(layout.skip)).toBeTrue()
			expect(tap(layout.continueButton)).toBeTrue()
			expect(layout.skip.x + layout.skip.w <= layout.card.w).toBeTrue()
			expect(layout.skip.y + layout.skip.h <= layout.card.h).toBeTrue()
			local grid = HudLayout.cardGrid(math.max(44, body.w - 16), body.h, 1)
			expect(grid.columns > 1).toBeTrue()
			expect(grid.cellH >= 228).toBeTrue()
			expect(grid.cellW >= UiTheme.TOUCH).toBeTrue()
			local cardX = body.x + 8
			local cardY = body.y + 8
			local tip = BagBoard.tipPlace(cardX, cardY, grid.cellW, grid.cellH, vx, vy, 1)
			expect(inside(tip, vx, vy, 8)).toBeTrue()
			expect(hits(tip, rail)).toBeFalse()
			local lastX = cardX + (grid.columns - 1) * (grid.cellW + grid.gap)
			local lastTip = BagBoard.tipPlace(lastX, cardY, grid.cellW, grid.cellH, vx, vy, 1)
			expect(inside(lastTip, vx, vy, 8)).toBeTrue()
			expect(hits(lastTip, rail)).toBeFalse()
			local span = math.max(80, hub.w - 32)
			local pity = ShardBoard.pityPlace(span, 0, 100)
			local tierRight = 8 + math.max(24, pity.lockX - 12)
			expect(tierRight <= pity.lockX).toBeTrue()
			expect(pity.countX >= pity.lockX + pity.lockW).toBeTrue()
			expect(pity.countX + pity.countW <= span).toBeTrue()
			local chrome = UiRouter.rollChrome(math.max(44, hub.h - 64))
			expect(chrome.button >= UiTheme.TOUCH).toBeTrue()
		end
		local sheet = ShellLayout.menuRect(1024, 768)
		local rail = railOf(1024, 768)
		local bar = HudLayout.actionCluster(1024, 768)
		local cluster = CombatCluster.place(1024, 768, nil, false)
		expect(rowClears(sheet, { rail, bar, cluster.attack, cluster.dodge, cluster.jump }, 44)).toBeTrue()
	end)

	it("walks the hub pages at both wide sizes", function()
		for _, view in ipairs(VIEWS) do
			local vx = view[1]
			local vy = view[2]
			local ui = boot(vx, vy)
			local gold = GuiFake.findNamed(ui.hud, "Gold")
			local shards = GuiFake.findNamed(ui.hud, "Shards")
			local mastery = GuiFake.findNamed(ui.hud, "Mastery")
			expect(gold.Text).toEqual("Gold 40")
			expect(shards.Text).toEqual("Shards 10")
			expect(mastery.Visible).toBeFalse()
			expect(hits(boxOf(GuiFake.findNamed(ui.hud, "Portrait")), boxOf(shards))).toBeFalse()
			local names = {}
			local rail = GuiFake.findNamed(ui.railGui, "Rail")
			for _, child in ipairs(rail:GetChildren()) do
				if child:IsA("TextButton") then
					table.insert(names, child.Name)
					expect(child.Visible).toBeTrue()
					expect(child.AbsoluteSize.X >= UiTheme.TOUCH).toBeTrue()
					expect(child.AbsoluteSize.Y >= UiTheme.TOUCH).toBeTrue()
					local caption = child:FindFirstChild("Caption")
					expect(caption.Text).toEqual(child.Name)
				end
			end
			expect(names).toEqual(RAIL)
			local skip = GuiFake.findNamed(ui.onboard, "Skip")
			expect(skip.Text).toEqual("Skip intro")
			expect(skip.AbsoluteSize.X >= UiTheme.TOUCH).toBeTrue()
			expect(skip.AbsoluteSize.Y >= UiTheme.TOUCH).toBeTrue()
			for _, id in ipairs({ "Swing", "Dodge", "Jump" }) do
				local button = GuiFake.findNamed(ui.actions, id)
				expect(button.Visible).toBeTrue()
				expect(button.AbsoluteSize.X >= UiTheme.TOUCH).toBeTrue()
				expect(button.AbsoluteSize.Y >= UiTheme.TOUCH).toBeTrue()
			end
			expect(GuiFake.findNamed(ui.actions, "Swing").Text).toEqual("Atk")
			expect(GuiFake.findNamed(ui.actions, "Jump").Text).toEqual("Jump")
			expect(GuiFake.findNamed(ui.actions, "Heavy").Visible).toBeFalse()
			local tabs = GuiFake.findNamed(ui.screen, "Tabs")
			expect(tabs.Visible).toBeFalse()
			local header = GuiFake.findNamed(ui.screen, "Header")
			local close = header:FindFirstChild("Close")
			expect(close.Size.Y.Offset >= UiTheme.TOUCH).toBeTrue()

			ui.hub.open("bag")
			local bagLines = shownText(ui.screen)
			expect(header:FindFirstChild("Title").Text).toEqual("Bag")
			expect(hasText(bagLines, "Salvage")).toBeFalse()
			expect(hasText(bagLines, "Robux")).toBeFalse()
			local equip = GuiFake.findNamed(ui.screen, "Equip")
			expect(equip.Text).toEqual("Equip")
			expect(equip.Size.Y.Offset >= UiTheme.TOUCH).toBeTrue()
			local card = nil
			for _, child in ipairs(ui.screen:GetDescendants()) do
				if child.Name == "Card" and child:IsA("TextButton") then
					card = child
					break
				end
			end
			expect(card ~= nil).toBeTrue()
			local grid = card.Parent:FindFirstChildOfClass("UIGridLayout")
			expect(grid.CellSize.X.Offset >= UiTheme.TOUCH).toBeTrue()
			expect(grid.CellSize.Y.Offset >= 228).toBeTrue()
			card.MouseEnter:Fire()
			local tip = GuiFake.findNamed(ui.screen, "Tip")
			expect(tip.Visible).toBeTrue()
			expect(inside(boxOf(tip), vx, vy, 8)).toBeTrue()
			local tipName = tip:FindFirstChild("Name")
			expect(tipName.Text).toEqual("Practice Blade")
			local red, green, blue = UiTheme.rarityColor("Rare")
			expect(tipName.TextColor3.R).toEqual(red)
			expect(tipName.TextColor3.G).toEqual(green)
			expect(tipName.TextColor3.B).toEqual(blue)
			local lineCount = 0
			for _, child in ipairs(tip:GetChildren()) do
				if child.Name == "Line" then
					lineCount += 1
					expect(child.Text).toEqual("Nothing equipped in this slot.")
				end
			end
			expect(lineCount).toEqual(1)
			GuiFake.activate(equip)
			expect(GuiFake.findNamed(ui.screen, "Equip").Text).toEqual("Equipped")

			ui.hub.open("roll")
			expect(header:FindFirstChild("Title").Text).toEqual("Roll")
			local rollLines = shownText(ui.screen)
			expect(hasText(rollLines, "Shards  10")).toBeTrue()
			expect(hasText(rollLines, "Pity 0/100")).toBeTrue()
			expect(hasText(rollLines, "Pity 0/1000")).toBeTrue()
			expect(hasText(rollLines, "CRACK x1")).toBeTrue()
			local rollButton = GuiFake.findNamed(ui.screen, "Roll")
			expect(rollButton.Size.Y.Offset >= UiTheme.TOUCH).toBeTrue()

			ui.hub.open("settings")
			expect(header:FindFirstChild("Title").Text).toEqual("Settings")
			local settings = shownText(ui.screen)
			expect(hasText(settings, "Trades")).toBeFalse()
			expect(hasText(settings, "Raid invites")).toBeFalse()
			expect(hasText(settings, "Hotkey raids")).toBeFalse()
			expect(hasText(settings, "Hotkey market")).toBeFalse()
			expect(hasText(settings, "Text size")).toBeTrue()

			ui.hub.open("pets")
			expect(header:FindFirstChild("Title").Text).toEqual("Pets")
			local pets = shownText(ui.screen)
			expect(hasText(pets, "Evolution")).toBeFalse()
			expect(hasText(pets, "Boss")).toBeFalse()
			expect(hasText(pets, "Crack a Pet Shard")).toBeTrue()

			ui.hub.open("shop")
			expect(header:FindFirstChild("Title").Text).toEqual("Shop")
			local shop = shownText(ui.screen)
			expect(hasText(shop, "Healing Tonic  40 Gold")).toBeTrue()
			expect(hasText(shop, "Bag slot  250 Gold")).toBeTrue()
			expect(hasText(shop, "Pet slot")).toBeFalse()
			expect(hasText(shop, "Dust")).toBeFalse()
			expect(hasText(shop, "Robux")).toBeFalse()
			ui.hub.close()
			expect(ui.screen.Enabled).toBeFalse()
		end
	end)
end)
