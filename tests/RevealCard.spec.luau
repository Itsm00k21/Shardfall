--!strict

-- Kevin, Oct 22 9:55 PM: a "Shard" card showed the title and an empty
-- dark-gray body (no icon, rarity text or stats) on x1 and x10. The crack
-- hid the crystal behind a wide "Shard" window and the staged card was
-- blank. Every face now has an icon, a title, a rarity line and a detail.

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local GuiFake = require("./GuiFake")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local RollReveal = require("../src/ReplicatedStorage/Shared/RollReveal")
local IconAssets = require("../src/ReplicatedStorage/Shared/IconAssets")

local entry = (Pools.get("verdant_armory") :: any).entries[1]

local function rig()
	local world = GuiFake.world()
	local count = 0
	local function item()
		count += 1
		return {
			uid = "u" .. count,
			templateId = entry.templateId,
			name = entry.name,
			rarity = "Rare",
			kind = entry.kind,
			stats = { { id = "power", value = 12 } },
		}
	end
	local MenuHub = world.load("MenuHub")
	local hub = MenuHub.start(world.playerGui, {
		invoke = function(name: string)
			if name == "RollShard" then
				return { ok = true, item = item(), rarity = "Rare", fillerSeed = 3 }
			end
			if name == "RollShards" then
				local items = {}
				for index = 1, 10 do
					table.insert(items, { item = item(), rarity = "Rare", fillerSeed = index })
				end
				return { ok = true, items = items }
			end
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
	})
	hub.setProfile({
		level = 20,
		xp = 0,
		classId = "warden",
		classXp = { warden = 1800 },
		shardTokens = 50,
		gold = 0,
		shardRolls = 0,
		inventory = {},
		pets = {},
		equipped = {},
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	})
	hub.open("roll")
	world.clock.now = 100
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
	local card = GuiFake.findNamed(screen, "Reveal")
	local reel = GuiFake.findNamed(screen, "Reel")
	return {
		world = world,
		screen = screen,
		card = card,
		stone = GuiFake.findNamed(reel, "Shard"),
		step = function(seconds: number)
			local left = seconds
			while left > 0 do
				world.clock.now += 0.1
				world.runService.Heartbeat:Fire(0.1)
				left -= 0.1
			end
		end,
	}
end

local function filled(card: any): boolean
	local title = GuiFake.findNamed(card, "Name")
	local rarity = GuiFake.findNamed(card, "Rarity")
	local detail = GuiFake.findNamed(card, "Detail")
	local icon = GuiFake.findNamed(card, "Icon")
	return title.Text ~= ""
		and rarity.Text ~= ""
		and detail.Text ~= ""
		and type(icon.Image) == "string"
		and icon.Image ~= ""
end

describe("Roll reveal card faces", function()
	it("shows the cracking shard with an icon, not a blank body (x1)", function()
		local r = rig()
		GuiFake.activate(GuiFake.findNamed(r.screen, "Roll"))
		r.step(0.2)
		expect(r.card.Visible).toEqual(true)
		expect(filled(r.card)).toEqual(true)
		expect(GuiFake.findNamed(r.card, "Name").Text).toEqual("Shard")
		expect(GuiFake.findNamed(r.card, "Icon").Image).toEqual(IconAssets.Shards)
		-- The crystal that cracks stays on screen during the crack.
		expect(r.stone.Visible).toEqual(true)
	end)

	it("lands with the gear icon, name, rarity and stats", function()
		local r = rig()
		GuiFake.activate(GuiFake.findNamed(r.screen, "Roll"))
		r.step(0.2)
		-- A second press skips straight to the landed card.
		GuiFake.activate(GuiFake.findNamed(r.screen, "Roll"))
		r.step(0.3)
		expect(GuiFake.findNamed(r.card, "Name").Text).toEqual(entry.name)
		expect(filled(r.card)).toEqual(true)
		expect(string.find(GuiFake.findNamed(r.card, "Rarity").Text, "Rare", 1, true) ~= nil).toEqual(true)
	end)

	it("never shows a blank Shard face on any x10 card", function()
		local r = rig()
		GuiFake.activate(GuiFake.findNamed(r.screen, "TimesTen"))
		local blanks = 0
		local sawCount = false
		for _ = 1, 120 do
			r.step(0.1)
			if r.card.Visible and not filled(r.card) then
				blanks += 1
			end
			local detail = GuiFake.findNamed(r.card, "Detail").Text
			if string.find(detail, "of 10", 1, true) ~= nil then
				sawCount = true
			end
		end
		expect(blanks).toEqual(0)
		expect(sawCount).toEqual(true)
	end)

	it("builds pending, gear and currency faces", function()
		local pending = RollReveal.pendingFace(3, 10)
		expect(pending.title).toEqual("Shard")
		expect(pending.icon).toEqual("Shards")
		expect(pending.detail).toEqual("Card 3 of 10")
		expect(RollReveal.pendingFace(1, 1).detail ~= "").toEqual(true)
		local record = { id = "a", name = "Iron Blade", rarity = "Epic" }
		local gear = RollReveal.cardFace({ kind = "Weapon", templateId = "x" }, record, { "Power  12", "Haste  3", "Crit  1" })
		expect(gear.icon).toEqual("ItemWeapon")
		expect(gear.detail).toEqual("Power  12  ·  Haste  3")
		expect(string.find(gear.rarity, "Epic", 1, true) ~= nil).toEqual(true)
		local bare = RollReveal.cardFace({ kind = "Armor", templateId = "y" }, record, {})
		expect(bare.detail).toEqual("Armor")
		local coins = RollReveal.cardFace({ amount = 25 }, { id = "c", name = "Shard", rarity = "Common" }, nil)
		expect(coins.title).toEqual("+25 Shards")
		expect(coins.icon).toEqual("Shards")
		expect(coins.detail ~= "").toEqual(true)
		for _, face in ipairs({ pending, gear, bare, coins }) do
			expect(type((IconAssets :: any)[face.icon])).toEqual("string")
		end
	end)
end)
