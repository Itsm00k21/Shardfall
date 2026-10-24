--!strict

--[[
	Server math for the three V1 enemy types and the wave-5 boss.
	Positions and damage come from Config/Enemies.luau. This module does
	not create parts, read a profile, or spend Robux.

	EnemyTypeService is the gate. It calls these functions only while
	LaunchGate.enemyTypes is on. A client that requires this file can
	move a local table. It cannot grant loot or change a save.
]]

local Enemies = require("./Config/Enemies")

local EnemyRoster = {}

export type Actor = {
	kind: string,
	x: number,
	z: number,
	hp: number,
	cooldown: number,
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
	return Enemies.row(kind)
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

-- One server tick. Returns the damage this enemy deals to the target.
-- The number is the config damage, never a value passed in by the caller.
function EnemyRoster.step(actor: Actor, targetX: number, targetZ: number, dt: number): number
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
	local now = distance(actor.x, actor.z, targetX, targetZ)
	local inBand = not kiting and now <= row.range and (row.retreat <= 0 or now >= row.retreat)
	if inBand and actor.cooldown <= 0 and actor.hp > 0 then
		actor.cooldown = 1 / row.attackSpeed
		return row.damage
	end
	return 0
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
