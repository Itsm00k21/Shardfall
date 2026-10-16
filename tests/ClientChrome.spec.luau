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
		expect(ClientChrome.legacyReadout("Pity 0 / 50 toward Legendary")).toEqual(false)
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
		expect(string.find(bar, '"Tonic"', 1, true) ~= nil).toBeTrue()
	end)

	it("joins with one labeled action bar and a closed roll sheet", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local bar = fs.readFile(root .. "ActionBar.luau")
		local reel = fs.readFile(root .. "RollReel.luau")
		local debugHud = fs.readFile(root .. "DebugHud.luau")
		local ui = fs.readFile(root .. "Ui.luau")
		local combat = fs.readFile("src/ServerScriptService/ShardfallServer/CombatService.luau")
		expect(fs.isFile(root .. "ThumbBar.luau")).toEqual(false)
		for _, label in ipairs({ "Attack", "Dodge", "Skills", "Tonic", "Items", "Travel", "Menu" }) do
			expect(string.find(bar, '"' .. label .. '"', 1, true) ~= nil).toBeTrue()
		end
		expect(string.find(bar, "math.max(64, slot.h)", 1, true) ~= nil).toBeTrue()
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
end)
