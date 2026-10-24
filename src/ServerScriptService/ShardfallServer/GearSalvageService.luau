--!strict

--[[
	Player entry for Stage B salvage.

	LaunchGate.gearSalvage is off until Kevin flips it. While it is off
	every call returns before a profile write. The client never chooses
	the Essence amount. Roll's "Salvage now" is nudge (preview, no
	delete) then salvageNow (the confirm token).

	nudge and salvageNow are the API Ghost can call from the Roll tab.
	They are not a second remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local GearSalvage = require(ReplicatedStorage.Shared.GearSalvage)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)

local GearSalvageService = {}

local function closed()
	return { ok = false, error = "That is closed." }
end

function GearSalvageService.handle(player: Player, action: any, payload: any)
	if not LaunchGate.on("gearSalvage") then
		return closed()
	end
	if typeof(player) ~= "Instance" or player:IsA("Player") ~= true then
		return { ok = false, error = "Profile is not loaded." }
	end
	local body = if type(payload) == "table" then payload else {}
	local now = os.time()
	if GearSalvage.isRead(action) then
		local data = DataService.get(player)
		if data == nil then
			return { ok = false, error = "Profile is not loaded." }
		end
		return GearSalvage.applyAction(data, player.UserId, action, body, now)
	end
	local outcome = nil
	local ok, err = DataService.mutate(player, function(data)
		outcome = GearSalvage.applyAction(data, player.UserId, action, body, now)
		if type(outcome) ~= "table" or outcome.ok ~= true then
			local why = "Could not salvage that."
			if type(outcome) == "table" and type(outcome.error) == "string" then
				why = outcome.error
			end
			return why
		end
		return nil
	end)
	if not ok then
		return { ok = false, error = err or "Could not salvage that." }
	end
	return outcome
end

-- Preview only. Deletes nothing. Roll shows the count, then salvageNow.
function GearSalvageService.nudge(player: Player, rarity: any)
	local payload = {}
	if rarity ~= nil then
		payload.rarity = rarity
	end
	return GearSalvageService.handle(player, "nudge", payload)
end

-- The confirm token from nudge or preview. A missing token deletes nothing.
function GearSalvageService.salvageNow(player: Player, token: any)
	return GearSalvageService.handle(player, "salvageNow", { token = token })
end

return GearSalvageService
