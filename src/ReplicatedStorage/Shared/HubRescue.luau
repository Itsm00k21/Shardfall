--!strict

--[[
	Where a player who has fallen out of the world is sent.

	LaunchGate.waveArena off always means the hub, even if a caller claims
	the player is inside an arena run. An arena run with that flag on goes
	back to the arena origin. Everyone else who fell goes to HubSpawn.
	A player who has not fallen is left where they are.

	An arena fall is caught ARENA_DROP studs under the arena origin. The
	hub keeps the hub height the caller passes in. After the rescue
	teleport, the root is unanchored even when the stream hold left it
	anchored or the move threw.
]]

local HubRescue = {}

-- Studs under the arena origin. Hub falls do not use this.
HubRescue.ARENA_DROP = 30

function HubRescue.destination(waveArenaOn: boolean, inArena: boolean, fell: boolean): string
	if fell ~= true then
		return "none"
	end
	if waveArenaOn == true and inArena == true then
		return "arena"
	end
	return "hub"
end

function HubRescue.fallLine(where: string, hubY: number, arenaOriginY: number): number
	if where == "arena" and type(arenaOriginY) == "number" and arenaOriginY == arenaOriginY then
		return arenaOriginY - HubRescue.ARENA_DROP
	end
	if type(hubY) ~= "number" or hubY ~= hubY then
		return 0
	end
	return hubY
end

function HubRescue.pastLine(y: number, line: number): boolean
	return type(y) == "number" and y == y and type(line) == "number" and line == line and y < line
end

-- Runs the teleport, then forces the current root unanchored.
-- A move that throws still releases the root.
function HubRescue.recover(readRoot: () -> any, move: () -> ()): (boolean, any)
	local ok, err = pcall(move)
	local readOk, root = pcall(readRoot)
	if not readOk then
		return false, root
	end
	if root ~= nil then
		local released, releaseErr = pcall(function()
			root.Anchored = false
		end)
		if not released then
			return false, releaseErr
		end
	end
	return ok, err
end

return HubRescue
