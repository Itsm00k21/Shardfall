--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ClientChrome = require("../src/ReplicatedStorage/Shared/ClientChrome")

describe("Client chrome", function()
	it("replaces the current panels and leaves Roblox core guis alone", function()
		expect(ClientChrome.shouldClear("Shardfall")).toEqual(true)
		expect(ClientChrome.shouldClear("ShardfallActions")).toEqual(true)
		expect(ClientChrome.shouldClear("ShardfallCombat")).toEqual(true)
		expect(ClientChrome.shouldClear("ShardfallDebug")).toEqual(true)
		expect(ClientChrome.shouldClear("ShardfallTouch")).toEqual(true)
		expect(ClientChrome.shouldClear("Chat")).toEqual(false)
		expect(ClientChrome.shouldClear("Health")).toEqual(false)
		expect(ClientChrome.legacyReadout("Pity 0/80")).toEqual(true)
		expect(ClientChrome.legacyReadout("Pity 0 / 80 toward Legendary")).toEqual(true)
		expect(ClientChrome.legacyReadout("Pity 0 / 50 toward Legendary")).toEqual(true)
		expect(ClientChrome.legacyReadout("Pity 12 / 50 toward Legendary")).toEqual(true)
		expect(ClientChrome.legacyReadout("Pity 0/50")).toEqual(true)
		expect(ClientChrome.legacyReadout("Epic 0/100 · Legendary 0/1000")).toEqual(false)
		expect(ClientChrome.legacyReadout("Inv 3, Shop 0, Pets P, Roll R, Guilds Y")).toEqual(true)
		expect(ClientChrome.legacyReadout("Hero C, Bag B, Raids T, Market M")).toEqual(false)
	end)

	it("does not ship the old Pity 0/80 readout", function()
		local ui = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
		local reel =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RollReel.luau")
		local bar =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau")
		expect(string.find(ui, "Pity 0/80", 1, true)).toBeNil()
		expect(string.find(reel, "Pity 0/80", 1, true)).toBeNil()
		expect(string.find(ui, "Crack (Shard Token)", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "Toxin", 1, true)).toBeNil()
		expect(string.find(bar, "HelpTab", 1, true)).toBeNil()
		expect(string.find(bar, "GameSettingsTab", 1, true)).toBeNil()
		expect(string.find(bar, "ShardfallActionBar", 1, true) ~= nil).toBeTrue()
	end)

	it("joins with one labeled action bar and a closed roll sheet", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local bar = fs.readFile(root .. "ActionBar.luau")
		local reel = fs.readFile(root .. "RollReel.luau")
		local debugHud = fs.readFile(root .. "DebugHud.luau")
		local ui = fs.readFile(root .. "Ui.luau")
		local combat = fs.readFile("src/ServerScriptService/ShardfallServer/CombatService.luau")
		expect(fs.isFile(root .. "ThumbBar.luau")).toEqual(false)
		expect(string.find(bar, '"Attack"', 1, true)).toBeNil()
		expect(string.find(bar, '"Skills"', 1, true)).toBeNil()
		expect(string.find(bar, "Name = \"Lock\"", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "Name = \"Radial\"", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "Name = \"Seconds\"", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "Name = \"Stacks\"", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, 'promptButton("Dodge", "Shift")', 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, 'promptButton("Interact", "F")', 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "Enum.ScreenInsets.DeviceSafeInsets", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "UIStroke", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "BackgroundTransparency = 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "UDim2.fromOffset(bar.x, bar.y)", 1, true)).toBeNil()
		expect(string.find(debugHud, "Enum.ScreenInsets.DeviceSafeInsets", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "UiTheme.safeMargin()", 1, true) ~= nil).toBeTrue()
		expect(string.find(reel, "setOpen", 1, true) ~= nil).toBeTrue()
		expect(string.find(reel, "odds.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, 'Text = "Debug"', 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "row.Visible = false", 1, true) ~= nil).toBeTrue()
		local panelAt = string.find(ui, 'Name = "Panel"', 1, true)
		expect(panelAt ~= nil).toBeTrue()
		local window = string.sub(ui, panelAt :: number, (panelAt :: number) + 500)
		expect(string.find(window, "Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "humanoid.MaxHealth = maxHealth", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, 'string.format("HP  %d / %d", hp, maxHp)', 1, true) ~= nil).toBeTrue()
	end)

	it("keeps the class picker up until a choice or an explicit close", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local classHud = fs.readFile(root .. "ClassHud.luau")
		local client = fs.readFile(root .. "init.client.luau")
		local haven = fs.readFile(root .. "HavenClient.luau")
		expect(string.find(classHud, "function ClassHud.holdsChoice", 1, true) ~= nil).toBeTrue()
		expect(string.find(classHud, "function ClassHud.dismiss", 1, true) ~= nil).toBeTrue()
		expect(string.find(classHud, "Pick a class. Swap later at the Forge.", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "ClassHud.dismiss()", 1, true) ~= nil).toBeTrue()
		expect(string.find(haven, "now - recentAt < 2", 1, true) ~= nil).toBeTrue()
	end)

	it("joins with no visible legacy panels", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local reel = fs.readFile(root .. "RollReel.luau")
		local debugHud = fs.readFile(root .. "DebugHud.luau")
		local ui = fs.readFile(root .. "Ui.luau")
		local loops = fs.readFile(root .. "LoopHud.luau")
		local market = fs.readFile(root .. "MarketHud.luau")
		local inventory = fs.readFile(root .. "InventoryHud.luau")
		local travel = fs.readFile(root .. "TravelHud.luau")
		local classes = fs.readFile(root .. "ClassHud.luau")
		local client = fs.readFile(root .. "init.client.luau")
		local combat = fs.readFile("src/ServerScriptService/ShardfallServer/CombatService.luau")
		expect(fs.isFile(root .. "ThumbBar.luau")).toEqual(false)
		expect(string.find(reel, "odds.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(reel, "button.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(reel, "rollButton.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "row.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "IsStudio()", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, '"Vault"', 1, true) ~= nil).toBeTrue()
		local panelAt = string.find(ui, 'Name = "Panel"', 1, true)
		expect(panelAt ~= nil).toBeTrue()
		local window = string.sub(ui, panelAt :: number, (panelAt :: number) + 500)
		expect(string.find(window, "Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(loops, "panel.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(loops, "BackgroundTransparency = 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(market, "toggle.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(inventory, '"No items yet"', 1, true) ~= nil).toBeTrue()
		expect(string.find(inventory, "N/A", 1, true)).toBeNil()
		expect(string.find(inventory, "BackgroundTransparency = 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(travel, "BackgroundTransparency = 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(classes, "panel.BackgroundTransparency = 0", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(client, "SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)", 1, true)
				~= nil
		).toBeTrue()
		expect(string.find(client, "setHubChrome(false)", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "humanoid.MaxHealth = maxHealth", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, 'string.format("HP  %d / %d", hp, maxHp)', 1, true) ~= nil).toBeTrue()
	end)

	it("shows only the shell at join", function()
		expect(ClientChrome.visibleAtJoin("ShardfallHud")).toEqual(true)
		expect(ClientChrome.visibleAtJoin("ShardfallCombat")).toEqual(false)
		expect(ClientChrome.visibleAtJoin("ShardfallActions")).toEqual(true)
		expect(ClientChrome.visibleAtJoin("ShardfallDebug")).toEqual(false)
		for _, name in ipairs({
			"Shardfall",
			"ShardfallRoll",
			"ShardfallLoops",
			"ShardfallMenu",
			"ShardfallClasses",
			"ShardfallPets",
			"ShardfallRaids",
			"ShardfallInventory",
			"ShardfallTravel",
			"ShardfallMarket",
			"ShardfallHub",
		}) do
			expect(ClientChrome.visibleAtJoin(name)).toEqual(false)
		end
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local ui = fs.readFile(root .. "Ui.luau")
		local client = fs.readFile(root .. "init.client.luau")
		local hub = fs.readFile(root .. "MenuHub.luau")
		local classes = fs.readFile(root .. "ClassHud.luau")
		local debugHud = fs.readFile(root .. "DebugHud.luau")
		expect(string.find(ui, "Loading profile...", 1, true)).toBeNil()
		expect(string.find(client, "setHubChrome(true)", 1, true)).toBeNil()
		expect(string.find(client, "MenuHub.start", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "LegacyChrome.shouldDestroy", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Enum.KeyCode.Escape", 1, true) ~= nil).toBeTrue()
		expect(ClientChrome.TABS[1].id).toEqual("hero")
		expect(ClientChrome.TABS[1].key).toEqual("C")
		expect(ClientChrome.TABS[4].id).toEqual("roll")
		expect(ClientChrome.TABS[4].key).toEqual("T")
		expect(string.find(classes, "Classes.cooldownText(skill)", 1, true) ~= nil).toBeTrue()
		expect(string.find(classes, "Change class", 1, true) ~= nil).toBeTrue()
		expect(string.find(classes, "panel.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "UIGridLayout", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "Enum.ScrollingDirection.Y", 1, true) ~= nil).toBeTrue()
		expect(string.find(debugHud, "Enum.ScrollingDirection.X", 1, true)).toBeNil()
		expect(string.find(debugHud, "ShellLayout.debugGrid", 1, true) ~= nil).toBeTrue()
	end)
end)
