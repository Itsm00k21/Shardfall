--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

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

	it("rejects Salvage, the dust shop, and the daily boss while gated", function()
		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local map = between(remotes, "local PARKED_ACTION", "local function guard")
		expect(string.find(map, 'Salvage = "forgeSalvage"', 1, true) ~= nil).toBeTrue()
		expect(string.find(map, 'BuyDustShard = "extraCurrencies"', 1, true) ~= nil).toBeTrue()
		expect(string.find(map, 'StartDailyBoss = "pass"', 1, true) ~= nil).toBeTrue()
		expect(string.find(map, "UpgradeGear", 1, true)).toBeNil()
		local guard = between(remotes, "local function guard", "local function validUid")
		local closed = string.find(guard, '"That is closed."', 1, true)
		local call = string.find(guard, "xpcall(callback", 1, true)
		expect(closed ~= nil and call ~= nil and (closed :: number) < (call :: number)).toBeTrue()
		expect(LaunchGate.on("forgeSalvage")).toEqual(false)
		expect(LaunchGate.on("extraCurrencies")).toEqual(false)
		expect(LaunchGate.on("pass")).toEqual(false)
	end)

	it("does not salvage a roll or offer salvage in the junk cycle", function()
		local hub = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local paint = between(hub, "function hubFn.paintResult", "function hubFn.chainAllowed")
		local gate = string.find(paint, 'LaunchGate.on("forgeSalvage")', 1, true)
		local invoke = string.find(paint, 'hooks.invoke, "Salvage"', 1, true)
		expect(gate ~= nil and invoke ~= nil and (gate :: number) < (invoke :: number)).toBeTrue()
		local junk = between(hub, 'cycle("Junk  "', 'cycle("Below  "')
		expect(string.find(junk, '{ "ask", "keep", "salvage" }', 1, true)).toBeNil()
		local offer = string.find(junk, 'LaunchGate.on("forgeSalvage")', 1, true)
		local word = string.find(junk, '"salvage"', 1, true)
		expect(offer ~= nil and word ~= nil and (offer :: number) < (word :: number)).toBeTrue()
	end)

	it("hides the dust shop and the dust balance while extra currencies are off", function()
		local hud = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/InventoryHud.luau")
		local chests = between(hud, "local function chestActions", "local function fitBagText")
		local keys = string.find(chests, "Shard Keys", 1, true)
		local gate = string.find(chests, 'LaunchGate.on("extraCurrencies")', 1, true)
		local dust = string.find(chests, "Shard Dust", 1, true)
		local shop = string.find(chests, '"Dust shop"', 1, true)
		expect(keys ~= nil and gate ~= nil and (keys :: number) < (gate :: number)).toBeTrue()
		expect(dust ~= nil and (gate :: number) < (dust :: number)).toBeTrue()
		local shopGate = string.find(chests, 'LaunchGate.on("extraCurrencies")', (dust :: number), true)
		expect(shopGate ~= nil and shop ~= nil and (shopGate :: number) < (shop :: number)).toBeTrue()
		expect(string.find(chests, "Daily login", 1, true) ~= nil).toBeTrue()
	end)

	it("lets a stale Forge-arrow wait leave the live arrow alone", function()
		local haven = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HavenClient.luau")
		local added = string.find(haven, "CharacterAdded:Connect", 1, true)
		expect(added ~= nil).toBeTrue()
		local body = string.sub(haven, added :: number, (added :: number) + 500)
		local stale = string.find(body, "Players.LocalPlayer.Character ~= character", 1, true)
		local clear = string.find(body, "clearArrow()", 1, true)
		local show = string.find(body, "showArrow()", 1, true)
		expect(stale ~= nil and clear ~= nil and show ~= nil).toBeTrue()
		expect((stale :: number) < (clear :: number) and (clear :: number) < (show :: number)).toBeTrue()
		expect(string.find(body, "seen", 1, true)).toBeNil()
		local showFn = between(haven, "local function showArrow()", "Players.LocalPlayer.CharacterAdded")
		local wipe = string.find(showFn, "clearArrow()", 1, true)
		local off = string.find(showFn, "if not crafting then", 1, true)
		expect(wipe ~= nil and off ~= nil and (wipe :: number) < (off :: number)).toBeTrue()
	end)

	it("rejects Raid Finder and Practice Grove while raids are closed", function()
		local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
		local queue = between(raid, "function RaidService.queue", "function RaidService.board")
		local queueGate = string.find(queue, 'LaunchGate.on("raids")', 1, true)
		local queueClosed = string.find(queue, '"That is closed."', 1, true)
		local sweep = string.find(queue, "sweep(now)", 1, true)
		expect(queueGate ~= nil and queueClosed ~= nil and sweep ~= nil).toBeTrue()
		expect((queueGate :: number) < (queueClosed :: number)).toBeTrue()
		expect((queueClosed :: number) < (sweep :: number)).toBeTrue()
		local practice = between(raid, "function RaidService.practice", "function RaidService.buy")
		local practiceGate = string.find(practice, 'LaunchGate.on("raids")', 1, true)
		local practiceClosed = string.find(practice, '"That is closed."', 1, true)
		local profile = string.find(practice, "DataService.get(player)", 1, true)
		expect(practiceGate ~= nil and practiceClosed ~= nil and profile ~= nil).toBeTrue()
		expect((practiceGate :: number) < (practiceClosed :: number)).toBeTrue()
		expect((practiceClosed :: number) < (profile :: number)).toBeTrue()
		expect(LaunchGate.on("raids")).toEqual(false)
	end)

	it("names the Haven market prompt from the live Gold shop offers", function()
		local client = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		expect(string.find(client, "Gold shop. A Healing Tonic and a bag slot.", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "and a pet slot.", 1, true)).toBeNil()
	end)
end)
