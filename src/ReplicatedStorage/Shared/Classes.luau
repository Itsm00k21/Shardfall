--!strict

--[[
	The five beta classes.

	Each row is the resource, core passive, four skills, ultimate, and the
	level-5 talent pair. Later talents stay out. Empty sound ids mean the
	client stays quiet until a licensed clip is filled in.
]]

local Classes = {}

Classes.MAX_LEVEL = 30
Classes.TALENT_LEVEL = 5
Classes.ULT_COST = 100

export type Skill = {
	id: string,
	name: string,
	kind: string,
	cooldown: number,
	damage: number,
	heal: number,
	shield: number,
	radius: number,
	resource: number,
	note: string,
}

export type Talent = {
	id: string,
	name: string,
	note: string,
}

export type ClassDef = {
	id: string,
	name: string,
	role: string,
	resource: string,
	palette: { number },
	sounds: { swing: string, skill: string, ult: string },
	passive: string,
	passiveNote: string,
	skills: { Skill },
	ultimate: Skill,
	talents: { Talent },
}

local function skill(
	id: string,
	name: string,
	kind: string,
	cooldown: number,
	damage: number,
	heal: number,
	shield: number,
	radius: number,
	resource: number,
	note: string
): Skill
	return {
		id = id,
		name = name,
		kind = kind,
		cooldown = cooldown,
		damage = damage,
		heal = heal,
		shield = shield,
		radius = radius,
		resource = resource,
		note = note,
	}
end

local LIST: { ClassDef } = {
	{
		id = "warden",
		name = "Warden",
		role = "Tank",
		resource = "Bark",
		palette = { 92, 140, 78 },
		sounds = { swing = "", skill = "", ult = "" },
		passive = "deep_roots",
		passiveNote = "Standing still takes 15% less damage.",
		skills = {
			skill(
				"thorn_bash",
				"Thorn Bash",
				"strike",
				4,
				1.15,
				0,
				0,
				6,
				8,
				"Shield strike. Short stun."
			),
			skill(
				"rootgrasp",
				"Rootgrasp",
				"circle",
				8,
				0.7,
				0,
				0,
				12,
				0,
				"Roots a circle for 2s."
			),
			skill(
				"barkskin",
				"Barkskin",
				"shield",
				12,
				0,
				0,
				0.2,
				0,
				-30,
				"Spend Bark for 20% max HP."
			),
			skill("vine_pull", "Vine Pull", "strike", 7, 0.9, 0, 0, 16, 0, "Yank the target in."),
		},
		ultimate = skill(
			"heart_grove",
			"Heart of the Grove",
			"ult",
			0,
			1.4,
			0.08,
			0,
			14,
			0,
			"Taunt, slam, and heal nearby."
		),
		talents = {
			{ id = "thornmail", name = "Thornmail", note = "Reflect 10% of a hit." },
			{ id = "overgrowth", name = "Overgrowth", note = "Rootgrasp reaches farther." },
		},
	},
	{
		id = "tidecaller",
		name = "Tidecaller",
		role = "Healer",
		resource = "Tide",
		palette = { 72, 186, 176 },
		sounds = { swing = "", skill = "", ult = "" },
		passive = "ebb_flow",
		passiveNote = "Extra healing becomes a small shield.",
		skills = {
			skill(
				"tidal_bolt",
				"Tidal Bolt",
				"bolt",
				3,
				1,
				0.12,
				0,
				18,
				8,
				"Hurts a foe or tops you up."
			),
			skill(
				"healing_pool",
				"Healing Pool",
				"heal",
				10,
				0,
				0.22,
				0,
				10,
				10,
				"A tidepool of healing."
			),
			skill(
				"bubble_ward",
				"Bubble Ward",
				"shield",
				9,
				0,
				0,
				0.15,
				0,
				12,
				"Shield and one cleanse."
			),
			skill(
				"undertow",
				"Undertow",
				"circle",
				8,
				0.75,
				0,
				0,
				12,
				0,
				"Wave that shoves foes back."
			),
		},
		ultimate = skill(
			"monsoon",
			"Monsoon",
			"ult",
			0,
			0.4,
			0.28,
			0,
			16,
			0,
			"Rain heals the party."
		),
		talents = {
			{ id = "riptide", name = "Riptide", note = "Tidal Bolt hits a second foe." },
			{ id = "still_waters", name = "Still Waters", note = "Healing Pool is larger." },
		},
	},
	{
		id = "forgeborn",
		name = "Forgeborn",
		role = "Bruiser",
		resource = "Heat",
		palette = { 220, 110, 48 },
		sounds = { swing = "", skill = "", ult = "" },
		passive = "tempered",
		passiveNote = "Up to +8% damage as HP falls.",
		skills = {
			skill("hammerfall", "Hammerfall", "circle", 5, 1.45, 0, 0, 8, 12, "Overhead slam."),
			skill(
				"molten_charge",
				"Molten Charge",
				"dash",
				7,
				1.1,
				0,
				0,
				14,
				8,
				"Dash that leaves fire."
			),
			skill("anvil_guard", "Anvil Guard", "guard", 8, 0, 0, 0, 0, 0, "Block the next hit."),
			skill(
				"eruption",
				"Eruption",
				"vent",
				11,
				0.4,
				0,
				0,
				12,
				0,
				"Vent all Heat into a ring."
			),
		},
		ultimate = skill(
			"forgeheart",
			"Forgeheart",
			"ult",
			0,
			1.6,
			0,
			0,
			10,
			0,
			"Overheat with no health drain."
		),
		talents = {
			{ id = "slag", name = "Slag", note = "Fire hits slow." },
			{ id = "bellows", name = "Bellows", note = "Heat builds faster." },
		},
	},
	{
		id = "frostblade",
		name = "Frostblade",
		role = "Melee",
		resource = "Chill",
		palette = { 150, 210, 240 },
		sounds = { swing = "", skill = "", ult = "" },
		passive = "shatter",
		passiveNote = "Frozen targets take a heavier crit.",
		skills = {
			skill("ice_edge", "Ice Edge", "strike", 2.5, 0.85, 0, 0, 7, 1, "Fast cut. Adds Chill."),
			skill(
				"glacial_dash",
				"Glacial Dash",
				"dash",
				6,
				0.9,
				0,
				0,
				16,
				1,
				"Dash through and chill."
			),
			skill(
				"frost_mirror",
				"Frost Mirror",
				"circle",
				10,
				1.1,
				0,
				0,
				8,
				0,
				"A decoy that bursts."
			),
			skill("cold_snap", "Cold Snap", "cone", 8, 0.6, 0, 0, 10, 2, "Two Chill in a cone."),
		},
		ultimate = skill(
			"absolute_zero",
			"Absolute Zero",
			"ult",
			0,
			1.5,
			0,
			0.1,
			14,
			0,
			"Freeze the room and crit them."
		),
		talents = {
			{ id = "biting_wind", name = "Biting Wind", note = "A freeze quickens you." },
			{ id = "permafrost", name = "Permafrost", note = "Chill sticks harder." },
		},
	},
	{
		id = "voidcaster",
		name = "Voidcaster",
		role = "Ranged",
		resource = "Void",
		palette = { 120, 70, 180 },
		sounds = { swing = "", skill = "", ult = "" },
		passive = "entropy",
		passiveNote = "At empty Void you are Unstable.",
		skills = {
			skill("void_bolt", "Void Bolt", "bolt", 2.5, 1.15, 0, 0, 28, -12, "A piercing bolt."),
			skill("rift", "Rift", "circle", 9, 0.85, 0, 0, 10, -18, "A pull that ticks."),
			skill(
				"blink",
				"Blink",
				"dash",
				7,
				0.4,
				0,
				0,
				12,
				-8,
				"Step through and curse the spot."
			),
			skill(
				"hex",
				"Hex of Unmaking",
				"strike",
				10,
				0.5,
				0,
				0,
				24,
				-15,
				"The target takes more damage."
			),
		},
		ultimate = skill(
			"event_horizon",
			"Event Horizon",
			"ult",
			0,
			1.8,
			0,
			0,
			16,
			0,
			"A black hole, then a boom."
		),
		talents = {
			{ id = "echo", name = "Echo", note = "Void Bolt repeats for 30%." },
			{ id = "hollow", name = "Hollow", note = "Rift is wider." },
		},
	},
}

local byId: { [string]: ClassDef } = {}
for _, row in ipairs(LIST) do
	byId[row.id] = row
end

function Classes.all(): { ClassDef }
	return LIST
end

function Classes.get(classId: any): ClassDef?
	if type(classId) ~= "string" then
		return nil
	end
	return byId[classId]
end

function Classes.xpForLevel(level: number): number
	local whole = math.floor(level)
	if whole < 1 then
		whole = 1
	end
	return 40 * whole
end

function Classes.progress(total: number): (number, number, number)
	local xp = math.max(0, math.floor(total))
	local level = 1
	local rest = xp
	while level < Classes.MAX_LEVEL do
		local need = Classes.xpForLevel(level)
		if rest < need then
			break
		end
		rest -= need
		level += 1
	end
	local nextNeed = 0
	if level < Classes.MAX_LEVEL then
		nextNeed = Classes.xpForLevel(level)
	else
		rest = 0
	end
	return level, rest, nextNeed
end

function Classes.talentChoices(classId: string): { Talent }
	local row = Classes.get(classId)
	if row == nil then
		return {}
	end
	return row.talents
end

function Classes.validTalent(classId: string, talentId: string): boolean
	for _, talent in ipairs(Classes.talentChoices(classId)) do
		if talent.id == talentId then
			return true
		end
	end
	return false
end

function Classes.tune(row: Skill, talentId: string?): Skill
	local copy = table.clone(row)
	if talentId == "overgrowth" and row.id == "rootgrasp" then
		copy.radius = math.floor(row.radius * 1.4)
	elseif talentId == "still_waters" and row.id == "healing_pool" then
		copy.heal = row.heal * 1.5
		copy.radius = math.floor(row.radius * 1.5)
	elseif talentId == "hollow" and row.id == "rift" then
		copy.radius = row.radius + 4
	elseif talentId == "echo" and row.id == "void_bolt" then
		copy.damage = row.damage * 1.3
	elseif talentId == "bellows" then
		if row.resource > 0 then
			copy.resource = math.floor(row.resource * 1.25)
		end
	end
	return copy
end

function Classes.takenMultiplier(
	classId: string?,
	standingStill: boolean,
	guarding: boolean
): number
	local multiplier = 1
	if guarding then
		multiplier *= 0.35
	end
	if classId == "warden" and standingStill then
		multiplier *= 0.85
	end
	return multiplier
end

function Classes.dealtMultiplier(
	classId: string?,
	hp: number,
	maxHp: number,
	unstable: boolean
): number
	local multiplier = 1
	if classId == "forgeborn" and maxHp > 0 then
		local missing = 1 - math.clamp(hp / maxHp, 0, 1)
		local bonus = math.floor(missing * 10) * 0.01
		if bonus > 0.08 then
			bonus = 0.08
		end
		multiplier += bonus
	end
	if classId == "voidcaster" and unstable then
		multiplier *= 1.2
	end
	return multiplier
end

function Classes.unstableTaken(classId: string?, unstable: boolean): number
	if classId == "voidcaster" and unstable then
		return 1.2
	end
	return 1
end

table.freeze(LIST)
for _, row in ipairs(LIST) do
	table.freeze(row.skills)
	table.freeze(row.talents)
	table.freeze(row.palette)
	table.freeze(row.sounds)
end

return Classes
