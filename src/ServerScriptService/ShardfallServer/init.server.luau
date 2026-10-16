--!strict

--[[
	Shardfall server entry.

	Order matters. Remotes are bound and the profile listener is connected
	before DataService.start(), which is what yields on DataStores and then
	tells the client the profile is ready. The listener is registered first
	so a fast in-memory load still pushes a snapshot. Dungeon startup, including
	the hub build, is isolated so a map error cannot skip that profile push.

	The first statement is a print, before any require, so a broken module
	still leaves `[Shardfall] build 5d864d6+ server` in Output.
]]

print("[Shardfall] build 5d864d6+ server")

local function silenceForeignScripts()
	local ForeignScripts = require(game:GetService("ReplicatedStorage").Shared.ForeignScripts)
	local found = 0
	for _, serviceName in ipairs(ForeignScripts.SERVICES) do
		local root = game:GetService(serviceName)
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BaseScript") then
				local names = { descendant.Name }
				local cursor: Instance? = descendant.Parent
				while cursor ~= nil do
					table.insert(names, cursor.Name)
					cursor = cursor.Parent
				end
				if ForeignScripts.shouldFlag(serviceName, names) then
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
local PolicyCache = require(script.PolicyCache)
local Remotes = require(script.Remotes)
local RollService = require(script.RollService)

DataService.onChanged(function(player, snapshot, saving)
	Remotes.pushProfile(player, snapshot, saving)
	CombatService.refresh(player)
end)

Remotes.bind()
RollService.bindAnnouncements()
PolicyCache.onChanged(function(player, policy)
	Remotes.pushPolicy(player, policy)
end)
PolicyCache.start()
CombatService.bindHooks({
	enemies = function(player)
		return DungeonService.enemyViews(player)
	end,
	onEnemyHit = function(player, enemyId, amount, crit, heavy)
		local killed = DungeonService.damageEnemy(player, enemyId, amount, crit, heavy == true)
		ClassService.grantXp(player, if killed then 24 else 4)
	end,
	onPlayerDown = function(player)
		DungeonService.onPlayerDown(player)
	end,
	inRun = function(player)
		return DungeonService.isInRun(player)
	end,
})
ClassService.start()
CombatService.bindPlayerHit(function(player)
	ClassService.onHit(player)
end)
CombatService.start()
local dungeonOk, dungeonError = pcall(DungeonService.start)
if not dungeonOk then
	warn("[Shardfall] Dungeon startup failed: " .. tostring(dungeonError))
end
DataService.start()
