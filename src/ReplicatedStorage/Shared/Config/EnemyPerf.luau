--!strict

--[[
	M10 enemy performance for the live crawl. Numbers and pure decisions.
	No save fields, no Robux, no remotes.

	LaunchGate.enemyPerf (default off) is what turns the server path on.

	The gray-box wave roster is on this branch. It does not keep a second
	alive cap or a second stuck watchdog. The only cap is ALIVE_CAP (22).
	The only watchdog is this module's 30 second clock, used by the live
	crawl. WaveFlow claims a slot per spawn and releases it on death or
	when that run stops.
]]

local EnemyPerf = {}

-- Hard ceiling on living wave enemies. Validation rejects any other value.
EnemyPerf.ALIVE_CAP = 22

-- An enemy that should be closing, and does not, is respawned at this age.
-- It must not stay stuck longer than 30 seconds.
EnemyPerf.STUCK_SECONDS = 30

-- Planar studs from the stall anchor that count as progress.
EnemyPerf.STUCK_PROGRESS = 0.75

-- Humanoid states the chase rig does not use. Running stays enabled.
-- The server calls SetStateEnabled(state, false) for each name.
EnemyPerf.DISABLED_STATES = table.freeze({
	"Climbing",
	"Dead",
	"FallingDown",
	"Flying",
	"Freefall",
	"GettingUp",
	"Jumping",
	"Landed",
	"Physics",
	"PlatformStanding",
	"Ragdoll",
	"RunningNoPhysics",
	"Seated",
	"StrafingNoPhysics",
	"Swimming",
})

export type Clock = {
	x: number,
	z: number,
	since: number,
}

export type Pool = {
	idle: { string },
	alive: number,
	queued: { string },
}

export type Retire = {
	keep: boolean,
	nextKind: string?,
	nextAction: ("fresh" | "reuse")?,
}

local KNOWN_DISABLED: { [string]: boolean } = {
	Climbing = true,
	Dead = true,
	FallingDown = true,
	Flying = true,
	Freefall = true,
	GettingUp = true,
	Jumping = true,
	Landed = true,
	Physics = true,
	PlatformStanding = true,
	Ragdoll = true,
	RunningNoPhysics = true,
	Seated = true,
	StrafingNoPhysics = true,
	Swimming = true,
}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function EnemyPerf.validate(config: any): (boolean, string?)
	if type(config) ~= "table" then
		return false, "config"
	end
	if config.ALIVE_CAP ~= 22 then
		return false, "ALIVE_CAP"
	end
	if not finite(config.STUCK_SECONDS) or config.STUCK_SECONDS <= 0 or config.STUCK_SECONDS > 30 then
		return false, "STUCK_SECONDS"
	end
	if not finite(config.STUCK_PROGRESS) or config.STUCK_PROGRESS <= 0 then
		return false, "STUCK_PROGRESS"
	end
	local states = config.DISABLED_STATES
	if type(states) ~= "table" or #states < 1 then
		return false, "DISABLED_STATES"
	end
	local seen: { [string]: boolean } = {}
	local hasDead = false
	for _, name in ipairs(states) do
		if type(name) ~= "string" or KNOWN_DISABLED[name] ~= true or seen[name] == true then
			return false, "DISABLED_STATES"
		end
		seen[name] = true
		if name == "Dead" then
			hasDead = true
		end
	end
	if not hasDead then
		return false, "DISABLED_STATES"
	end
	return true, nil
end

function EnemyPerf.isBiggest(count: number, maxCount: number): boolean
	if not finite(count) or not finite(maxCount) then
		return false
	end
	return maxCount > 0 and count >= maxCount
end

function EnemyPerf.begin(x: number, z: number, now: number): Clock
	return { x = x, z = z, since = now }
end

-- `moving` is false when the enemy is in range, stunned, or lunging.
-- That contact clears the stall. A true result means despawn and respawn.
function EnemyPerf.observe(clock: Clock, x: number, z: number, now: number, moving: boolean): (Clock, boolean)
	if not moving then
		return { x = x, z = z, since = now }, false
	end
	local dx = x - clock.x
	local dz = z - clock.z
	local moved = math.sqrt(dx * dx + dz * dz)
	if moved >= EnemyPerf.STUCK_PROGRESS then
		return { x = x, z = z, since = now }, false
	end
	if now - clock.since >= EnemyPerf.STUCK_SECONDS then
		return { x = x, z = z, since = now }, true
	end
	return { x = clock.x, z = clock.z, since = clock.since }, false
end

function EnemyPerf.respawnPad(x: number, z: number, pads: { { x: number, z: number } }): (number, number)
	local pick = pads[1]
	if pick == nil then
		return 0, 0
	end
	local best = -1
	for _, pad in ipairs(pads) do
		local dx = pad.x - x
		local dz = pad.z - z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist > best then
			best = dist
			pick = pad
		end
	end
	return pick.x, pick.z
end

function EnemyPerf.newPool(): Pool
	return {
		idle = {},
		alive = 0,
		queued = {},
	}
end

-- Undo one claim. The kind returns to the idle list while that list is
-- under the cap. This does not promote the queue. A stopped wave run
-- releases every slot it still holds.
function EnemyPerf.release(pool: Pool, kind: string): boolean
	if pool.alive <= 0 or type(kind) ~= "string" then
		return false
	end
	pool.alive -= 1
	if #pool.idle < EnemyPerf.ALIVE_CAP then
		table.insert(pool.idle, kind)
	end
	return true
end

function EnemyPerf.claim(pool: Pool, kind: string): "fresh" | "reuse" | "queued"
	if pool.alive >= EnemyPerf.ALIVE_CAP then
		table.insert(pool.queued, kind)
		return "queued"
	end
	pool.alive += 1
	local at = table.find(pool.idle, kind)
	if at ~= nil then
		table.remove(pool.idle, at)
		return "reuse"
	end
	return "fresh"
end

function EnemyPerf.retire(pool: Pool, kind: string): Retire
	if pool.alive > 0 then
		pool.alive -= 1
	end
	local keep = #pool.idle < EnemyPerf.ALIVE_CAP
	if keep then
		table.insert(pool.idle, kind)
	end
	local nextKind = table.remove(pool.queued, 1)
	if nextKind == nil then
		return { keep = keep, nextKind = nil, nextAction = nil }
	end
	pool.alive += 1
	local at = table.find(pool.idle, nextKind)
	if at ~= nil then
		table.remove(pool.idle, at)
		return { keep = keep, nextKind = nextKind, nextAction = "reuse" }
	end
	return { keep = keep, nextKind = nextKind, nextAction = "fresh" }
end

-- Wave clear parks a rig without promoting the queue. The caller wipes after.
function EnemyPerf.stash(pool: Pool, kind: string): boolean
	if #pool.idle >= EnemyPerf.ALIVE_CAP then
		return false
	end
	table.insert(pool.idle, kind)
	return true
end

function EnemyPerf.unstash(pool: Pool, kind: string)
	local at = table.find(pool.idle, kind)
	if at ~= nil then
		table.remove(pool.idle, at)
	end
end

function EnemyPerf.wipe(pool: Pool)
	pool.alive = 0
	table.clear(pool.queued)
end

return table.freeze(EnemyPerf)
