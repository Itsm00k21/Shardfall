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
