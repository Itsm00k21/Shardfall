--!strict

--[[
	Decisions that must not depend on DataStore or on a Player.

	alreadyOpen blocks a second load of the same player on this server.
	refusesWrite is the failed-load rule: that profile is never passed to
	UpdateAsync. Ephemeral (Studio memory) sessions are refused by
	DataService before this, because a memory session may still answer
	save() without writing.
]]

local SaveGuard = {}

function SaveGuard.alreadyOpen(present: boolean): boolean
	return present == true
end

function SaveGuard.refusesWrite(failed: boolean): boolean
	return failed == true
end

return SaveGuard
