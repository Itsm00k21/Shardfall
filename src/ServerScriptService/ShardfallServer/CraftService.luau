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
local Economy = require(ReplicatedStorage.Shared.Economy)
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
			xp = captured.xp,
			craftingLevel = captured.craftingLevel,
		},
	}
end

function CraftService.salvage(player: Player, targetUid: any)
	if
		type(targetUid) ~= "string"
		or string.match(targetUid, "^[%w%-]+$") == nil
		or #targetUid > 64
	then
		return reject("You do not have that item.")
	end
	local captured: any = nil
	local ok, err = DataService.mutate(player, function(data)
		local summary, reason = Crafting.salvage(data, targetUid, os.time())
		if reason ~= nil or summary == nil then
			return reason or "Could not salvage that."
		end
		captured = summary
		return nil
	end)
	if not ok or captured == nil then
		return reject(err or "Could not salvage that.")
	end
	return {
		ok = true,
		salvage = {
			name = captured.name,
			xp = captured.xp,
			craftingLevel = captured.craftingLevel,
		},
	}
end

function CraftService.salvageRarity(player: Player, rarity: any)
	if type(rarity) ~= "string" or string.match(rarity, "^[%w]+$") == nil or #rarity > 32 then
		return reject("Unknown rarity.")
	end
	local captured: any = nil
	local ok, err = DataService.mutate(player, function(data)
		local summary, reason = Crafting.salvageRarity(data, rarity, os.time())
		if reason ~= nil or summary == nil then
			return reason or "Could not salvage that."
		end
		captured = summary
		return nil
	end)
	if not ok or captured == nil then
		return reject(err or "Could not salvage that.")
	end
	return {
		ok = true,
		bulk = {
			count = captured.count,
			xp = captured.xp,
			rarity = captured.rarity,
			craftingLevel = captured.craftingLevel,
		},
	}
end

function CraftService.upgrade(player: Player, uid: any)
	if type(uid) ~= "string" or uid == "" then
		return reject("Pick a piece of gear.")
	end
	local note = ""
	local ok, err = DataService.mutate(player, function(data)
		local item = data.inventory[uid]
		local upgraded, reason = Economy.upgrade(item, data)
		if not upgraded then
			return reason
		end
		note = reason
		return nil
	end)
	if not ok then
		return reject(err or "Could not upgrade that.")
	end
	return { ok = true, note = note, profile = DataService.snapshot(player) }
end

return CraftService
