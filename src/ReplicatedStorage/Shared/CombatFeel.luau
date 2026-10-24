--!strict

--[[
	Hit feedback, dodge, combos, telegraphs, and the stagger bar.

	Times and multipliers live here so a playtest tune is one edit.
	The server owns charges, combo count, and stagger. The client only
	draws what a CombatFx payload already decided.
]]

local CombatFeel = {}

CombatFeel.HITSTOP = { light = 0.03, heavy = 0.07, kill = 0.1 }
CombatFeel.FLASH = { light = 0.08, heavy = 0.12, kill = 0.12 }
CombatFeel.DODGE_SECONDS = 0.35
CombatFeel.IFRAME_SECONDS = 0.2
CombatFeel.DODGE_CHARGES = 2
CombatFeel.DODGE_RECHARGE = 3
CombatFeel.PERFECT_WINDOW = 0.15
CombatFeel.SLOWMO_SECONDS = 0.3
CombatFeel.PERFECT_ULT = 12
CombatFeel.COMBO_HITS = 3
CombatFeel.CHARGE_MULT = 1.75
CombatFeel.HEAVY_MULT = 1.4
-- A heavy is a hold the server measured. The client boolean is not a multiplier.
CombatFeel.CHARGE_HOLD = 0.35
CombatFeel.CHARGE_GRACE = 1
-- cos(60 degrees). Aim outside this cone uses the server facing.
CombatFeel.AIM_DOT = 0.5
CombatFeel.COMBO_IDLE = 3
CombatFeel.STAGGER_MAX = 100
CombatFeel.STAGGER_STUN = 4
CombatFeel.STAGGER_LIGHT = 8
CombatFeel.STAGGER_HEAVY = 18
CombatFeel.NORMAL_STAGGER = 0.28
CombatFeel.TELEGRAPH_NORMAL = 0.8
CombatFeel.TELEGRAPH_MIN = 0.5
-- First boss (Grandmother Gnarl) windup. Long enough to walk out of the
-- 8-stud red square. Trash telegraphs stay on TELEGRAPH_NORMAL.
CombatFeel.TELEGRAPH_BOSS = 1.8
-- Half-extent of the red square marker (Vector3.new(8, 0.2, 8)).
CombatFeel.MARKER_HALF = 4
-- "RED dodge" is a lesson, not a permanent label.
CombatFeel.CUE_LESSONS = 3
CombatFeel.SWING_SECONDS = 0.28
CombatFeel.SWING_PITCH = 80
CombatFeel.FLINCH_SECONDS = 0.12
CombatFeel.DEATH_SECONDS = 0.45
CombatFeel.MAGNET_RANGE = 14
CombatFeel.PRESS = 0.94
CombatFeel.CAMERA_MIN = 3

CombatFeel.BUFFS = {
	{ hits = 10, bonus = 0.05 },
	{ hits = 25, bonus = 0.1 },
	{ hits = 50, bonus = 0.15 },
}

CombatFeel.TELEGRAPHS = {
	red = { verb = "dodge", rgb = { 220, 64, 56 } },
	yellow = { verb = "stack", rgb = { 240, 196, 64 } },
	purple = { verb = "spread", rgb = { 168, 96, 220 } },
	blue = { verb = "interrupt", rgb = { 80, 150, 230 } },
}

export type DodgeState = {
	charges: number,
	nextAt: number,
	iframeUntil: number,
	slowUntil: number,
}

export type Juice = {
	weight: string,
	hitstop: number,
	flash: number,
	shake: number,
	shards: boolean,
	particles: number,
}

function CombatFeel.blankDodge(now: number): DodgeState
	return {
		charges = CombatFeel.DODGE_CHARGES,
		nextAt = now,
		iframeUntil = 0,
		slowUntil = 0,
	}
end

function CombatFeel.refillDodge(state: DodgeState, now: number)
	if state.charges >= CombatFeel.DODGE_CHARGES then
		state.charges = CombatFeel.DODGE_CHARGES
		return
	end
	while state.charges < CombatFeel.DODGE_CHARGES and now >= state.nextAt do
		state.charges += 1
		if state.charges < CombatFeel.DODGE_CHARGES then
			state.nextAt += CombatFeel.DODGE_RECHARGE
		end
	end
end

function CombatFeel.tryDodge(state: DodgeState, now: number): boolean
	CombatFeel.refillDodge(state, now)
	if state.charges < 1 then
		return false
	end
	if state.charges >= CombatFeel.DODGE_CHARGES then
		state.nextAt = now + CombatFeel.DODGE_RECHARGE
	end
	state.charges -= 1
	state.iframeUntil = now + CombatFeel.IFRAME_SECONDS
	return true
end

function CombatFeel.iframe(state: DodgeState, now: number): boolean
	return now < state.iframeUntil
end

function CombatFeel.perfect(telegraphEndsAt: number, now: number): boolean
	return now <= telegraphEndsAt and now >= telegraphEndsAt - CombatFeel.PERFECT_WINDOW
end

export type Telegraph = {
	endsAt: number,
	awarded: boolean,
}

-- A dodge packet arrives after the press. This is the only extra time past
-- the telegraph end. It does not open the window any earlier.
CombatFeel.DODGE_LATENCY = 0.1

function CombatFeel.openTelegraph(endsAt: number): Telegraph
	return {
		endsAt = endsAt,
		awarded = false,
	}
end

-- `clientStamp` is never read. Perfect is the server receive time against
-- the server window, and one telegraph pays ult once.
function CombatFeel.scorePerfect(window: Telegraph?, now: number, _clientStamp: any): boolean
	if window == nil or window.awarded == true then
		return false
	end
	local endsAt = window.endsAt
	if type(endsAt) ~= "number" or endsAt ~= endsAt then
		return false
	end
	if type(now) ~= "number" or now ~= now then
		return false
	end
	local early = endsAt - CombatFeel.PERFECT_WINDOW
	local late = endsAt + CombatFeel.DODGE_LATENCY
	if now < early or now > late then
		return false
	end
	window.awarded = true
	return true
end

-- One dodge scores at most one telegraph. Each window still pays only once.
function CombatFeel.scoreAny(windows: { Telegraph }?, now: number, clientStamp: any): boolean
	if windows == nil then
		return false
	end
	for _, window in ipairs(windows) do
		if CombatFeel.scorePerfect(window, now, clientStamp) then
			return true
		end
	end
	return false
end

function CombatFeel.pruneTelegraphs(windows: { Telegraph }, now: number): { Telegraph }
	local kept = {}
	local limit = CombatFeel.DODGE_LATENCY
	for _, window in ipairs(windows) do
		if type(window.endsAt) == "number" and now <= window.endsAt + limit then
			table.insert(kept, window)
		end
	end
	return kept
end

function CombatFeel.notePerfect(state: DodgeState, now: number)
	state.slowUntil = now + CombatFeel.SLOWMO_SECONDS
end

export type ChargeClock = {
	startedAt: number?,
}

function CombatFeel.blankCharge(): ChargeClock
	return {}
end

function CombatFeel.beginCharge(clock: ChargeClock, now: number)
	if type(clock) ~= "table" or type(now) ~= "number" or now ~= now then
		return
	end
	local started = clock.startedAt
	local window = CombatFeel.CHARGE_HOLD + CombatFeel.CHARGE_GRACE
	if type(started) == "number" and started == started and now - started <= window then
		return
	end
	clock.startedAt = now
end

-- `_clientFlag` is accepted and ignored. A forged true does not shorten the hold.
function CombatFeel.takeCharge(clock: ChargeClock, now: number, _clientFlag: any): boolean
	if type(clock) ~= "table" then
		return false
	end
	local started = clock.startedAt
	clock.startedAt = nil
	if type(started) ~= "number" or started ~= started then
		return false
	end
	if type(now) ~= "number" or now ~= now then
		return false
	end
	local held = now - started
	if held < CombatFeel.CHARGE_HOLD then
		return false
	end
	if held > CombatFeel.CHARGE_HOLD + CombatFeel.CHARGE_GRACE then
		return false
	end
	return true
end

-- When the next local slash may start. A heavy's Attack packet lands
-- CHARGE_HOLD after the press, and the server cooldown starts then.
function CombatFeel.swingLock(now: number, cooldown: number, charged: boolean?): number
	local at = now
	if type(at) ~= "number" or at ~= at then
		at = 0
	end
	local wait = cooldown
	if type(wait) ~= "number" or wait ~= wait or wait < 0 then
		wait = 1
	end
	local hold = 0
	if charged == true then
		hold = CombatFeel.CHARGE_HOLD
	end
	return at + hold + wait
end

local function unitOf(x: number, y: number, z: number): (number?, number?, number?)
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return nil, nil, nil
	end
	if x ~= x or y ~= y or z ~= z then
		return nil, nil, nil
	end
	if math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then
		return nil, nil, nil
	end
	local length = math.sqrt(x * x + y * y + z * z)
	if length < 1e-4 then
		return nil, nil, nil
	end
	return x / length, y / length, z / length
end

function CombatFeel.clampLook(
	aimX: number,
	aimY: number,
	aimZ: number,
	faceX: number,
	faceY: number,
	faceZ: number,
	minDot: number
): (number, number, number)
	local fx, fy, fz = unitOf(faceX, faceY, faceZ)
	if fx == nil or fy == nil or fz == nil then
		return 0, 0, -1
	end
	local ax, ay, az = unitOf(aimX, aimY, aimZ)
	if ax == nil or ay == nil or az == nil then
		return fx, fy, fz
	end
	local limit = CombatFeel.AIM_DOT
	if type(minDot) == "number" and minDot == minDot then
		limit = minDot
	end
	local dot = ax * fx + ay * fy + az * fz
	if dot < limit then
		return fx, fy, fz
	end
	return ax, ay, az
end

function CombatFeel.advanceCombo(chain: number, lastAt: number, now: number, charged: boolean)
	local count = chain
	if lastAt > 0 and now - lastAt > CombatFeel.COMBO_IDLE then
		count = 0
	end
	local index = (count % CombatFeel.COMBO_HITS) + 1
	local heavy = charged or index == CombatFeel.COMBO_HITS
	local multiplier = 1
	if charged then
		multiplier = CombatFeel.CHARGE_MULT
	elseif index == CombatFeel.COMBO_HITS then
		multiplier = CombatFeel.HEAVY_MULT
	end
	local nextChain = count + 1
	return {
		index = index,
		chain = nextChain,
		heavy = heavy,
		multiplier = multiplier * (1 + CombatFeel.comboBonus(nextChain)),
		bonus = CombatFeel.comboBonus(nextChain),
	}
end

function CombatFeel.comboBonus(chain: number): number
	local bonus = 0
	for _, row in ipairs(CombatFeel.BUFFS) do
		if chain >= row.hits then
			bonus = row.bonus
		end
	end
	return bonus
end

function CombatFeel.weight(crit: boolean, heavy: boolean, killed: boolean): string
	if killed then
		return "kill"
	end
	if crit or heavy then
		return "heavy"
	end
	return "light"
end

function CombatFeel.juice(kind: string): Juice
	if kind == "kill" then
		return {
			weight = "kill",
			hitstop = CombatFeel.HITSTOP.kill,
			flash = CombatFeel.FLASH.kill,
			shake = 0.15,
			shards = true,
			particles = 12,
		}
	end
	if kind == "heavy" then
		return {
			weight = "heavy",
			hitstop = CombatFeel.HITSTOP.heavy,
			flash = CombatFeel.FLASH.heavy,
			shake = 0.15,
			shards = false,
			particles = 8,
		}
	end
	return {
		weight = "light",
		hitstop = CombatFeel.HITSTOP.light,
		flash = CombatFeel.FLASH.light,
		shake = 0,
		shards = false,
		particles = 5,
	}
end

function CombatFeel.particlesFor(tier: string, juice: Juice): number
	if tier == "low" then
		return math.max(2, math.floor(juice.particles * 0.5))
	end
	return juice.particles
end

function CombatFeel.vfxBudget(tier: string, intensity: number, juice: Juice): number
	local scale = intensity
	if scale ~= scale or scale < 0 then
		scale = 0
	elseif scale > 1 then
		scale = 1
	end
	return math.max(0, math.floor(CombatFeel.particlesFor(tier, juice) * scale + 0.5))
end

function CombatFeel.lootVelocity(index: number): (number, number, number)
	local angle = index * 1.7
	return math.cos(angle) * 8, 16, math.sin(angle) * 8
end

function CombatFeel.cooldownCover(elapsed: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.clamp(1 - elapsed / total, 0, 1)
end

function CombatFeel.attackAnim(index: number): string
	if index == 2 then
		return "attack2"
	end
	if index >= 3 then
		return "attack3"
	end
	return "attack1"
end

function CombatFeel.cameraDistance(blocked: number, desired: number): number
	if blocked <= 0 then
		return desired
	end
	return math.max(CombatFeel.CAMERA_MIN, blocked - 1.25)
end

function CombatFeel.shakeAllowed(tier: string, enabled: boolean, juice: Juice): number
	if not enabled or tier == "low" or juice.shake <= 0 then
		return 0
	end
	return juice.shake
end

function CombatFeel.applyStagger(bar: number, heavy: boolean, boss: boolean): (number, boolean)
	local gain = if heavy then CombatFeel.STAGGER_HEAVY else CombatFeel.STAGGER_LIGHT
	if boss then
		gain = math.floor(gain * 0.6)
	end
	local nextBar = bar + gain
	if nextBar >= CombatFeel.STAGGER_MAX then
		return 0, true
	end
	return nextBar, false
end

function CombatFeel.telegraph(color: string, difficulty: string?, role: string?)
	local row = CombatFeel.TELEGRAPHS[color]
	if row == nil then
		row = CombatFeel.TELEGRAPHS.red
		color = "red"
	end
	local seconds = CombatFeel.TELEGRAPH_MIN
	if difficulty == nil or difficulty == "normal" or difficulty == "story" then
		seconds = CombatFeel.TELEGRAPH_NORMAL
	end
	if role == "boss" then
		seconds = CombatFeel.TELEGRAPH_BOSS
	end
	return {
		color = color,
		verb = row.verb,
		seconds = seconds,
		rgb = row.rgb,
	}
end

-- Room and wave lines stay on the banner. Combat hints and loot lines do
-- not: those used to sit on the top-center toast stack.
-- Loot lines from Materials.lootHint start with this; they go to the
-- loot toast, not the gold banner.
CombatFeel.LOOT_PREFIX = "Loot: "
function CombatFeel.isLootLine(text: any): boolean
	return type(text) == "string"
		and string.sub(text, 1, #CombatFeel.LOOT_PREFIX) == CombatFeel.LOOT_PREFIX
end

function CombatFeel.hintOnBanner(text: string): boolean
	if type(text) ~= "string" then
		return false
	end
	local trimmed = string.match(text, "^%s*(.-)%s*$")
	if trimmed == nil or trimmed == "" then
		return false
	end
	if trimmed == "No target in range." then
		return false
	end
	if string.sub(trimmed, 1, 1) == "+" or CombatFeel.isLootLine(trimmed) then
		return false
	end
	if string.sub(trimmed, 1, 10) == "Picked up " then
		return false
	end
	return true
end

-- [Ghost] Clip 7: "No target in range." is a short hint. It shows for
-- 0.7 s, fades in 0.25 s, and a repeat inside HINT_REPEAT seconds is
-- skipped instead of restarting the clock (swinging at air kept it up).
CombatFeel.SHORT_HINTS = table.freeze({ ["No target in range."] = true })
CombatFeel.HINT_REPEAT = 3

export type HintPlan = { show: boolean, hold: number, fade: number }

function CombatFeel.hintPlan(text: any, lastText: any, lastAt: any, now: any): HintPlan
	local trimmed = if type(text) == "string" then string.match(text, "^%s*(.-)%s*$") or "" else ""
	if trimmed == "" then
		return { show = false, hold = 0, fade = 0 }
	end
	if CombatFeel.SHORT_HINTS[trimmed] ~= true then
		return { show = true, hold = 1.6, fade = 0.45 }
	end
	local since = if type(lastAt) == "number" and type(now) == "number"
		then now - lastAt
		else math.huge
	if lastText == trimmed and since >= 0 and since < CombatFeel.HINT_REPEAT then
		return { show = false, hold = 0, fade = 0 }
	end
	return { show = true, hold = 0.7, fade = 0.25 }
end

function CombatFeel.teachCue(seen: number): boolean
	if type(seen) ~= "number" or seen ~= seen then
		return false
	end
	return seen < CombatFeel.CUE_LESSONS
end

-- 0 at the start and end of a swing, 1 at the middle.
function CombatFeel.swingAlpha(age: number, duration: number): number
	local span = duration
	if type(span) ~= "number" or span ~= span or span <= 0 then
		span = CombatFeel.SWING_SECONDS
	end
	local t = age
	if type(t) ~= "number" or t ~= t then
		t = 0
	end
	t = math.clamp(t / span, 0, 1)
	return math.sin(t * math.pi)
end

function CombatFeel.insideMarker(
	px: number,
	pz: number,
	mx: number,
	mz: number,
	half: number
): boolean
	if
		type(px) ~= "number"
		or type(pz) ~= "number"
		or type(mx) ~= "number"
		or type(mz) ~= "number"
		or px ~= px
		or pz ~= pz
		or mx ~= mx
		or mz ~= mz
	then
		return false
	end
	local reach = half
	if type(reach) ~= "number" or reach ~= reach or reach < 0 then
		reach = CombatFeel.MARKER_HALF
	end
	return math.abs(px - mx) <= reach and math.abs(pz - mz) <= reach
end

return CombatFeel
