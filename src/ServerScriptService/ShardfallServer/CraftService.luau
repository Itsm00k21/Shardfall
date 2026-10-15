--!strict

--[[
	Turns a recipe id into a profile change.

	Crafting.commit does the validation. This wrapper is what the remote
	calls, so the spend and the reward share one DataService.mutate. A
	rejected craft gives the materials back.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crafting = require(ReplicatedStorage.Shared.Crafting)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local DataService = require(script.Parent.DataService)

local CraftService = {}

local function reject(message: string)
	return { ok = false, error = message }
end

function CraftService.craft(player: Player, recipeId: any, targetUid: string?)
	if
		type(recipeId) ~= "string"
		or string.match(recipeId, "^[%w_]+$") == nil
		or #recipeId > 64
	then
		return reject("Unknown recipe.")
	end

	local captured: any = nil
	local ok, err = DataService.mutate(player, function(data)
		local summary, reason = Crafting.commit(
			data,
			recipeId,
			targetUid,
			RollMath.defaultRng(),
			HttpService:GenerateGUID(false),
			os.time()
		)
		if reason ~= nil or summary == nil then
			return reason or "Could not craft that."
		end
		captured = summary
		return nil
	end)
	if not ok or captured == nil then
		return reject(err or "Could not craft that.")
	end

	return {
		ok = true,
		craft = {
			recipeId = captured.recipeId,
			name = captured.name,
			rerolled = captured.rerolled == true,
			consumable = captured.consumable,
		},
	}
end

return CraftService
