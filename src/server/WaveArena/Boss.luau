--!strict

--[[
	Boss slam. The red circle is placed when the windup starts. Damage is
	zero until the windup is released, and then only if the player is still
	inside that circle. Walking out is the dodge.
]]

local Boss = {}

export type Warning = {
	x: number,
	z: number,
	radius: number,
	damage: number,
	seconds: number,
	color: string,
}

function Boss.arm(attacker: any, player: any): Warning
	local seconds = attacker.windup or attacker.windupTotal or 0
	if typeof(seconds) ~= "number" or seconds ~= seconds then
		seconds = 0
	end
	return {
		x = player.x,
		z = player.z,
		radius = attacker.attackRadius or 0,
		damage = attacker.damage or 0,
		seconds = seconds,
		color = "red",
	}
end

function Boss.damage(warning: any, player: any, released: boolean): number
	if released ~= true or typeof(warning) ~= "table" or typeof(player) ~= "table" then
		return 0
	end
	local px = player.x
	local pz = player.z
	if typeof(px) ~= "number" or typeof(pz) ~= "number" or px ~= px or pz ~= pz then
		return 0
	end
	local dx = px - warning.x
	local dz = pz - warning.z
	local radius = warning.radius or 0
	if dx * dx + dz * dz <= radius * radius then
		return warning.damage or 0
	end
	return 0
end

return Boss
