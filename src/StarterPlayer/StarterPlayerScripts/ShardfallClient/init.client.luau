--!strict

--[[
	Client entry for the test UI.

	StarterPlayerScripts runs once and copies this LocalScript into
	PlayerScripts. The ScreenGui sets ResetOnSpawn = false so a respawn does
	not delete the panel while this script keeps running.

	Buttons call RemoteFunctions. The server rolls, saves, and answers with
	the item plus a profile snapshot. ProfileUpdated covers anything that
	changed without a button press (the first load, for example).

	The pool id comes from the selected roll area (Areas.luau). With one
	area that is the starter shard. Adding an area there is what the Crack
	button and the odds popup follow.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(script.Ui)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(shared:WaitForChild("Areas"))
local areaList = Areas.all()
local firstArea = areaList[1]
local selectedPoolId = if firstArea ~= nil then firstArea.poolId else "starter_shard"

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

-- nil when the remote succeeded. Otherwise the text to show, also warned
-- on the client so Output is not empty when a button appears to do nothing.
local function remoteError(ok: boolean, result: any, fallback: string): string?
	if not ok then
		local message = tostring(result)
		warn("[Shardfall] " .. message)
		return message
	end
	if type(result) ~= "table" then
		local message = fallback .. " (remote returned " .. typeof(result) .. ")"
		warn("[Shardfall] " .. message)
		return message
	end
	if result.ok ~= true then
		local message = tostring(result.error or fallback)
		warn("[Shardfall] " .. message)
		return message
	end
	return nil
end

local function refreshOdds()
	local ok, result = pcall(function()
		return invoke("GetOdds", selectedPoolId)
	end)
	local message = remoteError(ok, result, "Could not load odds.")
	if message ~= nil then
		ui.setStatus(message, "error")
		ui.setNotice(message)
		return
	end
	ui.setOdds((result :: any).odds)
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
				return invoke("RollShard", selectedPoolId)
			end)
			ui.setBusy(false)
			local message = remoteError(ok, result, "Roll failed.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.showRoll(result)
			local item = (result :: any).item
			local name = if type(item) == "table" then item.name else "a drop"
			ui.setStatus("Received " .. tostring(name) .. ".", "ok")
		end)
	end,
	onPaid = function()
		ui.setStatus("Checking paid-roll policy...", "info")
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("RollPaid", selectedPoolId)
			end)
			local message = remoteError(ok, result, "Paid roll blocked.")
			if type(result) == "table" and type(result.code) == "string" and message ~= nil then
				message ..= " (" .. result.code .. ")"
			end
			if message ~= nil then
				ui.setStatus(message, "error")
			end
			if ok and type(result) == "table" then
				applyResult(result)
			end
		end)
	end,
	onEquip = function(uid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("EquipItem", uid)
			end)
			local message = remoteError(ok, result, "Could not equip that.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus("Equipped.", "ok")
		end)
	end,
	onUnequip = function(uid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("UnequipItem", uid)
			end)
			local message = remoteError(ok, result, "Could not unequip that.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus("Unequipped.", "ok")
		end)
	end,
	onRemove = function(uid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("RemoveItem", uid)
			end)
			local message = remoteError(ok, result, "Could not drop that.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus("Dropped " .. tostring((result :: any).removedName or "item") .. ".", "ok")
		end)
	end,
	onDev = function(kind: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("DevGrant", kind)
			end)
			local message = remoteError(ok, result, "Dev grant failed.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus("Dev grant applied. Odds follow Shard Luck.", "ok")
		end)
	end,
	onArea = function(poolId: string)
		selectedPoolId = poolId
		refreshOdds()
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
	local message = remoteError(ok, result, "Could not load your profile.")
	if message ~= nil then
		ui.setStatus(message, "error")
		refreshOdds()
		return
	end
	applyProfile((result :: any).profile, (result :: any).saving)
end)
