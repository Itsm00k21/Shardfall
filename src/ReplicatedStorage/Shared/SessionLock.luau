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

	Studio (RunService:IsStudio, passed in by DataService) may claim a lock
	held by the same user id once it is at least STUDIO_STEAL_SECONDS old.
	A live server does not. That shorter steal is a claim, not a save:
	trySave still writes only when this server already owns the lock.
	userId on the lock is optional. Locks written before that field existed
	omit it. The profile key is already Player_<userId>, so a missing
	userId is that player's lock. This is not a profile schema field.
]]

local SessionLock = {}

-- Must stay much larger than DataService's autosave interval. A live server
-- refreshes lockedAt every autosave; this is only the crash timeout.
SessionLock.TIMEOUT_SECONDS = 60 * 20

-- Studio Stop can die before the release write lands. The next Play of the
-- same account may take that lock once it is about a minute old.
SessionLock.STUDIO_STEAL_SECONDS = 60

-- Outside Studio a fresh lock stays busy. The load retries a few times
-- across this window, then kicks. It does not shorten the crash timeout.
SessionLock.LIVE_BUSY_ATTEMPTS = 4
SessionLock.LIVE_BUSY_WINDOW_SECONDS = 30

export type Lock = {
	jobId: string,
	placeId: number,
	lockedAt: number,
	userId: number?,
}

export type Document = {
	Data: any,
	Lock: Lock?,
}

function SessionLock.isUserId(userId: any): boolean
	return type(userId) == "number" and userId == userId and userId > 0 and userId < math.huge
end

function SessionLock.claim(now: number, jobId: string, placeId: number, userId: number?): Lock
	local lock: Lock = {
		jobId = jobId,
		placeId = placeId,
		lockedAt = now,
	}
	if SessionLock.isUserId(userId) then
		lock.userId = userId :: number
	end
	return lock
end

-- Legacy locks have no userId. The key is already this player's, so a
-- missing id still counts as theirs. A stored id has to match.
function SessionLock.sameUser(lock: any, userId: number?): boolean
	if not SessionLock.isUserId(userId) then
		return false
	end
	if type(lock) ~= "table" then
		return false
	end
	local held = lock.userId
	if held == nil then
		return true
	end
	return SessionLock.isUserId(held) and held == userId
end

-- True for attempts that should wait and try again. The attempt that
-- equals LIVE_BUSY_ATTEMPTS is the last load; the caller kicks after it.
function SessionLock.liveBusyShouldRetry(attempt: number): boolean
	if type(attempt) ~= "number" or attempt ~= attempt then
		return false
	end
	return attempt < SessionLock.LIVE_BUSY_ATTEMPTS
end

-- Three gaps across four loads. 10 + 10 + 10 = 30 seconds.
function SessionLock.liveBusyPause(attempt: number): number
	if not SessionLock.liveBusyShouldRetry(attempt) then
		return 0
	end
	local gaps = SessionLock.LIVE_BUSY_ATTEMPTS - 1
	if gaps < 1 then
		return 0
	end
	return SessionLock.LIVE_BUSY_WINDOW_SECONDS / gaps
end

function SessionLock.cleared(): Lock
	return {
		jobId = "",
		placeId = 0,
		lockedAt = 0,
	}
end

function SessionLock.status(
	lock: any,
	now: number,
	jobId: string,
	timeout: number,
	userId: number?,
	studio: boolean?
): string
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
	-- Studio only. A live server keeps the 20 minute timeout above.
	if
		studio == true
		and SessionLock.sameUser(lock, userId)
		and now - lockedAt >= SessionLock.STUDIO_STEAL_SECONDS
	then
		return "expired"
	end
	return "busy"
end

function SessionLock.canClaim(
	lock: any,
	now: number,
	jobId: string,
	timeout: number,
	userId: number?,
	studio: boolean?
): boolean
	local status = SessionLock.status(lock, now, jobId, timeout, userId, studio)
	return status == "free" or status == "owned" or status == "expired"
end

function SessionLock.canWrite(lock: any, now: number, jobId: string, timeout: number): boolean
	-- A studio steal is a claim. Saving still requires the lock we hold.
	return SessionLock.status(lock, now, jobId, timeout) == "owned"
end

-- nil document means the key has never been written.
function SessionLock.tryClaim(
	document: Document?,
	now: number,
	jobId: string,
	placeId: number,
	timeout: number,
	data: any,
	userId: number?,
	studio: boolean?
): (Document?, string)
	local lock = nil
	if document ~= nil then
		lock = document.Lock
	end
	if not SessionLock.canClaim(lock, now, jobId, timeout, userId, studio) then
		return nil, "busy"
	end
	return {
		Data = data,
		Lock = SessionLock.claim(now, jobId, placeId, userId),
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
	local owner: number? = nil
	if type(document.Lock) == "table" and SessionLock.isUserId(document.Lock.userId) then
		owner = document.Lock.userId :: number
	end
	local lock = if releaseLock
		then SessionLock.cleared()
		else SessionLock.claim(now, jobId, placeId, owner)
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
