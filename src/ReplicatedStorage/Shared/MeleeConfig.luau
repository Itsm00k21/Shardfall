--!strict

--[[
	Melee reach and swing cone, one place (Kevin's Oct 19 playtest: every
	hit needed the player about half a body length away).

	Reach is measured on the ground plane from the player's root to the
	EDGE of the target (target radius is subtracted), so big enemies and
	bosses are hit from the same comfortable distance as small ones.

	Reference points (Roblox combat norms): the classic Roblox sword blade
	reaches about 4-5 studs past the hand, so roughly 6-7 studs from the
	root; battlegrounds-style M1 hitboxes are boxes about 5-6 studs deep in
	front of the root. A 7-8 stud reach to the target edge with a 100
	degree front cone is a forgiving version of that.

	Every number here is a tunable. Nothing costs Robux.
]]

local MeleeConfig = {}

-- Studs from the root to the target's edge.
MeleeConfig.REACH = {
	unarmed = 7,
	dagger = 7,
	sword = 8,
	greatsword = 9,
	hammer = 9,
}
MeleeConfig.DEFAULT_REACH = 7

-- Full front cone in degrees (100 = 50 degrees either side of the aim).
MeleeConfig.CONE_DEG = {
	unarmed = 100,
	dagger = 100,
	sword = 100,
	greatsword = 100,
	hammer = 100,
}
MeleeConfig.DEFAULT_CONE_DEG = 100

-- Anything this close to the target's edge is hit whatever the facing,
-- so a player hugging an enemy never whiffs.
MeleeConfig.CLOSE_STUDS = 3

-- Largest target radius the edge test will subtract (keeps a giant
-- boss collider from turning melee into a ranged attack).
MeleeConfig.MAX_TARGET_RADIUS = 6

local function finite(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function MeleeConfig.reach(weaponType: any): number
	local value = if type(weaponType) == "string" then MeleeConfig.REACH[weaponType] else nil
	return value or MeleeConfig.DEFAULT_REACH
end

function MeleeConfig.coneDeg(weaponType: any): number
	local value = if type(weaponType) == "string" then MeleeConfig.CONE_DEG[weaponType] else nil
	return value or MeleeConfig.DEFAULT_CONE_DEG
end

-- Cone to the dot-product threshold CombatMath.hitsMelee uses.
function MeleeConfig.minDot(weaponType: any): number
	local half = math.rad(MeleeConfig.coneDeg(weaponType) / 2)
	return math.floor(math.cos(half) * 1000 + 0.5) / 1000
end

-- Ground-plane radius of a target from its part size (X and Z), clamped.
function MeleeConfig.targetRadius(sizeX: any, sizeZ: any): number
	local x = finite(sizeX) or 0
	local z = finite(sizeZ) or 0
	local radius = math.max(0, math.max(x, z) / 2)
	return math.min(radius, MeleeConfig.MAX_TARGET_RADIUS)
end

return table.freeze(MeleeConfig)
