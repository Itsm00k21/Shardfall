--!strict

--[[
	Server grant for the five starter goals.

	StarterGoals stays pure. This module is what a server mutate calls.
	It builds progress from the profile, pays 10 Shard Keys when grant
	accepts, and stores the record on that profile. A second grant of
	the same goal pays nothing. An alt is a new profile and starts unpaid.
	There is no account flag.

	crafts and rootvaultClears live on the record because the profile
	has no craft count and no Normal Rootvault clear count. rolls and
	level stay derived. show and grant keep the shape StarterGoals
	already returns. Nothing here costs Robux.
]]

local Economy = require("./Economy")
local StarterGoals = require("./StarterGoals")

local StarterGoalPay = {}

StarterGoalPay.GUILD_LEVEL = 10
StarterGoalPay.REASON = "starter_goal"

local FACT_KEYS: { [string]: boolean } = {
	craft = true,
	rootvault = true,
	browse = true,
	paid = true,
}

local ID_KEYS: { [string]: boolean } = {
	userId = true,
	UserId = true,
	guildId = true,
	GuildId = true,
	playerId = true,
	PlayerId = true,
	host = true,
	hostUserId = true,
}

local SKIP_KEYS: { [string]: boolean } = {
	productId = true,
	robux = true,
	cost = true,
	skip = true,
}

local GOAL_IDS: { [string]: boolean } = {
	forge = true,
	rootvault = true,
	rolls = true,
	level = true,
	guild = true,
}

local function whole(value: any): number
	if type(value) ~= "number" then
		return 0
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	if value < 0 or value ~= math.floor(value) then
		return 0
	end
	if value > 1000000 then
		return 1000000
	end
	return value
end

local function blankGranted()
	return {
		forge = false,
		rootvault = false,
		rolls = false,
		level = false,
		guild = false,
	}
end

function StarterGoalPay.blank()
	return {
		returning = false,
		granted = blankGranted(),
		browsedGuild = false,
		crafts = 0,
		rootvaultClears = 0,
	}
end

function StarterGoalPay.normalize(raw: any)
	local blank = StarterGoalPay.blank()
	if type(raw) ~= "table" then
		return blank
	end
	local grantedIn = raw.granted
	local granted = blankGranted()
	if type(grantedIn) == "table" then
		for id in pairs(GOAL_IDS) do
			granted[id] = grantedIn[id] == true
		end
	end
	return {
		returning = raw.returning == true,
		granted = granted,
		browsedGuild = raw.browsedGuild == true,
		crafts = whole(raw.crafts),
		rootvaultClears = whole(raw.rootvaultClears),
	}
end

local function stateOf(record)
	return {
		returning = record.returning == true,
		granted = {
			forge = record.granted.forge == true,
			rootvault = record.granted.rootvault == true,
			rolls = record.granted.rolls == true,
			level = record.granted.level == true,
			guild = record.granted.guild == true,
		},
	}
end

local function progressOf(data, record, paid: any)
	local level = whole(data.level)
	local rolls = whole(data.shardRolls)
	return {
		forge = record.crafts,
		rootvault = record.rootvaultClears,
		rolls = rolls,
		level = level,
		guild = record.browsedGuild == true,
		paid = paid,
	}
end

function StarterGoalPay.tracker(data: any)
	local record = StarterGoalPay.normalize(if type(data) == "table" then data.starterGoals else nil)
	local profile = if type(data) == "table" then data else {}
	return StarterGoals.show(stateOf(record), progressOf(profile, record, nil))
end

-- Pays every visible goal that is already at its count. A hidden goal stays
-- unpaid. A second pass pays nothing for a goal that already cleared.
function StarterGoalPay.collect(data: any): number
	if type(data) ~= "table" then
		return 0
	end
	local paid = 0
	for _ = 1, #StarterGoals.ORDER do
		local shown = StarterGoalPay.tracker(data)
		local goals = if type(shown) == "table" then shown.goals else nil
		if type(goals) ~= "table" then
			break
		end
		local target = nil
		for _, goal in ipairs(goals) do
			if type(goal) == "table" and goal.met == true then
				target = goal.id
				break
			end
		end
		if target == nil then
			break
		end
		local noted = StarterGoalPay.grant(data, target, nil)
		if type(noted) ~= "table" or noted.accepted ~= true then
			break
		end
		local keys = 0
		if type(noted.keys) == "number" then
			keys = noted.keys
		end
		paid += keys
	end
	return paid
end

local function refused(reason: string)
	return {
		ok = false,
		accepted = false,
		keys = 0,
		error = reason,
	}
end

function StarterGoalPay.grant(data: any, goalId: any, fact: any)
	if type(data) ~= "table" then
		return refused(StarterGoals.ERRORS.state)
	end
	local paid = nil
	if fact ~= nil then
		if type(fact) ~= "table" then
			return refused(StarterGoals.ERRORS.progress)
		end
		for key, value in pairs(fact) do
			if ID_KEYS[key] == true then
				return refused(StarterGoals.ERRORS.id)
			end
			if SKIP_KEYS[key] == true then
				return refused(StarterGoals.ERRORS.paid)
			end
			if FACT_KEYS[key] ~= true then
				return refused(StarterGoals.ERRORS.progress)
			end
			if key == "paid" then
				paid = value
			elseif type(value) ~= "boolean" then
				return refused(StarterGoals.ERRORS.progress)
			end
		end
	end
	local record = StarterGoalPay.normalize(data.starterGoals)
	if type(fact) == "table" then
		if fact.craft == true and goalId == "forge" then
			record.crafts += 1
		end
		if fact.rootvault == true and goalId == "rootvault" then
			record.rootvaultClears += 1
		end
		if fact.browse == true and goalId == "guild" and whole(data.level) >= StarterGoalPay.GUILD_LEVEL then
			record.browsedGuild = true
		end
	end
	local noted = StarterGoals.grant(stateOf(record), goalId, progressOf(data, record, paid))
	if noted.ok ~= true then
		return {
			ok = false,
			accepted = false,
			keys = 0,
			error = noted.error,
			goals = noted.goals,
		}
	end
	if noted.accepted == true then
		local payout = noted.payout
		if type(payout) ~= "table" or payout.currency ~= "shardKeys" or payout.amount ~= StarterGoals.CONFIG.shardKeys then
			return refused(StarterGoals.ERRORS.rules)
		end
		local moved = Economy.grant(data, payout.currency, payout.amount, StarterGoalPay.REASON)
		if moved ~= true then
			return refused(StarterGoals.ERRORS.rules)
		end
	end
	local saved = StarterGoalPay.normalize({
		returning = noted.state.returning,
		granted = noted.state.granted,
		browsedGuild = record.browsedGuild,
		crafts = record.crafts,
		rootvaultClears = record.rootvaultClears,
	})
	data.starterGoals = saved
	return {
		ok = true,
		accepted = noted.accepted == true,
		keys = if noted.accepted == true then noted.keys else 0,
		goals = noted.goals,
		state = saved,
	}
end

return StarterGoalPay
