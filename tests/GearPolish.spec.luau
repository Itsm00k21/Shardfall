--!strict

--[[
	Oct 23 inventory polish (ghost/gear-ui-hooks): Shard Core feed picker
	grouped by item with counts, hover tips that hide on click / view
	change, the small Bag footer on every paint, no salvage list in the
	small Bag, and the Auto-salvage state shown where Kevin will see it.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local GearHooks = require("../src/ReplicatedStorage/Shared/GearHooks")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local GuiFake = require("./GuiFake")

local FLAGS = { "upgradeScale", "gearSalvage", "shardCore", "equip", "gearLevels", "forgeSalvage" }

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

local ALL = { upgradeScale = true, gearSalvage = true, shardCore = true, equip = true, gearLevels = true }

local function weapon(uid: string, name: string, upgrade: number?)
	return {
		uid = uid,
		name = name,
		rarity = "Rare",
		kind = "Weapon",
		templateId = uid,
		quality = 0.5,
		upgrade = upgrade,
		stats = { { id = "damage", value = 20 } },
	}
end

local function profile(extra: { [string]: any }?)
	local inventory = {
		blade = weapon("blade", "Bramble Fang", 2),
		spare = weapon("spare", "Iron Sword", 0),
	}
	for index = 1, 7 do
		local uid = string.format("hammer%d", index)
		local item = weapon(uid, "Beastbone Hammer", 0)
		item.rarity = "Common"
		item.templateId = "hammer"
		inventory[uid] = item
	end
	local out: { [string]: any } = {
		level = 20,
		xp = 0,
		classId = "warden",
		classXp = { warden = 1800 },
		shardTokens = 5,
		gold = 0,
		shardRolls = 0,
		gearEssence = 40,
		shardCores = {},
		inventory = inventory,
		pets = {},
		equipped = { weapon = "spare", armor = {} },
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	}
	for key, value in pairs(extra or {}) do
		out[key] = value
	end
	return out
end

local function boot(extra: { [string]: any }?, answer: ((string, ...any) -> any)?)
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
	hub.setProfile(profile(extra))
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

local function visibleTips(screen: any): number
	local n = 0
	for _, child in ipairs(screen:GetChildren()) do
		if child.Name == "Tip" and child.Visible then
			n += 1
		end
	end
	return n
end

local function anyText(root: any, needle: string): boolean
	for _, node in ipairs(root:GetDescendants()) do
		if (node:IsA("TextLabel") or node:IsA("TextButton")) and string.find(node.Text, needle, 1, true) ~= nil then
			return true
		end
	end
	return false
end

describe("Gear polish: Shard Core picker", function()
	it("groups identical weapons by name, rarity, and core level with counts", function()
		local preview = { weapons = {} }
		for index = 1, 7 do
			table.insert(preview.weapons, {
				uid = "h" .. index,
				name = "Beastbone Hammer",
				rarity = "Common",
				level = 0,
				nextCost = 5,
				canFeed = true,
			})
		end
		table.insert(preview.weapons, { uid = "b", name = "Bramble Fang", rarity = "Rare", level = 2, nextCost = 40 })
		table.insert(preview.weapons, { uid = "h9", name = "Beastbone Hammer", rarity = "Common", level = 1, nextCost = 15 })
		local groups = GearHooks.coreGroups(preview, "b")
		expect(#groups).toEqual(3)
		expect(groups[1].name).toEqual("Bramble Fang")
		expect(groups[1].selected).toBeTrue()
		local hammers = nil
		for _, group in ipairs(groups) do
			if group.name == "Beastbone Hammer" and group.level == 0 then
				hammers = group
			end
		end
		expect(hammers ~= nil).toBeTrue()
		expect(hammers.count).toEqual(7)
		expect(hammers.uid).toEqual("h1")
		expect(hammers.label).toEqual("Beastbone Hammer x7  ·  Core Lv 0")
		expect(GearHooks.coreHeader(2)).toEqual("Shard Core  Lv 2/5")
		expect(GearHooks.coreGroups(nil, nil)).toEqual({})
	end)

	it("feeds only the selected weapon's core after an inline confirm (clip 4)", function()
		withFlags(ALL, function()
			local _, hub, screen, calls = boot(nil, function(name: string, uid: any)
				if name == "FeedShardCore" then
					return { ok = true, essence = 35, level = 1, spent = 5, weapons = {} }
				end
				return nil
			end)
			hub.open("bag")
			GuiFake.activate(cardFor(screen, "Bramble Fang"))
			local card = GuiFake.findNamed(screen, "CoreCard")
			expect(card ~= nil).toBeTrue()
			-- No all-cores list.
			expect(GuiFake.findNamed(card, "CorePicker")).toBeNil()
			for _, node in ipairs(card:GetDescendants()) do
				expect(node.Name ~= "CoreGroup").toBeTrue()
				expect(node:IsA("ScrollingFrame")).toBeFalse()
			end
			local feed = GuiFake.findNamed(card, "CoreFeed")
			expect(feed.Text).toEqual("Feed 5 Essence")
			GuiFake.activate(feed)
			expect(GuiFake.findNamed(card, "CoreConfirm").Visible).toBeTrue()
			for _, call in ipairs(calls.invokes) do
				expect(call[1] ~= "FeedShardCore").toBeTrue()
			end
			GuiFake.activate(GuiFake.findNamed(card, "CoreConfirmFeed"))
			local fed = nil
			for _, call in ipairs(calls.invokes) do
				if call[1] == "FeedShardCore" then
					fed = call
				end
			end
			expect(fed ~= nil).toBeTrue()
			expect(fed[2]).toEqual("blade")
			local toasted = false
			for _, message in ipairs(calls.toasts) do
				if message == "Bramble Fang core Lv 1: +1% crit chance" then
					toasted = true
				end
			end
			expect(toasted).toBeTrue()
			-- The repaint lights the new pip and the perk it unlocked.
			card = GuiFake.findNamed(screen, "CoreCard")
			expect(GuiFake.findNamed(card, "Step1"):GetAttribute("Fresh")).toEqual(true)
			local perk = GuiFake.findNamed(card, "Perk1")
			expect(perk:GetAttribute("Fresh")).toEqual(true)
			expect(perk:GetAttribute("Unlocked")).toEqual(true)
			expect(GuiFake.findNamed(card, "CoreFeed").Text).toEqual("Feed 15 Essence")
		end)
	end)

	it("says the Essence gap instead of feeding when the wallet is short", function()
		withFlags(ALL, function()
			local _, hub, screen, calls = boot({ gearEssence = 3 })
			hub.open("bag")
			GuiFake.activate(cardFor(screen, "Bramble Fang"))
			local feed = GuiFake.findNamed(screen, "CoreFeed")
			expect(feed.Text).toEqual("Feed 5 Essence  (have 3)")
			expect(feed:GetAttribute("CanFeed")).toEqual(false)
			GuiFake.activate(feed)
			expect(GuiFake.findNamed(screen, "CoreConfirm").Visible).toBeFalse()
			for _, call in ipairs(calls.invokes) do
				expect(call[1] ~= "FeedShardCore").toBeTrue()
			end
		end)
	end)
end)

describe("Gear polish: clip 5", function()
	it("draws locked as a gold closed lock on the header and the Bag card", function()
		withFlags(ALL, function()
			local _, hub, screen = boot()
			local data = profile()
			data.inventory.blade.locked = true
			hub.setProfile(data)
			hub.open("bag")
			GuiFake.activate(cardFor(screen, "Bramble Fang"))
			local icon = GuiFake.findNamed(GuiFake.findNamed(screen, "Padlock"), "LockIcon")
			expect(icon:GetAttribute("Locked")).toEqual(true)
			local body = GuiFake.findNamed(icon, "Body")
			expect(body.BackgroundColor3.R > 240 and body.BackgroundColor3.G > 180).toBeTrue()
			local card = cardFor(screen, "Bramble Fang")
			local cardIcon = GuiFake.findNamed(card, "LockIcon")
			expect(cardIcon ~= nil).toBeTrue()
			expect(cardIcon:GetAttribute("Locked")).toEqual(true)
		end)
	end)

	it("shows the star row on every gear card, even at 0 stars", function()
		expect(GearHooks.levelLine({ stars = 0 })).toEqual("☆☆☆☆☆")
		expect(GearHooks.levelLine({})).toEqual("☆☆☆☆☆")
		expect(GearHooks.levelLine({ stars = 1, upgrade = 2 })).toEqual("+2  ★☆☆☆☆")
		expect(GearHooks.levelLine({ stars = 9 })).toEqual("★★★★★")
	end)

	it("shows Hero Crit damage as a percent", function()
		local HeroBoard = require("../src/ReplicatedStorage/Shared/HeroBoard")
		local value = nil
		for _, tile in ipairs(HeroBoard.tiles(profile())) do
			if tile.id == "critDamage" then
				value = tile.value
			end
		end
		expect(value ~= nil and string.match(value, "^%d+%%$") ~= nil).toBeTrue()
	end)
end)

describe("Gear polish: clip 4 detail panel", function()
	it("dims UPGRADE and names the gold gap when gold is short", function()
		withFlags(ALL, function()
			-- Bramble Fang is +2: the next upgrade costs 1,280 gold.
			local _, hub, screen, calls = boot({ gold = 300 })
			hub.open("bag")
			GuiFake.activate(cardFor(screen, "Bramble Fang"))
			local upgrade = GuiFake.findNamed(GuiFake.findNamed(screen, "DetailActions"), "Upgrade")
			expect(upgrade.Text).toEqual("UPGRADE  1,280")
			expect(upgrade:GetAttribute("Short")).toEqual(true)
			expect(upgrade.BackgroundColor3.R < 120).toBeTrue()
			expect(GuiFake.findNamed(screen, "UpgradeShort").Text).toEqual("Need 980 more gold")
			GuiFake.activate(upgrade)
			for _, call in ipairs(calls.invokes) do
				expect(call[1] ~= "UpgradeGear").toBeTrue()
			end
		end)
	end)

	it("shows one equipped state for worn gear", function()
		withFlags(ALL, function()
			local _, hub, screen = boot({ gold = 100000 })
			hub.open("bag")
			GuiFake.activate(cardFor(screen, "Iron Sword"))
			local equip = GuiFake.findNamed(GuiFake.findNamed(screen, "DetailActions"), "DetailEquip")
			expect(equip.Text).toEqual("EQUIPPED")
			local header = GuiFake.findNamed(screen, "CompareHeader")
			expect(header == nil or header.Visible == false).toBeTrue()
			-- Only the detail pane; the grid card keeps its own E state.
			local count = 0
			for _, node in ipairs(GuiFake.findNamed(screen, "Compare"):GetDescendants()) do
				if (node:IsA("TextLabel") or node:IsA("TextButton")) and node.Visible then
					local words = string.lower(node.Text)
					if words == "equipped" or words == "unequip" or words == "this is equipped." then
						count += 1
					end
				end
			end
			expect(count).toEqual(1)
		end)
	end)
end)

describe("Gear polish: tips", function()
	it("hides the hover tip on click, on opening an item, and on a tab change", function()
		withFlags(ALL, function()
			local world, hub, screen = boot()
			hub.open("bag")
			local card = cardFor(screen, "Iron Sword")
			expect(card ~= nil).toBeTrue()
			card.MouseEnter:_emit()
			expect(visibleTips(screen)).toEqual(1)
			world.userInput.InputBegan:Fire({
				KeyCode = world.enum.KeyCode.Unknown,
				UserInputType = world.enum.UserInputType.MouseButton1,
				Position = { X = 0, Y = 0, Z = 0 },
			}, false)
			expect(visibleTips(screen)).toEqual(0)
			card.MouseEnter:_emit()
			GuiFake.activate(card)
			expect(visibleTips(screen)).toEqual(0)
			card = cardFor(screen, "Iron Sword")
			card.MouseEnter:_emit()
			expect(visibleTips(screen)).toEqual(1)
			hub.open("roll")
			expect(visibleTips(screen)).toEqual(0)
		end)
	end)

	it("never pins a tip to the selected card", function()
		withFlags(ALL, function()
			local _, hub, screen = boot()
			hub.open("bag")
			local card = cardFor(screen, "Iron Sword")
			GuiFake.activate(card)
			card = cardFor(screen, "Iron Sword")
			card.MouseEnter:_emit()
			card.MouseLeave:_emit()
			expect(visibleTips(screen)).toEqual(0)
		end)
	end)
end)

describe("Gear polish: small Bag", function()
	it("keeps the footer on every paint and never shows a salvage list", function()
		withFlags(ALL, function()
			local _, hub, screen = boot()
			hub.open("bag")
			expect(GuiFake.findNamed(screen, "BagFoot") ~= nil).toBeTrue()
			GuiFake.activate(cardFor(screen, "Bramble Fang"))
			expect(GuiFake.findNamed(screen, "BagFoot") ~= nil).toBeTrue()
			hub.setProfile(profile())
			expect(GuiFake.findNamed(screen, "BagFoot") ~= nil).toBeTrue()
			expect(anyText(screen, "Salvage tools")).toBeFalse()
			expect(anyText(screen, "Hide salvage")).toBeFalse()
			expect(anyText(screen, "Salvage  Common")).toBeFalse()
			local opens = 0
			for _, node in ipairs(screen:GetDescendants()) do
				if node:IsA("TextButton") and string.gsub(node.Text, "^%s+", "") == "Open full bag" then
					opens += 1
				end
			end
			expect(opens).toEqual(1)
		end)
	end)

	it("shows the item icon, a padlock, and side-by-side EQUIP and UPGRADE", function()
		withFlags(ALL, function()
			local _, hub, screen = boot({ gold = 100000 })
			hub.open("bag")
			GuiFake.activate(cardFor(screen, "Bramble Fang"))
			expect(GuiFake.findNamed(screen, "ItemIcon") ~= nil).toBeTrue()
			-- Clip 5: a drawn lock, grey and open while unlocked.
			local padlock = GuiFake.findNamed(screen, "Padlock")
			local icon = GuiFake.findNamed(padlock, "LockIcon")
			expect(icon:GetAttribute("Locked")).toEqual(false)
			expect(GuiFake.findNamed(icon, "Body").BackgroundColor3.R < 200).toBeTrue()
			local actions = GuiFake.findNamed(screen, "DetailActions")
			local equip = actions:FindFirstChild("DetailEquip")
			local upgrade = actions:FindFirstChild("Upgrade")
			expect(equip.Text).toEqual("EQUIP")
			expect(string.find(upgrade.Text, "UPGRADE", 1, true) ~= nil).toBeTrue()
			-- Dark ink on amber, not white on yellow.
			-- GuiFake keeps Color3 channels in 0..255.
			expect(upgrade.TextColor3.R < 60).toBeTrue()
			expect(upgrade.BackgroundColor3.R > 230).toBeTrue()
			-- The avatar is not in the item pane.
			expect(GuiFake.findNamed(GuiFake.findNamed(screen, "Compare"), "Worn")).toBeNil()
		end)
	end)

	it("puts the auto-salvage warning in the Bag while it is on", function()
		withFlags(ALL, function()
			local _, hub, screen = boot({ autoSalvage = true, autoSalvageRarity = "Uncommon" })
			hub.open("bag")
			local warn = GuiFake.findNamed(screen, "AutoWarn")
			expect(warn ~= nil).toBeTrue()
			expect(string.find(warn.Text, "Auto-salvage ON: Uncommons and below", 1, true) ~= nil).toBeTrue()
			hub.setProfile(profile())
			expect(GuiFake.findNamed(screen, "AutoWarn")).toBeNil()
		end)
	end)
end)

describe("Gear polish: auto pill", function()
	it("reads the real auto-salvage state", function()
		local text, on = GearHooks.autoPill({ autoSalvage = true, autoSalvageRarity = "Uncommon" })
		expect(text).toEqual("⚠ Auto-salvage ON: Uncommons and below")
		expect(on).toBeTrue()
		text, on = GearHooks.autoPill({ autoSalvage = false, autoSalvageRarity = "Uncommon" })
		expect(text).toEqual("Auto-salvage: Off")
		expect(on).toBeFalse()
		expect((GearHooks.autoPill(nil))).toEqual("Auto-salvage: Off")
	end)

	it("puts the pill first in the full inventory header, amber while on", function()
		withFlags(ALL, function()
			local world = GuiFake.world()
			local GearBar = world.load("GearBar")
			local parent = world.playerGui
			local current: any = profile({ autoSalvage = true, autoSalvageRarity = "Uncommon" })
			local gear = GearBar.mount(parent, {
				invoke = function(): any
					return { ok = true }
				end,
				getProfile = function(): any
					return current
				end,
				onChanged = function() end,
				onStatus = function() end,
			})
			gear.refresh()
			local auto = GuiFake.findNamed(parent, "AutoSalvage")
			expect(auto.LayoutOrder < GuiFake.findNamed(parent, "Essence").LayoutOrder).toBeTrue()
			expect(auto.Text).toEqual("Auto-salvage: ≤ Uncommon  ⚙")
			expect(auto:GetAttribute("AutoOn")).toBeTrue()
			expect(GuiFake.findNamed(auto, "AutoMark").Visible).toBeTrue()
			current = profile()
			gear.refresh()
			expect(auto:GetAttribute("AutoOn")).toBeFalse()
			expect(GuiFake.findNamed(auto, "AutoMark").Visible).toBeFalse()
		end)
	end)
end)

describe("Gear polish: clip 6 Pets page", function()
	local function pets()
		return {
			fox = { uid = "fox", name = "Moss Fox", kind = "Pet", rarity = "Common", stars = 2 },
			owl = { uid = "owl", name = "Dusk Owl", kind = "Pet", rarity = "Rare", locked = true },
		}
	end

	local function petCard(screen: any, uid: string): any
		for _, node in ipairs(screen:GetDescendants()) do
			if node.Name == "PetCard" and node:GetAttribute("Uid") == uid then
				return node
			end
		end
		return nil
	end

	local function invoked(calls: any, name: string): { any }?
		for _, call in ipairs(calls.invokes) do
			if call[1] == name then
				return call
			end
		end
		return nil
	end

	it("gives pet cards the star row and the padlock, and flips the lock", function()
		withFlags(ALL, function()
			local _, hub, screen, calls = boot({ pets = pets() })
			hub.open("pets")
			local fox = petCard(screen, "fox")
			expect(fox ~= nil).toBeTrue()
			expect(GuiFake.findNamed(fox, "Stars").Text).toEqual("★★☆☆☆")
			expect(GuiFake.findNamed(fox, "Lock"):GetAttribute("Locked")).toEqual(false)
			local owl = petCard(screen, "owl")
			expect(GuiFake.findNamed(owl, "Stars").Text).toEqual("☆☆☆☆☆")
			expect(GuiFake.findNamed(owl, "Lock"):GetAttribute("Locked")).toEqual(true)
			GuiFake.activate(GuiFake.findNamed(fox, "Lock"))
			local call = invoked(calls, "SetItemLock")
			expect(call ~= nil and call[2] == "fox" and call[3] == true).toBeTrue()
			expect(GuiFake.findNamed(petCard(screen, "fox"), "Lock"):GetAttribute("Locked")).toEqual(
				true
			)
		end)
	end)

	it("shows one EQUIPPED state once a pet is worn, and a second tap unequips", function()
		withFlags(ALL, function()
			local _, hub, screen, calls = boot({ pets = pets() })
			hub.open("pets")
			GuiFake.activate(petCard(screen, "fox"))
			local equip = GuiFake.findNamed(screen, "PetEquip")
			expect(equip.Text).toEqual("EQUIP")
			GuiFake.activate(equip)
			expect(invoked(calls, "EquipItem") ~= nil).toBeTrue()
			equip = GuiFake.findNamed(screen, "PetEquip")
			expect(equip.Text).toEqual("EQUIPPED")
			expect(equip:GetAttribute("Worn")).toEqual(true)
			GuiFake.activate(equip)
			expect(equip.Text).toEqual("Tap again to unequip")
			expect(invoked(calls, "UnequipItem")).toBeNil()
			GuiFake.activate(equip)
			local call = invoked(calls, "UnequipItem")
			expect(call ~= nil and call[2] == "fox").toBeTrue()
			expect(GuiFake.findNamed(screen, "PetEquip").Text).toEqual("EQUIP")
		end)
	end)
end)

describe("Gear polish: clip 7 intro card", function()
	local function start(answer: (string) -> any)
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local calls = {}
		local applied = {}
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function(name: string, action: string)
			table.insert(calls, { name, action })
			return answer(action)
		end, function(result: any)
			table.insert(applied, result)
		end)
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		return OnboardHud, onboard, calls, applied
	end

	local function textHas(root: any, needle: string): boolean
		for _, node in ipairs(root:GetDescendants()) do
			if node:IsA("TextLabel") and string.find(node.Text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	it("hints instead of dead-clicking Continue at the class step", function()
		local OnboardHud, onboard, calls = start(function()
			return { ok = false, error = "Try it in the world first." }
		end)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		local continue = GuiFake.findNamed(onboard, "Continue")
		expect(continue.Parent.Visible).toEqual(true)
		GuiFake.activate(continue)
		expect(#calls).toEqual(0)
		expect(textHas(onboard, "press Choose on a class")).toBeTrue()
		-- The same push keeps the hint up; a new step replaces it.
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		expect(textHas(onboard, "press Choose on a class")).toBeTrue()
		expect(OnboardHud.continueHint("open")).toBeNil()
		expect(OnboardHud.continueHint("haven")).toBeNil()
	end)

	it("closes on Skip even when the server does not answer ok", function()
		local OnboardHud, onboard, calls = start(function()
			return { ok = false, error = "Could not save." }
		end)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		local skip = GuiFake.findNamed(onboard, "Skip")
		GuiFake.activate(skip)
		expect(skip.Parent.Visible).toEqual(false)
		expect(GuiFake.findNamed(onboard, "OnboardGoals").Visible).toEqual(false)
		expect(calls[1][2]).toEqual("skip")
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		expect(skip.Parent.Visible).toEqual(false)
	end)

	it("applies the skip answer so the starter kit lands at once", function()
		local OnboardHud, onboard, _, applied = start(function()
			return { ok = true, profile = { onboardDone = true } }
		end)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "open" })
		GuiFake.activate(GuiFake.findNamed(onboard, "Skip"))
		expect(#applied).toEqual(1)
	end)

	it("backs the goals with a panel and hides card and goals under an open menu", function()
		local OnboardHud, onboard = start(function()
			return { ok = true }
		end)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		local panel = GuiFake.findNamed(onboard, "OnboardGoals")
		local card = GuiFake.findNamed(onboard, "Continue").Parent
		expect(panel.Visible).toEqual(true)
		expect(panel.BackgroundTransparency < 0.5).toBeTrue()
		expect(
			string.find(GuiFake.findNamed(panel, "GoalText").Text, "Choose a class", 1, true) ~= nil
		).toBeTrue()
		OnboardHud.setCovered("hub", true)
		expect(card.Visible).toEqual(false)
		expect(panel.Visible).toEqual(false)
		OnboardHud.setCovered("inventory", true)
		OnboardHud.setCovered("hub", false)
		expect(card.Visible).toEqual(false)
		OnboardHud.setCovered("inventory", false)
		expect(card.Visible).toEqual(true)
		expect(panel.Visible).toEqual(true)
	end)

	it("puts the goals beside the card on a wide screen, clear of the character", function()
		local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
		local world = GuiFake.world()
		local OnboardHud = world.load("OnboardHud")
		local wide = HudLayout.onboard(1482, 669)
		local x, y, w, h = OnboardHud.goalRect(wide, 1482, 5)
		expect(x >= wide.card.x + wide.card.w).toBeTrue()
		expect(y).toEqual(wide.card.y)
		expect(x + w <= 1482 - 16).toBeTrue()
		expect(h >= 5 * 17).toBeTrue()
		local phone = HudLayout.onboard(667, 375)
		local px, py = OnboardHud.goalRect(phone, 667, 5)
		expect(px).toEqual(phone.tracker.x)
		expect(py).toEqual(phone.tracker.y)
	end)
end)
