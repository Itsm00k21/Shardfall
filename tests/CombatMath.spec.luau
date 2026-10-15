--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CombatMath = require("../src/ReplicatedStorage/Shared/CombatMath")

local function sword(damage: number, speed: number, crit: number, critDamage: number)
	return {
		kind = "Weapon",
		name = "Vinewood Sword",
		weaponType = "sword",
		stats = {
			{ id = "damage", value = damage },
			{ id = "attack_speed", value = speed },
			{ id = "crit_chance", value = crit },
			{ id = "crit_damage", value = critDamage },
		},
		traits = {},
	}
end

describe("CombatMath", function()
	it("swings fists when nothing is equipped", function()
		local offense = CombatMath.offense(nil, nil)
		expect(offense.unarmed).toEqual(true)
		expect(offense.style).toEqual("melee")
		expect(offense.damage).toEqual(5)
		expect(offense.weaponType).toEqual("unarmed")
	end)

	it("reads rolled weapon stats and picks melee or a projectile from the weapon type", function()
		local blade = CombatMath.offense(sword(12, 1, 0.05, 1.5), nil)
		expect(blade.damage).toEqual(12)
		expect(blade.style).toEqual("melee")
		expect(blade.range).toEqual(8)
		expect(blade.weaponType).toEqual("sword")

		local bow = CombatMath.offense({
			kind = "Weapon",
			name = "Briar Bow",
			weaponType = "bow",
			stats = {
				{ id = "damage", value = 9 },
				{ id = "attack_speed", value = 1 },
				{ id = "crit_chance", value = 0.1 },
				{ id = "crit_damage", value = 1.6 },
			},
		}, nil)
		expect(bow.style).toEqual("projectile")
		expect(bow.projectileSpeed).toEqual(95)
		expect(bow.range).toEqual(80)

		local staff = CombatMath.offense({
			kind = "Weapon",
			weaponType = "staff",
			stats = { { id = "damage", value = 15 } },
		}, nil)
		expect(staff.style).toEqual("projectile")
		expect(staff.projectileSpeed).toEqual(64)
	end)

	it("keeps melee closing in and ranged at a clamped distance", function()
		local near, far = CombatMath.farmBand("melee", 8)
		expect(near).toEqual(0)
		expect(far).toBeCloseTo(5.6, 1e-9)

		local back, hold = CombatMath.farmBand("projectile", 80)
		expect(hold).toEqual(32)
		expect(back).toEqual(24)

		local closeBack, closeHold = CombatMath.farmBand("projectile", 20)
		expect(closeHold).toEqual(16)
		expect(closeBack).toEqual(8)
	end)

	it("turns attack speed into a cooldown", function()
		expect(CombatMath.cooldown(1)).toEqual(1)
		expect(CombatMath.cooldown(2)).toEqual(0.5)
		expect(CombatMath.cooldown(0)).toEqual(1)
	end)

	it("subtracts defense after the hit and keeps at least 1", function()
		local hit = CombatMath.resolveHit(12, 0.5, 2, 5, 0.9, 0)
		expect(hit.crit).toEqual(false)
		expect(hit.amount).toEqual(7)

		local chip = CombatMath.resolveHit(4, 0, 2, 20, 0.5, 0)
		expect(chip.amount).toEqual(1)
	end)

	it("multiplies crits before defense and can heal from lifesteal", function()
		local hit = CombatMath.resolveHit(10, 0.5, 2, 4, 0.1, 0.1)
		expect(hit.crit).toEqual(true)
		expect(hit.raw).toEqual(20)
		expect(hit.amount).toEqual(16)
		expect(hit.healed).toEqual(2)
	end)

	it("adds armor HP onto the base and sums defense", function()
		local vitality = CombatMath.vitality({
			{ stats = { { id = "health", value = 20 }, { id = "defense", value = 4.2 } } },
			{ stats = { { id = "health", value = 10.4 }, { id = "defense", value = 3 } } },
		})
		expect(vitality.maxHealth).toEqual(130)
		expect(vitality.defense).toEqual(7)
	end)

	it("accepts a target in front and rejects one behind or out of range", function()
		expect(CombatMath.hitsMelee(0, 0, 0, 1, 0, 5, 8, 0.25)).toEqual(true)
		expect(CombatMath.hitsMelee(0, 0, 0, 1, 0, -5, 8, 0.25)).toEqual(false)
		expect(CombatMath.hitsMelee(0, 0, 0, 1, 0, 20, 8, 0.25)).toEqual(false)
	end)

	it("stops a projectile when it has flown its range", function()
		local x, y, z, left = CombatMath.stepProjectile(0, 2, 0, 1, 0, 0, 10, 1, 6)
		expect(x).toEqual(6)
		expect(y).toEqual(2)
		expect(z).toEqual(0)
		expect(left).toEqual(0)
	end)

	it("lets the boss take a chip outside her weak spot and full damage inside it", function()
		expect(CombatMath.bossTaken(10, 1, false, 0.45)).toEqual(5)
		expect(CombatMath.bossTaken(10, 1, true, 0.45)).toEqual(10)
		expect(CombatMath.bossTaken(10, 2, false, 0.45)).toEqual(10)
	end)

	it(
		"scales pet damage by bonus pet damage and falls back when attack speed is missing",
		function()
			local offense = CombatMath.petOffense({
				kind = "Pet",
				stats = { { id = "pet_damage", value = 10 } },
				traits = { { id = "lifesteal", value = 0.04 } },
			}, 0.2)
			assert(offense ~= nil)
			expect(offense.damage).toBeCloseTo(12, 1e-9)
			expect(offense.attackSpeed).toEqual(0.7)
			expect(offense.critChance).toEqual(0)
			expect(offense.critDamage).toEqual(1.5)
			expect(offense.lifesteal).toEqual(0.04)
			expect(offense.range).toEqual(16)
			expect(CombatMath.petOffense(nil, 0)).toBeNil()
			expect(CombatMath.petFromProfile(nil)).toBeNil()
		end
	)

	it("adds weapon bonus pet damage to the pet and keeps pet lifesteal off the weapon", function()
		local profile = {
			equipped = { weapon = "w", pet = "p", armor = {} },
			inventory = {
				w = {
					kind = "Weapon",
					weaponType = "sword",
					stats = {
						{ id = "damage", value = 10 },
						{ id = "attack_speed", value = 1 },
						{ id = "crit_chance", value = 0 },
						{ id = "crit_damage", value = 1.5 },
					},
					traits = {
						{ id = "bonus_pet_damage", value = 0.2 },
						{ id = "lifesteal", value = 0.05 },
					},
				},
			},
			pets = {
				p = {
					kind = "Pet",
					stats = {
						{ id = "pet_damage", value = 10 },
						{ id = "attack_speed", value = 1 },
					},
					traits = {
						{ id = "lifesteal", value = 0.1 },
						{ id = "gold_find", value = 0.05 },
					},
				},
			},
		}
		local petHit = CombatMath.petFromProfile(profile)
		assert(petHit ~= nil)
		expect(petHit.damage).toBeCloseTo(12, 1e-9)
		expect(petHit.lifesteal).toEqual(0.1)
		local weapon, _, gold = CombatMath.loadout(profile)
		expect(weapon.lifesteal).toEqual(0.05)
		expect(gold).toBeCloseTo(0.05, 1e-9)
	end)

	it("picks the nearest enemy inside weapon range and aims melee at them", function()
		local picked = CombatMath.nearestInRange(0, 0, {
			{ x = 0, z = 30 },
			{ x = 3, z = 4 },
		}, 8)
		assert(picked ~= nil)
		expect(picked.z).toEqual(4)
		expect(CombatMath.nearestInRange(0, 0, { { x = 0, z = 30 } }, 8)).toBeNil()

		local ax, _ay, az = CombatMath.aimAt(0, 0, 0, 3, 1, 4)
		expect(CombatMath.hitsMelee(0, 0, ax, az, 3, 4, 8, 0.45)).toEqual(true)
	end)

	it("adds gold find as a fraction of the clear reward", function()
		expect(CombatMath.bonusGold(45, 0.1)).toEqual(5)
		expect(CombatMath.bonusGold(45, 0)).toEqual(0)
	end)

	it("heals a fraction of max HP without going over it", function()
		local healed, hp = CombatMath.tonicHeal(80, 100, 0.4)
		expect(healed).toEqual(20)
		expect(hp).toEqual(100)
		local none, full = CombatMath.tonicHeal(100, 100, 0.4)
		expect(none).toEqual(0)
		expect(full).toEqual(100)
	end)
end)
