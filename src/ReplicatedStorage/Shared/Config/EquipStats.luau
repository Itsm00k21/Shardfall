--!strict

--[[
	Phase 2 stat definitions (ROADMAP 2.2 and 2.3). Data only.

	Totals are computed from the equipped pieces. They are not saved.
	base is the naked number (same unarmed damage and HP the combat
	math uses). stack "add" is base plus every contributing piece.
	stack "replace" uses the first contributing piece in `from`, and
	the base when no piece has the stat.

	ELEMENT_MULT is one number for every element, so Ember, Frost, and
	Void stay on the same scale. It multiplies a piece's rolled value
	only for the stats that element lists in Config/Elements. Values
	outside 0..1 are clamped by the total, so a typo cannot triple power.

	ELEMENT_FLAT is added once per piece of an element that scales that
	stat. Luck is not a rolled gear stat yet; the flat is how Void's
	luck shows up. It is not a Robux bonus.
]]

local EquipStats = {}

EquipStats.ELEMENT_MULT = 0.1

EquipStats.ELEMENT_FLAT = table.freeze({
	luck = 1,
})

EquipStats.ORDER = table.freeze({
	"damage",
	"attack_speed",
	"crit_chance",
	"crit_damage",
	"health",
	"defense",
	"luck",
	"pet_damage",
	"pet_health",
})

EquipStats.DEFS = table.freeze({
	damage = table.freeze({
		id = "damage",
		name = "Damage",
		unit = "flat",
		decimals = 0,
		stack = "replace",
		from = table.freeze({ "weapon" }),
		base = 5,
	}),
	attack_speed = table.freeze({
		id = "attack_speed",
		name = "Attack Speed",
		unit = "multiplier",
		decimals = 2,
		stack = "replace",
		from = table.freeze({ "weapon" }),
		base = 1,
	}),
	crit_chance = table.freeze({
		id = "crit_chance",
		name = "Crit Chance",
		unit = "percent",
		decimals = 1,
		stack = "replace",
		from = table.freeze({ "weapon" }),
		base = 0.02,
		cap = 1,
	}),
	crit_damage = table.freeze({
		id = "crit_damage",
		name = "Crit Damage",
		unit = "multiplier",
		decimals = 2,
		stack = "replace",
		from = table.freeze({ "weapon" }),
		base = 1.5,
	}),
	health = table.freeze({
		id = "health",
		name = "HP",
		unit = "flat",
		decimals = 0,
		stack = "add",
		base = 100,
	}),
	defense = table.freeze({
		id = "defense",
		name = "Defense",
		unit = "flat",
		decimals = 0,
		stack = "add",
		base = 0,
	}),
	luck = table.freeze({
		id = "luck",
		name = "Luck",
		unit = "flat",
		decimals = 0,
		stack = "add",
		base = 0,
	}),
	pet_damage = table.freeze({
		id = "pet_damage",
		name = "Pet Damage",
		unit = "flat",
		decimals = 0,
		stack = "add",
		base = 0,
	}),
	pet_health = table.freeze({
		id = "pet_health",
		name = "Pet HP",
		unit = "flat",
		decimals = 0,
		stack = "add",
		base = 0,
	}),
})

return table.freeze(EquipStats)
