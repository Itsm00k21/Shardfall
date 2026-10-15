--!strict

--[[
	Shardfall server entry.

	Order matters. Remotes are bound and the profile listener is connected
	before DataService.start(), which is what yields on DataStores and then
	tells the client the profile is ready. The listener is registered first
	so a fast in-memory load still pushes a snapshot.
]]

local CombatService = require(script.CombatService)
local DataService = require(script.DataService)
local DungeonService = require(script.DungeonService)
local PolicyCache = require(script.PolicyCache)
local Remotes = require(script.Remotes)

DataService.onChanged(function(player, snapshot, saving)
	Remotes.pushProfile(player, snapshot, saving)
	CombatService.refresh(player)
end)

Remotes.bind()
PolicyCache.onChanged(function(player, policy)
	Remotes.pushPolicy(player, policy)
end)
PolicyCache.start()
CombatService.bindHooks({
	enemies = function(player)
		return DungeonService.enemyViews(player)
	end,
	onEnemyHit = function(player, enemyId, amount, crit)
		DungeonService.damageEnemy(player, enemyId, amount, crit)
	end,
	onPlayerDown = function(player)
		DungeonService.onPlayerDown(player)
	end,
	inRun = function(player)
		return DungeonService.isInRun(player)
	end,
})
CombatService.start()
DungeonService.start()
DataService.start()
