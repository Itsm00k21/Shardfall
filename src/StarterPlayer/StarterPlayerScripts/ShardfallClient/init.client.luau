--!strict

--[[
	Client entry for the test UI.

	StarterPlayerScripts runs once and copies this LocalScript into
	PlayerScripts. The ScreenGui sets ResetOnSpawn = false so a respawn does
	not delete the panel while this script keeps running.

	Buttons call RemoteFunctions. The server rolls, saves, and answers with
	the item plus a profile snapshot. ProfileUpdated covers anything that
	changed without a button press (the first load, for example).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(script.Ui)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Pools = require(shared:WaitForChild("Pools"))

local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if remotes == nil then
	warn("[Shardfall] ReplicatedStorage.Remotes did not appear. Connect Rojo, then press Play.")
	return
end

local shownLuck: number? = nil
local ui

local function invoke(name: string, ...: any)
	local remote = (remotes :: Instance):WaitForChild(name)
	assert(remote:IsA("RemoteFunction"), name .. " is not a RemoteFunction")
	return remote:InvokeServer(...)
end

local function refreshOdds()
	local ok, result = pcall(function()
		return invoke("GetOdds", Pools.STARTER_ID)
	end)
	if ok and type(result) == "table" and result.ok == true then
		ui.setOdds(result.odds)
	elseif not ok then
		ui.setStatus("Could not load odds.", "error")
	end
end

local function applyProfile(profile: any, saving: any)
	if type(profile) ~= "table" then
		return
	end
	ui.setProfile(profile, saving == true)
	if profile.shardLuck ~= shownLuck then
		shownLuck = profile.shardLuck
		refreshOdds()
	end
end

local function applyResult(result: any)
	if type(result) == "table" and type(result.profile) == "table" then
		applyProfile(result.profile, result.saving)
	end
end

ui = Ui.mount(playerGui, {
	showDev = RunService:IsStudio(),
	onCrack = function()
		ui.setBusy(true)
		ui.setStatus("Cracking a shard...", "info")
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("RollShard", Pools.STARTER_ID)
			end)
			ui.setBusy(false)
			if not ok or type(result) ~= "table" then
				ui.setStatus("Could not reach the server.", "error")
				return
			end
			applyResult(result)
			if result.ok ~= true then
				ui.setStatus(tostring(result.error or "Roll failed."), "error")
				return
			end
			ui.showRoll(result)
			local item = result.item
			local name = if type(item) == "table" then item.name else "a drop"
			ui.setStatus("Received " .. tostring(name) .. ".", "ok")
		end)
	end,
	onPaid = function()
		ui.setStatus("Checking paid-roll policy...", "info")
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("RollPaid", Pools.STARTER_ID)
			end)
			if not ok or type(result) ~= "table" then
				ui.setStatus("Could not reach the server.", "error")
				return
			end
			applyResult(result)
			local code = if type(result.code) == "string" then " (" .. result.code .. ")" else ""
			ui.setStatus(tostring(result.error or "Paid roll blocked.") .. code, "error")
		end)
	end,
	onEquip = function(uid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("EquipItem", uid)
			end)
			if not ok or type(result) ~= "table" then
				ui.setStatus("Could not equip that.", "error")
				return
			end
			applyResult(result)
			if result.ok ~= true then
				ui.setStatus(tostring(result.error or "Could not equip that."), "error")
				return
			end
			ui.setStatus("Equipped.", "ok")
		end)
	end,
	onUnequip = function(uid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("UnequipItem", uid)
			end)
			if not ok or type(result) ~= "table" then
				ui.setStatus("Could not unequip that.", "error")
				return
			end
			applyResult(result)
			if result.ok ~= true then
				ui.setStatus(tostring(result.error or "Could not unequip that."), "error")
				return
			end
			ui.setStatus("Unequipped.", "ok")
		end)
	end,
	onRemove = function(uid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("RemoveItem", uid)
			end)
			if not ok or type(result) ~= "table" then
				ui.setStatus("Could not drop that.", "error")
				return
			end
			applyResult(result)
			if result.ok ~= true then
				ui.setStatus(tostring(result.error or "Could not drop that."), "error")
				return
			end
			ui.setStatus("Dropped " .. tostring(result.removedName or "item") .. ".", "ok")
		end)
	end,
	onDev = function(kind: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("DevGrant", kind)
			end)
			if not ok or type(result) ~= "table" then
				ui.setStatus("Dev grant failed.", "error")
				return
			end
			applyResult(result)
			if result.ok ~= true then
				ui.setStatus(tostring(result.error or "Dev grant failed."), "error")
				return
			end
			ui.setStatus("Dev grant applied. Odds follow Shard Luck.", "ok")
		end)
	end,
})

local profileEvent = (remotes :: Instance):WaitForChild("ProfileUpdated")
if profileEvent:IsA("RemoteEvent") then
	profileEvent.OnClientEvent:Connect(function(profile, saving)
		applyProfile(profile, saving)
	end)
end

task.spawn(function()
	local ok, result = pcall(function()
		return invoke("GetProfile")
	end)
	if not ok or type(result) ~= "table" or result.ok ~= true then
		ui.setStatus("Could not load your profile. Read the Output window.", "error")
		refreshOdds()
		return
	end
	applyProfile(result.profile, result.saving)
end)
