--!strict

--[[
	Hit math for weapons and armor. No Instances, so tests can run it.

	The equipped weapon supplies Damage, Attack Speed, Crit Chance, and Crit
	Damage. Those numbers were already rolled and scaled when the item
	dropped, so this module does not scale them again. Armor supplies HP and
	Defense. Weapon type (`sword`, `bow`, `staff`, `dagger`, `hammer`) picks
	melee or a projectile. That tag is also the class-system hook; class
	weights are applied at roll time, not here.

	A hit:
	  1. Roll crit. On a crit, multiply damage by crit damage.
	  2. Subtract defense.
	  3. Round, and keep at least 1.

	Attack speed is swings per second. The cooldown is 1 / attack speed.
	Lifesteal, when a trait has it, heals for that fraction of the damage
	dealt. Gold Find adds that fraction of a reward's gold, including Gold
	Find on the equipped pet. An equipped pet hits on its own timer using
	Pet Damage, multiplied by Bonus Pet Damage from the pet, weapon, and
	armor. Pet Lifesteal heals those hits only. Chain Lightning is still
	only stored.
]]

local CombatMath = {}

export type StatLine = {
	id: string,
	value: number,
}

export type Gear = {
	kind: string?,
	weaponType: string?,
	stats: { StatLine }?,
	traits: { any }?,
	name: string?,
}

export type Style = {
	style: "melee" | "projectile",
	range: number,
	minDot: number,
	projectileSpeed: number,
}

export type Offense = {
	name: string,
	weaponType: string,
	style: "melee" | "projectile",
	damage: number,
	attackSpeed: number,
	critChance: number,
	critDamage: number,
	range: number,
	minDot: number,
	projectileSpeed: number,
	lifesteal: number,
	unarmed: boolean,
}

export type Vitality = {
	maxHealth: number,
	defense: number,
}

export type PetOffense = {
	damage: number,
	attackSpeed: number,
	critChance: number,
	critDamage: number,
	lifesteal: number,
	range: number,
}

export type Hit = {
	amount: number,
	crit: boolean,
	raw: number,
	healed: number,
}

CombatMath.BASE_HEALTH = 100

CombatMath.UNARMED = {
	name = "Fists",
	weaponType = "unarmed",
	style = "melee" :: "melee",
	damage = 5,
	attackSpeed = 1,
	critChance = 0.02,
	critDamage = 1.5,
	range = 6,
	minDot = 0.2,
	projectileSpeed = 0,
	lifesteal = 0,
	unarmed = true,
}

-- Studs. Melee is a swing in front of the player. Bows and staffs spawn a
-- server-side part that flies `range` studs at `projectileSpeed` studs/sec.
CombatMath.STYLES = {
	sword = { style = "melee", range = 8, minDot = 0.25, projectileSpeed = 0 },
	dagger = { style = "melee", range = 6, minDot = 0.05, projectileSpeed = 0 },
	hammer = { style = "melee", range = 11, minDot = 0.45, projectileSpeed = 0 },
	bow = { style = "projectile", range = 80, minDot = -1, projectileSpeed = 95 },
	staff = { style = "projectile", range = 62, minDot = -1, projectileSpeed = 64 },
} :: { [string]: Style }

CombatMath.PROJECTILE_RADIUS = 2.6

-- Pets with no Attack Speed (the sprout style) still swing. Crits use a
-- fixed multiplier because pets do not roll Crit Damage.
CombatMath.PET_RANGE = 16
CombatMath.PET_CRIT_DAMAGE = 1.5
CombatMath.PET_ATTACK_SPEED = 0.7

function CombatMath.readStat(stats: any, statId: string, fallback: number): number
	if type(stats) ~= "table" then
		return fallback
	end
	for _, stat in ipairs(stats) do
		if type(stat) == "table" and stat.id == statId then
			local value = stat.value
			if type(value) == "number" and value == value then
				return value
			end
		end
	end
	return fallback
end

function CombatMath.traitSum(items: { Gear }, traitId: string): number
	local total = 0
	for _, item in ipairs(items) do
		if type(item.traits) == "table" then
			for _, trait in ipairs(item.traits) do
				if
					type(trait) == "table"
					and trait.id == traitId
					and type(trait.value) == "number"
				then
					if trait.value == trait.value and trait.value > 0 then
						total += trait.value
					end
				end
			end
		end
	end
	return total
end

function CombatMath.cooldown(attackSpeed: number): number
	if type(attackSpeed) ~= "number" or attackSpeed ~= attackSpeed or attackSpeed <= 0 then
		return 1
	end
	return 1 / attackSpeed
end

function CombatMath.offense(weapon: Gear?, extra: { Gear }?): Offense
	local worn = {}
	if weapon ~= nil then
		table.insert(worn, weapon)
	end
	if extra ~= nil then
		for _, piece in ipairs(extra) do
			table.insert(worn, piece)
		end
	end

	if weapon == nil or weapon.kind ~= "Weapon" then
		local fists = table.clone(CombatMath.UNARMED)
		fists.lifesteal = CombatMath.traitSum(worn, "lifesteal")
		return fists
	end

	local weaponType = weapon.weaponType
	local style = if type(weaponType) == "string" then CombatMath.STYLES[weaponType] else nil
	if style == nil then
		style = CombatMath.STYLES.sword
		weaponType = "sword"
	end

	local attackSpeed = CombatMath.readStat(weapon.stats, "attack_speed", 1)
	if attackSpeed < 0.2 then
		attackSpeed = 0.2
	elseif attackSpeed > 4 then
		attackSpeed = 4
	end

	local critChance = CombatMath.readStat(weapon.stats, "crit_chance", 0)
	if critChance < 0 then
		critChance = 0
	elseif critChance > 1 then
		critChance = 1
	end

	local critDamage = CombatMath.readStat(weapon.stats, "crit_damage", 1.5)
	if critDamage < 1 then
		critDamage = 1
	end

	local damage = CombatMath.readStat(weapon.stats, "damage", CombatMath.UNARMED.damage)
	if damage < 1 then
		damage = 1
	end

	return {
		name = if type(weapon.name) == "string" then weapon.name else "Weapon",
		weaponType = weaponType :: string,
		style = style.style,
		damage = damage,
		attackSpeed = attackSpeed,
		critChance = critChance,
		critDamage = critDamage,
		range = style.range,
		minDot = style.minDot,
		projectileSpeed = style.projectileSpeed,
		lifesteal = CombatMath.traitSum(worn, "lifesteal"),
		unarmed = false,
	}
end

function CombatMath.vitality(armor: { Gear }): Vitality
	local health = CombatMath.BASE_HEALTH
	local defense = 0
	for _, piece in ipairs(armor) do
		health += math.max(0, CombatMath.readStat(piece.stats, "health", 0))
		defense += math.max(0, CombatMath.readStat(piece.stats, "defense", 0))
	end
	return {
		maxHealth = math.floor(health + 0.5),
		defense = math.floor(defense + 0.5),
	}
end

-- `roll` is the same 0..1 number Random:NextNumber returns. Below crit chance
-- is a crit. Defense is applied after the crit multiplier.
function CombatMath.resolveHit(
	damage: number,
	critChance: number,
	critDamage: number,
	defense: number,
	roll: number,
	lifesteal: number
): Hit
	local safeRoll = roll
	if type(safeRoll) ~= "number" or safeRoll ~= safeRoll then
		safeRoll = 1
	end
	local crit = safeRoll < critChance
	local raw = damage
	if crit then
		raw = damage * critDamage
	end
	if type(defense) ~= "number" or defense ~= defense or defense < 0 then
		defense = 0
	end
	local amount = math.floor(raw - defense + 0.5)
	if amount < 1 then
		amount = 1
	end
	local healed = 0
	if type(lifesteal) == "number" and lifesteal > 0 then
		healed = math.floor(amount * lifesteal + 0.5)
	end
	return {
		amount = amount,
		crit = crit,
		raw = raw,
		healed = healed,
	}
end

-- Phase 1 Grandmother Gnarl only takes full damage during her weak spot.
-- `armoredMultiplier` is the fraction she takes the rest of the time.
function CombatMath.bossTaken(
	amount: number,
	phase: number,
	weak: boolean,
	armoredMultiplier: number
): number
	if phase >= 2 or weak then
		return amount
	end
	local multiplier = armoredMultiplier
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 0 then
		multiplier = 1
	end
	if multiplier > 1 then
		multiplier = 1
	end
	local reduced = math.floor(amount * multiplier + 0.5)
	if reduced < 1 then
		reduced = 1
	end
	return reduced
end

function CombatMath.bonusGold(baseGold: number, goldFind: number): number
	if type(baseGold) ~= "number" or baseGold <= 0 then
		return 0
	end
	if type(goldFind) ~= "number" or goldFind ~= goldFind or goldFind <= 0 then
		return 0
	end
	return math.floor(baseGold * goldFind + 0.5)
end

function CombatMath.tonicHeal(
	current: number,
	maxHealth: number,
	fraction: number
): (number, number)
	local amount = math.floor(maxHealth * fraction + 0.5)
	if amount < 1 then
		amount = 1
	end
	local healed = math.min(amount, math.max(0, maxHealth - current))
	return healed, current + healed
end

function CombatMath.aimAt(
	originX: number,
	originY: number,
	originZ: number,
	targetX: number,
	targetY: number,
	targetZ: number
): (number, number, number)
	local dx = targetX - originX
	local dy = targetY - originY
	local dz = targetZ - originZ
	local magnitude = math.sqrt(dx * dx + dy * dy + dz * dz)
	if magnitude < 1e-4 then
		return 0, 0, -1
	end
	return dx / magnitude, dy / magnitude, dz / magnitude
end

function CombatMath.nearestInRange(
	originX: number,
	originZ: number,
	points: { any },
	range: number
): any?
	if type(points) ~= "table" or type(range) ~= "number" then
		return nil
	end
	local best = nil
	local bestDistance = math.huge
	for _, point in ipairs(points) do
		if type(point) == "table" and type(point.x) == "number" and type(point.z) == "number" then
			local distance = CombatMath.planarDistance(originX, originZ, point.x, point.z)
			if distance <= range and distance < bestDistance then
				best = point
				bestDistance = distance
			end
		end
	end
	return best
end

function CombatMath.planarDistance(ax: number, az: number, bx: number, bz: number): number
	local dx = bx - ax
	local dz = bz - az
	return math.sqrt(dx * dx + dz * dz)
end

-- True when `target` is within `range` studs on the ground plane and in front
-- of the look direction. `minDot` is 1 dead ahead and -1 behind.
function CombatMath.hitsMelee(
	originX: number,
	originZ: number,
	lookX: number,
	lookZ: number,
	targetX: number,
	targetZ: number,
	range: number,
	minDot: number
): boolean
	local dx = targetX - originX
	local dz = targetZ - originZ
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > range or distance < 1e-4 then
		return false
	end
	local lookLength = math.sqrt(lookX * lookX + lookZ * lookZ)
	if lookLength < 1e-4 then
		return false
	end
	local dot = (dx / distance) * (lookX / lookLength) + (dz / distance) * (lookZ / lookLength)
	return dot >= minDot
end

function CombatMath.within(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	radius: number
): boolean
	local dx = bx - ax
	local dy = by - ay
	local dz = bz - az
	return dx * dx + dy * dy + dz * dz <= radius * radius
end

function CombatMath.withinPlanar(
	ax: number,
	az: number,
	bx: number,
	bz: number,
	radius: number
): boolean
	return CombatMath.planarDistance(ax, az, bx, bz) <= radius
end

-- Moves a shot forward. `remaining` is studs left before it expires.
function CombatMath.stepProjectile(
	x: number,
	y: number,
	z: number,
	dirX: number,
	dirY: number,
	dirZ: number,
	speed: number,
	dt: number,
	remaining: number
): (number, number, number, number)
	local step = speed * dt
	if step < 0 then
		step = 0
	end
	if step > remaining then
		step = remaining
	end
	return x + dirX * step, y + dirY * step, z + dirZ * step, remaining - step
end

-- Pet Damage times (1 + Bonus Pet Damage). Attack speed falls back when the
-- style omitted it. Lifesteal is only the pet's own trait.
function CombatMath.petOffense(pet: Gear?, bonusFraction: number): PetOffense?
	if type(pet) ~= "table" then
		return nil
	end
	local damage = CombatMath.readStat(pet.stats, "pet_damage", 0)
	if damage <= 0 then
		return nil
	end
	local bonus = bonusFraction
	if type(bonus) ~= "number" or bonus ~= bonus or bonus < 0 then
		bonus = 0
	end
	damage *= 1 + bonus

	local attackSpeed = CombatMath.readStat(pet.stats, "attack_speed", CombatMath.PET_ATTACK_SPEED)
	if attackSpeed < 0.2 then
		attackSpeed = 0.2
	elseif attackSpeed > 4 then
		attackSpeed = 4
	end

	local critChance = CombatMath.readStat(pet.stats, "crit_chance", 0)
	if critChance < 0 then
		critChance = 0
	elseif critChance > 1 then
		critChance = 1
	end

	return {
		damage = damage,
		attackSpeed = attackSpeed,
		critChance = critChance,
		critDamage = CombatMath.PET_CRIT_DAMAGE,
		lifesteal = CombatMath.traitSum({ pet }, "lifesteal"),
		range = CombatMath.PET_RANGE,
	}
end

function CombatMath.petFromProfile(profile: any): PetOffense?
	if
		type(profile) ~= "table"
		or type(profile.equipped) ~= "table"
		or type(profile.pets) ~= "table"
	then
		return nil
	end
	local petId = profile.equipped.pet
	if type(petId) ~= "string" then
		return nil
	end
	local pet = profile.pets[petId]
	if type(pet) ~= "table" or pet.kind ~= "Pet" then
		return nil
	end
	local sources: { Gear } = { pet }
	if type(profile.inventory) == "table" then
		local weaponId = profile.equipped.weapon
		if type(weaponId) == "string" then
			local weapon = profile.inventory[weaponId]
			if type(weapon) == "table" then
				table.insert(sources, weapon)
			end
		end
		if type(profile.equipped.armor) == "table" then
			for _, uid in pairs(profile.equipped.armor) do
				if type(uid) == "string" then
					local piece = profile.inventory[uid]
					if type(piece) == "table" then
						table.insert(sources, piece)
					end
				end
			end
		end
	end
	return CombatMath.petOffense(pet, CombatMath.traitSum(sources, "bonus_pet_damage"))
end

-- Reads the equipped weapon and armor off a profile table. The pet is not
-- part of the weapon swing. Its Gold Find is included in the third return.
function CombatMath.loadout(profile: any): (Offense, Vitality, number)
	local weapon: Gear? = nil
	local armor: { Gear } = {}
	if
		type(profile) == "table"
		and type(profile.inventory) == "table"
		and type(profile.equipped) == "table"
	then
		local weaponId = profile.equipped.weapon
		if type(weaponId) == "string" then
			local item = profile.inventory[weaponId]
			if type(item) == "table" and item.kind == "Weapon" then
				weapon = item
			end
		end
		if type(profile.equipped.armor) == "table" then
			for _, uid in pairs(profile.equipped.armor) do
				if type(uid) == "string" then
					local piece = profile.inventory[uid]
					if type(piece) == "table" and piece.kind == "Armor" then
						table.insert(armor, piece)
					end
				end
			end
		end
	end
	local worn: { Gear } = table.clone(armor)
	if weapon ~= nil then
		table.insert(worn, weapon)
	end
	if
		type(profile) == "table"
		and type(profile.pets) == "table"
		and type(profile.equipped) == "table"
	then
		local petId = profile.equipped.pet
		if type(petId) == "string" then
			local pet = profile.pets[petId]
			if type(pet) == "table" and pet.kind == "Pet" then
				table.insert(worn, pet)
			end
		end
	end
	return CombatMath.offense(weapon, armor),
		CombatMath.vitality(armor),
		CombatMath.traitSum(worn, "gold_find")
end

table.freeze(CombatMath.UNARMED)
table.freeze(CombatMath.STYLES)
for _, style in pairs(CombatMath.STYLES) do
	table.freeze(style)
end

return CombatMath
