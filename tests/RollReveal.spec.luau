--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local RollReveal = require("../src/ReplicatedStorage/Shared/RollReveal")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

describe("Roll reveal", function()
	it("keeps the spin and the card on the same roll id", function()
		local previous = RollReveal.capture({
			rollId = "vinewood",
			item = { uid = "vinewood", name = "Vinewood Sword", rarity = "Common" },
		})
		local current = RollReveal.capture({
			rollId = "briar",
			item = { uid = "briar", name = "Briar Mace", rarity = "Rare" },
		})
		expect(previous ~= nil).toBeTrue()
		expect(current ~= nil).toBeTrue()
		local spun = RollReveal.present(current :: any)
		local card = RollReveal.present(current :: any)
		expect(spun.id).toEqual("briar")
		expect(card.id).toEqual(spun.id)
		expect(card.name).toEqual("Briar Mace")
		expect(card.name).toEqual(spun.name)
		expect(card.name ~= (previous :: any).name).toBeTrue()
	end)

	it("lands the strip on the resolved item without a near-miss", function()
		local pool = Pools.get("verdant_armory")
		local record = {
			id = "briar",
			name = "Briar Mace",
			rarity = "Rare",
		}
		local slots = RollReveal.strip(48271, pool, record)
		local last = slots[#slots]
		expect(last.name).toEqual("Briar Mace")
		expect(last.rarity).toEqual("Rare")
		local rareRank = 3
		for index = math.max(1, #slots - 4), #slots - 1 do
			local row = slots[index]
			local higher = row.rarity == "Epic"
				or row.rarity == "Legendary"
				or row.rarity == "Mythic"
				or row.rarity == "Secret"
			expect(higher).toBeFalse()
			expect(row.rarity == "Rare" or row.rarity == "Common" or row.rarity == "Uncommon").toBeTrue()
			expect(index > 0 and rareRank == 3).toBeTrue()
		end
	end)

	it("follows the full clock and skips from the first moment", function()
		local settings = Settings.default()
		settings.rolls.skipAt = "off"
		expect(RollReveal.duration(settings, "Epic", false)).toEqual(1.65)
		expect(RollReveal.skipReady(0, 1.65)).toBeTrue()
		expect(RollReveal.dim(0, 1.65)).toEqual(0)
		expect(RollReveal.dim(0.15, 1.65)).toEqual(1)
		expect(RollReveal.spinProgress(0.15, 1.65)).toEqual(0)
		expect(RollReveal.spinProgress(0.6, 1.65) > RollReveal.spinProgress(0.3, 1.65)).toBeTrue()
		expect(RollReveal.spinProgress(1.3, 1.65)).toEqual(1)
		expect(RollReveal.glow(1.0, 1.65, "Epic")).toBeTrue()
		expect(RollReveal.glow(1.0, 1.65, "Rare")).toBeFalse()
		expect(RollReveal.morph(1.3, 1.65)).toEqual(nil)
		local morph = RollReveal.morph(1.5, 1.65)
		expect(morph ~= nil and (morph :: number) > 0).toBeTrue()
		expect(RollReveal.morphScale(0)).toEqual(0.85)
		expect(RollReveal.morphScale(1)).toEqual(1)
		expect(RollReveal.flashOn(1.2, 1.65, "Legendary")).toBeTrue()
		expect(RollReveal.flashOn(1.2, 1.65, "Epic")).toBeFalse()
		expect(RollReveal.particles(1.2, 1.65, "Legendary")).toBeTrue()
		expect(RollReveal.particles(1.7, 1.65, "Legendary")).toBeFalse()
	end)

	it("honors the saved animation and never slows a paid roll", function()
		local settings = Settings.default()
		expect(RollReveal.duration(settings, "Epic", false)).toEqual(1.65)
		expect(RollReveal.duration(settings, "Legendary", false)).toEqual(0)
		settings.rolls.animation = "short"
		expect(RollReveal.duration(settings, "Epic", false)).toEqual(0.7)
		expect(RollReveal.duration(settings, "Epic", true) <= 0.7).toBeTrue()
		settings.rolls.animation = "instant"
		expect(RollReveal.duration(settings, "Epic", false)).toEqual(0)
		expect(RollReveal.duration(settings, "Mythic", true)).toEqual(0)
		settings.rolls.animation = "full"
		settings.rolls.skipAt = "off"
		local free = RollReveal.duration(settings, "Legendary", false)
		local paid = RollReveal.duration(settings, "Legendary", true)
		expect(paid <= free).toBeTrue()
		expect(free).toEqual(1.65)
	end)

	it("clears the previous card on a miss and does not invent a near-miss", function()
		local landed = RollReveal.capture({
			rollId = "vinewood",
			item = { uid = "vinewood", name = "Vinewood Sword", rarity = "Common" },
		})
		expect(landed ~= nil).toBeTrue()
		local shown = RollReveal.face(landed)
		expect(shown).toEqual({
			visible = true,
			name = "Vinewood Sword",
			rarity = "Common",
		})
		local again = RollReveal.face(landed)
		expect(again).toEqual(shown)
		expect(again ~= shown).toBeTrue()
		expect((landed :: any).visible).toBeNil()

		local cooled = RollReveal.capture({ ok = false, error = "Roll cooling down." })
		expect(cooled).toBeNil()
		local missed = RollReveal.face(cooled)
		expect(missed).toEqual({
			visible = false,
			name = "",
			rarity = "",
		})
		expect(shown.visible).toEqual(true)
		expect(shown.name).toEqual("Vinewood Sword")

		local paidMiss = RollReveal.face(RollReveal.capture({
			ok = false,
			paid = true,
			currency = "prism",
			error = "You cannot pay for that crack.",
			almost = "Mythic",
			odds = { Legendary = 1 },
		}))
		expect(paidMiss).toEqual(missed)
		expect(paidMiss ~= missed).toBeTrue()

		local nextLand = RollReveal.face(RollReveal.capture({
			rollId = "briar",
			item = { uid = "briar", name = "Briar Mace", rarity = "Rare" },
		}))
		expect(nextLand.name).toEqual("Briar Mace")
		expect(nextLand.name ~= shown.name).toBeTrue()
		expect(nextLand.visible).toEqual(true)
	end)

	it("captions a refused roll with the server reason and a miss stays Miss", function()
		expect(RollReveal.reelCaption({
			ok = false,
			error = "Roll cooling down.",
		})).toEqual("Roll cooling down.")
		expect(RollReveal.reelCaption({
			ok = false,
			paid = true,
			error = "You need a Shard Token to crack a shard.",
		})).toEqual("You need a Shard Token to crack a shard.")
		expect(RollReveal.reelCaption({
			ok = false,
			error = "Inventory is full.",
		})).toEqual("Inventory is full.")
		expect(RollReveal.reelCaption({
			ok = false,
			error = "  Roll cooling down.  ",
		})).toEqual("Roll cooling down.")
		expect(RollReveal.reelCaption({ ok = false })).toEqual("Miss")
		expect(RollReveal.reelCaption({ error = "" })).toEqual("Miss")
		expect(RollReveal.reelCaption({ error = "   " })).toEqual("Miss")
		expect(RollReveal.reelCaption({ error = 12 })).toEqual("Miss")
		expect(RollReveal.reelCaption(nil)).toEqual("Miss")
		expect(RollReveal.reelCaption("Inventory is full.")).toEqual("Miss")
		expect(RollReveal.reelCaption({ error = "Roll cooling down.\nstack" })).toEqual("Miss")
		local cooled = RollReveal.capture({ ok = false, error = "Roll cooling down." })
		expect(cooled).toBeNil()
		expect(RollReveal.face(cooled)).toEqual({
			visible = false,
			name = "",
			rarity = "",
		})
	end)

	it("hides the reveal card on leave, on every hide, and on a refused roll", function()
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local blankAt = string.find(hub, "function hubFn.blankReveal()", 1, true)
		expect(blankAt ~= nil).toBeTrue()
		local blankEnd = string.find(hub, "hubState.closeBeat = Instance.new", blankAt or 1, true)
		expect(blankEnd ~= nil and (blankEnd :: number) > (blankAt :: number)).toBeTrue()
		local blank = string.sub(hub, blankAt or 1, (blankEnd or 1) - 1)
		expect(string.find(blank, "local face = RollReveal.face(nil)", 1, true) ~= nil).toBeTrue()
		expect(string.find(blank, "revealCard.Visible = face.visible", 1, true) ~= nil).toBeTrue()
		expect(string.find(blank, "revealTitle.Text = face.name", 1, true) ~= nil).toBeTrue()
		expect(string.find(blank, "revealRarity.Text = face.rarity", 1, true) ~= nil).toBeTrue()
		expect(string.find(blank, "bumpCardGeneration()", 1, true) ~= nil).toBeTrue()
		expect(string.find(blank, "activeReveal = nil", 1, true) ~= nil).toBeTrue()
		expect(string.find(blank, "showCloseBeat", 1, true)).toBeNil()
		expect(string.find(blank, "revealCard.Visible = true", 1, true)).toBeNil()

		local leaveAt =
			string.find(hub, 'local leftRoll = hubState.shownId == "roll" and id ~= "roll"', 1, true)
		local leaveEnd = string.find(hub, "function hubFn.publishBadges", leaveAt or 1, true)
		local leave = string.sub(hub, leaveAt or 1, (leaveEnd or 1) - 1)
		expect(string.find(leave, "stopRollChain()", 1, true) ~= nil).toBeTrue()
		expect(string.find(leave, "blankReveal()", 1, true) ~= nil).toBeTrue()

		local _, blankCalls = string.gsub(hub, "blankReveal%(%)", "")
		-- The definition plus leave, the miss, and the three other hides.
		expect(blankCalls).toEqual(6)
		local _, hidden = string.gsub(hub, "revealCard%.Visible = false", "")
		expect(hidden).toEqual(1)

		local rollAt = string.find(hub, "beginRoll = function()", 1, true)
		local finishAt = string.find(hub, "function hubFn.pointerDown", rollAt or 1, true)
		local body = string.sub(hub, rollAt or 1, (finishAt or 1) - 1)
		expect(string.find(body, "paintReelIdle(RollReveal.reelCaption(result))", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, 'paintReelIdle("Miss")', 1, true)).toBeNil()
		expect(string.find(hub, "placeReelWindows(false)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "placeReelWindows(wide)", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "blankReveal()", 1, true) ~= nil).toBeTrue()
		local _, bodyBlanks = string.gsub(body, "blankReveal%(%)", "")
		expect(bodyBlanks).toEqual(4)
		expect(string.find(body, "revealTitle.Text =", 1, true)).toBeNil()

		local heartbeat = string.find(hub, "active.generation ~= hubState.cardGeneration", 1, true)
		expect(heartbeat ~= nil).toBeTrue()
		local invokeAt = string.find(hub, 'hooks.invoke, "RollShard"', rollAt or 1, true)
		local opening = string.sub(hub, rollAt or 1, (invokeAt or 2) - 1)
		expect(string.find(opening, "bumpCardGeneration()", 1, true) ~= nil).toBeTrue()
		expect(string.find(opening, "revealToken += 1", 1, true) ~= nil).toBeTrue()
		expect(string.find(opening, "flashCover.BackgroundTransparency = 1", 1, true) ~= nil).toBeTrue()
	end)

	it("keeps the item name off the HP bar", function()
		local margin = UiTheme.safeMargin()
		for _, size in ipairs({
			{ 1280, 800 },
			{ 1920, 1080 },
			{ 844, 390 },
		}) do
			local name = RollReveal.nameRect(size[1], size[2], margin)
			local health = HudLayout.health(margin)
			expect(RollReveal.separated(name, health)).toBeTrue()
			expect(name.y >= health.y + health.h).toBeTrue()
		end
	end)
end)
