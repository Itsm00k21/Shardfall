--!strict

--[[
	The one loader for SharedRequire.

	Studio reaches this module from script (the server folder under
	WaveArenaSrc) and then reads ReplicatedStorage.Shared. Lune has no
	script. This file sits beside SharedRequire, so the sibling require
	is a fixed path and does not read the caller's source.
]]

local SharedRequire
if game ~= nil and game.GetService ~= nil then
	local server = script.Parent
	if server == nil then
		error("SharedRequire is not under server")
	end
	SharedRequire = require(server:WaitForChild("SharedRequire"))
else
	SharedRequire = require("./SharedRequire")
end

return SharedRequire
