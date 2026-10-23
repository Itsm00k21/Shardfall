--!strict

--[[
	How many times to wait DataService's base delay before the next
	DataStore attempt. Attempt 1 waits once, then 2, then 4, then the
	count stays at 4 so a dead store cannot stall a join forever.

	Writes retry thrown calls and a transform that never reported a
	result. A lost or missing lock is not retried: another server owns
	the profile, and writing again could take it back.
]]

local SaveRetry = {}

SaveRetry.WRITE_ATTEMPTS = 3

function SaveRetry.pauses(attempt: number): number
	if type(attempt) ~= "number" or attempt ~= attempt or attempt < 1 then
		return 1
	end
	local shift = math.floor(attempt) - 1
	if shift > 2 then
		shift = 2
	end
	local pauses = 1
	for _ = 1, shift do
		pauses *= 2
	end
	return pauses
end

function SaveRetry.seconds(attempt: number, base: number): number
	local unit = base
	if type(unit) ~= "number" or unit ~= unit or unit < 0 or unit >= math.huge then
		unit = 0
	end
	return SaveRetry.pauses(attempt) * unit
end

function SaveRetry.shouldRetry(attempt: number, maxAttempts: number, reason: string): boolean
	if type(attempt) ~= "number" or type(maxAttempts) ~= "number" or attempt >= maxAttempts then
		return false
	end
	return reason == "error" or reason == "unwritten"
end

return SaveRetry
