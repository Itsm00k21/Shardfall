--!strict

--[[
	Studio-only jumps. Outside Studio every action refuses, and inside
	Studio only the game owner may use them (DevAccess, Oct 22 2026).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DebugTools = require(ReplicatedStorage.Shared.DebugTools)
local DevAccess = require(ReplicatedStorage.Shared.DevAccess)
local DataService = require(script.Parent.DataService)

local DebugService = {}

local function reject(message: string)
	return { ok = false, error = message }
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
	if action == "dungeon" then
		local DungeonService = require(script.Parent.DungeonService)
		DungeonService.leave(player)
		return DungeonService.enter(player, "rootvault", "normal")
	end
	if action == "raid" then
		local DungeonService = require(script.Parent.DungeonService)
		local RaidService = require(script.Parent.RaidService)
		DungeonService.leave(player)
		return RaidService.practice(player, 1, 1)
	end
	if action == "phase" then
		local DungeonService = require(script.Parent.DungeonService)
		return DungeonService.setBossPhase(player, 2)
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
	return { ok = true, note = note, profile = DataService.snapshot(player) }
end

return DebugService
