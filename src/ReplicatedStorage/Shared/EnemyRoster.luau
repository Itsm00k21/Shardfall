--!strict

--[[
	Server math for the three V1 enemy types. Positions, arena bounds,
	and damage come from Config/Enemies.luau. A ranged kite is clamped
	to that arena. A ranged shot travels at projectileSpeed and deals
	damage only after a line-of-sight check. This module does not create
	parts, raycast the world, read a profile, or spend Robux.

	EnemyTypeService is the gate. It calls these functions only while
	LaunchGate.enemyTypes is on, and it owns the world raycast. A client
	that requires this file can move a local table. It cannot grant loot
	or change a save.
]]

local Enemies = require("./Config/Enemies")

local EnemyRoster = {}

export type Shot = {
	x: number,
	z: number,
	dirX: number,
	dirZ: number,
	speed: number,
	remaining: number,
	damage: number,
	originX: number,
	originZ: number,
	aimX: number,
	aimZ: number,
}

-- True when the segment from the muzzle to the aim point is blocked.
export type Cast = (number, number, number, number) -> boolean

export type Actor = {
	kind: string,
	x: number,
	z: number,
	hp: number,
	cooldown: number,
	shot: Shot?,
}

export type Box = {
	shape: string,
	id: string,
	name: string,
	size: { number },
	color: { number },
	x: number,
	y: number,
	z: number,
}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function rowOf(kind: string): Enemies.Row?
	local row = Enemies.TYPES[kind]
	if row == nil or row.id ~= kind then
		return nil
	end
	return row
end

function EnemyRoster.order(): { string }
	return Enemies.ORDER
end

function EnemyRoster.spawn(kind: string, x: number, z: number): Actor?
	local row = rowOf(kind)
	if row == nil or not finite(x) or not finite(z) then
		return nil
	end
	return {
		kind = kind,
		x = x,
		z = z,
		hp = row.maxHealth,
		cooldown = 0,
		shot = nil,
	}
end

function EnemyRoster.graybox(kind: string, index: number): Box?
	local row = rowOf(kind)
	if row == nil or not finite(index) or index < 1 then
		return nil
	end
	local slot = math.floor(index)
	return {
		shape = "block",
		id = row.id,
		name = row.name,
		size = { row.size[1], row.size[2], row.size[3] },
		color = { row.color[1], row.color[2], row.color[3] },
		x = (slot - 1) * Enemies.PREVIEW_GAP,
		y = Enemies.PREVIEW_LIFT,
		z = 0,
	}
end

local function distance(x: number, z: number, targetX: number, targetZ: number): (number, number, number)
	local dx = targetX - x
	local dz = targetZ - z
	return math.sqrt(dx * dx + dz * dz), dx, dz
end

local function slide(actor: Actor, dx: number, dz: number, dist: number, step: number)
	if dist <= 0 or step == 0 then
		return
	end
	local scale = step / dist
	actor.x += dx * scale
	actor.z += dz * scale
end

-- A kite that would leave the floor stops on the edge. Chase is untouched.
local function clampArena(actor: Actor)
	local box = Enemies.ARENA
	actor.x = math.clamp(actor.x, box.minX, box.maxX)
	actor.z = math.clamp(actor.z, box.minZ, box.maxZ)
end

-- Move one in-flight shot. Damage lands only when it reaches the aim
-- point and the cast says the segment is clear. Nil cast is a clear shot.
local function advanceShot(actor: Actor, stepDt: number, blocked: Cast?): number
	local shot = actor.shot
	if shot == nil then
		return 0
	end
	if not finite(shot.speed) or shot.speed <= 0 or not finite(shot.remaining) then
		actor.shot = nil
		return 0
	end
	local step = shot.speed * stepDt
	if step > shot.remaining then
		step = shot.remaining
	end
	if step < 0 then
		step = 0
	end
	shot.x += shot.dirX * step
	shot.z += shot.dirZ * step
	shot.remaining -= step
	if shot.remaining > 1e-4 then
		return 0
	end
	local damage = shot.damage
	local originX, originZ = shot.originX, shot.originZ
	local aimX, aimZ = shot.aimX, shot.aimZ
	actor.shot = nil
	if not finite(actor.hp) or actor.hp <= 0 or not finite(damage) or damage <= 0 then
		return 0
	end
	if blocked ~= nil and blocked(originX, originZ, aimX, aimZ) == true then
		return 0
	end
	return damage
end

local function launch(actor: Actor, row: Enemies.Row, aimX: number, aimZ: number, aimDist: number, aimDx: number, aimDz: number)
	local dirX = aimDx / aimDist
	local dirZ = aimDz / aimDist
	actor.shot = {
		x = actor.x,
		z = actor.z,
		dirX = dirX,
		dirZ = dirZ,
		speed = row.projectileSpeed,
		remaining = aimDist,
		damage = row.damage,
		originX = actor.x,
		originZ = actor.z,
		aimX = aimX,
		aimZ = aimZ,
	}
end

-- One server tick. Returns the damage this enemy deals to the target.
-- The number is the config damage, never a value passed in by the caller.
-- `blocked` is the line-of-sight check for a ranged shot. Melee ignores it.
function EnemyRoster.step(actor: Actor, targetX: number, targetZ: number, dt: number, blocked: Cast?): number
	if type(actor) ~= "table" or type(actor.kind) ~= "string" then
		return 0
	end
	local row = rowOf(actor.kind)
	if row == nil or not finite(actor.x) or not finite(actor.z) then
		return 0
	end
	if not finite(targetX) or not finite(targetZ) or not finite(dt) or dt <= 0 then
		return 0
	end
	local stepDt = math.min(dt, Enemies.STEP_MAX)
	local dist, dx, dz = distance(actor.x, actor.z, targetX, targetZ)
	-- A tick that opens inside the retreat band is a kite. No shot that tick.
	local kiting = row.retreat > 0 and dist < row.retreat
	if kiting then
		if dist == 0 then
			actor.x -= row.moveSpeed * stepDt
		else
			slide(actor, dx, dz, dist, -(row.moveSpeed * stepDt))
		end
		clampArena(actor)
	elseif dist > row.stop then
		local travel = math.min(row.moveSpeed * stepDt, dist - row.stop)
		slide(actor, dx, dz, dist, travel)
	end
	if not finite(actor.cooldown) then
		actor.cooldown = 0
	else
		actor.cooldown -= stepDt
		if actor.cooldown < 0 then
			actor.cooldown = 0
		end
	end
	local dealt = advanceShot(actor, stepDt, blocked)
	local now, aimDx, aimDz = distance(actor.x, actor.z, targetX, targetZ)
	local inBand = not kiting and now <= row.range and (row.retreat <= 0 or now >= row.retreat)
	if actor.shot == nil and inBand and actor.cooldown <= 0 and actor.hp > 0 then
		actor.cooldown = 1 / row.attackSpeed
		if row.style == "projectile" then
			if now > 1e-4 and row.projectileSpeed > 0 then
				launch(actor, row, targetX, targetZ, now, aimDx, aimDz)
				dealt += advanceShot(actor, stepDt, blocked)
			elseif blocked == nil or blocked(actor.x, actor.z, targetX, targetZ) ~= true then
				dealt += row.damage
			end
		else
			dealt += row.damage
		end
	end
	return dealt
end

-- Damage the enemy takes. The fraction is damageTaken from config.
function EnemyRoster.hurt(actor: Actor, raw: number): number
	if type(actor) ~= "table" or type(actor.kind) ~= "string" then
		return 0
	end
	local row = rowOf(actor.kind)
	if row == nil or not finite(actor.hp) or not finite(raw) or raw <= 0 then
		return 0
	end
	local taken = raw * row.damageTaken
	actor.hp -= taken
	if actor.hp < 0 then
		actor.hp = 0
	end
	return taken
end

return EnemyRoster
