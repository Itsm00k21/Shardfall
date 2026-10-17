--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidReady = require("../src/ServerScriptService/ShardfallServer/RaidReady")

local RAID = "src/ServerScriptService/ShardfallServer/RaidService.luau"

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

local function members(...: number): { { userId: number, role: string } }
	local rows = {}
	for index, userId in ipairs({ ... }) do
		rows[index] = { userId = userId, role = "flex" }
	end
	return rows
end

describe("RaidReady score", function()
	it("lets only the host open the check and counts server members", function()
		local party = members(7, 8, 9, 10)
		local early = RaidReady.vote(nil, 8, 7, party, true)
		expect(early.ok).toEqual(false)
		expect(early.error).toEqual("The host has not started the ready check.")
		expect(early.check).toBeNil()
		expect(early.complete).toEqual(false)

		local opened = RaidReady.vote(nil, 7, 7, party, true)
		expect(opened.ok).toEqual(true)
		expect(opened.started).toEqual(true)
		expect(opened.complete).toEqual(false)
		expect(opened.readyCount).toEqual(1)
		expect(opened.partySize).toEqual(4)
		assert(opened.check ~= nil)
		expect(opened.check.ready[7]).toEqual(true)
		expect(opened.check.ready[8]).toBeNil()

		local second = RaidReady.vote(opened.check, 8, 7, party, true)
		expect(second.started).toEqual(false)
		expect(second.readyCount).toEqual(2)
		expect(second.complete).toEqual(false)
		assert(second.check ~= nil)
		expect(second.check.ready[9]).toBeNil()

		local again = RaidReady.vote(second.check, 8, 7, party, true)
		expect(again.readyCount).toEqual(2)

		local third = RaidReady.vote(again.check, 9, 7, party, true)
		assert(third.check ~= nil)
		local done = RaidReady.vote(third.check, 10, 7, party, true)
		expect(done.ok).toEqual(true)
		expect(done.complete).toEqual(true)
		expect(done.readyCount).toEqual(4)
		expect(done.partySize).toEqual(4)
	end)

	it("ignores a stored id that is not a current member and refuses a short party", function()
		local party = members(7, 8, 9, 10)
		local poisoned = {
			open = true,
			ready = {
				[99] = true,
				[8] = true,
				["7"] = true,
			},
		}
		local vote = RaidReady.vote(poisoned, 7, 7, party, true)
		expect(vote.ok).toEqual(true)
		expect(vote.readyCount).toEqual(2)
		expect(vote.complete).toEqual(false)
		assert(vote.check ~= nil)
		expect(vote.check.ready[99]).toBeNil()
		expect(vote.check.ready[7]).toEqual(true)
		expect(vote.check.ready[8]).toEqual(true)

		local grew = members(7, 8, 9, 10, 11)
		local after = RaidReady.vote(vote.check, 8, 7, grew, true)
		expect(after.complete).toEqual(false)
		expect(after.readyCount).toEqual(2)
		expect(after.partySize).toEqual(5)

		local closed = RaidReady.vote(nil, 7, 7, party, false)
		expect(closed.ok).toEqual(false)
		expect(closed.error).toEqual("Fill the party before the ready check.")
		expect(closed.check).toBeNil()

		local outsider = RaidReady.vote(vote.check, 12, 7, party, true)
		expect(outsider.ok).toEqual(false)
		expect(outsider.error).toEqual("You are not seated on a premade listing.")
	end)

	it("rejects a forged host, a bad id, and a duplicate seat", function()
		local party = members(7, 8)
		local forged = RaidReady.vote(nil, 8, 7, party, true)
		expect(forged.ok).toEqual(false)
		expect(forged.error).toEqual("The host has not started the ready check.")
		local hostOpens = RaidReady.vote(nil, 7, 7, party, true)
		expect(hostOpens.ok).toEqual(true)
		expect(hostOpens.started).toEqual(true)

		expect(RaidReady.vote(nil, "7" :: any, 7, party, true).error).toEqual(
			"That listing is unusable."
		)
		expect(RaidReady.vote(nil, 7.5, 7, party, true).error).toEqual("That listing is unusable.")
		expect(RaidReady.vote(nil, 0, 7, party, true).error).toEqual("That listing is unusable.")
		expect(RaidReady.vote(nil, 7, -1, party, true).error).toEqual("That listing is unusable.")
		expect(RaidReady.vote(nil, 7, 7, { { userId = 7 }, { userId = 7 } }, true).error).toEqual(
			"That listing is unusable."
		)
		expect(RaidReady.vote(nil, 7, 7, "party" :: any, true).error).toEqual(
			"That listing is unusable."
		)
		expect(RaidReady.vote(nil, 7, 7, { { role = "flex" } }, true).ok).toEqual(false)
	end)
end)

describe("RaidReady wire", function()
	it("scores the check on the server and does not launch from the last join", function()
		local raid = fs.readFile(RAID)
		local join = between(raid, "function RaidService.join", "local function partyHealer")
		local ready = between(raid, "function RaidService.ready", "function RaidService.practice")
		local launch = between(raid, "local function launchPremade", "function RaidService.ready")
		local depart = between(raid, "local function departUser", "function RaidService.memberLeft")
		local filter = between(raid, "local function filterTitle", "local function copyStrings")

		expect(string.find(raid, "function RaidService.ready(player: Player)", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(raid, "local RaidReady = require(script.Parent.RaidReady)", 1, true) ~= nil
		).toBeTrue()
		expect(string.find(ready, "player.UserId", 1, true) ~= nil).toBeTrue()
		expect(string.find(ready, "seat.listing.hostUserId", 1, true) ~= nil).toBeTrue()
		expect(string.find(ready, "seat.listing.members", 1, true) ~= nil).toBeTrue()
		expect(string.find(ready, "RaidReady.vote(", 1, true) ~= nil).toBeTrue()
		expect(string.find(ready, "payload", 1, true)).toBeNil()
		expect(string.find(ready, "listingId", 1, true)).toBeNil()
		expect(string.find(ready, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(ready, "PromptProduct", 1, true)).toBeNil()
		expect(string.find(ready, "Robux", 1, true)).toBeNil()
		expect(string.find(ready, "Raids.difficulty", 1, true)).toBeNil()
		local completeAt = string.find(ready, "vote.complete ~= true", 1, true)
		local launchAt = string.find(ready, "launchPremade(seat)", 1, true)
		expect(
			completeAt ~= nil and launchAt ~= nil and (completeAt :: number) < (launchAt :: number)
		).toBeTrue()

		expect(string.find(join, "DungeonService", 1, true)).toBeNil()
		expect(string.find(join, "EchoParty", 1, true)).toBeNil()
		expect(string.find(join, "launchPremade", 1, true)).toBeNil()
		expect(string.find(join, "startQueue", 1, true)).toBeNil()
		expect(string.find(join, "launch(", 1, true)).toBeNil()
		expect(string.find(join, "Raids.difficulty", 1, true)).toBeNil()
		expect(string.find(join, "Party is full. The host starts the ready check.", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "Ready check comes later.", 1, true)).toBeNil()

		local gateAt =
			string.find(launch, 'difficulty ~= "story" and difficulty ~= "normal"', 1, true)
		local enterAt = string.find(launch, "DungeonService.enter", 1, true)
		expect(gateAt ~= nil and enterAt ~= nil and (gateAt :: number) < (enterAt :: number)).toBeTrue()
		expect(
			string.find(launch, "Party is ready. Hard and Shardbreaker stay closed.", 1, true)
				~= nil
		).toBeTrue()
		expect(string.find(launch, "DungeonService.backfill", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "EchoParty.route", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "listing.hostUserId", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "Players:GetPlayerByUserId", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "Raids.difficulty", 1, true)).toBeNil()
		expect(string.find(launch, "startQueue", 1, true)).toBeNil()
		expect(string.find(launch, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(launch, "PromptProduct", 1, true)).toBeNil()
		expect(string.find(launch, "Robux", 1, true)).toBeNil()
		expect(string.find(launch, "RunService:IsStudio()", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "hopPremade(", 1, true) ~= nil).toBeTrue()
		-- The studio branch still enters here. The reserve lives in hopPremade.
		expect(string.find(launch, "TeleportAsync", 1, true)).toBeNil()
		local studioAt = string.find(launch, "RunService:IsStudio()", 1, true)
		local hopAt = string.find(launch, "hopPremade(", 1, true)
		expect(studioAt ~= nil and hopAt ~= nil and (studioAt :: number) < (hopAt :: number)).toBeTrue()
		expect(hopAt ~= nil and enterAt ~= nil and (hopAt :: number) < (enterAt :: number)).toBeTrue()

		expect(string.find(depart, "row.ready = nil", 1, true) ~= nil).toBeTrue()
		expect(string.find(depart, "row.readyToken", 1, true) ~= nil).toBeTrue()
		expect(string.find(depart, "launchPremade", 1, true)).toBeNil()
		expect(string.find(depart, "dungeon()", 1, true)).toBeNil()
		expect(string.find(depart, "DungeonService.enter", 1, true)).toBeNil()
		expect(string.find(depart, "DungeonService.leave", 1, true)).toBeNil()

		expect(string.find(filter, "TextService:FilterStringAsync", 1, true) ~= nil).toBeTrue()
		expect(string.find(filter, "RunService:IsStudio()", 1, true) ~= nil).toBeTrue()
		expect(string.find(filter, 'return nil, "Could not filter that title."', 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "Schema", 1, true)).toBeNil()

		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local limiter = fs.readFile("src/ServerScriptService/ShardfallServer/RateLimiter.luau")
		local project = fs.readFile("default.project.json")
		local hud =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RaidHud.luau")
		local remote =
			between(remotes, 'functionRemote("RaidReady")', 'functionRemote("UpgradeGear")')
		expect(string.find(remote, "RaidService.ready(player)", 1, true) ~= nil).toBeTrue()
		expect(string.find(remote, "listingId", 1, true)).toBeNil()
		expect(string.find(remote, "payload", 1, true)).toBeNil()
		expect(
			string.find(limiter, "RaidReady = { capacity = 3, perSecond = 0.5 }", 1, true) ~= nil
		).toBeTrue()
		expect(
			string.find(project, '"RaidReady": { "$className": "RemoteFunction" }', 1, true) ~= nil
		).toBeTrue()
		expect(string.find(hud, 'invoke("RaidReady")', 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, 'button("Ready"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "MarketplaceService", 1, true)).toBeNil()
	end)
end)
