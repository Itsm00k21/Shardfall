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

	The first statement is a print, before any require, so a broken module
	still leaves `[Shardfall] build 2743749+ client` in Output.
]]

print("[Shardfall] build 2743749+ client")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local ClientChrome = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClientChrome"))
local LegacyChrome = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LegacyChrome"))
local UiRouter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiRouter"))
local ForeignScripts =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ForeignScripts"))
local ActionBar = require(script.ActionBar)
local CaptureHud = require(script.CaptureHud)
local ClassHud = require(script.ClassHud)
local CombatHud = require(script.CombatHud)
local CombatStage = require(script.CombatStage)
local DebugHud = require(script.DebugHud)
local DoorHud = require(script.DoorHud)
local HavenClient = require(script.HavenClient)
local HudShell = require(script.HudShell)
local MenuHub = require(script.MenuHub)
local InventoryHud = require(script.InventoryHud)
local MusicController = require(script.MusicController)
local OnboardHud = require(script.OnboardHud)
local LoopHud = require(script.LoopHud)
local MarketHud = require(script.MarketHud)
local PetHud = require(script.PetHud)
local RaidHud = require(script.RaidHud)
local RollReel = require(script.RollReel)
local TravelHud = require(script.TravelHud)
local Ui = require(script.Ui)
local VerdantLod = require(script.VerdantLod)

local player = Players.LocalPlayer

local function hideRobloxChrome()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end
hideRobloxChrome()
task.spawn(function()
	for _ = 1, 10 do
		hideRobloxChrome()
		task.wait(0.5)
	end
end)

-- Haven's walk surface is y=120. The default camera follows the Humanoid,
-- which is what PlayerModule does. Set it here as well so a late control
-- script cannot leave the camera in the void under the island.
local function followCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 8)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		local at = root.Position
		camera.CFrame = CFrame.new(at + Vector3.new(0, 6, 14), at + Vector3.new(0, 2, 0))
	end
end

if player.Character ~= nil then
	task.spawn(followCharacter, player.Character)
end
player.CharacterAdded:Connect(function(character)
	followCharacter(character)
	CombatStage.bind(character)
end)
if player.Character ~= nil then
	CombatStage.bind(player.Character)
end
CombatStage.watchCamera()

local playerGui = player:WaitForChild("PlayerGui")

local function scriptNames(instance: Instance): { string }
	local names = { instance.Name }
	local cursor: Instance? = instance.Parent
	while cursor ~= nil do
		table.insert(names, cursor.Name)
		cursor = cursor.Parent
	end
	return names
end

local function dropStaleScripts(root: Instance)
	local doomed = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BaseScript") and descendant ~= script then
			local avatar = descendant:FindFirstAncestorOfClass("Model")
			local inAvatar = avatar ~= nil and Players:GetPlayerFromCharacter(avatar) ~= nil
			-- PlayerGui and PlayerScripts only. Never Workspace, and never
			-- a script on the character that is keeping the avatar upright.
			if
				not inAvatar and ForeignScripts.shouldFlag("StarterPlayer", scriptNames(descendant))
			then
				table.insert(doomed, descendant)
			end
		end
	end
	for _, descendant in ipairs(doomed) do
		warn(
			string.format(
				"[Shardfall] removed stale UI script %s so it cannot draw a second panel.",
				descendant:GetFullName()
			)
		)
		descendant:Destroy()
	end
end

local function clearStaleGuis(gui: PlayerGui)
	local doomed = {}
	for _, child in ipairs(gui:GetChildren()) do
		if
			child:IsA("ScreenGui")
			and (ClientChrome.shouldClear(child.Name) or LegacyChrome.shouldDestroy(child.Name))
		then
			if LegacyChrome.shouldDestroy(child.Name) then
				warn("[Shardfall] removed legacy ScreenGui " .. child.Name)
			end
			table.insert(doomed, child)
		end
	end
	for _, child in ipairs(doomed) do
		child:Destroy()
	end
	local hosts: { [ScreenGui]: boolean } = {}
	for _, descendant in ipairs(gui:GetDescendants()) do
		if descendant:IsA("TextLabel") and ClientChrome.legacyReadout(descendant.Text) then
			local host = descendant:FindFirstAncestorOfClass("ScreenGui")
			if host ~= nil then
				hosts[host] = true
			end
		end
	end
	for host in pairs(hosts) do
		warn("[Shardfall] removed legacy panel " .. host:GetFullName())
		host:Destroy()
	end
end

if script.Parent ~= nil then
	dropStaleScripts(script.Parent)
end
dropStaleScripts(playerGui)
clearStaleGuis(playerGui)
playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") and LegacyChrome.shouldDestroy(child.Name) then
		warn("[Shardfall] removed legacy ScreenGui " .. child.Name)
		child:Destroy()
	end
end)
local shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(shared:WaitForChild("Areas"))
local Currencies = require(shared:WaitForChild("Currencies"))
local Quality = require(shared:WaitForChild("Quality"))
local Settings = require(shared:WaitForChild("Settings"))
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
local rollReel
local musicController = MusicController.start()
local inventory
local travel
local actionBar
local hudShell
local menuHub
local latestProfile: any = nil
local graphicsTier = "med"
local graphicsSent = false

local function deviceIsTouch(): boolean
	local preferred = ""
	pcall(function()
		preferred = tostring(UserInputService.PreferredInput)
	end)
	local named = if string.find(preferred, "Touch", 1, true) ~= nil then "touch" else nil
	return Quality.touchDevice(UserInputService.TouchEnabled, named)
end

-- A missing remote must not yield this script forever. 15 seconds matches
-- the server lookup. Callers already treat ok == false as a failed action.
local REMOTE_WAIT_SECONDS = 15

local function invoke(name: string, ...: any)
	local remote = (remotes :: Instance):WaitForChild(name, REMOTE_WAIT_SECONDS)
	if remote == nil or not remote:IsA("RemoteFunction") then
		warn("[Shardfall] " .. name .. " remote is not available")
		return {
			ok = false,
			error = name .. " remote is not available",
		}
	end
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
		"%s:%s:%s:%s:%s:%s",
		selectedPoolId,
		tostring(profile.shardLuck or 0),
		tostring(profile.luckBoost or 0),
		tostring(profile.shardRolls or 0),
		tostring(profile.vip == true),
		tostring(since)
	)
end

local function applyProfile(profile: any, saving: any)
	if type(profile) ~= "table" then
		return
	end
	latestProfile = profile
	ui.clearStatus()
	ui.setProfile(profile, saving == true)
	CombatHud.setWallet(profile.gold or 0, profile.shardTokens or 0, profile.gems or 0)
	if hudShell ~= nil then
		hudShell.setProfile(profile)
		hudShell.noteDevice(deviceIsTouch())
	end
	if menuHub ~= nil then
		menuHub.setProfile(profile)
		menuHub.promptClass(false)
	end
	ClassHud.setProfile(profile)
	OnboardHud.setProfile(profile)
	PetHud.setProfile(profile)
	LoopHud.setProfile(profile)
	RaidHud.setProfile(profile)
	if inventory ~= nil then
		inventory.setProfile(profile)
	end
	if travel ~= nil then
		travel.setProfile(profile)
	end
	local tier = Quality.resolve(profile.graphicsQuality, deviceIsTouch())
	graphicsTier = tier
	VerdantLod.setTier(tier)
	ui.setGraphics(Quality.label(tier))
	if rollReel ~= nil then
		rollReel.setProfile(profile)
		rollReel.setTier(tier)
	end
	local master = 1
	local uiVolume = profile.sfxVolume or 0
	local settings = profile.uiSettings
	if type(settings) == "table" and type(settings.audio) == "table" then
		if type(settings.audio.master) == "number" then
			master = settings.audio.master
		end
		if type(settings.audio.ui) == "number" then
			uiVolume = settings.audio.ui
		end
	end
	musicController.setVolumes(
		(profile.musicVolume or 0) * master,
		(profile.sfxVolume or 0) * master
	)
	musicController.setUiVolume(uiVolume * master)
	CombatHud.setFeel(tier, profile.shake ~= false)
	local vfx = 1
	if type(settings) == "table" and type(settings.graphics) == "table" then
		if type(settings.graphics.vfx) == "number" then
			vfx = settings.graphics.vfx
		end
	end
	CombatStage.setBudget(tier, vfx)
	local camera = workspace.CurrentCamera
	if camera ~= nil and type(settings) == "table" and type(settings.camera) == "table" then
		if type(settings.camera.fov) == "number" then
			camera.FieldOfView = settings.camera.fov
		end
	end
	if
		type(settings) == "table"
		and type(settings.graphics) == "table"
		and settings.graphics.shadows == false
	then
		game:GetService("Lighting").GlobalShadows = false
	end
	if Quality.normalize(profile.graphicsQuality) == nil and not graphicsSent then
		graphicsSent = true
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("SetGraphicsQuality", tier)
			end)
			if ok and type(result) == "table" and type(result.profile) == "table" then
				applyProfile(result.profile, result.saving)
			end
		end)
	end
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

local cycleGraphics: () -> ()

local function requestDungeon(action: string, dungeonId: string?)
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
			musicController.syncRun(result.run)
			DoorHud.setRun(result.run)
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
end

ui = Ui.mount(playerGui, {
	showDev = false,
	onCrack = function()
		if rollReel ~= nil then
			rollReel.request(false)
		end
	end,
	onPaid = function()
		if rollReel ~= nil then
			rollReel.request(true)
		end
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
			local xp = if type(craft) == "table" then craft.xp else nil
			local note = "Crafted " .. tostring(name) .. "."
			if type(xp) == "number" and xp > 0 then
				note ..= string.format(" +%d Crafting XP.", xp)
			end
			ui.setStatus(note, "ok")
		end)
	end,
	onSalvage = function(uid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("Salvage", uid)
			end)
			local message = remoteError(ok, result, "Could not salvage that.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local salvage = if type(result) == "table" then (result :: any).salvage else nil
			local name = if type(salvage) == "table" then salvage.name else "gear"
			local xp = if type(salvage) == "table" then salvage.xp else nil
			local note = "Salvaged " .. tostring(name) .. "."
			if type(xp) == "number" and xp > 0 then
				note ..= string.format(" +%d Crafting XP.", xp)
			end
			ui.setStatus(note, "ok")
		end)
	end,
	onBuyForge = function()
		ui.setStatus(Currencies.forgeBoostPitch(0, os.time()), "info")
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BuyForgeBoost")
			end)
			local message = remoteError(ok, result, "Could not buy a Forge Boost.")
			if message ~= nil then
				ui.setStatus(message, "error")
			end
			if ok and type(result) == "table" then
				applyResult(result)
			end
		end)
	end,
	onDungeon = requestDungeon,
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
		CombatStage.swing()
		CombatHud.swing()
	end,
	onAudio = function(music: number, sfx: number, commit: boolean)
		musicController.setVolumes(music, sfx)
		if not commit then
			return
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("SetAudio", music, sfx)
			end)
			local message = remoteError(ok, result, "Could not save audio.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
		end)
	end,
	onChests = function()
		if inventory ~= nil then
			inventory.openTab("chests")
		end
	end,
	onGraphics = function()
		cycleGraphics()
	end,
	onAutoFarm = function(enabled: boolean)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("SetAutoFarm", enabled)
			end)
			local message = remoteError(ok, result, "Could not set auto farm.")
			local applied = enabled
			if message ~= nil then
				applied = not enabled
				ui.setStatus(message, "error")
			else
				ui.setStatus(
					if enabled
						then "Auto Farm is on. Wins and losses start the same run again."
						else "Auto Farm is off.",
					"ok"
				)
			end
			ui.setAutoFarm(applied)
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
})

rollReel = RollReel.mount(playerGui, {
	invoke = invoke,
	remoteError = remoteError,
	getPoolId = function()
		return selectedPoolId
	end,
	applyResult = applyResult,
	setStatus = function(text: string, kind: string)
		ui.setStatus(text, kind)
	end,
	setBusy = function(isBusy: boolean)
		ui.setBusy(isBusy)
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
	tier = function()
		return graphicsTier
	end,
})

local function hideMarket()
	local gui = playerGui:FindFirstChild("ShardfallMarket")
	if gui == nil then
		return
	end
	local market = gui:FindFirstChild("Market")
	if market ~= nil and market:IsA("GuiObject") then
		market.Visible = false
	end
	local toggle = gui:FindFirstChild("OpenMarket")
	if toggle ~= nil and toggle:IsA("GuiObject") then
		toggle.Visible = false
		toggle.Position = UDim2.new(0, 16, 1, -16)
	end
end

local function guiChild(guiName: string, childName: string): GuiObject?
	local gui = playerGui:FindFirstChild(guiName)
	if gui == nil then
		return nil
	end
	local child = gui:FindFirstChild(childName)
	if child ~= nil and child:IsA("GuiObject") then
		return child
	end
	return nil
end

-- Hatch, the raid chip, and the market button never sit on the join screen.
local function hideStrayButtons()
	local hatch = guiChild("ShardfallPets", "Hatch")
	if hatch ~= nil then
		hatch.Visible = false
	end
	local raid = guiChild("ShardfallRaids", "RaidToggle")
	if raid ~= nil then
		raid.Visible = false
	end
	local market = guiChild("ShardfallMarket", "OpenMarket")
	if market ~= nil then
		market.Visible = false
	end
end

-- Join shows HP, currency, the action bar, and the Studio debug toggle.
-- open is ignored: nothing here may reveal the roll sheet or the daily board.
local function setHubChrome(open: boolean, _keepRaid: boolean?)
	if open == true then
		return
	end
	if rollReel ~= nil then
		rollReel.setOpen(false)
	end
	LoopHud.setOpen(false)
	hideStrayButtons()
end

local function closePanels(except: string?)
	if except ~= "menu" and menuHub ~= nil then
		menuHub.close()
	end
	if except ~= "craft" then
		ui.close()
	end
	if except ~= "inventory" and inventory ~= nil then
		inventory.close()
	end
	if except ~= "travel" and travel ~= nil then
		travel.close()
	end
	if except ~= "skills" then
		ClassHud.close()
	end
	if except ~= "raid" then
		RaidHud.close()
	end
	if except ~= "market" then
		hideMarket()
	end
	if except ~= "roll" and rollReel ~= nil then
		rollReel.setOpen(false)
	end
	if except ~= "daily" and except ~= "pass" then
		LoopHud.setOpen(false)
	end
	hideStrayButtons()
	DoorHud.suppress(except ~= nil)
end

inventory = InventoryHud.start(playerGui, {
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
	onSalvage = function(uid: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("Salvage", uid)
			end)
			local message = remoteError(ok, result, "Could not salvage that.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local salvage = if type(result) == "table" then (result :: any).salvage else nil
			local name = if type(salvage) == "table" then salvage.name else "gear"
			ui.setStatus("Salvaged " .. tostring(name) .. ".", "ok")
		end)
	end,
	onBulkSalvage = function(rarity: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BulkSalvage", rarity)
			end)
			local message = remoteError(ok, result, "Could not salvage those.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local bulk = if type(result) == "table" then (result :: any).bulk else nil
			local count = if type(bulk) == "table" then bulk.count else 0
			ui.setStatus(string.format("Salvaged %s %s pieces.", tostring(count), rarity), "ok")
		end)
	end,
	onLock = function(uid: string, locked: boolean)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("SetItemLock", uid, locked)
			end)
			local message = remoteError(ok, result, "Could not change that lock.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus(if locked then "Locked." else "Unlocked.", "ok")
		end)
	end,
	onFavorite = function(uid: string, favorite: boolean)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("SetItemFavorite", uid, favorite)
			end)
			local message = remoteError(ok, result, "Could not change that favorite.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus(if favorite then "Favorited." else "Favorite cleared.", "ok")
		end)
	end,
	onExpand = function()
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BuyInventoryExpansion")
			end)
			local message = remoteError(ok, result, "Could not expand the inventory.")
			if message ~= nil then
				ui.setStatus(message, "error")
			end
			if ok and type(result) == "table" then
				applyResult(result)
			end
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
	onOpenChest = function(tier: string, count: number)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("OpenChest", tier, count)
			end)
			local message = remoteError(ok, result, "Could not open that chest.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local chest = if type(result) == "table" then result.chest else nil
			if rollReel ~= nil and type(chest) == "table" then
				rollReel.playChest(chest)
			end
			if count > 1 then
				ui.setStatus(string.format("Opened %d %s chests.", count, tier), "ok")
			else
				ui.setStatus("Opened a " .. tier .. " chest.", "ok")
			end
		end)
	end,
	onMergeChest = function(tier: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("MergeChest", tier)
			end)
			local message = remoteError(ok, result, "Could not merge those chests.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local merged = if type(result) == "table" then result.merge else nil
			local nextTier = if type(merged) == "table" then tostring(merged.to) else "the next"
			ui.setStatus("Merged into a " .. nextTier .. " chest.", "ok")
		end)
	end,
	onBuyChest = function(tier: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BuyChest", tier)
			end)
			local message = remoteError(ok, result, "Could not buy that chest.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus("Bought a " .. tier .. " chest with Shard Keys.", "ok")
		end)
	end,
	onClaimLogin = function()
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("ClaimLogin")
			end)
			local message = remoteError(ok, result, "Could not claim the daily chest.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus("Daily login claimed.", "ok")
		end)
	end,
	onBuyDust = function(templateId: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BuyDustShard", templateId)
			end)
			local message = remoteError(ok, result, "Could not buy that shard.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			local name = if type(result) == "table" then tostring(result.name) else "shard"
			ui.setStatus("Bought " .. name .. " with Shard Dust.", "ok")
		end)
	end,
	onBuyBundle = function()
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BuyChestBundle")
			end)
			if ok and type(result) == "table" and result.ok == true then
				applyResult(result)
				return
			end
			if ok and type(result) == "table" and result.code == "stub" then
				ui.setStatus("That bundle is not for sale yet. Odds stay on the chest tab.", "info")
				return
			end
			local message = remoteError(ok, result, "Could not request that bundle.")
			if message ~= nil then
				ui.setStatus(message, "error")
			end
		end)
	end,
	onChestOptions = function(mode: string, salvage: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("SetChestOptions", mode, salvage)
			end)
			local message = remoteError(ok, result, "Could not save chest options.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus("Chest options saved.", "ok")
		end)
	end,
	onResumeChest = function(pending: any)
		if rollReel == nil or type(pending) ~= "table" then
			return
		end
		local reel = rollReel
		task.spawn(function()
			reel.playChest({
				tier = "Mythic",
				pending = pending,
				results = {},
				bestIndex = 1,
				seconds = 4,
				reelSeconds = 0,
				luck = 1,
			})
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
			ui.setStatus("Drank a Healing Tonic.", "ok")
		end)
	end,
	onStatus = function(text: string, kind: string)
		ui.setStatus(text, kind)
	end,
	onVisible = function(open: boolean)
		if open then
			closePanels("inventory")
		end
		ui.setCovered(open)
	end,
})

travel = TravelHud.start(playerGui, {
	onVisible = function(open: boolean)
		if open then
			closePanels("travel")
		end
	end,
	onTravel = function(destinationId: string)
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("Travel", destinationId)
			end)
			local message = remoteError(ok, result, "Could not travel.")
			if message ~= nil then
				ui.setStatus(message, "error")
				return
			end
			applyResult(result)
			ui.setStatus("Traveled.", "ok")
		end)
	end,
	onBuyPass = function()
		task.spawn(function()
			local ok, result = pcall(function()
				return invoke("BuyTravelPass")
			end)
			local message = remoteError(ok, result, "Could not buy a travel pass.")
			if message ~= nil then
				ui.setStatus(message, "info")
				return
			end
			applyResult(result)
		end)
	end,
})

function cycleGraphics()
	local order = Quality.ids()
	local nextId = order[1]
	for index, id in ipairs(order) do
		if id == graphicsTier then
			nextId = order[(index % #order) + 1]
			break
		end
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return invoke("SetGraphicsQuality", nextId)
		end)
		local message = remoteError(ok, result, "Could not change graphics.")
		if message ~= nil then
			ui.setStatus(message, "error")
			return
		end
		applyResult(result)
		ui.setStatus("Graphics " .. Quality.label(nextId) .. ".", "ok")
	end)
end

local function openHub(tab: string)
	if menuHub == nil or ClassHud.holdsChoice() then
		return
	end
	if not menuHub.isOpen() then
		closePanels("menu")
	end
	menuHub.toggle(tab)
end

menuHub = MenuHub.start(playerGui, {
	invoke = invoke,
	getPoolId = function()
		return selectedPoolId
	end,
	onBag = function()
		closePanels("inventory")
		inventory.open()
		if menuHub ~= nil then
			menuHub.close()
		end
	end,
	onMarket = function()
		closePanels("market")
		MarketHud.open()
		if menuHub ~= nil then
			menuHub.close()
		end
	end,
	onDim = function(open: boolean)
		if hudShell ~= nil and not open then
			hudShell.setRail("")
		end
	end,
	onTab = function(id: string)
		if hudShell ~= nil then
			hudShell.setRail(id)
		end
	end,
	onBadges = function(badges)
		if hudShell ~= nil then
			hudShell.setBadges(badges)
		end
	end,
})

hudShell = HudShell.start(playerGui, {
	onHero = function()
		openHub("hero")
	end,
	onBag = function()
		openHub("bag")
	end,
	onRoll = function()
		openHub("roll")
	end,
	onPets = function()
		openHub("pets")
	end,
	onMarket = function()
		openHub("market")
	end,
	onPass = function()
		openHub("pass")
	end,
	onSettings = function()
		openHub("settings")
	end,
	onAttack = function()
		CombatStage.swing()
		CombatHud.swing()
	end,
	onDodge = function()
		CombatStage.dodge()
		CombatHud.dodge()
	end,
	onSkill = function(index: number)
		CombatStage.skill()
		task.spawn(function()
			pcall(invoke, "UseSkill", index)
		end)
	end,
	onUlt = function()
		task.spawn(function()
			pcall(invoke, "UseSkill", "ult")
		end)
	end,
	onHeavy = function()
		CombatHud.swing(true)
	end,
	onLayout = function(name: string, x: number, y: number)
		if type(latestProfile) ~= "table" then
			return
		end
		local nextSettings = Settings.normalize(latestProfile.uiSettings)
		nextSettings.controls.layout[name] = { math.floor(x), math.floor(y) }
		task.spawn(function()
			pcall(invoke, "SetSettings", nextSettings)
		end)
	end,
})

actionBar = ActionBar.start(playerGui, {
	onMenu = function()
		openHub("hero")
	end,
	onInventory = function()
		local opening = not inventory.isOpen()
		closePanels(if opening then "inventory" else nil)
		if opening then
			inventory.open()
		end
	end,
	onTravel = function()
		local opening = not travel.isOpen()
		closePanels(if opening then "travel" else nil)
		if opening then
			travel.open()
		end
	end,
	onAttack = function()
		CombatStage.swing()
		CombatHud.swing()
	end,
	onDodge = function()
		CombatStage.dodge()
		CombatHud.dodge()
	end,
	onSkills = function()
		local opening = not ClassHud.isVisible()
		if opening then
			closePanels("skills")
			ClassHud.setVisible(true)
		else
			ClassHud.dismiss()
		end
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
})

HavenClient.start({
	onPanel = function(kind: string, areaId: string?)
		local tab = UiRouter.havenTab(kind, areaId)
		if tab == nil or menuHub == nil or ClassHud.holdsChoice() then
			return
		end
		closePanels("menu")
		menuHub.open(tab)
		if kind == "market" then
			ui.setStatus("Haven Market. Browse, sell, and trade.", "info")
		elseif kind == "craft" then
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

VerdantLod.start()

MarketHud.start(function(action: string, ...: any)
	return invoke(action, ...)
end)
CaptureHud.start(invoke)
PetHud.start(function(action: string, ...: any)
	return invoke(action, ...)
end)
LoopHud.start(function(action: string, ...: any)
	return invoke(action, ...)
end)
RaidHud.setListener(function(opening: boolean)
	if opening then
		closePanels("raid")
	end
end)
RaidHud.start(function(action: string, ...: any)
	return invoke(action, ...)
end)
setHubChrome(false)
DebugHud.start(function(action: string, ...: any)
	return invoke(action, ...)
end)
local function retireChrome(name: string)
	local gui = playerGui:FindFirstChild(name)
	if gui ~= nil and gui:IsA("ScreenGui") then
		gui.Enabled = false
	end
end
retireChrome("ShardfallActions")
retireChrome("ShardfallDebug")
retireChrome("ShardfallMenu")
OnboardHud.start(function(action: string, ...: any)
	return invoke(action, ...)
end)
DoorHud.start(function(action: string, ...: any)
	return invoke(action, ...)
end)
ClassHud.start(remotes :: Instance, function(action: string, ...: any)
	return invoke(action, ...)
end)
CombatHud.start(remotes :: Instance, {
	onDodgeCharges = function(charges: number)
		if actionBar ~= nil then
			actionBar.setDodge(charges)
		end
	end,
	onRun = function(run)
		ui.setRun(run)
		musicController.syncRun(run)
		DoorHud.setRun(run)
	end,
	onHint = function(text)
		ui.setStatus(text, "info")
		if hudShell ~= nil and string.sub(text, 1, 1) == "+" then
			hudShell.toast(text)
		end
	end,
})
setHubChrome(false)

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
		if rollReel ~= nil then
			rollReel.setPolicy(policy)
		end
	end)
end

task.spawn(function()
	local ok, result = pcall(function()
		return invoke("GetProfile")
	end)
	local message = remoteError(ok, result, "Could not load your profile.")
	if message ~= nil then
		ui.setStatus(message, "error", true)
		ui.setNotice(message)
		return
	end
	applyProfile((result :: any).profile, (result :: any).saving)
end)
