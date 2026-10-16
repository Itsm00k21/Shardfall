--!strict

--[[
	Rojo does not manage Workspace (`$ignoreUnknownInstances`). A saved
	place can still contain an old hub, a ShardfallWorld folder, or the
	default baseplate. Those are removed at startup. Camera, Terrain, and
	a spawned character stay.
]]

local SavedWorld = {}

function SavedWorld.shouldRemove(name: string, className: string, hasHumanoid: boolean): boolean
	if hasHumanoid == true then
		return false
	end
	if name == "Camera" or className == "Camera" then
		return false
	end
	if name == "Terrain" or className == "Terrain" then
		return false
	end
	return true
end

return SavedWorld
