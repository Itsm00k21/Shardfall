--!strict

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
