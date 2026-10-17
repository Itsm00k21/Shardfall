--!strict

--[[
	Studio jump actions that only change the profile.

	Teleport and boss phase stay in DebugService. This module is the part
	the tests can run without a server.
]]

local DebugTools = {}

function DebugTools.apply(data, action: string): (boolean, string)
	if action == "level" then
		data.level = 20
		data.xp = 0
		return true, "Level 20."
	end
	if action == "gold" then
		data.gold = (data.gold or 0) + 1000
		return true, "+1000 gold."
	end
	if action == "keys" then
		data.shardKeys = (data.shardKeys or 0) + 20
		return true, "+20 Shard Keys."
	end
	if action == "gems" then
		data.gems = (data.gems or 0) + 50
		return true, "+50 gems."
	end
	if action == "dust" then
		data.shardDust = (data.shardDust or 0) + 50
		return true, "+50 dust."
	end
	if action == "tokens" then
		data.eventTokens = (data.eventTokens or 0) + 10
		return true, "+10 event tokens."
	end
	if action == "chest" then
		if type(data.chests) ~= "table" then
			data.chests = {}
		end
		data.chests.Rare = (data.chests.Rare or 0) + 1
		return true, "+1 Rare chest."
	end
	if action == "eggs" then
		data.eggs = (data.eggs or 0) + 1
		return true, "+1 egg."
	end
	return false, "Unknown debug action."
end

return DebugTools
