--!strict

--[[
	T3 first-session guide. Config and the grant rules.

	LaunchGate.firstSessionGuide ships false. While it is off, free rolls,
	the pad, and Replay leave the profile alone. Skip still pays the saved
	step's token count once, so a rollback cannot zero that debt or pay it
	twice.

	R1. Unused free rolls become Shard Tokens once, from the saved step
	(open = 3, roll1 = 3, roll2 = 2, roll3 = 1, anything else = 0), and
	only while onboardDone is still false. The flag does not change that
	count.
	R2. claimFree spends the free roll and moves onboardStep together.
	A roll step does not move through note().
	R3. Free or not is read from onboardDone and onboardStep. There is
	no client tutorial, replay, or freeCount argument.
	R4. The Rare floor is only the roll that leaves roll3. That roll
	closes firstSession.granted.roll so the kit does not floor a second one.
	R5. The kit still waits for a class. This module does not mint it.
]]

local FirstSessionKit = require("./FirstSessionKit")
local LaunchGate = require("./LaunchGate")
local Rarities = require("./Rarities")
local WaveArenaConfig = require("./Config/WaveArenaConfig")

local SessionGuide = {}

-- One source for the three free cracks. open and roll1 owe all of them.
-- roll2 and roll3 owe what is left. check() still locks freeRolls at 3.
local FREE_ROLLS = 3

local TOKEN_COUNT: { [string]: number } = {
	open = FREE_ROLLS,
	roll1 = FREE_ROLLS,
	roll2 = FREE_ROLLS - 1,
	roll3 = FREE_ROLLS - 2,
}

SessionGuide.PAD_RADIUS = 6
SessionGuide.PAD_HEIGHT = 12
SessionGuide.PAD_HZ = 5
SessionGuide.FREE_ROLL_NOTICE = "use your free roll"

SessionGuide.TIMING = table.freeze({
	pointer = 4,
	repeatIdle = 9,
	edge = 6,
	takeMe = 30,
	freeRolls = FREE_ROLLS,
})

local STEPS = table.freeze({
	table.freeze({
		id = "open",
		text = "Crack your first shard.",
		hint = "",
		short = "Welcome",
		tokens = TOKEN_COUNT.open,
		free = false,
	}),
	table.freeze({
		id = "roll1",
		text = "Crack your first shard. Tap ROLL below.",
		desktop = "Click ROLL or press R.",
		hint = "Crack shard 1",
		short = "Crack a shard",
		continueHint = "Tap ROLL at the bottom. Or press Skip intro.",
		tokens = TOKEN_COUNT.roll1,
		free = true,
	}),
	table.freeze({
		id = "roll2",
		text = "Nice! Two more free shards.",
		hint = "Crack shard 2",
		short = "2 free shards left",
		continueHint = "Tap ROLL at the bottom. Or press Skip intro.",
		tokens = TOKEN_COUNT.roll2,
		free = true,
	}),
	table.freeze({
		id = "roll3",
		text = "Last free shard. Make it count!",
		hint = "Crack shard 3",
		short = "Last free shard",
		continueHint = "Tap ROLL at the bottom. Or press Skip intro.",
		tokens = TOKEN_COUNT.roll3,
		free = true,
		floor = "Rare",
	}),
	table.freeze({
		id = "gate",
		text = "A Rare! Now test it at the Shard Gate.",
		epic = "An Epic! Now test it at the Shard Gate.",
		legendary = "A Legendary! Now test it at the Shard Gate.",
		hint = "Step on the Gate",
		short = "Follow the arrow",
		continueHint = "Follow the arrow to the Gate. Or press Skip intro.",
		idle = "Follow the arrow to the Gate.",
		tokens = 0,
		free = false,
	}),
	table.freeze({
		id = "wave1",
		text = "Step in. Smash the shardlings!",
		hint = "Clear wave 1",
		short = "Clear wave 1",
		continueHint = "Clear wave 1 in the arena.",
		tokens = 0,
		free = false,
	}),
})

local ORDER = { "open", "roll1", "roll2", "roll3", "gate", "wave1" }
local LOG_CAP = 32
local log: { { name: string, detail: string } } = {}

export type Claim = {
	free: boolean,
	stepId: string,
	floor: string?,
}

local function enabled(): boolean
	return LaunchGate.on("firstSessionGuide")
end

local function find(id: any): any
	if type(id) ~= "string" then
		return nil
	end
	for _, row in ipairs(STEPS) do
		if row.id == id then
			return row
		end
	end
	return nil
end

local function nextId(id: string): string?
	for index, row in ipairs(STEPS) do
		if row.id == id then
			local following = STEPS[index + 1]
			if following == nil then
				return nil
			end
			return following.id
		end
	end
	return nil
end

local function record(name: string, detail: string)
	if #log >= LOG_CAP then
		table.remove(log, 1)
	end
	table.insert(log, { name = name, detail = detail })
end

function SessionGuide.steps()
	return STEPS
end

function SessionGuide.known(id: any): boolean
	return find(id) ~= nil
end

function SessionGuide.short(id: any): string?
	local row = find(id)
	if row == nil or type(row.short) ~= "string" or row.short == "" then
		return nil
	end
	return row.short
end

function SessionGuide.freeStep(id: any): boolean
	if not enabled() then
		return false
	end
	local row = find(id)
	return row ~= nil and row.free == true
end

-- Tokens still owed for unused free rolls. 0 once the guide is finished
-- or the saved step owes none. The flag does not change the count, so a
-- rollback still pays the saved step and a second skip pays 0.
function SessionGuide.unusedRollTokens(data: any): number
	if type(data) ~= "table" or data.onboardDone == true then
		return 0
	end
	local row = find(data.onboardStep)
	if row == nil or type(row.tokens) ~= "number" then
		return 0
	end
	return row.tokens
end

-- The x10 press during roll1, roll2, or roll3. Nil when the guide is off,
-- finished, or on any other step. The string is the roll result the client
-- already shows.
function SessionGuide.batchNotice(data: any): string?
	if not enabled() or type(data) ~= "table" or data.onboardDone == true then
		return nil
	end
	local row = find(data.onboardStep)
	if row == nil or row.free ~= true then
		return nil
	end
	return SessionGuide.FREE_ROLL_NOTICE
end

-- Pays `count` only when it is exactly the saved step's unused rolls
-- and the guide is still open. A second call sees onboardDone or a
-- count that no longer matches, and pays 0. The flag is not a gate.
function SessionGuide.grantTokens(data: any, count: any): number
	if type(data) ~= "table" or data.onboardDone == true then
		return 0
	end
	local owed = SessionGuide.unusedRollTokens(data)
	if type(count) ~= "number" or count ~= owed or owed <= 0 then
		return 0
	end
	data.shardTokens = (data.shardTokens or 0) + owed
	return owed
end

local function closeRollGoal(data: any)
	local recordState = FirstSessionKit.normalize(data.firstSession)
	recordState.granted.roll = true
	data.firstSession = recordState
end

-- One free roll for the saved step, and the step moves before this
-- returns. The caller grants the item in the same mutate. No argument
-- here can ask for a free roll.
function SessionGuide.claimFree(data: any): Claim?
	if not enabled() or type(data) ~= "table" or data.onboardDone == true then
		return nil
	end
	local row = find(data.onboardStep)
	if row == nil or row.free ~= true then
		return nil
	end
	local following = nextId(row.id)
	if following == nil then
		return nil
	end
	local floorName = if type(row.floor) == "string" then row.floor else nil
	data.onboardStep = following
	if floorName ~= nil then
		closeRollGoal(data)
	end
	record("roll", row.id)
	return {
		free = true,
		stepId = row.id,
		floor = floorName,
	}
end

-- Raise only. A roll that is already at the floor, or above it, stays.
function SessionGuide.floorRarity(rarity: any, floorName: any): string
	if type(rarity) ~= "string" or Rarities.INDEX[rarity] == nil then
		return if type(rarity) == "string" then rarity else "Common"
	end
	if type(floorName) ~= "string" or Rarities.INDEX[floorName] == nil then
		return rarity
	end
	if Rarities.rank(rarity) >= Rarities.rank(floorName) then
		return rarity
	end
	return floorName
end

function SessionGuide.padHit(x: any, y: any, z: any): boolean
	if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return false
	end
	local pad = WaveArenaConfig.hubPad.position
	local dx = x - pad.x
	local dz = z - pad.z
	local radius = SessionGuide.PAD_RADIUS
	if dx * dx + dz * dz > radius * radius then
		return false
	end
	if type(y) ~= "number" or y ~= y then
		return true
	end
	local dy = y - pad.y
	if dy < 0 then
		dy = -dy
	end
	return dy <= SessionGuide.PAD_HEIGHT
end

-- Gate-pad clock. One check per call, about PAD_HZ times a second.
-- A short frame returns false and keeps the leftover. A long frame
-- still checks once.
function SessionGuide.padClock(carried: any, dt: any): (number, boolean)
	local rate = SessionGuide.PAD_HZ
	if type(rate) ~= "number" or rate ~= rate or rate <= 0 or rate == math.huge then
		return 0, false
	end
	local interval = 1 / rate
	local clock = 0
	if type(carried) == "number" and carried == carried and carried >= 0 and carried < math.huge then
		clock = carried
	end
	if type(dt) == "number" and dt == dt and dt > 0 and dt < math.huge then
		clock += dt
	end
	if clock + 1e-6 < interval then
		return clock, false
	end
	clock -= interval
	if clock < 0 then
		clock = 0
	end
	if clock + 1e-6 >= interval then
		clock = clock % interval
	end
	return clock, true
end

-- Server pad check. Moves gate to wave1 only. No reward.
function SessionGuide.advancePad(data: any, x: any, y: any, z: any): boolean
	if not enabled() or type(data) ~= "table" or data.onboardDone == true then
		return false
	end
	if data.onboardStep ~= "gate" then
		return false
	end
	if not SessionGuide.padHit(x, y, z) then
		return false
	end
	data.onboardStep = "wave1"
	record("gate", "pad")
	return true
end

-- Replay points. It does not grant, and it does not write the profile.
function SessionGuide.replay(_data: any): boolean
	return false
end

function SessionGuide.record(name: string, detail: string)
	if type(name) ~= "string" or type(detail) ~= "string" then
		return
	end
	record(name, detail)
end

function SessionGuide.trace(): { { name: string, detail: string } }
	local copy = {}
	for _, row in ipairs(log) do
		table.insert(copy, { name = row.name, detail = row.detail })
	end
	return copy
end

local function dirty(value: any, depth: number): boolean
	if depth > 6 or type(value) ~= "table" then
		return false
	end
	for key, child in pairs(value) do
		if key == "productId" or key == "robux" or key == "Robux" then
			return true
		end
		if dirty(child, depth + 1) then
			return true
		end
	end
	return false
end

local function textOf(row: any, key: string): boolean
	return type(row[key]) == "string" and row[key] ~= ""
end

function SessionGuide.check(definition: any): (boolean, string?)
	if type(definition) ~= "table" or type(definition.steps) ~= "table" then
		return false, "steps"
	end
	if type(definition.timing) ~= "table" then
		return false, "timing"
	end
	local timing = definition.timing
	if timing.pointer ~= 4 or timing.repeatIdle ~= 9 or timing.edge ~= 6 then
		return false, "timing"
	end
	if timing.takeMe ~= 30 or timing.freeRolls ~= 3 then
		return false, "timing"
	end
	if dirty(definition, 0) then
		return false, "robux"
	end
	local steps = definition.steps
	if #steps ~= #ORDER then
		return false, "length"
	end
	local seen: { [string]: boolean } = {}
	local floors = 0
	local freeRolls = 0
	for index, row in ipairs(steps) do
		if type(row) ~= "table" or row.id ~= ORDER[index] then
			return false, "order"
		end
		if seen[row.id] == true then
			return false, "duplicate"
		end
		seen[row.id] = true
		if not textOf(row, "text") or type(row.short) ~= "string" or row.short == "" then
			return false, "copy"
		end
		if row.id == "open" then
			if row.hint ~= "" then
				return false, "open"
			end
		elseif type(row.hint) ~= "string" or row.hint == "" then
			return false, "hint"
		end
		local owed = TOKEN_COUNT[row.id] or 0
		if row.tokens ~= owed then
			return false, "tokens"
		end
		local free = row.id == "roll1" or row.id == "roll2" or row.id == "roll3"
		if row.free ~= free then
			return false, "free"
		end
		if free then
			freeRolls += 1
			if not textOf(row, "continueHint") then
				return false, "continue"
			end
		end
		if row.id == "roll1" and row.desktop ~= "Click ROLL or press R." then
			return false, "desktop"
		end
		if row.id == "roll3" then
			if row.floor ~= "Rare" then
				return false, "floor"
			end
			floors += 1
		elseif row.floor ~= nil then
			return false, "floor"
		end
		if row.id == "gate" then
			if row.epic ~= "An Epic! Now test it at the Shard Gate." then
				return false, "gate"
			end
			if row.legendary ~= "A Legendary! Now test it at the Shard Gate." then
				return false, "gate"
			end
			if row.idle ~= "Follow the arrow to the Gate." then
				return false, "gate"
			end
		end
		if row.id == "wave1" and not textOf(row, "continueHint") then
			return false, "continue"
		end
	end
	if freeRolls ~= 3 or floors ~= 1 then
		return false, "count"
	end
	if steps[1].id ~= "open" then
		return false, "open"
	end
	return true, nil
end

function SessionGuide.validate(): (boolean, string?)
	local ok, err = SessionGuide.check({
		steps = STEPS,
		timing = SessionGuide.TIMING,
	})
	if not ok then
		return false, err
	end
	local pad = WaveArenaConfig.hubPad
	if type(pad) ~= "table" or type(pad.position) ~= "table" then
		return false, "pad"
	end
	if type(pad.position.x) ~= "number" or type(pad.position.z) ~= "number" then
		return false, "pad"
	end
	if SessionGuide.PAD_RADIUS <= 0 or SessionGuide.PAD_HEIGHT <= 0 then
		return false, "pad"
	end
	if SessionGuide.PAD_HZ ~= 5 then
		return false, "rate"
	end
	if SessionGuide.FREE_ROLL_NOTICE ~= "use your free roll" then
		return false, "notice"
	end
	return true, nil
end

return SessionGuide
