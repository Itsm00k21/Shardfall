--!strict

--[[
	Small-Bag specs still open the page oneInventory retires. Pin that
	flag off for the case, then put the caller's value back so a local
	flags-on run is unchanged for the next case.
]]

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

local function wrap(register: (string, () -> ()) -> ()): (string, () -> ()) -> ()
	return function(name: string, fn: () -> ())
		register(name, function()
			local previous = LaunchGate.SHOW.oneInventory
			LaunchGate.SHOW.oneInventory = false
			local ok, err = xpcall(fn, function(inner)
				return debug.traceback(tostring(inner), 2)
			end)
			LaunchGate.SHOW.oneInventory = previous
			if not ok then
				error(err, 0)
			end
		end)
	end
end

return wrap
