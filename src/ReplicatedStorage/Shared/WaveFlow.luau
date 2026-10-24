--!strict

--[[
	Server math for roadmap 3.5, the wave-5 boss (3.6), and the
	stuck-enemy watchdog (3.8). Wave sizes, the boss, the four adds,
	and the stall clock come from Config/Enemies.luau. This module
	does not create parts, fire a remote, read a profile, or spend Robux.

	WaveFlowService is the gate. It calls these functions only while
	LaunchGate.enemyTypes is on. A client that requires this file can
	step a local table. It cannot grant loot or push the counter.
]]

local Enemies = require("./Config/Enemies")
local EnemyRoster = require("./EnemyRoster")

local WaveFlow = {}

export type Counter = {
	wave: number,
	left: number,
}

export type Box = {
	shape: string,
	id: number,
	kind: string,
	name: string,
	size: { number },
	color: { number },
	x: number,
	y: number,
	z: number,
	wave: number,
}

export type Member = {
	id: number,
	slot: number,
	actor: EnemyRoster.Actor,
}

export type Track = {
	best: number,
	idle: number,
	nudges: number,
	resets: number,
	hurt: boolean,
}

export type Obstacle = {
	x: number,
	z: number,
	radius: number,
}

export type Pulse = {
	id: number,
	kind: string,
	engaged: boolean,
	nudged: boolean,
	reset: boolean,
	idle: number,
	nudges: number,
	resets: number,
	x: number,
	z: number,
}

export type Run = {
	wave: number,
	clear: boolean,
	nextId: number,
	members: { Member },
	tracks: { [number]: Track },
}

local function living(run: Run): number
	local left = 0
	for _, member in ipairs(run.members) do
		if member.actor.hp > 0 then
			left += 1
		end
	end
	return left
end

-- Boss first, then adds in WAVE_ORDER. Nil when the mix is not four adds.
local function bossPlan(): { string }?
	local boss = Enemies.BOSS
	local mix = Enemies.BOSS_ADD_MIX
	local adds = Enemies.BOSS_ADDS
	if boss == nil or type(boss.id) ~= "string" or type(mix) ~= "table" or type(adds) ~= "number" then
		return nil
	end
	local kinds = { boss.id }
	local sum = 0
	for _, role in ipairs(Enemies.WAVE_ORDER) do
		local amount = mix[role]
		if amount == nil then
			amount = 0
		end
		if type(amount) ~= "number" or amount < 0 or amount ~= math.floor(amount) then
			return nil
		end
		for _ = 1, amount do
			table.insert(kinds, role)
		end
		sum += amount
	end
	for key in pairs(mix) do
		if table.find(Enemies.WAVE_ORDER, key) == nil then
			return nil
		end
	end
	if sum ~= adds or #kinds ~= adds + 1 then
		return nil
	end
	return kinds
end

-- Kinds for one wave. Trash waves follow WAVE_ORDER. Wave 5 is the boss
-- plan. Nil when the wave is outside that list.
function WaveFlow.plan(wave: number): { string }?
	if type(wave) ~= "number" or wave ~= wave or wave ~= math.floor(wave) then
		return nil
	end
	if wave == Enemies.BOSS_WAVE then
		return bossPlan()
	end
	local mix = Enemies.WAVE_MIXES[wave]
	local count = Enemies.WAVE_COUNTS[wave]
	if type(mix) ~= "table" or type(count) ~= "number" then
		return nil
	end
	local kinds = {}
	for _, role in ipairs(Enemies.WAVE_ORDER) do
		local amount = mix[role]
		if type(amount) ~= "number" or amount < 1 or amount ~= math.floor(amount) then
			return nil
		end
		for _ = 1, amount do
			table.insert(kinds, role)
		end
	end
	if #kinds ~= count then
		return nil
	end
	return kinds
end

local function spawnWave(run: Run, wave: number): boolean
	local kinds = WaveFlow.plan(wave)
	if kinds == nil then
		return false
	end
	local members = {}
	local nextId = run.nextId
	for slot, kind in ipairs(kinds) do
		local actor = EnemyRoster.spawn(kind, (slot - 1) * Enemies.WAVE_GAP, 0)
		if actor == nil then
			return false
		end
		table.insert(members, {
			id = nextId,
			slot = slot,
			actor = actor,
		})
		nextId += 1
	end
	run.nextId = nextId
	run.wave = wave
	run.clear = false
	run.members = members
	run.tracks = {}
	return true
end

function WaveFlow.start(): Run?
	local run: Run = {
		wave = 0,
		clear = false,
		nextId = 1,
		members = {},
		tracks = {},
	}
	if not spawnWave(run, 1) then
		return nil
	end
	return run
end

function WaveFlow.counter(run: Run): Counter
	return {
		wave = run.wave,
		left = living(run),
	}
end

function WaveFlow.boxes(run: Run): { Box }
	local boxes = {}
	for _, member in ipairs(run.members) do
		local actor = member.actor
		if actor.hp > 0 then
			local row = Enemies.row(actor.kind)
			if row ~= nil then
				table.insert(boxes, {
					shape = "block",
					id = member.id,
					kind = actor.kind,
					name = row.name,
					size = { row.size[1], row.size[2], row.size[3] },
					color = { row.color[1], row.color[2], row.color[3] },
					x = actor.x,
					y = Enemies.WAVE_LIFT,
					z = actor.z,
					wave = run.wave,
				})
			end
		end
	end
	return boxes
end

local markHurt: (Run, number) -> ()

-- Damage from the roster. A killing blow on the last enemy opens the
-- next wave. The run is clear when the boss wave is empty. A miss, a
-- dead id, or a hit that leaves HP up does not change the count.
function WaveFlow.hurt(run: Run, id: number, raw: number): number
	if run.clear == true or type(id) ~= "number" then
		return 0
	end
	local member: Member? = nil
	for _, candidate in ipairs(run.members) do
		if candidate.id == id and candidate.actor.hp > 0 then
			member = candidate
			break
		end
	end
	if member == nil then
		return 0
	end
	local taken = EnemyRoster.hurt(member.actor, raw)
	if taken > 0 then
		markHurt(run, id)
	end
	if taken <= 0 or member.actor.hp > 0 then
		return taken
	end
	if living(run) > 0 then
		return taken
	end
	local nextWave = run.wave + 1
	if not spawnWave(run, nextWave) then
		run.clear = true
	end
	return taken
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function distance(x: number, z: number, targetX: number, targetZ: number): (number, number, number)
	local dx = targetX - x
	local dz = targetZ - z
	return math.sqrt(dx * dx + dz * dz), dx, dz
end

local function bodyRadius(kind: string): number
	local row = Enemies.row(kind)
	if row == nil then
		return 1
	end
	local wide = row.size[1]
	if row.size[3] > wide then
		wide = row.size[3]
	end
	return wide * 0.5
end

local function segmentHits(x0: number, z0: number, x1: number, z1: number, cx: number, cz: number, reach: number): boolean
	local dx = x1 - x0
	local dz = z1 - z0
	local len2 = dx * dx + dz * dz
	local t = 0
	if len2 > 1e-8 then
		t = ((cx - x0) * dx + (cz - z0) * dz) / len2
		if t < 0 then
			t = 0
		elseif t > 1 then
			t = 1
		end
	end
	local px = x0 + dx * t - cx
	local pz = z0 + dz * t - cz
	return px * px + pz * pz < reach * reach
end

local function diskOk(disk: any): boolean
	return type(disk) == "table" and finite(disk.x) and finite(disk.z) and finite(disk.radius) and disk.radius > 0
end

-- True when the segment crosses an obstacle. `radius` is the body; a shot
-- passes 0 so only the obstacle itself blocks the ray.
local function blockedPath(
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	radius: number,
	obstacles: { Obstacle }?
): boolean
	if obstacles == nil then
		return false
	end
	for _, disk in ipairs(obstacles) do
		if diskOk(disk) and segmentHits(x0, z0, x1, z1, disk.x, disk.z, disk.radius + radius) then
			return true
		end
	end
	return false
end

local function copyShot(shot: EnemyRoster.Shot?): EnemyRoster.Shot?
	if shot == nil then
		return nil
	end
	return {
		x = shot.x,
		z = shot.z,
		dirX = shot.dirX,
		dirZ = shot.dirZ,
		speed = shot.speed,
		remaining = shot.remaining,
		damage = shot.damage,
		originX = shot.originX,
		originZ = shot.originZ,
		aimX = shot.aimX,
		aimZ = shot.aimZ,
	}
end

-- Move and attack. A step that would enter an obstacle is undone, including
-- the cooldown and the shot, so a blocked enemy does not deal damage.
local function applyMove(actor: EnemyRoster.Actor, targetX: number, targetZ: number, dt: number, obstacles: { Obstacle }?): number
	local radius = bodyRadius(actor.kind)
	local beforeX = actor.x
	local beforeZ = actor.z
	local beforeCd = actor.cooldown
	local beforeShot = copyShot(actor.shot)
	local function sight(x0: number, z0: number, x1: number, z1: number): boolean
		return blockedPath(x0, z0, x1, z1, 0, obstacles)
	end
	local dealt = EnemyRoster.step(actor, targetX, targetZ, dt, sight)
	if blockedPath(beforeX, beforeZ, actor.x, actor.z, radius, obstacles) then
		actor.x = beforeX
		actor.z = beforeZ
		actor.cooldown = beforeCd
		actor.shot = beforeShot
		return 0
	end
	return dealt
end

local function insideArena(x: number, z: number, radius: number): boolean
	local box = Enemies.ARENA
	return x >= box.minX + radius and x <= box.maxX - radius and z >= box.minZ + radius and z <= box.maxZ - radius
end

local function crowded(
	x: number,
	z: number,
	radius: number,
	obstacles: { Obstacle }?,
	members: { Member },
	selfId: number
): boolean
	if not insideArena(x, z, radius) then
		return true
	end
	local pad = Enemies.SPAWN_CLEAR
	if not finite(pad) or pad < 0 then
		pad = 0
	end
	if obstacles ~= nil then
		for _, disk in ipairs(obstacles) do
			if diskOk(disk) then
				local dx = x - disk.x
				local dz = z - disk.z
				local reach = radius + disk.radius + pad
				if dx * dx + dz * dz < reach * reach then
					return true
				end
			end
		end
	end
	for _, member in ipairs(members) do
		local other = member.actor
		if member.id ~= selfId and other.hp > 0 then
			local dx = x - other.x
			local dz = z - other.z
			local reach = radius + bodyRadius(other.kind) + pad
			if dx * dx + dz * dz < reach * reach then
				return true
			end
		end
	end
	return false
end

-- `probe` is one full step at this enemy's speed. A shorter look misses a
-- wall that the next tick would still run into, and the nudge would
-- shuffle along it forever.
local function canAdvance(
	x: number,
	z: number,
	targetX: number,
	targetZ: number,
	radius: number,
	obstacles: { Obstacle }?,
	probe: number
): boolean
	local dist, dx, dz = distance(x, z, targetX, targetZ)
	if dist <= 1e-4 then
		return true
	end
	if not finite(probe) or probe <= 0 then
		probe = Enemies.STUCK_PROGRESS
	end
	if probe > dist then
		probe = dist
	end
	local nx = x + dx / dist * probe
	local nz = z + dz / dist * probe
	return not blockedPath(x, z, nx, nz, radius, obstacles)
end

local function stepReach(kind: string): number
	local row = Enemies.row(kind)
	local speed = if row ~= nil then row.moveSpeed else 1
	local cap = Enemies.STEP_MAX
	if not finite(speed) or speed <= 0 then
		speed = 1
	end
	if not finite(cap) or cap <= 0 then
		cap = 0.5
	end
	return speed * cap
end

-- Slide off the blocked line. True when the new point is inside the arena,
-- clear of obstacles and bodies, and a step from there moves toward the target.
local function tryNudge(
	actor: EnemyRoster.Actor,
	targetX: number,
	targetZ: number,
	obstacles: { Obstacle }?,
	members: { Member },
	selfId: number
): boolean
	local radius = bodyRadius(actor.kind)
	local dist, dx, dz = distance(actor.x, actor.z, targetX, targetZ)
	local ux = 0
	local uz = -1
	if dist > 1e-4 then
		ux = dx / dist
		uz = dz / dist
	end
	local px = -uz
	local pz = ux
	local diag = 0.70710678118
	local headings = {
		{ px, pz },
		{ -px, -pz },
		{ ux * diag + px * diag, uz * diag + pz * diag },
		{ ux * diag - px * diag, uz * diag - pz * diag },
	}
	local nudge = Enemies.STUCK_NUDGE
	if not finite(nudge) or nudge <= 0 then
		nudge = 8
	end
	local reach = stepReach(actor.kind)
	for _, heading in ipairs(headings) do
		local nx = actor.x + heading[1] * nudge
		local nz = actor.z + heading[2] * nudge
		if
			not crowded(nx, nz, radius, obstacles, members, selfId)
			and canAdvance(nx, nz, targetX, targetZ, radius, obstacles, reach)
		then
			actor.x = nx
			actor.z = nz
			return true
		end
	end
	return false
end

local function nearestGap(
	x: number,
	z: number,
	radius: number,
	obstacles: { Obstacle }?,
	members: { Member },
	selfId: number
): number
	local gap = 1000
	local pad = Enemies.SPAWN_CLEAR
	if not finite(pad) or pad < 0 then
		pad = 0
	end
	if obstacles ~= nil then
		for _, disk in ipairs(obstacles) do
			if diskOk(disk) then
				local dx = x - disk.x
				local dz = z - disk.z
				local room = math.sqrt(dx * dx + dz * dz) - disk.radius - radius - pad
				if room < gap then
					gap = room
				end
			end
		end
	end
	for _, member in ipairs(members) do
		local other = member.actor
		if member.id ~= selfId and other.hp > 0 then
			local dx = x - other.x
			local dz = z - other.z
			local room = math.sqrt(dx * dx + dz * dz) - bodyRadius(other.kind) - radius - pad
			if room < gap then
				gap = room
			end
		end
	end
	return gap
end

-- A grid point inside ARENA. Prefer a point that can step toward the target
-- and has the most air around it. The center is only the last resort.
local function findClearSpawn(
	radius: number,
	targetX: number,
	targetZ: number,
	obstacles: { Obstacle }?,
	members: { Member },
	selfId: number,
	reach: number
): (number, number)
	local box = Enemies.ARENA
	local stride = Enemies.SPAWN_CLEAR
	if not finite(stride) or stride < 1 then
		stride = 3
	end
	local bestX = (box.minX + box.maxX) * 0.5
	local bestZ = (box.minZ + box.maxZ) * 0.5
	local bestScore = -math.huge
	local found = false
	local roomX = bestX
	local roomZ = bestZ
	local roomGap = -math.huge
	local z = box.minZ + radius
	local zMax = box.maxZ - radius
	local xMin = box.minX + radius
	local xMax = box.maxX - radius
	while z <= zMax do
		local x = xMin
		while x <= xMax do
			local gap = nearestGap(x, z, radius, obstacles, members, selfId)
			if gap > roomGap then
				roomGap = gap
				roomX = x
				roomZ = z
			end
			if not crowded(x, z, radius, obstacles, members, selfId) then
				local score = gap
				if canAdvance(x, z, targetX, targetZ, radius, obstacles, reach) then
					score += 1000
				end
				if not found or score > bestScore then
					found = true
					bestScore = score
					bestX = x
					bestZ = z
				end
			end
			x += stride
		end
		z += stride
	end
	if found then
		return bestX, bestZ
	end
	if insideArena(roomX, roomZ, radius) then
		return roomX, roomZ
	end
	return bestX, bestZ
end

local function respawnAt(
	actor: EnemyRoster.Actor,
	targetX: number,
	targetZ: number,
	obstacles: { Obstacle }?,
	members: { Member },
	selfId: number
)
	local radius = bodyRadius(actor.kind)
	local x, z = findClearSpawn(radius, targetX, targetZ, obstacles, members, selfId, stepReach(actor.kind))
	actor.x = x
	actor.z = z
	actor.shot = nil
end

local function blankTrack(): Track
	return {
		best = -1,
		idle = 0,
		nudges = 0,
		resets = 0,
		hurt = false,
	}
end

function markHurt(run: Run, id: number)
	if run.tracks == nil then
		run.tracks = {}
	end
	local track = run.tracks[id]
	if track == nil then
		track = blankTrack()
		run.tracks[id] = track
	end
	track.hurt = true
	track.idle = 0
end

local function stallLimit(): number
	local limit = Enemies.STUCK_SECONDS
	if not finite(limit) or limit <= 0 or limit > 30 then
		return 30
	end
	return limit
end

local function watchMember(
	run: Run,
	member: Member,
	targetX: number,
	targetZ: number,
	dt: number,
	obstacles: { Obstacle }?,
	limit: number
): Pulse
	local actor = member.actor
	local track = run.tracks[member.id]
	if track == nil then
		track = blankTrack()
		run.tracks[member.id] = track
	end
	local distBefore = distance(actor.x, actor.z, targetX, targetZ)
	if track.best < 0 then
		track.best = distBefore
	end
	local dealt = applyMove(actor, targetX, targetZ, dt, obstacles)
	local distAfter = distance(actor.x, actor.z, targetX, targetZ)
	local closed = track.best - distAfter
	local engaged = dealt > 0 or track.hurt == true or closed >= Enemies.STUCK_PROGRESS
	track.hurt = false
	if engaged then
		track.idle = 0
		track.best = distAfter
	else
		track.idle += dt
		if track.idle > limit then
			track.idle = limit
		end
	end
	local stall = track.idle
	local nudged = false
	local reset = false
	if not engaged and track.idle >= limit then
		nudged = true
		track.nudges += 1
		local freed = tryNudge(actor, targetX, targetZ, obstacles, run.members, member.id)
		if freed then
			engaged = true
			track.idle = 0
			track.best = distance(actor.x, actor.z, targetX, targetZ)
		else
			respawnAt(actor, targetX, targetZ, obstacles, run.members, member.id)
			reset = true
			track.resets += 1
			track.idle = 0
			track.best = distance(actor.x, actor.z, targetX, targetZ)
		end
	end
	return {
		id = member.id,
		kind = actor.kind,
		engaged = engaged,
		nudged = nudged,
		reset = reset,
		idle = stall,
		nudges = track.nudges,
		resets = track.resets,
		x = actor.x,
		z = actor.z,
	}
end

-- One server tick for every living enemy. Progress toward `target` or
-- damage clears the stall clock. At the config limit the enemy is nudged
-- onto a clear step, and if that step is still blocked it respawns inside
-- the arena. The reported idle never passes the 30 second cap.
function WaveFlow.step(run: Run, targetX: number, targetZ: number, dt: number, obstacles: { Obstacle }?): { Pulse }
	local pulses = {}
	if type(run) ~= "table" or run.clear == true then
		return pulses
	end
	if not finite(targetX) or not finite(targetZ) or not finite(dt) or dt <= 0 then
		return pulses
	end
	if run.tracks == nil then
		run.tracks = {}
	end
	local limit = stallLimit()
	for _, member in ipairs(run.members) do
		if member.actor.hp > 0 then
			table.insert(pulses, watchMember(run, member, targetX, targetZ, dt, obstacles, limit))
		end
	end
	return pulses
end

return WaveFlow
