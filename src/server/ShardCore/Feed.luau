--!strict

--[[
	Spend Essence to raise one weapon's Shard Core by 1.

	Writes profile.gearEssence and profile.shardCores[uid] only.
	The item table is not changed. Equipped gear is not changed.
	Gold is not spent. There is no pet feeder.
]]

local Validate = require("./Validate")

local Feed = {}

function Feed.view(profile: any, selectedUid: any, config: any): any
	local state = config.preview(profile, selectedUid)
	state.ok = true
	return state
end

function Feed.apply(profile: any, itemId: any, config: any): (boolean, string?, any?)
	local reason = Validate.feed(profile, itemId, config)
	if reason ~= nil then
		return false, reason, nil
	end
	local level = config.levelOf(profile, itemId)
	local cost = config.costToNext(level)
	local essence = config.essenceOf(profile)
	if type(profile.shardCores) ~= "table" then
		profile.shardCores = {}
	end
	profile.gearEssence = essence - cost
	profile.shardCores[itemId] = level + 1
	local view = Feed.view(profile, itemId, config)
	view.spent = cost
	view.level = level + 1
	return true, nil, view
end

return Feed
