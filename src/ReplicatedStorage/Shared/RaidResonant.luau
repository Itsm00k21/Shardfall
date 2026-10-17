--!strict

--[[
	Resonant Heartshard patterns. Pure rules for the red-border count.

	The server passes a plain record and one drop. This module does not
	craft, spend Marks, grant materials, roll loot, read players, or
	touch saved data, memory queues, and remotes. It does not read the
	clock. Thresholds live in CONFIG. Nothing here costs Robux. There
	is no paid skip of the three drops.

	A Resonant drop (red border) counts toward that weapon. Three
	Resonant drops of the same weapon unlock its Forge pattern. The
	count sticks at the threshold. Unlock stays set. The same uid does
	not count twice, on this weapon or on any other. A missing uid is
	refused so a retry cannot double-count. Anything other than
	resonant == true does not count. Practice Grove does not count.

	weaponId is a trimmed non-empty string. This file does not know
	the weapon catalog. Each call returns a new table and does not
	write its input.
]]

local RaidResonant = {}

RaidResonant.CONFIG = table.freeze({
	threshold = 3,
	-- A longer weapon id or uid is refused before it is stored.
	-- Placeholder, the same cap the practice guard uses. A GUID is 36.
	maxIdLength = 64,
})

RaidResonant.REASONS = table.freeze({
	practice = "practice",
	resonant = "resonant",
	duplicate = "duplicate",
	capped = "capped",
})

RaidResonant.ERRORS = table.freeze({
	state = "The Resonant record is unusable.",
	drop = "That drop is unusable.",
	weapon = "That weapon is unusable.",
	uid = "That drop has no uid.",
	uidShape = "That uid is unusable.",
	practice = "That practice flag is unusable.",
	rules = "The Resonant rules are unusable.",
})

export type WeaponRow = {
	weaponId: string,
	count: number,
	unlocked: boolean,
	uids: { string },
}

export type State = {
	weapons: { WeaponRow },
}

export type Progress = {
	weaponId: string,
	count: number,
	unlocked: boolean,
	threshold: number,
}

export type Note = {
	ok: boolean,
	persist: boolean,
	state: State,
	weaponId: string,
	count: number,
	unlocked: boolean,
	threshold: number,
	counted: boolean,
	duplicate: boolean,
	reason: string?,
	error: string?,
}

export type View = {
	ok: boolean,
	persist: boolean,
	state: State,
	weaponId: string?,
	count: number,
	unlocked: boolean,
	threshold: number,
	weapons: { Progress },
	error: string?,
}

type Incoming = {
	weaponId: string,
	resonant: any,
	practice: boolean,
	uid: string,
}

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

local function whole(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < 1 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function rules(): (number?, number?, string?)
	local limit = whole(RaidResonant.CONFIG.threshold)
	local cap = whole(RaidResonant.CONFIG.maxIdLength)
	if limit == nil or cap == nil then
		return nil, nil, RaidResonant.ERRORS.rules
	end
	return limit, cap, nil
end

local function canonical(value: any, cap: number): string?
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = trim(value)
	if trimmed == "" or #trimmed > cap then
		return nil
	end
	return trimmed
end

local function blankState(): State
	return {
		weapons = {},
	}
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

local function copyUids(uids: { string }): { string }
	return table.clone(uids)
end

local function copyWeapon(row: WeaponRow): WeaponRow
	return {
		weaponId = row.weaponId,
		count = row.count,
		unlocked = row.unlocked,
		uids = copyUids(row.uids),
	}
end

local function copyState(state: State): State
	local weapons = {}
	for index, row in ipairs(state.weapons) do
		weapons[index] = copyWeapon(row)
	end
	return {
		weapons = weapons,
	}
end

local function findWeapon(state: State, weaponId: string): WeaponRow?
	for _, row in ipairs(state.weapons) do
		if row.weaponId == weaponId then
			return row
		end
	end
	return nil
end

local function uidOwner(state: State, uid: string): string?
	for _, row in ipairs(state.weapons) do
		for _, seen in ipairs(row.uids) do
			if seen == uid then
				return row.weaponId
			end
		end
	end
	return nil
end

local function progressOf(state: State, weaponId: string): (number, boolean)
	local row = findWeapon(state, weaponId)
	if row == nil then
		return 0, false
	end
	return row.count, row.unlocked
end

local function listProgress(state: State, limit: number): { Progress }
	local rows = {}
	for index, row in ipairs(state.weapons) do
		rows[index] = {
			weaponId = row.weaponId,
			count = row.count,
			unlocked = row.unlocked,
			threshold = limit,
		}
	end
	return rows
end

local function readWeapon(
	value: any,
	limit: number,
	cap: number,
	seenWeapons: { [string]: boolean },
	seenUids: { [string]: boolean }
): WeaponRow?
	if type(value) ~= "table" then
		return nil
	end
	if type(value.weaponId) ~= "string" then
		return nil
	end
	local weaponId = canonical(value.weaponId, cap)
	if weaponId == nil or weaponId ~= value.weaponId then
		return nil
	end
	if seenWeapons[weaponId] == true then
		return nil
	end
	local count = value.count
	if type(count) ~= "number" then
		return nil
	end
	if count ~= count or count == math.huge or count == -math.huge then
		return nil
	end
	if count < 1 or count > limit or count ~= math.floor(count) then
		return nil
	end
	if type(value.unlocked) ~= "boolean" or value.unlocked ~= (count >= limit) then
		return nil
	end
	local size = arraySize(value.uids)
	if size == nil or size ~= count then
		return nil
	end
	local uids = {}
	for index = 1, size do
		local uid = value.uids[index]
		if type(uid) ~= "string" then
			return nil
		end
		local cleaned = canonical(uid, cap)
		if cleaned == nil or cleaned ~= uid or seenUids[cleaned] == true then
			return nil
		end
		seenUids[cleaned] = true
		uids[index] = cleaned
	end
	seenWeapons[weaponId] = true
	return {
		weaponId = weaponId,
		count = count,
		unlocked = value.unlocked,
		uids = uids,
	}
end

local function readState(value: any, limit: number, cap: number): (State?, string?)
	if value == nil then
		return blankState(), nil
	end
	if type(value) ~= "table" then
		return nil, RaidResonant.ERRORS.state
	end
	if value.weapons == nil then
		return blankState(), nil
	end
	local size = arraySize(value.weapons)
	if size == nil then
		return nil, RaidResonant.ERRORS.state
	end
	local weapons = {}
	local seenWeapons: { [string]: boolean } = {}
	local seenUids: { [string]: boolean } = {}
	for index = 1, size do
		local row = readWeapon(value.weapons[index], limit, cap, seenWeapons, seenUids)
		if row == nil then
			return nil, RaidResonant.ERRORS.state
		end
		weapons[index] = row
	end
	return {
		weapons = weapons,
	}, nil
end

local function parseDrop(value: any, cap: number): (Incoming?, string?, string?)
	if type(value) ~= "table" then
		return nil, RaidResonant.ERRORS.drop, nil
	end
	local weaponId = canonical(value.weaponId, cap)
	if weaponId == nil then
		return nil, RaidResonant.ERRORS.weapon, nil
	end
	local practice = value.practice
	if practice == nil then
		practice = false
	end
	if type(practice) ~= "boolean" then
		return nil, RaidResonant.ERRORS.practice, weaponId
	end
	local uid = value.uid
	if uid == nil then
		return nil, RaidResonant.ERRORS.uid, weaponId
	end
	if type(uid) ~= "string" then
		return nil, RaidResonant.ERRORS.uidShape, weaponId
	end
	local trimmed = trim(uid)
	if trimmed == "" then
		return nil, RaidResonant.ERRORS.uid, weaponId
	end
	if #trimmed > cap then
		return nil, RaidResonant.ERRORS.uidShape, weaponId
	end
	return {
		weaponId = weaponId,
		resonant = value.resonant,
		practice = practice,
		uid = trimmed,
	},
		nil,
		weaponId
end

local function fail(message: string, state: State, weaponId: string?, limit: number): Note
	local id = weaponId or ""
	local count = 0
	local unlocked = false
	if id ~= "" then
		count, unlocked = progressOf(state, id)
	end
	return {
		ok = false,
		persist = false,
		state = state,
		weaponId = id,
		count = count,
		unlocked = unlocked,
		threshold = limit,
		counted = false,
		duplicate = false,
		reason = nil,
		error = message,
	}
end

local function outcome(
	state: State,
	weaponId: string,
	limit: number,
	counted: boolean,
	duplicate: boolean,
	reason: string?,
	persist: boolean
): Note
	local count, unlocked = progressOf(state, weaponId)
	return {
		ok = true,
		persist = persist,
		state = state,
		weaponId = weaponId,
		count = count,
		unlocked = unlocked,
		threshold = limit,
		counted = counted,
		duplicate = duplicate,
		reason = reason,
		error = nil,
	}
end

local function withDrop(state: State, weaponId: string, uid: string, limit: number): State
	local weapons = {}
	local found = false
	for index, row in ipairs(state.weapons) do
		if row.weaponId == weaponId then
			found = true
			local uids = copyUids(row.uids)
			table.insert(uids, uid)
			local count = row.count + 1
			weapons[index] = {
				weaponId = row.weaponId,
				count = count,
				unlocked = count >= limit,
				uids = uids,
			}
		else
			weapons[index] = copyWeapon(row)
		end
	end
	if found ~= true then
		table.insert(weapons, {
			weaponId = weaponId,
			count = 1,
			unlocked = 1 >= limit,
			uids = { uid },
		})
	end
	return {
		weapons = weapons,
	}
end

function RaidResonant.fresh(): { ok: boolean, state: State }
	return {
		ok = true,
		state = blankState(),
	}
end

function RaidResonant.note(state: State?, drop: any): Note
	local limit, cap, rulesError = rules()
	if limit == nil or cap == nil then
		return fail(rulesError or RaidResonant.ERRORS.rules, blankState(), nil, 0)
	end
	local record, stateError = readState(state, limit, cap)
	if record == nil then
		return fail(stateError or RaidResonant.ERRORS.state, blankState(), nil, limit)
	end
	local incoming, dropError, weaponId = parseDrop(drop, cap)
	if incoming == nil then
		return fail(dropError or RaidResonant.ERRORS.drop, copyState(record), weaponId, limit)
	end
	local saved = copyState(record)
	if uidOwner(saved, incoming.uid) ~= nil then
		return outcome(
			saved,
			incoming.weaponId,
			limit,
			false,
			true,
			RaidResonant.REASONS.duplicate,
			false
		)
	end
	if incoming.practice then
		return outcome(
			saved,
			incoming.weaponId,
			limit,
			false,
			false,
			RaidResonant.REASONS.practice,
			false
		)
	end
	if incoming.resonant ~= true then
		return outcome(
			saved,
			incoming.weaponId,
			limit,
			false,
			false,
			RaidResonant.REASONS.resonant,
			false
		)
	end
	local row = findWeapon(saved, incoming.weaponId)
	if row ~= nil and (row.count >= limit or row.unlocked == true) then
		return outcome(
			saved,
			incoming.weaponId,
			limit,
			false,
			false,
			RaidResonant.REASONS.capped,
			false
		)
	end
	local nextState = withDrop(saved, incoming.weaponId, incoming.uid, limit)
	return outcome(nextState, incoming.weaponId, limit, true, false, nil, true)
end

local function viewFail(message: string, state: State, limit: number): View
	return {
		ok = false,
		persist = false,
		state = state,
		weaponId = nil,
		count = 0,
		unlocked = false,
		threshold = limit,
		weapons = {},
		error = message,
	}
end

function RaidResonant.view(state: State?, weaponId: any): View
	local limit, cap, rulesError = rules()
	if limit == nil or cap == nil then
		return viewFail(rulesError or RaidResonant.ERRORS.rules, blankState(), 0)
	end
	local record, stateError = readState(state, limit, cap)
	if record == nil then
		return viewFail(stateError or RaidResonant.ERRORS.state, blankState(), limit)
	end
	local saved = copyState(record)
	local rows = listProgress(saved, limit)
	if weaponId == nil then
		return {
			ok = true,
			persist = false,
			state = saved,
			weaponId = nil,
			count = 0,
			unlocked = false,
			threshold = limit,
			weapons = rows,
			error = nil,
		}
	end
	local id = canonical(weaponId, cap)
	if id == nil then
		return viewFail(RaidResonant.ERRORS.weapon, saved, limit)
	end
	local count, unlocked = progressOf(saved, id)
	return {
		ok = true,
		persist = false,
		state = saved,
		weaponId = id,
		count = count,
		unlocked = unlocked,
		threshold = limit,
		weapons = rows,
		error = nil,
	}
end

return RaidResonant
