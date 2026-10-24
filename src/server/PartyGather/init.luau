--!strict

--[[
	Gate Ring entry. plan() and observe() do nothing unless
	LaunchGate.parties is on. Requiring this module builds nothing
	and writes nothing.
]]

local Gate = require("./PartyGather/Gate")
local Graybox = require("./PartyGather/Graybox")
local Party = require("./PartyGather/Party")
local Validate = require("./PartyGather/Validate")

local Gather = {}

local function open(options: any?): boolean
	if typeof(options) ~= "table" then
		return false
	end
	return Gate.open(options.launchGate)
end

local function cfg(options: any?): any
	if typeof(options) == "table" then
		return options.config
	end
	return nil
end

function Gather.plan(options: any?): { Graybox.Piece }?
	if not open(options) then
		return nil
	end
	return Graybox.pieces(cfg(options))
end

function Gather.inPromptZone(x: number, z: number, config: any?): boolean
	return Graybox.inPromptZone(x, z, config)
end

function Gather.suppressPrompt(havenAction: any, x: any, z: any, config: any?): boolean
	return Graybox.suppressPrompt(havenAction, x, z, config)
end

function Gather.problems(config: any): { string }
	return Validate.problems(config)
end

function Gather.new(config: any?): Party.State
	return Party.new(config)
end

function Gather.multiplier(n: number, config: any?): number
	return Party.multiplier(n, config)
end

function Gather.observe(state: Party.State, actor: Party.Actor, now: number, options: any?): { Party.Event }
	if not open(options) then
		return {}
	end
	return Party.observe(state, actor, now, cfg(options))
end

function Gather.drop(state: Party.State, userId: number, options: any?): { Party.Event }
	if not open(options) then
		return {}
	end
	return Party.drop(state, userId, cfg(options))
end

function Gather.setFriendsOnly(state: Party.State, userId: number, on: boolean, options: any?): { Party.Event }
	if not open(options) then
		return {}
	end
	return Party.setFriendsOnly(state, userId, on, cfg(options))
end

function Gather.setTier(state: Party.State, userId: number, tier: string, options: any?): { Party.Event }
	if not open(options) then
		return {}
	end
	return Party.setTier(state, userId, tier, cfg(options))
end

function Gather.startNow(state: Party.State, userId: number, now: number, options: any?): { Party.Event }
	if not open(options) then
		return {}
	end
	return Party.startNow(state, userId, now, cfg(options))
end

function Gather.tick(state: Party.State, now: number, options: any?): { Party.Event }
	if not open(options) then
		return {}
	end
	return Party.tick(state, now, cfg(options))
end

function Gather.view(state: Party.State, now: number, options: any?): Party.View?
	if not open(options) then
		return nil
	end
	return Party.view(state, now, cfg(options))
end

return Gather
