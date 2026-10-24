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
local PartyGatherPrompt = require("../src/ReplicatedStorage/Shared/PartyGatherPrompt")
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
	"src/ReplicatedStorage/Shared/PartyGatherPrompt.luau",
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
		expect(PartyGather.pad.x).toEqual(-18)
		expect(PartyGather.pad.z).toEqual(100)
		expect(Haven.SPAWN.x).toEqual(gate.x)
		-- The mouth sits outside the prompt-free radius, so the arch is not in the silence zone.
		expect(Gather.inPromptZone(gate.x, gate.z, PartyGather)).toBeFalse()
		local other = heartwood()
		expect(Gather.inPromptZone(other.x, other.z, PartyGather)).toBeFalse()
	end)

	it("does not hide or suppress a Haven portal prompt in the gather zone", function()
		local actions = { "rootvault", "waves", "heartwood", "practice", "soon" }
		local gate = rootvault()
		expect(Gather.inPromptZone(gate.x, gate.z, PartyGather)).toBeFalse()
		for _, portal in ipairs(Haven.PORTALS) do
			for _, action in ipairs(actions) do
				expect(Gather.suppressPrompt(action, portal.x, portal.z, PartyGather)).toBeFalse()
			end
		end
		expect(Gather.suppressPrompt("rootvault", PartyGather.pad.x, PartyGather.pad.z, PartyGather)).toBeFalse()
		expect(Gather.suppressPrompt("waves", gate.x, gate.z, PartyGather)).toBeFalse()
		-- The mouth is outside the zone, so an untagged prompt there stays up.
		-- The same prompt on the pad is silenced.
		expect(Gather.suppressPrompt(nil, gate.x, gate.z, PartyGather)).toBeFalse()
		expect(Gather.suppressPrompt("", PartyGather.pad.x, PartyGather.pad.z, PartyGather)).toBeTrue()
		local other = heartwood()
		expect(Gather.suppressPrompt(nil, other.x, other.z, PartyGather)).toBeFalse()
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/PartyGatherHost.luau")
		expect(string.find(host, "suppressPrompt", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "descendant.Enabled = false", 1, true) ~= nil).toBeTrue()
		expect(LaunchGate.SHOW.parties).toEqual(false)
	end)

	it("keeps the prompt list on CollectionService instead of scanning Workspace", function()
		expect(PartyGatherPrompt.TAG).toEqual("PartyGatherPrompt")
		expect(Schema.VERSION).toEqual(26)
		expect(LaunchGate.SHOW.parties).toEqual(false)
		local seen = {
			near = { name = "near" },
			haven = { name = "haven" },
		}
		local added: ((any) -> ())? = nil
		local removed: ((any) -> ())? = nil
		local reads = 0
		local service = {
			GetTagged = function(_service, tag)
				reads += 1
				expect(tag).toEqual(PartyGatherPrompt.TAG)
				return { seen.near, seen.haven }
			end,
			GetInstanceAddedSignal = function(_service, tag)
				expect(tag).toEqual(PartyGatherPrompt.TAG)
				return {
					Connect = function(_signal, callback)
						added = callback
					end,
				}
			end,
			GetInstanceRemovedSignal = function(_service, tag)
				expect(tag).toEqual(PartyGatherPrompt.TAG)
				return {
					Connect = function(_signal, callback)
						removed = callback
					end,
				}
			end,
		}
		local list = PartyGatherHost.trackPrompts(service, PartyGatherPrompt.TAG)
		expect(reads).toEqual(1)
		expect(#list).toEqual(2)
		expect(list[1]).toEqual(seen.near)
		expect(list[2]).toEqual(seen.haven)
		expect(added ~= nil and removed ~= nil).toBeTrue()
		local add = added :: (any) -> ()
		local drop = removed :: (any) -> ()
		local late = { late = true }
		add(late)
		add(late)
		add(nil)
		expect(#list).toEqual(3)
		expect(list[3]).toEqual(late)
		expect(reads).toEqual(1)
		drop(seen.near)
		drop(seen.near)
		expect(#list).toEqual(2)
		expect(list[1]).toEqual(seen.haven)
		expect(list[2]).toEqual(late)
		expect(reads).toEqual(1)
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/PartyGatherHost.luau")
		expect(string.find(host, "GetDescendants", 1, true)).toBeNil()
		expect(string.find(host, "service:GetTagged(tag)", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "GetInstanceAddedSignal", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "GetInstanceRemovedSignal", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "for _, descendant in ipairs(prompts)", 1, true) ~= nil).toBeTrue()
		local _, taggedCount = string.gsub(host, "service:GetTagged%(tag%)", "")
		expect(taggedCount).toEqual(1)
		for _, path in ipairs({
			"src/ServerScriptService/ShardfallServer/HavenBuilder.luau",
			"src/ServerScriptService/ShardfallServer/PropService.luau",
			"src/ServerScriptService/ShardfallServer/WaveArenaHost.luau",
		}) do
			expect(string.find(fs.readFile(path), "PartyGatherPrompt.tag", 1, true) ~= nil).toBeTrue()
		end
	end)

	it("keeps the disc clear of the pier and the mouth strip", function()
		local gate = rootvault()
		local pad = PartyGather.pad
		local clear = PartyGather.clearance
		expect(gate.bearing).toEqual(0)
		expect(clear.pierHalf).toEqual(1.25)
		expect(clear.mouthHalfX).toEqual(4)
		expect(clear.mouthHalfZ).toEqual(0.3)
		local function away(x: number, z: number): number
			local dx = pad.x - x
			local dz = pad.z - z
			return math.sqrt(dx * dx + dz * dz)
		end
		for _, localX in ipairs(clear.pierLocalX) do
			local pierX = gate.x + localX
			expect(away(pierX, gate.z)).toBeGreaterThan(pad.radius + clear.pierHalf)
		end
		local mouthDx = math.max(math.abs(pad.x - gate.x) - clear.mouthHalfX, 0)
		local mouthDz = math.max(math.abs(pad.z - gate.z) - clear.mouthHalfZ, 0)
		local mouthDist = math.sqrt(mouthDx * mouthDx + mouthDz * mouthDz)
		expect(mouthDist).toBeGreaterThan(pad.radius)

		local onPier = table.clone(PartyGather)
		local pierPad = table.clone(PartyGather.pad)
		pierPad.x = gate.x + clear.pierLocalX[1]
		pierPad.z = gate.z
		onPier.pad = pierPad
		expect(table.find(Gather.problems(onPier), "pier") ~= nil).toBeTrue()

		local onMouth = table.clone(PartyGather)
		local mouthPad = table.clone(PartyGather.pad)
		mouthPad.x = gate.x
		mouthPad.z = gate.z
		onMouth.pad = mouthPad
		expect(table.find(Gather.problems(onMouth), "mouth") ~= nil).toBeTrue()
		expect(LaunchGate.SHOW.parties).toEqual(false)
	end)

	it("keeps the lane margin at least the pad radius plus 3", function()
		local gate = rootvault()
		local pad = PartyGather.pad
		expect(PartyGather.clearance.laneExtra).toEqual(3)
		expect(Haven.SPAWN.x).toEqual(gate.x)
		expect(Haven.SPAWN.z < gate.z).toBeTrue()
		local lane = math.abs(pad.x - Haven.SPAWN.x)
		expect(lane >= pad.radius + PartyGather.clearance.laneExtra).toBeTrue()
		local tight = table.clone(PartyGather)
		local tightPad = table.clone(PartyGather.pad)
		tightPad.x = gate.x - (pad.radius + 2)
		tightPad.z = pad.z
		tight.pad = tightPad
		expect(table.find(Gather.problems(tight), "lane") ~= nil).toBeTrue()
		expect(Schema.VERSION).toEqual(26)
		expect(LaunchGate.SHOW.parties).toEqual(false)
	end)

	it("rejects a pad that covers the gate mouth", function()
		local bad = table.clone(PartyGather)
		local pad = table.clone(PartyGather.pad)
		pad.x = PartyGather.gate.x
		pad.z = PartyGather.gate.z
		bad.pad = pad
		local problems = Gather.problems(bad)
		expect(table.find(problems, "mouth") ~= nil).toBeTrue()
	end)

	it("tags every ProximityPrompt created under src", function()
		local function walk(dir: string, found: { string })
			for _, name in ipairs(fs.readDir(dir)) do
				local path = dir .. "/" .. name
				if fs.isDir(path) then
					walk(path, found)
				elseif string.sub(name, -5) == ".luau" then
					local source = fs.readFile(path)
					if string.find(source, 'Instance.new("ProximityPrompt")', 1, true) ~= nil then
						table.insert(found, path)
						if string.find(source, "PartyGatherPrompt.tag", 1, true) == nil then
							error(path .. " creates a ProximityPrompt without PartyGatherPrompt.tag", 2)
						end
					end
				end
			end
		end
		local found: { string } = {}
		walk("src", found)
		table.sort(found)
		expect(table.find(found, "src/ServerScriptService/ShardfallServer/HavenBuilder.luau") ~= nil).toBeTrue()
		expect(table.find(found, "src/ServerScriptService/ShardfallServer/PropService.luau") ~= nil).toBeTrue()
		expect(table.find(found, "src/ServerScriptService/ShardfallServer/WaveArenaHost.luau") ~= nil).toBeTrue()
		expect(#found >= 3).toBeTrue()
		expect(Schema.VERSION).toEqual(26)
		expect(LaunchGate.SHOW.parties).toEqual(false)
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

	it("starts by a fixed deadline when players hop in and out", function()
		local options = opened()
		local state = Gather.new(PartyGather)
		Gather.observe(state, onPad(1, "Ada"), 0, options)
		local deadline = PartyGather.party.countdown + PartyGather.party.deadlineExtra
		expect(PartyGather.party.deadlineExtra).toEqual(10)
		expect(state.countdownEnds).toEqual(PartyGather.party.countdown)
		expect(state.countdownCap).toEqual(deadline)
		local now = 11
		while now < deadline do
			Gather.observe(state, onPad(2, "Bea"), now, options)
			Gather.drop(state, 2, options)
			expect(state.countdownEnds <= deadline).toBeTrue()
			expect(state.countdownCap).toEqual(deadline)
			expect(state.phase).toEqual("gather")
			now += 0.5
		end
		Gather.observe(state, onPad(2, "Bea"), deadline - 0.2, options)
		expect(state.countdownEnds).toEqual(deadline)
		expect(#state.members).toEqual(2)
		local locked = Gather.tick(state, deadline, options)
		expect(locked[1].kind).toEqual("lock")
		local started = Gather.tick(state, deadline + PartyGather.party.startSweep, options)
		expect(started[1].kind).toEqual("start")
		expect(started[1].n).toEqual(2)
		expect(LaunchGate.SHOW.parties).toEqual(false)
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
		local options = opened()
		local state = Gather.new(PartyGather)
		Gather.observe(state, onPad(1, "Ada", true, 10), 0, options)
		Gather.observe(state, onPad(2, "Bea", true, 4), 1, options)
		local denied = Gather.setTier(state, 1, "Hard", options)
		expect(denied[1].reason).toEqual("level")
		expect(state.tier).toEqual("Normal")
		Gather.drop(state, 2, options)
		expect(Gather.setTier(state, 1, "Hard", options)[1].tier).toEqual("Hard")
		local low = Gather.observe(state, onPad(3, "Cal", true, 4), 2, options)
		expect(low[1].reason).toEqual("level")
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
		expect(#state.members).toEqual(0)
		expect(state.phase).toEqual("idle")
	end)
end)
