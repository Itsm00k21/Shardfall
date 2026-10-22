--!strict

--[[
	Studio-only jumps. Outside Studio every action refuses, and inside
	Studio only the game owner may use them (DevAccess, Oct 22 2026).

	Every answer carries one line for the Dev Tools toast: `message` on
	success, `error` on a refusal. An action whose system is parked in
	LaunchGate is refused with DevTools.offMessage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DebugTools = require(ReplicatedStorage.Shared.DebugTools)
local DevAccess = require(ReplicatedStorage.Shared.DevAccess)
local DevTools = require(ReplicatedStorage.Shared.DevTools)
local DataService = require(script.Parent.DataService)

local DebugService = {}

local function reject(message: string)
	return { ok = false, error = message }
end

-- A success from another service gets the toast line it lacks.
local function withMessage(result: any, message: string)
	if type(result) == "table" and result.ok == true and result.message == nil then
		result.message = message
	end
	return result
end

function DebugService.run(player: Player, action: any)
	if not RunService:IsStudio() then
		return reject("Dev tools only work in Studio.")
	end
	if not DevAccess.player(player) then
		return reject(DevAccess.DENIED)
	end
	if type(action) ~= "string" then
		return reject("Unknown debug action.")
	end
	local off = DevTools.blocked("Debug", action)
	if off ~= nil then
		return reject(off)
	end
	if action == "dungeon" then
		local DungeonService = require(script.Parent.DungeonService)
		DungeonService.leave(player)
		return withMessage(DungeonService.enter(player, "rootvault", "normal"), "Entered the Rootvault.")
	end
	if action == "raid" then
		local DungeonService = require(script.Parent.DungeonService)
		local RaidService = require(script.Parent.RaidService)
		DungeonService.leave(player)
		return withMessage(RaidService.practice(player, 1, 1), "Raid practice started.")
	end
	if action == "phase" then
		local DungeonService = require(script.Parent.DungeonService)
		return withMessage(DungeonService.setBossPhase(player, 2), "Boss set to phase 2.")
	end
	local note = ""
	local ok, err = DataService.mutate(player, function(data)
		local applied, text = DebugTools.apply(data, action)
		if not applied then
			return text
		end
		note = text
		return nil
	end)
	if not ok then
		return reject(err or "Could not do that.")
	end
	return { ok = true, message = note, note = note, profile = DataService.snapshot(player) }
end

return DebugService
