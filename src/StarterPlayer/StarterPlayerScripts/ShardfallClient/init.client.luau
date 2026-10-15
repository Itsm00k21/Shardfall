--!strict

--[[
	Client entry for the test UI.

	StarterPlayerScripts runs once and copies this LocalScript into
	PlayerScripts. The ScreenGui sets ResetOnSpawn = false so a respawn does
	not delete the panel while this script keeps running.

	Buttons call RemoteFunctions. The server rolls, saves, and answers with
	the item plus a profile snapshot. ProfileUpdated covers anything that
	changed without a button press (the first load, for example).

	The pool id is the realm selected in the current roll area. Armory and
	Pets are separate. A realm above the player's ascension is not offered.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatHud = require(script.CombatHud)
local HavenClient = require(script.HavenClient)
local Ui = require(script.Ui)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(shared:WaitForChild("Areas"))
local Currencies = require(shared:WaitForChild("Currencies"))
local areaList = Areas.all()
local firstArea = areaList[1]
local firstPools = if firstArea ~= nil then Areas.pools(firstArea.id) else {}
local firstPool = firstPools[1]
local selectedPoolId = if firstPool ~= nil then firstPool.id else "verdant_armory"

local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if remotes == nil then
	warn("[Shardfall] ReplicatedStorage.Remotes did not appear. Connect Rojo, then press Play.")
	return
end

local shownOddsKey: string? = nil
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

local function oddsKey(profile: any): string
	local since = 0
	if type(profile.pity) == "table" then
		local bucket = profile.pity[selectedPoolId]
		if type(bucket) == "table" then
			since = bucket.rollsSinceLegendary or 0
		end
	end
	return string.format(
		"%s:%s:%s:%s",
		selectedPoolId,
		tostring(profile.shardLuck or 0),
		tostring(profile.luckBoost or 0),
		tostring(since)
	)
end

local function applyProfile(profile: any, saving: any)
	if type(profile) ~= "table" then
		return
	end
	ui.setProfile(profile, saving == true)
	local key = oddsKey(profile)
	if key ~= shownOddsKey then
		shownOddsKey = key
		refreshOdds()
	end
end

local function applyResult(result: any)
	if type(result) ~= "table" then
		return
	end
	if type(result.profile) == "table" then
		applyProfile(result.profile, result.saving)
	end
	if type(result.policy) == "table" then
		ui.setPolicy(result.policy)
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
		ui.setStatus("Cracking with a Prism Token...", "info")
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("RollPaid", selectedPoolId)
			end)
			local message = remoteError(ok, result, "Prism crack blocked.")
			if message ~= nil then
				ui.setStatus(message, "error")
			else
				applyResult(result)
				ui.showRoll(result)
				local item = (result :: any).item
				local name = if type(item) == "table" then item.name else "a drop"
				ui.setStatus("Received " .. tostring(name) .. " for a Prism Token.", "ok")
			end
			if ok and type(result) == "table" and message ~= nil then
				applyResult(result)
			end
		end)
	end,
	onBuyPrism = function()
		ui.setStatus(Currencies.packPitch(), "info")
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BuyPrism")
			end)
			local message = remoteError(ok, result, "Could not buy Prism Tokens.")
			if message ~= nil then
				ui.setStatus(message, "error")
			end
			if ok and type(result) == "table" then
				applyResult(result)
			end
		end)
	end,
	onBuyBoost = function()
		ui.setStatus(Currencies.boostPitch(0), "info")
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BuyBoost")
			end)
			local message = remoteError(ok, result, "Could not buy a Luck Boost.")
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
	onCraft = function(recipeId: string, targetUid: string?)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("Craft", recipeId, targetUid)
			end)
			local message = remoteError(ok, result, "Craft failed.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local craft = (result :: any).craft
			local name = if type(craft) == "table" then craft.name else "recipe"
			ui.setStatus("Crafted " .. tostring(name) .. ".", "ok")
		end)
	end,
	onDungeon = function(action: string, dungeonId: string?)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("Dungeon", action, dungeonId)
			end)
			local message = remoteError(ok, result, "Dungeon request failed.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			if type(result) == "table" and type(result.run) == "table" then
				ui.setRun(result.run)
			end
			if action == "enter" and dungeonId == "rootvault_waves" then
				ui.setStatus("Entered Rootvault Waves. It continues until you fall.", "ok")
			elseif action == "enter" then
				ui.setStatus("Entered the Rootvault. Cleared rooms advance on their own.", "ok")
			elseif action == "advance" then
				ui.setStatus("Next room.", "ok")
			elseif action == "leave" then
				ui.setStatus("Back at the hub.", "ok")
			elseif action == "skip" then
				ui.setStatus("Skipped to the boss.", "ok")
			end
		end)
	end,
	onTonic = function()
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("UseTonic")
			end)
			local message = remoteError(ok, result, "Could not drink that.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local healed = if type(result) == "table" then result.healed else nil
			ui.setStatus(
				string.format("Healing Tonic restored %s HP.", tostring(healed or "some")),
				"ok"
			)
		end)
	end,
	onAttack = function()
		CombatHud.swing()
	end,
	onAutoFarm = function(enabled: boolean)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("SetAutoFarm", enabled)
			end)
			local message = remoteError(ok, result, "Could not set auto farm.")
			if message ~= nil then
				ui.setAutoFarm(not enabled)
				ui.setStatus(message, "error")
				return
			end
			ui.setStatus(
				if enabled
					then "Auto Farm is on. Wins and losses start the same run again."
					else "Auto Farm is off.",
				"ok"
			)
		end)
	end,
	onAutoAttack = function(enabled: boolean)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("SetAutoAttack", enabled)
			end)
			local message = remoteError(ok, result, "Could not change auto attack.")
			if message ~= nil then
				ui.setAutoAttack(not enabled)
				ui.setStatus(message, "error")
				return
			end
			local flag = if type(result) == "table" then result.autoAttack else enabled
			ui.setAutoAttack(flag == true)
			ui.setStatus(if flag == true then "Auto Attack on." else "Auto Attack off.", "ok")
		end)
	end,
	onFeed = function(keptUid: string, feederUid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("FeedItem", keptUid, feederUid)
			end)
			local message = remoteError(ok, result, "Could not feed that.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local feed = if type(result) == "table" then result.feed else nil
			local note = if type(feed) == "table" then feed.message else nil
			ui.setStatus(if type(note) == "string" then note else "Fed.", "ok")
		end)
	end,
})

HavenClient.start({
	onPanel = function(kind: string, areaId: string?)
		ui.openPanel(kind, areaId)
		if kind == "craft" then
			ui.setStatus("Forge. Craft, upgrade, and reroll.", "info")
		elseif areaId == "pets" then
			ui.setStatus("Pet Garden. Companions.", "info")
		else
			ui.setStatus("Armory. Weapons and armor.", "info")
		end
	end,
	onSoon = function(message: string)
		ui.setStatus(message, "info")
	end,
})

CombatHud.start(remotes :: Instance, {
	onRun = function(run)
		ui.setRun(run)
	end,
	onHint = function(text)
		ui.setStatus(text, "info")
	end,
})

local profileEvent = (remotes :: Instance):WaitForChild("ProfileUpdated")
if profileEvent:IsA("RemoteEvent") then
	profileEvent.OnClientEvent:Connect(function(profile, saving)
		applyProfile(profile, saving)
	end)
end

local policyEvent = (remotes :: Instance):WaitForChild("PolicyUpdated")
if policyEvent:IsA("RemoteEvent") then
	policyEvent.OnClientEvent:Connect(function(policy)
		ui.setPolicy(policy)
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
