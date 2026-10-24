--!strict

--[[
	Session-lock decisions, with no DataStore calls.

	A lock is { jobId, placeId, lockedAt }. The server that loaded the profile
	writes its job id. tryClaim / trySave return nil when the write must be
	aborted (UpdateAsync treats a nil return as "leave the key unchanged").

	  free     nobody holds it (or the lock was cleared on release)
	  owned    this server already holds it, so refresh / save is allowed
	  busy     another server holds a fresh lock — do not touch the data
	  expired  another server's lock is older than the timeout (it crashed
	           or stopped autosaving) — this server may claim it

	Our own lock stays "owned" even if lockedAt is old, so a slow autosave
	does not kick the player who is actually playing here. Other servers
	treat that same old timestamp as expired and may take over.
]]

local SessionLock = {}

-- Must stay much larger than DataService's autosave interval. A live server
-- refreshes lockedAt every autosave; this is only the crash timeout.
SessionLock.TIMEOUT_SECONDS = 60 * 20

export type Lock = {
	jobId: string,
	placeId: number,
	lockedAt: number,
}

export type Document = {
	Data: any,
	Lock: Lock?,
}

function SessionLock.claim(now: number, jobId: string, placeId: number): Lock
	return {
		jobId = jobId,
		placeId = placeId,
		lockedAt = now,
	}
end

function SessionLock.cleared(): Lock
	return {
		jobId = "",
		placeId = 0,
		lockedAt = 0,
	}
end

function SessionLock.status(lock: any, now: number, jobId: string, timeout: number): string
	if type(lock) ~= "table" then
		return "free"
	end
	if type(lock.jobId) ~= "string" or lock.jobId == "" then
		return "free"
	end
	if lock.jobId == jobId then
		return "owned"
	end
	local lockedAt = lock.lockedAt
	-- NaN and infinity never age out. A foreign lock with either value
	-- would stay busy forever, so another server may claim it.
	if
		type(lockedAt) ~= "number"
		or lockedAt ~= lockedAt
		or lockedAt >= math.huge
		or lockedAt <= -math.huge
	then
		return "expired"
	end
	if now - lockedAt >= timeout then
		return "expired"
	end
	return "busy"
end

function SessionLock.canClaim(lock: any, now: number, jobId: string, timeout: number): boolean
	local status = SessionLock.status(lock, now, jobId, timeout)
	return status == "free" or status == "owned" or status == "expired"
end

function SessionLock.canWrite(lock: any, now: number, jobId: string, timeout: number): boolean
	return SessionLock.status(lock, now, jobId, timeout) == "owned"
end

-- nil document means the key has never been written.
function SessionLock.tryClaim(
	document: Document?,
	now: number,
	jobId: string,
	placeId: number,
	timeout: number,
	data: any
): (Document?, string)
	local lock = nil
	if document ~= nil then
		lock = document.Lock
	end
	if not SessionLock.canClaim(lock, now, jobId, timeout) then
		return nil, "busy"
	end
	return {
		Data = data,
		Lock = SessionLock.claim(now, jobId, placeId),
	}, "claimed"
end

function SessionLock.trySave(
	document: Document?,
	now: number,
	jobId: string,
	placeId: number,
	timeout: number,
	data: any,
	releaseLock: boolean
): (Document?, string)
	if document == nil then
		return nil, "missing"
	end
	if not SessionLock.canWrite(document.Lock, now, jobId, timeout) then
		return nil, "lost"
	end
	local lock = if releaseLock
		then SessionLock.cleared()
		else SessionLock.claim(now, jobId, placeId)
	return {
		Data = data,
		Lock = lock,
	}, "saved"
end

-- Clear a lock this server owns. Data stays the stored document, so a
-- failed load cannot replace a claimed profile with a blank one.
function SessionLock.tryRelease(document: Document?, jobId: string): (Document?, string)
	if document == nil then
		return nil, "missing"
	end
	if SessionLock.status(document.Lock, 0, jobId, SessionLock.TIMEOUT_SECONDS) ~= "owned" then
		return nil, "busy"
	end
	return {
		Data = document.Data,
		Lock = SessionLock.cleared(),
	}, "released"
end

return SessionLock
