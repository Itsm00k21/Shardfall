--!strict

--[[
	Shardfall server entry.

	Order matters. Remotes are bound and the profile listener is connected
	before the profile load, which is what yields on DataStores and then
	tells the client the profile is ready. The listener is registered first
	so a fast in-memory load still pushes a snapshot.

	The profile load runs before trade, market, receipts, raids, messaging,
	and the hub build. Every service start sits in its own begin() so one
	throw (ProcessReceipt, a DataStore, MemoryStore, or MessagingService
	with API access off) warns and the rest of boot continues. A hung
	subscribe cannot sit in front of the profile load.

	The first statement is a print, before any require, so a broken module
	still leaves `[Shardfall] build <git sha> server` in Output. Build has no
	requires; the sha comes from the generated BuildStamp (scripts/stamp.sh).
]]

print((function(): string
	local ok, line = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Build")).line("server")
	end)
	return if ok then line else "[Shardfall] build unknown server"
end)())

local function silenceForeignScripts()
	local ForeignScripts = require(game:GetService("ReplicatedStorage").Shared.ForeignScripts)
	local found = 0
	for _, serviceName in ipairs(ForeignScripts.SERVICES) do
		local root = game:GetService(serviceName)
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BaseScript") then
				local names = { descendant.Name }
				local cursor: Instance? = descendant.Parent
				local inAvatar = false
				while cursor ~= nil do
					table.insert(names, cursor.Name)
					if
						cursor:IsA("Model")
						and game:GetService("Players"):GetPlayerFromCharacter(cursor) ~= nil
					then
						inAvatar = true
					end
					cursor = cursor.Parent
				end
				-- Avatar scripts stay. Disabling them does not delete the
				-- floor, but it does drop the character when the plate goes.
				if not inAvatar and ForeignScripts.shouldFlag(serviceName, names) then
					found += 1
					warn(
						string.format(
							"[Shardfall] foreign script %s (%s) is outside ShardfallServer/ShardfallClient. Disabled so it cannot spawn a second world.",
							descendant:GetFullName(),
							descendant.ClassName
						)
					)
					descendant.Disabled = true
				end
			end
		end
	end
	if found == 0 then
		print("[Shardfall] foreign-script scan: none outside ShardfallServer and ShardfallClient")
	else
		warn(
			string.format(
				"[Shardfall] foreign-script scan: disabled %d script(s). Delete them in Explorer, then reconnect Rojo.",
				found
			)
		)
	end
end

do
	local scanOk, scanErr = pcall(silenceForeignScripts)
	if not scanOk then
		warn("[Shardfall] foreign-script scan failed: " .. tostring(scanErr))
	end
end

local CombatService = require(script.CombatService)
local ClassService = require(script.ClassService)
local DataService = require(script.DataService)
local DungeonService = require(script.DungeonService)
-- Connects PlayerRemoving and BindToClose. Does not start a run.
require(script.WaveFlowService)
local GroveService = require(script.GroveService)
local LaunchGate = require(game:GetService("ReplicatedStorage").Shared.LaunchGate)
local MarketService = require(script.MarketService)
local OnboardingService = require(script.OnboardingService)
local TradeService = require(script.TradeService)
local PolicyCache = require(script.PolicyCache)
local RaidService = require(script.RaidService)
local ReceiptService = require(script.ReceiptService)
local Remotes = require(script.Remotes)
local RollService = require(script.RollService)
local PropService = require(script.PropService)
local GearService = require(script.GearService)

local function begin(label: string, start: () -> ())
	local ok, err = pcall(start)
	if not ok then
		warn(string.format("[Shardfall] %s failed: %s", label, tostring(err)))
	end
end

DataService.onChanged(function(player, snapshot, saving)
	Remotes.pushProfile(player, snapshot, saving)
	CombatService.refresh(player)
end)

begin("Remotes", function()
	Remotes.bind()
end)
PolicyCache.onChanged(function(player, policy)
	Remotes.pushPolicy(player, policy)
end)
begin("CombatHooks", function()
	CombatService.bindHooks({
		enemies = function(player)
			return DungeonService.enemyViews(player)
		end,
		onEnemyHit = function(player, enemyId, amount, crit, heavy)
			local killed = DungeonService.damageEnemy(player, enemyId, amount, crit, heavy == true)
			if not DungeonService.isPractice(player) then
				ClassService.grantXp(player, if killed then 24 else 4)
			end
		end,
		onPlayerDown = function(player)
			DungeonService.onPlayerDown(player)
		end,
		inRun = function(player)
			return DungeonService.isInRun(player)
		end,
		paysProgress = function(player)
			return not DungeonService.isPractice(player)
		end,
	})
end)

-- Profiles first. A receipt read, trade audit, or messaging hang must not skip this.
-- Arena settlement is idempotent per run id. Save, teleport, disconnect, and
-- shutdown all call it. The require stays behind the flag.
if LaunchGate.on("waveArena") then
	DataService.beforeSave(function(player, reason)
		require(script.WaveArenaHost).settle(player, reason)
	end)
end
game:BindToClose(function()
	if not LaunchGate.on("waveArena") then
		return
	end
	local ok, err = pcall(function()
		require(script.WaveArenaHost).shutdown()
	end)
	if not ok then
		warn("[Shardfall] WaveArena shutdown:", err)
	end
end)
game:GetService("Players").PlayerRemoving:Connect(function(player)
	if not LaunchGate.on("waveArena") then
		return
	end
	local ok, err = pcall(function()
		require(script.WaveArenaHost).disconnect(player)
	end)
	if not ok then
		warn("[Shardfall] WaveArena disconnect:", err)
	end
end)
begin("DataService", function()
	DataService.start()
end)
begin("Onboarding", function()
	OnboardingService.start()
end)

begin("PolicyCache", function()
	PolicyCache.start()
end)
begin("RollService", function()
	RollService.bindAnnouncements()
end)
begin("ReceiptService", function()
	ReceiptService.start()
end)
begin("ClassService", function()
	ClassService.start()
end)
begin("CombatService", function()
	CombatService.bindPlayerHit(function(player)
		ClassService.onHit(player)
	end)
	CombatService.start()
end)
begin("DungeonService", function()
	DungeonService.start()
end)
begin("PropService", function()
	PropService.start()
end)
begin("GearService", function()
	GearService.start()
end)
-- [ECHO hook] Equip remotes. The handler refuses while LaunchGate.equip is off.
begin("EquipService", function()
	require(script.EquipService.Bind).start()
end)
-- [ECHO hook] Shard Core remotes. The handler refuses while LaunchGate.shardCore is off.
begin("ShardCore", function()
	require(script.ShardCore.Bind).start()
end)
begin("GroveService", function()
	if LaunchGate.on("grove") then
		GroveService.start()
	end
end)
begin("TradeService", function()
	TradeService.start()
end)
begin("MarketService", function()
	MarketService.start()
end)
begin("WaveArena", function()
	-- [ECHO hook] present builds nothing unless both switches are on.
	if not LaunchGate.on("waveArena") then
		return
	end
	require(script.WaveArenaHost).present()
end)
begin("PartyGather", function()
	-- [ECHO hook] T4 Gate Ring. Builds nothing unless LaunchGate.parties is on.
	if not LaunchGate.on("parties") then
		return
	end
	require(script.PartyGatherHost).start()
end)
game:GetService("Players").PlayerAdded:Connect(function(player)
	task.spawn(function()
		local ok, err = pcall(function()
			DataService.waitFor(player, 20)
			RaidService.receive(player)
		end)
		if not ok then
			warn("[Shardfall] RaidService failed: " .. tostring(err))
		end
	end)
end)
