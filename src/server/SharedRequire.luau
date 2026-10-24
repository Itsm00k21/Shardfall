--!strict

--[[
	Cross-tree requires for modules under src/server.

	Studio reads ReplicatedStorage.Shared on the DataModel. A string such
	as ../ReplicatedStorage is not a child of WaveArenaSrc.server, so it
	does not resolve there. Lune has no DataModel. The same call loads the
	file beside src/server. The relative prefix is built at runtime so this
	file does not contain a require string Studio would miss.
]]

local SharedRequire = {}

local function inStudio(): boolean
	return game ~= nil and game.GetService ~= nil
end

function SharedRequire.module(path: string): any
	if inStudio() then
		local node = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		for piece in string.gmatch(path, "[^/]+") do
			node = (node :: any):WaitForChild(piece)
		end
		return require(node :: ModuleScript)
	end
	local parent = string.char(46, 46)
	return require(parent .. "/ReplicatedStorage/Shared/" .. path)
end

return SharedRequire
