--!strict

--[[
	Weekly Vault. Pure rules for the Tuesday boss chest.

	The server passes a plain record, a boss kill, and unix seconds.
	This module does not read players, roll loot, grant items, or
	touch saved data, memory queues, and remotes. It does not read
	the clock. Pass unix seconds in as now. It has no RNG: the caller
	supplies the choice items. Thresholds live in CONFIG. Nothing
	here costs Robux.

	Killing 2, 4, or 6 different raid bosses in one Tuesday week opens
	1, 2, or 3 choices. The same boss counts once, at the highest
	difficulty recorded that week. A later higher difficulty upgrades
	that boss. A repeat or a lower difficulty does not add a kill.
	Practice Grove, an AFK removal, and a passed vote-kick do not count.

	Slot quality is the difficulty of the 2nd, 4th, or 6th boss after
	sorting from highest difficulty to lowest. The player picks one
	supplied item at the next Tuesday reset. An unpicked Vault expires
	at the Tuesday after that and is not granted.

	The week key matches the Tuesday 00:00 UTC shape: week 1 starts at
	1970-01-06 00:00:00 UTC. This file does not load the Marks module.
	Each call returns a new table and does not write its input.
]]

local RaidVault = {}

RaidVault.CONFIG = table.freeze({
	weekSeconds = 7 * 86400,
	-- 1970-01-01 was a Thursday. The first Tuesday 00:00 UTC is 5 days later.
	tuesdayOffset = 5 * 86400,
	thresholds = table.freeze({ 2, 4, 6 }),
	choiceCounts = table.freeze({ 1, 2, 3 }),
	rank = table.freeze({
		story = 1,
		normal = 2,
		hard = 3,
		shardbreaker = 4,
	}),
})

RaidVault.REMOVALS = table.freeze({
	afk = true,
	kick = true,
})

RaidVault.REASONS = table.freeze({
	practice = "practice",
	afk = "afk",
	kick = "kick",
	duplicate = "duplicate",
	upgrade = "upgrade",
})

RaidVault.ERRORS = table.freeze({
	time = "Raid time is missing.",
	state = "The Vault record is unusable.",
	kill = "That boss kill is unusable.",
	boss = "That boss is unusable.",
	difficulty = "That difficulty has no Vault rank.",
	practice = "That practice flag is unusable.",
	guided = "That guided flag is unusable.",
	removal = "That removal is not a known cause.",
	clock = "Raid time moved backwards.",
	rules = "The Vault rules are unusable.",
	items = "Those Vault choices are unusable.",
	item = "That Vault choice is unusable.",
	count = "That Vault needs one choice per open slot.",
	closed = "The Vault has no choices yet.",
	early = "The Vault opens at the Tuesday reset.",
	pick = "That Vault choice is not open.",
	picked = "A Vault choice was already taken.",
	offer = "Offer the Vault choices before the pick.",
	expired = "That Vault expired.",
})

export type Kill = {
	bossId: string,
	difficulty: string,
	guided: boolean,
}

export type Slot = {
	index: number,
	threshold: number,
	choiceCount: number,
	open: boolean,
	difficulty: string?,
	rank: number,
}

export type Choice = {
	index: number,
	slot: number,
	threshold: number,
	difficulty: string,
	rank: number,
	item: any,
}

export type State = {
	weekKey: number,
	kills: { Kill },
	vault: Vault?,
}

export type Vault = {
	earnedWeek: number,
	kills: { Kill },
	choices: { any }?,
	picked: number?,
}

export type VaultView = {
	earnedWeek: number,
	opensWeek: number,
	expiresWeek: number,
	killCount: number,
	slots: { Slot },
	choiceCount: number,
	choices: { Choice }?,
	offered: boolean,
	picked: number?,
	item: any,
}

export type Note = {
	ok: boolean,
	persist: boolean,
	state: State,
	counted: boolean,
	upgraded: boolean,
	duplicate: boolean,
	reason: string?,
	weekKey: number,
	killCount: number,
	slots: { Slot },
	choiceCount: number,
	vault: VaultView?,
	rolled: boolean,
	expired: boolean,
	error: string?,
}

export type View = {
	ok: boolean,
	persist: boolean,
	state: State,
	weekKey: number,
	killCount: number,
	slots: { Slot },
	choiceCount: number,
	vault: VaultView?,
	rolled: boolean,
	expired: boolean,
	error: string?,
}

export type Offer = {
	ok: boolean,
	persist: boolean,
	state: State,
	choices: { Choice },
	choiceCount: number,
	rolled: boolean,
	expired: boolean,
	error: string?,
}

export type Pick = {
	ok: boolean,
	persist: boolean,
	state: State,
	index: number,
	slot: number,
	threshold: number,
	difficulty: string,
	rank: number,
	item: any,
	rolled: boolean,
	expired: boolean,
	error: string?,
}

type Step = {
	threshold: number,
	choices: number,
}

type Incoming = {
	bossId: string,
	difficulty: string,
	practice: boolean,
	guided: boolean,
	removal: string?,
}

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

local function normalize(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = trim(value)
	if trimmed == "" then
		return nil
	end
	return string.lower(trimmed)
end

local function blankState(): State
	return {
		weekKey = -1,
		kills = {},
		vault = nil,
	}
end

local function rankOf(difficulty: string): number?
	local ranks = RaidVault.CONFIG.rank
	if type(ranks) ~= "table" then
		return nil
	end
	local rank = (ranks :: any)[difficulty]
	if type(rank) ~= "number" then
		return nil
	end
	if rank ~= rank or rank == math.huge or rank == -math.huge then
		return nil
	end
	if rank < 1 or rank ~= math.floor(rank) then
		return nil
	end
	return rank
end

local function ladder(): { Step }?
	local thresholds = RaidVault.CONFIG.thresholds
	local counts = RaidVault.CONFIG.choiceCounts
	if type(thresholds) ~= "table" or type(counts) ~= "table" then
		return nil
	end
	if #thresholds == 0 or #thresholds ~= #counts then
		return nil
	end
	local steps = {}
	local lastKills = 0
	local lastChoices = 0
	for index, threshold in ipairs(thresholds) do
		local choices = counts[index]
		if type(threshold) ~= "number" or type(choices) ~= "number" then
			return nil
		end
		if threshold ~= math.floor(threshold) or choices ~= math.floor(choices) then
			return nil
		end
		if threshold < 1 or choices < 1 or threshold <= lastKills or choices <= lastChoices then
			return nil
		end
		lastKills = threshold
		lastChoices = choices
		steps[index] = {
			threshold = threshold,
			choices = choices,
		}
	end
	return steps
end

local function arraySize(value: any): number?
	if type(value) ~= "table" then
		return nil
	end
	local count = #value
	local seen = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key > count or key ~= math.floor(key) then
			return nil
		end
		seen += 1
	end
	if seen ~= count then
		return nil
	end
	return count
end

local function copyItem(item: any): any
	if type(item) ~= "table" then
		return item
	end
	return table.clone(item)
end

local function copyKill(kill: Kill): Kill
	return {
		bossId = kill.bossId,
		difficulty = kill.difficulty,
		guided = kill.guided,
	}
end

local function copyKills(kills: { Kill }): { Kill }
	local copy = {}
	for index, kill in ipairs(kills) do
		copy[index] = copyKill(kill)
	end
	return copy
end

local function copyChoices(choices: { any }?): { any }?
	if choices == nil then
		return nil
	end
	local copy = {}
	for index, item in ipairs(choices) do
		copy[index] = copyItem(item)
	end
	return copy
end

local function copyVault(vault: Vault?): Vault?
	if vault == nil then
		return nil
	end
	return {
		earnedWeek = vault.earnedWeek,
		kills = copyKills(vault.kills),
		choices = copyChoices(vault.choices),
		picked = vault.picked,
	}
end

local function copyState(state: State): State
	return {
		weekKey = state.weekKey,
		kills = copyKills(state.kills),
		vault = copyVault(state.vault),
	}
end

-- Week 1 starts at 1970-01-06 00:00:00 UTC. The reset instant is the new week.
-- Times before that Tuesday are week 0. A bad clock returns nil.
function RaidVault.weekKey(now: number): number?
	local at = finite(now)
	if at == nil or at < 0 then
		return nil
	end
	local offset = RaidVault.CONFIG.tuesdayOffset
	local span = RaidVault.CONFIG.weekSeconds
	if type(offset) ~= "number" or type(span) ~= "number" or span < 1 or offset < 0 then
		return nil
	end
	if at < offset then
		return 0
	end
	return math.floor((at - offset) / span) + 1
end

local function sortKills(kills: { Kill }): { Kill }
	local rows = {}
	for index, kill in ipairs(kills) do
		rows[index] = {
			kill = kill,
			index = index,
			rank = rankOf(kill.difficulty) or 0,
		}
	end
	table.sort(rows, function(left, right)
		if left.rank ~= right.rank then
			return left.rank > right.rank
		end
		return left.index < right.index
	end)
	local sorted = {}
	for index, row in ipairs(rows) do
		sorted[index] = row.kill
	end
	return sorted
end

local function slotsFor(kills: { Kill }): ({ Slot }?, number, string?)
	local steps = ladder()
	if steps == nil then
		return nil, 0, RaidVault.ERRORS.rules
	end
	local sorted = sortKills(kills)
	local rows = {}
	local choiceCount = 0
	for index, step in ipairs(steps) do
		local open = #sorted >= step.threshold
		local difficulty = nil
		local rank = 0
		if open then
			local kill = sorted[step.threshold]
			difficulty = kill.difficulty
			rank = rankOf(kill.difficulty) or 0
			choiceCount = step.choices
		end
		rows[index] = {
			index = index,
			threshold = step.threshold,
			choiceCount = step.choices,
			open = open,
			difficulty = difficulty,
			rank = rank,
		}
	end
	return rows, choiceCount, nil
end

local function readKill(value: any): Kill?
	if type(value) ~= "table" then
		return nil
	end
	if type(value.bossId) ~= "string" or normalize(value.bossId) ~= value.bossId then
		return nil
	end
	if type(value.difficulty) ~= "string" or rankOf(value.difficulty) == nil then
		return nil
	end
	local guided = value.guided
	if guided == nil then
		guided = false
	end
	if type(guided) ~= "boolean" then
		return nil
	end
	return {
		bossId = value.bossId,
		difficulty = value.difficulty,
		guided = guided,
	}
end

local function readKills(value: any): { Kill }?
	if value == nil then
		return {}
	end
	local count = arraySize(value)
	if count == nil then
		return nil
	end
	local kills = {}
	local seen: { [string]: boolean } = {}
	for index = 1, count do
		local kill = readKill(value[index])
		if kill == nil or seen[kill.bossId] == true then
			return nil
		end
		seen[kill.bossId] = true
		kills[index] = kill
	end
	return kills
end

local function storedItem(value: any): any?
	if type(value) == "string" then
		if normalize(value) == nil or trim(value) ~= value then
			return nil
		end
		return value
	end
	if type(value) ~= "table" or next(value) == nil then
		return nil
	end
	return copyItem(value)
end

local function readItems(value: any): { any }?
	local count = arraySize(value)
	if count == nil or count < 1 then
		return nil
	end
	local items = {}
	for index = 1, count do
		local item = storedItem(value[index])
		if item == nil then
			return nil
		end
		items[index] = item
	end
	return items
end

local function readVault(value: any, weekKey: number): (Vault?, string?)
	if value == nil then
		return nil, nil
	end
	if type(value) ~= "table" or weekKey < 1 then
		return nil, RaidVault.ERRORS.state
	end
	local earned = finite(value.earnedWeek)
	if earned == nil or earned < 0 or earned ~= math.floor(earned) or earned ~= weekKey - 1 then
		return nil, RaidVault.ERRORS.state
	end
	local kills = readKills(value.kills)
	if kills == nil then
		return nil, RaidVault.ERRORS.state
	end
	local _, choiceCount, rulesError = slotsFor(kills)
	if rulesError ~= nil or choiceCount < 1 then
		return nil, rulesError or RaidVault.ERRORS.state
	end
	local choices = nil
	if value.choices ~= nil then
		choices = readItems(value.choices)
		if choices == nil or #choices ~= choiceCount then
			return nil, RaidVault.ERRORS.state
		end
	end
	local picked = value.picked
	if picked ~= nil then
		local index = finite(picked)
		if
			choices == nil
			or index == nil
			or index ~= math.floor(index)
			or index < 1
			or index > #choices
		then
			return nil, RaidVault.ERRORS.state
		end
		picked = index
	end
	return {
		earnedWeek = earned,
		kills = kills,
		choices = choices,
		picked = picked,
	}, nil
end

local function readState(value: any): (State?, string?)
	if value == nil then
		return blankState(), nil
	end
	if type(value) ~= "table" then
		return nil, RaidVault.ERRORS.state
	end
	local weekKey = value.weekKey
	if weekKey == nil then
		weekKey = -1
	end
	local key = finite(weekKey)
	if key == nil or key ~= math.floor(key) then
		return nil, RaidVault.ERRORS.state
	end
	if key < 0 then
		key = -1
	end
	local kills = readKills(value.kills)
	if kills == nil then
		return nil, RaidVault.ERRORS.state
	end
	local vault, vaultError = readVault(value.vault, key)
	if vaultError ~= nil then
		return nil, vaultError
	end
	return {
		weekKey = key,
		kills = kills,
		vault = vault,
	}, nil
end

local function presentChoices(slots: { Slot }, choiceCount: number, items: { any }?): { Choice }?
	if items == nil then
		return nil
	end
	local choices = {}
	local cursor = 0
	for _, slot in ipairs(slots) do
		if slot.open == true and cursor < choiceCount then
			cursor += 1
			local item = items[cursor]
			choices[cursor] = {
				index = cursor,
				slot = slot.index,
				threshold = slot.threshold,
				difficulty = slot.difficulty :: string,
				rank = slot.rank,
				item = copyItem(item),
			}
		end
	end
	return choices
end

local function presentVault(vault: Vault?): (VaultView?, string?)
	if vault == nil then
		return nil, nil
	end
	local slots, choiceCount, rulesError = slotsFor(vault.kills)
	if slots == nil or rulesError ~= nil then
		return nil, rulesError or RaidVault.ERRORS.rules
	end
	local choices = presentChoices(slots, choiceCount, vault.choices)
	local item = nil
	if vault.picked ~= nil and choices ~= nil then
		local chosen = choices[vault.picked]
		if chosen ~= nil then
			item = copyItem(chosen.item)
		end
	end
	return {
		earnedWeek = vault.earnedWeek,
		opensWeek = vault.earnedWeek + 1,
		expiresWeek = vault.earnedWeek + 2,
		killCount = #vault.kills,
		slots = slots,
		choiceCount = choiceCount,
		choices = choices,
		offered = vault.choices ~= nil,
		picked = vault.picked,
		item = item,
	},
		nil
end

local function progressOf(state: State): ({ Slot }, number, VaultView?, string?)
	local slots, choiceCount, rulesError = slotsFor(state.kills)
	if slots == nil or rulesError ~= nil then
		return {}, 0, nil, rulesError or RaidVault.ERRORS.rules
	end
	local vault, vaultError = presentVault(state.vault)
	if vaultError ~= nil then
		return slots, choiceCount, nil, vaultError
	end
	return slots, choiceCount, vault, nil
end

-- A stored week below 0 has never been stamped. A later key is a bad clock.
-- The next week opens a Vault from this week's bosses. A skipped claim week
-- drops an unpicked Vault and does not grant it.
local function roll(record: State, key: number): (State?, boolean, boolean, string?)
	if record.weekKey < 0 then
		return {
			weekKey = key,
			kills = {},
			vault = nil,
		}, true, false, nil
	end
	if record.weekKey > key then
		return nil, false, false, RaidVault.ERRORS.clock
	end
	if record.weekKey == key then
		return copyState(record), false, false, nil
	end
	local expired = false
	if record.vault ~= nil and record.vault.picked == nil then
		expired = true
	end
	local vault = nil
	if key == record.weekKey + 1 then
		local _, choiceCount, rulesError = slotsFor(record.kills)
		if rulesError ~= nil then
			return nil, false, false, rulesError
		end
		if choiceCount > 0 then
			vault = {
				earnedWeek = record.weekKey,
				kills = copyKills(record.kills),
				choices = nil,
				picked = nil,
			}
		end
	else
		local _, choiceCount, rulesError = slotsFor(record.kills)
		if rulesError ~= nil then
			return nil, false, false, rulesError
		end
		if choiceCount > 0 then
			expired = true
		end
	end
	return {
		weekKey = key,
		kills = {},
		vault = vault,
	}, true, expired, nil
end

local function applyKill(
	kills: { Kill },
	bossId: string,
	difficulty: string,
	guided: boolean
): ({ Kill }, boolean, boolean, boolean)
	local nextKills = copyKills(kills)
	local rank = rankOf(difficulty) or 0
	for index, kill in ipairs(nextKills) do
		if kill.bossId == bossId then
			local oldRank = rankOf(kill.difficulty) or 0
			if rank > oldRank then
				nextKills[index] = {
					bossId = bossId,
					difficulty = difficulty,
					guided = guided,
				}
				return nextKills, false, true, false
			end
			return nextKills, false, false, true
		end
	end
	table.insert(nextKills, {
		bossId = bossId,
		difficulty = difficulty,
		guided = guided,
	})
	return nextKills, true, false, false
end

local function noteFail(message: string, state: State): Note
	local slots, choiceCount, vault = progressOf(state)
	return {
		ok = false,
		persist = false,
		state = state,
		counted = false,
		upgraded = false,
		duplicate = false,
		reason = nil,
		weekKey = state.weekKey,
		killCount = #state.kills,
		slots = slots,
		choiceCount = choiceCount,
		vault = vault,
		rolled = false,
		expired = false,
		error = message,
	}
end

local function parseKill(value: any): (Incoming?, string?)
	if type(value) ~= "table" then
		return nil, RaidVault.ERRORS.kill
	end
	local bossId = normalize(value.bossId)
	if bossId == nil then
		return nil, RaidVault.ERRORS.boss
	end
	local difficulty = normalize(value.difficulty)
	if difficulty == nil or rankOf(difficulty) == nil then
		return nil, RaidVault.ERRORS.difficulty
	end
	local practice = value.practice
	if practice == nil then
		practice = false
	end
	if type(practice) ~= "boolean" then
		return nil, RaidVault.ERRORS.practice
	end
	local guided = value.guided
	if guided == nil then
		guided = false
	end
	if type(guided) ~= "boolean" then
		return nil, RaidVault.ERRORS.guided
	end
	local removal = value.removal
	if removal ~= nil then
		if type(removal) ~= "string" then
			return nil, RaidVault.ERRORS.removal
		end
		local cause = string.lower(trim(removal))
		if (RaidVault.REMOVALS :: any)[cause] ~= true then
			return nil, RaidVault.ERRORS.removal
		end
		removal = cause
	end
	return {
		bossId = bossId,
		difficulty = difficulty,
		practice = practice,
		guided = guided,
		removal = removal,
	},
		nil
end

local function unavailable(state: State, expired: boolean): string
	if expired then
		return RaidVault.ERRORS.expired
	end
	local _, choiceCount = slotsFor(state.kills)
	if state.vault == nil and choiceCount > 0 then
		return RaidVault.ERRORS.early
	end
	return RaidVault.ERRORS.closed
end

function RaidVault.fresh(): { ok: boolean, state: State }
	return {
		ok = true,
		state = blankState(),
	}
end

function RaidVault.note(state: State?, kill: any, now: number): Note
	local record, stateError = readState(state)
	if record == nil then
		return noteFail(stateError or RaidVault.ERRORS.state, blankState())
	end
	local at = finite(now)
	local key = if at ~= nil then RaidVault.weekKey(at) else nil
	if key == nil then
		return noteFail(RaidVault.ERRORS.time, copyState(record))
	end
	local incoming, killError = parseKill(kill)
	if incoming == nil then
		return noteFail(killError or RaidVault.ERRORS.kill, copyState(record))
	end
	local nextRecord, rolled, expired, rollError = roll(record, key)
	if nextRecord == nil then
		return noteFail(rollError or RaidVault.ERRORS.clock, copyState(record))
	end
	local reason = nil
	local counted = false
	local upgraded = false
	local duplicate = false
	local saved = nextRecord
	if incoming.practice then
		reason = RaidVault.REASONS.practice
	elseif incoming.removal ~= nil then
		reason = incoming.removal
	else
		local kills, didCount, didUpgrade, didDuplicate =
			applyKill(nextRecord.kills, incoming.bossId, incoming.difficulty, incoming.guided)
		counted = didCount
		upgraded = didUpgrade
		duplicate = didDuplicate
		if didUpgrade then
			reason = RaidVault.REASONS.upgrade
		elseif didDuplicate then
			reason = RaidVault.REASONS.duplicate
		end
		saved = {
			weekKey = nextRecord.weekKey,
			kills = kills,
			vault = copyVault(nextRecord.vault),
		}
	end
	local slots, choiceCount, vault, progressError = progressOf(saved)
	if progressError ~= nil then
		return noteFail(progressError, copyState(record))
	end
	return {
		ok = true,
		persist = rolled or counted or upgraded,
		state = saved,
		counted = counted,
		upgraded = upgraded,
		duplicate = duplicate,
		reason = reason,
		weekKey = saved.weekKey,
		killCount = #saved.kills,
		slots = slots,
		choiceCount = choiceCount,
		vault = vault,
		rolled = rolled,
		expired = expired,
		error = nil,
	}
end

function RaidVault.view(state: State?, now: number): View
	local record, stateError = readState(state)
	if record == nil then
		local failed = noteFail(stateError or RaidVault.ERRORS.state, blankState())
		return {
			ok = false,
			persist = false,
			state = failed.state,
			weekKey = failed.weekKey,
			killCount = 0,
			slots = failed.slots,
			choiceCount = 0,
			vault = nil,
			rolled = false,
			expired = false,
			error = failed.error,
		}
	end
	local at = finite(now)
	local key = if at ~= nil then RaidVault.weekKey(at) else nil
	if key == nil then
		local failed = noteFail(RaidVault.ERRORS.time, copyState(record))
		return {
			ok = false,
			persist = false,
			state = failed.state,
			weekKey = failed.weekKey,
			killCount = failed.killCount,
			slots = failed.slots,
			choiceCount = failed.choiceCount,
			vault = failed.vault,
			rolled = false,
			expired = false,
			error = failed.error,
		}
	end
	local nextRecord, rolled, expired, rollError = roll(record, key)
	if nextRecord == nil then
		local failed = noteFail(rollError or RaidVault.ERRORS.clock, copyState(record))
		return {
			ok = false,
			persist = false,
			state = failed.state,
			weekKey = failed.weekKey,
			killCount = failed.killCount,
			slots = failed.slots,
			choiceCount = failed.choiceCount,
			vault = failed.vault,
			rolled = false,
			expired = false,
			error = failed.error,
		}
	end
	local slots, choiceCount, vault, progressError = progressOf(nextRecord)
	if progressError ~= nil then
		local failed = noteFail(progressError, copyState(record))
		return {
			ok = false,
			persist = false,
			state = failed.state,
			weekKey = failed.weekKey,
			killCount = failed.killCount,
			slots = failed.slots,
			choiceCount = failed.choiceCount,
			vault = nil,
			rolled = false,
			expired = false,
			error = failed.error,
		}
	end
	return {
		ok = true,
		persist = rolled,
		state = nextRecord,
		weekKey = nextRecord.weekKey,
		killCount = #nextRecord.kills,
		slots = slots,
		choiceCount = choiceCount,
		vault = vault,
		rolled = rolled,
		expired = expired,
		error = nil,
	}
end

local function parseItems(value: any): ({ any }?, string?)
	local count = arraySize(value)
	if count == nil or count < 1 then
		return nil, RaidVault.ERRORS.items
	end
	local items = {}
	for index = 1, count do
		local item = storedItem(value[index])
		if type(value[index]) == "string" then
			local trimmed = trim(value[index])
			if normalize(trimmed) == nil then
				return nil, RaidVault.ERRORS.item
			end
			item = trimmed
		end
		if item == nil then
			return nil, RaidVault.ERRORS.item
		end
		items[index] = item
	end
	return items, nil
end

local function offerFail(
	message: string,
	state: State,
	rolled: boolean,
	expired: boolean,
	choiceCount: number
): Offer
	return {
		ok = false,
		persist = rolled,
		state = state,
		choices = {},
		choiceCount = choiceCount,
		rolled = rolled,
		expired = expired,
		error = message,
	}
end

function RaidVault.offer(state: State?, items: any, now: number): Offer
	local record, stateError = readState(state)
	if record == nil then
		return offerFail(stateError or RaidVault.ERRORS.state, blankState(), false, false, 0)
	end
	local at = finite(now)
	local key = if at ~= nil then RaidVault.weekKey(at) else nil
	if key == nil then
		return offerFail(RaidVault.ERRORS.time, copyState(record), false, false, 0)
	end
	local nextRecord, rolled, expired, rollError = roll(record, key)
	if nextRecord == nil then
		return offerFail(rollError or RaidVault.ERRORS.clock, copyState(record), false, false, 0)
	end
	local shown, showError = presentVault(nextRecord.vault)
	if showError ~= nil then
		return offerFail(showError, copyState(record), false, false, 0)
	end
	if shown == nil then
		local _, choiceCount = slotsFor(nextRecord.kills)
		return offerFail(unavailable(nextRecord, expired), nextRecord, rolled, expired, choiceCount)
	end
	if nextRecord.vault ~= nil and nextRecord.vault.picked ~= nil then
		return offerFail(RaidVault.ERRORS.picked, nextRecord, rolled, expired, shown.choiceCount)
	end
	local parsed, itemError = parseItems(items)
	if parsed == nil then
		return offerFail(
			itemError or RaidVault.ERRORS.items,
			nextRecord,
			rolled,
			expired,
			shown.choiceCount
		)
	end
	if #parsed ~= shown.choiceCount then
		return offerFail(RaidVault.ERRORS.count, nextRecord, rolled, expired, shown.choiceCount)
	end
	local saved: State = {
		weekKey = nextRecord.weekKey,
		kills = copyKills(nextRecord.kills),
		vault = {
			earnedWeek = nextRecord.vault.earnedWeek,
			kills = copyKills(nextRecord.vault.kills),
			choices = parsed,
			picked = nil,
		},
	}
	local viewVault = presentVault(saved.vault)
	local choices = if viewVault ~= nil and viewVault.choices ~= nil then viewVault.choices else {}
	return {
		ok = true,
		persist = true,
		state = saved,
		choices = choices,
		choiceCount = shown.choiceCount,
		rolled = rolled,
		expired = expired,
		error = nil,
	}
end

local function pickFail(message: string, state: State, rolled: boolean, expired: boolean): Pick
	return {
		ok = false,
		persist = rolled,
		state = state,
		index = 0,
		slot = 0,
		threshold = 0,
		difficulty = "",
		rank = 0,
		item = nil,
		rolled = rolled,
		expired = expired,
		error = message,
	}
end

function RaidVault.pick(state: State?, index: any, now: number): Pick
	local record, stateError = readState(state)
	if record == nil then
		return pickFail(stateError or RaidVault.ERRORS.state, blankState(), false, false)
	end
	local at = finite(now)
	local key = if at ~= nil then RaidVault.weekKey(at) else nil
	if key == nil then
		return pickFail(RaidVault.ERRORS.time, copyState(record), false, false)
	end
	local nextRecord, rolled, expired, rollError = roll(record, key)
	if nextRecord == nil then
		return pickFail(rollError or RaidVault.ERRORS.clock, copyState(record), false, false)
	end
	local shown, showError = presentVault(nextRecord.vault)
	if showError ~= nil then
		return pickFail(showError, copyState(record), false, false)
	end
	if shown == nil then
		return pickFail(unavailable(nextRecord, expired), nextRecord, rolled, expired)
	end
	if shown.offered ~= true or shown.choices == nil then
		return pickFail(RaidVault.ERRORS.offer, nextRecord, rolled, expired)
	end
	if shown.picked ~= nil then
		return pickFail(RaidVault.ERRORS.picked, nextRecord, rolled, expired)
	end
	local choiceIndex = finite(index)
	if
		choiceIndex == nil
		or choiceIndex ~= math.floor(choiceIndex)
		or choiceIndex < 1
		or choiceIndex > #shown.choices
	then
		return pickFail(RaidVault.ERRORS.pick, nextRecord, rolled, expired)
	end
	local choice = shown.choices[choiceIndex]
	local saved: State = {
		weekKey = nextRecord.weekKey,
		kills = copyKills(nextRecord.kills),
		vault = {
			earnedWeek = nextRecord.vault.earnedWeek,
			kills = copyKills(nextRecord.vault.kills),
			choices = copyChoices(nextRecord.vault.choices),
			picked = choiceIndex,
		},
	}
	return {
		ok = true,
		persist = true,
		state = saved,
		index = choice.index,
		slot = choice.slot,
		threshold = choice.threshold,
		difficulty = choice.difficulty,
		rank = choice.rank,
		item = copyItem(choice.item),
		rolled = rolled,
		expired = expired,
		error = nil,
	}
end

return RaidVault
