--!strict

--[[
	One PolicyService lookup per join, then a cache.

	Paid remotes read the cache and fail closed when it is missing or the
	lookup errored. A Studio dev toggle can force the restricted path without
	changing the live account. Clearing it asks PolicyService again.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PaidRollPolicy = require(ReplicatedStorage.Shared.PaidRollPolicy)

local PolicyCache = {}

export type PublicPolicy = {
	ready: boolean,
	restricted: boolean,
	tradingAllowed: boolean,
	paidRolls: boolean,
	simulated: boolean,
	message: string?,
}

type Row = {
	ready: boolean,
	restricted: boolean,
	tradingAllowed: boolean,
	simulated: boolean,
}

local rows: { [Player]: Row } = {}
local overrideRestricted: { [Player]: boolean } = {}
local generation: { [Player]: number } = {}
local listeners: { (Player, PublicPolicy) -> () } = {}

local CHECKING = "Checking purchase policy..."

function PolicyCache.public(player: Player): PublicPolicy
	local row = rows[player]
	local simulated = overrideRestricted[player] == true
	if row == nil or row.ready ~= true then
		return {
			ready = false,
			restricted = true,
			tradingAllowed = false,
			paidRolls = false,
			simulated = simulated,
			message = CHECKING,
		}
	end
	local paid = row.restricted ~= true
	return {
		ready = true,
		restricted = row.restricted,
		tradingAllowed = row.tradingAllowed,
		paidRolls = paid,
		simulated = row.simulated,
		message = if paid then nil else PaidRollPolicy.REGION_MESSAGE,
	}
end

local function emit(player: Player)
	local view = PolicyCache.public(player)
	for _, listener in ipairs(listeners) do
		task.spawn(listener, player, view)
	end
end

function PolicyCache.onChanged(listener: (Player, PublicPolicy) -> ())
	table.insert(listeners, listener)
end

function PolicyCache.refresh(player: Player)
	generation[player] = (generation[player] or 0) + 1
	local token = generation[player]
	if overrideRestricted[player] == true then
		rows[player] = {
			ready = true,
			restricted = true,
			tradingAllowed = false,
			simulated = true,
		}
		emit(player)
		return
	end

	local lookupOk, policyInfo = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if player.Parent == nil or generation[player] ~= token then
		return
	end
	if overrideRestricted[player] == true then
		rows[player] = {
			ready = true,
			restricted = true,
			tradingAllowed = false,
			simulated = true,
		}
		emit(player)
		return
	end

	local read = PaidRollPolicy.read(if lookupOk then policyInfo else nil)
	if read.ok then
		rows[player] = {
			ready = true,
			restricted = read.restricted,
			tradingAllowed = read.tradingAllowed,
			simulated = false,
		}
	else
		rows[player] = {
			ready = false,
			restricted = true,
			tradingAllowed = false,
			simulated = false,
		}
	end
	emit(player)
end

function PolicyCache.ensure(player: Player)
	local row = rows[player]
	if row ~= nil and row.ready == true then
		return
	end
	PolicyCache.refresh(player)
end

-- true when this player may see and use paid random items.
function PolicyCache.allowPaid(player: Player): (boolean, string, string)
	PolicyCache.ensure(player)
	local view = PolicyCache.public(player)
	if view.ready ~= true then
		return false, "Could not check purchase policy. Try again.", "policy_unavailable"
	end
	if view.paidRolls ~= true then
		return false, view.message or PaidRollPolicy.REGION_MESSAGE, "restricted"
	end
	return true, "", "allowed"
end

function PolicyCache.setSimulatedRestriction(player: Player, restricted: boolean): boolean
	if not RunService:IsStudio() then
		return false
	end
	if restricted then
		overrideRestricted[player] = true
	else
		overrideRestricted[player] = nil
		rows[player] = nil
	end
	PolicyCache.refresh(player)
	return true
end

function PolicyCache.start()
	local function hook(player: Player)
		task.spawn(function()
			if player.Parent == nil then
				return
			end
			PolicyCache.refresh(player)
		end)
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		rows[player] = nil
		overrideRestricted[player] = nil
		generation[player] = nil
	end)
end

return PolicyCache
