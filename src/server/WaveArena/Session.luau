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

-- The first server tick when a run has no clock yet. Later ticks use the
-- real gap since that clock. A client time step is never applied.
local SERVER_TICK = 0.1
local MAX_STEP = 0.5

function Session.clock(last: any, now: number, _clientDt: any): (number, number)
	if type(now) ~= "number" or now ~= now or now == math.huge or now == -math.huge then
		local kept = if type(last) == "number" then last else 0
		return 0, kept
	end
	if type(last) ~= "number" then
		return SERVER_TICK, now
	end
	local elapsed = now - last
	if elapsed ~= elapsed or elapsed == math.huge or elapsed == -math.huge or elapsed < 0 then
		elapsed = 0
	end
	if elapsed > MAX_STEP then
		elapsed = MAX_STEP
	end
	return elapsed, now
end

function Session.clientStep(run: any, now: number, clientDt: any, input: any, options: any): (any, { any })
	local dt, clock = Session.clock(if typeof(run) == "table" then run.clock else nil, now, clientDt)
	if typeof(run) == "table" then
		run.clock = clock
	end
	return Round.step(run, dt, input, options)
end

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
