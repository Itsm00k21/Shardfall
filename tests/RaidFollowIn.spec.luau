--!strict

--[[
	T-102. A reserved arrival with no teleport data used to return
	before the pull. A follow-in joins the one Heartwood pull already
	on that server. The host id comes from the server, not the client.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local Loops = require("../src/ReplicatedStorage/Shared/Loops")
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

describe("Reserved follow-in", function()
	it("joins the one in-progress pull and takes the host from the server", function()
		local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
		local receive = between(raid, "function RaidService.receive", "return RaidService")
		local studioAt = at(receive, "if RunService:IsStudio() then")
		local joinAt = at(receive, "player:GetJoinData()")
		expect(studioAt < joinAt).toBeTrue()

		local follow = between(
			receive,
			'if type(payload) ~= "table" then',
			'if payload.raid ~= "heartwood" then'
		)
		local reservedAt = at(follow, "if onReserved then")
		local storyAt = at(follow, 'DungeonService.echoHost(player, "story")')
		local normalAt = at(follow, 'DungeonService.echoHost(player, "normal")')
		local storyJoin = at(follow, 'startQueue(player, "story", "flex", false)')
		local normalJoin = at(follow, 'startQueue(player, "normal", "flex", false)')
		expect(at(follow, "ProfileLoad.hopOnArrival") < reservedAt).toBeTrue()
		expect(reservedAt < storyAt).toBeTrue()
		expect(storyAt < normalAt).toBeTrue()
		expect(normalAt < storyJoin).toBeTrue()
		expect(storyJoin < normalJoin).toBeTrue()
		-- One pull only. Both difficulties, or neither, do not launch.
		expect(string.find(follow, "storyHost ~= nil and normalHost == nil", 1, true) ~= nil).toBeTrue()
		expect(string.find(follow, "normalHost ~= nil and storyHost == nil", 1, true) ~= nil).toBeTrue()
		expect(string.find(follow, "payload.", 1, true)).toBeNil()
		expect(string.find(follow, "GetJoinData", 1, true)).toBeNil()
		expect(string.find(follow, "UserId", 1, true)).toBeNil()
		expect(string.find(follow, "TeleportAsync", 1, true)).toBeNil()
		expect(string.find(follow, "ReserveServer", 1, true)).toBeNil()
		expect(string.find(follow, "RaidService.queue", 1, true)).toBeNil()

		-- A real teleport payload still launches here and ignores a client host.
		local landed = string.sub(receive, at(receive, 'if payload.raid ~= "heartwood" then'))
		expect(string.find(landed, "ProfileLoad.hopOnArrival", 1, true) ~= nil).toBeTrue()
		expect(string.find(landed, "startQueue", 1, true) ~= nil).toBeTrue()
		expect(string.find(landed, "payload.host", 1, true)).toBeNil()
		expect(string.find(landed, "TeleportData.host", 1, true)).toBeNil()
		expect(string.find(landed, "RaidService.queue", 1, true)).toBeNil()
		expect(string.find(landed, "TeleportAsync", 1, true)).toBeNil()
		expect(string.find(landed, "ReserveServer(", 1, true)).toBeNil()
		expect(string.find(receive, "DungeonService.echoHost", 1, true) ~= nil).toBeTrue()
	end)

	it("leaves the premade board and the paid switches alone", function()
		local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
		local receive = between(raid, "function RaidService.receive", "return RaidService")
		local post = between(raid, "function RaidService.post", "function RaidService.join")
		expect(string.find(post, "startQueue", 1, true)).toBeNil()
		expect(string.find(receive, "RaidPremadeHop.admit", 1, true) ~= nil).toBeTrue()
		expect(string.find(receive, "\n\t\t\t\tfalse,\n", 1, true) ~= nil).toBeTrue()

		expect(Schema.VERSION).toEqual(25)
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		expect(Loops.PASS_PRODUCT_ID).toEqual(0)
		expect(Loops.ARCHIVE_PRODUCT_ID).toEqual(0)
		expect(RarityConfig.PAID_LUCK_ENABLED).toEqual(false)
		expect(ChestConfig.PAID_CHESTS_ENABLED).toEqual(false)
	end)
end)
