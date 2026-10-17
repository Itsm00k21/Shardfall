--!strict

--[[
	Starter goals after the first five minutes. Pure rules.

	Five one-time goals, in this order:
	  forge: Craft your first item at the Forge (1)
	  rootvault: Clear Rootvault (1)
	  rolls: Roll 10 shards (10)
	  level: Reach Lv 5 (5)
	  guild: Join or browse a guild (1)

	The tracker shows three at a time: the first three not yet
	granted, in that order. Granting one reveals the next. A goal
	that is still hidden does not pay, even if its count is already
	met. One call grants one goal. It does not grant the goal that
	just became visible.

	Each grant pays the same Shard Key amount. A goal already
	granted pays nothing again. A returning player gets nothing.
	There is no paid skip. paid does not raise the key amount.

	The caller passes the progress counts. The guild flag is a
	boolean the server already decided. This module does not take
	a user id or a guild id. Each call returns a new table and does
	not write the input. No clock. No RNG. Nothing here costs Robux.

	It stands alone. It does not load another module. Nothing in
	src loads this module.
]]

local StarterGoals = {}

StarterGoals.ERRORS = table.freeze({
	state = "That starter-goal record is unusable.",
	progress = "That progress is unusable.",
	goal = "That goal is not a starter goal.",
	paid = "A paid skip is refused.",
	id = "A user id or a guild id is refused.",
	rules = "The starter-goal rules are unusable.",
})

StarterGoals.CONFIG = table.freeze({
	visible = 3,
	shardKeys = 10,
	currency = "shardKeys",
})

local function goalRow(id: string, text: string, goal: number)
	return table.freeze({
		id = id,
		text = text,
		goal = goal,
	})
end

StarterGoals.GOALS = table.freeze({
	goalRow("forge", "Craft your first item at the Forge", 1),
	goalRow("rootvault", "Clear Rootvault", 1),
	goalRow("rolls", "Roll 10 shards", 10),
	goalRow("level", "Reach Lv 5", 5),
	goalRow("guild", "Join or browse a guild", 1),
})

local order: { string } = {}
for _, goal in ipairs(StarterGoals.GOALS) do
	table.insert(order, goal.id)
end
StarterGoals.ORDER = table.freeze(order)

export type GoalRow = {
	id: string,
	text: string,
	goal: number,
}

export type Granted = {
	forge: boolean,
	rootvault: boolean,
	rolls: boolean,
	level: boolean,
	guild: boolean,
}

export type State = {
	returning: boolean,
	granted: Granted,
}

export type Opened = {
	ok: boolean,
	state: State,
	error: string?,
}

export type GoalView = {
	id: string,
	text: string,
	goal: number,
	progress: number,
	met: boolean,
}

export type Shown = {
	ok: boolean,
	state: State,
	goals: { GoalView },
	error: string?,
}

export type Payout = {
	currency: string,
	amount: number,
	goal: string,
}

export type Grant = {
	ok: boolean,
	state: State,
	goal: string?,
	accepted: boolean,
	keys: number,
	met: boolean,
	visible: boolean,
	goals: { GoalView },
	payout: Payout?,
	error: string?,
}

type Counts = {
	forge: number,
	rootvault: number,
	rolls: number,
	level: number,
	guild: boolean,
}

local ERRORS = StarterGoals.ERRORS
local CONFIG = StarterGoals.CONFIG

local EXPECTED_GOAL = { 1, 1, 10, 5, 1 }
local EXPECTED_TEXT = {
	"Craft your first item at the Forge",
	"Clear Rootvault",
	"Roll 10 shards",
	"Reach Lv 5",
	"Join or browse a guild",
}

local ID_KEYS: { [string]: boolean } = {
	userId = true,
	UserId = true,
	guildId = true,
	GuildId = true,
	playerId = true,
	PlayerId = true,
}

local SKIP_KEYS: { [string]: boolean } = {
	productId = true,
	robux = true,
	cost = true,
	skip = true,
}

local COUNT_KEYS: { [string]: boolean } = {
	forge = true,
	rootvault = true,
	rolls = true,
	level = true,
	guild = true,
	paid = true,
}

local function whole(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < 0 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function rulesOk(): string?
	if CONFIG.visible ~= 3 or CONFIG.shardKeys ~= 10 or CONFIG.currency ~= "shardKeys" then
		return ERRORS.rules
	end
	local seenConfig = 0
	for key in pairs(CONFIG) do
		if key ~= "visible" and key ~= "shardKeys" and key ~= "currency" then
			return ERRORS.rules
		end
		seenConfig += 1
	end
	if seenConfig ~= 3 then
		return ERRORS.rules
	end
	if #StarterGoals.ORDER ~= 5 or #StarterGoals.GOALS ~= 5 then
		return ERRORS.rules
	end
	local seenId: { [string]: boolean } = {}
	for index, id in ipairs(StarterGoals.ORDER) do
		local goal = StarterGoals.GOALS[index]
		if type(id) ~= "string" or goal == nil or goal.id ~= id or seenId[id] == true then
			return ERRORS.rules
		end
		if goal.text ~= EXPECTED_TEXT[index] or goal.goal ~= EXPECTED_GOAL[index] then
			return ERRORS.rules
		end
		seenId[id] = true
	end
	return nil
end

local function blankGranted(): Granted
	return {
		forge = false,
		rootvault = false,
		rolls = false,
		level = false,
		guild = false,
	}
end

local function blankState(): State
	return {
		returning = false,
		granted = blankGranted(),
	}
end

local function copyGranted(granted: Granted): Granted
	return {
		forge = granted.forge,
		rootvault = granted.rootvault,
		rolls = granted.rolls,
		level = granted.level,
		guild = granted.guild,
	}
end

local function copyState(state: State): State
	return {
		returning = state.returning,
		granted = copyGranted(state.granted),
	}
end

local function readGranted(value: any): (Granted?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	if type(value.forge) ~= "boolean" or type(value.rootvault) ~= "boolean" then
		return nil, ERRORS.state
	end
	if type(value.rolls) ~= "boolean" or type(value.level) ~= "boolean" then
		return nil, ERRORS.state
	end
	if type(value.guild) ~= "boolean" then
		return nil, ERRORS.state
	end
	local seen = 0
	for key in pairs(value) do
		if
			key ~= "forge"
			and key ~= "rootvault"
			and key ~= "rolls"
			and key ~= "level"
			and key ~= "guild"
		then
			return nil, ERRORS.state
		end
		seen += 1
	end
	if seen ~= 5 then
		return nil, ERRORS.state
	end
	return {
		forge = value.forge,
		rootvault = value.rootvault,
		rolls = value.rolls,
		level = value.level,
		guild = value.guild,
	},
		nil
end

local function readState(value: any): (State?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	if type(value.returning) ~= "boolean" then
		return nil, ERRORS.state
	end
	local seen = 0
	for key in pairs(value) do
		if key ~= "returning" and key ~= "granted" then
			return nil, ERRORS.state
		end
		seen += 1
	end
	if seen ~= 2 then
		return nil, ERRORS.state
	end
	local granted, grantedErr = readGranted(value.granted)
	if granted == nil then
		return nil, grantedErr or ERRORS.state
	end
	return {
		returning = value.returning,
		granted = granted,
	}, nil
end

local function readCounts(value: any): (Counts?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.progress
	end
	local paidSkip = false
	for key in pairs(value) do
		if type(key) ~= "string" then
			return nil, ERRORS.progress
		end
		if ID_KEYS[key] == true then
			return nil, ERRORS.id
		end
		if SKIP_KEYS[key] == true then
			paidSkip = true
		elseif COUNT_KEYS[key] ~= true then
			return nil, ERRORS.progress
		end
	end
	if paidSkip then
		return nil, ERRORS.paid
	end
	local forge = whole(value.forge)
	local rootvault = whole(value.rootvault)
	local rolls = whole(value.rolls)
	local level = whole(value.level)
	if forge == nil or rootvault == nil or rolls == nil or level == nil then
		return nil, ERRORS.progress
	end
	if type(value.guild) ~= "boolean" then
		return nil, ERRORS.progress
	end
	if value.paid ~= nil and type(value.paid) ~= "boolean" then
		return nil, ERRORS.progress
	end
	return {
		forge = forge,
		rootvault = rootvault,
		rolls = rolls,
		level = level,
		guild = value.guild,
	},
		nil
end

local function isGoal(value: any): boolean
	return value == "forge"
		or value == "rootvault"
		or value == "rolls"
		or value == "level"
		or value == "guild"
end

local function definition(id: string): GoalRow
	for _, goal in ipairs(StarterGoals.GOALS) do
		if goal.id == id then
			return goal
		end
	end
	return StarterGoals.GOALS[1]
end

local function isGranted(granted: Granted, id: string): boolean
	if id == "forge" then
		return granted.forge
	elseif id == "rootvault" then
		return granted.rootvault
	elseif id == "rolls" then
		return granted.rolls
	elseif id == "level" then
		return granted.level
	end
	return granted.guild
end

local function withGranted(state: State, id: string): State
	local granted = copyGranted(state.granted)
	if id == "forge" then
		granted.forge = true
	elseif id == "rootvault" then
		granted.rootvault = true
	elseif id == "rolls" then
		granted.rolls = true
	elseif id == "level" then
		granted.level = true
	elseif id == "guild" then
		granted.guild = true
	end
	return {
		returning = state.returning,
		granted = granted,
	}
end

local function countFor(counts: Counts, id: string): number
	if id == "forge" then
		return counts.forge
	elseif id == "rootvault" then
		return counts.rootvault
	elseif id == "rolls" then
		return counts.rolls
	elseif id == "level" then
		return counts.level
	elseif counts.guild then
		return 1
	end
	return 0
end

local function viewOf(counts: Counts, id: string): GoalView
	local goal = definition(id)
	local count = countFor(counts, id)
	local capped = count
	if capped > goal.goal then
		capped = goal.goal
	end
	return {
		id = goal.id,
		text = goal.text,
		goal = goal.goal,
		progress = capped,
		met = count >= goal.goal,
	}
end

local function windowIds(state: State): { string }
	local ids = {}
	if state.returning then
		return ids
	end
	for _, id in ipairs(StarterGoals.ORDER) do
		if not isGranted(state.granted, id) then
			table.insert(ids, id)
			if #ids >= CONFIG.visible then
				break
			end
		end
	end
	return ids
end

local function listed(ids: { string }, goalId: string): boolean
	for _, id in ipairs(ids) do
		if id == goalId then
			return true
		end
	end
	return false
end

local function views(state: State, counts: Counts): { GoalView }
	local goals = {}
	for _, id in ipairs(windowIds(state)) do
		table.insert(goals, viewOf(counts, id))
	end
	return goals
end

local function kept(current: State?): State
	if current == nil then
		return blankState()
	end
	return copyState(current)
end

local function failShow(state: State, err: string): Shown
	return {
		ok = false,
		state = state,
		goals = {},
		error = err,
	}
end

local function failGrant(state: State, err: string, goalId: string?): Grant
	return {
		ok = false,
		state = state,
		goal = goalId,
		accepted = false,
		keys = 0,
		met = false,
		visible = false,
		goals = {},
		error = err,
	}
end

function StarterGoals.fresh(options: any): Opened
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
	for key in pairs(options) do
		if key ~= "returning" then
			return {
				ok = false,
				state = blankState(),
				error = ERRORS.state,
			}
		end
	end
	if options.returning ~= nil and type(options.returning) ~= "boolean" then
		return {
			ok = false,
			state = blankState(),
			error = ERRORS.state,
		}
	end
	return {
		ok = true,
		state = {
			returning = options.returning == true,
			granted = blankGranted(),
		},
	}
end

function StarterGoals.show(state: any, progress: any): Shown
	local broken = rulesOk()
	if broken ~= nil then
		return failShow(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local counts, progressErr = readCounts(progress)
	if progressErr == ERRORS.id or progressErr == ERRORS.paid then
		return failShow(kept(current), progressErr)
	end
	if current == nil then
		return failShow(blankState(), stateErr or ERRORS.state)
	end
	if counts == nil then
		return failShow(copyState(current), progressErr or ERRORS.progress)
	end
	return {
		ok = true,
		state = copyState(current),
		goals = views(current, counts),
	}
end

function StarterGoals.grant(state: any, goalId: any, progress: any): Grant
	local broken = rulesOk()
	if broken ~= nil then
		return failGrant(blankState(), broken, nil)
	end
	local current, stateErr = readState(state)
	local counts, progressErr = readCounts(progress)
	if progressErr == ERRORS.id or progressErr == ERRORS.paid then
		return failGrant(kept(current), progressErr, nil)
	end
	if current == nil then
		return failGrant(blankState(), stateErr or ERRORS.state, nil)
	end
	if counts == nil then
		return failGrant(copyState(current), progressErr or ERRORS.progress, nil)
	end
	if not isGoal(goalId) then
		return failGrant(copyState(current), ERRORS.goal, nil)
	end
	local known: string = goalId
	local wasVisible = listed(windowIds(current), known)
	local met = countFor(counts, known) >= definition(known).goal
	local already = isGranted(current.granted, known)
	local accept = current.returning == false and already == false and wasVisible and met
	local nextState = if accept then withGranted(current, known) else copyState(current)
	local keys = if accept then CONFIG.shardKeys else 0
	local payout: Payout? = nil
	if accept then
		payout = {
			currency = CONFIG.currency,
			amount = keys,
			goal = known,
		}
	end
	return {
		ok = true,
		state = nextState,
		goal = known,
		accepted = accept,
		keys = keys,
		met = met,
		visible = wasVisible,
		goals = views(nextState, counts),
		payout = payout,
	}
end

return StarterGoals
