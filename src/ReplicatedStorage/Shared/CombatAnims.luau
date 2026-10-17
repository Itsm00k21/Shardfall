--!strict

--[[
	Animation ids Kevin can swap.

	An empty string plays a procedural pose so a hit still reads before a
	real clip is uploaded. Put a published id in the matching field
	(rbxassetid://123) and the client loads that instead.
]]

local CombatAnims = {}

CombatAnims.IDS = {
	attack1 = "",
	attack2 = "",
	attack3 = "",
	dodge = "",
	skill = "",
	enemyIdle = "",
	enemyAttack = "",
	enemyDeath = "",
}

function CombatAnims.id(name: string): string
	local value = CombatAnims.IDS[name]
	if type(value) ~= "string" then
		return ""
	end
	return value
end

return CombatAnims
