--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local Keybinds = require("../src/ReplicatedStorage/Shared/Keybinds")
local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local IconAssets = require("../src/ReplicatedStorage/Shared/IconAssets")

local function levelTwo(): any
	return {
		classId = "tidecaller",
		classXp = { tidecaller = 40 },
		consumables = { healing_tonic = 3 },
		inventory = {},
	}
end

local function copySlots(bar: ActionSlots.Bar): { ActionSlots.Slot }
	local slots = {}
	for index = 1, ActionSlots.COUNT do
		local slot = bar.slots[index]
		slots[index] = { kind = slot.kind, id = slot.id }
	end
	return slots
end

describe("Action slots", function()
	it("gives every class skill and ultimate painted hotbar art", function()
		local ids = {}
		for _, def in ipairs(Classes.all()) do
			table.insert(ids, def.id)
		end
		expect(#ids > 0).toBeTrue()
		for _, id in ipairs(ids) do
			local def = Classes.get(id) :: any
			for _, skill in ipairs(def.skills) do
				local key = ActionSlots.art(id, { kind = "skill", id = skill.id })
				expect(key ~= nil).toBeTrue()
				expect(string.sub(IconAssets[key :: string] or "", 1, 13)).toEqual("rbxassetid://")
			end
			expect(ActionSlots.art(id, { kind = "skill", id = def.ultimate.id })).toEqual("SkillUlt")
		end
		expect(ActionSlots.art("", { kind = "consumable", id = "tonic" })).toEqual("ItemConsumable")
		expect(ActionSlots.art("", { kind = "empty", id = "" })).toBeNil()
	end)

	it("fills a new class bar with skills, a tonic, and two empty slots", function()
		local bar = ActionSlots.defaults("tidecaller")
		expect(bar.locked).toEqual(false)
		expect(#bar.slots).toEqual(8)
		expect(bar.slots[1]).toEqual({ kind = "skill", id = "tidal_bolt" })
		expect(bar.slots[2]).toEqual({ kind = "skill", id = "healing_pool" })
		expect(bar.slots[3]).toEqual({ kind = "skill", id = "bubble_ward" })
		expect(bar.slots[4]).toEqual({ kind = "skill", id = "undertow" })
		expect(bar.slots[5]).toEqual({ kind = "skill", id = "monsoon" })
		expect(bar.slots[6]).toEqual({ kind = "consumable", id = "healing_tonic" })
		expect(bar.slots[7]).toEqual({ kind = "empty", id = "" })
		expect(bar.slots[8]).toEqual({ kind = "empty", id = "" })
		local fresh = ActionSlots.fresh()
		expect(fresh.warden.slots[1].id).toEqual("thorn_bash")
		expect(fresh.warden.slots[5].kind).toEqual("skill")
		expect(fresh.warden.slots[6].id).toEqual("healing_tonic")
		expect(fresh.tidecaller.slots[6].id).toEqual("healing_tonic")
	end)

	it("accepts owned unique slots and rejects a ninth, a duplicate, or a foreign skill", function()
		local profile = levelTwo()
		local bar = ActionSlots.defaults("tidecaller")
		local accepted, err = ActionSlots.accept("tidecaller", bar.slots, false, profile)
		expect(err).toBeNil()
		assert(accepted ~= nil)
		expect(accepted.slots[1].id).toEqual("tidal_bolt")

		local nine = copySlots(bar)
		nine[9] = { kind = "empty", id = "" }
		local rejected, why = ActionSlots.accept("tidecaller", nine, false, profile)
		expect(rejected).toBeNil()
		expect(why).toEqual("The bar holds 8 slots.")

		local doubled = copySlots(bar)
		doubled[7] = { kind = "skill", id = "tidal_bolt" }
		local duplicate, duplicateWhy = ActionSlots.accept("tidecaller", doubled, false, profile)
		expect(duplicate).toBeNil()
		expect(duplicateWhy).toEqual("That skill or item is already on the bar.")

		local foreign = copySlots(bar)
		foreign[7] = { kind = "skill", id = "thorn_bash" }
		local other, otherWhy = ActionSlots.accept("tidecaller", foreign, false, profile)
		expect(other).toBeNil()
		expect(otherWhy).toEqual("That skill is not on this class.")

		local missing = copySlots(bar)
		missing[7] = { kind = "item", id = "not-owned" }
		local unowned, unownedWhy = ActionSlots.accept("tidecaller", missing, false, profile)
		expect(unowned).toBeNil()
		expect(unownedWhy).toEqual("You do not have that item.")

		local owned = copySlots(bar)
		owned[7] = { kind = "item", id = "sword" }
		profile.inventory.sword = { uid = "sword", kind = "Weapon", name = "Wooden Sword", rarity = "Rare" }
		local placed, placedWhy = ActionSlots.accept("tidecaller", owned, true, profile)
		expect(placedWhy).toBeNil()
		assert(placed ~= nil)
		expect(placed.locked).toEqual(true)
		expect(placed.slots[7].id).toEqual("sword")

		local unknown, unknownWhy = ActionSlots.accept("solecaster", owned, false, profile)
		expect(unknown).toBeNil()
		expect(unknownWhy).toEqual("That class is not in the beta.")
	end)

	it("repairs a bad save and keeps a saved bar without stripping items", function()
		local saved = ActionSlots.defaults("tidecaller")
		saved.slots[2] = { kind = "skill", id = "thorn_bash" }
		saved.slots[7] = { kind = "skill", id = "tidal_bolt" }
		saved.slots[8] = { kind = "item", id = "sword" }
		local repaired = ActionSlots.repair("tidecaller", saved, { inventory = {} })
		expect(repaired.slots[1].id).toEqual("tidal_bolt")
		expect(repaired.slots[2].kind).toEqual("empty")
		expect(repaired.slots[7].kind).toEqual("empty")
		expect(repaired.slots[8].kind).toEqual("empty")

		local bars = {
			tidecaller = {
				locked = false,
				slots = saved.slots,
			},
		}
		local kept = ActionSlots.barFor(bars, "tidecaller")
		expect(kept.slots[8].id).toEqual("sword")
		local missing = ActionSlots.barFor({}, "tidecaller")
		expect(missing.slots[1].id).toEqual("tidal_bolt")
		expect(missing.slots[6].id).toEqual("healing_tonic")
	end)

	it("maps keys 1 through 8 and leaves Shift and F off the bar", function()
		for index, key in ipairs(ActionSlots.KEYS) do
			expect(ActionSlots.keyLabel(index)).toEqual(tostring(index))
			expect(ActionSlots.indexForKey(key)).toEqual(index)
			expect(ActionSlots.indexForKey(tostring(index))).toEqual(index)
			expect(Keybinds.display(key)).toEqual(tostring(index))
			expect(Keybinds.COMBAT["slot" .. tostring(index)]).toEqual(key)
		end
		expect(ActionSlots.indexForKey("F")).toBeNil()
		expect(ActionSlots.indexForKey("LeftShift")).toBeNil()
		expect(ActionSlots.indexForKey("E")).toBeNil()
		expect(ActionSlots.indexForKey("Q")).toBeNil()
		expect(Keybinds.COMBAT.dodge).toEqual("LeftShift")
		expect(Keybinds.display(Keybinds.COMBAT.dodge)).toEqual("Shift")
		expect(Keybinds.COMBAT.interact).toEqual("F")
		expect(Keybinds.owner("1")).toEqual("slot1")
		expect(Keybinds.owner("8")).toEqual("slot8")
		expect(Keybinds.owner("F")).toEqual("interact")
		expect(Keybinds.owner("Shift")).toEqual("dodge")
		expect(Keybinds.owner("E")).toBeNil()
		expect(Keybinds.owner("Q")).toBeNil()
		expect(ActionSlots.castKey("tidecaller", "tidal_bolt")).toEqual(1)
		expect(ActionSlots.castKey("tidecaller", "undertow")).toEqual(4)
		expect(ActionSlots.castKey("tidecaller", "monsoon")).toEqual("ult")
		expect(ActionSlots.castKey("tidecaller", "thorn_bash")).toBeNil()
	end)

	it("locks later skills, tints range and cooldown, and counts tonics", function()
		local profile = levelTwo()
		local bolt = { kind = "skill", id = "tidal_bolt" }
		local pool = { kind = "skill", id = "healing_pool" }
		local undertow = { kind = "skill", id = "undertow" }
		local ward = { kind = "skill", id = "bubble_ward" }
		local monsoon = { kind = "skill", id = "monsoon" }
		expect(ActionSlots.level(profile, "tidecaller")).toEqual(2)
		expect(ActionSlots.block("tidecaller", bolt, profile, false, true)).toBeNil()
		expect(ActionSlots.block("tidecaller", pool, profile, false, true)).toBeNil()
		expect(ActionSlots.block("tidecaller", undertow, profile, false, true)).toEqual(
			"Locked until Lv 6"
		)
		expect(ActionSlots.lockLabel("tidecaller", undertow, profile)).toEqual(
			ActionSlots.PADLOCK .. " Lv 6"
		)
		expect(ActionSlots.lockLabel("tidecaller", ward, profile)).toEqual(
			ActionSlots.PADLOCK .. " Lv 4"
		)
		expect(ActionSlots.lockLabel("tidecaller", monsoon, profile)).toEqual(
			ActionSlots.PADLOCK .. " Lv 10"
		)
		expect(ActionSlots.tint("Locked until Lv 4")).toEqual("locked")
		expect(ActionSlots.block("tidecaller", bolt, profile, true, true)).toEqual("On cooldown")
		expect(ActionSlots.tint("On cooldown")).toEqual("cooldown")
		expect(ActionSlots.block("tidecaller", bolt, profile, false, false)).toEqual("Out of range")
		expect(ActionSlots.tint("Out of range")).toEqual("range")
		expect(ActionSlots.block("tidecaller", ward, profile, false, false)).toEqual(
			"Locked until Lv 4"
		)
		local tonic = { kind = "consumable", id = "healing_tonic" }
		expect(ActionSlots.stacks(tonic, profile)).toEqual(3)
		expect(ActionSlots.block("tidecaller", tonic, profile, false, true)).toBeNil()
		expect(ActionSlots.block("tidecaller", tonic, { consumables = {} }, false, true)).toEqual(
			"You have no Healing Tonic."
		)
		expect(ActionSlots.tint("You have no Healing Tonic.")).toEqual("unusable")
		local sword = { kind = "item", id = "sword" }
		profile.inventory.sword = { uid = "sword", kind = "Weapon", name = "Wooden Sword" }
		expect(ActionSlots.block("tidecaller", sword, profile, false, true)).toEqual(
			"That item cannot be used."
		)
		profile.inventory.sword.kind = "Usable"
		expect(ActionSlots.block("tidecaller", sword, profile, false, true)).toBeNil()
		local letter, color = ActionSlots.glyph("tidecaller", bolt)
		expect(letter).toEqual("T")
		expect(color).toEqual({ 72, 186, 176 })
		local tonicLetter, tonicColor = ActionSlots.glyph("tidecaller", tonic)
		expect(tonicLetter).toEqual("+")
		expect(tonicColor).toEqual({ 140, 230, 170 })
		local name, note = ActionSlots.describe("tidecaller", bolt, profile)
		expect(name).toEqual("Tidal Bolt")
		expect(note).toEqual("Hurts a foe or tops you up.")
		expect(ActionSlots.border(bolt, profile)).toEqual({ 255, 206, 96 })
		expect(ActionSlots.border(tonic, profile)).toEqual({ 198, 196, 206 })
		profile.inventory.sword.rarity = "Rare"
		expect(ActionSlots.border(sword, profile)).toEqual({ 96, 168, 232 })
		profile.inventory.sword.rarity = "Mythic"
		expect(ActionSlots.border(sword, profile)).toEqual({ 230, 64, 78 })
		profile.inventory.sword.rarity = "Secret"
		expect(ActionSlots.border(sword, profile)).toEqual({ 255, 255, 255 })
		expect(ActionSlots.secondsLeft(10, 8)).toEqual(2)
		expect(ActionSlots.secondsLeft(8, 8)).toEqual(0)
		expect(ActionSlots.sweep(0, 8)).toEqual(1)
		expect(ActionSlots.sweep(4, 8)).toEqual(0.5)
		expect(ActionSlots.sweep(8, 8)).toEqual(0)
		expect(ActionSlots.fromRow({ kind = "Consumable", id = "consumable:healing_tonic" })).toEqual({
			kind = "consumable",
			id = "healing_tonic",
		})
		expect(ActionSlots.fromRow({ uid = "sword", kind = "Weapon" })).toEqual({
			kind = "item",
			id = "sword",
		})
	end)

	it("swaps, clears, and refuses a drag while the bar is locked", function()
		local bar = ActionSlots.defaults("tidecaller")
		local swapped, swapWhy = ActionSlots.swap(bar, 1, 8)
		expect(swapWhy).toBeNil()
		assert(swapped ~= nil)
		expect(swapped.slots[1].kind).toEqual("empty")
		expect(swapped.slots[8].id).toEqual("tidal_bolt")
		local cleared, clearWhy = ActionSlots.clear(swapped, 8)
		expect(clearWhy).toBeNil()
		assert(cleared ~= nil)
		expect(cleared.slots[8].kind).toEqual("empty")
		local dropped, dropWhy = ActionSlots.drop(cleared, 8, { kind = "skill", id = "healing_pool" })
		expect(dropWhy).toBeNil()
		assert(dropped ~= nil)
		expect(dropped.slots[2].kind).toEqual("empty")
		expect(dropped.slots[8].id).toEqual("healing_pool")
		dropped.locked = true
		local locked, lockedWhy = ActionSlots.swap(dropped, 8, 1)
		expect(locked).toBeNil()
		expect(lockedWhy).toEqual("Bar is locked.")
		local still, stillWhy = ActionSlots.clear(dropped, 8)
		expect(still).toBeNil()
		expect(stillWhy).toEqual("Bar is locked.")
		local refused, refusedWhy = ActionSlots.drop(dropped, 1, { kind = "skill", id = "tidal_bolt" })
		expect(refused).toBeNil()
		expect(refusedWhy).toEqual("Bar is locked.")
	end)

	it("centers eight slots on a desktop and keeps a thumb cluster clear of the joystick", function()
		local desktop = ActionSlots.placement(1280, 720, false)
		expect(desktop.mobile).toEqual(false)
		expect(desktop.columns).toEqual(8)
		expect(desktop.rows).toEqual(1)
		expect(desktop.slot).toEqual(64)
		expect(desktop.w).toEqual(568)
		expect(desktop.x).toEqual(356)
		expect(desktop.x + desktop.w / 2).toEqual(640)
		local desktopRect = { x = desktop.x, y = desktop.y, w = desktop.w, h = desktop.h }
		expect(ActionSlots.overlaps(desktopRect, ActionSlots.toastHost(1280))).toEqual(false)

		local phone = ActionSlots.placement(390, 844, true)
		expect(phone.mobile).toEqual(true)
		expect(phone.columns).toEqual(4)
		expect(phone.rows).toEqual(2)
		expect(phone.slot).toEqual(48)
		expect(phone.x).toEqual(158)
		expect(phone.y).toEqual(600)
		expect(phone.w).toEqual(216)
		expect(phone.h).toEqual(140)
		expect(phone.x >= 140).toBeTrue()
		local phoneRect = { x = phone.x, y = phone.y, w = phone.w, h = phone.h }
		expect(ActionSlots.overlaps(phoneRect, ActionSlots.joystick(844))).toEqual(false)
		expect(ActionSlots.overlaps(phoneRect, ActionSlots.toastHost(390))).toEqual(false)
		local chips = ActionSlots.prompts(phone, 390, 844)
		expect(ActionSlots.overlaps(phoneRect, chips.dodge)).toEqual(false)
		expect(ActionSlots.overlaps(phoneRect, chips.interact)).toEqual(false)
		expect(ActionSlots.overlaps(chips.dodge, ActionSlots.joystick(844))).toEqual(false)
	end)

	it("lines Lock up with T and paints a high-contrast slot", function()
		local desktop = ActionSlots.placement(1280, 720, false)
		local chrome = ActionSlots.chrome(desktop)
		expect(chrome.lock.y).toEqual(chrome.roll.y)
		expect(chrome.lock.h).toEqual(chrome.roll.h)
		expect(chrome.lock.h).toEqual(28)
		expect(chrome.lock.y).toEqual(4)
		expect(chrome.lock.w).toEqual(desktop.slot)
		expect(chrome.roll.w).toEqual(desktop.slot)
		expect(chrome.roll.x).toEqual(chrome.lock.w + desktop.gap)
		expect(chrome.lock.y + chrome.lock.h <= 36).toBeTrue()
		expect(ActionSlots.chrome(desktop, { paid = true })).toEqual(chrome)
		local phone = ActionSlots.placement(390, 844, true)
		local phoneChrome = ActionSlots.chrome(phone)
		expect(phoneChrome.roll.x).toEqual(phoneChrome.lock.w + phone.gap)
		expect(phoneChrome.lock.y).toEqual(phoneChrome.roll.y)
		local face = ActionSlots.face()
		expect(face).toEqual({
			fill = { 12, 10, 16 },
			stroke = { 255, 214, 120 },
			thickness = 3,
		})
		expect(ActionSlots.face({ paid = true, cost = 25 })).toEqual(face)
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local bar = fs.readFile(root .. "ActionBar.luau")
		expect(string.find(bar, "ActionSlots.chrome(spot)", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "ActionSlots.face()", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, 'rollKey.Name = "RollKey"', 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, 'rollKey.Text = "T"', 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "callbacks.onRoll", 1, true) ~= nil).toBeTrue()
		local client = fs.readFile(root .. "init.client.luau")
		local at = string.find(client, "actionBar = ActionBar.start", 1, true)
		expect(at ~= nil).toBeTrue()
		local chunk = string.sub(client, at or 1, (at or 1) + 900)
		expect(string.find(chunk, "onRoll = function()", 1, true) ~= nil).toBeTrue()
		expect(string.find(chunk, 'openHub("roll")', 1, true) ~= nil).toBeTrue()
	end)

	it("binds the bar through the hub and the gamepad d-pad", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local bar = fs.readFile(root .. "ActionBar.luau")
		local hub = fs.readFile(root .. "MenuHub.luau")
		local shell = fs.readFile(root .. "HudShell.luau")
		local slots = fs.readFile("src/ReplicatedStorage/Shared/ActionSlots.luau")
		expect(string.find(bar, "ContextActionService", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "ShardfallActionBar", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "ShardfallDodge", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "Gamepad paging is not bound", 1, true)).toBeNil()
		expect(string.find(bar, "ShardfallActionBarPad", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "PadGlyph", 1, true) ~= nil).toBeTrue()
		expect(string.find(slots, "Gamepad d-pad and bumper paging are not bound", 1, true)).toBeNil()
		expect(string.find(slots, "Holding ButtonL1", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "HelpTab", 1, true)).toBeNil()
		expect(string.find(bar, "GameSettingsTab", 1, true)).toBeNil()
		expect(string.find(bar, "skillButton", 1, true)).toBeNil()
		expect(string.find(shell, "skillButton", 1, true)).toBeNil()
		expect(string.find(hub, "UiRouter", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "ActionDrag.begin", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Drag a skill onto the bar.", 1, true) ~= nil).toBeTrue()
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/ActionBarService.luau")
		expect(string.find(service, "ClassService.cast", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "ActionBarService.drink", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "RateLimiter.take", 1, true) ~= nil).toBeTrue()
	end)
end)
