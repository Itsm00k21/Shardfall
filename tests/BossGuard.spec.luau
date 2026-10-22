--!strict

--[[
	Kevin's Oct 19 playtest: Grandmother Gnarl's gold weak spot sat too high
	and early hits looked like no damage. Body hits already count at the
	armoured fraction; now every boss hit says "Guarded" or "Weak!", and the
	weak spot sits at chest height.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CombatMath = require("../src/ReplicatedStorage/Shared/CombatMath")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")

describe("Boss guard popups", function()
	it("tags armoured, weak, and phase-two hits", function()
		local gnarl = Dungeons.ENEMIES.grandmother_gnarl
		expect(CombatMath.bossTag(1, false, gnarl.armoredMultiplier)).toEqual("Guarded")
		expect(CombatMath.bossTag(1, true, gnarl.armoredMultiplier)).toEqual("Weak!")
		expect(CombatMath.bossTag(2, false, gnarl.armoredMultiplier)).toBeNil()
		expect(CombatMath.bossTag(1, false, 1)).toBeNil()
	end)

	it("never lets a body hit do nothing", function()
		local gnarl = Dungeons.ENEMIES.grandmother_gnarl
		expect(gnarl.armoredMultiplier > 0).toBeTrue()
		expect(CombatMath.bossTaken(20, 1, false, gnarl.armoredMultiplier) >= 1).toBeTrue()
		expect(CombatMath.bossTaken(1, 1, false, gnarl.armoredMultiplier)).toEqual(1)
	end)

	it("sends the tag and the client paints it", function()
		local combat = fs.readFile("src/ServerScriptService/ShardfallServer/CombatService.luau")
		local hud = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau")
		expect(string.find(combat, "tag = CombatMath.bossTag(enemy.phase, enemy.weak, enemy.armoredMultiplier)", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "tag = tag,", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, 'text = text .. " " .. payload.tag', 1, true) ~= nil).toBeTrue()
	end)

	it("keeps the weak spot at chest height", function()
		local factory = fs.readFile("src/ReplicatedStorage/Shared/ModelFactory.luau")
		expect(string.find(factory, 'block("WeakSpot", 1.0, 1.0, 0.25, 0, 1.5, -0.85, GOLD', 1, true) ~= nil).toBeTrue()
	end)
end)
