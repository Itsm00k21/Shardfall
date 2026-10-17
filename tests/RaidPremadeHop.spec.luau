--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidPremadeHop = require("../src/ReplicatedStorage/Shared/RaidPremadeHop")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local RAID = "src/ServerScriptService/ShardfallServer/RaidService.luau"

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

local function members(healerId: number?): { { userId: number, role: string } }
	return {
		{ userId = 7, role = "flex" },
		{ userId = 8, role = if healerId == 8 then "healer" else "dps" },
		{ userId = 9, role = "dps" },
		{ userId = 10, role = "flex" },
	}
end

local function draft(extra: { [string]: any }?)
	local row: { [string]: any } = {
		difficulty = "story",
		members = members(8),
		token = "party-token-1",
		homeJobId = "job-plaza-1",
		healer = true,
	}
	if extra ~= nil then
		for key, value in pairs(extra) do
			row[key] = value
		end
	end
	return row
end

describe("RaidPremadeHop rules", function()
	it("reserves outside Studio and stays local in Studio", function()
		expect(RaidPremadeHop.route(false, "story")).toEqual("reserve")
		expect(RaidPremadeHop.route(false, "normal")).toEqual("reserve")
		expect(RaidPremadeHop.route(true, "story")).toEqual("local")
		expect(RaidPremadeHop.route(true, "normal")).toEqual("local")
		expect(RaidPremadeHop.route(false, "hard")).toEqual("closed")
		expect(RaidPremadeHop.route(true, "shardbreaker")).toEqual("closed")
		expect(RaidPremadeHop.route(false, "guided")).toEqual("closed")
	end)

	it("stops after three failed hops", function()
		local first, gate = RaidPremadeHop.spend(nil)
		expect(first).toEqual(1)
		expect(gate).toEqual("go")
		local second, again = RaidPremadeHop.spend(first)
		expect(second).toEqual(2)
		expect(again).toEqual("go")
		local third, last = RaidPremadeHop.spend(second)
		expect(third).toEqual(3)
		expect(last).toEqual("go")
		local capped, stop = RaidPremadeHop.spend(third)
		expect(capped).toEqual(3)
		expect(stop).toEqual("capped")
		expect(RaidPremadeHop.spend(3)).toEqual(3)
		expect(select(2, RaidPremadeHop.spend(-1))).toEqual("capped")
		expect(select(2, RaidPremadeHop.spend(1.5))).toEqual("capped")
		expect(RaidPremadeHop.CONFIG.tries).toEqual(3)
	end)

	it("rolls the whole party back when anyone fails", function()
		expect(RaidPremadeHop.together({ "ok", "ok", "ok", "ok" })).toEqual("teleported")
		expect(RaidPremadeHop.together({ "ok", "fail", "ok", "ok" })).toEqual("rollback")
		expect(RaidPremadeHop.together({ "ok", "away" })).toEqual("rollback")
		expect(RaidPremadeHop.together({})).toEqual("rollback")
		expect(RaidPremadeHop.together(nil)).toEqual("rollback")
		expect(string.find(RaidPremadeHop.ERRORS.seated, "still seated", 1, true) ~= nil).toBeTrue()
		expect(string.find(RaidPremadeHop.ERRORS.capped, "still seated", 1, true) ~= nil).toBeTrue()
		expect(string.find(RaidPremadeHop.ERRORS.server, "still seated", 1, true) ~= nil).toBeTrue()
	end)

	it("packs the server listing and refuses a client host id", function()
		local packed = RaidPremadeHop.pack(draft(nil))
		assert(packed ~= nil, "pack")
		expect(packed.raid).toEqual("heartwood")
		expect(packed.difficulty).toEqual("story")
		expect(packed.premade).toEqual(true)
		expect(packed.partySize).toEqual(4)
		expect(packed.healer).toEqual(true)
		expect(packed.roles["8"]).toEqual("healer")
		expect(packed.host).toBeNil()
		expect(packed.hostUserId).toBeNil()
		expect(packed.listingId).toBeNil()
		expect(packed.userId).toBeNil()

		expect(RaidPremadeHop.pack(draft({ host = 7 }))).toBeNil()
		expect(RaidPremadeHop.pack(draft({ hostUserId = 7 }))).toBeNil()
		expect(RaidPremadeHop.pack(draft({ listingId = 4 }))).toBeNil()
		expect(RaidPremadeHop.pack(draft({ userId = 7 }))).toBeNil()
		expect(RaidPremadeHop.pack(draft({ robux = 0 }))).toBeNil()
		expect(RaidPremadeHop.pack(draft({ skip = false }))).toBeNil()
		expect(RaidPremadeHop.pack(draft({ productId = 1 }))).toBeNil()
		expect(RaidPremadeHop.pack(draft({ difficulty = "hard" }))).toBeNil()
		expect(RaidPremadeHop.pack(draft({ members = { { userId = 7, role = "flex" } } }))).toBeNil()
	end)

	it("waits until every seated member arrives and ignores a forged host", function()
		local packed = RaidPremadeHop.pack(draft(nil))
		assert(packed ~= nil, "pack")
		local first, waiting = RaidPremadeHop.admit(nil, 7, packed)
		expect(waiting).toEqual("wait")
		assert(first ~= nil)
		expect(first.count).toEqual(1)
		local again, still = RaidPremadeHop.admit(first, 7, packed)
		expect(still).toEqual("wait")
		assert(again ~= nil)
		expect(again.count).toEqual(1)

		local second = RaidPremadeHop.admit(again, 8, packed)
		local third = RaidPremadeHop.admit(second, 9, packed)
		local ready, state = RaidPremadeHop.admit(third, 10, packed)
		expect(state).toEqual("ready")
		assert(ready ~= nil)
		expect(ready.count).toEqual(4)
		expect(RaidPremadeHop.ids(ready)).toEqual({ 7, 8, 9, 10 })
		expect(RaidPremadeHop.roleFor(ready.roles, 8)).toEqual("healer")
		expect(RaidPremadeHop.roleFor(ready.roles, 99)).toEqual("flex")

		local forged = table.clone(packed)
		forged.host = 7
		expect(RaidPremadeHop.admit(nil, 7, forged)).toBeNil()
		forged.host = nil
		forged.hostUserId = 7
		expect(select(2, RaidPremadeHop.admit(nil, 7, forged))).toEqual("refuse")
		expect(RaidPremadeHop.admit(nil, 11, packed)).toBeNil()

		local dropped, left = RaidPremadeHop.drop(ready, 10)
		expect(left).toEqual("wait")
		assert(dropped ~= nil)
		expect(dropped.count).toEqual(3)
		local mid, midState = RaidPremadeHop.drop(dropped, 7)
		expect(midState).toEqual("wait")
		assert(mid ~= nil)
		expect(mid.count).toEqual(2)
		local smaller = RaidPremadeHop.drop(mid, 8)
		local empty, gone = RaidPremadeHop.drop(smaller, 9)
		expect(empty).toBeNil()
		expect(gone).toEqual("empty")
	end)
end)

describe("RaidPremadeHop wire", function()
	it("teleports the seated party once and keeps the studio entry", function()
		local raid = fs.readFile(RAID)
		local hop = between(raid, "local function hopPremade", "local function launchPremade")
		local launch = between(raid, "local function launchPremade", "function RaidService.ready")
		local receive = between(raid, "function RaidService.receive", "return RaidService")
		local depart = between(raid, "local function departUser", "function RaidService.memberLeft")

		expect(string.find(hop, "TeleportService:TeleportAsync", 1, true) ~= nil).toBeTrue()
		expect(string.find(hop, "ReservedServerAccessCode", 1, true) ~= nil).toBeTrue()
		expect(string.find(hop, "SetTeleportData", 1, true) ~= nil).toBeTrue()
		expect(string.find(hop, "reservedCode()", 1, true) ~= nil).toBeTrue()
		expect(string.find(hop, "releasePartyForTeleport", 1, true) ~= nil).toBeTrue()
		expect(string.find(hop, "TeleportToPlaceInstance", 1, true) ~= nil).toBeTrue()
		expect(string.find(hop, "RaidPremadeHop.pack", 1, true) ~= nil).toBeTrue()
		expect(string.find(hop, "RaidPremadeHop.spend", 1, true) ~= nil).toBeTrue()
		expect(string.find(hop, "startQueue", 1, true)).toBeNil()
		expect(string.find(hop, "receive(", 1, true)).toBeNil()
		expect(string.find(hop, "DungeonService.enter", 1, true)).toBeNil()
		expect(string.find(hop, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(hop, "Robux", 1, true)).toBeNil()
		expect(string.find(hop, "Schema", 1, true)).toBeNil()
		local reserveAt = string.find(hop, "local code = reservedCode()", 1, true)
		local teleportAt = string.find(hop, "TeleportService:TeleportAsync", 1, true)
		expect(
			reserveAt ~= nil
				and teleportAt ~= nil
				and (reserveAt :: number) < (teleportAt :: number)
		).toBeTrue()

		expect(string.find(launch, "RunService:IsStudio()", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "DungeonService.enter", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "DungeonService.backfill", 1, true) ~= nil).toBeTrue()
		local studioAt = string.find(launch, "if not RunService:IsStudio() then", 1, true)
		local enterAt = string.find(launch, "DungeonService.enter", 1, true)
		expect(studioAt ~= nil and enterAt ~= nil and (studioAt :: number) < (enterAt :: number)).toBeTrue()
		expect(
			string.find(launch, "Party is ready. Hard and Shardbreaker stay closed.", 1, true)
				~= nil
		).toBeTrue()

		expect(string.find(receive, "RaidPremadeHop.admit", 1, true) ~= nil).toBeTrue()
		expect(string.find(receive, "startQueue", 1, true) ~= nil).toBeTrue()
		expect(string.find(receive, "payload.host", 1, true)).toBeNil()
		expect(string.find(receive, "TeleportData.host", 1, true)).toBeNil()
		expect(string.find(receive, "TeleportAsync", 1, true)).toBeNil()
		expect(string.find(receive, "ReserveServer(", 1, true)).toBeNil()
		expect(string.find(depart, "hopHold[userId]", 1, true) ~= nil).toBeTrue()

		-- A hop that returns from TeleportAsync keeps the seats. The pull
		-- has not started, so the success path must not depart and must
		-- not mark the listing launched.
		local returned = string.find(hop, 'status ~= "teleported"', 1, true)
		assert(returned ~= nil, "teleport result")
		local afterReturn = string.sub(hop, returned)
		expect(string.find(afterReturn, "departUser", 1, true)).toBeNil()
		expect(string.find(afterReturn, "row.launched = true", 1, true)).toBeNil()
		expect(string.find(afterReturn, "row.hopping = true", 1, true) ~= nil).toBeTrue()
		-- The hold stays through the disconnect. It drops only if that
		-- player is still on this server after the wait, so Leave works
		-- when the teleport never removed them.
		local stillHere = string.find(afterReturn, "person.Parent == Players", 1, true)
		local clearHold = string.find(afterReturn, "hopHold[person.UserId] = nil", 1, true)
		expect(
			stillHere ~= nil and clearHold ~= nil and (stillHere :: number) < (clearHold :: number)
		).toBeTrue()

		local timeout = string.find(receive, "RaidPremadeHop.CONFIG.waitSeconds", 1, true)
		assert(timeout ~= nil, "reserved-server timeout")
		local timeoutBody = string.sub(receive, timeout, timeout + 700)
		expect(string.find(timeoutBody, "current.started == true", 1, true) ~= nil).toBeTrue()
		expect(string.find(timeoutBody, "sendHome(current, nil)", 1, true) ~= nil).toBeTrue()
		expect(string.find(timeoutBody, "startQueue", 1, true)).toBeNil()
		expect(string.find(receive, "premadeRecall", 1, true) ~= nil).toBeTrue()
		expect(string.find(receive, "payload.userId", 1, true)).toBeNil()
		expect(string.find(receive, "payload.hostUserId", 1, true)).toBeNil()
		local recallAt = string.find(receive, "payload.premadeRecall == true", 1, true)
		local admitAt = string.find(receive, "RaidPremadeHop.admit", 1, true)
		expect(recallAt ~= nil and admitAt ~= nil and (recallAt :: number) < (admitAt :: number)).toBeTrue()

		local disconnect =
			between(raid, "Players.PlayerRemoving:Connect", "function RaidService.leave")
		local departAt = string.find(disconnect, "departUser(leaving.UserId)", 1, true)
		local clearAt = string.find(disconnect, "hopHold[leaving.UserId] = nil", 1, true)
		expect(departAt ~= nil and clearAt ~= nil and (departAt :: number) < (clearAt :: number)).toBeTrue()

		local seatedLine = string.find(receive, "recallLine(player)", 1, true)
		local tokenMatch = string.find(receive, "seat.hopToken == payload.token", 1, true)
		expect(
			tokenMatch ~= nil
				and seatedLine ~= nil
				and (tokenMatch :: number) < (seatedLine :: number)
		).toBeTrue()
		local hud =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RaidHud.luau")
		expect(string.find(hud, 'payload.kind == "premadeRecall"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "RaidPremadeHop.ERRORS.seated", 1, true) ~= nil).toBeTrue()
		expect(RaidPremadeHop.ERRORS.seated).toEqual(
			"The raid teleport failed. The party is still seated."
		)
		expect(string.find(hud, "payload.userId", 1, true)).toBeNil()
		expect(string.find(hud, "payload.host", 1, true)).toBeNil()
		expect(string.find(receive, "FireClient(player", 1, true)).toBeNil()
		local recallFn = between(raid, "local function recallLine", "local function sendHome")
		expect(string.find(recallFn, 'kind = "premadeRecall"', 1, true) ~= nil).toBeTrue()
		expect(string.find(recallFn, "userId", 1, true)).toBeNil()

		local home = between(raid, "local function sendHome", "local function forgetArrival")
		expect(string.find(home, "premadeRecall = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(home, "userId", 1, true)).toBeNil()
		expect(string.find(home, "hostUserId", 1, true)).toBeNil()

		local limiter = fs.readFile("src/ServerScriptService/ShardfallServer/RateLimiter.luau")
		expect(string.find(limiter, "RaidJoin = { capacity = 3, perSecond = 0.5 }", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(limiter, "RaidReady = { capacity = 3, perSecond = 0.5 }", 1, true) ~= nil
		).toBeTrue()
		expect(Schema.VERSION).toEqual(25)

		local dataService = fs.readFile("src/ServerScriptService/ShardfallServer/DataService.luau")
		local partyBody = between(
			dataService,
			"function DataService.releasePartyForTeleport",
			"local function onPlayer"
		)
		expect(string.find(partyBody, "TeleportAsync", 1, true)).toBeNil()
		expect(string.find(partyBody, "ProfileLoad.release", 1, true) ~= nil).toBeTrue()
		local releaseAt = string.find(partyBody, "ProfileLoad.release", 1, true)
		local callAt = string.find(partyBody, "pcall(teleport)", 1, true)
		expect(releaseAt ~= nil and callAt ~= nil and (releaseAt :: number) < (callAt :: number)).toBeTrue()
	end)
end)
