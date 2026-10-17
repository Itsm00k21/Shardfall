--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local PetEvolution = require("../src/ReplicatedStorage/Shared/PetEvolution")
local WildCapture = require("../src/ReplicatedStorage/Shared/WildCapture")
local WildCaptureService = require("../src/ServerScriptService/ShardfallServer/WildCaptureService")

local function fox(level: number): any
	return {
		uid = "pet-1",
		species = "ember_fox",
		name = "Pip",
		speciesName = "Ember Fox",
		role = "Striker",
		rarity = "Common",
		personality = "Brave",
		level = level,
		xp = 12,
		bond = 3,
		affinity = 7,
		favorite = true,
		colors = { primary = "rose", secondary = "sap", glow = "none" },
		journal = { "Hatched", "First Legendary roll together" },
	}
end

local function pay(step: PetEvolution.Step): { [string]: number }
	local materials = {}
	for _, row in ipairs(step.materials) do
		materials[row.id] = row.count
	end
	return materials
end

describe("Pet evolution", function()
	it("gates on level, materials, and species", function()
		local young = fox(24)
		local ready, levelNote = PetEvolution.canEvolve(young, {})
		expect(ready).toEqual(false)
		expect(levelNote).toEqual("Reach level 25 to evolve.")

		local first = PetEvolution.next("ember_fox")
		expect(first ~= nil).toEqual(true)
		if first == nil then
			return
		end
		local short = pay(first)
		short.heartwood = 0
		local broke, need = PetEvolution.canEvolve(fox(25), short)
		expect(broke).toEqual(false)
		expect(need).toEqual("Need 4 Heartwood.")

		local wisp = fox(50)
		wisp.species = "pollen_wisp"
		local wrong, speciesNote = PetEvolution.canEvolve(wisp, pay(first))
		expect(wrong).toEqual(false)
		expect(speciesNote).toEqual("That companion cannot evolve.")

		local grew, growNote = PetEvolution.canEvolve(fox(25), pay(first))
		expect(grew).toEqual(true)
		expect(growNote).toEqual("Ready to evolve.")
		expect(first.level).toEqual(25)
		expect(first.species).toEqual("blaze_fox")
	end)

	it("keeps the name, affinity, and journal when the species changes", function()
		local pet = fox(50)
		local first = PetEvolution.next("ember_fox")
		expect(first ~= nil).toEqual(true)
		if first == nil then
			return
		end
		local materials = pay(first)
		local before = #pet.journal
		local ok, note, evolved, spent = PetEvolution.evolve(pet, materials)
		expect(ok).toEqual(true)
		expect(note).toEqual("Evolved to Blaze Fox")
		expect(evolved.species).toEqual("blaze_fox")
		expect(evolved.speciesName).toEqual("Blaze Fox")
		expect(evolved.ability).toEqual("blaze_bite")
		expect(evolved.name).toEqual("Pip")
		expect(evolved.affinity).toEqual(7)
		expect(evolved.favorite).toEqual(true)
		expect(evolved.uid).toEqual("pet-1")
		expect(evolved.bond).toEqual(3)
		expect(evolved.colors.primary).toEqual("rose")
		expect(evolved.journal[1]).toEqual("Hatched")
		expect(evolved.journal[2]).toEqual("First Legendary roll together")
		expect(evolved.journal[3]).toEqual("Evolved to Blaze Fox")
		evolved.colors.primary = "gold"
		expect(#pet.journal).toEqual(before)
		expect(pet.species).toEqual("ember_fox")
		expect(pet.colors.primary).toEqual("rose")
		expect(materials.heartwood).toEqual(first.materials[1].count)
		expect(spent.heartwood).toEqual(4)
		expect(spent.verdant_bark).toEqual(8)
		expect(spent.vine).toEqual(6)

		evolved.level = 50
		local second = PetEvolution.next("blaze_fox")
		expect(second ~= nil and second.level == 50).toEqual(true)
		if second == nil then
			return
		end
		local again, againNote, kitsune = PetEvolution.evolve(evolved, pay(second))
		expect(again).toEqual(true)
		expect(againNote).toEqual("Evolved to Inferno Kitsune")
		expect(kitsune.species).toEqual("inferno_kitsune")
		expect(kitsune.ability).toEqual("inferno_pounce")
		expect(kitsune.name).toEqual("Pip")
		expect(kitsune.affinity).toEqual(7)
		expect(kitsune.journal[3]).toEqual("Evolved to Blaze Fox")
		expect(kitsune.journal[4]).toEqual("Evolved to Inferno Kitsune")
		expect(evolved.species).toEqual("blaze_fox")
	end)

	it("walks the other Verdant chains in order", function()
		local chains = {
			{ "mossback", "ridgeback", "elder_mossback" },
			{ "root_mole", "burrow_mole", "den_architect" },
		}
		for _, chain in ipairs(chains) do
			local pet = fox(25)
			pet.species = chain[1]
			pet.name = "Den"
			local first = PetEvolution.next(chain[1])
			expect(first ~= nil).toEqual(true)
			if first ~= nil then
				local ok, _, mid = PetEvolution.evolve(pet, pay(first))
				expect(ok).toEqual(true)
				expect(mid.species).toEqual(chain[2])
				expect(mid.name).toEqual("Den")
				expect(mid.affinity).toEqual(7)
				mid.level = 50
				local second = PetEvolution.next(chain[2])
				expect(second ~= nil).toEqual(true)
				if second ~= nil then
					local finalOk, _, finalPet = PetEvolution.evolve(mid, pay(second))
					expect(finalOk).toEqual(true)
					expect(finalPet.species).toEqual(chain[3])
					expect(finalPet.name).toEqual("Den")
					expect(
						string.find(finalPet.journal[#finalPet.journal], "Evolved to ", 1, true)
							~= nil
					).toEqual(true)
				end
			end
		end
	end)
end)

describe("Wild capture", function()
	it("requires a charm and still misses on a high roll", function()
		local bare, bareNote = WildCapture.tryCapture(false, 0)
		expect(bare).toEqual(false)
		expect(bareNote).toEqual("Equip a Capture Charm.")

		local owned = {
			inventory = {
				c1 = { uid = "c1", templateId = WildCapture.CHARM_ITEM_ID },
			},
			equipped = { accessories = {} },
		}
		expect(WildCapture.charmEquipped(owned)).toEqual(false)
		owned.equipped.accessories.charm = "c1"
		expect(WildCapture.charmEquipped(owned)).toEqual(true)

		local tamed, tamedNote = WildCapture.tryCapture(true, 0)
		expect(tamed).toEqual(true)
		expect(tamedNote).toEqual("Tamed.")
		local missed, missedNote = WildCapture.tryCapture(true, WildCapture.CAPTURE_CHANCE)
		expect(missed).toEqual(false)
		expect(missedNote).toEqual("The shiny slipped away.")

		expect(WildCapture.rollShiny(0)).toEqual(true)
		expect(WildCapture.rollShiny(WildCapture.SHINY_SPAWN_RATE)).toEqual(false)

		local pet, petNote = WildCapture.shinyCompanion("vine_crawler")
		expect(petNote).toEqual("Tamed.")
		expect(pet.species).toEqual("vine_sprout")
		expect(pet.shiny).toEqual(true)
		expect(pet.golden).toEqual(true)
		expect(pet.statBonus).toEqual(WildCapture.SHINY_STAT_BONUS)
		expect(pet.statNote).toEqual("+5% stats")
		expect(pet.ability).toEqual("vine_lash")
		expect(pet.journal[1]).toEqual("Captured shiny")

		local blocked = WildCapture.shinyCompanion("grandmother_gnarl")
		expect(blocked).toBeNil()
	end)

	it("returns the Gnarlling species on a deterministic boss roll", function()
		local row = WildCapture.BOSS_PETS.grandmother_gnarl
		expect(row.species).toEqual("gnarlling")
		expect(row.ability).toEqual("tiny_gnarl")
		expect(row.dropRate < 0.05).toEqual(true)

		local pet, note = WildCapture.rollBossPet("grandmother_gnarl", 0)
		expect(note).toEqual("Gnarlling")
		expect(pet.species).toEqual("gnarlling")
		expect(pet.ability).toEqual("tiny_gnarl")
		expect(pet.bossPet).toEqual(true)
		expect(pet.shiny).toEqual(false)
		expect(pet.golden).toEqual(false)
		expect(pet.statBonus).toEqual(0)
		expect(pet.name).toEqual("Gnarlling")

		local missed = WildCapture.rollBossPet("grandmother_gnarl", row.dropRate)
		expect(missed).toBeNil()
		local unknown = WildCapture.rollBossPet("not_a_boss", 0)
		expect(unknown).toBeNil()
	end)
end)

describe("Wild capture service", function()
	local now = 0

	local function player(id: number): any
		return { ClassName = "Player", UserId = id }
	end

	local function useClock()
		WildCaptureService.setMutate(nil)
		WildCaptureService.setClock(function()
			return now
		end)
	end

	local function charmProfile(): any
		return {
			inventory = {
				c1 = { uid = "c1", templateId = WildCapture.CHARM_ITEM_ID },
			},
			equipped = { accessories = { charm = "c1" } },
			companions = {},
		}
	end

	local function useProfile(profile: any)
		WildCaptureService.setMutate(function(_who, mutator)
			local err = mutator(profile)
			if err ~= nil then
				return false, err
			end
			return true, nil
		end)
	end

	it("refuses a tame before the shiny is defeated", function()
		now = 1000
		useClock()
		local who = player(1)
		WildCaptureService.clear(who)
		expect(WildCapture.TAME_WINDOW).toEqual(30)

		local noted = WildCaptureService.noteShiny(who, "vine_crawler", 0)
		expect(noted.shiny).toEqual(true)
		local early = WildCaptureService.tame(who, {
			enemyId = "vine_crawler",
			defeated = true,
			roll = 0,
		})
		expect(early.ok).toEqual(false)
		expect(early.error).toEqual("Defeat the shiny first.")

		local fromClient = WildCaptureService.handle(who, "tame", {
			enemyId = "vine_crawler",
			defeated = true,
			roll = 0,
		})
		expect(fromClient.ok).toEqual(false)
		expect(fromClient.error).toEqual("Defeat the shiny first.")
		expect(WildCaptureService.markDefeated(who, "vine_crawler").ok).toEqual(true)
	end)

	it("refuses a tame after the window and keeps the mark", function()
		now = 2000
		useClock()
		local who = player(2)
		WildCaptureService.clear(who)
		WildCaptureService.noteShiny(who, "spore_bat", 0)
		expect(WildCaptureService.markDefeated(who, "spore_bat").ok).toEqual(true)

		now = 2000 + WildCapture.TAME_WINDOW
		local late = WildCaptureService.tame(who, { enemyId = "spore_bat", roll = 0 })
		expect(late.ok).toEqual(false)
		expect(late.error).toEqual("The shiny slipped away.")
		local again = WildCaptureService.tame(who, { enemyId = "spore_bat", roll = 0 })
		expect(again.ok).toEqual(false)
		expect(again.error).toEqual("The shiny slipped away.")
	end)

	it("tames inside the window with a charm and a winning roll", function()
		now = 3000
		useClock()
		local who = player(3)
		WildCaptureService.clear(who)
		WildCaptureService.noteShiny(who, "vine_crawler", 0)
		expect(WildCaptureService.markDefeated(who, "vine_crawler").ok).toEqual(true)
		now = 3000 + WildCapture.TAME_WINDOW - 1

		local profile = charmProfile()
		useProfile(profile)
		local caught = WildCaptureService.tame(who, { enemyId = "vine_crawler", roll = 0 })
		expect(caught.ok).toEqual(true)
		expect(caught.shiny).toEqual(true)
		expect(caught.species).toEqual("vine_sprout")
		expect(caught.name).toEqual("Vine Sprout")
		expect(#profile.companions).toEqual(1)
		expect(profile.companions[1].shiny).toEqual(true)
		expect(profile.companions[1].golden).toEqual(true)
		expect(profile.companions[1].statBonus).toEqual(WildCapture.SHINY_STAT_BONUS)

		local spent = WildCaptureService.tame(who, { enemyId = "vine_crawler", roll = 0 })
		expect(spent.ok).toEqual(false)
		expect(spent.error).toEqual("No shiny is here.")

		WildCaptureService.noteShiny(who, "thorn_sprite", 0)
		WildCaptureService.markDefeated(who, "thorn_sprite")
		local bare = {
			inventory = {},
			equipped = { accessories = {} },
			companions = {},
		}
		useProfile(bare)
		local unarmed = WildCaptureService.tame(who, { enemyId = "thorn_sprite", roll = 0 })
		expect(unarmed.ok).toEqual(false)
		expect(unarmed.error).toEqual("Equip a Capture Charm.")
		local bareGone = WildCaptureService.tame(who, { enemyId = "thorn_sprite", roll = 0 })
		expect(bareGone.ok).toEqual(false)
		expect(bareGone.error).toEqual("No shiny is here.")

		useProfile(profile)
		WildCaptureService.noteShiny(who, "moss_crawler", 0)
		WildCaptureService.markDefeated(who, "moss_crawler")
		local missed = WildCaptureService.tame(who, {
			enemyId = "moss_crawler",
			roll = WildCapture.CAPTURE_CHANCE,
		})
		expect(missed.ok).toEqual(false)
		expect(missed.error).toEqual("The shiny slipped away.")
		local gone = WildCaptureService.tame(who, { enemyId = "moss_crawler", roll = 0 })
		expect(gone.ok).toEqual(false)
		expect(gone.error).toEqual("No shiny is here.")
	end)

	it("drops every mark when the run is cleared", function()
		now = 4000
		useClock()
		local who = player(4)
		WildCaptureService.noteShiny(who, "vine_crawler", 0)
		WildCaptureService.noteShiny(who, "root_brute", 0)
		expect(WildCaptureService.markDefeated(who, "vine_crawler").ok).toEqual(true)
		WildCaptureService.clear(who)

		local defeated = WildCaptureService.tame(who, { enemyId = "vine_crawler", roll = 0 })
		expect(defeated.ok).toEqual(false)
		expect(defeated.error).toEqual("No shiny is here.")
		local spawned = WildCaptureService.tame(who, { enemyId = "root_brute", roll = 0 })
		expect(spawned.ok).toEqual(false)
		expect(spawned.error).toEqual("No shiny is here.")
		expect(WildCaptureService.markDefeated(who, "vine_crawler").ok).toEqual(false)
		expect(WildCaptureService.markDefeated(who, "root_brute").ok).toEqual(false)
	end)
end)
