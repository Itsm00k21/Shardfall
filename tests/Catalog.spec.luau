--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Areas = require("../src/ReplicatedStorage/Shared/Areas")
local ItemBases = require("../src/ReplicatedStorage/Shared/ItemBases")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")

local function weightSum(pool): number
	local sum = 0
	for _, entry in ipairs(pool.entries) do
		sum += entry.weight
	end
	return sum
end

describe("Catalog", function()
	it("splits weapons and armor from pets and gates realms by ascension", function()
		local areas = Areas.all()
		expect(#areas).toEqual(2)
		expect(areas[1].id).toEqual("armory")
		expect(areas[2].id).toEqual("pets")
		expect(Areas.get("nope")).toBeNil()

		for _, area in ipairs(areas) do
			local pools = Areas.pools(area.id)
			expect(#pools).toEqual(5)
			for index, pool in ipairs(pools) do
				expect(pool.ascension).toEqual(index - 1)
				expect(pool.placeholder).toBeTrue()
				expect(pool.public).toBeTrue()
				expect(pool.pityLegendaryAt).toEqual(RarityConfig.LEGENDARY_PITY)
				expect(pool.pityLegendaryAt).toEqual(1000)
				expect(weightSum(pool)).toEqual(10000)
				expect(Pools.isUnlocked(pool, pool.ascension)).toBeTrue()
				expect(Pools.isUnlocked(pool, pool.ascension - 1)).toBeFalse()
			end
		end

		expect(Pools.isUnlocked(Pools.forArea("armory")[1], 0)).toBeTrue()
		expect(#Pools.forArea("armory")).toEqual(5)
		local unlocked = 0
		for _, pool in ipairs(Pools.forArea("pets")) do
			if Pools.isUnlocked(pool, 2) then
				unlocked += 1
			end
		end
		expect(unlocked).toEqual(3)
	end)

	it("gives Verdant Wilds a roster and the later realms a placeholder each", function()
		local armory = Pools.get("verdant_armory")
		local pets = Pools.get("verdant_pets")
		assert(armory ~= nil and pets ~= nil)
		expect(#armory.entries).toBeGreaterThan(20)
		expect(#pets.entries).toBeGreaterThan(10)
		expect(armory.theme).toEqual("Nature, beasts, wood, and vines")

		local types = {}
		local grove = {}
		for _, entry in ipairs(armory.entries) do
			local base = ItemBases.get(entry.templateId)
			assert(base ~= nil)
			expect(base.kind ~= "Pet").toBeTrue()
			expect(base.ascension).toEqual(0)
			expect(base.rarity).toEqual(entry.rarity)
			expect(base.name).toEqual(entry.name)
			if base.weaponType ~= nil then
				types[base.weaponType] = true
			end
			if base.setId == "grovewarden" then
				grove[base.slot] = true
				expect(base.rarity).toEqual("Epic")
			end
			if base.kind ~= "Pet" then
				expect(base.stats ~= nil and #base.stats > 0).toBeTrue()
			end
		end
		for _, weaponType in ipairs({ "sword", "bow", "staff", "dagger", "hammer" }) do
			expect(types[weaponType]).toBeTrue()
		end
		expect(grove.helm).toBeTrue()
		expect(grove.chest).toBeTrue()
		expect(grove.legs).toBeTrue()
		expect(grove.boots).toBeTrue()

		for _, entry in ipairs(pets.entries) do
			local base = ItemBases.get(entry.templateId)
			assert(base ~= nil and base.stats ~= nil)
			expect(base.kind).toEqual("Pet")
			expect(base.weaponType).toBeNil()
			expect(#base.stats).toBeGreaterThan(1)
			local damage = false
			local speed = false
			for _, stat in ipairs(base.stats) do
				if stat.id == "pet_damage" then
					damage = true
				elseif stat.id == "attack_speed" then
					speed = true
				end
			end
			expect(damage).toBeTrue()
			if entry.templateId == "moss_hare" then
				expect(#base.stats).toEqual(2)
				expect(speed).toBeFalse()
			elseif entry.templateId == "fern_stag" then
				expect(speed).toBeTrue()
				expect(base.petStyle).toEqual("beast")
			end
		end

		for _, pool in ipairs(Pools.all()) do
			if pool.ascension > 0 then
				expect(#pool.entries).toEqual(7)
				local seen = {}
				for _, entry in ipairs(pool.entries) do
					expect(seen[entry.rarity] == nil).toBeTrue()
					seen[entry.rarity] = true
					expect(Rarities.INDEX[entry.rarity] ~= nil).toBeTrue()
				end
			end
		end
	end)
end)
