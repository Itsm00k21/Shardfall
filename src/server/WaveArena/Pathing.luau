--!strict

--[[
	Server pathing for one wave.

	Each body gets its own spot on a ring inside the arena (the boss keeps
	the open centre spawn). Bodies walk straight in to that radius, then
	along the ring to their spot. The disk is convex, so the inward leg
	cannot enter the wall. Spots are spaced so the largest wave can all
	arrive without stacking on one point and stalling.

	simulate copies its input. It does not move instances.
]]

local WaveArenaConfig = require("../../shared/Config/WaveArenaConfig")
local Graybox = require("./Graybox")
local Spawns = require("./Spawns")

local Pathing = {}

export type Body = {
	id: string,
	kind: string,
	x: number,
	z: number,
	radius: number,
	speed: number,
	arrive: number,
	slotX: number,
	slotZ: number,
}

export type Sim = {
	bodies: { Body },
	stuck: { number },
	inGeometry: number,
	steps: number,
	seconds: number,
}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

local function length(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

local function wrapPi(delta: number): number
	local turn = math.pi * 2
	while delta > math.pi do
		delta -= turn
	end
	while delta < -math.pi do
		delta += turn
	end
	return delta
end

local function pushOffBoss(
	x: number,
	z: number,
	radius: number,
	boss: Body,
	gap: number
): (number, number)
	local dx = x - boss.slotX
	local dz = z - boss.slotZ
	local dist = length(dx, dz)
	local need = radius + boss.radius + gap
	if dist >= need then
		return x, z
	end
	if dist < 1e-4 then
		dx = 1
		dz = 0
		dist = 1
	end
	local scale = need / dist
	return boss.slotX + dx * scale, boss.slotZ + dz * scale
end

function Pathing.assignSlots(bodies: { Body }, config: any?)
	local cfg = cfgOf(config)
	local inner = Spawns.innerRadius(cfg)
	local boss: Body? = nil
	local movers: { Body } = {}
	for _, body in ipairs(bodies) do
		if body.kind == "boss" then
			body.slotX = body.x
			body.slotZ = body.z
			boss = body
		else
			table.insert(movers, body)
		end
	end
	local count = #movers
	if count == 0 then
		return
	end
	local gap = cfg.spawn.gap
	local minChord = 0
	for _, body in ipairs(movers) do
		local need = body.radius * 2 + gap
		if need > minChord then
			minChord = need
		end
	end
	local ring = movers[1].arrive + movers[1].radius
	if count >= 2 then
		local packed = minChord / (2 * math.sin(math.pi / count)) + 0.25
		if packed > ring then
			ring = packed
		end
	end
	if boss ~= nil then
		local anchor = boss :: Body
		local around = anchor.radius + movers[1].radius + gap + 0.25
		local bossR = length(anchor.slotX, anchor.slotZ)
		if bossR + around > ring then
			ring = bossR + around
		end
	end
	table.sort(movers, function(a: Body, b: Body): boolean
		local aa = math.atan2(a.z, a.x)
		local bb = math.atan2(b.z, b.x)
		if aa == bb then
			return a.x * a.x + a.z * a.z > b.x * b.x + b.z * b.z
		end
		return aa < bb
	end)
	local base = math.atan2(movers[1].z, movers[1].x)
	local step = (math.pi * 2) / count
	for index, body in ipairs(movers) do
		local angle = base + (index - 1) * step
		local x = math.cos(angle) * ring
		local z = math.sin(angle) * ring
		if boss ~= nil then
			x, z = pushOffBoss(x, z, body.radius, boss :: Body, gap)
		end
		local cap = inner - cfg.spawn.margin - body.radius
		local r = length(x, z)
		if cap < 0 then
			x = 0
			z = 0
		elseif r > cap and r > 0 then
			x *= cap / r
			z *= cap / r
		end
		body.slotX = x
		body.slotZ = z
	end
end

-- One tick. Inward (or outward) to the slot radius, then along the ring.
function Pathing.nudge(body: Body, dt: number, limit: number)
	local slotR = length(body.slotX, body.slotZ)
	local cap = math.max(0, limit)
	if slotR > cap then
		slotR = cap
	end
	local r = length(body.x, body.z)
	if math.abs(r - slotR) > 0.05 then
		local dir = if r > slotR then -1 else 1
		local step = math.min(math.abs(r - slotR), body.speed * dt)
		local nextR = math.clamp(r + dir * step, 0, cap)
		if r < 1e-4 then
			local angle = math.atan2(body.slotZ, body.slotX)
			body.x = math.cos(angle) * nextR
			body.z = math.sin(angle) * nextR
		else
			local scale = nextR / r
			body.x *= scale
			body.z *= scale
		end
		return
	end
	if slotR < 1e-4 then
		body.x = 0
		body.z = 0
		return
	end
	local angle = math.atan2(body.z, body.x)
	local delta = wrapPi(math.atan2(body.slotZ, body.slotX) - angle)
	local maxTurn = (body.speed * dt) / slotR
	if math.abs(delta) <= maxTurn then
		angle += delta
	elseif delta > 0 then
		angle += maxTurn
	else
		angle -= maxTurn
	end
	body.x = math.cos(angle) * slotR
	body.z = math.sin(angle) * slotR
end

local function copyOf(placed: { any }): { Body }
	local bodies: { Body } = {}
	for _, unit in ipairs(placed) do
		table.insert(bodies, {
			id = unit.id,
			kind = unit.kind,
			x = unit.x,
			z = unit.z,
			radius = unit.radius,
			speed = unit.speed,
			arrive = unit.arrive,
			slotX = 0,
			slotZ = 0,
		})
	end
	return bodies
end

function Pathing.simulate(placed: { any }, config: any?, seconds: number?): Sim
	local cfg = cfgOf(config)
	local duration = if seconds == nil then cfg.path.stuckSeconds else seconds
	local dt = cfg.path.tick
	local inner = Spawns.innerRadius(cfg)
	local solids = Graybox.solids(cfg)
	local bodies = copyOf(placed)
	Pathing.assignSlots(bodies, cfg)
	local steps = math.max(1, math.ceil(duration / dt - 1e-9))
	local inGeometry = 0
	for _ = 1, steps do
		for _, body in ipairs(bodies) do
			Pathing.nudge(body, dt, inner - body.radius)
			if Spawns.blocked(body.x, body.z, body.radius, inner, solids) then
				inGeometry += 1
			end
		end
	end
	local stuck = {}
	for index, body in ipairs(bodies) do
		local dx = body.x - body.slotX
		local dz = body.z - body.slotZ
		if dx * dx + dz * dz > 0.5 * 0.5 then
			table.insert(stuck, index)
		end
	end
	return {
		bodies = bodies,
		stuck = stuck,
		inGeometry = inGeometry,
		steps = steps,
		seconds = steps * dt,
	}
end

return Pathing
