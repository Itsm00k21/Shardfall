--!strict

--[[
	Shard Core remote handlers. No Player, no DataStore. The binder
	passes the profile reads and writes.

	Order: rate limit, LaunchGate.shardCore, then argument checks,
	then the profile. A closed gate does not read or write a save.
]]

local Feed = require("./Feed")
local GearSalvage = require("../../ReplicatedStorage/Shared/GearSalvage")
local Rate = require("./Rate")
local Validate = require("./Validate")

local Remotes = {}

Remotes.RULE = table.freeze({ capacity = 4, perSecond = 1 })

local ACTIONS = {
	GetShardCore = true,
	FeedShardCore = true,
}

local function fail(message: string)
	return { ok = false, error = message }
end

local function userOk(userId: any): boolean
	return type(userId) == "number"
		and userId == userId
		and userId >= 1
		and userId < math.huge
		and math.floor(userId) == userId
end

function Remotes.handle(request: any, deps: any, buckets: any): any
	if type(request) ~= "table" or type(deps) ~= "table" then
		return fail(Validate.PROFILE)
	end
	local action = request.action
	if type(action) ~= "string" or ACTIONS[action] ~= true then
		return fail(Validate.ID)
	end
	if not userOk(request.userId) then
		return fail(Validate.PROFILE)
	end
	local allowed = Rate.take(buckets, request.userId, action, request.now, Remotes.RULE)
	if not allowed then
		return fail(Validate.SLOW)
	end
	if type(deps.coreOn) ~= "function" or deps.coreOn() ~= true then
		return fail(Validate.OFF)
	end
	if type(deps.ctx) ~= "table" or type(deps.ctx.config) ~= "table" then
		return fail(Validate.PROFILE)
	end
	local config = deps.ctx.config
	if action == "GetShardCore" then
		local profile = deps.read(request.userId)
		if type(profile) ~= "table" then
			return fail(Validate.PROFILE)
		end
		local view = Feed.view(profile, nil, config)
		local help = GearSalvage.takeHelp(request.userId)
		if help ~= nil then
			view.help = help
		end
		return view
	end
	local args = request.args
	if type(args) ~= "table" then
		args = {}
	end
	local itemId = args[1]
	if type(config.validId) ~= "function" or config.validId(itemId) ~= true then
		return fail(Validate.ID)
	end
	local view = nil
	local reason = nil
	local ok, err = deps.mutate(request.userId, function(profile)
		local wrote, why, result = Feed.apply(profile, itemId, config)
		if not wrote then
			reason = why
			return why or Validate.UPDATE
		end
		view = result
		return nil
	end)
	if not ok then
		return fail(reason or err or Validate.UPDATE)
	end
	if type(deps.changed) == "function" and type(view) == "table" then
		deps.changed(request.userId, view)
	end
	return view
end

return Remotes
