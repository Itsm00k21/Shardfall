--!strict

--[[
	Run a DataStore call without letting it stall the server.

	Studio with API access off sometimes never resumes UpdateAsync. A
	budget returns "timed out" so the caller can fall back to memory.
	The callback may still finish later; callers must ignore that result.
]]

local CallBudget = {}

CallBudget.DATASTORE_SECONDS = 4

function CallBudget.run(seconds: number, callback: () -> any): (boolean, any)
	local state = {
		done = false,
		ok = false,
		value = nil :: any,
	}
	task.spawn(function()
		local ok, value = pcall(callback)
		state.ok = ok
		state.value = value
		state.done = true
	end)
	local deadline = os.clock() + seconds
	while not state.done and os.clock() < deadline do
		task.wait(0.05)
	end
	if not state.done then
		return false, "timed out"
	end
	if not state.ok then
		return false, state.value
	end
	return true, state.value
end

return CallBudget
