--!strict

--[[
	Kevin's call, Oct 22 2026: dev tools (Debug, DevGrant, Dungeon "skip")
	work only for the game owner. A Team Test runs in Studio, so a Studio
	check alone let every tester use them. The servers gate the handlers;
	the client only hides the rows.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local DevAccess = require("../src/ReplicatedStorage/Shared/DevAccess")

local OWNER = 1001
local TESTER = 2002

local function after(source: string, anchor: string, needle: string): boolean
	local from = string.find(source, anchor, 1, true)
	if from == nil then
		return false
	end
	local found = string.find(source, needle, from, true)
	return found ~= nil and found - from < 600
end

describe("DevAccess rules", function()
	it("refuses everyone outside Studio", function()
		expect(DevAccess.allowed(OWNER, false, OWNER, true)).toEqual(false)
		expect(DevAccess.allowed(OWNER, nil, 0, true)).toEqual(false)
	end)

	it("lets the user who owns the place in and keeps Team Test guests out", function()
		expect(DevAccess.allowed(OWNER, true, OWNER, true)).toEqual(true)
		expect(DevAccess.allowed(TESTER, true, OWNER, true)).toEqual(false)
	end)

	it("does not treat a group id as a user", function()
		-- A group-owned place needs OWNER_IDS; a member whose user id
		-- happens to equal the group id does not pass.
		expect(DevAccess.allowed(OWNER, true, OWNER, false)).toEqual(false)
	end)

	it("allows the local session of an unpublished place", function()
		expect(DevAccess.allowed(OWNER, true, 0, false)).toEqual(true)
	end)

	it("refuses fake and local test-player ids", function()
		for _, bad in ipairs({ 0, -1, -2, 1.5, 0 / 0, math.huge, "1001", nil } :: { any }) do
			expect(DevAccess.allowed(bad, true, OWNER, true)).toEqual(false)
			expect(DevAccess.allowed(bad, true, 0, true)).toEqual(false)
		end
	end)

	it("honours OWNER_IDS when the list has entries", function()
		for _, id in ipairs(DevAccess.OWNER_IDS) do
			expect(DevAccess.allowed(id, true, 999999999, false)).toEqual(true)
		end
		expect(table.isfrozen(DevAccess.OWNER_IDS)).toEqual(true)
	end)
end)

describe("DevAccess wiring", function()
	local server = "src/ServerScriptService/ShardfallServer/"
	local client = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"

	it("gates every dev handler on the server", function()
		local remotes = fs.readFile(server .. "Remotes.luau")
		expect(after(remotes, 'functionRemote("Debug")', "DevAccess.player(player)")).toEqual(true)
		expect(after(remotes, 'functionRemote("DevGrant")', "DevAccess.player(player)")).toEqual(
			true
		)

		local debug = fs.readFile(server .. "DebugService.luau")
		expect(after(debug, "function DebugService.run", "DevAccess.player(player)")).toEqual(true)

		local roll = fs.readFile(server .. "RollService.luau")
		expect(after(roll, "function RollService.devGrant", "DevAccess.player(player)")).toEqual(
			true
		)

		local dungeon = fs.readFile(server .. "DungeonService.luau")
		expect(after(dungeon, "function DungeonService.skipToBoss", "DevAccess.player(player)")).toEqual(
			true
		)
	end)

	it("hides the dev rows from everyone else", function()
		local hub = fs.readFile(client .. "MenuHub.luau")
		expect(
			string.find(
				hub,
				"if RunService:IsStudio() and DevAccess.player(Players.LocalPlayer) then",
				1,
				true
			) ~= nil
		).toEqual(true)
		local hud = fs.readFile(client .. "DebugHud.luau")
		expect(after(hud, "function DebugHud.start", "DevAccess.player(player)")).toEqual(true)
	end)
end)
