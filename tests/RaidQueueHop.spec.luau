--!strict

--[[
	T-101. RaidService.queue always passed allowHop true, so a click
	inside a reserved server reserved another server and teleported.
	The plaza still hops. A reserved server launches in place.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local Loops = require("../src/ReplicatedStorage/Shared/Loops")
local ProfileLoad = require("../src/ReplicatedStorage/Shared/ProfileLoad")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

local function at(source: string, needle: string): number
	local found = string.find(source, needle, 1, true)
	assert(found ~= nil, "missing " .. needle)
	return found
end

describe("Reserved-server queue hop", function()
	it("launches in place when the click is already on a reserved server", function()
		-- Public and VIP servers still hop. A ReserveServer instance does not.
		expect(ProfileLoad.hopOnArrival("", 0)).toEqual(true)
		expect(ProfileLoad.hopOnArrival("vip-code", 42)).toEqual(true)
		expect(ProfileLoad.hopOnArrival("reserved-code", 0)).toEqual(false)

		local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
		local queue = between(raid, "function RaidService.queue", "function RaidService.board")
		expect(string.find(queue, "startQueue(player, difficulty, role, true)", 1, true)).toBeNil()
		expect(string.find(queue, "ReserveServer", 1, true)).toBeNil()
		expect(string.find(queue, "TeleportAsync", 1, true)).toBeNil()
		expect(string.find(queue, "GetJoinData", 1, true)).toBeNil()
		local flagAt =
			at(queue, "ProfileLoad.hopOnArrival(game.PrivateServerId, game.PrivateServerOwnerId)")
		local callAt = at(queue, "return startQueue(player, difficulty, role, allowHop)")
		expect(flagAt < callAt).toBeTrue()

		local start = between(raid, "local function startQueue", "local function trim")
		local gateAt = at(start, "if allowHop and canHop then")
		local codeAt = at(start, "local code = reservedCode()")
		local teleportAt = at(start, "TeleportService:TeleportAsync")
		local launchAt = at(start, "local started = launch(")
		expect(at(start, "local canHop = ProfileLoad.hopOnArrival(") < gateAt).toBeTrue()
		expect(gateAt < codeAt).toBeTrue()
		expect(codeAt < teleportAt).toBeTrue()
		expect(teleportAt < launchAt).toBeTrue()
		-- Level and role still refuse before any reserve.
		expect(at(start, "Raids.roleOk") < gateAt).toBeTrue()
		expect(at(start, "Clear Story once before Normal.") < gateAt).toBeTrue()
		expect(string.find(start, "payload.host", 1, true)).toBeNil()
		expect(string.find(start, "GetJoinData", 1, true)).toBeNil()
	end)

	it("leaves the premade board and the paid switches alone", function()
		local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
		local post = between(raid, "function RaidService.post", "function RaidService.join")
		local join = between(raid, "function RaidService.join", "local function partyHealer")
		expect(string.find(post, "startQueue", 1, true)).toBeNil()
		expect(string.find(join, "startQueue", 1, true)).toBeNil()
		expect(string.find(join, "RaidService.queue", 1, true)).toBeNil()
		-- The seated party still arrives with allowHop false.
		local receive = between(raid, "function RaidService.receive", "return RaidService")
		expect(string.find(receive, "\n\t\t\t\tfalse,\n", 1, true) ~= nil).toBeTrue()
		expect(string.find(receive, "TeleportAsync", 1, true)).toBeNil()
		expect(string.find(receive, "ReserveServer(", 1, true)).toBeNil()

		expect(Schema.VERSION).toEqual(26)
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		expect(Loops.PASS_PRODUCT_ID).toEqual(0)
		expect(Loops.ARCHIVE_PRODUCT_ID).toEqual(0)
		expect(RarityConfig.PAID_LUCK_ENABLED).toEqual(false)
		expect(ChestConfig.PAID_CHESTS_ENABLED).toEqual(false)
	end)
end)
