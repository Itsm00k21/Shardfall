--!strict

--[[
	Lune resolves ./SharedRoot from a module in this folder. That file is
	this forwarder. Studio callers use the server folder's SharedRoot
	instead, through script.
]]

if game ~= nil and game.GetService ~= nil then
	local parent = script.Parent
	local server = if parent ~= nil then parent.Parent else nil
	if server == nil then
		error("SharedRequire is not under server")
	end
	local real = server:FindFirstChild("SharedRoot")
	if real == nil or real == script then
		error("SharedRequire is not under server")
	end
	return require(real)
end

local parent = string.char(46, 46)
return require(parent .. "/SharedRoot")
