--!strict

--[[
	Where a player who has fallen out of the world is sent.

	LaunchGate.waveArena off always means the hub, even if a caller claims
	the player is inside an arena run. An arena run with that flag on goes
	back to the arena origin. Everyone else who fell goes to HubSpawn.
	A player who has not fallen is left where they are.
]]

local HubRescue = {}

function HubRescue.destination(waveArenaOn: boolean, inArena: boolean, fell: boolean): string
	if fell ~= true then
		return "none"
	end
	if waveArenaOn == true and inArena == true then
		return "arena"
	end
	return "hub"
end

return HubRescue
