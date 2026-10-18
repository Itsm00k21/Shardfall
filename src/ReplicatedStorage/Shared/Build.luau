--!strict

--[[
	The stamp printed at startup.

	Playtest Output has to show this exact id. If it does not, Studio is
	running a script that is not this repo. Keep the literal in
	init.server.luau and init.client.luau identical to STAMP.
]]

local Build = {}

Build.STAMP = "e98f84e+"

function Build.line(side: string): string
	return string.format("[Shardfall] build %s %s", Build.STAMP, side)
end

return Build
