--!strict

local fs = require("@lune/fs")

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
		local rail = GuiFake.findNamed(screen, "Rail")
		expect(rail ~= nil).toBeTrue()
		local names = {}
		for _, child in ipairs(rail:GetChildren()) do
			if child:IsA("TextButton") then
				table.insert(names, child.Name)
				expect(child.Name ~= "Market").toBeTrue()
				expect(child.Name ~= "Pass").toBeTrue()
				local caption = child:FindFirstChild("Caption")
				expect(caption ~= nil).toBeTrue()
				expect(string.find(caption.Text, "Market", 1, true)).toBeNil()
				expect(string.find(caption.Text, "Pass", 1, true)).toBeNil()
			end
		end
		expect(names).toEqual({ "Hero", "Bag", "Pets", "Roll", "Shop", "Settings" })
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
		local settings = GuiFake.findNamed(screen, "Settings")
		local caption = settings:FindFirstChild("Caption")
		expect(caption ~= nil and caption.Text == "Settings").toBeTrue()
		local promptGui = world.playerGui:FindFirstChild("ShardfallPrompt")
		expect(promptGui ~= nil and promptGui.DisplayOrder == 90).toBeTrue()
		local prompt = GuiFake.findNamed(promptGui, "Prompt")
		expect(prompt ~= nil).toBeTrue()
		expect(GuiFake.findNamed(prompt, "Equip") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(prompt, "Keep") ~= nil).toBeTrue()
	end)

	it("hides parked trade, raid, and market settings", function()
		local hub = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		expect(string.find(hub, 'LaunchGate.on("trading")', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'LaunchGate.on("raids")', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'field == "market"', 1, true) ~= nil).toBeTrue()
		local plan = fs.readFile("docs/design/LAUNCH_PLAN.md")
		expect(string.find(plan, "Healing Tonic and a bag slot", 1, true) ~= nil).toBeTrue()
		expect(string.find(plan, "a pet slot.", 1, true)).toBeNil()
	end)
end)
