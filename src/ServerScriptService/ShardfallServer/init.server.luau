--!strict

--[[
	Shardfall server entry.

	Order matters. Remotes are bound and the profile listener is connected
	before DataService.start(), which is what yields on DataStores and then
	tells the client the profile is ready. The listener is registered first
	so a fast in-memory load still pushes a snapshot.
]]

local DataService = require(script.DataService)
local Remotes = require(script.Remotes)

DataService.onChanged(function(player, snapshot, saving)
	Remotes.pushProfile(player, snapshot, saving)
end)

Remotes.bind()
DataService.start()
