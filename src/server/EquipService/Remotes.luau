--!strict

--[[
	Equip remote handlers. No Player, no DataStore. The binder passes
	the profile reads and writes.

	Order: rate limit, LaunchGate.equip, then argument checks, then
	the profile. A closed gate does not read or write a save. A bad
	argument does not either.
]]

local EquipService = require("./EquipService")
local Rate = require("./Rate")
local Validate = require("./Validate")

local Remotes = {}

Remotes.RULE = table.freeze({ capacity = 6, perSecond = 3 })

local ACTIONS = {
	EquipSlot = true,
	UnequipSlot = true,
	GetEquip = true,
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
		return fail(Validate.UNKNOWN_SLOT)
	end
	if not userOk(request.userId) then
		return fail(Validate.PROFILE)
	end
	local allowed = Rate.take(buckets, request.userId, action, request.now, Remotes.RULE)
	if not allowed then
		return fail(Validate.SLOW)
	end
	if type(deps.equipOn) ~= "function" or deps.equipOn() ~= true then
		return fail(Validate.OFF)
	end
	local args = request.args
	if type(args) ~= "table" then
		args = {}
	end
	if action == "GetEquip" then
		local profile = deps.read(request.userId)
		if type(profile) ~= "table" then
			return fail(Validate.PROFILE)
		end
		return EquipService.view(profile, deps.ctx)
	end
	local slotId = args[1]
	if type(slotId) ~= "string" or deps.ctx.slots.LIST[slotId] == nil then
		return fail(Validate.UNKNOWN_SLOT)
	end
	local itemId = nil
	if action == "EquipSlot" then
		itemId = args[2]
		if not Validate.validId(itemId) then
			return fail(Validate.MISSING)
		end
	end
	local view = nil
	local reason = nil
	local ok, err = deps.mutate(request.userId, function(profile)
		local wrote, why, result
		if action == "EquipSlot" then
			wrote, why, result = EquipService.equip(profile, slotId, itemId, deps.ctx)
		else
			wrote, why, result = EquipService.unequip(profile, slotId, deps.ctx)
		end
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
