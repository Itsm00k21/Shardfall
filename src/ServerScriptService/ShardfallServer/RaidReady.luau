--!strict

--[[
	Server score for a premade ready check.

	The caller id, the host id, and the member list are the server's.
	This module has no argument for a client ready map, a client host,
	or a client member list. A stored check only records ids this
	function already accepted. Leaving cancels the check in RaidService
	by dropping it. Nothing here spends Robux or skips the check.
]]

local RaidReady = {}

export type Check = {
	open: boolean,
	ready: { [number]: boolean },
}

export type Vote = {
	ok: boolean,
	error: string?,
	check: Check?,
	complete: boolean,
	readyCount: number,
	partySize: number,
	started: boolean,
}

local function denied(message: string, partySize: number): Vote
	return {
		ok = false,
		error = message,
		complete = false,
		readyCount = 0,
		partySize = partySize,
		started = false,
	}
end

local function wholeUserId(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value <= 0 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function memberIds(members: any): { number }?
	if type(members) ~= "table" then
		return nil
	end
	local ids = {}
	local seen: { [number]: boolean } = {}
	for _, member in ipairs(members) do
		if type(member) ~= "table" then
			return nil
		end
		local userId = wholeUserId(member.userId)
		if userId == nil or seen[userId] == true then
			return nil
		end
		seen[userId] = true
		table.insert(ids, userId)
	end
	if #ids == 0 then
		return nil
	end
	return ids
end

local function seated(ids: { number }, userId: number): boolean
	for _, id in ipairs(ids) do
		if id == userId then
			return true
		end
	end
	return false
end

-- Only ids on the server member list count. A stored id for someone
-- who is no longer seated does not fill a seat.
local function countReady(ids: { number }, ready: { [number]: boolean }): number
	local count = 0
	for _, id in ipairs(ids) do
		if ready[id] == true then
			count += 1
		end
	end
	return count
end

-- Keep a stored flag only when that id is still seated. A leftover id
-- must not become ready again by rejoining the same check.
local function copyReady(source: any, ids: { number }): { [number]: boolean }
	local copy: { [number]: boolean } = {}
	if type(source) ~= "table" then
		return copy
	end
	for _, id in ipairs(ids) do
		if source[id] == true then
			copy[id] = true
		end
	end
	return copy
end

local function accepted(ready: { [number]: boolean }, ids: { number }, started: boolean): Vote
	local count = countReady(ids, ready)
	local size = #ids
	return {
		ok = true,
		check = {
			open = true,
			ready = ready,
		},
		complete = count == size,
		readyCount = count,
		partySize = size,
		started = started,
	}
end

-- `check` is the server's previous score, or nil when no check is open.
-- `callerUserId` is the player who invoked the remote. Only that id can
-- become ready on this call. `hostUserId` and `members` come from the
-- stored listing. `full` is the server's seat count, not a client flag.
function RaidReady.vote(
	check: any,
	callerUserId: any,
	hostUserId: any,
	members: any,
	full: boolean
): Vote
	local ids = memberIds(members)
	local caller = wholeUserId(callerUserId)
	local host = wholeUserId(hostUserId)
	if ids == nil or caller == nil or host == nil then
		return denied("That listing is unusable.", 0)
	end
	if not seated(ids, caller) then
		return denied("You are not seated on a premade listing.", #ids)
	end
	if full ~= true then
		return denied("Fill the party before the ready check.", #ids)
	end
	local open = type(check) == "table" and check.open == true
	if not open then
		if caller ~= host then
			return denied("The host has not started the ready check.", #ids)
		end
		local ready: { [number]: boolean } = {}
		ready[caller] = true
		return accepted(ready, ids, true)
	end
	local ready = copyReady(check.ready, ids)
	ready[caller] = true
	return accepted(ready, ids, false)
end

return RaidReady
