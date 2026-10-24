--!strict

--[[
	T4 Gate Ring. The content table is checked against the live Rootvault
	mouth, and the party rules run in memory. The flag ships off, so the
	plan is nil and observe does not take a slot.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Haven = require("../src/ReplicatedStorage/Shared/Haven")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local PartyGather = require("../src/ReplicatedStorage/Shared/Config/PartyGather")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Gather = require("../src/server/PartyGather")
local PartyGatherHost = require("../src/ServerScriptService/ShardfallServer/PartyGatherHost")

local FILES = {
	"src/ReplicatedStorage/Shared/Config/PartyGather.luau",
	"src/server/PartyGather/init.luau",
	"src/server/PartyGather/Gate.luau",
	"src/server/PartyGather/Party.luau",
	"src/server/PartyGather/Graybox.luau",
	"src/server/PartyGather/Validate.luau",
	"src/ServerScriptService/ShardfallServer/PartyGatherHost.luau",
}

local function rootvault(): any
	for _, portal in ipairs(Haven.PORTALS) do
		if portal.id == "rootvault" then
			return portal
		end
	end
	return nil
end

local function heartwood(): any
	for _, portal in ipairs(Haven.PORTALS) do
		if portal.id == "heartwood" then
			return portal
		end
	end
	return nil
end

local function opened(): any
	return {
		launchGate = { parties = true },
		config = PartyGather,
	}
end

local function person(userId: number, name: string, x: number, z: number, friend: boolean, level: number?): any
	return {
		userId = userId,
		name = name,
		level = if level == nil then 10 else level,
		levelKnown = true,
		x = x,
		y = PartyGather.pad.y + 3,
		z = z,
		friendKnown = true,
		friendOfLeader = friend,
	}
end

local function onPad(userId: number, name: string, friend: boolean?, level: number?): any
	return person(userId, name, PartyGather.pad.x, PartyGather.pad.z, friend ~= false, level)
end

describe("Party gather config", function()
	it("matches the Gate Ring numbers and sits by the live gate", function()
		expect(Gather.problems(PartyGather)).toEqual({})
		expect(Schema.VERSION).toEqual(26)
		expect(LaunchGate.SHOW.parties).toEqual(false)
		expect(LaunchGate.on("parties")).toEqual(false)
		local gate = rootvault()
		expect(gate ~= nil).toBeTrue()
		expect(PartyGather.gate.x).toEqual(gate.x)
		expect(PartyGather.gate.z).toEqual(gate.z)
		expect(PartyGather.pad.y).toEqual(Haven.FLOOR_Y)
		local dx = PartyGather.pad.x - gate.x
		local dz = PartyGather.pad.z - gate.z
		local dist = math.sqrt(dx * dx + dz * dz)
		expect(dist).toEqual(10)
		expect(dist).toBeGreaterThan(PartyGather.pad.radius)
		expect(Gather.inPromptZone(gate.x, gate.z, PartyGather)).toBeTrue()
		local other = heartwood()
		expect(Gather.inPromptZone(other.x, other.z, PartyGather)).toBeFalse()
	end)

	it("rejects a pad that covers the gate mouth", function()
		local bad = table.clone(PartyGather)
		local pad = table.clone(PartyGather.pad)
		pad.z = PartyGather.gate.z
		bad.pad = pad
		local problems = Gather.problems(bad)
		expect(table.find(problems, "pad") ~= nil or table.find(problems, "near gate") ~= nil).toBeTrue()
	end)

	it("ships the flag off and builds no prompt", function()
		expect(Gather.plan({ launchGate = LaunchGate, config = PartyGather })).toBeNil()
		expect(Gather.plan(nil)).toBeNil()
		expect(Gather.plan({ launchGate = { parties = false }, config = PartyGather })).toBeNil()
		expect(Gather.plan({ launchGate = { SHOW = { parties = false } }, config = PartyGather })).toBeNil()
		local parts = Gather.plan(opened())
		expect(parts ~= nil).toBeTrue()
		expect(#(parts :: { any })).toEqual(5)
		for _, piece in ipairs(parts :: { any }) do
			expect(piece.canCollide).toEqual(false)
			expect(piece.canTouch).toEqual(false)
			expect(piece.canQuery).toEqual(false)
			expect(piece.prompt).toBeNil()
		end
		local slots = 0
		for _, piece in ipairs(parts :: { any }) do
			if piece.slotId ~= nil then
				slots += 1
				local dx = piece.position[1] - PartyGather.pad.x
				local dz = piece.position[3] - PartyGather.pad.z
				expect(math.sqrt(dx * dx + dz * dz)).toBeLessThan(PartyGather.pad.radius)
			end
		end
		expect(slots).toEqual(4)
		expect(PartyGatherHost.start()).toBeNil()
		local launchSrc = fs.readFile("src/ReplicatedStorage/Shared/LaunchGate.luau")
		expect(string.find(launchSrc, "parties = false", 1, true) ~= nil).toBeTrue()
		local boot = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local gateAt = string.find(boot, 'LaunchGate.on("parties")', 1, true)
		local startAt = string.find(boot, "PartyGatherHost).start()", 1, true)
		expect(gateAt ~= nil and startAt ~= nil and (gateAt :: number) < (startAt :: number)).toBeTrue()
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/PartyGatherHost.luau")
		expect(string.find(host, 'Instance.new("ProximityPrompt")', 1, true)).toBeNil()
		for _, path in ipairs(FILES) do
			local source = fs.readFile(path)
			expect(string.find(source, "schemaVersion =", 1, true)).toBeNil()
			expect(string.find(source, "DataStore", 1, true)).toBeNil()
			expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
			expect(string.find(source, "UpdateAsync", 1, true)).toBeNil()
			expect(string.find(source, "Robux", 1, true)).toBeNil()
		end
	end)
end)

describe("Party gather rules", function()
	it("does nothing while the flag is off", function()
		local state = Gather.new(PartyGather)
		local options = { launchGate = LaunchGate, config = PartyGather }
		Gather.observe(state, onPad(1, "Ada"), 0, options)
		expect(#state.members).toEqual(0)
		expect(Gather.view(state, 0, options)).toBeNil()
		expect(Gather.tick(state, 20, options)).toEqual({})
	end)

	it("scales HP readout 1, 1.3, 1.6, 1.9 and caps the fifth player", function()
		expect(Gather.multiplier(1, PartyGather)).toEqual(1)
		expect(Gather.multiplier(2, PartyGather)).toEqual(1.3)
		expect(Gather.multiplier(3, PartyGather)).toEqual(1.6)
		expect(Gather.multiplier(4, PartyGather)).toEqual(1.9)
		local options = opened()
		local state = Gather.new(PartyGather)
		for index = 1, 4 do
			local events = Gather.observe(state, onPad(index, "P" .. tostring(index)), 0, options)
			expect(events[1].kind).toEqual("join")
			expect(events[1].slot).toEqual(index)
		end
		expect(Gather.view(state, 0, options).n).toEqual(4)
		expect(Gather.view(state, 0, options).mult).toEqual(1.9)
		local refused = Gather.observe(state, onPad(5, "Eve"), 0, options)
		expect(refused[1].kind).toEqual("refuse")
		expect(refused[1].reason).toEqual("full")
		expect(#state.members).toEqual(4)
		expect(Gather.tick(state, 1, options)).toEqual({})
	end)

	it("keeps later slots and hands the lead to the next joiner", function()
		local options = opened()
		local state = Gather.new(PartyGather)
		Gather.observe(state, onPad(1, "Ada"), 0, options)
		Gather.observe(state, onPad(2, "Bea"), 0, options)
		Gather.observe(state, onPad(3, "Cal"), 0, options)
		local left = Gather.drop(state, 2, options)
		expect(left[1].kind).toEqual("leave")
		local again = Gather.observe(state, onPad(4, "Dee"), 1, options)
		expect(again[1].slot).toEqual(2)
		expect(state.members[1].userId).toEqual(1)
		expect(state.members[2].slot).toEqual(3)
		local handed = Gather.drop(state, 1, options)
		expect(handed[2].kind).toEqual("leader")
		expect(handed[2].userId).toEqual(3)
		expect(state.members[1].slot).toEqual(3)
		local view = Gather.view(state, 1, options)
		expect(view.slots[3].role).toEqual("leader")
		expect(view.slots[1].role).toEqual("open")
		expect(view.slots[2].role).toEqual("member")
	end)

	it("refuses a non-friend and keeps one who was already in", function()
		local options = opened()
		local state = Gather.new(PartyGather)
		Gather.observe(state, onPad(1, "Ada", true), 0, options)
		Gather.observe(state, onPad(2, "Bea", false), 1, options)
		expect(#state.members).toEqual(2)
		local toggled = Gather.setFriendsOnly(state, 1, true, options)
		expect(toggled[1].kind).toEqual("friends")
		expect(state.friendsOnly).toEqual(true)
		expect(#state.members).toEqual(2)
		local denied = Gather.setFriendsOnly(state, 2, false, options)
		expect(denied[1].reason).toEqual("leader")
		expect(state.friendsOnly).toEqual(true)
		local refused = Gather.observe(state, onPad(3, "Cal", false), 2, options)
		expect(refused[1].reason).toEqual("friends")
		expect(refused[1].slot).toEqual(3)
		expect(#state.members).toEqual(2)
		local allowed = Gather.observe(state, onPad(4, "Dee", true), 2, options)
		expect(allowed[1].kind).toEqual("join")
	end)

	it("bumps a late join to 5 seconds once, and again if they rejoin", function()
		local options = opened()
		local state = Gather.new(PartyGather)
		Gather.observe(state, onPad(1, "Ada"), 0, options)
		expect(state.countdownEnds).toEqual(15)
		Gather.observe(state, onPad(2, "Bea"), 2, options)
		expect(state.countdownEnds).toEqual(15)
		Gather.observe(state, onPad(3, "Cal"), 11, options)
		expect(state.countdownEnds).toEqual(16)
		Gather.drop(state, 3, options)
		Gather.observe(state, onPad(3, "Cal"), 12, options)
		expect(state.countdownEnds).toEqual(17)
	end)

	it("holds a slot through a short step off, then drops it", function()
		local options = opened()
		local state = Gather.new(PartyGather)
		Gather.observe(state, onPad(1, "Ada"), 0, options)
		Gather.observe(state, onPad(2, "Bea"), 0, options)
		local away = person(2, "Bea", 40, 40, true)
		expect(Gather.observe(state, away, 1, options)).toEqual({})
		expect(#state.members).toEqual(2)
		Gather.observe(state, onPad(2, "Bea"), 1.4, options)
		expect(#state.members).toEqual(2)
		Gather.observe(state, away, 2, options)
		local dropped = Gather.observe(state, away, 2.5, options)
		expect(dropped[1].kind).toEqual("leave")
		expect(#state.members).toEqual(1)
	end)

	it("requires level 5 for Hard and locks the roster when the clock ends", function()
		local previous = LaunchGate.SHOW.hardMode
		LaunchGate.SHOW.hardMode = true
		local ok, err = pcall(function()
			local options = opened()
			local state = Gather.new(PartyGather)
			Gather.observe(state, onPad(1, "Ada", true, 10), 0, options)
			Gather.observe(state, onPad(2, "Bea", true, 4), 1, options)
			local picked = Gather.setTier(state, 1, "Hard", options)
			expect(picked[1].tier).toEqual("Hard")
			expect(state.members[1].tier).toEqual("Hard")
			expect(state.tier).toEqual("Normal")
			local denied = Gather.setTier(state, 2, "Hard", options)
			expect(denied[1].reason).toEqual("level")
			expect(state.members[2].tier).toEqual("Normal")
			Gather.drop(state, 2, options)
			expect(state.tier).toEqual("Hard")
			local low = Gather.observe(state, onPad(3, "Cal", true, 4), 2, options)
			expect(low[1].kind).toEqual("join")
			expect(state.tier).toEqual("Normal")
			Gather.drop(state, 3, options)
			expect(state.tier).toEqual("Hard")
			expect(#state.members).toEqual(1)
			local locked = Gather.tick(state, 15, options)
			expect(locked[1].kind).toEqual("lock")
			expect(state.phase).toEqual("starting")
			local started = Gather.tick(state, 15.4, options)
			expect(started[1].kind).toEqual("start")
			expect(started[1].n).toEqual(1)
			expect(started[1].tier).toEqual("Hard")
			expect(started[1].mult).toEqual(1)
			expect(#started[1].roster).toEqual(1)
			expect(started[1].roster[1].tier).toEqual("Hard")
			expect(#state.members).toEqual(0)
			expect(state.phase).toEqual("idle")
		end)
		LaunchGate.SHOW.hardMode = previous
		if not ok then
			error(err, 0)
		end
	end)
end)
