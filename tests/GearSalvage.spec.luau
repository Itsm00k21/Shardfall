--!strict

--[[
	Stage B. Essence salvage, the capped-dupe grant seam, save defaults,
	and the BagTools mount. The flag stays off when the file finishes.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Essence = require("../src/ReplicatedStorage/Shared/Config/Essence")
local GearSalvage = require("../src/ReplicatedStorage/Shared/GearSalvage")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local RateLimiter = require("../src/ServerScriptService/ShardfallServer/RateLimiter")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local AMOUNTS = {
	Common = 1,
	Uncommon = 3,
	Rare = 10,
	Epic = 40,
	Legendary = 200,
	Mythic = 200,
	Secret = 200,
}

local function sword(uid: string, rarity: string, extra: { [string]: any }?): { [string]: any }
	local item: { [string]: any } = {
		uid = uid,
		templateId = "iron_sword",
		name = "Iron Sword",
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

local function fresh(): any
	local data = Schema.template()
	data.inventory = {}
	data.pets = {}
	return data
end

local function put(data: any, item: { [string]: any })
	Schema.insertItem(data, item :: any)
end

local function withFlag(on: boolean, fn: () -> ())
	local previous = LaunchGate.SHOW.gearSalvage
	LaunchGate.SHOW.gearSalvage = on
	GearSalvage._reset()
	local ok, err = pcall(fn)
	LaunchGate.SHOW.gearSalvage = previous
	GearSalvage._reset()
	if not ok then
		error(err, 0)
	end
end

describe("Essence amounts", function()
	it("matches the overflow table and the 1e9 cap", function()
		expect(GearSalvage.FIELD).toEqual("gearEssence")
		expect(GearSalvage.CAP).toEqual(1000000000)
		expect(Essence.CAP).toEqual(1000000000)
		for _, rarity in ipairs(Rarities.ORDER) do
			expect(Essence.amount(rarity)).toEqual(AMOUNTS[rarity])
		end
		expect(Essence.amount("nope")).toBeNil()
		expect(Essence.amount(1)).toBeNil()
		local count = 0
		for _ in pairs(Essence.AMOUNT) do
			count += 1
		end
		expect(count).toEqual(7)
	end)
end)

describe("Essence save fields", function()
	it("defaults a copy and leaves the caller's table alone", function()
		local raw = {
			gold = 3,
			gearEssence = 12.8,
			inventory = {
				a = { uid = "a", locked = true, upgrade = 4 },
			},
		}
		local shot = Schema.deepCopy(raw)
		local copy = GearSalvage.migrate(raw)
		expect(raw).toEqual(shot)
		expect(copy.gearEssence).toEqual(12)
		expect(copy.gold).toEqual(3)
		expect(copy.inventory.a.locked).toEqual(true)
		expect(copy.inventory.a.upgrade).toEqual(4)
		expect(copy.essence).toBeNil()
		expect(copy.autoSalvage).toEqual(false)
		expect(copy.autoSalvageRarity).toEqual("")

		local bad = Schema.deepCopy(raw)
		bad.gearEssence = -4
		GearSalvage.applySave(bad)
		expect(bad.gearEssence).toEqual(0)
		bad.gearEssence = 0 / 0
		GearSalvage.applySave(bad)
		expect(bad.gearEssence).toEqual(0)
		bad.gearEssence = math.huge
		GearSalvage.applySave(bad)
		expect(bad.gearEssence).toEqual(0)
		bad.gearEssence = 1000000001
		GearSalvage.applySave(bad)
		expect(bad.gearEssence).toEqual(1000000000)
		bad.autoSalvage = true
		bad.autoSalvageRarity = "Rare"
		local keptGold = bad.gold
		local keptItem = Schema.deepCopy(bad.inventory.a)
		GearSalvage.applySave(bad)
		expect(bad.autoSalvage).toEqual(true)
		expect(bad.autoSalvageRarity).toEqual("Uncommon")
		expect(bad.gold).toEqual(keptGold)
		expect(bad.inventory.a).toEqual(keptItem)
		bad.autoSalvage = true
		bad.autoSalvageRarity = "nope"
		GearSalvage.applySave(bad)
		expect(bad.autoSalvage).toEqual(false)
		expect(bad.autoSalvageRarity).toEqual("")
		expect(GearSalvage.migrate("nope")).toBeNil()
	end)

	it("fills an old v26 save on a copy and keeps schema 26", function()
		local raw = { schemaVersion = 26, gold = 9 }
		local shot = Schema.deepCopy(raw)
		local saved = Schema.migrate(Schema.deepCopy(raw))
		expect(raw).toEqual(shot)
		assert(saved ~= nil)
		expect(saved.gearEssence).toEqual(0)
		expect(saved.autoSalvage).toEqual(false)
		expect(saved.autoSalvageRarity).toEqual("")
		expect(saved.gold).toEqual(9)
		expect(Schema.VERSION).toEqual(26)
		expect(saved.schemaVersion).toEqual(26)
		local snap = Schema.snapshot(saved)
		expect(snap.gearEssence).toEqual(0)
		expect(snap.autoSalvage).toEqual(false)
		expect(snap.autoSalvageRarity).toEqual("")

		local tuned = Schema.template()
		tuned.gearEssence = 12.9
		tuned.autoSalvage = true
		tuned.autoSalvageRarity = "Epic"
		tuned.chestSalvageBelow = "Mythic"
		tuned.gold = 40
		local worn = tuned.inventory
		Schema.reconcile(tuned)
		expect(tuned.gearEssence).toEqual(12)
		expect(tuned.autoSalvage).toEqual(true)
		expect(tuned.autoSalvageRarity).toEqual("Uncommon")
		expect(tuned.chestSalvageBelow).toEqual("Uncommon")
		expect(tuned.gold).toEqual(40)
		expect(tuned.inventory).toEqual(worn)
		expect(tuned.schemaVersion).toEqual(26)
		tuned.autoSalvage = true
		tuned.autoSalvageRarity = "nope"
		tuned.gearEssence = math.huge
		Schema.reconcile(tuned)
		expect(tuned.autoSalvage).toEqual(false)
		expect(tuned.autoSalvageRarity).toEqual("")
		expect(tuned.gearEssence).toEqual(0)
	end)
end)

describe("Essence grant seam", function()
	it("adds Essence without reading items, even while salvage is off", function()
		expect(LaunchGate.on("gearSalvage")).toEqual(false)
		local data = fresh()
		put(data, sword("a", "Common", { upgrade = 2 }))
		local before = Schema.deepCopy(data.inventory)
		GearSalvage.grant(data, 5.9)
		expect(data.gearEssence).toEqual(5)
		expect(data.inventory).toEqual(before)
		GearSalvage.grant(data, 0)
		GearSalvage.grant(data, -3)
		expect(data.gearEssence).toEqual(5)
		data.gearEssence = GearSalvage.CAP - 1
		GearSalvage.grant(data, 50)
		expect(data.gearEssence).toEqual(GearSalvage.CAP)
	end)

	it("pays a capped duplicate once per key and does not inspect the item", function()
		GearSalvage._reset()
		local data = fresh()
		put(data, sword("owned", "Rare", { upgrade = 10 }))
		local before = Schema.deepCopy(data.inventory)
		local first = GearSalvage.grantCappedDupe(data, "Rare", "roll-1", 7)
		expect(first.paid).toEqual(true)
		expect(first.gained).toEqual(10)
		expect(data.gearEssence).toEqual(10)
		expect(data.inventory).toEqual(before)
		local again = GearSalvage.grantCappedDupe(data, "Rare", "roll-1", 7)
		expect(again.paid).toEqual(false)
		expect(again.gained).toEqual(0)
		expect(data.gearEssence).toEqual(10)
		local other = GearSalvage.grantCappedDupe(data, "Common", "roll-2", 7)
		expect(other.gained).toEqual(1)
		data.gearEssence = GearSalvage.CAP
		local capped = GearSalvage.grantCappedDupe(data, "Common", "roll-cap", 7)
		expect(capped.gained).toEqual(0)
		expect(capped.paid).toEqual(false)
		local remembered = GearSalvage.grantCappedDupe(data, "Epic", "roll-cap", 7)
		expect(remembered.gained).toEqual(0)
		expect(remembered.paid).toEqual(false)
		expect(data.gearEssence).toEqual(GearSalvage.CAP)
		GearSalvage._reset()
	end)
end)

describe("Gear salvage", function()
	it("locks with item.locked and leaves an equipped weapon worn", function()
		local data = fresh()
		put(data, sword("w", "Common"))
		data.equipped.weapon = "w"
		local ok = GearSalvage.setLock(data, "w", true)
		expect(ok).toEqual(true)
		expect(data.inventory.w.locked).toEqual(true)
		expect(data.equipped.weapon).toEqual("w")
		local cleared = GearSalvage.setLock(data, "w", false)
		expect(cleared).toEqual(true)
		expect(data.inventory.w.locked).toEqual(false)
		expect(data.equipped.weapon).toEqual("w")
	end)

	it("salvages an explicit list all-or-nothing and ignores a client amount", function()
		withFlag(true, function()
			local data = fresh()
			put(data, sword("a", "Common", { upgrade = 3 }))
			put(data, sword("b", "Uncommon"))
			local looked = GearSalvage.applyAction(data, 42, "salvage", {
				uids = { "b", "a" },
				amount = 999,
				gearEssence = 999,
			}, 1000)
			expect(looked.ok).toEqual(true)
			expect(looked.gain).toEqual(4)
			expect(looked.token ~= nil).toBeTrue()
			expect(data.gearEssence).toEqual(0)
			expect(data.inventory.a ~= nil).toBeTrue()
			expect(data.inventory.b ~= nil).toBeTrue()
			local result =
				GearSalvage.applyAction(data, 42, "confirm", { token = looked.token }, 1000)
			expect(result.ok).toEqual(true)
			expect(result.gained).toEqual(4)
			expect(data.gearEssence).toEqual(4)
			expect(data.inventory.a).toBeNil()
			expect(data.inventory.b).toBeNil()

			put(data, sword("keep", "Common"))
			put(data, sword("locked", "Common", { locked = true }))
			local blocked = GearSalvage.applyAction(data, 42, "salvage", {
				uids = { "keep", "locked" },
			}, 1000)
			expect(blocked.ok).toEqual(false)
			expect(data.inventory.keep ~= nil).toBeTrue()
			expect(data.inventory.locked.locked).toEqual(true)
			expect(data.gearEssence).toEqual(4)

			put(data, sword("worn", "Common"))
			data.equipped.weapon = "worn"
			local worn = GearSalvage.applyAction(data, 42, "salvage", { uids = { "worn" } }, 1000)
			expect(worn.ok).toEqual(false)
			expect(data.inventory.worn ~= nil).toBeTrue()
			expect(data.equipped.weapon).toEqual("worn")

			put(data, sword("loadout", "Rare"))
			data.equipLoadout = { weapon = "loadout" }
			local held =
				GearSalvage.applyAction(data, 42, "salvage", { uids = { "loadout" } }, 1000)
			expect(held.ok).toEqual(false)
			expect(data.inventory.loadout ~= nil).toBeTrue()

			local pet = sword("pet", "Common")
			pet.kind = "Pet"
			put(data, pet)
			local petResult = GearSalvage.applyAction(data, 42, "salvage", {
				uids = { "pet" },
			}, 1000)
			expect(petResult.ok).toEqual(false)
			expect(data.pets.pet ~= nil).toBeTrue()

			local gem = sword("gem", "Common")
			gem.kind = "Accessory"
			put(data, gem)
			local gemResult =
				GearSalvage.applyAction(data, 42, "salvage", { uids = { "gem" } }, 1000)
			expect(gemResult.ok).toEqual(false)
			expect(data.inventory.gem ~= nil).toBeTrue()

			local missing = GearSalvage.applyAction(data, 42, "salvage", {
				uids = { "keep", "missing" },
			}, 1000)
			expect(missing.ok).toEqual(false)
			expect(data.inventory.keep ~= nil).toBeTrue()

			local sale = GearSalvage.applyAction(data, 42, "salvage", {
				uids = { "keep" },
				robux = 1,
			}, 1000)
			expect(sale.ok).toEqual(false)
			expect(sale.error).toEqual("Nothing here is for sale.")
			expect(data.inventory.keep ~= nil).toBeTrue()
			local product = GearSalvage.applyAction(data, 42, "salvage", {
				uids = { "keep" },
				productId = 1,
			}, 1000)
			expect(product.error).toEqual("Nothing here is for sale.")
			local receipt = GearSalvage.applyAction(data, 42, "salvage", {
				uids = { "keep" },
				receiptId = "r",
			}, 1000)
			expect(receipt.error).toEqual("Nothing here is for sale.")
		end)
	end)

	it("keeps favorited gear on every salvage path", function()
		withFlag(true, function()
			local data = fresh()
			put(data, sword("plain", "Common"))
			put(data, sword("star", "Common", { favorite = true }))
			put(data, sword("locked", "Common", { locked = true }))
			local one = GearSalvage.applyAction(data, 42, "salvage", { uids = { "star" } }, 1000)
			expect(one.ok).toEqual(false)
			expect(one.error).toEqual("That item is a favorite.")
			expect(one.token).toBeNil()
			expect(data.inventory.star.favorite).toEqual(true)
			expect(data.gearEssence).toEqual(0)

			local bulk = GearSalvage.applyAction(data, 42, "preview", {
				uids = { "plain", "star" },
			}, 1000)
			expect(bulk.ok).toEqual(false)
			expect(bulk.error).toEqual("That item is a favorite.")
			expect(data.inventory.plain ~= nil).toBeTrue()
			expect(data.inventory.star ~= nil).toBeTrue()
			expect(data.gearEssence).toEqual(0)

			local sweep = GearSalvage.applyAction(data, 42, "preview", { rarity = "Common" }, 1000)
			expect(sweep.ok).toEqual(true)
			expect(sweep.count).toEqual(1)
			expect(sweep.gain).toEqual(1)
			expect(sweep.uids).toEqual({ "plain" })
			local favoriteSkip = nil
			for _, row in ipairs(sweep.skipped) do
				if row.uid == "star" then
					favoriteSkip = row
				end
			end
			expect(favoriteSkip).toEqual({ uid = "star", reason = "That item is a favorite." })
			local done =
				GearSalvage.applyAction(data, 42, "salvageNow", { token = sweep.token }, 1000)
			expect(done.ok).toEqual(true)
			expect(data.inventory.plain).toBeNil()
			expect(data.inventory.star.favorite).toEqual(true)
			expect(data.inventory.locked.locked).toEqual(true)
			expect(data.gearEssence).toEqual(1)

			local only = fresh()
			put(only, sword("star", "Rare", { favorite = true }))
			local none = GearSalvage.applyAction(only, 7, "nudge", { rarity = "Rare" }, 20)
			expect(none.ok).toEqual(false)
			expect(none.error).toEqual("That item is a favorite.")
			expect(none.skipped).toEqual({
				{ uid = "star", reason = "That item is a favorite." },
			})
			expect(only.inventory.star ~= nil).toBeTrue()

			only.autoSalvage = true
			only.autoSalvageRarity = "Rare"
			local arrival = GearSalvage.receive(only, sword("drop", "Common", { favorite = true }))
			expect(arrival.kept).toEqual(true)
			expect(arrival.gained).toEqual(0)
			expect(arrival.reason).toEqual("That item is a favorite.")
			expect(only.gearEssence).toEqual(0)
			expect(only.inventory.drop).toBeNil()
			expect(only.inventory.star ~= nil).toBeTrue()
		end)
	end)

	it("confirms salvage selected with a token and deletes nothing before that", function()
		withFlag(true, function()
			local data = fresh()
			put(data, sword("a", "Common"))
			put(data, sword("b", "Uncommon"))
			local looked = GearSalvage.applyAction(data, 42, "preview", {
				uids = { "b", "a" },
			}, 80)
			expect(looked.ok).toEqual(true)
			expect(looked.uids).toEqual({ "a", "b" })
			expect(data.inventory.a ~= nil).toBeTrue()
			expect(data.gearEssence).toEqual(0)
			data.inventory.a.favorite = true
			local held = GearSalvage.applyAction(data, 42, "confirm", { token = looked.token }, 80)
			expect(held.error).toEqual("That item is a favorite.")
			expect(data.inventory.a ~= nil).toBeTrue()
			expect(data.inventory.b ~= nil).toBeTrue()
			expect(data.gearEssence).toEqual(0)

			data.inventory.a.favorite = false
			local again = GearSalvage.applyAction(data, 42, "salvage", {
				uids = { "a", "b" },
			}, 90)
			expect(again.ok).toEqual(true)
			expect(data.inventory.a ~= nil).toBeTrue()
			local done = GearSalvage.applyAction(data, 42, "confirm", { token = again.token }, 90)
			expect(done.ok).toEqual(true)
			expect(done.gained).toEqual(4)
			expect(data.inventory.a).toBeNil()
			expect(data.inventory.b).toBeNil()
			expect(data.gearEssence).toEqual(4)
			local second = GearSalvage.applyAction(data, 42, "confirm", { token = again.token }, 90)
			expect(second.ok).toEqual(false)
		end)
	end)

	it("previews a sweep, then confirms only with the matching token", function()
		withFlag(true, function()
			local data = fresh()
			put(data, sword("common", "Common"))
			put(data, sword("locked", "Common", { locked = true }))
			put(data, sword("worn", "Common"))
			data.equipped.weapon = "worn"
			put(data, sword("rare", "Rare"))
			local preview =
				GearSalvage.applyAction(data, 42, "preview", { rarity = "Common" }, 1000)
			expect(preview.ok).toEqual(true)
			expect(preview.gain).toEqual(1)
			expect(preview.count).toEqual(1)
			expect(preview.uids).toEqual({ "common" })
			expect(data.inventory.common ~= nil).toBeTrue()

			local wrong = GearSalvage.applyAction(data, 42, "confirm", { token = "es-9-9" }, 1000)
			expect(wrong.ok).toEqual(false)
			expect(data.inventory.common ~= nil).toBeTrue()
			local done =
				GearSalvage.applyAction(data, 42, "confirm", { token = preview.token }, 1020)
			expect(done.ok).toEqual(true)
			expect(done.gained).toEqual(1)
			expect(data.gearEssence).toEqual(1)
			expect(data.inventory.common).toBeNil()
			expect(data.inventory.locked ~= nil).toBeTrue()
			expect(data.inventory.worn ~= nil).toBeTrue()
			expect(data.inventory.rare ~= nil).toBeTrue()
			local second =
				GearSalvage.applyAction(data, 42, "confirm", { token = preview.token }, 1020)
			expect(second.ok).toEqual(false)
			expect(data.gearEssence).toEqual(1)
		end)
	end)

	it("refuses an expired token, a changed bag, and a full wallet", function()
		withFlag(true, function()
			local data = fresh()
			put(data, sword("common", "Common"))
			local preview =
				GearSalvage.applyAction(data, 42, "preview", { rarity = "Common" }, 1000)
			local late =
				GearSalvage.applyAction(data, 42, "confirm", { token = preview.token }, 1021)
			expect(late.ok).toEqual(false)
			expect(data.inventory.common ~= nil).toBeTrue()
			local still =
				GearSalvage.applyAction(data, 42, "confirm", { token = preview.token }, 1020)
			expect(still.ok).toEqual(true)
			expect(data.inventory.common).toBeNil()

			put(data, sword("next", "Common"))
			local look = GearSalvage.applyAction(data, 42, "nudge", { rarity = "Common" }, 50)
			expect(look.ok).toEqual(true)
			expect(data.inventory.next ~= nil).toBeTrue()
			put(data, sword("extra", "Common"))
			local changed =
				GearSalvage.applyAction(data, 42, "salvageNow", { token = look.token }, 50)
			expect(changed.error).toEqual("The bag changed. Look again.")
			expect(data.inventory.next ~= nil).toBeTrue()
			expect(data.inventory.extra ~= nil).toBeTrue()

			local again = GearSalvage.applyAction(data, 42, "preview", { rarity = "Common" }, 50)
			data.gearEssence = GearSalvage.CAP
			local full = GearSalvage.applyAction(data, 42, "confirm", { token = again.token }, 50)
			expect(full.error).toEqual("Essence is full.")
			expect(data.inventory.next ~= nil).toBeTrue()
			expect(data.inventory.extra ~= nil).toBeTrue()
			expect(data.gearEssence).toEqual(GearSalvage.CAP)
		end)
	end)

	it("auto-salvages a new drop only, and only while the flag and toggle are on", function()
		local off = fresh()
		put(off, sword("kept", "Common", { upgrade = 1 }))
		local shot = Schema.deepCopy(off)
		local closed = GearSalvage.receive(off, sword("new", "Common"))
		expect(closed.kept).toEqual(true)
		expect(closed.gained).toEqual(0)
		expect(off).toEqual(shot)

		withFlag(true, function()
			local data = fresh()
			put(data, sword("kept", "Rare", { upgrade = 2 }))
			local before = Schema.deepCopy(data)
			local idle = GearSalvage.receive(data, sword("fresh", "Common"))
			expect(idle.kept).toEqual(true)
			expect(data).toEqual(before)

			local turned = GearSalvage.applyAction(data, 42, "auto", {
				enabled = true,
				rarity = "Uncommon",
			}, 10)
			expect(turned.ok).toEqual(true)
			expect(data.autoSalvage).toEqual(true)
			expect(data.inventory.kept).toEqual(before.inventory.kept)

			local common = GearSalvage.receive(data, sword("drop", "Common"))
			expect(common.kept).toEqual(false)
			expect(common.gained).toEqual(1)
			expect(data.gearEssence).toEqual(1)
			expect(data.inventory.drop).toBeNil()
			local epic = GearSalvage.receive(data, sword("epic", "Epic"))
			expect(epic.kept).toEqual(true)
			expect(data.inventory.epic).toBeNil()
			local owned = GearSalvage.receive(data, data.inventory.kept)
			expect(owned.kept).toEqual(true)
			expect(data.inventory.kept.upgrade).toEqual(2)

			data.gearEssence = GearSalvage.CAP
			local held = GearSalvage.receive(data, sword("overflow", "Common"))
			expect(held.kept).toEqual(true)
			expect(data.gearEssence).toEqual(GearSalvage.CAP)
			expect(data.inventory.overflow).toBeNil()
		end)
	end)

	it("writes nothing while the flag is off", function()
		expect(LaunchGate.on("gearSalvage")).toEqual(false)
		local data = fresh()
		put(data, sword("a", "Common"))
		local shot = Schema.deepCopy(data)
		local result = GearSalvage.applyAction(data, 42, "salvage", { uids = { "a" } }, 10)
		expect(result.ok).toEqual(false)
		expect(result.error).toEqual("That is closed.")
		expect(data).toEqual(shot)
		local state = GearSalvage.applyAction(data, 42, "state", {}, 10)
		expect(state.error).toEqual("That is closed.")
		expect(data).toEqual(shot)
	end)

	it("fills the bag by adding rows and grants 500 Essence", function()
		local data = fresh()
		local legend =
			sword("legend", "Legendary", { locked = true, upgrade = 3, name = "Sun Blade" })
		put(data, legend)
		local before = Schema.deepCopy(data.inventory.legend)
		local ok, text = GearSalvage.debugFill(data, 5)
		expect(ok).toEqual(true)
		expect(string.find(text, "Filled the Bag", 1, true) ~= nil).toBeTrue()
		expect(data.inventory.legend).toEqual(before)
		expect(Schema.countItems(data)).toEqual(Schema.inventoryCap(data))
		local sample = data.inventory["salvage-fill-5-1"]
		expect(sample.templateId).toEqual("iron_sword")
		expect(sample.upgrade).toBeNil()
		local _, again = GearSalvage.debugFill(data, 6)
		expect(string.find(again, "already full", 1, true) ~= nil).toBeTrue()
		expect(data.inventory.legend).toEqual(before)

		local empty = fresh()
		local granted, line = GearSalvage.debugGrant(empty)
		expect(granted).toEqual(true)
		expect(line).toEqual("+500 Essence (now 500).")
		expect(empty.gearEssence).toEqual(500)
	end)
end)

describe("Gear salvage wiring", function()
	it("parks the remote, rates it, and auto-salvages only through receive", function()
		expect(LaunchGate.on("gearSalvage")).toEqual(false)
		expect(RateLimiter.take(4242, "GearSalvage")).toEqual(true)
		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		expect(string.find(remotes, 'GearSalvage = "gearSalvage"', 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, 'functionRemote("GearSalvage")', 1, true) ~= nil).toBeTrue()
		local project = fs.readFile("default.project.json")
		expect(string.find(project, '"GearSalvage"', 1, true) ~= nil).toBeTrue()
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		local drawAt = string.find(roll, "local function drawInto", 1, true) :: number
		local body = string.sub(roll, drawAt, drawAt + 1600)
		local receiveAt = string.find(body, "GearSalvage.receive", 1, true)
		local insertAt = string.find(body, "Schema.insertItem", 1, true)
		expect(
			receiveAt ~= nil and insertAt ~= nil and (receiveAt :: number) < (insertAt :: number)
		).toBeTrue()
		local rules = fs.readFile("src/ReplicatedStorage/Shared/GearSalvage.luau")
		expect(string.find(rules, ".upgrade =", 1, true)).toBeNil()
		local service =
			fs.readFile("src/ServerScriptService/ShardfallServer/GearSalvageService.luau")
		local handleAt =
			string.find(service, "function GearSalvageService.handle", 1, true) :: number
		local handle = string.sub(service, handleAt, handleAt + 700)
		local gateAt = string.find(handle, 'LaunchGate.on("gearSalvage")', 1, true)
		local mutateAt = string.find(handle, "DataService.mutate", 1, true)
		expect(gateAt ~= nil and mutateAt ~= nil and (gateAt :: number) < (mutateAt :: number)).toBeTrue()
		local tools =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/BagTools/init.luau")
		expect(string.find(tools, "MenuHub", 1, true)).toBeNil()
		expect(string.find(tools, "paintDetail", 1, true)).toBeNil()
		expect(string.find(tools, "BagCompare", 1, true)).toBeNil()
		expect(string.find(tools, "BagTools.mount", 1, true) ~= nil).toBeTrue()
	end)
end)

describe("BagTools mount", function()
	it("selects, locks, confirms, and stays up when the flag is off", function()
		local function signal()
			local handlers = {}
			return {
				Connect = function(_, fn)
					table.insert(handlers, fn)
					return { Disconnect = function() end }
				end,
				Fire = function()
					for _, fn in ipairs(handlers) do
						fn()
					end
				end,
			}
		end

		local function newInstance(className: string, parent: any?)
			local inst = {
				ClassName = className,
				Name = className,
				Parent = nil,
				Visible = true,
				Text = "",
				TextSize = 16,
				BackgroundTransparency = 0,
				children = {},
				MouseButton1Click = signal(),
			}
			local proxy = {}
			local function detach()
				local owner = inst.Parent
				if type(owner) ~= "table" or type(owner.children) ~= "table" then
					return
				end
				for index, child in ipairs(owner.children) do
					if child == proxy then
						table.remove(owner.children, index)
						return
					end
				end
			end
			function inst:IsA(kind: string): boolean
				return kind == className or kind == "Instance"
			end
			function inst:FindFirstChild(name: string)
				for _, child in ipairs(self.children) do
					if child.Name == name then
						return child
					end
				end
				return nil
			end
			function inst:GetChildren()
				local copy = {}
				for index, child in ipairs(self.children) do
					copy[index] = child
				end
				return copy
			end
			function inst:Destroy()
				detach()
				inst.Parent = nil
			end
			setmetatable(proxy, {
				__index = inst,
				__newindex = function(_, key, value)
					if key == "Parent" then
						if inst.Parent == value then
							return
						end
						detach()
						inst.Parent = value
						if type(value) == "table" and type(value.children) == "table" then
							table.insert(value.children, proxy)
						end
					else
						inst[key] = value
					end
				end,
			})
			if parent ~= nil then
				proxy.Parent = parent
			end
			return proxy
		end

		local profile = {
			gearEssence = 4,
			inventory = {
				["sword-1"] = {
					uid = "sword-1",
					name = "Iron Sword",
					kind = "Weapon",
					rarity = "Common",
					locked = false,
				},
				["worn-1"] = {
					uid = "worn-1",
					name = "Worn Sword",
					kind = "Weapon",
					rarity = "Common",
					locked = false,
				},
			},
			equipped = { weapon = "worn-1", armor = {}, accessories = {} },
			pets = {},
		}
		local calls = {}
		local function invoke(name: string, action: string, payload: any)
			table.insert(calls, { name = name, action = action, payload = payload })
			if action == "state" then
				return { ok = true, gearEssence = 4, autoSalvage = false, autoSalvageRarity = "" }
			elseif action == "lock" then
				return {
					ok = true,
					message = "Locked.",
					gearEssence = 4,
					autoSalvage = false,
					autoSalvageRarity = "",
				}
			elseif action == "salvage" then
				return {
					ok = true,
					message = "Salvaged 1 for 1 Essence.",
					gearEssence = 5,
					autoSalvage = false,
					autoSalvageRarity = "",
				}
			elseif action == "preview" then
				return {
					ok = true,
					token = "es-1-2",
					message = "1 pieces would become 1 Essence.",
					gearEssence = 5,
					autoSalvage = false,
					autoSalvageRarity = "",
				}
			elseif action == "confirm" then
				return {
					ok = true,
					message = "Salvaged 1 for 1 Essence.",
					gearEssence = 6,
					autoSalvage = false,
					autoSalvageRarity = "",
				}
			elseif action == "auto" then
				return {
					ok = true,
					message = "Auto-salvage on: Common and below.",
					gearEssence = 6,
					autoSalvage = true,
					autoSalvageRarity = "Common",
				}
			end
			return { ok = false, error = "That is closed." }
		end

		local env = {
			game = {
				GetService = function(_, serviceName: string)
					if serviceName == "ReplicatedStorage" then
						return { Shared = { Rarities = { Name = "Rarities" } } }
					end
					error(serviceName)
				end,
			},
			require = function(module)
				if type(module) == "table" and module.Name == "Rarities" then
					return Rarities
				end
				error("require")
			end,
			Instance = { new = newInstance },
			UDim2 = {
				new = function()
					return {}
				end,
				fromScale = function()
					return {}
				end,
			},
			UDim = {
				new = function()
					return {}
				end,
			},
			Color3 = {
				fromRGB = function()
					return {}
				end,
			},
			Enum = {
				Font = { GothamMedium = "GothamMedium" },
				TextXAlignment = { Left = "Left" },
				SortOrder = { LayoutOrder = "LayoutOrder", Name = "Name" },
			},
			math = math,
			string = string,
			table = table,
			pairs = pairs,
			ipairs = ipairs,
			type = type,
			tostring = tostring,
			error = error,
		}

		local source =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/BagTools/init.luau")
		local chunk = luau.load(luau.compile(source, { debugLevel = 2 }), {
			debugName = "BagTools",
			environment = env,
		})
		local BagTools = chunk()
		local parent = newInstance("Frame")
		local handle = BagTools.mount(parent, {
			invoke = invoke,
			getProfile = function()
				return profile
			end,
		})
		expect(calls[1].name).toEqual("GearSalvage")
		expect(calls[1].action).toEqual("state")
		expect(handle.root.Visible).toEqual(true)
		expect(handle.root:FindFirstChild("EssenceLabel").Text).toEqual("Essence: 4")
		expect(handle.root:FindFirstChild("AutoButton").Text).toEqual("Auto-salvage: Off")
		local list = handle.root:FindFirstChild("List")
		list:FindFirstChild("sword-1").MouseButton1Click:Fire()
		expect(handle:getSelected()).toEqual({ "sword-1" })
		list:FindFirstChild("worn-1").MouseButton1Click:Fire()
		expect(handle.root:FindFirstChild("Status").Text).toEqual("Equipped gear stays.")
		expect(handle:getSelected()).toEqual({ "sword-1" })
		handle.root:FindFirstChild("SalvageSelected").MouseButton1Click:Fire()
		expect(calls[#calls].action).toEqual("preview")
		expect(calls[#calls].payload.uids).toEqual({ "sword-1" })
		expect(handle.root:FindFirstChild("Confirm").Visible).toEqual(true)
		handle.root:FindFirstChild("LockButton").MouseButton1Click:Fire()
		expect(calls[#calls].action).toEqual("lock")
		expect(calls[#calls].payload.uid).toEqual("sword-1")
		expect(calls[#calls].payload.locked).toEqual(true)
		handle.root:FindFirstChild("SalvageAll").MouseButton1Click:Fire()
		expect(calls[#calls].action).toEqual("preview")
		expect(handle.root:FindFirstChild("Confirm").Visible).toEqual(true)
		handle.root:FindFirstChild("Confirm").MouseButton1Click:Fire()
		expect(calls[#calls].action).toEqual("confirm")
		expect(calls[#calls].payload.token).toEqual("es-1-2")
		handle.root:FindFirstChild("AutoButton").MouseButton1Click:Fire()
		expect(calls[#calls].action).toEqual("auto")
		expect(calls[#calls].payload.enabled).toEqual(true)
		expect(handle.root:FindFirstChild("AutoButton").Text).toEqual("Auto-salvage: On (Common)")
		for _, row in ipairs({
			handle.root:FindFirstChild("EssenceLabel"),
			handle.root:FindFirstChild("AutoButton"),
		}) do
			expect(row.TextSize >= 14).toBeTrue()
		end

		local closedCalls = {}
		local closed = BagTools.mount(parent, {
			invoke = function(name, action)
				table.insert(closedCalls, { name = name, action = action })
				return { ok = false, error = "That is closed." }
			end,
		})
		expect(closed.root.Visible).toEqual(true)
		expect(closed.root:FindFirstChild("Status").Text).toEqual("That is closed.")
		expect(closedCalls[1].action).toEqual("state")
		handle:destroy()
		closed:destroy()
		expect(LaunchGate.on("gearSalvage")).toEqual(false)
	end)
end)

-- Loads RollService the way Studio would, with the real salvage rules and
-- a profile mutate that keeps the same table. Random always misses, so a
-- draw is Common unless Legendary pity fires. A saved sinceEpic is ignored.
local function loadRollService(current: { profile: any })
	local guid = 0
	local function node(name: string)
		local inst = { Name = name, ClassName = "ModuleScript" }
		-- Live announces a Legendary. The harness has no Remotes folder.
		function inst:FindFirstChild(_child: string)
			return nil
		end
		function inst:IsA(_className: string)
			return false
		end
		setmetatable(inst, {
			__index = function(_self, key)
				return node(tostring(key))
			end,
		})
		return inst
	end

	local function restore(data, backup)
		local keys = {}
		for key in pairs(data) do
			table.insert(keys, key)
		end
		for _, key in ipairs(keys) do
			data[key] = nil
		end
		for key, value in pairs(backup) do
			data[key] = value
		end
	end

	local dataService = {
		get = function()
			return current.profile
		end,
		mutate = function(_player, callback)
			local backup = Schema.deepCopy(current.profile)
			local ok, result = pcall(callback, current.profile)
			if not ok or result ~= nil then
				restore(current.profile, backup)
				if not ok then
					return false, "Could not update your profile."
				end
				if type(result) == "string" then
					return false, result
				end
				return false, "Could not update your profile."
			end
			return true, nil
		end,
	}
	local scriptNode = node("RollService")
	scriptNode.Parent = node("ShardfallServer")
	local services = {
		HttpService = {
			GenerateGUID = function()
				guid += 1
				return string.format("salvage-roll-%d", guid)
			end,
			JSONEncode = function()
				return "{}"
			end,
		},
		Players = {
			PlayerRemoving = {
				Connect = function()
					return { Disconnect = function() end }
				end,
			},
		},
		ReplicatedStorage = node("ReplicatedStorage"),
		RunService = {
			IsStudio = function()
				return true
			end,
		},
	}
	local game = {
		JobId = "salvage-test",
		PlaceId = 0,
	}
	function game:GetService(name: string)
		local found = services[name]
		if found == nil then
			error("No service " .. name, 2)
		end
		return found
	end
	local shared = {
		CallBudget = true,
		DebugTools = true,
		DevAccess = true,
		DevTools = true,
		LaunchGate = true,
		Currencies = true,
		Pools = true,
		RarityConfig = true,
		Rarities = true,
		RollConfig = true,
		RollLoop = true,
		RollMath = true,
		Schema = true,
		GearSalvage = true,
		Settings = true,
		StarterGoalPay = true,
	}
	local source = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
	local chunk = luau.load(luau.compile(source, { debugLevel = 2 }), {
		debugName = "RollService",
		environment = {
			assert = assert,
			error = error,
			ipairs = ipairs,
			next = next,
			pairs = pairs,
			pcall = pcall,
			print = print,
			select = select,
			tonumber = tonumber,
			tostring = tostring,
			type = type,
			warn = function() end,
			math = math,
			string = string,
			table = table,
			os = os,
			coroutine = coroutine,
			Random = {
				new = function()
					return {
						NextNumber = function()
							return 0.999
						end,
						NextInteger = function(_self, minimum: number)
							return minimum
						end,
					}
				end,
			},
			game = game,
			script = scriptNode,
			typeof = typeof,
			require = function(module)
				local name = if type(module) == "table" then module.Name else ""
				if name == "DataService" then
					return dataService
				end
				if name == "PolicyCache" then
					return {
						allowPaid = function()
							return true
						end,
					}
				end
				if name == "LaunchGate" then
					return LaunchGate
				end
				if name == "GearSalvage" then
					return GearSalvage
				end
				if name == "Schema" then
					return Schema
				end
				if shared[name] ~= true then
					error("Unexpected require " .. tostring(name), 2)
				end
				return require("../src/ReplicatedStorage/Shared/" .. name)
			end,
		},
	})
	return chunk()
end

local function rollPlayer(userId: number)
	return {
		ClassName = "Player",
		Name = "Echo",
		UserId = userId,
	}
end

local function salvageProfile(sinceLegendary: number)
	local data = Schema.template()
	data.shardTokens = 50
	-- Old Epic meter. Live rolls ignore it. The batch below proves that.
	data.sinceEpic = 45
	data.sinceLegendary = sinceLegendary
	data.autoSalvage = true
	data.autoSalvageRarity = "Common"
	return data
end

describe("Auto-salvage cap", function()
	it("refuses a client cap above Uncommon and lowers a saved one", function()
		expect(Schema.VERSION).toEqual(26)
		local saved = Schema.template()
		saved.schemaVersion = 26
		saved.gold = 40
		saved.gearEssence = 7
		saved.autoSalvage = true
		saved.autoSalvageRarity = "Mythic"
		saved.chestSalvageBelow = "Legendary"
		put(saved, sword("kept", "Rare", { upgrade = 2, favorite = true }))
		Schema.reconcile(saved)
		expect(saved.schemaVersion).toEqual(26)
		expect(saved.autoSalvage).toEqual(true)
		expect(saved.autoSalvageRarity).toEqual("Uncommon")
		expect(saved.chestSalvageBelow).toEqual("Uncommon")
		expect(saved.gold).toEqual(40)
		expect(saved.gearEssence).toEqual(7)
		expect(saved.inventory.kept.uid).toEqual("kept")
		expect(saved.inventory.kept.rarity).toEqual("Rare")
		expect(saved.inventory.kept.upgrade).toEqual(2)
		expect(saved.inventory.kept.favorite).toEqual(true)

		local live = fresh()
		live.gold = 3
		live.autoSalvage = true
		live.autoSalvageRarity = "Epic"
		put(live, sword("worn", "Rare"))
		GearSalvage.applySave(live)
		expect(live.autoSalvage).toEqual(true)
		expect(live.autoSalvageRarity).toEqual("Uncommon")
		expect(live.gold).toEqual(3)
		expect(live.inventory.worn.rarity).toEqual("Rare")

		withFlag(true, function()
			local data = fresh()
			data.gold = 8
			data.gearEssence = 4
			data.autoSalvage = true
			data.autoSalvageRarity = "Common"
			put(data, sword("bag", "Epic", { upgrade = 1 }))
			local shot = Schema.deepCopy(data)
			for _, rarity in ipairs({ "Rare", "Epic", "Legendary", "Mythic", "Secret" }) do
				local refused = GearSalvage.applyAction(data, 42, "auto", {
					enabled = true,
					rarity = rarity,
				}, 10)
				expect(refused.ok).toEqual(false)
				expect(refused.error).toEqual("Auto-salvage stops at Uncommon.")
				expect(data).toEqual(shot)
				local off = GearSalvage.applyAction(data, 42, "auto", {
					enabled = false,
					rarity = rarity,
				}, 10)
				expect(off.ok).toEqual(false)
				expect(off.error).toEqual("Auto-salvage stops at Uncommon.")
				expect(data).toEqual(shot)
			end
			local on = GearSalvage.applyAction(data, 42, "auto", {
				enabled = true,
				rarity = "Uncommon",
			}, 10)
			expect(on.ok).toEqual(true)
			expect(data.autoSalvage).toEqual(true)
			expect(data.autoSalvageRarity).toEqual("Uncommon")
			expect(data.gold).toEqual(8)
			expect(data.gearEssence).toEqual(4)
			expect(data.inventory.bag.upgrade).toEqual(1)

			data.autoSalvageRarity = "Secret"
			local common = GearSalvage.receive(data, sword("drop", "Common"))
			expect(common.kept).toEqual(false)
			expect(common.gained).toEqual(1)
			expect(data.autoSalvageRarity).toEqual("Uncommon")
			local rare = GearSalvage.receive(data, sword("rare", "Rare"))
			expect(rare.kept).toEqual(true)
			expect(data.inventory.rare).toBeNil()
			expect(data.inventory.bag.upgrade).toEqual(1)
			expect(data.gearEssence).toEqual(5)
		end)
		expect(LaunchGate.on("gearSalvage")).toEqual(false)
	end)
end)

describe("Auto-salvaged x10 batch", function()
	it("copies autoSalvaged and essenceGained onto batch rows", function()
		local current = { profile = salvageProfile(0) }
		local roll = loadRollService(current)
		local singlePlayer = rollPlayer(4101)
		local batchPlayer = rollPlayer(4102)

		withFlag(true, function()
			local single = roll.rollFree(singlePlayer, "verdant_armory", false)
			expect(single.ok).toEqual(true)
			expect(single.rarity).toEqual("Common")
			expect(single.autoSalvaged).toEqual(true)
			expect(single.essenceGained).toEqual(1)
			expect(current.profile.inventory[single.item.uid]).toBeNil()
			expect(current.profile.gearEssence).toEqual(1)

			-- 145 + four misses lands the fifth crack on Legendary pity 150.
			current.profile = salvageProfile(145)
			local batch = roll.rollMany(batchPlayer, "verdant_armory", 10)
			expect(batch.ok).toEqual(true)
			expect(batch.count).toEqual(10)
			expect(#batch.items).toEqual(10)
			local salvaged = 0
			local kept = 0
			for index, row in ipairs(batch.items) do
				if index == 5 then
					expect(row.rarity).toEqual("Legendary")
					expect(row.autoSalvaged).toBeNil()
					expect(row.essenceGained).toBeNil()
					expect(current.profile.inventory[row.item.uid]).toEqual(row.item)
					kept += 1
				else
					expect(row.rarity).toEqual("Common")
					expect(row.autoSalvaged).toEqual(single.autoSalvaged)
					expect(row.essenceGained).toEqual(single.essenceGained)
					expect(current.profile.inventory[row.item.uid]).toBeNil()
					salvaged += 1
				end
			end
			expect(salvaged).toEqual(9)
			expect(kept).toEqual(1)
			expect(current.profile.gearEssence).toEqual(9)
			expect(current.profile.shardTokens).toEqual(41)
			expect(current.profile.sinceEpic).toEqual(45)
			expect(Schema.countItems(current.profile)).toEqual(1)
		end)

		current.profile = salvageProfile(0)
		local closed = roll.rollMany(rollPlayer(4103), "verdant_armory", 10)
		expect(closed.ok).toEqual(true)
		expect(#closed.items).toEqual(10)
		for _, row in ipairs(closed.items) do
			expect(row.autoSalvaged).toBeNil()
			expect(row.essenceGained).toBeNil()
			expect(current.profile.inventory[row.item.uid]).toEqual(row.item)
		end
		expect(current.profile.gearEssence).toEqual(0)
		expect(current.profile.shardTokens).toEqual(41)
		expect(LaunchGate.on("gearSalvage")).toEqual(false)
	end)
end)
