--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidPremade = require("../src/ReplicatedStorage/Shared/RaidPremade")

local ERRORS = RaidPremade.ERRORS
local NOW = 1_000_000
local RAID = "src/ServerScriptService/ShardfallServer/RaidService.luau"

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

local function flexSlots(size: number): { string }
	local slots = {}
	for index = 1, size do
		slots[index] = "flex"
	end
	return slots
end

-- The shape RaidService.buildDraft stores. Client members, clock, and host id are not copied.
local function serverDraft(hostUserId: number, patch: { [string]: any }?): { [string]: any }
	local size = RaidPremade.CONFIG.minParty
	local row: { [string]: any } = {
		hostUserId = hostUserId,
		difficulty = "story",
		tags = "Learning",
		partySize = size,
		slots = flexSlots(size),
		createdAt = NOW,
		members = {
			{ userId = hostUserId, role = "flex" },
		},
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			row[key] = value
		end
	end
	return row
end

describe("RaidPremade wire", function()
	it("calls the board rules from the raid server and keeps Finder off this path", function()
		local raid = fs.readFile(RAID)
		local post = between(raid, "function RaidService.post", "function RaidService.join")
		local join = between(raid, "function RaidService.join", "function RaidService.practice")
		local board = between(raid, "function RaidService.board", "function RaidService.post")
		local queue = between(raid, "function RaidService.queue", "function RaidService.board")
		local practice = between(raid, "function RaidService.practice", "function RaidService.buy")
		local block = between(raid, "local function boardBlock", "local function listingActive")
		local draft = between(raid, "local function buildDraft", "local function filterTitle")
		local filter = between(raid, "local function filterTitle", "local function copyStrings")
		local roleFn = between(raid, "local function acceptRole", "local function premadeGate")

		expect(
			string.find(
				raid,
				"local RaidPremade = require(ReplicatedStorage.Shared.RaidPremade)",
				1,
				true
			) ~= nil
		).toBeTrue()
		expect(string.find(raid, "RaidFinder", 1, true)).toBeNil()
		expect(string.find(raid, "raidFinderCooldownUntil", 1, true)).toBeNil()
		expect(string.find(raid, "tonumber(", 1, true)).toBeNil()
		expect(string.find(raid, "while #listings > 20", 1, true)).toBeNil()
		expect(string.find(raid, "payload.members", 1, true)).toBeNil()
		expect(string.find(raid, "payload.hostUserId", 1, true)).toBeNil()
		expect(string.find(raid, "payload.createdAt", 1, true)).toBeNil()
		expect(string.find(raid, "payload.clears", 1, true)).toBeNil()
		expect(string.find(raid, "payload.expiresAt", 1, true)).toBeNil()
		expect(string.find(raid, "listingId.clears", 1, true)).toBeNil()
		expect(string.find(raid, "listingId.userId", 1, true)).toBeNil()
		expect(string.find(raid, "listingId.now", 1, true)).toBeNil()

		expect(string.find(post, "RaidPremade.open", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "os.time()", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, ".raidClears", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "have < opened.listing.requiredClears", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "acceptRole(", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "boardBlock(player)", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "buildDraft(player, payload, role, postedAt)", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "filterTitle(player, payload.title)", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "The premade board is full.", 1, true) ~= nil).toBeTrue()
		expect(string.find(roleFn, "Raids.roleOk", 1, true) ~= nil).toBeTrue()
		expect(string.find(draft, "userId = player.UserId", 1, true) ~= nil).toBeTrue()
		expect(string.find(draft, "payload.guided", 1, true) ~= nil).toBeTrue()
		expect(string.find(filter, "TextService:FilterStringAsync", 1, true) ~= nil).toBeTrue()
		expect(string.find(filter, "GetNonChatStringForBroadcastAsync", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(block, "Leave your current run before using the premade board.", 1, true)
				~= nil
		).toBeTrue()
		expect(string.find(block, "DataService.teleportHold", 1, true) ~= nil).toBeTrue()
		expect(string.find(block, "isInRun", 1, true) ~= nil).toBeTrue()
		local filterAt = string.find(post, "filterTitle", 1, true)
		local secondOpen = string.find(post, "RaidPremade.open", (filterAt or 1) + 1, true)
		local insertAt = string.find(post, "table.insert(listings", 1, true)
		expect(filterAt ~= nil and secondOpen ~= nil and insertAt ~= nil).toBeTrue()
		expect((filterAt :: number) < (secondOpen :: number)).toBeTrue()
		expect((secondOpen :: number) < (insertAt :: number)).toBeTrue()

		expect(string.find(join, "RaidPremade.join", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "acceptRole(", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "boardBlock(player)", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "RaidService.queue", 1, true)).toBeNil()
		expect(string.find(join, "startQueue", 1, true)).toBeNil()
		expect(string.find(join, "launch(", 1, true)).toBeNil()
		expect(string.find(join, "RaidFinder", 1, true)).toBeNil()
		expect(string.find(join, "gearScore", 1, true)).toBeNil()
		expect(string.find(join, "cooldownUntil", 1, true)).toBeNil()
		expect(string.find(join, "clears = (profile :: any).raidClears", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "userId = player.UserId", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "wholeId(rawId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "EchoParty.route", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "DungeonService.backfill", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "Party is full. Ready check comes later.", 1, true) ~= nil).toBeTrue()
		expect(string.find(join, "Leave your listing before joining another.", 1, true) ~= nil).toBeTrue()

		expect(string.find(board, "RaidPremade.status", 1, true) ~= nil).toBeTrue()
		expect(string.find(board, "state.active == true", 1, true) ~= nil).toBeTrue()
		expect(string.find(board, "gearScore", 1, true)).toBeNil()
		expect(string.find(board, "userId", 1, true)).toBeNil()

		expect(
			string.find(queue, "Leave your premade listing before using Raid Finder.", 1, true)
				~= nil
		).toBeTrue()
		expect(
			string.find(practice, "Leave your premade listing before Practice Grove.", 1, true)
				~= nil
		).toBeTrue()
		expect(string.find(raid, "Players.PlayerRemoving:Connect", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "RaidPremade.depart", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "function RaidService.memberLeft", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "BOARD_CAP = 20", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "TITLE_MAX = 48", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "RaidPremade.CONFIG.minParty", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "1800", 1, true)).toBeNil()

		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local limiter = fs.readFile("src/ServerScriptService/ShardfallServer/RateLimiter.luau")
		expect(string.find(remotes, 'guard(player, "RaidPost"', 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, "RaidService.post(player, tag, difficulty)", 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, 'guard(player, "RaidJoin"', 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, "RaidService.join(player, listingId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(limiter, "RaidPost = { capacity = 3, perSecond = 0.5 }", 1, true) ~= nil).toBeTrue()
		expect(string.find(limiter, "RaidJoin = { capacity = 3, perSecond = 0.5 }", 1, true) ~= nil).toBeTrue()
		expect(string.find(raid, "RateLimiter", 1, true)).toBeNil()
	end)

	it("refuses a second host, a guided row, story gear, and a forged member list", function()
		local first = RaidPremade.open(nil, serverDraft(7), NOW)
		expect(first.ok).toEqual(true)
		assert(first.listing ~= nil)
		expect(first.listing.tags[1]).toEqual("learning")
		expect(first.listing.difficulty).toEqual("story")
		expect(first.listing.requiredClears).toEqual(0)
		expect(#first.listing.slots).toEqual(RaidPremade.CONFIG.minParty)
		expect(first.listing.members[1].userId).toEqual(7)

		local again = RaidPremade.open({ first.listing }, serverDraft(7), NOW)
		expect(again.ok).toEqual(false)
		expect(again.error).toEqual(ERRORS.taken)

		local guided =
			RaidPremade.open(nil, serverDraft(7, { guided = true, difficulty = "hard" }), NOW)
		expect(guided.ok).toEqual(false)
		expect(guided.error).toEqual(ERRORS.guided)

		local named = RaidPremade.open(nil, serverDraft(7, { difficulty = "guided" }), NOW)
		expect(named.ok).toEqual(false)
		expect(named.error).toEqual(ERRORS.guided)

		local gear = RaidPremade.open(nil, serverDraft(7, { gearScore = 0 }), NOW)
		expect(gear.ok).toEqual(false)
		expect(gear.error).toEqual(ERRORS.gear)

		local forged = serverDraft(7)
		forged.members = {
			{ userId = 99, role = "flex" },
		}
		local stolen = RaidPremade.open(nil, forged, NOW)
		expect(stolen.ok).toEqual(false)
		expect(stolen.error).toEqual(ERRORS.hostSeat)

		local fraction = RaidPremade.open(nil, serverDraft(7, { requiredClears = 1.5 }), NOW)
		expect(fraction.ok).toEqual(false)
		expect(fraction.error).toEqual(ERRORS.clears)

		local four = RaidPremade.open(
			nil,
			serverDraft(7, {
				slots = { "dps", "dps", "dps", "dps" },
				members = { { userId = 7, role = "dps" } },
			}),
			NOW
		)
		expect(four.ok).toEqual(true)
	end)

	it(
		"refuses a full, closed, expired, or under-cleared join and ignores gear and cooldown",
		function()
			local span = RaidPremade.CONFIG.listingSeconds
			local hard = RaidPremade.open(
				nil,
				serverDraft(7, {
					difficulty = "hard",
					gearScore = 500,
					requiredClears = 2,
					partySize = 4,
					slots = { "tank", "healer", "dps", "dps" },
					members = { { userId = 7, role = "tank" } },
				}),
				NOW
			)
			expect(hard.ok).toEqual(true)
			assert(hard.listing ~= nil)
			expect(hard.listing.gearScore).toEqual(500)

			local short = RaidPremade.join(hard.listing, {
				userId = 8,
				role = "healer",
				clears = nil,
				cooldownUntil = NOW + 999,
				gearScore = 0,
			}, NOW)
			expect(short.allowed).toEqual(false)
			expect(short.error).toEqual(ERRORS.short)

			local exact = RaidPremade.join(hard.listing, {
				userId = 8,
				role = "healer",
				clears = 2,
				cooldownUntil = NOW + 999,
			}, NOW)
			expect(exact.allowed).toEqual(true)
			assert(exact.listing ~= nil)

			local closed =
				RaidPremade.join(exact.listing, { userId = 8, role = "healer", clears = 2 }, NOW)
			expect(closed.allowed).toEqual(false)
			expect(closed.error).toEqual(ERRORS.duplicate)

			local party = exact.listing
			local third = RaidPremade.join(party, { userId = 9, role = "dps", clears = 2 }, NOW)
			expect(third.allowed).toEqual(true)
			assert(third.listing ~= nil)
			local fourth =
				RaidPremade.join(third.listing, { userId = 10, role = "dps", clears = 2 }, NOW)
			expect(fourth.allowed).toEqual(true)
			assert(fourth.listing ~= nil)
			local overflow =
				RaidPremade.join(fourth.listing, { userId = 11, role = "flex", clears = 99 }, NOW)
			expect(overflow.allowed).toEqual(false)
			expect(overflow.error).toEqual(ERRORS.full)

			local hostLeft = RaidPremade.depart(fourth.listing, 7, NOW)
			expect(hostLeft.ok).toEqual(true)
			expect(hostLeft.hostLeft).toEqual(true)
			local locked = RaidPremade.canJoin(
				hostLeft.listing,
				{ userId = 12, role = "flex", clears = 2 },
				NOW
			)
			expect(locked.allowed).toEqual(false)
			expect(locked.error).toEqual(ERRORS.closed)

			local deadline = NOW + span
			local still = RaidPremade.status(hard.listing, deadline - 1)
			expect(still.active).toEqual(true)
			expect(still.expired).toEqual(false)
			local expired = RaidPremade.status(hard.listing, deadline)
			expect(expired.expired).toEqual(true)
			expect(expired.active).toEqual(false)
			local late = RaidPremade.join(
				hard.listing,
				{ userId = 12, role = "healer", clears = 2 },
				deadline
			)
			expect(late.allowed).toEqual(false)
			expect(late.error).toEqual(ERRORS.expired)

			local fresh = RaidPremade.open(
				{ hard.listing },
				serverDraft(7, { createdAt = deadline }),
				deadline
			)
			expect(fresh.ok).toEqual(true)
		end
	)

	it("leaves a connected seat through depart and keeps disconnect off that path", function()
		local raid = fs.readFile(RAID)
		local leave = between(raid, "function RaidService.leave", "local function clientPost")
		local depart = between(raid, "local function departUser", "function RaidService.memberLeft")
		local disconnect =
			between(raid, "Players.PlayerRemoving:Connect", "function RaidService.leave")
		local member =
			between(raid, "function RaidService.memberLeft", "Players.PlayerRemoving:Connect")
		expect(string.find(leave, "departUser(userId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(depart, "RaidPremade.depart", 1, true) ~= nil).toBeTrue()
		expect(string.find(leave, "You are not seated on a premade listing.", 1, true) ~= nil).toBeTrue()
		expect(string.find(leave, "launch(", 1, true)).toBeNil()
		expect(string.find(leave, "DungeonService", 1, true)).toBeNil()
		expect(string.find(leave, "filterTitle", 1, true)).toBeNil()
		expect(string.find(leave, "player.UserId", 1, true) ~= nil).toBeTrue()
		expect(string.find(disconnect, "departUser(leaving.UserId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(disconnect, "RaidService.leave", 1, true)).toBeNil()
		expect(string.find(member, "departUser(player.UserId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(member, "RaidService.leave", 1, true)).toBeNil()

		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local limiter = fs.readFile("src/ServerScriptService/ShardfallServer/RateLimiter.luau")
		local project = fs.readFile("default.project.json")
		local hud =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RaidHud.luau")
		expect(string.find(remotes, 'functionRemote("RaidLeave")', 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, "RaidService.leave(player)", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(limiter, "RaidLeave = { capacity = 3, perSecond = 0.5 }", 1, true) ~= nil
		).toBeTrue()
		expect(
			string.find(project, '"RaidLeave": { "$className": "RemoteFunction" }', 1, true) ~= nil
		).toBeTrue()
		expect(string.find(hud, 'invoke("RaidLeave")', 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, 'button("Leave"', 1, true) ~= nil).toBeTrue()
	end)
end)
