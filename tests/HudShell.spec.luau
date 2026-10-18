--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local GuiFake = require("./GuiFake")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

describe("Hud shell", function()
	it("applies a profile when every parked launch element is absent", function()
		local parked = 0
		for _, on in pairs(LaunchGate.SHOW) do
			parked += 1
			expect(on).toEqual(false)
		end
		expect(parked >= 14).toBeTrue()

		local world = GuiFake.world()
		local HudShell = world.load("HudShell")
		local shell = HudShell.start(world.playerGui, {
			onHero = function() end,
			onBag = function() end,
			onRoll = function() end,
			onPets = function() end,
			onShop = function() end,
			onSettings = function() end,
		})
		local screen = world.playerGui:FindFirstChild("ShardfallHud")
		expect(screen ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "Market")).toBeNil()
		expect(GuiFake.findNamed(screen, "Pass")).toBeNil()
		expect(GuiFake.findNamed(screen, "Raids")).toBeNil()
		local mastery = GuiFake.findNamed(screen, "Mastery")
		expect(mastery ~= nil).toBeTrue()
		expect(mastery.Visible).toEqual(false)
		expect(GuiFake.findNamed(screen, "Shop") ~= nil).toBeTrue()

		local scale = GuiFake.findNamed(screen, "ShellScale")
		expect(scale.Scale).toEqual(1)
		local gold = GuiFake.findNamed(screen, "Gold")
		local before = gold.TextSize
		shell.setProfile({
			level = 4,
			classId = "warden",
			gold = 40,
			shardTokens = 3,
			xp = 12,
			xpToNext = 50,
			eggs = 2,
			dailyBossReady = true,
			uiSettings = {
				hud = { scale = 1.2, hidden = false },
				access = { textScale = 1.4 },
			},
		})
		expect(scale.Scale).toEqual(1.2)
		expect(gold.Text).toEqual("Gold 40")
		expect(gold.TextSize > before).toBeTrue()
		expect(GuiFake.findNamed(screen, "Xp").Text).toEqual("XP  12 / 50")
		expect(mastery.Visible).toEqual(false)
		local pets = GuiFake.findNamed(screen, "Pets")
		local petsDot = pets:FindFirstChild("Dot")
		expect(petsDot ~= nil and petsDot.Visible == true).toBeTrue()
	end)
end)
