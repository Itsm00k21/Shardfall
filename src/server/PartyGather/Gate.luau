--!strict

--[[
	LaunchGate.parties is the only switch. A missing key is off.
	SHOW.parties is the live field. A direct `parties` field is the
	test alias. Both ship false.
]]

local Gate = {}

function Gate.open(launchGate: any): boolean
	if typeof(launchGate) ~= "table" then
		return false
	end
	if (launchGate :: any).parties == true then
		return true
	end
	local show = (launchGate :: any).SHOW
	if typeof(show) == "table" and show.parties == true then
		return true
	end
	return false
end

return Gate
