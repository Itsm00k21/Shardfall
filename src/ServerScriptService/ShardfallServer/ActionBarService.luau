--!strict

--[[
	Saves the action bar and uses one slot.

	Use calls the existing skill cast or tonic drink. The client does not
	choose the effect. A locked skill, a cooldown, and a missing tonic are
	refused here before anything lands.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionSlots = require(ReplicatedStorage.Shared.ActionSlots)
local ClassService = require(script.Parent.ClassService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)

local ActionBarService = {}

local tonicReady: { [Player]: number } = {}

local function coolingMessage(text: string): string
	if string.find(text, "cooling", 1, true) ~= nil then
		return "On cooldown"
	end
	return text
end

function ActionBarService.drink(player: Player): { [string]: any }
	local now = os.clock()
	local ready = tonicReady[player] or 0
	if now < ready then
		return {
			ok = false,
			error = "On cooldown",
			cooldown = ready - now,
		}
	end
	local result = CombatService.useTonic(player)
	if type(result) == "table" and result.ok == true then
		tonicReady[player] = now + ActionSlots.TONIC_COOLDOWN
		result.cooldown = ActionSlots.TONIC_COOLDOWN
	end
	return result
end

function ActionBarService.set(player: Player, classId: any, slots: any, locked: any): { [string]: any }
	if type(classId) ~= "string" then
		return { ok = false, error = "Pick a class at the Forge." }
	end
	local profile = DataService.get(player)
	if profile == nil then
		return { ok = false, error = "Profile is still loading." }
	end
	local bar, why = ActionSlots.accept(classId, slots, locked, profile)
	if bar == nil then
		return { ok = false, error = why or "The bar needs 8 slots." }
	end
	local saved, err = DataService.mutate(player, function(data)
		if type(data.actionBars) ~= "table" then
			data.actionBars = {}
		end
		data.actionBars[classId] = bar
		return nil
	end)
	if not saved then
		return { ok = false, error = err or "Could not save the bar." }
	end
	return { ok = true }
end

function ActionBarService.use(player: Player, index: any): { [string]: any }
	if type(index) ~= "number" then
		return { ok = false, error = "That slot is empty." }
	end
	local slotIndex = math.floor(index)
	if slotIndex < 1 or slotIndex > ActionSlots.COUNT then
		return { ok = false, error = "That slot is empty." }
	end
	local profile = DataService.get(player)
	if profile == nil then
		return { ok = false, error = "Profile is still loading." }
	end
	local classId = profile.classId
	if type(classId) ~= "string" or classId == "" then
		return { ok = false, error = "Pick a class at the Forge." }
	end
	local bar = ActionSlots.repair(classId, ActionSlots.barFor(profile.actionBars, classId), profile)
	local slot = bar.slots[slotIndex]
	if slot == nil or slot.kind == "empty" then
		return { ok = false, error = "That slot is empty." }
	end
	if slot.kind == "skill" then
		local reason = ActionSlots.block(classId, slot, profile, false, true)
		if reason ~= nil then
			return { ok = false, error = reason }
		end
		if not RateLimiter.take(player.UserId, "UseSkill") then
			return { ok = false, error = "Slow down a moment." }
		end
		local cast = ActionSlots.castKey(classId, slot.id)
		local result = ClassService.cast(player, cast)
		if type(result) ~= "table" then
			return { ok = false, error = "Could not use that skill." }
		end
		if result.ok ~= true then
			local message = coolingMessage(tostring(result.error or "Could not use that skill."))
			local key = if cast == "ult" then "ult" else tostring(cast)
			local left = ClassService.cooldownLeft(player, key)
			if message == "On cooldown" and left > 0 then
				result.cooldown = left
			end
			result.error = message
			return result
		end
		local skillLeft = ClassService.cooldownLeft(player, if cast == "ult" then "ult" else tostring(cast))
		if skillLeft > 0 then
			result.cooldown = skillLeft
		end
		return result
	end
	if slot.kind == "consumable" then
		local reason = ActionSlots.block(classId, slot, profile, false, true)
		if reason ~= nil then
			return { ok = false, error = reason }
		end
		if not RateLimiter.take(player.UserId, "UseTonic") then
			return { ok = false, error = "Slow down a moment." }
		end
		return ActionBarService.drink(player)
	end
	if slot.kind == "item" then
		local reason = ActionSlots.block(classId, slot, profile, false, true)
		if reason ~= nil then
			return { ok = false, error = reason }
		end
		local item = profile.inventory[slot.id]
		if item == nil and type(profile.pets) == "table" then
			item = profile.pets[slot.id]
		end
		if type(item) == "table" and (item.kind == "Consumable" or item.templateId == "healing_tonic") then
			if not RateLimiter.take(player.UserId, "UseTonic") then
				return { ok = false, error = "Slow down a moment." }
			end
			return ActionBarService.drink(player)
		end
		return { ok = false, error = "That item cannot be used." }
	end
	return { ok = false, error = "That slot is empty." }
end

Players.PlayerRemoving:Connect(function(player)
	tonicReady[player] = nil
end)

return ActionBarService
