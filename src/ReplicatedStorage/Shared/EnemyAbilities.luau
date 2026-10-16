--!strict

--[[
	Rootvault haste shrines, mender healing, and shielder blocks.

	The server calls these with plain tables. This module does not spawn
	instances, read profiles, or spend Robux. Tunables live in the tables
	below. Kinds match Rootvault.ROLES (shielder = root_brute, mender =
	moss_crawler) and Rootvault.SHRINES includes "haste".

	Haste is a timed player buff. A mender pulse heals one wounded ally.
	A shielder blocks a hit that comes from its front arc.
]]

local EnemyAbilities = {}

export type Haste = {
	id: string,
	untilAt: number,
	attackSpeed: number,
	moveSpeed: number,
}

export type Pulse = {
	menderId: string,
	targetId: string,
	amount: number,
	hp: number,
	nextHeal: number,
}

-- Shorter than a Normal run. Picking Haste again refreshes this and does
-- not stack. Might's damage bonus is separate and is not applied here.
EnemyAbilities.HASTE = {
	id = "haste",
	duration = 30,
	attackSpeed = 1.2,
	moveSpeed = 1.15,
	attackMin = 0.2,
	attackMax = 4,
	moveMin = 8,
	moveMax = 24,
	-- Roblox default, used only when the shrine is taken with no humanoid.
	baseWalk = 16,
	gainedNote = "Haste. Swings and steps come faster.",
	fadedNote = "Haste fades.",
}

-- One ally per pulse. 12% of that ally's max HP, clamped, and never past full.
EnemyAbilities.MENDER = {
	kind = "moss_crawler",
	ignoreKind = "grandmother_gnarl",
	interval = 4,
	range = 18,
	healFraction = 0.12,
	minHeal = 1,
	maxHeal = 24,
	pulseNote = "The moss crawler mends an ally.",
	priorityNote = "Focus the mender.",
}

-- cos(60°) = 0.5, so the front 120° is the shield. The turn cap is what
-- lets a player step out of that arc. moveEnemy currently snaps lookAt.
EnemyAbilities.SHIELDER = {
	kind = "root_brute",
	frontDot = 0.5,
	frontMultiplier = 0,
	flankMultiplier = 1,
	turnSpeed = 1.6,
	blockNote = "Blocked. Flank the brute.",
}

local MIN_LENGTH = 1e-4

table.freeze(EnemyAbilities.HASTE)
table.freeze(EnemyAbilities.MENDER)
table.freeze(EnemyAbilities.SHIELDER)

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function clamp(value: number, low: number, high: number): number
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

local function unit(x: any, z: any): (number?, number?)
	local fx = finite(x)
	local fz = finite(z)
	if fx == nil or fz == nil then
		return nil, nil
	end
	local length = math.sqrt(fx * fx + fz * fz)
	if length < MIN_LENGTH then
		return nil, nil
	end
	return fx / length, fz / length
end

local function scaleHit(amount: number, multiplier: number): number
	local mul = finite(multiplier)
	if mul == nil or mul < 0 then
		return 0
	end
	local dealt = math.floor(amount * mul + 0.5)
	if dealt < 0 then
		return 0
	end
	return dealt
end

function EnemyAbilities.applyHaste(shrineId: any, now: number): Haste?
	local at = finite(now)
	if at == nil or shrineId ~= EnemyAbilities.HASTE.id then
		return nil
	end
	local row = EnemyAbilities.HASTE
	local untilAt = at + row.duration
	if finite(untilAt) == nil then
		return nil
	end
	return {
		id = row.id,
		untilAt = untilAt,
		attackSpeed = row.attackSpeed,
		moveSpeed = row.moveSpeed,
	}
end

function EnemyAbilities.hasteActive(haste: Haste?, now: number): boolean
	local at = finite(now)
	if haste == nil or at == nil or haste.id ~= EnemyAbilities.HASTE.id then
		return false
	end
	local deadline = finite(haste.untilAt)
	if deadline == nil then
		return false
	end
	return at < deadline
end

-- Drops the buff once `now` has reached untilAt. An active buff is returned
-- unchanged so the caller can keep the same table.
function EnemyAbilities.expireHaste(haste: Haste?, now: number): Haste?
	if EnemyAbilities.hasteActive(haste, now) then
		return haste
	end
	return nil
end

function EnemyAbilities.secondsLeft(haste: Haste?, now: number): number
	local at = finite(now)
	if haste == nil or at == nil or not EnemyAbilities.hasteActive(haste, now) then
		return 0
	end
	return haste.untilAt - at
end

local function scaledSpeed(base: number, multiplier: number, low: number, high: number): number
	local speed = finite(base)
	local mul = finite(multiplier)
	if speed == nil or speed <= 0 or mul == nil or mul <= 0 then
		return 0
	end
	return clamp(speed * mul, low, high)
end

-- Pass the gear attack speed, not a value this function already returned.
function EnemyAbilities.attackSpeed(base: number, haste: Haste?, now: number): number
	local speed = finite(base)
	if speed == nil or speed <= 0 then
		return 0
	end
	if haste == nil or not EnemyAbilities.hasteActive(haste, now) then
		return speed
	end
	local row = EnemyAbilities.HASTE
	return scaledSpeed(speed, haste.attackSpeed, row.attackMin, row.attackMax)
end

-- Pass the WalkSpeed captured when Haste was applied.
function EnemyAbilities.moveSpeed(base: number, haste: Haste?, now: number): number
	local speed = finite(base)
	if speed == nil or speed <= 0 then
		return 0
	end
	if haste == nil or not EnemyAbilities.hasteActive(haste, now) then
		return speed
	end
	local row = EnemyAbilities.HASTE
	return scaledSpeed(speed, haste.moveSpeed, row.moveMin, row.moveMax)
end

-- Rotates a planar look toward `aim` by at most SHIELDER.turnSpeed * dt.
-- A zero look snaps to aim. A zero aim, or a non-positive dt, keeps look.
function EnemyAbilities.turnShield(
	lookX: number,
	lookZ: number,
	aimX: number,
	aimZ: number,
	dt: number
): (number, number)
	local ax, az = unit(aimX, aimZ)
	local lx, lz = unit(lookX, lookZ)
	if ax == nil or az == nil then
		if lx == nil or lz == nil then
			return 0, 1
		end
		return lx, lz
	end
	if lx == nil or lz == nil then
		return ax, az
	end
	local step = finite(dt)
	if step == nil or step <= 0 then
		return lx, lz
	end
	local maxStep = EnemyAbilities.SHIELDER.turnSpeed * step
	local dot = math.clamp(lx * ax + lz * az, -1, 1)
	local cross = lx * az - lz * ax
	local angle = math.atan2(cross, dot)
	if angle > maxStep then
		angle = maxStep
	elseif angle < -maxStep then
		angle = -maxStep
	end
	local sine = math.sin(angle)
	local cosine = math.cos(angle)
	return lx * cosine - lz * sine, lx * sine + lz * cosine
end

-- Frontal hits use frontMultiplier (0 blocks). Flank and rear use
-- flankMultiplier. Dead shielders, other kinds, a missing look, a bad
-- amount, and an attacker with no offset do not block.
function EnemyAbilities.block(
	enemy: any,
	attackerX: number,
	attackerZ: number,
	amount: number
): (number, boolean)
	local dealt = finite(amount)
	if dealt == nil or dealt <= 0 then
		return 0, false
	end
	if type(enemy) ~= "table" or enemy.kind ~= EnemyAbilities.SHIELDER.kind then
		return dealt, false
	end
	local hp = finite(enemy.hp)
	if hp == nil or hp <= 0 then
		return dealt, false
	end
	local lx, lz = unit(enemy.lookX, enemy.lookZ)
	local ex = finite(enemy.x)
	local ez = finite(enemy.z)
	local ax = finite(attackerX)
	local az = finite(attackerZ)
	if lx == nil or lz == nil or ex == nil or ez == nil or ax == nil or az == nil then
		return dealt, false
	end
	local dx = ax - ex
	local dz = az - ez
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < MIN_LENGTH then
		return dealt, false
	end
	local facing = (dx / dist) * lx + (dz / dist) * lz
	local row = EnemyAbilities.SHIELDER
	if facing >= row.frontDot then
		return scaleHit(dealt, row.frontMultiplier), true
	end
	return scaleHit(dealt, row.flankMultiplier), false
end

local function isMender(enemy: any): boolean
	if type(enemy) ~= "table" then
		return false
	end
	if enemy.kind ~= EnemyAbilities.MENDER.kind or type(enemy.id) ~= "string" or enemy.id == "" then
		return false
	end
	local hp = finite(enemy.hp)
	return hp ~= nil and hp > 0
end

local function placed(enemy: any): boolean
	local maxHp = finite(enemy.maxHp)
	return finite(enemy.x) ~= nil and finite(enemy.z) ~= nil and maxHp ~= nil and maxHp > 0
end

local function healAmount(maxHp: number, current: number): number
	local room = maxHp - current
	if room <= 0 then
		return 0
	end
	local row = EnemyAbilities.MENDER
	local raw = math.floor(maxHp * row.healFraction + 0.5)
	if raw < row.minHeal then
		raw = row.minHeal
	end
	if raw > row.maxHeal then
		raw = row.maxHeal
	end
	if raw > room then
		raw = room
	end
	return raw
end

local function inRange(mender: any, ally: any): boolean
	local mx = finite(mender.x)
	local mz = finite(mender.z)
	local ax = finite(ally.x)
	local az = finite(ally.z)
	if mx == nil or mz == nil or ax == nil or az == nil then
		return false
	end
	local dx = ax - mx
	local dz = az - mz
	return dx * dx + dz * dz <= EnemyAbilities.MENDER.range * EnemyAbilities.MENDER.range
end

local function wounded(enemy: any, mender: any, hpNow: { [string]: number }): boolean
	if type(enemy) ~= "table" or type(enemy.id) ~= "string" or enemy.id == mender.id then
		return false
	end
	if enemy.kind == EnemyAbilities.MENDER.ignoreKind or not placed(enemy) then
		return false
	end
	local hp = hpNow[enemy.id]
	local maxHp = finite(enemy.maxHp)
	if hp == nil or maxHp == nil or hp <= 0 or hp >= maxHp then
		return false
	end
	return inRange(mender, enemy)
end

local function prefer(candidate: any, current: any, hpNow: { [string]: number }): boolean
	local cHp = hpNow[candidate.id]
	local uHp = hpNow[current.id]
	local cMax = finite(candidate.maxHp) or 0
	local uMax = finite(current.maxHp) or 0
	if cHp * uMax < uHp * cMax then
		return true
	end
	if uHp * cMax < cHp * uMax then
		return false
	end
	return candidate.id < current.id
end

-- Each living, placed mender who is off cooldown heals one ally. No legal
-- target leaves the cooldown alone (no pulse). Inputs are not mutated.
-- Ids in one call are unique. A repeated id is the same fighter.
function EnemyAbilities.mend(enemies: { any }, now: number): { Pulse }
	local at = finite(now)
	if at == nil or type(enemies) ~= "table" then
		return {}
	end
	local hpNow: { [string]: number } = {}
	local menders = {}
	for _, enemy in ipairs(enemies) do
		if type(enemy) == "table" and type(enemy.id) == "string" then
			local hp = finite(enemy.hp)
			if hp ~= nil then
				hpNow[enemy.id] = hp
			end
		end
		if isMender(enemy) and placed(enemy) then
			table.insert(menders, enemy)
		end
	end
	table.sort(menders, function(left, right)
		return left.id < right.id
	end)

	local pulses: { Pulse } = {}
	for _, mender in ipairs(menders) do
		local due = finite(mender.nextHeal)
		if due ~= nil and at < due then
			continue
		end
		local target: any = nil
		for _, enemy in ipairs(enemies) do
			if
				wounded(enemy, mender, hpNow) and (target == nil or prefer(enemy, target, hpNow))
			then
				target = enemy
			end
		end
		if target == nil then
			continue
		end
		local current = hpNow[target.id]
		local maxHp = finite(target.maxHp)
		if current == nil or maxHp == nil then
			continue
		end
		local amount = healAmount(maxHp, current)
		if amount <= 0 then
			continue
		end
		local nextHp = current + amount
		hpNow[target.id] = nextHp
		table.insert(pulses, {
			menderId = mender.id,
			targetId = target.id,
			amount = amount,
			hp = nextHp,
			nextHeal = at + EnemyAbilities.MENDER.interval,
		})
	end
	return pulses
end

-- The living mender the player should focus. Ready menders (no deadline,
-- or a deadline already reached) win. Ties break to the lower id.
function EnemyAbilities.priority(enemies: { any }, now: number): string?
	if type(enemies) ~= "table" then
		return nil
	end
	local at = finite(now) or 0
	local bestId: string? = nil
	local bestScore = math.huge
	for _, enemy in ipairs(enemies) do
		if isMender(enemy) then
			local due = finite(enemy.nextHeal)
			local score = 0
			if due ~= nil and due > at then
				score = due
			end
			local id = enemy.id :: string
			if bestId == nil or score < bestScore or (score == bestScore and id < bestId) then
				bestId = id
				bestScore = score
			end
		end
	end
	return bestId
end

return EnemyAbilities
