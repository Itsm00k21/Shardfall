--!strict

--[[
	Rojo does not manage Workspace (`$ignoreUnknownInstances`). A saved
	place can still contain an old hub or a ShardfallWorld folder. Those
	are removed at startup. Camera, Terrain, a spawned character, and the
	default baseplate stay. The baseplate is the floor the player is
	standing on until HubSpawn exists; clearing it earlier drops them
	into the void.
]]

local SavedWorld = {}

function SavedWorld.shouldRemove(
	name: string,
	className: string,
	hasHumanoid: boolean,
	isCharacter: boolean?
): boolean
	if hasHumanoid == true or isCharacter == true then
		return false
	end
	if name == "Camera" or className == "Camera" then
		return false
	end
	if name == "Terrain" or className == "Terrain" then
		return false
	end
	if name == "Baseplate" or name == "SpawnLocation" or className == "SpawnLocation" then
		return false
	end
	return true
end

-- The default plate and spawn go away only after HubSpawn is in the world
-- and the players already there have been moved onto it.
function SavedWorld.shouldClearDefault(name: string, className: string, hubSpawnReady: boolean): boolean
	if hubSpawnReady ~= true then
		return false
	end
	if name == "HubSpawn" then
		return false
	end
	if name == "Baseplate" then
		return true
	end
	if className == "SpawnLocation" or name == "SpawnLocation" then
		return true
	end
	return false
end

return SavedWorld
