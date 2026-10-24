--!strict

--[[
	Server session for one arena run.

	Remotes and the teleport read the server switches and the server
	in-arena flag. A client payload cannot turn those on. Disconnect,
	wipe, and timeout settle the run. Rejoin does not put the player
	back in the arena, and the loot receipt does not pay a second time.
]]

local Gate = require("./Gate")
local Loot = require("./Loot")
local Round = require("./Round")

local Session = {}

function Session.serverOpen(launchGate: any, config: any): boolean
	return Gate.open(launchGate, config)
end

-- action "leave" is refused. The client does not get a vote.
function Session.remoteOk(serverOpen: boolean, inArena: boolean, action: string): boolean
	if serverOpen ~= true then
		return false
	end
	if action == "state" or action == "enter" then
		return true
	end
	if action == "step" or action == "skip" or action == "boss" then
		return inArena == true
	end
	return false
end

-- "arena" only when the server opened the run. Anything else is the hub.
function Session.teleport(serverOpen: boolean, inArena: boolean): string
	if serverOpen == true and inArena == true then
		return "arena"
	end
	return "hub"
end

function Session.exit(profile: any, run: any, reason: string, options: any): any
	local updated, events = Round.settle(run, reason, options)
	local grant = Loot.commit(profile, if updated ~= nil then updated else run)
	return {
		inArena = false,
		position = "hub",
		run = updated,
		events = events,
		grant = grant,
	}
end

-- where is the last place the client claims. It cannot restore the arena.
function Session.rejoin(profile: any, run: any, where: any): any
	if run ~= nil then
		Loot.commit(profile, run)
	end
	local claimedArena = where == "arena"
	return {
		inArena = false,
		position = "hub",
		stranded = claimedArena and false,
	}
end

return Session
