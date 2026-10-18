--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

describe("LaunchGate", function()
	it("keeps every parked switch off", function()
		local flags = {
			"raids",
			"trading",
			"market",
			"pass",
			"petEvolution",
			"bossPets",
			"relicSets",
			"forgeReroll",
			"forgeSalvage",
			"forgeCraft",
			"guilds",
			"leaderboards",
			"extraRealms",
			"extraCurrencies",
		}
		for _, id in ipairs(flags) do
			expect(LaunchGate.on(id)).toEqual(false)
		end
		expect(LaunchGate.on("shop")).toEqual(false)
	end)

	it("hides raids, the market board, and the pass from the hub cycle", function()
		expect(LaunchGate.tabOpen("hero")).toEqual(true)
		expect(LaunchGate.tabOpen("shop")).toEqual(true)
		expect(LaunchGate.tabOpen("raids")).toEqual(false)
		expect(LaunchGate.tabOpen("market")).toEqual(false)
		expect(LaunchGate.tabOpen("pass")).toEqual(false)
		local live = LaunchGate.visibleTabs({
			"hero",
			"bag",
			"pets",
			"roll",
			"raids",
			"market",
			"pass",
			"settings",
		})
		expect(live).toEqual({ "hero", "bag", "pets", "roll", "settings" })
	end)
end)
