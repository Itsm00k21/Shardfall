--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Schema = require("../src/ReplicatedStorage/Shared/Schema")

describe("Schema", function()
	it("starts a new profile at version 1 with starter tokens", function()
		local profile = Schema.template()
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.level).toEqual(1)
		expect(profile.shardTokens).toEqual(25)
		expect(profile.shardLuck).toEqual(0)
		expect(profile.gold).toEqual(0)
		expect(profile.ascension).toEqual(0)
		expect(profile.equipped.weapon).toBeNil()
		expect(profile.equipped.pet).toBeNil()
	end)

	it("migrates an empty save without wiping fields that already exist", function()
		local saved = {
			gold = 40,
			inventory = {
				abc = { uid = "abc", name = "Wooden Sword", kind = "Weapon" },
			},
			futureFlag = true,
		}
		local profile, err = Schema.migrate(saved)
		expect(err).toBeNil()
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.gold).toEqual(40)
		expect(profile.shardLuck).toEqual(0)
		expect(profile.shardTokens).toEqual(25)
		expect(profile.inventory.abc.name).toEqual("Wooden Sword")
		expect((saved :: any).futureFlag).toEqual(true)
		expect((profile :: any).futureFlag).toEqual(true)
	end)

	it("fills a missing luck stat on a versioned profile", function()
		local profile = Schema.migrate({
			schemaVersion = 1,
			gold = 3,
			level = 4,
			xp = 10,
		})
		assert(profile ~= nil)
		expect(profile.gold).toEqual(3)
		expect(profile.level).toEqual(4)
		expect(profile.shardLuck).toEqual(0)
		expect(profile.xp).toEqual(10)
	end)

	it("refuses corrupt data and profiles from a newer server", function()
		local _, corrupt = Schema.migrate("nope")
		expect(corrupt).toEqual("corrupt")
		local _, newer = Schema.migrate({ schemaVersion = 99, gold = 1 })
		expect(newer).toEqual("newer")
	end)

	it("clamps bad numbers instead of deleting the profile", function()
		local profile = Schema.migrate({
			schemaVersion = 1,
			gold = -20,
			level = 0,
			shardTokens = "lots",
			shardLuck = -4,
		})
		assert(profile ~= nil)
		expect(profile.gold).toEqual(0)
		expect(profile.level).toEqual(1)
		expect(profile.shardTokens).toEqual(25)
		expect(profile.shardLuck).toEqual(0)
	end)

	it("copies snapshots so the client table is not the live profile", function()
		local profile = Schema.template()
		profile.inventory.abc = {
			uid = "abc",
			templateId = "wooden_sword",
			name = "Wooden Sword",
			kind = "Weapon",
			rarity = "Common",
			traits = {},
			poolId = "starter_shard",
			obtainedAt = 1,
		}
		local snapshot = Schema.snapshot(profile)
		snapshot.inventory.abc.name = "Changed"
		snapshot.gold = 99
		expect(profile.inventory.abc.name).toEqual("Wooden Sword")
		expect(profile.gold).toEqual(0)
		expect(snapshot.xpToNext).toEqual(100)
		expect(Schema.xpToNext(3)).toEqual(math.floor(100 * (3 ^ 1.6) + 0.5))
	end)

	it("tracks pity per pool and files pets separately from weapons", function()
		local profile = Schema.template()
		local pity = Schema.pityBucket(profile, "starter_shard")
		pity.rollsSinceLegendary = 2
		expect(Schema.pityBucket(profile, "starter_shard").rollsSinceLegendary).toEqual(2)
		expect(Schema.pityBucket(profile, "other").rollsSinceLegendary).toEqual(0)

		Schema.insertItem(profile, {
			uid = "pet-1",
			templateId = "training_pup",
			name = "Training Pup",
			kind = "Pet",
			rarity = "Uncommon",
			traits = {},
			poolId = "starter_shard",
			obtainedAt = 1,
		})
		Schema.insertItem(profile, {
			uid = "wep-1",
			templateId = "wooden_sword",
			name = "Wooden Sword",
			kind = "Weapon",
			rarity = "Common",
			traits = {},
			poolId = "starter_shard",
			obtainedAt = 1,
		})
		expect(Schema.countItems(profile)).toEqual(2)
		expect(profile.pets["pet-1"].name).toEqual("Training Pup")
		expect(profile.inventory["wep-1"].name).toEqual("Wooden Sword")
		local found = Schema.findItem(profile, "wep-1")
		assert(found ~= nil)
		expect(found.kind).toEqual("Weapon")
	end)

	it("clears an equipped id that is not in the bag and keeps one that is", function()
		local missing = Schema.migrate({
			schemaVersion = 1,
			equipped = { weapon = "missing-sword", pet = "missing-pet" },
			inventory = {
				sword = { uid = "sword", name = "Wooden Sword", kind = "Weapon" },
			},
		})
		assert(missing ~= nil)
		expect(missing.equipped.weapon).toBeNil()
		expect(missing.equipped.pet).toBeNil()
		expect(missing.inventory.sword.name).toEqual("Wooden Sword")

		local kept = Schema.migrate({
			schemaVersion = 1,
			equipped = { weapon = "sword", pet = "pup" },
			inventory = {
				sword = { uid = "sword", name = "Wooden Sword", kind = "Weapon" },
			},
			pets = {
				pup = { uid = "pup", name = "Training Pup", kind = "Pet" },
			},
		})
		assert(kept ~= nil)
		expect(kept.equipped.weapon).toEqual("sword")
		expect(kept.equipped.pet).toEqual("pup")
		expect(kept.equipped.armor).toEqual({})
	end)

	it("equips armor into its slot and drops a slot that is not in the bag", function()
		local profile = Schema.template()
		local hood = {
			uid = "hood",
			templateId = "grovewarden_hood",
			name = "Grovewarden Hood",
			kind = "Armor",
			rarity = "Epic",
			slot = "helm",
			setId = "grovewarden",
			traits = {},
			poolId = "verdant_armory",
			obtainedAt = 1,
		}
		Schema.insertItem(profile, hood)
		expect(Schema.equipItem(profile, hood)).toBeNil()
		expect(profile.equipped.armor.helm).toEqual("hood")
		expect(Schema.isEquipped(profile, "hood")).toBeTrue()

		local migrated = Schema.migrate({
			schemaVersion = 1,
			equipped = { armor = { helm = "missing", ring = "nope" } },
			inventory = { hood = hood },
		})
		assert(migrated ~= nil)
		expect(migrated.schemaVersion).toEqual(Schema.VERSION)
		expect(migrated.equipped.armor.helm).toBeNil()
		expect(migrated.equipped.armor.ring).toBeNil()

		local kept = Schema.migrate({
			schemaVersion = 1,
			equipped = { armor = { helm = "hood" } },
			inventory = { hood = hood },
		})
		assert(kept ~= nil)
		expect(kept.equipped.armor.helm).toEqual("hood")
		Schema.clearEquip(kept, "hood")
		expect(kept.equipped.armor.helm).toBeNil()
	end)

	it("fills materials, tonics, and vouchers when migrating an older save", function()
		local profile = Schema.migrate({
			schemaVersion = 2,
			gold = 8,
		})
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.gold).toEqual(8)
		expect(profile.materials.wood).toEqual(0)
		expect(profile.materials.heartwood).toEqual(0)
		expect(profile.consumables.healing_tonic).toEqual(0)
		expect(profile.vouchers.armory).toEqual(0)
		expect(profile.vouchers.pets).toEqual(0)
	end)

	it("stamps star fields onto gear from an older save", function()
		local profile = Schema.migrate({
			schemaVersion = 3,
			inventory = {
				blade = {
					uid = "blade",
					templateId = "nightbriar",
					name = "Nightbriar",
					kind = "Weapon",
					stats = { { id = "damage", value = 10 } },
				},
			},
		})
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.prismTokens).toEqual(0)
		expect(profile.luckBoost).toEqual(0)
		expect(profile.shardTokens).toEqual(Schema.STARTER_TOKENS)
		expect(profile.inventory.blade.stars).toEqual(0)
		expect(profile.inventory.blade.starProgress).toEqual(0)
		expect(profile.inventory.blade.stats[1].baseValue).toEqual(10)
		expect(profile.inventory.blade.stats[1].value).toEqual(10)
	end)

	it("keeps earned Shard Tokens separate from Prism Tokens", function()
		local profile = Schema.migrate({
			schemaVersion = 4,
			shardTokens = 12,
			shardLuck = 25,
		})
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.craftingLevel).toEqual(1)
		expect(profile.craftingXp).toEqual(0)
		expect(profile.forgeBoostUntil).toEqual(0)
		expect(profile.shardTokens).toEqual(12)
		expect(profile.prismTokens).toEqual(0)
		expect(profile.luckBoost).toEqual(0)
		expect(profile.shardLuck).toEqual(25)
		profile.prismTokens = 3
		expect(profile.shardTokens).toEqual(12)
	end)

	it("keeps a lock, a favorite, and socket count across a version 7 migrate", function()
		local profile = Schema.migrate({
			schemaVersion = 6,
			inventoryBonus = 10,
			inventory = {
				kept = {
					uid = "kept",
					templateId = "vinewood_sword",
					name = "Vinewood Sword",
					kind = "Weapon",
					rarity = "Common",
					locked = true,
					favorite = true,
					sockets = 2,
				},
				plain = {
					uid = "plain",
					templateId = "thorn_dagger",
					name = "Thorn Dagger",
					kind = "Weapon",
					rarity = "Common",
				},
			},
		})
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.inventoryBonus).toEqual(10)
		expect(Schema.inventoryCap(profile)).toEqual(Schema.INVENTORY_CAP + 10)
		expect(profile.inventory.kept.locked).toEqual(true)
		expect(profile.inventory.kept.favorite).toEqual(true)
		expect(profile.inventory.kept.sockets).toEqual(2)
		expect(profile.inventory.plain.locked).toEqual(false)
		expect(profile.inventory.plain.favorite).toEqual(false)
		expect(profile.inventory.plain.sockets).toEqual(0)
		expect(profile.equipped.accessories ~= nil).toBeTrue()
		local copy = Schema.snapshot(profile)
		expect(copy.inventory.kept.locked).toEqual(true)
		expect(copy.inventoryCap).toEqual(Schema.INVENTORY_CAP + 10)
	end)

	it("keeps waystones when a version 7 save is migrated", function()
		local fresh = Schema.migrate({
			schemaVersion = 7,
			gold = 4,
		})
		assert(fresh ~= nil)
		expect(fresh.schemaVersion).toEqual(Schema.VERSION)
		expect(fresh.gold).toEqual(4)
		expect(fresh.waystones).toEqual({})
		expect(fresh.lastTravel).toEqual(0)
		expect(fresh.travelPass).toEqual(false)

		local kept = Schema.migrate({
			schemaVersion = 7,
			waystones = { forge = true, nope = true, spawn = true },
			lastTravel = 12,
			travelPass = true,
			gold = 9,
		})
		assert(kept ~= nil)
		expect(kept.waystones.forge).toEqual(true)
		expect(kept.waystones.spawn).toEqual(true)
		expect(kept.waystones.nope).toBeNil()
		expect(kept.lastTravel).toEqual(12)
		expect(kept.travelPass).toEqual(true)
		expect(kept.gold).toEqual(9)
		local copy = Schema.snapshot(kept)
		expect(copy.waystones.forge).toEqual(true)
		expect(copy.waystones.nope).toBeNil()
		expect(copy.lastTravel).toEqual(12)
		expect(copy.travelPass).toEqual(true)
	end)

	it("keeps a graphics tier and drops an unknown one", function()
		local fresh = Schema.migrate({
			schemaVersion = 8,
			gold = 3,
		})
		assert(fresh ~= nil)
		expect(fresh.schemaVersion).toEqual(Schema.VERSION)
		expect(fresh.graphicsQuality).toEqual("")
		expect(fresh.gold).toEqual(3)

		local kept = Schema.migrate({
			schemaVersion = 8,
			graphicsQuality = "HIGH",
			gold = 6,
		})
		assert(kept ~= nil)
		expect(kept.graphicsQuality).toEqual("high")
		expect(kept.gold).toEqual(6)
		local copy = Schema.snapshot(kept)
		expect(copy.graphicsQuality).toEqual("high")

		local dropped = Schema.migrate({
			schemaVersion = 9,
			graphicsQuality = "ultra",
		})
		assert(dropped ~= nil)
		expect(dropped.graphicsQuality).toEqual("")
		expect(dropped.schemaVersion).toEqual(Schema.VERSION)
		expect(dropped.shardRolls).toEqual(0)
		expect(dropped.sinceEpic).toEqual(0)
		expect(dropped.sinceLegendary).toEqual(0)
		expect(dropped.quickRoll).toEqual(false)
		expect(dropped.vip).toEqual(false)
		expect(dropped.shake).toEqual(true)
		local pityCopy = Schema.snapshot(dropped)
		expect(pityCopy.shardRolls).toEqual(0)
		expect(pityCopy.shake).toEqual(true)

		local keptRolls = Schema.migrate({
			schemaVersion = 10,
			shardRolls = 40,
			sinceEpic = 12,
			sinceLegendary = 400,
			quickRoll = true,
			vip = true,
			shake = false,
			gold = 2,
		})
		assert(keptRolls ~= nil)
		expect(keptRolls.shardRolls).toEqual(40)
		expect(keptRolls.sinceEpic).toEqual(12)
		expect(keptRolls.sinceLegendary).toEqual(400)
		expect(keptRolls.quickRoll).toEqual(true)
		expect(keptRolls.vip).toEqual(true)
		expect(keptRolls.shake).toEqual(false)
		expect(keptRolls.gold).toEqual(2)
		expect(keptRolls.chests.Common).toEqual(0)
		expect(keptRolls.shardKeys).toEqual(0)
		expect(keptRolls.lastLoginDay).toEqual(-1)
		expect(keptRolls.chestDuplicates).toEqual("dust")
		local chestCopy = Schema.snapshot(keptRolls)
		expect(chestCopy.chests.Mythic).toEqual(0)
		expect(chestCopy.shardDust).toEqual(0)
		expect(keptRolls.musicVolume).toEqual(1)
		expect(keptRolls.sfxVolume).toEqual(1)
		expect(chestCopy.musicVolume).toEqual(1)
		expect(chestCopy.sfxVolume).toEqual(1)

		local quiet = Schema.migrate({
			schemaVersion = 12,
			musicVolume = 0,
			sfxVolume = 2,
			gold = 3,
		})
		assert(quiet ~= nil)
		expect(quiet.musicVolume).toEqual(0)
		expect(quiet.sfxVolume).toEqual(1)
		expect(quiet.gold).toEqual(3)
	end)

	it("fills per-class action bars when a version 23 save is migrated", function()
		local profile = Schema.migrate({
			schemaVersion = 23,
			classId = "tidecaller",
			gold = 5,
		})
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(26)
		expect(profile.gold).toEqual(5)
		local bar = profile.actionBars.tidecaller
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
		local fresh = Schema.template()
		expect(fresh.schemaVersion).toEqual(Schema.VERSION)
		expect(fresh.actionBars.tidecaller.slots[1].id).toEqual("tidal_bolt")
		expect(fresh.actionBars.warden.slots[1].id).toEqual("thorn_bash")
		expect(fresh.actionBars.warden.slots[6].id).toEqual("healing_tonic")

		local slots = {}
		for index = 1, 8 do
			slots[index] = { kind = "empty", id = "" }
		end
		slots[1] = { kind = "skill", id = "healing_pool" }
		slots[2] = { kind = "skill", id = "thorn_bash" }
		slots[8] = { kind = "skill", id = "tidal_bolt" }
		local kept = Schema.migrate({
			schemaVersion = 24,
			classId = "tidecaller",
			gold = 1,
			actionBars = {
				tidecaller = { locked = true, slots = slots },
			},
		})
		assert(kept ~= nil)
		expect(kept.schemaVersion).toEqual(26)
		expect(kept.gold).toEqual(1)
		expect(kept.actionBars.tidecaller.locked).toEqual(true)
		expect(kept.actionBars.tidecaller.slots[1].id).toEqual("healing_pool")
		expect(kept.actionBars.tidecaller.slots[2].kind).toEqual("empty")
		expect(kept.actionBars.tidecaller.slots[8].id).toEqual("tidal_bolt")
		expect(kept.actionBars.warden.slots[1].id).toEqual("thorn_bash")
		local copy = Schema.snapshot(kept)
		expect(copy.actionBars.tidecaller.slots[1].id).toEqual("healing_pool")
		copy.actionBars.tidecaller.slots[1].id = "changed"
		expect(kept.actionBars.tidecaller.slots[1].id).toEqual("healing_pool")
	end)
end)

describe("Codex seen flags", function()
	local IDS = {
		"attack",
		"dodge",
		"perfect",
		"skills",
		"telegraphs",
		"shards",
		"doors",
		"pets",
		"crafting",
		"rarity",
	}

	local function expectLocked(codex: any)
		expect(type(codex)).toEqual("table")
		expect(type(codex.unlocked)).toEqual("table")
		for _, id in ipairs(IDS) do
			expect(codex.unlocked[id]).toEqual(false)
		end
	end

	it("starts a new profile and a version 24 save locked", function()
		expect(Schema.VERSION).toEqual(26)
		local fresh = Schema.template()
		expect(fresh.schemaVersion).toEqual(26)
		expectLocked(fresh.codex)

		local old = Schema.migrate({
			schemaVersion = 24,
			gold = 7,
			codex = { unlocked = { attack = true } },
		})
		assert(old ~= nil)
		expect(old.schemaVersion).toEqual(26)
		expect(old.gold).toEqual(7)
		expectLocked(old.codex)
	end)

	it("keeps saved flags and fills a missing record", function()
		local unlocked = {}
		for _, id in ipairs(IDS) do
			unlocked[id] = false
		end
		unlocked.attack = true
		unlocked.rarity = true
		local kept = Schema.migrate({
			schemaVersion = 25,
			gold = 4,
			codex = { unlocked = unlocked, paid = true },
		})
		assert(kept ~= nil)
		expect(kept.schemaVersion).toEqual(26)
		expect(kept.gold).toEqual(4)
		expect(kept.codex.unlocked.attack).toEqual(true)
		expect(kept.codex.unlocked.rarity).toEqual(true)
		expect(kept.codex.unlocked.dodge).toEqual(false)
		expect(kept.codex.unlocked.crafting).toEqual(false)
		expect(kept.codex.paid).toBeNil()

		local partial = Schema.migrate({
			schemaVersion = 25,
			codex = { unlocked = { attack = true, dodge = 1, pets = "true" } },
		})
		assert(partial ~= nil)
		expect(partial.codex.unlocked.attack).toEqual(true)
		expect(partial.codex.unlocked.dodge).toEqual(false)
		expect(partial.codex.unlocked.pets).toEqual(false)
		expect(partial.codex.unlocked.skills).toEqual(false)

		local missing = Schema.migrate({ schemaVersion = 25, gold = 2 })
		assert(missing ~= nil)
		expect(missing.gold).toEqual(2)
		expectLocked(missing.codex)

		local copy = Schema.snapshot(kept)
		expect(copy.codex.unlocked.attack).toEqual(true)
		copy.codex.unlocked.attack = false
		expect(kept.codex.unlocked.attack).toEqual(true)
	end)

	it("keeps the saved flags when an unlock fails", function()
		local saved = {
			unlocked = {
				attack = true,
				dodge = false,
				perfect = false,
				skills = false,
				telegraphs = false,
				shards = false,
				doors = false,
				pets = false,
				crafting = false,
				rarity = false,
			},
		}
		table.freeze(saved.unlocked)
		table.freeze(saved)
		local failed = {
			ok = false,
			state = {
				unlocked = {
					attack = false,
					dodge = true,
				},
			},
			paid = true,
			productId = 0,
			robux = 0,
			cost = 0,
			skip = false,
		}
		table.freeze(failed.state.unlocked)
		table.freeze(failed.state)
		table.freeze(failed)
		local kept = Schema.applyCodex(saved, failed)
		expect(kept.unlocked.attack).toEqual(true)
		expect(kept.unlocked.dodge).toEqual(false)
		expect(kept.keys).toBeNil()
		expect(kept.gold).toBeNil()
		expect(saved.unlocked.attack).toEqual(true)
		expect(failed.ok).toEqual(false)
		expect(failed.state.unlocked.dodge).toEqual(true)
		expect(kept == saved).toBeFalse()

		local missing = Schema.applyCodex(saved, nil)
		expect(missing.unlocked.attack).toEqual(true)

		local skipped = Schema.applyCodex(saved, {
			ok = true,
			skip = true,
			state = { unlocked = { attack = false, dodge = true } },
		})
		expect(skipped.unlocked.attack).toEqual(true)
		expect(skipped.unlocked.dodge).toEqual(false)

		local named = Schema.applyCodex(saved, {
			ok = true,
			userId = 1,
			state = { unlocked = { dodge = true } },
		})
		expect(named.unlocked.attack).toEqual(true)
		expect(named.unlocked.dodge).toEqual(false)

		local opened = {
			ok = true,
			paid = true,
			state = {
				unlocked = {
					attack = true,
					dodge = true,
					perfect = false,
					skills = false,
					telegraphs = false,
					shards = false,
					doors = false,
					pets = false,
					crafting = false,
					rarity = true,
				},
			},
		}
		table.freeze(opened.state.unlocked)
		table.freeze(opened.state)
		table.freeze(opened)
		local stored = Schema.applyCodex(saved, opened)
		expect(stored.unlocked.attack).toEqual(true)
		expect(stored.unlocked.dodge).toEqual(true)
		expect(stored.unlocked.rarity).toEqual(true)
		expect(stored.unlocked.skills).toEqual(false)
		expect(saved.unlocked.dodge).toEqual(false)
		expect(opened.state.unlocked.dodge).toEqual(true)
	end)
end)

describe("Training Grove record", function()
	local function expectEmpty(grove: any)
		expect(grove.hits).toEqual(0)
		expect(grove.damage).toEqual(0)
		expect(grove.healing).toEqual(0)
		expect(grove.up).toEqual(true)
		expect(grove.dummy).toEqual(false)
		expect(grove.dodge).toEqual(false)
		expect(grove.room).toEqual(false)
		expect(grove.cosmetic).toEqual(false)
		expect(grove.colors.red).toEqual(false)
		expect(grove.colors.yellow).toEqual(false)
		expect(grove.colors.purple).toEqual(false)
		expect(grove.colors.blue).toEqual(false)
		expect(grove.keys).toBeNil()
		expect(grove.gold).toBeNil()
	end

	it("starts a new profile and a version 25 save empty", function()
		expect(Schema.VERSION).toEqual(26)
		local fresh = Schema.template()
		expect(fresh.schemaVersion).toEqual(26)
		expectEmpty(fresh.trainingGrove)
		expect(fresh.codex.unlocked.attack).toEqual(false)

		local old = Schema.migrate({
			schemaVersion = 25,
			gold = 6,
			codex = {
				unlocked = {
					attack = true,
					dodge = false,
					perfect = false,
					skills = false,
					telegraphs = false,
					shards = false,
					doors = false,
					pets = false,
					crafting = false,
					rarity = false,
				},
			},
			trainingGrove = { hits = 9, cosmetic = true, keys = 10, gold = 15 },
		})
		assert(old ~= nil)
		expect(old.schemaVersion).toEqual(26)
		expect(old.gold).toEqual(6)
		expect(old.codex.unlocked.attack).toEqual(true)
		expect(old.codex.unlocked.dodge).toEqual(false)
		expectEmpty(old.trainingGrove)
		expect(old.codex.hits).toBeNil()
	end)

	it("keeps a saved grove and does not fold it into codex", function()
		local kept = Schema.migrate({
			schemaVersion = 26,
			gold = 3,
			codex = { unlocked = { attack = true } },
			trainingGrove = {
				hits = 4,
				damage = 12,
				healing = 1.9,
				up = false,
				dummy = true,
				dodge = true,
				colors = { red = true, yellow = false, purple = 1, blue = "true" },
				room = true,
				cosmetic = true,
				keys = 10,
				gold = 15,
			},
		})
		assert(kept ~= nil)
		expect(kept.schemaVersion).toEqual(26)
		expect(kept.gold).toEqual(3)
		expect(kept.codex.unlocked.attack).toEqual(true)
		expect(kept.trainingGrove.hits).toEqual(4)
		expect(kept.trainingGrove.damage).toEqual(12)
		expect(kept.trainingGrove.healing).toEqual(1)
		expect(kept.trainingGrove.up).toEqual(false)
		expect(kept.trainingGrove.dummy).toEqual(true)
		expect(kept.trainingGrove.dodge).toEqual(true)
		expect(kept.trainingGrove.colors.red).toEqual(true)
		expect(kept.trainingGrove.colors.yellow).toEqual(false)
		expect(kept.trainingGrove.colors.purple).toEqual(false)
		expect(kept.trainingGrove.colors.blue).toEqual(false)
		expect(kept.trainingGrove.room).toEqual(true)
		expect(kept.trainingGrove.cosmetic).toEqual(true)
		expect(kept.trainingGrove.keys).toBeNil()
		expect(kept.trainingGrove.gold).toBeNil()

		local missing = Schema.migrate({ schemaVersion = 26, gold = 1 })
		assert(missing ~= nil)
		expectEmpty(missing.trainingGrove)

		local copy = Schema.snapshot(kept)
		expect(copy.trainingGrove.hits).toEqual(4)
		copy.trainingGrove.hits = 0
		expect(kept.trainingGrove.hits).toEqual(4)
	end)

	it("keeps the saved record when a grove call fails", function()
		local saved = {
			hits = 2,
			damage = 8,
			healing = 0,
			up = true,
			dummy = true,
			dodge = false,
			colors = { red = true, yellow = false, purple = false, blue = false },
			room = false,
			cosmetic = false,
		}
		table.freeze(saved.colors)
		table.freeze(saved)
		local failed = {
			ok = false,
			keys = 10,
			gold = 15,
			paid = true,
			productId = 0,
			robux = 0,
			cost = 0,
			skip = false,
			state = { hits = 0, cosmetic = true, keys = 10, gold = 15 },
		}
		table.freeze(failed.state)
		table.freeze(failed)
		local kept = Schema.applyGrove(saved, failed)
		expect(kept.hits).toEqual(2)
		expect(kept.cosmetic).toEqual(false)
		expect(kept.colors.red).toEqual(true)
		expect(kept.keys).toBeNil()
		expect(kept.gold).toBeNil()
		expect(saved.hits).toEqual(2)
		expect(failed.state.hits).toEqual(0)
		expect(kept == saved).toBeFalse()

		local skipped = Schema.applyGrove(saved, {
			ok = true,
			skip = true,
			state = { hits = 9, cosmetic = true },
		})
		expect(skipped.hits).toEqual(2)
		expect(skipped.cosmetic).toEqual(false)

		local named = Schema.applyGrove(saved, {
			ok = true,
			guildId = "grove",
			state = { hits = 9 },
		})
		expect(named.hits).toEqual(2)

		local opened = {
			ok = true,
			paid = true,
			keys = 10,
			gold = 15,
			state = {
				hits = 3,
				damage = 20,
				healing = 0,
				up = true,
				dummy = true,
				dodge = true,
				colors = { red = true, yellow = true, purple = true, blue = true },
				room = true,
				cosmetic = true,
				keys = 10,
				gold = 15,
			},
		}
		table.freeze(opened.state.colors)
		table.freeze(opened.state)
		table.freeze(opened)
		local stored = Schema.applyGrove(saved, opened)
		expect(stored.hits).toEqual(3)
		expect(stored.damage).toEqual(20)
		expect(stored.dodge).toEqual(true)
		expect(stored.colors.blue).toEqual(true)
		expect(stored.room).toEqual(true)
		expect(stored.cosmetic).toEqual(true)
		expect(stored.keys).toBeNil()
		expect(stored.gold).toBeNil()
		expect(saved.hits).toEqual(2)
		expect(opened.state.hits).toEqual(3)
	end)
end)
