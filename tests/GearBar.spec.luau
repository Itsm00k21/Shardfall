--!strict

--[[
	Full-bag salvage (GearBar) and the auto-salvage-off regression from
	Kevin's playtest: "Off" came back "On (Uncommon)" and Commons were
	salvaged. The label is the server's value, a press sends explicit
	values, a second tap while one is out is dropped, and Off stays off
	through save, reload, and a drop.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local GearHooks = require("../src/ReplicatedStorage/Shared/GearHooks")
local GearSalvage = require("../src/ReplicatedStorage/Shared/GearSalvage")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local GuiFake = require("./GuiFake")

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

local function withFlag(fn: () -> ())
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

local function bag(): any
	local data = Schema.template()
	data.inventory = {}
	data.pets = {}
	Schema.insertItem(data, sword("a", "Common") :: any)
	Schema.insertItem(data, sword("b", "Uncommon") :: any)
	Schema.insertItem(data, sword("worn", "Common") :: any)
	Schema.insertItem(data, sword("held", "Common", { locked = true }) :: any)
	Schema.insertItem(data, sword("fav", "Common", { favorite = true }) :: any)
	data.equipped = data.equipped or {}
	data.equipped.weapon = "worn"
	data.gearEssence = 0
	return data
end

-- A fake server: GearSalvage.applyAction on one profile, the way the
-- remote guard does it, with the profile attached to every answer.
local function server(profile: any)
	local calls = {}
	local hold = false
	local function invoke(action: string, payload: any): any
		table.insert(calls, { action, payload })
		if hold then
			return { ok = false, error = "Too fast. Try again in a moment." }
		end
		local result = GearSalvage.applyAction(profile, 42, action, payload, 100)
		if type(result) == "table" then
			result.profile = profile
		end
		return result
	end
	return invoke, calls, function(value: boolean)
		hold = value
	end
end

local function mount(profile: any, invoke: any)
	local world = GuiFake.world()
	local GearBar = world.load("GearBar")
	local parent = world.playerGui
	local statuses = {}
	local changed = 0
	local handle = GearBar.mount(parent, {
		invoke = invoke,
		getProfile = function()
			return profile
		end,
		onChanged = function()
			changed += 1
		end,
		onStatus = function(text: string, kind: string)
			table.insert(statuses, { text, kind })
		end,
	})
	return handle, parent, statuses, function()
		return changed
	end
end

describe("GearBar: auto-salvage labels", function()
	it("reads the profile and defaults to Off", function()
		expect(GearHooks.autoLabel(nil)).toEqual("Auto-salvage: Off")
		expect(GearHooks.autoLabel({ autoSalvage = false, autoSalvageRarity = "Uncommon" })).toEqual(
			"Auto-salvage: Off"
		)
		expect(GearHooks.autoLabel({ autoSalvage = true, autoSalvageRarity = "Common" })).toEqual(
			"Auto-salvage: Commons and below"
		)
		expect(GearHooks.autoLabel({ autoSalvage = true, autoSalvageRarity = "" })).toEqual("Auto-salvage: Off")
		expect(GearHooks.autoToggle({ autoSalvage = true, autoSalvageRarity = "Uncommon" })).toEqual({
			enabled = false,
			rarity = "Uncommon",
		})
		expect(GearHooks.autoToggle({})).toEqual({ enabled = true, rarity = "Common" })
		expect(GearHooks.autoChip({})).toEqual("Auto-salvage: Off")
		expect(GearHooks.autoChip({ autoSalvage = true, autoSalvageRarity = "Uncommon" })).toEqual(
			"Auto-salvage: ≤ Uncommon"
		)
	end)

	it("clamps every cap the client sends to Common or Uncommon", function()
		expect(GearHooks.safeCap("Common")).toEqual("Common")
		expect(GearHooks.safeCap("Uncommon")).toEqual("Uncommon")
		expect(GearHooks.safeCap("Rare")).toEqual("Uncommon")
		expect(GearHooks.safeCap("Legendary")).toEqual("Uncommon")
		expect(GearHooks.safeCap(nil)).toEqual("Common")
		expect(GearHooks.autoWant({ autoSalvageRarity = "Rare" }, true, nil)).toEqual({
			enabled = true,
			rarity = "Uncommon",
		})
		expect(GearHooks.capUnsafe({ autoSalvageRarity = "Rare" })).toBeTrue()
		expect(GearHooks.capUnsafe({ autoSalvageRarity = "Uncommon" })).toBeFalse()
	end)

	it("asks before turning on or raising the cap, never before off or lower", function()
		local off = { autoSalvage = false, autoSalvageRarity = "Common" }
		expect(GearHooks.autoAsk(off, { enabled = true, rarity = "Uncommon" })).toEqual(
			"Auto-salvage will destroy new Uncommon and lower drops. Turn on?"
		)
		local on = { autoSalvage = true, autoSalvageRarity = "Common" }
		expect(GearHooks.autoAsk(on, { enabled = true, rarity = "Uncommon" })).toEqual(
			"Auto-salvage will destroy new Uncommon and lower drops. Raise the cap?"
		)
		expect(GearHooks.autoAsk(on, { enabled = false, rarity = "Common" })).toBeNil()
		local high = { autoSalvage = true, autoSalvageRarity = "Uncommon" }
		expect(GearHooks.autoAsk(high, { enabled = true, rarity = "Common" })).toBeNil()
	end)

	it("the pill opens a popover; one tap never changes the setting", function()
		withFlag(function()
			local profile = bag()
			local invoke, calls = server(profile)
			local _, parent = mount(profile, invoke)
			local auto = GuiFake.findNamed(parent, "AutoSalvage")
			expect(auto.Text).toEqual("Auto-salvage: Off  ⚙")
			expect(GuiFake.findNamed(parent, "AutoCap")).toBeNil()
			GuiFake.activate(auto)
			GuiFake.activate(auto)
			GuiFake.activate(auto)
			expect(#calls).toEqual(0)
			expect(profile.autoSalvage).toEqual(false)
			expect(GuiFake.findNamed(parent, "AutoPopover").Visible).toBeTrue()
			-- Rare and above are not offered at all.
			expect(GuiFake.findNamed(parent, "AutoCapPick_Common") ~= nil).toBeTrue()
			expect(GuiFake.findNamed(parent, "AutoCapPick_Uncommon") ~= nil).toBeTrue()
			expect(GuiFake.findNamed(parent, "AutoCapPick_Rare")).toBeNil()
			expect(GuiFake.findNamed(parent, "AutoCapPick_Epic")).toBeNil()
		end)
	end)

	it("turning on needs the confirm; Cancel sends nothing", function()
		withFlag(function()
			local profile = bag()
			local invoke, calls = server(profile)
			local _, parent = mount(profile, invoke)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoSalvage"))
			-- Cap to Uncommon while off: saved, still off, no confirm.
			GuiFake.activate(GuiFake.findNamed(parent, "AutoCapPick"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoCapPick_Uncommon"))
			expect(profile.autoSalvage).toEqual(false)
			expect(profile.autoSalvageRarity).toEqual("Uncommon")
			local sent = #calls
			GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
			local ask = GuiFake.findNamed(parent, "AutoAsk")
			expect(ask.Visible).toBeTrue()
			expect(GuiFake.findNamed(parent, "AutoAskText").Text).toEqual(
				"Auto-salvage will destroy new Uncommon and lower drops. Turn on?"
			)
			expect(#calls).toEqual(sent)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoNo"))
			expect(ask.Visible).toBeFalse()
			expect(profile.autoSalvage).toEqual(false)
			expect(#calls).toEqual(sent)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoYes"))
			expect(profile.autoSalvage).toEqual(true)
			expect(calls[#calls][2]).toEqual({ enabled = true, rarity = "Uncommon" })
			expect(GuiFake.findNamed(parent, "AutoSalvage").Text).toEqual("Auto-salvage: ≤ Uncommon  ⚙")
			expect(GuiFake.findNamed(parent, "AutoSalvage"):GetAttribute("AutoOn")).toEqual(true)
			-- Turning off never asks.
			GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
			expect(profile.autoSalvage).toEqual(false)
			expect(GuiFake.findNamed(parent, "AutoAsk").Visible).toBeFalse()
		end)
	end)

	it("raising the cap while on asks; lowering does not", function()
		withFlag(function()
			local profile = bag()
			profile.autoSalvage = true
			profile.autoSalvageRarity = "Common"
			local invoke, calls = server(profile)
			local _, parent = mount(profile, invoke)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoSalvage"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoCapPick"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoCapPick_Uncommon"))
			expect(#calls).toEqual(0)
			expect(GuiFake.findNamed(parent, "AutoAskText").Text).toEqual(
				"Auto-salvage will destroy new Uncommon and lower drops. Raise the cap?"
			)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoYes"))
			expect(profile.autoSalvageRarity).toEqual("Uncommon")
			GuiFake.activate(GuiFake.findNamed(parent, "AutoCapPick"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoCapPick_Common"))
			expect(profile.autoSalvageRarity).toEqual("Common")
			expect(GuiFake.findNamed(parent, "AutoAsk").Visible).toBeFalse()
		end)
	end)

	it("a saved Rare cap is clamped quietly when the popover opens, with one plain line", function()
		withFlag(function()
			local profile = bag()
			profile.autoSalvage = true
			profile.autoSalvageRarity = "Rare"
			local invoke, calls = server(profile)
			local _, parent = mount(profile, invoke)
			expect(GuiFake.findNamed(parent, "AutoSalvage").Text).toEqual("Auto-salvage: ≤ Rare  ⚙")
			-- Mounting sends nothing.
			expect(#calls).toEqual(0)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoSalvage"))
			-- Clip 9: no "saved cap is Rare" warning and no Lower button.
			expect(GuiFake.findNamed(parent, "AutoUnsafe")).toBeNil()
			expect(GuiFake.findNamed(parent, "AutoLower")).toBeNil()
			local note = GuiFake.findNamed(parent, "AutoCapNote")
			expect(note.Visible).toBeTrue()
			expect(note.Text).toEqual(GearHooks.capNote(profile))
			expect(calls[#calls][2]).toEqual({ enabled = true, rarity = "Uncommon" })
			expect(profile.autoSalvageRarity).toEqual("Uncommon")
			expect(GuiFake.findNamed(parent, "AutoSalvage").Text).toEqual("Auto-salvage: ≤ Uncommon  ⚙")
			-- Off then On again sends Uncommon, never Rare.
			GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoYes"))
			for _, call in ipairs(calls) do
				expect(GearHooks.capRank(call[2].rarity) <= 2).toBeTrue()
			end
		end)
	end)

	it("a saved Rare cap that is off is shown clamped and never sent", function()
		withFlag(function()
			local profile = bag()
			profile.autoSalvage = false
			profile.autoSalvageRarity = "Rare"
			local invoke, calls = server(profile)
			local _, parent = mount(profile, invoke)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoSalvage"))
			expect(#calls).toEqual(0)
			expect(GuiFake.findNamed(parent, "AutoCapPick").Text).toEqual("Cap: Uncommon  ▼")
		end)
	end)

	it("keeps auto-salvage off once turned off: save, reload, and a Common drop", function()
		withFlag(function()
			local profile = bag()
			local invoke, calls = server(profile)
			local handle, parent = mount(profile, invoke)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoSalvage"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoYes"))
			expect(profile.autoSalvage).toEqual(true)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
			expect(profile.autoSalvage).toEqual(false)
			local auto = GuiFake.findNamed(parent, "AutoSalvage")
			expect(auto.Text).toEqual("Auto-salvage: Off  ⚙")
			expect(calls[#calls][2]).toEqual({ enabled = false, rarity = "Common" })
			handle.refresh()
			expect(auto.Text).toEqual("Auto-salvage: Off  ⚙")
			local reloaded = Schema.reconcile(Schema.deepCopy(profile))
			expect(reloaded.autoSalvage).toEqual(false)
			local before = profile.gearEssence
			local drop = GearSalvage.receive(profile, sword("new", "Common"))
			expect(drop.kept).toEqual(true)
			expect(profile.gearEssence).toEqual(before)
		end)
	end)

	it("shows the server value after a refused press", function()
		withFlag(function()
			local profile = bag()
			local invoke, calls, hold = server(profile)
			local _, parent, statuses = mount(profile, invoke)
			hold(true)
			GuiFake.activate(GuiFake.findNamed(parent, "AutoSalvage"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
			GuiFake.activate(GuiFake.findNamed(parent, "AutoYes"))
			expect(profile.autoSalvage).toEqual(false)
			expect(GuiFake.findNamed(parent, "AutoSalvage").Text).toEqual("Auto-salvage: Off  ⚙")
			expect(statuses[#statuses][2]).toEqual("error")
			hold(false)
			local before = #calls
			mount(profile, invoke)
			expect(#calls).toEqual(before)
		end)
	end)
end)

describe("GearBar: one request at a time", function()
	it("drops a second tap while the first is still out", function()
		withFlag(function()
			local profile = bag()
			profile.autoSalvage = true
			profile.autoSalvageRarity = "Common"
			local sent = 0
			local inner = server(profile)
			local parent: any = nil
			local nested = false
			local function invoke(action: string, payload: any): any
				sent += 1
				if not nested then
					nested = true
					GuiFake.activate(GuiFake.findNamed(parent, "AutoToggle"))
				end
				return inner(action, payload)
			end
			local _, root = mount(profile, invoke)
			parent = root
			GuiFake.activate(GuiFake.findNamed(root, "AutoSalvage"))
			GuiFake.activate(GuiFake.findNamed(root, "AutoToggle"))
			expect(sent).toEqual(1)
			expect(profile.autoSalvage).toEqual(false)
		end)
	end)
end)

describe("GearBar: select and salvage", function()
	it("will not pick equipped, locked, or favorite gear", function()
		withFlag(function()
			local profile = bag()
			local invoke = server(profile)
			local handle, parent = mount(profile, invoke)
			GuiFake.activate(GuiFake.findNamed(parent, "SelectMode"))
			expect(handle.selecting()).toBeTrue()
			expect(GuiFake.findNamed(parent, "SalvageBar").Visible).toBeTrue()
			local okWorn, whyWorn = handle.toggle("worn")
			expect(okWorn).toEqual(false)
			expect(whyWorn).toEqual("Equipped")
			expect(select(2, handle.toggle("held"))).toEqual("Locked")
			expect(select(2, handle.toggle("fav"))).toEqual("Favorite")
			expect(handle.toggle("a")).toEqual(true)
			expect(handle.toggle("b")).toEqual(true)
			expect(GuiFake.findNamed(parent, "SalvageSelected").Text).toEqual("Salvage 2 for +4 Essence")
			expect(handle.toggle("b")).toEqual(true)
			expect(GuiFake.findNamed(parent, "SalvageSelected").Text).toEqual("Salvage 1 for +1 Essence")
		end)
	end)

	it("needs Confirm before anything is deleted", function()
		withFlag(function()
			local profile = bag()
			local invoke, calls = server(profile)
			local handle, parent, statuses = mount(profile, invoke)
			GuiFake.activate(GuiFake.findNamed(parent, "SelectMode"))
			handle.toggle("a")
			handle.toggle("b")
			GuiFake.activate(GuiFake.findNamed(parent, "SalvageSelected"))
			expect(calls[#calls][1]).toEqual("preview")
			expect(profile.inventory.a ~= nil).toBeTrue()
			local confirm = GuiFake.findNamed(parent, "SalvageConfirm")
			expect(confirm.Visible).toBeTrue()
			expect(GuiFake.findNamed(confirm, "Text").Text).toEqual("Salvage 2 for +4 Essence? This cannot be undone.")
			-- Cancel keeps everything.
			GuiFake.activate(GuiFake.findNamed(parent, "CancelSalvage"))
			expect(confirm.Visible).toBeFalse()
			expect(profile.inventory.a ~= nil).toBeTrue()
			GuiFake.activate(GuiFake.findNamed(parent, "SalvageSelected"))
			GuiFake.activate(GuiFake.findNamed(parent, "ConfirmSalvage"))
			expect(calls[#calls][1]).toEqual("confirm")
			expect(profile.inventory.a).toBeNil()
			expect(profile.inventory.b).toBeNil()
			expect(profile.inventory.worn ~= nil).toBeTrue()
			expect(profile.inventory.fav ~= nil).toBeTrue()
			expect(profile.gearEssence).toEqual(4)
			expect(GuiFake.findNamed(parent, "Essence").Text).toEqual("Essence 4")
			expect(statuses[#statuses][2]).toEqual("ok")
			expect(handle.isSelected("a")).toEqual(false)
		end)
	end)

	it("selects everything at or below a rarity from the dropdown", function()
		withFlag(function()
			local profile = bag()
			local invoke, calls = server(profile)
			local handle, parent = mount(profile, invoke)
			expect(GuiFake.findNamed(parent, "SelectUpTo").Visible).toBeFalse()
			GuiFake.activate(GuiFake.findNamed(parent, "SelectMode"))
			expect(GuiFake.findNamed(parent, "SelectUpTo").Visible).toBeTrue()
			GuiFake.activate(GuiFake.findNamed(parent, "SelectUpTo"))
			GuiFake.activate(GuiFake.findNamed(parent, "SelectUpTo_Common"))
			expect(calls[#calls][2]).toEqual({ rarity = "Common" })
			expect(handle.isSelected("a")).toEqual(true)
			expect(handle.isSelected("b")).toEqual(false)
			expect(handle.isSelected("fav")).toEqual(false)
			expect(handle.isSelected("worn")).toEqual(false)
			GuiFake.activate(GuiFake.findNamed(parent, "SelectUpTo"))
			GuiFake.activate(GuiFake.findNamed(parent, "SelectUpTo_Uncommon"))
			expect(handle.isSelected("b")).toEqual(true)
			-- Nothing is gone until Confirm.
			expect(profile.inventory.a ~= nil).toBeTrue()
			GuiFake.activate(GuiFake.findNamed(parent, "ClearSelection"))
			expect(handle.isSelected("a")).toEqual(false)
		end)
	end)

	it("says why nothing qualifies instead of asking the server", function()
		withFlag(function()
			local profile = bag()
			profile.inventory.a.locked = true
			local invoke, calls = server(profile)
			local _, parent, statuses = mount(profile, invoke)
			GuiFake.activate(GuiFake.findNamed(parent, "SelectMode"))
			GuiFake.activate(GuiFake.findNamed(parent, "SelectUpTo"))
			GuiFake.activate(GuiFake.findNamed(parent, "SelectUpTo_Common"))
			expect(#calls).toEqual(0)
			expect(statuses[#statuses][1]).toEqual(
				"No unlocked, unequipped Commons in your Bag (2 locked, 1 equipped, 1 favorite)."
			)
			expect(statuses[#statuses][2]).toEqual("info")
		end)
		expect(GearHooks.pickEmpty({ inventory = {} }, "Common", "weapons")).toEqual("No Commons in Weapons.")
		expect(GearHooks.pickEmpty({
			inventory = { x = { uid = "x", kind = "Armor", rarity = "Common", locked = true } },
		}, "Uncommon", "armor")).toEqual("No unlocked, unequipped Uncommons or lower in Armor (1 locked).")
	end)
end)

describe("GearBar: x10 with auto-salvage", function()
	it("marks rows that never reached the Bag and says so", function()
		local profile = {
			inventory = { keep = { uid = "keep" } },
			autoSalvage = true,
			autoSalvageRarity = "Uncommon",
		}
		local items = {
			{ item = { uid = "c1", kind = "Weapon", rarity = "Common" }, rarity = "Common" },
			{ item = { uid = "u1", kind = "Armor", rarity = "Uncommon" }, rarity = "Uncommon" },
			{ item = { uid = "keep", kind = "Weapon", rarity = "Rare" }, rarity = "Rare" },
			{
				item = { uid = "m1", kind = "Weapon", rarity = "Rare" },
				rarity = "Rare",
				merged = true,
			},
		}
		local gone, gain = GearHooks.markBatch(items, profile)
		expect(gone).toEqual(2)
		expect(gain).toEqual(4)
		expect(items[1].autoSalvaged).toEqual(true)
		expect(items[3].autoSalvaged).toBeNil()
		expect(items[4].autoSalvaged).toBeNil()
		expect(GearHooks.batchLine(4, gone, gain)).toEqual("x4 done: 2 auto-salvaged (+4 Essence), 2 kept.")
		expect(GearHooks.batchLine(10, 0, 0)).toBeNil()
	end)

	it("never marks pets, Legendaries, or anything while auto-salvage is off (clip 6)", function()
		-- The clip: a pity Legendary Antler Hart and a first Moss Hare stayed
		-- in profile.pets but showed Salvaged +200 / +1 Essence.
		local pets = {
			hart = { uid = "hart", kind = "Pet", rarity = "Legendary" },
			hare = { uid = "hare", kind = "Pet", rarity = "Common" },
		}
		local function rows()
			return {
				{ item = pets.hart, kind = "Pet", rarity = "Legendary" },
				{ item = pets.hare, kind = "Pet", rarity = "Common" },
				{ item = { uid = "gone", kind = "Pet", rarity = "Common" }, rarity = "Common" },
				{
					item = { uid = "leg", kind = "Weapon", rarity = "Legendary" },
					rarity = "Legendary",
				},
				{ item = { uid = "c1", kind = "Weapon", rarity = "Common" }, rarity = "Common" },
			}
		end
		local off = rows()
		local gone, gain =
			GearHooks.markBatch(off, { inventory = {}, pets = pets, autoSalvage = false })
		expect(gone).toEqual(0)
		expect(gain).toEqual(0)
		for _, row in ipairs(off) do
			expect(row.autoSalvaged).toBeNil()
		end
		local on = rows()
		gone, gain = GearHooks.markBatch(
			on,
			{ inventory = {}, pets = pets, autoSalvage = true, autoSalvageRarity = "Uncommon" }
		)
		expect(gone).toEqual(1)
		expect(gain).toEqual(1)
		expect(on[1].autoSalvaged).toBeNil()
		expect(on[2].autoSalvaged).toBeNil()
		expect(on[3].autoSalvaged).toBeNil()
		expect(on[4].autoSalvaged).toBeNil()
		expect(on[5].autoSalvaged).toEqual(true)
		-- A stray server flag on a pet row is dropped too.
		local stray = {
			{
				item = pets.hart,
				kind = "Pet",
				rarity = "Legendary",
				autoSalvaged = true,
				essenceGained = 200,
			},
		}
		expect((GearHooks.markBatch(stray, { inventory = {}, pets = pets }))).toEqual(0)
		expect(stray[1].autoSalvaged).toBeNil()
	end)
end)
