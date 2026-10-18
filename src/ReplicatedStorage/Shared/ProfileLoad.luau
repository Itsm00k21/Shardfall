--!strict

--[[
	One profile read: migrate the saved document, or a session profile when
	the store throws.

	DataService adds the Studio timeout around this. A thrown UpdateAsync
	(API access off, unpublished place) must not leave the load hanging.
	The session profile is a fresh migrated template. It is not written back
	here, so a later retry cannot replace a real save with a blank one.

	A load attempt carries a generation token. DataService bumps that
	generation when CallBudget returns at the timeout, while the spawned
	UpdateAsync can still be waiting to run its transform. A transform
	whose token is no longer current returns nil. UpdateAsync then leaves
	the key unchanged: no session lock, and no Progression.applyReturn
	or lastSeen write for the attempt that was already abandoned.

	release() writes the profile and clears the session lock. handoff()
	does that before it calls teleport. A failed release does not teleport.
	If teleport throws, handoff claims the lock back when it still can, so
	the player can stay on this server. TeleportAsync can also return and
	still fail (TeleportInitFailed). The caller should error from teleport
	when that signal is already set, so the same reclaim runs. A failure
	that arrives after a successful return uses failedHop: reclaim and
	restore when this server still has the player, or kick when the lock
	was taken. A second save from the server that just released does not
	take the lock again: trySave only writes an owned lock, and a cleared
	lock is free.

	hopOnArrival is false on a reserved server (private id set, owner 0).
	Queueing from there would reserve another server and hop forever.
]]

local Progression = require("./Progression")
local Schema = require("./Schema")
local SessionLock = require("./SessionLock")

local ProfileLoad = {}

export type Adapter = {
	updateAsync: (self: Adapter, key: string, transform: (any) -> any) -> any,
}

export type Outcome = {
	data: any,
	reason: string,
	session: boolean,
	error: string?,
}

export type Release = {
	ok: boolean,
	reason: string,
	error: string?,
}

export type Handoff = {
	teleported: boolean,
	reason: string,
	error: string?,
}

-- One load attempt. current() is the caller's generation. The transform
-- writes only while current() still returns token.
export type Attempt = {
	token: number,
	current: () -> number,
}

local function attemptLive(attempt: Attempt?): boolean
	if attempt == nil then
		return true
	end
	return attempt.current() == attempt.token
end

-- BindToClose may yield until the engine shuts the process down. That
-- budget is 30 seconds. DataService used to return at 25, which is still
-- inside the window, so a slow UpdateAsync was abandoned while it held
-- the lock.
ProfileLoad.SHUTDOWN_BUDGET_SECONDS = 30

-- A second queue while the first hop is still saving. Neutral on purpose:
-- the profile save has not failed.
ProfileLoad.TELEPORT_ALREADY = "A teleport is already in progress."

-- Reclaim lost the race. The player has to rejoin the server that holds
-- the profile. Do not restore a loaded record here.
ProfileLoad.HOP_REJOIN = "The raid teleport failed and your profile could not be reopened. Rejoin."

function ProfileLoad.shutdownStillWaiting(pending: number, elapsed: number): boolean
	return pending > 0 and elapsed < ProfileLoad.SHUTDOWN_BUDGET_SECONDS
end

-- A timed-out load can still be marked loaded once the memory fallback is
-- installed. That fallback is ephemeral. Autosave and release must not
-- write it, because the store may already hold the real claimed profile.
function ProfileLoad.maySave(loaded: boolean, ephemeral: boolean): boolean
	return loaded == true and ephemeral ~= true
end

local function sessionProfile(now: number): any
	local migrated = Schema.migrate(nil)
	if migrated ~= nil then
		Progression.applyReturn(migrated, now)
	end
	return migrated
end

function ProfileLoad.open(
	adapter: Adapter,
	key: string,
	now: number,
	serverId: string,
	placeId: number,
	timeout: number,
	attempt: Attempt?
): Outcome
	local migrated = nil
	local reason = "error"
	local ok, err = pcall(function()
		adapter:updateAsync(key, function(document)
			-- Abandoned after the budget. Nil tells UpdateAsync to skip
			-- the write, so this attempt cannot claim or touch lastSeen.
			if not attemptLive(attempt) then
				reason = "abandoned"
				migrated = nil
				return nil
			end
			local source = nil
			if type(document) == "table" then
				source = Schema.deepCopy(document.Data)
			end
			local data, migrateErr = Schema.migrate(source)
			if data ~= nil then
				Progression.applyReturn(data, now)
			end
			if data == nil then
				reason = migrateErr or "corrupt"
				migrated = nil
				return nil
			end
			local written, claimReason = SessionLock.tryClaim(
				if type(document) == "table" then document else nil,
				now,
				serverId,
				placeId,
				timeout,
				Schema.deepCopy(data)
			)
			reason = claimReason
			if written == nil then
				migrated = nil
				return nil
			end
			migrated = data
			return written
		end)
	end)
	if not ok then
		return {
			data = sessionProfile(now),
			reason = "session",
			session = true,
			error = tostring(err),
		}
	end
	if migrated == nil then
		return {
			data = nil,
			reason = reason,
			session = false,
		}
	end
	return {
		data = migrated,
		reason = "claimed",
		session = false,
	}
end

local function storedDocument(document: any): SessionLock.Document?
	if type(document) == "table" then
		return document
	end
	return nil
end

function ProfileLoad.release(
	adapter: Adapter,
	key: string,
	now: number,
	serverId: string,
	placeId: number,
	timeout: number,
	data: any
): Release
	local reason = "error"
	local ok, err = pcall(function()
		adapter:updateAsync(key, function(document)
			local written, saveReason = SessionLock.trySave(
				storedDocument(document),
				now,
				serverId,
				placeId,
				timeout,
				Schema.deepCopy(data),
				true
			)
			reason = saveReason
			return written
		end)
	end)
	if not ok then
		return {
			ok = false,
			reason = "error",
			error = tostring(err),
		}
	end
	if reason ~= "saved" then
		return {
			ok = false,
			reason = reason,
		}
	end
	return {
		ok = true,
		reason = "saved",
	}
end

function ProfileLoad.reclaim(
	adapter: Adapter,
	key: string,
	now: number,
	serverId: string,
	placeId: number,
	timeout: number,
	data: any
): Release
	local reason = "error"
	local ok, err = pcall(function()
		adapter:updateAsync(key, function(document)
			local written, claimReason = SessionLock.tryClaim(
				storedDocument(document),
				now,
				serverId,
				placeId,
				timeout,
				Schema.deepCopy(data)
			)
			reason = claimReason
			return written
		end)
	end)
	if not ok then
		return {
			ok = false,
			reason = "error",
			error = tostring(err),
		}
	end
	if reason ~= "claimed" then
		return {
			ok = false,
			reason = reason,
		}
	end
	return {
		ok = true,
		reason = "claimed",
	}
end

-- Save and clear the lock, then teleport. Teleport is not called when the
-- save fails, and the stored document is left as it was. A thrown teleport
-- claims the same profile back when nobody else has taken it.
function ProfileLoad.handoff(
	adapter: Adapter,
	key: string,
	now: number,
	serverId: string,
	placeId: number,
	timeout: number,
	data: any,
	teleport: () -> ()
): Handoff
	local released = ProfileLoad.release(adapter, key, now, serverId, placeId, timeout, data)
	if not released.ok then
		return {
			teleported = false,
			reason = released.reason,
			error = released.error,
		}
	end
	local callOk, callErr = pcall(teleport)
	if callOk then
		return {
			teleported = true,
			reason = "saved",
		}
	end
	local again = ProfileLoad.reclaim(adapter, key, now, serverId, placeId, timeout, data)
	if again.ok then
		return {
			teleported = false,
			reason = "teleport",
			error = tostring(callErr),
		}
	end
	return {
		teleported = false,
		reason = "stolen",
		error = tostring(callErr),
	}
end

-- True on a public server and on a player-owned private server. False on
-- a ReserveServer instance: PrivateServerId is set and PrivateServerOwnerId
-- is 0. Receiving a raid there must launch in place.
function ProfileLoad.hopOnArrival(privateServerId: any, ownerId: any): boolean
	if type(privateServerId) ~= "string" or privateServerId == "" then
		return true
	end
	if ownerId == 0 then
		return false
	end
	return true
end

-- What to do after ProfileLoad.reclaim, once TeleportAsync has already
-- cleared the lock and the hop then failed.
--   restore  player is still here and this server owns the lock again
--   release  reclaim won but the player already left; clear that lock
--   kick     player is here and someone else owns the lock
--   drop     player is gone and this server does not own the lock
function ProfileLoad.failedHop(stillHere: boolean, reclaimed: boolean): string
	if reclaimed then
		if stillHere then
			return "restore"
		end
		return "release"
	end
	if stillHere then
		return "kick"
	end
	return "drop"
end

return ProfileLoad
