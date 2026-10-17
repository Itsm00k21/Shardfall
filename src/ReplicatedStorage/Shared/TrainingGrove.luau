--!strict

--[[
	Haven Training Grove. Pure rules.

	An optional corner of Haven: a dummy, a dodge course, and a
	boss-mechanics room with each telegraph color. Clearing it
	flags a small cosmetic. It does not block progress.

	This is not Practice Grove and not the Codex. It does not pay
	the grove_course quest's gold or keys.

	Frozen CONFIG:
	  dummyHits: 1
	  staysUp: the dummy stays up
	  window: the readout window, 10 seconds
	  colors: red, yellow, purple, blue
	  dodgeColor: red
	  cosmeticId: grove_ribbon
	  keys: 0
	  gold: 0

	hit counts one finite non-negative hit and adds its damage.
	heal adds healing and completes nothing. readout takes a
	caller-supplied elapsed time and returns damage, healing,
	dps, and hps for that window, with no reward. dodge completes
	only on red. color marks one of the four colors, and that
	room completes when all four are marked. clear sets the
	cosmetic flag only when the dummy, the dodge course, and the
	color room are all done. A later clear does not set it again.

	paid does not complete a station. A productId, robux, cost,
	or skip field grants nothing. This module does not take a
	user id or a guild id. Each call returns a new table and does
	not write the input. Store state only when ok == true. No
	clock. No RNG. Nothing here costs Robux.

	It stands alone. It does not load another module. Nothing in
	src loads this module.
]]

local TrainingGrove = {}

TrainingGrove.ERRORS = table.freeze({
	state = "That grove record is unusable.",
	hit = "That hit is unusable.",
	damage = "That damage amount is unusable.",
	heal = "That heal is unusable.",
	healing = "That healing amount is unusable.",
	readout = "That readout is unusable.",
	elapsed = "That elapsed time is unusable.",
	dodge = "That dodge is unusable.",
	color = "That color is unusable.",
	clear = "That clear is unusable.",
	paid = "A paid skip is refused.",
	id = "A user id or a guild id is refused.",
	rules = "The grove rules are unusable.",
})

TrainingGrove.CONFIG = table.freeze({
	dummyHits = 1,
	staysUp = true,
	window = 10,
	colors = table.freeze({ "red", "yellow", "purple", "blue" }),
	dodgeColor = "red",
	cosmeticId = "grove_ribbon",
	keys = 0,
	gold = 0,
})

export type Marks = {
	red: boolean,
	yellow: boolean,
	purple: boolean,
	blue: boolean,
}

export type State = {
	hits: number,
	damage: number,
	healing: number,
	up: boolean,
	dummy: boolean,
	dodge: boolean,
	colors: Marks,
	room: boolean,
	cosmetic: boolean,
}

export type Opened = {
	ok: boolean,
	state: State,
	error: string?,
}

export type Hit = {
	ok: boolean,
	state: State,
	hits: number,
	damage: number,
	counted: boolean,
	dummy: boolean,
	up: boolean,
	keys: number,
	gold: number,
	error: string?,
}

export type Healed = {
	ok: boolean,
	state: State,
	healing: number,
	dummy: boolean,
	dodge: boolean,
	room: boolean,
	cosmetic: boolean,
	up: boolean,
	keys: number,
	gold: number,
	error: string?,
}

export type Readout = {
	ok: boolean,
	state: State,
	damage: number,
	healing: number,
	dps: number,
	hps: number,
	elapsed: number?,
	window: number,
	keys: number,
	gold: number,
	error: string?,
}

export type Dodged = {
	ok: boolean,
	state: State,
	color: string?,
	dodge: boolean,
	completed: boolean,
	keys: number,
	gold: number,
	error: string?,
}

export type Marked = {
	ok: boolean,
	state: State,
	color: string?,
	marked: boolean,
	room: boolean,
	keys: number,
	gold: number,
	error: string?,
}

export type Cleared = {
	ok: boolean,
	state: State,
	ready: boolean,
	granted: boolean,
	cosmetic: boolean,
	cosmeticId: string?,
	keys: number,
	gold: number,
	error: string?,
}

local ERRORS = TrainingGrove.ERRORS
local CONFIG = TrainingGrove.CONFIG

local EXPECTED_COLORS = { "red", "yellow", "purple", "blue" }

local ID_FIELDS = { "userId", "UserId", "playerId", "PlayerId", "guildId", "GuildId" }

local STATE_KEYS: { [string]: boolean } = {
	hits = true,
	damage = true,
	healing = true,
	up = true,
	dummy = true,
	dodge = true,
	colors = true,
	room = true,
	cosmetic = true,
}

local COLOR_KEYS: { [string]: boolean } = {
	red = true,
	yellow = true,
	purple = true,
	blue = true,
}

local function nonNegative(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < 0 then
		return nil
	end
	return value
end

local function whole(value: any): number?
	local number = nonNegative(value)
	if number == nil or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function addCount(current: number): number?
	local nextCount = current + 1
	if nextCount ~= nextCount or nextCount == math.huge or nextCount == -math.huge then
		return nil
	end
	if nextCount <= current or nextCount ~= math.floor(nextCount) then
		return nil
	end
	return nextCount
end

local function addAmount(current: number, amount: number): number?
	local total = current + amount
	if total ~= total or total == math.huge or total == -math.huge then
		return nil
	end
	if total < 0 or total < current then
		return nil
	end
	return total
end

local function rates(damage: number, healing: number, elapsed: number): (number?, number?)
	if elapsed <= 0 then
		return 0, 0
	end
	local dealt = damage / elapsed
	local healed = healing / elapsed
	if dealt ~= dealt or dealt == math.huge or dealt == -math.huge then
		return nil, nil
	end
	if healed ~= healed or healed == math.huge or healed == -math.huge then
		return nil, nil
	end
	return dealt, healed
end

local function isColor(value: any): boolean
	return value == "red" or value == "yellow" or value == "purple" or value == "blue"
end

local function rulesOk(): string?
	if CONFIG.dummyHits ~= 1 or CONFIG.staysUp ~= true or CONFIG.window ~= 10 then
		return ERRORS.rules
	end
	if CONFIG.dodgeColor ~= "red" or CONFIG.cosmeticId ~= "grove_ribbon" then
		return ERRORS.rules
	end
	if CONFIG.keys ~= 0 or CONFIG.gold ~= 0 then
		return ERRORS.rules
	end
	local seenConfig = 0
	for key in pairs(CONFIG) do
		if
			key ~= "dummyHits"
			and key ~= "staysUp"
			and key ~= "window"
			and key ~= "colors"
			and key ~= "dodgeColor"
			and key ~= "cosmeticId"
			and key ~= "keys"
			and key ~= "gold"
		then
			return ERRORS.rules
		end
		seenConfig += 1
	end
	if seenConfig ~= 8 then
		return ERRORS.rules
	end
	local colors = CONFIG.colors
	if type(colors) ~= "table" or #colors ~= 4 then
		return ERRORS.rules
	end
	local seenColor: { [string]: boolean } = {}
	for index, id in ipairs(colors) do
		if id ~= EXPECTED_COLORS[index] or seenColor[id] == true then
			return ERRORS.rules
		end
		seenColor[id] = true
	end
	if seenColor[CONFIG.dodgeColor] ~= true then
		return ERRORS.rules
	end
	return nil
end

local function blankColors(): Marks
	return {
		red = false,
		yellow = false,
		purple = false,
		blue = false,
	}
end

local function copyColors(colors: Marks): Marks
	return {
		red = colors.red,
		yellow = colors.yellow,
		purple = colors.purple,
		blue = colors.blue,
	}
end

local function roomDone(colors: Marks): boolean
	return colors.red == true
		and colors.yellow == true
		and colors.purple == true
		and colors.blue == true
end

local function blankState(): State
	return {
		hits = 0,
		damage = 0,
		healing = 0,
		up = true,
		dummy = false,
		dodge = false,
		colors = blankColors(),
		room = false,
		cosmetic = false,
	}
end

local function copyState(state: State): State
	return {
		hits = state.hits,
		damage = state.damage,
		healing = state.healing,
		up = state.up,
		dummy = state.dummy,
		dodge = state.dodge,
		colors = copyColors(state.colors),
		room = state.room,
		cosmetic = state.cosmetic,
	}
end

local function readyOf(state: State): boolean
	return state.dummy == true and state.dodge == true and state.room == true
end

local function kept(current: State?): State
	if current == nil then
		return blankState()
	end
	return copyState(current)
end

local function foreign(
	value: { [any]: any },
	allowPaid: boolean,
	allow: { [string]: boolean },
	shapeErr: string
): string?
	for _, key in ipairs(ID_FIELDS) do
		if value[key] ~= nil then
			return ERRORS.id
		end
	end
	if value.productId ~= nil or value.robux ~= nil or value.cost ~= nil or value.skip ~= nil then
		return ERRORS.paid
	end
	for key in pairs(value) do
		local allowed = type(key) == "string"
			and (allow[key] == true or (allowPaid and key == "paid"))
		if not allowed then
			return shapeErr
		end
	end
	return nil
end

local function paidType(value: { [any]: any }, shapeErr: string): string?
	if value.paid ~= nil and type(value.paid) ~= "boolean" then
		return shapeErr
	end
	return nil
end

local function refusal(left: string?, right: string?): string?
	if left == ERRORS.id or right == ERRORS.id then
		return ERRORS.id
	end
	if left == ERRORS.paid or right == ERRORS.paid then
		return ERRORS.paid
	end
	return nil
end

local function readColors(value: any): (Marks?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local problem = foreign(value, false, COLOR_KEYS, ERRORS.state)
	if problem ~= nil then
		return nil, problem
	end
	if
		type(value.red) ~= "boolean"
		or type(value.yellow) ~= "boolean"
		or type(value.purple) ~= "boolean"
		or type(value.blue) ~= "boolean"
	then
		return nil, ERRORS.state
	end
	return {
		red = value.red,
		yellow = value.yellow,
		purple = value.purple,
		blue = value.blue,
	},
		nil
end

local function consistent(state: State): boolean
	if state.up ~= true then
		return false
	end
	if state.dummy ~= (state.hits >= CONFIG.dummyHits) then
		return false
	end
	if state.room ~= roomDone(state.colors) then
		return false
	end
	if state.cosmetic == true and readyOf(state) ~= true then
		return false
	end
	return true
end

local function readState(value: any): (State?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local problem = foreign(value, false, STATE_KEYS, ERRORS.state)
	if problem ~= nil then
		return nil, problem
	end
	local hits = whole(value.hits)
	local damage = nonNegative(value.damage)
	local healing = nonNegative(value.healing)
	if hits == nil or damage == nil or healing == nil then
		return nil, ERRORS.state
	end
	if
		type(value.up) ~= "boolean"
		or type(value.dummy) ~= "boolean"
		or type(value.dodge) ~= "boolean"
		or type(value.room) ~= "boolean"
		or type(value.cosmetic) ~= "boolean"
	then
		return nil, ERRORS.state
	end
	local colors, colorErr = readColors(value.colors)
	if colors == nil then
		return nil, colorErr or ERRORS.state
	end
	local state: State = {
		hits = hits,
		damage = damage,
		healing = healing,
		up = value.up,
		dummy = value.dummy,
		dodge = value.dodge,
		colors = colors,
		room = value.room,
		cosmetic = value.cosmetic,
	}
	if not consistent(state) then
		return nil, ERRORS.state
	end
	return state, nil
end

local function readHit(value: any): (number?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.hit
	end
	local problem = foreign(value, true, { damage = true }, ERRORS.hit)
	if problem ~= nil then
		return nil, problem
	end
	local typed = paidType(value, ERRORS.hit)
	if typed ~= nil then
		return nil, typed
	end
	local amount = nonNegative(value.damage)
	if amount == nil then
		return nil, ERRORS.damage
	end
	return amount, nil
end

local function readHeal(value: any): (number?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.heal
	end
	local problem = foreign(value, true, { healing = true }, ERRORS.heal)
	if problem ~= nil then
		return nil, problem
	end
	local typed = paidType(value, ERRORS.heal)
	if typed ~= nil then
		return nil, typed
	end
	local amount = nonNegative(value.healing)
	if amount == nil then
		return nil, ERRORS.healing
	end
	return amount, nil
end

local function readElapsed(value: any): (number?, string?)
	if type(value) == "number" then
		local elapsed = nonNegative(value)
		if elapsed == nil then
			return nil, ERRORS.elapsed
		end
		return elapsed, nil
	end
	if type(value) ~= "table" then
		return nil, ERRORS.readout
	end
	local problem = foreign(value, true, { elapsed = true }, ERRORS.readout)
	if problem ~= nil then
		return nil, problem
	end
	local typed = paidType(value, ERRORS.readout)
	if typed ~= nil then
		return nil, typed
	end
	local elapsed = nonNegative(value.elapsed)
	if elapsed == nil then
		return nil, ERRORS.elapsed
	end
	return elapsed, nil
end

local function readColor(value: any, shapeErr: string): (string?, string?)
	if type(value) == "string" then
		if not isColor(value) then
			return nil, ERRORS.color
		end
		return value, nil
	end
	if type(value) ~= "table" then
		return nil, shapeErr
	end
	local problem = foreign(value, true, { color = true }, shapeErr)
	if problem ~= nil then
		return nil, problem
	end
	local typed = paidType(value, shapeErr)
	if typed ~= nil then
		return nil, typed
	end
	if type(value.color) ~= "string" then
		return nil, shapeErr
	end
	if not isColor(value.color) then
		return nil, ERRORS.color
	end
	return value.color, nil
end

local function readClear(value: any): string?
	if value == nil then
		return nil
	end
	if type(value) ~= "table" then
		return ERRORS.clear
	end
	local problem = foreign(value, true, {}, ERRORS.clear)
	if problem ~= nil then
		return problem
	end
	return paidType(value, ERRORS.clear)
end

local function withHit(state: State, amount: number): State?
	local hits = addCount(state.hits)
	local damage = addAmount(state.damage, amount)
	if hits == nil or damage == nil then
		return nil
	end
	local nextState = copyState(state)
	nextState.hits = hits
	nextState.damage = damage
	nextState.dummy = hits >= CONFIG.dummyHits
	nextState.up = true
	return nextState
end

local function withHeal(state: State, amount: number): State?
	local healing = addAmount(state.healing, amount)
	if healing == nil then
		return nil
	end
	local nextState = copyState(state)
	nextState.healing = healing
	nextState.up = true
	return nextState
end

local function paint(colors: Marks, color: string): (Marks, boolean)
	local nextColors = copyColors(colors)
	local marked = false
	if color == "red" then
		marked = colors.red == false
		nextColors.red = true
	elseif color == "yellow" then
		marked = colors.yellow == false
		nextColors.yellow = true
	elseif color == "purple" then
		marked = colors.purple == false
		nextColors.purple = true
	elseif color == "blue" then
		marked = colors.blue == false
		nextColors.blue = true
	end
	return nextColors, marked
end

local function withDodge(state: State, color: string): (State, boolean)
	local nextState = copyState(state)
	local completed = false
	if color == CONFIG.dodgeColor and state.dodge == false then
		nextState.dodge = true
		completed = true
	end
	nextState.up = true
	return nextState, completed
end

local function withColor(state: State, color: string): (State, boolean)
	local nextColors, marked = paint(state.colors, color)
	local nextState = copyState(state)
	nextState.colors = nextColors
	nextState.room = roomDone(nextColors)
	nextState.up = true
	return nextState, marked
end

local function withClear(state: State): (State, boolean)
	local nextState = copyState(state)
	local granted = readyOf(state) == true and state.cosmetic == false
	if granted then
		nextState.cosmetic = true
	end
	nextState.up = true
	return nextState, granted
end

local function failHit(state: State, err: string): Hit
	return {
		ok = false,
		state = state,
		hits = state.hits,
		damage = state.damage,
		counted = false,
		dummy = state.dummy,
		up = state.up,
		keys = 0,
		gold = 0,
		error = err,
	}
end

local function failHeal(state: State, err: string): Healed
	return {
		ok = false,
		state = state,
		healing = state.healing,
		dummy = state.dummy,
		dodge = state.dodge,
		room = state.room,
		cosmetic = state.cosmetic,
		up = state.up,
		keys = 0,
		gold = 0,
		error = err,
	}
end

local function failReadout(state: State, err: string): Readout
	return {
		ok = false,
		state = state,
		damage = state.damage,
		healing = state.healing,
		dps = 0,
		hps = 0,
		window = CONFIG.window,
		keys = 0,
		gold = 0,
		error = err,
	}
end

local function failDodge(state: State, err: string): Dodged
	return {
		ok = false,
		state = state,
		dodge = state.dodge,
		completed = false,
		keys = 0,
		gold = 0,
		error = err,
	}
end

local function failColor(state: State, err: string): Marked
	return {
		ok = false,
		state = state,
		marked = false,
		room = state.room,
		keys = 0,
		gold = 0,
		error = err,
	}
end

local function failClear(state: State, err: string): Cleared
	return {
		ok = false,
		state = state,
		ready = readyOf(state),
		granted = false,
		cosmetic = state.cosmetic,
		keys = 0,
		gold = 0,
		error = err,
	}
end

function TrainingGrove.fresh(options: any): Opened
	local broken = rulesOk()
	if broken ~= nil then
		return {
			ok = false,
			state = blankState(),
			error = broken,
		}
	end
	if options == nil then
		return {
			ok = true,
			state = blankState(),
		}
	end
	if type(options) ~= "table" then
		return {
			ok = false,
			state = blankState(),
			error = ERRORS.state,
		}
	end
	local problem = foreign(options, false, {}, ERRORS.state)
	if problem ~= nil then
		return {
			ok = false,
			state = blankState(),
			error = problem,
		}
	end
	return {
		ok = true,
		state = blankState(),
	}
end

function TrainingGrove.hit(state: any, hit: any): Hit
	local broken = rulesOk()
	if broken ~= nil then
		return failHit(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local amount, hitErr = readHit(hit)
	local refused = refusal(stateErr, hitErr)
	if refused ~= nil then
		return failHit(kept(current), refused)
	end
	if current == nil then
		return failHit(blankState(), stateErr or ERRORS.state)
	end
	if amount == nil then
		return failHit(copyState(current), hitErr or ERRORS.hit)
	end
	local nextState = withHit(current, amount)
	if nextState == nil then
		return failHit(copyState(current), ERRORS.damage)
	end
	return {
		ok = true,
		state = nextState,
		hits = nextState.hits,
		damage = nextState.damage,
		counted = true,
		dummy = nextState.dummy,
		up = nextState.up,
		keys = CONFIG.keys,
		gold = CONFIG.gold,
	}
end

function TrainingGrove.heal(state: any, heal: any): Healed
	local broken = rulesOk()
	if broken ~= nil then
		return failHeal(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local amount, healErr = readHeal(heal)
	local refused = refusal(stateErr, healErr)
	if refused ~= nil then
		return failHeal(kept(current), refused)
	end
	if current == nil then
		return failHeal(blankState(), stateErr or ERRORS.state)
	end
	if amount == nil then
		return failHeal(copyState(current), healErr or ERRORS.heal)
	end
	local nextState = withHeal(current, amount)
	if nextState == nil then
		return failHeal(copyState(current), ERRORS.healing)
	end
	return {
		ok = true,
		state = nextState,
		healing = nextState.healing,
		dummy = nextState.dummy,
		dodge = nextState.dodge,
		room = nextState.room,
		cosmetic = nextState.cosmetic,
		up = nextState.up,
		keys = CONFIG.keys,
		gold = CONFIG.gold,
	}
end

function TrainingGrove.readout(state: any, elapsed: any): Readout
	local broken = rulesOk()
	if broken ~= nil then
		return failReadout(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local span, elapsedErr = readElapsed(elapsed)
	local refused = refusal(stateErr, elapsedErr)
	if refused ~= nil then
		return failReadout(kept(current), refused)
	end
	if current == nil then
		return failReadout(blankState(), stateErr or ERRORS.state)
	end
	if span == nil then
		return failReadout(copyState(current), elapsedErr or ERRORS.readout)
	end
	local dealt, healed = rates(current.damage, current.healing, span)
	if dealt == nil or healed == nil then
		return failReadout(copyState(current), ERRORS.elapsed)
	end
	return {
		ok = true,
		state = copyState(current),
		damage = current.damage,
		healing = current.healing,
		dps = dealt,
		hps = healed,
		elapsed = span,
		window = CONFIG.window,
		keys = CONFIG.keys,
		gold = CONFIG.gold,
	}
end

function TrainingGrove.dodge(state: any, request: any): Dodged
	local broken = rulesOk()
	if broken ~= nil then
		return failDodge(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local color, requestErr = readColor(request, ERRORS.dodge)
	local refused = refusal(stateErr, requestErr)
	if refused ~= nil then
		return failDodge(kept(current), refused)
	end
	if current == nil then
		return failDodge(blankState(), stateErr or ERRORS.state)
	end
	if color == nil then
		return failDodge(copyState(current), requestErr or ERRORS.dodge)
	end
	local nextState, completed = withDodge(current, color)
	return {
		ok = true,
		state = nextState,
		color = color,
		dodge = nextState.dodge,
		completed = completed,
		keys = CONFIG.keys,
		gold = CONFIG.gold,
	}
end

function TrainingGrove.color(state: any, request: any): Marked
	local broken = rulesOk()
	if broken ~= nil then
		return failColor(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local color, requestErr = readColor(request, ERRORS.color)
	local refused = refusal(stateErr, requestErr)
	if refused ~= nil then
		return failColor(kept(current), refused)
	end
	if current == nil then
		return failColor(blankState(), stateErr or ERRORS.state)
	end
	if color == nil then
		return failColor(copyState(current), requestErr or ERRORS.color)
	end
	local nextState, marked = withColor(current, color)
	return {
		ok = true,
		state = nextState,
		color = color,
		marked = marked,
		room = nextState.room,
		keys = CONFIG.keys,
		gold = CONFIG.gold,
	}
end

function TrainingGrove.clear(state: any, request: any): Cleared
	local broken = rulesOk()
	if broken ~= nil then
		return failClear(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local requestErr = readClear(request)
	local refused = refusal(stateErr, requestErr)
	if refused ~= nil then
		return failClear(kept(current), refused)
	end
	if current == nil then
		return failClear(blankState(), stateErr or ERRORS.state)
	end
	if requestErr ~= nil then
		return failClear(copyState(current), requestErr)
	end
	local nextState, granted = withClear(current)
	local cosmeticId = nil
	if granted then
		cosmeticId = CONFIG.cosmeticId
	end
	return {
		ok = true,
		state = nextState,
		ready = readyOf(nextState),
		granted = granted,
		cosmetic = nextState.cosmetic,
		cosmeticId = cosmeticId,
		keys = CONFIG.keys,
		gold = CONFIG.gold,
	}
end

return TrainingGrove
