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
			"chests",
			"paid",
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

	it("refuses every parked remote before the handler can write", function()
		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local map = between(remotes, "local PARKED_ACTION", "local function guard")
		local guard = between(remotes, "local function guard", "local function validUid")
		local closed = string.find(guard, '"That is closed."', 1, true)
		local call = string.find(guard, "xpcall(callback", 1, true)
		expect(closed ~= nil and call ~= nil and (closed :: number) < (call :: number)).toBeTrue()
		local parked = {
			{ "Salvage", "forgeSalvage" },
			{ "BulkSalvage", "forgeSalvage" },
			{ "FusePet", "petEvolution" },
			{ "Trade", "trading" },
			{ "Market", "market" },
			{ "ClaimPass", "pass" },
			{ "PremiumPass", "pass" },
			{ "StartDailyBoss", "pass" },
			{ "RaidQueue", "raids" },
			{ "RaidPost", "raids" },
			{ "RaidJoin", "raids" },
			{ "RaidPractice", "raids" },
			{ "RaidBuy", "raids" },
			{ "RaidLeave", "raids" },
			{ "RaidReady", "raids" },
			{ "BuyTravelPass", "extraRealms" },
			{ "BuyDustShard", "extraCurrencies" },
			{ "SetChestOptions", "chests" },
			{ "BuyChestBundle", "chests" },
			{ "BuyForgeBoost", "paid" },
			{ "BuyBoost", "paid" },
			{ "BuyPrism", "paid" },
			{ "RollPaid", "paid" },
			{ "BuyInventoryExpansion", "paid" },
		}
		for _, row in ipairs(parked) do
			local name = row[1]
			local flag = row[2]
			expect(string.find(map, name .. ' = "' .. flag .. '"', 1, true) ~= nil).toBeTrue()
			expect(LaunchGate.on(flag)).toEqual(false)
			expect(string.find(remotes, 'guard(player, "' .. name .. '"', 1, true) ~= nil).toBeTrue()
		end
		expect(string.find(map, "UpgradeGear", 1, true)).toBeNil()
		expect(string.find(map, "ClaimLogin", 1, true)).toBeNil()
		expect(string.find(map, "OpenChest", 1, true)).toBeNil()
		local options = between(remotes, 'functionRemote("SetChestOptions")', 'functionRemote("RollPaid")')
		expect(string.find(options, "ChestService.setOptions", 1, true) ~= nil).toBeTrue()
		expect(string.find(options, "chestSalvageBelow", 1, true)).toBeNil()
		local bundle = between(remotes, 'functionRemote("BuyChestBundle")', 'functionRemote("SetChestOptions")')
		expect(string.find(bundle, "ChestService.buyBundle", 1, true) ~= nil).toBeTrue()
		local boost = between(remotes, 'functionRemote("BuyForgeBoost")', 'functionRemote("BuyGoldShop")')
		expect(string.find(boost, "RollService.buyForgeBoost", 1, true) ~= nil).toBeTrue()
		local craft = between(remotes, 'functionRemote("Craft")', 'functionRemote("Salvage")')
		local reroll = string.find(craft, 'LaunchGate.on("forgeReroll")', 1, true)
		local recipes = string.find(craft, 'LaunchGate.on("forgeCraft")', 1, true)
		local service = string.find(craft, "CraftService.craft", 1, true)
		expect(reroll ~= nil and recipes ~= nil and service ~= nil).toBeTrue()
		expect((reroll :: number) < (service :: number) and (recipes :: number) < (service :: number)).toBeTrue()
		local loops = between(remotes, 'functionRemote("Loops")', 'functionRemote("RerollDaily")')
		local board = string.find(loops, 'LaunchGate.on("leaderboards")', 1, true)
		local drop = string.find(loops, "result.leaderboard = nil", 1, true)
		local refresh = string.find(loops, "LoopService.refresh", 1, true)
		expect(refresh ~= nil and board ~= nil and drop ~= nil).toBeTrue()
		expect((refresh :: number) < (board :: number) and (board :: number) < (drop :: number)).toBeTrue()
		expect(string.find(remotes, 'functionRemote("Guild"', 1, true)).toBeNil()
		expect(string.find(remotes, 'functionRemote("Relic"', 1, true)).toBeNil()
		expect(string.find(remotes, 'functionRemote("Leaderboard"', 1, true)).toBeNil()
	end)

	it("hides the parked chest tab, Forge Boost, and the leftover Forge labels", function()
		local ui = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
		local chests = string.find(ui, 'callbacks.onChests ~= nil and LaunchGate.on("chests")', 1, true)
		local chestButton = string.find(ui, 'makeButton(panel, "Chests"', 1, true)
		expect(chests ~= nil and chestButton ~= nil and (chests :: number) < (chestButton :: number)).toBeTrue()
		local boost = string.find(ui, 'makeButton(craftPage, "Forge Boost"', 1, true)
		local boostGate = string.find(ui, 'forgeBoostButton.Visible = LaunchGate.on("paid")', 1, true)
		expect(boost ~= nil and boostGate ~= nil and (boost :: number) < (boostGate :: number)).toBeTrue()
		local materials = string.find(ui, 'makeButton(forgeTabs, "Materials"', 1, true)
		local materialsGate = string.find(ui, 'materialTabButton.Visible = LaunchGate.on("forgeCraft")', 1, true)
		expect(materials ~= nil and materialsGate ~= nil and (materials :: number) < (materialsGate :: number)).toBeTrue()
		expect(string.find(ui, 'makeButton(tabRow, "Forge"', 1, true) ~= nil).toBeTrue()
		expect(string.find(ui, 'makeButton(tabRow, "Craft"', 1, true)).toBeNil()
		local client = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local gate = string.find(client, 'not LaunchGate.on("chests")', 1, true)
		local open = string.find(client, 'inventory.openTab("chests")', 1, true)
		expect(gate ~= nil and open ~= nil and (gate :: number) < (open :: number)).toBeTrue()
		local bag = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/InventoryHud.luau")
		expect(string.find(bag, 'tab ~= "chests" or LaunchGate.on("chests")', 1, true) ~= nil).toBeTrue()
		expect(string.find(bag, 'tab == "chests" and not LaunchGate.on("chests")', 1, true) ~= nil).toBeTrue()
		local haven = fs.readFile("src/ServerScriptService/ShardfallServer/HavenBuilder.luau")
		expect(string.find(haven, 'promptOn(forge, "Forge", "Upgrade gear", "craft", nil)', 1, true) ~= nil).toBeTrue()
		expect(string.find(haven, "Craft, upgrade, reroll", 1, true)).toBeNil()
		expect(LaunchGate.on("chests")).toEqual(false)
		expect(LaunchGate.on("paid")).toEqual(false)
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
