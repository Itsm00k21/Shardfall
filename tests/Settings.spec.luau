--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")

describe("Settings", function()
	it("fills defaults and clamps the saved ranges", function()
		local fresh = Settings.normalize(nil)
		expect(fresh.graphics.quality).toEqual("auto")
		expect(fresh.rolls.animation).toEqual("full")
		expect(fresh.controls.hotkeys.hero).toEqual("C")
		expect(fresh.controls.hotkeys.market).toEqual("M")
		expect(fresh.hud.scale).toEqual(1)
		local patched = Settings.normalize({
			hud = { scale = 9 },
			graphics = { quality = "HIGH", fpsCap = 15, vfx = 4 },
			rolls = { animation = "short", skipAt = "epic" },
			camera = { shake = false, flash = "reduced", fov = 200 },
			access = { holdToTap = true, textScale = 0.2 },
		})
		expect(patched.hud.scale).toEqual(1.25)
		expect(patched.graphics.quality).toEqual("high")
		expect(patched.graphics.fpsCap).toEqual(60)
		expect(patched.graphics.vfx).toEqual(1)
		expect(patched.rolls.animation).toEqual("short")
		expect(patched.rolls.skipAt).toEqual("epic")
		expect(patched.rolls.autoJunk).toEqual("ask")
		expect(patched.rolls.junkBelow).toEqual("Rare")
		expect(fresh.rolls.autoJunk).toEqual("ask")
		expect(fresh.rolls.junkBelow).toEqual("Rare")
		local junk = Settings.normalize({
			rolls = { autoJunk = "SALVAGE", junkBelow = "epic" },
		})
		expect(junk.rolls.autoJunk).toEqual("salvage")
		expect(junk.rolls.junkBelow).toEqual("Epic")
		expect(patched.camera.shake).toEqual(false)
		expect(patched.camera.fov).toEqual(90)
		expect(patched.access.holdToTap).toEqual(true)
		expect(patched.access.textScale).toEqual(1)
	end)

	it("skips a cutscene at the saved rarity and never stretches a paid roll", function()
		local settings = Settings.default()
		expect(Settings.skipsCutscene(settings, "Legendary")).toEqual(true)
		expect(Settings.skipsCutscene(settings, "Epic")).toEqual(false)
		expect(Settings.rollDuration(settings)).toEqual(1.65)
		settings.rolls.animation = "short"
		expect(Settings.rollDuration(settings) < 1.65).toBeTrue()
		settings.rolls.animation = "instant"
		expect(Settings.rollDuration(settings)).toEqual(0)
		expect(Settings.skipsCutscene(settings, "Common")).toEqual(true)
	end)

	it("stores settings on a version 21 profile", function()
		expect(Schema.VERSION).toEqual(21)
		local profile = Schema.template()
		expect(profile.uiSettings.hud.scale).toEqual(1)
		local migrated = Schema.migrate({ schemaVersion = 20, gold = 4 })
		expect(migrated.uiSettings.controls.hotkeys.bag).toEqual("B")
		expect(migrated.gold).toEqual(4)
		expect(migrated.schemaVersion).toEqual(21)
	end)
end)
