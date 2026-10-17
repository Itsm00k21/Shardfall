--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Materials = require("../src/ReplicatedStorage/Shared/Materials")

describe("Dungeon playtest", function()
	it("names a pickup after the material, not the boss", function()
		local line = Materials.lootHint({ "Gnarl's Seed x1" }, "Grandmother Gnarl")
		expect(line).toEqual("+ Gnarl's Seed x1")
		expect(string.find(line, "Grandmother", 1, true)).toBeNil()
		expect(string.find(line, "Grandfather", 1, true)).toBeNil()
		expect(Materials.lootHint({ "Grandmother Gnarl!" }, "Grandmother Gnarl")).toEqual("")
		expect(Materials.lootHint({ "Grandmother Great!" }, "Grandmother Gnarl")).toEqual("")
		expect(Materials.lootHint({ "Grandfather Great!" }, "Grandmother Gnarl")).toEqual("")
	end)

	it("hides an empty banner, fades loot, and keeps the red square", function()
		local ui = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
		expect(string.find(ui, "banner.Visible = shown ~= \"\"", 1, true) ~= nil).toBeTrue()
		expect(string.find(ui, "banner.Visible = false", 1, true) ~= nil).toBeTrue()
		-- Gold-banner fit owns the safe inset. Hide-when-empty stays.
		expect(string.find(ui, "IgnoreGuiInset = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(ui, "ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets", 1, true) ~= nil).toBeTrue()

		local hud = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau")
		expect(string.find(hud, "string.upper(colorName)", 1, true)).toBeNil()
		expect(string.find(hud, "CueEdge", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "showCombatHint", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "CombatFeel.teachCue", 1, true) ~= nil).toBeTrue()

		local stage = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatStage.luau")
		expect(string.find(stage, "Motor6D", 1, true) ~= nil).toBeTrue()
		expect(string.find(stage, "WeaponGrip", 1, true) ~= nil).toBeTrue()
		expect(string.find(stage, "CombatFeel.swingAlpha", 1, true) ~= nil).toBeTrue()

		local doors = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/DoorHud.luau")
		expect(string.find(doors, "GroupTransparency", 1, true) ~= nil).toBeTrue()
		expect(string.find(doors, "Rootvault.DOOR_FADE", 1, true) ~= nil).toBeTrue()
		expect(string.find(doors, "doorSignature", 1, true) ~= nil).toBeTrue()

		local service = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(service, "Dungeons.defeatLine", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "The Rootvault pushes you out", 1, true)).toBeNil()
		expect(string.find(service, "Rockdust", 1, true)).toBeNil()
		expect(string.find(service, "Materials.lootHint", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "CombatFeel.insideMarker", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "ModelFactory.adorn", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "build 3ddf279+", 1, true) ~= nil).toBeTrue()

		local factory = fs.readFile("src/ReplicatedStorage/Shared/ModelFactory.luau")
		expect(string.find(factory, "ShardfallHitbox", 1, true) ~= nil).toBeTrue()
		expect(string.find(factory, "root.Transparency = 1", 1, true) ~= nil).toBeTrue()
	end)
end)
