--!strict

--[[
	One profile read: migrate the saved document, or a session profile when
	the store throws.

	DataService adds the Studio timeout around this. A thrown UpdateAsync
	(API access off, unpublished place) must not leave the load hanging.
	The session profile is a fresh migrated template. It is not written back
	here, so a later retry cannot replace a real save with a blank one.
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
	timeout: number
): Outcome
	local migrated = nil
	local reason = "error"
	local ok, err = pcall(function()
		adapter:updateAsync(key, function(document)
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

return ProfileLoad
