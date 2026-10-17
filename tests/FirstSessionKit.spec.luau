--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local FirstSessionKit = require("../src/ReplicatedStorage/Shared/FirstSessionKit")
local ItemBases = require("../src/ReplicatedStorage/Shared/ItemBases")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local CLASSES = { "warden", "tidecaller", "forgeborn", "frostblade", "voidcaster" }

local function count(map): number
	local total = 0
	if type(map) ~= "table" then
		return 0
	end
	for _ in pairs(map) do
		total += 1
	end
	return total
end

describe("FirstSessionKit", function()
	it("mints the class weapon, the Common vest, and one Shardjaw, with no ring", function()
		for _, classId in ipairs(CLASSES) do
			local data = Schema.template()
			expect(data.firstSession.returning).toEqual(false)
			data.classId = classId
			local gold = data.gold
			local keys = data.shardKeys
			local noted = FirstSessionKit.grant(data)
			expect(noted.ok).toEqual(true)
			expect(noted.accepted).toEqual(true)
			expect(noted.petId).toEqual("shardjaw")
			expect(#data.companions).toEqual(1)
			expect(data.companions[1].species).toEqual("shardjaw")
			expect(data.companions[1].name).toEqual("Shardjaw")
			expect(data.companions[1].role).toEqual("Gatherer")
			expect(noted.ringId).toBeNil()
			expect(noted.armorId).toEqual("woven_bark_vest")
			expect(noted.weaponId).toEqual(FirstSessionKit.WEAPONS[classId])
			expect(data.gold).toEqual(gold)
			expect(data.shardKeys).toEqual(keys)
			expect(count(data.pets)).toEqual(0)
			expect(data.equipped.pet).toBeNil()
			expect(data.equipped.accessories.ring).toBeNil()
			local weapon = data.inventory[data.equipped.weapon]
			local armor = data.inventory[data.equipped.armor.chest]
			expect(weapon.templateId).toEqual(FirstSessionKit.WEAPONS[classId])
			expect(weapon.kind).toEqual("Weapon")
			expect(armor.templateId).toEqual("woven_bark_vest")
			expect(armor.kind).toEqual("Armor")
			expect(armor.rarity).toEqual("Common")
			expect(armor.slot).toEqual("chest")
			if classId == "forgeborn" then
				expect(weapon.templateId).toEqual("iron_hammer")
				expect(weapon.rarity).toEqual("Common")
				expect(weapon.sockets).toEqual(0)
			else
				expect(weapon.rarity).toEqual("Rare")
				expect(weapon.sockets).toEqual(1)
			end
			expect(ItemBases.get(weapon.templateId).ascension).toEqual(0)
			for _, item in pairs(data.inventory) do
				expect(item.kind == "Pet").toEqual(false)
				expect(item.templateId == "moss_hare" or item.templateId == "acorn_newt").toEqual(
					false
				)
				expect(item.templateId == "mossback" or item.templateId == "tide_sprite").toEqual(
					false
				)
				expect(
					item.templateId == "living_bark_cuirass" or item.templateId == "green_tyrant"
				).toEqual(false)
			end
			expect(count(data.inventory)).toEqual(2)
			local again = FirstSessionKit.grant(data)
			expect(again.accepted).toEqual(false)
			expect(count(data.inventory)).toEqual(2)
			expect(count(data.pets)).toEqual(0)
			expect(#data.companions).toEqual(1)

			local rejoined = Schema.migrate({
				schemaVersion = 23,
				classId = classId,
				gold = 3,
				firstSession = data.firstSession,
				inventory = {},
				pets = {},
				equipped = {
					weapon = nil,
					pet = nil,
					armor = {},
					accessories = {},
				},
			})
			assert(rejoined ~= nil)
			expect(FirstSessionKit.grant(rejoined).accepted).toEqual(false)
			expect(count(rejoined.inventory)).toEqual(0)
			expect(count(rejoined.pets)).toEqual(0)
			expect(rejoined.gold).toEqual(3)
		end
	end)

	it(
		"starts an alt fresh and withholds the kit from an onboarded save and from a classless skip",
		function()
			local main = Schema.template()
			main.classId = "warden"
			FirstSessionKit.grant(main)
			local alt = Schema.template()
			alt.classId = "tidecaller"
			expect(alt.firstSession.granted.chest).toEqual(false)
			expect(FirstSessionKit.grant(alt).weaponId).toEqual("mycelium_staff")
			expect(count(main.inventory)).toEqual(2)
			expect(count(alt.inventory)).toEqual(2)

			local old = Schema.migrate({
				schemaVersion = 22,
				onboardDone = true,
				classId = "warden",
				gold = 11,
			})
			assert(old ~= nil)
			expect(old.schemaVersion).toEqual(23)
			expect(old.gold).toEqual(11)
			expect(old.firstSession.returning).toEqual(true)
			old.companions = {
				{ species = "mossback", name = "Mossback Turtle" },
				{ species = "mossback", name = "Mossback Turtle" },
				{ species = "mossback", name = "Mossback Turtle" },
			}
			expect(FirstSessionKit.grant(old).accepted).toEqual(false)
			expect(count(old.inventory)).toEqual(0)
			expect(count(old.pets)).toEqual(0)
			expect(#old.companions).toEqual(3)
			expect(old.companions[1].species).toEqual("mossback")

			local fresh = Schema.migrate({ schemaVersion = 22, onboardDone = false, gold = 2 })
			assert(fresh ~= nil)
			expect(fresh.firstSession.returning).toEqual(false)
			expect(fresh.gold).toEqual(2)
			local early = FirstSessionKit.grant(fresh)
			expect(early.ok).toEqual(false)
			expect(early.accepted).toEqual(false)
			expect(count(fresh.inventory)).toEqual(0)
			expect(fresh.firstSession.granted.forge).toEqual(false)
		end
	)

	it(
		"keeps the currency kit in Onboarding and does not mint a cute pet or a fake ring",
		function()
			local onboarding = fs.readFile("src/ReplicatedStorage/Shared/Onboarding.luau")
			expect(string.find(onboarding, "data.gold = (data.gold or 0) + 250", 1, true) ~= nil).toBeTrue()
			expect(
				string.find(onboarding, "data.shardKeys = (data.shardKeys or 0) + 40", 1, true)
					~= nil
			).toBeTrue()
			expect(string.find(onboarding, "healing_tonic", 1, true) ~= nil).toBeTrue()
			expect(string.find(onboarding, "FirstSession", 1, true)).toBeNil()

			local kit = fs.readFile("src/ReplicatedStorage/Shared/FirstSessionKit.luau")
			expect(string.find(kit, "shardjaw", 1, true) ~= nil).toBeTrue()
			expect(string.find(kit, "Pets.hatch", 1, true)).toBeNil()
			expect(string.find(kit, "TODO(G-078)", 1, true)).toBeNil()
			expect(string.find(kit, "Marketplace", 1, true)).toBeNil()
			expect(string.find(kit, "productId", 1, true)).toBeNil()
			expect(string.find(kit, "verdant_ring", 1, true) ~= nil).toBeTrue()
			expect(FirstSessionKit.RING_ID).toBeNil()
			expect(ItemBases.get("woven_bark_vest").rarity).toEqual("Common")
			expect(ItemBases.get("living_bark_cuirass").rarity).toEqual("Rare")
			expect(ItemBases.get("green_tyrant").rarity).toEqual("Mythic")

			local select = fs.readFile("src/ServerScriptService/ShardfallServer/ClassService.luau")
			local classAt = string.find(select, "data.classId = classId", 1, true)
			local grantAt = string.find(select, "FirstSessionKit.grant(data)", 1, true)
			expect(classAt ~= nil and grantAt ~= nil and (classAt :: number) < (grantAt :: number)).toBeTrue()
			local skip =
				fs.readFile("src/ServerScriptService/ShardfallServer/OnboardingService.luau")
			expect(string.find(skip, "Onboarding.starter(data)", 1, true) ~= nil).toBeTrue()
			expect(string.find(skip, "FirstSessionKit.grant(data)", 1, true) ~= nil).toBeTrue()
			expect(string.find(skip, "classId", 1, true)).toBeNil()
		end
	)
end)
