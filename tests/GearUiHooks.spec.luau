--!strict

--[[
	Ghost's hookups for Echo's gear stages (#387/#388/#389): BagTools in
	the Bag, upgrade-boosted stats in the details pane, the Shard Core on
	a selected weapon, "Salvage now" on a bag-full refusal, and the merge
	line on the reveal card. Every flag is restored when a test ends.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local BagCompare = require("../src/ReplicatedStorage/Shared/BagCompare")
local GearHooks = require("../src/ReplicatedStorage/Shared/GearHooks")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local GuiFake = require("./GuiFake")

local FLAGS = { "upgradeScale", "gearSalvage", "shardCore", "equip", "gearLevels" }

local function withFlags(on: { [string]: boolean }, fn: () -> ())
	local saved = {}
	for _, id in ipairs(FLAGS) do
		saved[id] = LaunchGate.SHOW[id]
		LaunchGate.SHOW[id] = on[id] == true
	end
	local ok, err = pcall(fn)
	for _, id in ipairs(FLAGS) do
		LaunchGate.SHOW[id] = saved[id]
	end
	if not ok then
		error(err, 0)
	end
end

local function weapon(uid: string, name: string, upgrade: number?)
	return {
		uid = uid,
		name = name,
		rarity = "Rare",
		kind = "Weapon",
		templateId = uid,
		quality = 0.5,
		upgrade = upgrade,
		stats = {
			{ id = "damage", value = 20 },
		},
	}
end

local function profile()
	return {
		level = 20,
		xp = 0,
		classId = "warden",
		classXp = { warden = 1800 },
		shardTokens = 5,
		gold = 0,
		shardRolls = 0,
		gearEssence = 40,
		shardCores = {},
		inventory = {
			blade = weapon("blade", "Bramble Fang", 2),
			spare = weapon("spare", "Iron Sword", 0),
		},
		pets = {},
		equipped = { weapon = "spare", armor = {} },
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	}
end

local function boot(answer: ((string, ...any) -> any)?)
	local world = GuiFake.world()
	local MenuHub = world.load("MenuHub")
	local calls = { invokes = {}, toasts = {} }
	local hub = MenuHub.start(world.playerGui, {
		invoke = function(name: string, ...: any)
			table.insert(calls.invokes, { name, ... })
			if answer ~= nil then
				local result = answer(name, ...)
				if result ~= nil then
					return result
				end
			end
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
		onToast = function(message: string)
			table.insert(calls.toasts, message)
		end,
	})
	hub.setProfile(profile())
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
	return world, hub, screen, calls
end

local function cardFor(screen: any, name: string): any
	for _, node in ipairs(screen:GetDescendants()) do
		if node.Name == "Card" then
			for _, child in ipairs(node:GetChildren()) do
				if child:IsA("TextLabel") and child.Text == name then
					return node
				end
			end
		end
	end
	return nil
end

local function called(calls: any, name: string, action: string?): { any }
	local out = {}
	for _, call in ipairs(calls.invokes) do
		if call[1] == name and (action == nil or call[2] == action) then
			table.insert(out, call)
		end
	end
	return out
end

local function crack(screen: any)
	local button = GuiFake.findNamed(screen, "Roll")
	GuiFake.emit(button, "Activated")
end

describe("Gear UI hooks: pure text", function()
	it("names a merged dupe and an auto-salvaged drop on the reveal card", function()
		expect(GearHooks.revealNote({ merged = true, levelText = "Bramble Fang ★2 -> ★3" })).toEqual(
			"Bramble Fang ★2 -> ★3"
		)
		expect(GearHooks.revealNote({ merged = true, oldLevel = 5, newLevel = 5, essence = 25 })).toEqual(
			"★5 -> ★5  +25 Essence"
		)
		expect(GearHooks.revealNote({ autoSalvaged = true, essenceGained = 3 })).toEqual(
			"Auto-salvaged  +3 Essence"
		)
		expect(GearHooks.revealNote({ ok = true })).toBeNil()
		expect(GearHooks.bagFull(true, { ok = false, error = "Inventory is full." })).toBeTrue()
		expect(GearHooks.bagFull(true, { ok = false, error = "Not enough tokens." })).toBeFalse()
		expect(GearHooks.nudgeLabel({ token = "t", count = 0, gain = 0 })).toBeNil()
		expect(GearHooks.nudgeLabel({ token = "t", count = 12, gain = 12 })).toEqual(
			"Salvage now  (12 for +12 Essence)"
		)
	end)

	it("boosts compare stats only while upgradeScale is on", function()
		local item = weapon("blade", "Bramble Fang", 2)
		withFlags({}, function()
			expect(BagCompare.statMap(item).damage).toEqual(20)
			expect(BagCompare.boost(item)).toBeNil()
		end)
		withFlags({ upgradeScale = true }, function()
			expect(math.abs(BagCompare.statMap(item).damage - 23.2) < 1e-6).toBeTrue()
			expect((BagCompare.boost(item) :: any).text).toEqual("Upgrade +2  stats x1.16")
			expect(item.stats[1].value).toEqual(20)
		end)
	end)
end)

describe("Gear UI hooks: Bag", function()
	it("shows nothing new while every gear flag is off", function()
		withFlags({}, function()
			local _, hub, screen = boot()
			hub.open("bag")
			GuiFake.activate(cardFor(screen, "Bramble Fang"))
			expect(GuiFake.findNamed(screen, "SalvageTools")).toBeNil()
			expect(GuiFake.findNamed(screen, "Stat_boost")).toBeNil()
			expect(GuiFake.findNamed(screen, "CoreHost")).toBeNil()
		end)
	end)

	it("mounts BagTools behind gearSalvage and applies the server profile", function()
		withFlags({ gearSalvage = true }, function()
			local after = profile()
			after.inventory.spare = nil
			after.gearEssence = 41
			local _, hub, screen, calls = boot(function(name: string, action: any)
				if name == "GearSalvage" and action == "salvage" then
					return {
						ok = true,
						message = "Salvaged 1 for 1 Essence.",
						gearEssence = 41,
						profile = after,
					}
				end
				if name == "GearSalvage" then
					return { ok = true, gearEssence = 40 }
				end
				return nil
			end)
			hub.open("bag")
			local toggle = GuiFake.findNamed(screen, "SalvageTools")
			expect(toggle ~= nil).toBeTrue()
			expect(GuiFake.findNamed(screen, "BagTools")).toBeNil()
			GuiFake.activate(toggle)
			local tools = GuiFake.findNamed(screen, "BagTools")
			expect(tools ~= nil).toBeTrue()
			expect(#called(calls, "GearSalvage", "state")).toEqual(1)
			-- The worn Iron Sword cannot be picked; the Fang can.
			local list = tools:FindFirstChild("List")
			GuiFake.activate(list:FindFirstChild("blade"))
			GuiFake.activate(tools:FindFirstChild("SalvageSelected"))
			local sent = called(calls, "GearSalvage", "salvage")
			expect(#sent).toEqual(1)
			expect(sent[1][3].uids).toEqual({ "blade" })
			expect(tools:FindFirstChild("Status").Text).toEqual("Salvaged 1 for 1 Essence.")
		end)
	end)

	it("shows the upgrade boost and the Shard Core on a selected weapon", function()
		withFlags({ upgradeScale = true, shardCore = true }, function()
			local _, hub, screen = boot(function(name: string)
				if name == "GetShardCore" then
					return { ok = true, essence = 40, weapons = {} }
				end
				return nil
			end)
			hub.open("bag")
			GuiFake.activate(cardFor(screen, "Bramble Fang"))
			local boost = GuiFake.findNamed(screen, "Stat_boost")
			expect(boost ~= nil).toBeTrue()
			expect(boost.Text).toEqual("Upgrade +2  stats x1.16")
			expect(GuiFake.findNamed(screen, "Stat_damage").Text).toEqual("Damage  23  +")
			local host = GuiFake.findNamed(screen, "CoreHost")
			expect(host ~= nil).toBeTrue()
			expect(host:FindFirstChild("ShardCore") ~= nil).toBeTrue()
		end)
	end)
end)

describe("Gear UI hooks: Roll tab", function()
	it("offers Salvage now on a bag-full refusal and sends the nudge token", function()
		withFlags({ gearSalvage = true }, function()
			local after = profile()
			local _, hub, screen, calls = boot(function(name: string, action: any)
				if name == "RollShard" then
					return { ok = false, error = "Inventory is full." }
				end
				if name == "GearSalvage" and action == "nudge" then
					return { ok = true, token = "tok-1", count = 12, gain = 12 }
				end
				if name == "GearSalvage" and action == "salvageNow" then
					return { ok = true, message = "Salvaged 12 for 12 Essence.", profile = after }
				end
				return nil
			end)
			hub.open("roll")
			crack(screen)
			local button = GuiFake.findNamed(screen, "SalvageNow")
			expect(button.Visible).toBeTrue()
			expect(button.Text).toEqual("Salvage now  (12 for +12 Essence)")
			-- Nothing is salvaged until the press.
			expect(#called(calls, "GearSalvage", "salvageNow")).toEqual(0)
			GuiFake.activate(button)
			local sent = called(calls, "GearSalvage", "salvageNow")
			expect(#sent).toEqual(1)
			expect(sent[1][3].token).toEqual("tok-1")
			expect(button.Visible).toBeFalse()
			expect(calls.toasts[#calls.toasts]).toEqual("Salvaged 12 for 12 Essence.")
		end)
	end)

	it("keeps Salvage now hidden while gearSalvage is off", function()
		withFlags({}, function()
			local _, hub, screen, calls = boot(function(name: string)
				if name == "RollShard" then
					return { ok = false, error = "Inventory is full." }
				end
				return nil
			end)
			hub.open("roll")
			crack(screen)
			expect(GuiFake.findNamed(screen, "SalvageNow").Visible).toBeFalse()
			expect(#called(calls, "GearSalvage")).toEqual(0)
		end)
	end)

	it("adds the merge line to the reveal card", function()
		withFlags({ gearLevels = true }, function()
			local _, hub, screen = boot(function(name: string)
				if name == "RollShard" then
					return {
						ok = true,
						rarity = "Rare",
						item = weapon("blade", "Bramble Fang", 2),
						merged = true,
						levelText = "Bramble Fang ★2 -> ★3",
						profile = profile(),
					}
				end
				return nil
			end)
			hub.open("roll")
			crack(screen)
			crack(screen)
			local rarity = GuiFake.findNamed(GuiFake.findNamed(screen, "Reveal"), "Rarity")
			expect(rarity ~= nil).toBeTrue()
			expect(rarity.Text).toEqual("Rare  ·  Bramble Fang ★2 -> ★3")
		end)
	end)
end)
