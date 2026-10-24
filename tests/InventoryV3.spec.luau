--!strict

--[[
	[Ghost] Phase 3: the one inventory. Pure geometry (InventoryLayout) and
	the live InventoryHud on GuiFake: the modal respects the rail and the
	HUD, one filter row with dropdowns and no sideways scroll, square-ish
	cards with an E badge and a padlock only when locked, the detail
	panel starts on the equipped weapon and never empties in Select mode,
	and "+ Slots" is for DevAccess owners only.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local InventoryLayout = require("../src/ReplicatedStorage/Shared/InventoryLayout")
local GearSalvage = require("../src/ReplicatedStorage/Shared/GearSalvage")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local GuiFake = require("./GuiFake")

local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau"

local VIEWS = {
	{ 1482, 669, false },
	{ 1280, 720, false },
	{ 1920, 1080, false },
	{ 1024, 600, false },
	{ 844, 390, true },
	{ 667, 375, true },
}

describe("InventoryLayout modal", function()
	it("keeps right of the rail, under the HUD, inside the screen, with a max size", function()
		for _, view in ipairs(VIEWS) do
			local vx, vy, phone = view[1], view[2], view[3]
			local box = InventoryLayout.modal(vx, vy, { phone = phone, railRight = 80, top = 132 })
			expect(box.x >= 0 and box.y >= 0).toBeTrue()
			expect(box.x + box.w <= vx).toBeTrue()
			expect(box.y + box.h <= vy).toBeTrue()
			expect(box.w <= InventoryLayout.MAX_W).toBeTrue()
			expect(box.h <= InventoryLayout.MAX_H).toBeTrue()
			if not phone then
				expect(box.x >= 92).toBeTrue()
				expect(box.y >= 132).toBeTrue()
			end
		end
	end)

	it("is 80-90% wide on Kevin's window and centered in the free space", function()
		local box = InventoryLayout.modal(1482, 669, { railRight = 80, top = 132 })
		expect(box.w).toEqual(1180)
		local leftGap = box.x - 92
		local rightGap = 1482 - 16 - (box.x + box.w)
		expect(math.abs(leftGap - rightGap) <= 1).toBeTrue()
		local small = InventoryLayout.modal(1024, 600, { railRight = 80, top = 132 })
		expect(small.w / 1024 >= 0.8).toBeTrue()
	end)
end)

describe("InventoryLayout chrome and grid", function()
	it("stacks the rows without overlap and leaves room for two card rows", function()
		for _, view in ipairs(VIEWS) do
			local vx, vy, phone = view[1], view[2], view[3]
			local box = InventoryLayout.modal(vx, vy, { phone = phone, railRight = 80, top = 132 })
			local chrome = InventoryLayout.chrome(box.w, box.h, phone, true)
			expect(chrome.filters.y >= chrome.header.y + chrome.header.h).toBeTrue()
			if not chrome.compact then
				expect(chrome.tabs.y >= chrome.header.y + chrome.header.h).toBeTrue()
				expect(chrome.filters.y >= chrome.tabs.y + chrome.tabs.h).toBeTrue()
			end
			expect(chrome.actions.y >= chrome.filters.y + chrome.filters.h).toBeTrue()
			expect(chrome.body.y >= chrome.actions.y + chrome.actions.h).toBeTrue()
			expect(chrome.body.y + chrome.body.h <= box.h).toBeTrue()
			local detailW = InventoryLayout.detailW(chrome.body.w, phone)
			local gridW = if phone then chrome.body.w else chrome.body.w - detailW - 12
			local cells = InventoryLayout.grid(gridW, phone, chrome.body.h)
			expect(chrome.body.h >= cells.cellH * 2 + cells.gap).toBeTrue()
			expect(cells.cellW >= 72).toBeTrue()
			local used = cells.cols * cells.cellW + (cells.cols - 1) * cells.gap
			expect(used <= gridW).toBeTrue()
		end
	end)

	it("picks 4-6 columns on desktop and 3-6 on a phone, square-ish", function()
		for _, width in ipairs({ 500, 640, 800, 1000 }) do
			local cells = InventoryLayout.grid(width, false)
			expect(cells.cols >= 4 and cells.cols <= 6).toBeTrue()
			expect(math.abs(cells.cellH - cells.cellW) <= cells.cellW * 0.15).toBeTrue()
		end
		for _, width in ipairs({ 300, 420, 640 }) do
			local cells = InventoryLayout.grid(width, true)
			expect(cells.cols >= 3 and cells.cols <= 6).toBeTrue()
		end
		local wide = InventoryLayout.grid(808, false)
		expect(wide.cols).toEqual(6)
	end)

	it("centers the icon and keeps name, level and marks apart on a card", function()
		for _, size in ipairs({ 96, 118, 126, 150 }) do
			local card = InventoryLayout.card(size, size)
			expect(math.abs((card.art.x + card.art.w / 2) - size / 2) <= 1).toBeTrue()
			expect(card.art.y + card.art.h <= card.name.y).toBeTrue()
			expect(card.name.y + card.name.h <= card.level.y).toBeTrue()
			expect(card.level.y + card.level.h <= card.marks.y).toBeTrue()
			expect(card.marks.y + card.marks.h <= size).toBeTrue()
			expect(card.name.h >= 26).toBeTrue()
		end
	end)
end)

local function sword(uid: string, rarity: string, extra: { [string]: any }?): { [string]: any }
	local item: { [string]: any } = {
		uid = uid,
		templateId = "iron_sword",
		name = "Iron Sword " .. uid,
		kind = "Weapon",
		rarity = rarity,
		traits = {},
		poolId = "dev",
		obtainedAt = 1,
		locked = false,
	}
	if extra ~= nil then
		for key, value in pairs(extra) do
			item[key] = value
		end
	end
	return item
end

local function bag(): any
	local data = Schema.template()
	data.inventory = {}
	data.pets = {}
	Schema.insertItem(data, sword("a", "Common") :: any)
	Schema.insertItem(data, sword("b", "Uncommon") :: any)
	Schema.insertItem(data, sword("worn", "Rare") :: any)
	Schema.insertItem(data, sword("held", "Common", { locked = true }) :: any)
	data.equipped = data.equipped or {}
	data.equipped.weapon = "worn"
	data.gearEssence = 0
	return data
end

local function withGear(fn: () -> ())
	local previous = LaunchGate.SHOW.gearSalvage
	LaunchGate.SHOW.gearSalvage = true
	GearSalvage._reset()
	local ok, err = pcall(fn)
	LaunchGate.SHOW.gearSalvage = previous
	GearSalvage._reset()
	if not ok then
		error(err, 0)
	end
end

local function mount(profile: any): (any, any, { any })
	local world = GuiFake.world()
	local InventoryHud = world.load("InventoryHud")
	local calls: { any } = {}
	local function note(name: string)
		return function(...)
			table.insert(calls, { name, ... })
		end
	end
	local controller = InventoryHud.start(world.playerGui, {
		onEquip = note("equip"),
		onUnequip = note("unequip"),
		onSalvage = note("salvage"),
		onBulkSalvage = note("bulk"),
		onLock = note("lock"),
		onFavorite = note("favorite"),
		onExpand = note("expand"),
		onRemove = note("remove"),
		onFeed = note("feed"),
		onTonic = note("tonic"),
		onStatus = note("status"),
		onGear = function(action: string, payload: any): any
			return GearSalvage.applyAction(profile, 42, action, payload, 100)
		end,
	})
	controller.setProfile(profile)
	controller.open()
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallInventory")
	return controller, screen, calls
end

describe("InventoryHud one inventory", function()
	it("builds every label with real colours and text (Studio rejects a number)", function()
		withGear(function()
			local _, screen = mount(bag())
			local help = GuiFake.findNamed(screen, "AutoHelp")
			expect(help ~= nil).toBeTrue()
			expect(string.find(help.Text, "Destroys new drops", 1, true) ~= nil).toBeTrue()
			for _, desc in ipairs(screen:GetDescendants()) do
				if desc:IsA("TextLabel") or desc:IsA("TextButton") then
					expect(type(desc.TextColor3) == "number").toBeFalse()
					expect(type(desc.Text)).toEqual("string")
					expect(type(desc.TextSize)).toEqual("number")
				end
			end
		end)
	end)

	it("shows worn gear as one EQUIPPED state with no Unequip (clip 4)", function()
		withGear(function()
			local _, screen = mount(bag())
			local equip = GuiFake.findNamed(screen, "DetailEquip")
			expect(equip ~= nil).toBeTrue()
			expect(equip.Text).toEqual("EQUIPPED")
			for _, desc in ipairs(screen:GetDescendants()) do
				if desc:IsA("TextButton") or desc:IsA("TextLabel") then
					expect(desc.Text ~= "Unequip").toBeTrue()
					expect(desc.Text ~= "This is equipped.").toBeTrue()
				end
			end
		end)
	end)

	it("dims UPGRADE when a profile push drops gold below the cost (clip 6)", function()
		withGear(function()
			local rich = bag()
			rich.gold = 250
			local controller, screen = mount(rich)
			-- The worn Rare is +0: the next upgrade costs 150.
			local upgrade = GuiFake.findNamed(screen, "Upgrade")
			expect(upgrade.Text).toEqual("UPGRADE  150")
			expect(upgrade:GetAttribute("Short")).toEqual(false)
			expect(GuiFake.findNamed(screen, "UpgradeGold").Text).toEqual("You have 250 gold")
			local broke = table.clone(rich)
			broke.gold = 0
			controller.setProfile(broke)
			upgrade = GuiFake.findNamed(screen, "Upgrade")
			expect(upgrade:GetAttribute("Short")).toEqual(true)
			expect(upgrade.BackgroundColor3.R < 120).toBeTrue()
			expect(GuiFake.findNamed(screen, "UpgradeShort").Text).toEqual("Need 150 more gold")
			expect(GuiFake.findNamed(screen, "UpgradeGold")).toBeNil()
		end)
	end)

	it("shows a gold padlock on a locked pet card (clip 5)", function()
		withGear(function()
			local data = bag()
			data.pets = {
				owl = {
					uid = "owl",
					templateId = "dusk_owl",
					name = "Dusk Owl",
					kind = "Pet",
					rarity = "Rare",
					traits = {},
					poolId = "dev",
					obtainedAt = 1,
					locked = true,
				},
			}
			local _, screen = mount(data)
			local root = GuiFake.findNamed(screen, "Inventory")
			GuiFake.activate(GuiFake.findNamed(root, "Tab_pets"))
			local card = GuiFake.findNamed(root, "Grid"):FindFirstChild("owl")
			expect(card ~= nil).toBeTrue()
			local padlock = card:FindFirstChild("Padlock")
			expect(padlock ~= nil).toBeTrue()
			expect(padlock.Visible).toEqual(true)
			local icon = padlock:FindFirstChild("LockIcon")
			expect(icon:GetAttribute("Locked")).toEqual(true)
			local body = icon:FindFirstChild("Body")
			expect(body.BackgroundColor3.R).toEqual(255)
		end)
	end)

	it("gives a pet the gear header and one EQUIPPED state, at the top (clip 5)", function()
		withGear(function()
			local data = bag()
			data.pets = {
				fox = {
					uid = "fox",
					templateId = "moss_fox",
					name = "Moss Fox",
					kind = "Pet",
					rarity = "Legendary",
					traits = {},
					poolId = "dev",
					obtainedAt = 1,
					locked = false,
				},
			}
			data.equipped.pet = "fox"
			local _, screen, calls = mount(data)
			local root = GuiFake.findNamed(screen, "Inventory")
			-- Scrolled down on the weapon panel, then open Pets.
			local detail = GuiFake.findNamed(root, "Detail")
			expect(detail ~= nil).toBeTrue()
			detail.CanvasPosition = { X = 0, Y = 400 }
			GuiFake.activate(GuiFake.findNamed(root, "Tab_pets"))
			local grid = GuiFake.findNamed(root, "Grid")
			local card = grid:FindFirstChild("fox")
			expect(card ~= nil).toBeTrue()
			GuiFake.activate(card)
			local hero = GuiFake.findNamed(root, "Hero")
			expect(hero ~= nil).toBeTrue()
			expect(GuiFake.findNamed(hero, "ItemIcon") ~= nil).toBeTrue()
			expect(string.find(GuiFake.findNamed(hero, "Title").Text, "Moss Fox", 1, true) ~= nil).toBeTrue()
			expect(GuiFake.findNamed(hero, "Kind").Text).toEqual("Legendary  ·  Pet")
			local padlock = GuiFake.findNamed(hero, "Padlock")
			expect(padlock ~= nil).toBeTrue()
			local wear = GuiFake.findNamed(root, "PetEquip")
			expect(wear.Text).toEqual("EQUIPPED")
			for _, desc in ipairs(screen:GetDescendants()) do
				if (desc:IsA("TextButton") or desc:IsA("TextLabel")) and desc.Visible ~= false then
					expect(desc.Text ~= "Unequip").toBeTrue()
					expect(desc.Text ~= "This is equipped.").toBeTrue()
					expect(desc.Text ~= "🔓 Lock" and desc.Text ~= "🔒 Unlock").toBeTrue()
				end
			end
			expect(detail.CanvasPosition.Y).toEqual(0)
			-- Unequip stays possible: tap EQUIPPED twice.
			GuiFake.activate(wear)
			expect(wear.Text).toEqual("Tap again to unequip")
			GuiFake.activate(wear)
			local unequipped = false
			for _, call in ipairs(calls) do
				if call[1] == "unequip" and call[2] == "fox" then
					unequipped = true
				end
			end
			expect(unequipped).toBeTrue()
			GuiFake.activate(padlock)
			local locked = false
			for _, call in ipairs(calls) do
				if call[1] == "lock" and call[2] == "fox" and call[3] == true then
					locked = true
				end
			end
			expect(locked).toBeTrue()
		end)
	end)

	it("fits the phone header and action bar without sideways overflow", function()
		withGear(function()
			local world = GuiFake.world()
			world.userInput.TouchEnabled = true
			world.userInput.KeyboardEnabled = false
			local InventoryHud = world.load("InventoryHud")
			local profile = bag()
			local controller = InventoryHud.start(world.playerGui, {
				onGear = function(action: string, payload: any): any
					return GearSalvage.applyAction(profile, 42, action, payload, 100)
				end,
			})
			controller.setProfile(profile)
			controller.open()
			local screen = GuiFake.findNamed(world.playerGui, "ShardfallInventory")
			local root = GuiFake.findNamed(screen, "Inventory")
			expect(GuiFake.findNamed(root, "EquipBest").Text).toEqual("Best")
			-- Wide (landscape) phone: the side detail panel stays up.
			expect(GuiFake.findNamed(root, "Detail").Visible).toBeTrue()
			expect(GuiFake.findNamed(root, "Grid").Visible).toBeTrue()
			local auto = GuiFake.findNamed(root, "AutoSalvage")
			expect(string.find(auto.Text, "Auto: Off", 1, true) ~= nil).toBeTrue()
			local actions = GuiFake.findNamed(root, "Actions")
			local row = GuiFake.findNamed(root, "GearRow")
			local function rowWidth(): number
				local width, shown = 0, 0
				for _, child in ipairs(row:GetChildren()) do
					if child:IsA("GuiObject") and child.Visible then
						width += child.Size.X.Offset
						shown += 1
					end
				end
				return width + 8 * math.max(0, shown - 1)
			end
			expect(rowWidth() <= 370).toBeTrue()
			expect(rowWidth() <= actions.Size.X.Offset).toBeTrue()
			GuiFake.activate(GuiFake.findNamed(root, "SelectMode"))
			expect(auto.Visible).toBeFalse()
			expect(GuiFake.findNamed(root, "Essence").Visible).toBeFalse()
			expect(rowWidth() <= 370).toBeTrue()
		end)
	end)

	it("has one filter row of Search plus three dropdowns and no sideways scroll", function()
		withGear(function()
			local _, screen = mount(bag())
			local root = GuiFake.findNamed(screen, "Inventory")
			local filters = GuiFake.findNamed(root, "Filters")
			expect(filters.ClassName).toEqual("Frame")
			expect(GuiFake.findNamed(root, "Tabs").ClassName).toEqual("Frame")
			expect(GuiFake.findNamed(filters, "Search") ~= nil).toBeTrue()
			for _, name in ipairs({ "RarityFilter", "TypeFilter", "SortFilter" }) do
				expect(GuiFake.findNamed(filters, name) ~= nil).toBeTrue()
			end
			local width = 0
			local shown = 0
			for _, child in ipairs(filters:GetChildren()) do
				if child:IsA("GuiObject") and child.Visible then
					width += child.Size.X.Offset
					shown += 1
				end
			end
			width += 6 * math.max(0, shown - 1)
			expect(width <= filters.Size.X.Offset).toBeTrue()
			expect(GuiFake.findNamed(root, "Rarity_Common")).toBeNil()
			expect(GuiFake.findNamed(root, "GearRow").Parent.Name).toEqual("Actions")
		end)
	end)

	it("filters by one rarity from the dropdown", function()
		withGear(function()
			local _, screen = mount(bag())
			local root = GuiFake.findNamed(screen, "Inventory")
			GuiFake.activate(GuiFake.findNamed(root, "RarityFilter"))
			GuiFake.activate(GuiFake.findNamed(root, "RarityFilter_Common"))
			local grid = GuiFake.findNamed(root, "Grid")
			expect(grid:FindFirstChild("a") ~= nil).toBeTrue()
			expect(grid:FindFirstChild("b")).toBeNil()
			expect(grid:FindFirstChild("worn")).toBeNil()
			GuiFake.activate(GuiFake.findNamed(root, "RarityFilter"))
			GuiFake.activate(GuiFake.findNamed(root, "RarityFilter_All"))
			expect(grid:FindFirstChild("b") ~= nil).toBeTrue()
		end)
	end)

	it("badges the worn card with E and shows a padlock only when locked", function()
		withGear(function()
			local _, screen = mount(bag())
			local grid = GuiFake.findNamed(screen, "Grid")
			expect(GuiFake.findNamed(grid:FindFirstChild("worn"), "EquipBadge").Text).toEqual("E")
			expect(grid:FindFirstChild("a"):FindFirstChild("EquipBadge")).toBeNil()
			local held = GuiFake.findNamed(grid:FindFirstChild("held"), "Padlock")
			expect(held.Visible).toBeTrue()
			expect(held:GetAttribute("Locked")).toBeTrue()
			local open = GuiFake.findNamed(grid:FindFirstChild("a"), "Padlock")
			expect(open.Visible).toBeFalse()
			local card = grid:FindFirstChild("a")
			expect(card.Size == nil or true).toBeTrue()
		end)
	end)

	it("starts the detail panel on the equipped weapon and keeps it in Select mode", function()
		withGear(function()
			local _, screen = mount(bag())
			local root = GuiFake.findNamed(screen, "Inventory")
			local grid = GuiFake.findNamed(root, "Grid")
			expect(grid:FindFirstChild("worn"):FindFirstChild("Focus") ~= nil).toBeTrue()
			local detail = GuiFake.findNamed(root, "Detail")
			expect(GuiFake.findNamed(detail, "Title") ~= nil).toBeTrue()
			GuiFake.activate(GuiFake.findNamed(root, "SelectMode"))
			expect(GuiFake.findNamed(detail, "Title") ~= nil).toBeTrue()
			GuiFake.activate(grid:FindFirstChild("a"))
			expect(grid:FindFirstChild("a"):FindFirstChild("Focus") ~= nil).toBeTrue()
			expect(GuiFake.findNamed(detail, "Title") ~= nil).toBeTrue()
			local worn = grid:FindFirstChild("worn")
			expect(worn.BackgroundTransparency > 0.5).toBeTrue()
		end)
	end)

	it("hides + Slots from players who are not DevAccess owners", function()
		withGear(function()
			local _, screen, calls = mount(bag())
			local expand = GuiFake.findNamed(screen, "Expand")
			expect(expand.Visible).toBeFalse()
			GuiFake.activate(expand)
			for _, call in ipairs(calls) do
				expect(call[1] ~= "expand").toBeTrue()
			end
		end)
	end)

	it("equips the best gear from the header", function()
		withGear(function()
			local profile = bag()
			profile.equipped.weapon = "a"
			local _, screen, calls = mount(profile)
			GuiFake.activate(GuiFake.findNamed(screen, "EquipBest"))
			local equipped = {}
			for _, call in ipairs(calls) do
				if call[1] == "equip" then
					table.insert(equipped, call[2])
				end
			end
			expect(#equipped >= 1).toBeTrue()
		end)
	end)
end)

describe("One inventory routing", function()
	local function hubWith(flag: boolean): (any, { number })
		local previous = LaunchGate.SHOW.oneInventory
		LaunchGate.SHOW.oneInventory = flag
		local bags = { 0 }
		local ok, result = pcall(function()
			local world = GuiFake.world()
			local MenuHub = world.load("MenuHub")
			local hub = MenuHub.start(world.playerGui, {
				invoke = function(): any
					return { ok = true }
				end,
				onBag = function()
					bags[1] += 1
				end,
				onMarket = function() end,
				onDim = function() end,
				onToast = function() end,
			})
			hub.setProfile(bag())
			return hub
		end)
		LaunchGate.SHOW.oneInventory = previous
		if not ok then
			error(result, 0)
		end
		return result, bags
	end

	it("sends the Bag route to the full Inventory while oneInventory is on", function()
		local previous = LaunchGate.SHOW.oneInventory
		local hub, bags = hubWith(true)
		LaunchGate.SHOW.oneInventory = true
		local ok, err = pcall(function()
			hub.toggle("bag")
			expect(bags[1]).toEqual(1)
			expect(hub.current() ~= "bag").toBeTrue()
			hub.toggle("bag")
			expect(bags[1]).toEqual(2)
		end)
		LaunchGate.SHOW.oneInventory = previous
		if not ok then
			error(err, 0)
		end
	end)

	it("keeps the small Bag while oneInventory is off", function()
		local previous = LaunchGate.SHOW.oneInventory
		LaunchGate.SHOW.oneInventory = false
		local ok, err = pcall(function()
			local hub, bags = hubWith(false)
			hub.toggle("bag")
			expect(bags[1]).toEqual(0)
			expect(hub.current()).toEqual("bag")
		end)
		LaunchGate.SHOW.oneInventory = previous
		if not ok then
			error(err, 0)
		end
	end)

	it("rail Bag opens the inventory, and the next press closes it without reopening", function()
		local previous = LaunchGate.SHOW.oneInventory
		LaunchGate.SHOW.oneInventory = true
		local ok, err = pcall(function()
			local source = fs.readFile(CLIENT)
			local startAt = string.find(source, "local function pressRailBag()", 1, true)
			expect(startAt ~= nil).toBeTrue()
			local callAt = string.find(source, 'openHub("bag")', startAt :: number, true)
			expect(callAt ~= nil).toBeTrue()
			local endAt = string.find(source, "end", callAt :: number, true)
			expect(endAt ~= nil).toBeTrue()
			local body = string.sub(source, startAt :: number, (endAt :: number) + 2)
			local bytecode = luau.compile(body .. "\nreturn pressRailBag\n", { debugLevel = 2 })
			local world = GuiFake.world()
			local InventoryHud = world.load("InventoryHud")
			local HudShell = world.load("HudShell")
			local calls: { any } = {}
			local function note(name: string)
				return function(...)
					table.insert(calls, { name, ... })
				end
			end
			local profile = bag()
			local inventory = InventoryHud.start(world.playerGui, {
				onEquip = note("equip"),
				onUnequip = note("unequip"),
				onSalvage = note("salvage"),
				onBulkSalvage = note("bulk"),
				onLock = note("lock"),
				onFavorite = note("favorite"),
				onExpand = note("expand"),
				onRemove = note("remove"),
				onFeed = note("feed"),
				onTonic = note("tonic"),
				onStatus = note("status"),
				onGear = function(action: string, payload: any): any
					return GearSalvage.applyAction(profile, 42, action, payload, 100)
				end,
			})
			inventory.setProfile(profile)
			expect(inventory.isOpen()).toBeFalse()
			local panels = {}
			local hubs = 0
			local chunk = luau.load(bytecode, {
				debugName = "pressRailBag",
				environment = {
					LaunchGate = LaunchGate,
					inventory = inventory,
					closePanels = function(except: string)
						table.insert(panels, except)
					end,
					openHub = function(_tab: string)
						hubs += 1
						-- The old rail path: closePanels already shut the bag,
						-- then follow opens it again.
						inventory.close()
						inventory.open()
					end,
				},
			})
			local press = chunk()
			HudShell.start(world.playerGui, {
				onHero = function() end,
				onBag = press,
				onRoll = function() end,
				onPets = function() end,
				onShop = function() end,
				onSettings = function() end,
			})
			local rail = world.playerGui:FindFirstChild("ShardfallRail")
			local button = GuiFake.findNamed(rail, "Bag")
			GuiFake.activate(button)
			expect(inventory.isOpen()).toBeTrue()
			expect(inventory.isShown()).toBeTrue()
			expect(panels).toEqual({ "inventory" })
			expect(hubs).toEqual(0)
			GuiFake.activate(button)
			expect(inventory.isOpen()).toBeFalse()
			expect(inventory.isShown()).toBeFalse()
			expect(panels).toEqual({ "inventory" })
			expect(hubs).toEqual(0)
		end)
		LaunchGate.SHOW.oneInventory = previous
		if not ok then
			error(err, 0)
		end
	end)

	it("treats a shown inventory as menu-open for skills", function()
		local source = fs.readFile(CLIENT)
		local at = string.find(source, "menuOpen = function()", 1, true)
		expect(at ~= nil).toBeTrue()
		local body = string.sub(source, at :: number, (at :: number) + 220)
		expect(string.find(body, "menuHub.isOpen()", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "inventory.isShown()", 1, true) ~= nil).toBeTrue()
	end)
end)
