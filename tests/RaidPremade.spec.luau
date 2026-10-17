--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidPremade = require("../src/ReplicatedStorage/Shared/RaidPremade")
local RaidFinder = require("../src/ReplicatedStorage/Shared/RaidFinder")
local Raids = require("../src/ReplicatedStorage/Shared/Raids")

local ERRORS = RaidPremade.ERRORS
local NOW = 1000000

local function listing(patch: { [string]: any }?): { [string]: any }
	local row: { [string]: any } = {
		hostUserId = 1,
		difficulty = "story",
		tags = { "learning" },
		partySize = 4,
		slots = { "tank", "healer", "dps", "dps" },
		createdAt = NOW,
		members = {
			{ userId = 1, role = "tank" },
		},
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			row[key] = value
		end
	end
	return row
end

local function player(userId: number, role: string, patch: { [string]: any }?): { [string]: any }
	local row: { [string]: any } = {
		userId = userId,
		role = role,
		clears = 0,
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			row[key] = value
		end
	end
	return row
end

local function walk(value: any, banned: { [string]: boolean })
	if type(value) ~= "table" then
		expect(type(value) == "function").toEqual(false)
		return
	end
	for key, child in pairs(value) do
		if type(key) == "string" then
			expect(banned[string.lower(key)]).toBeNil()
		end
		walk(child, banned)
	end
end

describe("RaidPremade config", function()
	it("pins the placeholder thresholds and the shared role and tag names", function()
		local config = RaidPremade.CONFIG
		expect(config.minParty).toEqual(4)
		expect(config.maxParty).toEqual(8)
		expect(config.listingSeconds).toEqual(1800)
		expect(config.minClears).toEqual(0)
		expect(RaidPremade.DIFFICULTIES.story).toEqual(true)
		expect(RaidPremade.DIFFICULTIES.normal).toEqual(true)
		expect(RaidPremade.DIFFICULTIES.hard).toEqual(true)
		expect(RaidPremade.DIFFICULTIES.shardbreaker).toEqual(true)
		expect(RaidPremade.GEAR_FREE.story).toEqual(true)
		expect(RaidPremade.GEAR_FREE.normal).toEqual(true)
		expect(RaidPremade.GEAR_FREE.hard).toBeNil()
		expect(RaidPremade.REFUSED.guided).toEqual(true)
		local finderRoles = {}
		for role in pairs(RaidFinder.ROLES) do
			expect(RaidPremade.ROLES[role]).toEqual(true)
			finderRoles[role] = true
		end
		for role in pairs(RaidPremade.ROLES) do
			expect(finderRoles[role]).toEqual(true)
		end
		local raidTags = {}
		for _, name in ipairs(Raids.TAGS) do
			local key = string.lower(name)
			expect(RaidPremade.TAGS[key]).toEqual(true)
			raidTags[key] = true
		end
		for tag in pairs(RaidPremade.TAGS) do
			expect(raidTags[tag]).toEqual(true)
		end
	end)

	it("freezes the thresholds, the sets, and the errors", function()
		expect(function()
			RaidPremade.CONFIG.listingSeconds = 1
		end).toThrow()
		expect(function()
			RaidPremade.DIFFICULTIES.hard = false
		end).toThrow()
		expect(function()
			RaidPremade.GEAR_FREE.story = false
		end).toThrow()
		expect(function()
			RaidPremade.REFUSED.guided = false
		end).toThrow()
		expect(function()
			RaidPremade.ROLES.flex = false
		end).toThrow()
		expect(function()
			RaidPremade.TAGS.farm = false
		end).toThrow()
		expect(function()
			RaidPremade.ERRORS.guided = "open"
		end).toThrow()
	end)

	it("has no Robux price and no service handles", function()
		local banned = {
			robux = true,
			productid = true,
			premium = true,
			gamepass = true,
		}
		walk(RaidPremade.CONFIG, banned)
		walk(RaidPremade.DIFFICULTIES, banned)
		walk(RaidPremade.GEAR_FREE, banned)
		walk(RaidPremade.REFUSED, banned)
		walk(RaidPremade.ROLES, banned)
		walk(RaidPremade.TAGS, banned)
		walk(RaidPremade.ERRORS, banned)
	end)
end)

describe("RaidPremade validate", function()
	it("accepts a story listing and ignores the title", function()
		local draft = listing({
			difficulty = " Story ",
			tags = { " Speedrun ", "Achievement", "Learning", "Farm" },
			title = "unfiltered title",
			cooldownUntil = NOW + 50,
		})
		draft.members[1].marker = "keep"
		local result = RaidPremade.validate(draft, NOW)
		expect(result.ok).toEqual(true)
		local row = result.listing
		expect(row.difficulty).toEqual("story")
		expect(row.tags).toEqual({ "speedrun", "achievement", "learning", "farm" })
		expect(row.requiredClears).toEqual(0)
		expect(row.partySize).toEqual(4)
		expect(row.gearScore).toBeNil()
		expect(row.title).toBeNil()
		expect(row.createdAt).toEqual(NOW)
		expect(row.expiresAt).toEqual(NOW + 1800)
		expect(row.closed).toEqual(false)
		expect(row.hostUserId).toEqual(1)
		expect(row.members[1]).toEqual({
			userId = 1,
			role = "tank",
			slot = 1,
			filled = "tank",
		})
		expect(draft.members[1].marker).toEqual("keep")
		expect(draft.title).toEqual("unfiltered title")
		expect(#draft.members).toEqual(1)
		expect(result.listing == draft).toEqual(false)
		local again = RaidPremade.validate(row, NOW)
		expect(again.listing).toEqual(row)
		expect(again.listing == row).toEqual(false)
	end)

	it("accepts one tag string, Hard, Shardbreaker, and a party of 8", function()
		local one = RaidPremade.validate(listing({ tags = "Learning" }), NOW)
		expect(one.listing.tags).toEqual({ "learning" })
		local hard = RaidPremade.validate(listing({ difficulty = " Hard " }), NOW)
		expect(hard.listing.difficulty).toEqual("hard")
		local wideSlots = { "tank", "healer", "dps", "dps", "dps", "dps", "dps", "dps" }
		local wide = RaidPremade.validate(
			listing({
				difficulty = " Shardbreaker ",
				partySize = 8,
				slots = wideSlots,
			}),
			NOW
		)
		expect(wide.ok).toEqual(true)
		expect(wide.listing.difficulty).toEqual("shardbreaker")
		expect(wide.listing.partySize).toEqual(8)
		local dpsOnly = RaidPremade.validate(
			listing({
				slots = { "dps", "dps", "dps", "dps" },
				members = { { userId = 1, role = "dps" } },
			}),
			NOW
		)
		expect(dpsOnly.ok).toEqual(true)
		expect(dpsOnly.listing.members[1].filled).toEqual("dps")
	end)

	it("seats a tank in the tank slot ahead of an earlier flex slot", function()
		local seated = RaidPremade.validate(
			listing({
				slots = { "flex", "tank", "dps", "healer" },
			}),
			NOW
		)
		expect(seated.listing.members[1].slot).toEqual(2)
		expect(seated.listing.members[1].filled).toEqual("tank")
		local ordered = RaidPremade.validate(
			listing({
				slots = { "flex", "tank", "healer", "dps" },
				members = {
					{ userId = 2, role = "flex" },
					{ userId = 1, role = "tank" },
				},
			}),
			NOW
		)
		expect(ordered.listing.members[1]).toEqual({
			userId = 2,
			role = "flex",
			slot = 1,
			filled = "flex",
		})
		expect(ordered.listing.members[2].slot).toEqual(2)
		expect(ordered.listing.members[2].filled).toEqual("tank")
	end)

	it("refuses guided, a bad mode, and bad tags", function()
		expect(RaidPremade.validate(listing({ difficulty = "guided" }), NOW).error).toEqual(
			ERRORS.guided
		)
		expect(RaidPremade.validate(listing({ difficulty = "hard", guided = true }), NOW).error).toEqual(
			ERRORS.guided
		)
		expect(
			RaidPremade.validate(listing({ difficulty = "shardbreaker", guided = "yes" }), NOW).error
		).toEqual(ERRORS.guidedFlag)
		expect(RaidPremade.validate(listing({ difficulty = "fracture" }), NOW).error).toEqual(
			ERRORS.difficulty
		)
		expect(RaidPremade.validate(listing({ tags = {} }), NOW).error).toEqual(ERRORS.tag)
		expect(RaidPremade.validate(listing({ tags = "  " }), NOW).error).toEqual(ERRORS.tag)
		expect(RaidPremade.validate(listing({ tags = 4 }), NOW).error).toEqual(ERRORS.tag)
		expect(RaidPremade.validate(listing({ tags = { "nope" } }), NOW).error).toEqual(
			ERRORS.tagUnknown
		)
		expect(RaidPremade.validate(listing({ tags = "nope" }), NOW).error).toEqual(
			ERRORS.tagUnknown
		)
		expect(RaidPremade.validate(listing({ tags = { "Farm", "farm" } }), NOW).error).toEqual(
			ERRORS.tagDuplicate
		)
	end)

	it("refuses a gear score on Story and Normal and stores one on Hard", function()
		expect(RaidPremade.validate(listing({ gearScore = 0 }), NOW).error).toEqual(ERRORS.gear)
		expect(RaidPremade.validate(listing({ difficulty = "normal", gearScore = 10 }), NOW).error).toEqual(
			ERRORS.gear
		)
		expect(RaidPremade.validate(listing({ gearScore = -5 }), NOW).error).toEqual(
			ERRORS.gearValue
		)
		expect(RaidPremade.validate(listing({ difficulty = "hard", gearScore = 1.5 }), NOW).error).toEqual(
			ERRORS.gearValue
		)
		local hard = RaidPremade.validate(listing({ difficulty = "hard", gearScore = 500 }), NOW)
		expect(hard.ok).toEqual(true)
		expect(hard.listing.gearScore).toEqual(500)
		local zero =
			RaidPremade.validate(listing({ difficulty = "shardbreaker", gearScore = 0 }), NOW)
		expect(zero.listing.gearScore).toEqual(0)
		local draft = listing({ difficulty = "hard", gearScore = 500 })
		draft.expiresAt = draft.createdAt
		local stored = RaidPremade.validate(draft, NOW).listing
		expect(stored.expiresAt).toEqual(NOW + 1800)
	end)

	it("refuses a bad size, a bad slot, a bad clock, and a party that does not fit", function()
		expect(RaidPremade.validate(nil, NOW).error).toEqual(ERRORS.listing)
		expect(RaidPremade.validate(listing(), nil).error).toEqual(ERRORS.time)
		expect(RaidPremade.validate(listing(), -1).error).toEqual(ERRORS.time)
		expect(RaidPremade.validate(listing(), 0 / 0).error).toEqual(ERRORS.time)
		expect(RaidPremade.validate(listing(), math.huge).error).toEqual(ERRORS.time)
		local undated = listing()
		undated.createdAt = nil
		expect(RaidPremade.validate(undated, NOW).error).toEqual(ERRORS.created)
		expect(RaidPremade.validate(listing({ createdAt = NOW + 1 }), NOW).error).toEqual(
			ERRORS.clock
		)
		expect(
			RaidPremade.validate(
				listing({ partySize = 3, slots = { "tank", "healer", "dps" } }),
				NOW
			).error
		).toEqual(ERRORS.size)
		expect(RaidPremade.validate(listing({ partySize = 9 }), NOW).error).toEqual(ERRORS.size)
		expect(RaidPremade.validate(listing({ partySize = 4.5 }), NOW).error).toEqual(ERRORS.size)
		expect(RaidPremade.validate(listing({ slots = "tank" }), NOW).error).toEqual(ERRORS.slots)
		expect(RaidPremade.validate(listing({ slots = { "tank", "healer", "dps" } }), NOW).error).toEqual(
			ERRORS.slotCount
		)
		expect(
			RaidPremade.validate(listing({ slots = { "tank", "healer", "dps", "bard" } }), NOW).error
		).toEqual(ERRORS.role)
		expect(RaidPremade.validate(listing({ requiredClears = 1.5 }), NOW).error).toEqual(
			ERRORS.clears
		)
		expect(RaidPremade.validate(listing({ requiredClears = -1 }), NOW).error).toEqual(
			ERRORS.clears
		)
		expect(RaidPremade.validate(listing({ hostUserId = 0 }), NOW).error).toEqual(ERRORS.host)
		expect(RaidPremade.validate(listing({ hostUserId = 1.5 }), NOW).error).toEqual(ERRORS.host)
		expect(RaidPremade.validate(listing({ closed = "yes" }), NOW).error).toEqual(ERRORS.flag)
		expect(
			RaidPremade.validate(listing({ members = { { userId = 2, role = "tank" } } }), NOW).error
		).toEqual(ERRORS.hostSeat)
		expect(RaidPremade.validate(listing({ members = {} }), NOW).error).toEqual(ERRORS.hostSeat)
		expect(RaidPremade.validate(
			listing({
				members = {
					{ userId = 1, role = "tank" },
					{ userId = 1, role = "dps" },
				},
			}),
			NOW
		).error).toEqual(ERRORS.duplicate)
		expect(RaidPremade.validate(listing({ members = { { userId = 1 } } }), NOW).error).toEqual(
			ERRORS.role
		)
		expect(RaidPremade.validate(
			listing({
				members = {
					{ userId = 1, role = "tank" },
					{ userId = 2, role = "tank" },
				},
			}),
			NOW
		).error).toEqual(ERRORS.fit)
	end)
end)

describe("RaidPremade board", function()
	it("allows one active listing per host and ignores a closed or expired one", function()
		local first = RaidPremade.open(nil, listing(), NOW)
		expect(first.ok).toEqual(true)
		expect(#first.listing.members).toEqual(1)
		local board = { first.listing }
		local again = RaidPremade.open(board, listing(), NOW + 1)
		expect(again.ok).toEqual(false)
		expect(again.error).toEqual(ERRORS.taken)
		expect(again.listing).toBeNil()
		expect(#board).toEqual(1)
		expect(board[1].hostUserId).toEqual(1)
		local other = RaidPremade.open(
			board,
			listing({
				hostUserId = 2,
				members = { { userId = 2, role = "healer" } },
				slots = { "healer", "tank", "dps", "dps" },
			}),
			NOW
		)
		expect(other.ok).toEqual(true)
		expect(other.listing.hostUserId).toEqual(2)
		local expired = RaidPremade.validate(listing({ createdAt = NOW - 1800 }), NOW)
		expect(expired.ok).toEqual(true)
		expect(RaidPremade.open(nil, listing({ createdAt = NOW - 1800 }), NOW).error).toEqual(
			ERRORS.expired
		)
		expect(RaidPremade.open({ expired.listing }, listing(), NOW).ok).toEqual(true)
		local almost = RaidPremade.validate(listing({ createdAt = NOW - 1799 }), NOW).listing
		expect(RaidPremade.open({ almost }, listing(), NOW).error).toEqual(ERRORS.taken)
		expect(RaidPremade.open(nil, listing({ closed = true }), NOW).error).toEqual(ERRORS.closed)
		local closed = RaidPremade.validate(listing({ closed = true }), NOW).listing
		expect(RaidPremade.open({ closed }, listing(), NOW).ok).toEqual(true)
		expect(RaidPremade.open("nope", listing(), NOW).error).toEqual(ERRORS.board)
		expect(RaidPremade.open({ "bad" }, listing(), NOW).error).toEqual(ERRORS.listing)
	end)

	it("lets a seated player host their own listing", function()
		local hosted = RaidPremade.join(
			RaidPremade.validate(listing(), NOW).listing,
			player(2, "healer"),
			NOW
		).listing
		local board = { hosted }
		local theirs = RaidPremade.open(
			board,
			listing({
				hostUserId = 2,
				members = { { userId = 2, role = "dps" } },
				slots = { "dps", "dps", "dps", "dps" },
			}),
			NOW
		)
		expect(theirs.ok).toEqual(true)
		expect(#hosted.members).toEqual(2)
		expect(#board).toEqual(1)
	end)
end)

describe("RaidPremade join", function()
	it("gives a role its slot, then a flex slot, and lets flex take any open slot", function()
		local row = RaidPremade.validate(listing(), NOW).listing
		local healer = RaidPremade.canJoin(row, player(2, " Healer "), NOW)
		expect(healer.ok).toEqual(true)
		expect(healer.allowed).toEqual(true)
		expect(healer.role).toEqual("healer")
		expect(healer.slot).toEqual(2)
		expect(healer.filled).toEqual("healer")
		local added = RaidPremade.join(row, player(2, " Healer "), NOW)
		expect(added.slot).toEqual(healer.slot)
		expect(added.listing.members[2]).toEqual({
			userId = 2,
			role = "healer",
			slot = 2,
			filled = "healer",
		})
		expect(#row.members).toEqual(1)
		expect(added.listing.members[2].cooldownUntil).toBeNil()
		local dpsOnly = RaidPremade.validate(
			listing({
				slots = { "tank", "dps", "dps", "dps" },
			}),
			NOW
		).listing
		local denied = RaidPremade.canJoin(dpsOnly, player(2, "healer"), NOW)
		expect(denied.allowed).toEqual(false)
		expect(denied.error).toEqual(ERRORS.slot)
		local flex = RaidPremade.canJoin(dpsOnly, player(2, "flex"), NOW)
		expect(flex.allowed).toEqual(true)
		expect(flex.slot).toEqual(2)
		expect(flex.filled).toEqual("dps")
		local mixed = RaidPremade.validate(
			listing({
				slots = { "dps", "dps", "flex", "tank" },
				members = {
					{ userId = 1, role = "dps" },
					{ userId = 3, role = "dps" },
				},
			}),
			NOW
		).listing
		local third = RaidPremade.canJoin(mixed, player(4, "dps"), NOW)
		expect(third.allowed).toEqual(true)
		expect(third.slot).toEqual(3)
		expect(third.filled).toEqual("flex")
		local tank = RaidPremade.canJoin(mixed, player(4, "tank"), NOW)
		expect(tank.slot).toEqual(4)
		expect(tank.filled).toEqual("tank")
	end)

	it("checks clears and ignores gear score and the Finder cooldown", function()
		local row = RaidPremade.validate(listing({ requiredClears = 3 }), NOW).listing
		expect(row.requiredClears).toEqual(3)
		expect(RaidPremade.canJoin(row, { userId = 2, role = "healer" }, NOW).error).toEqual(
			ERRORS.short
		)
		expect(RaidPremade.canJoin(row, player(2, "healer"), NOW).error).toEqual(ERRORS.short)
		expect(RaidPremade.canJoin(row, player(2, "healer", { clears = 2 }), NOW).error).toEqual(
			ERRORS.short
		)
		local met = RaidPremade.canJoin(row, player(2, "healer", { clears = 3 }), NOW)
		expect(met.allowed).toEqual(true)
		local cooling =
			player(2, "healer", { clears = 3, cooldownUntil = NOW + 5000, gearScore = 0 })
		expect(RaidPremade.canJoin(row, cooling, NOW).allowed).toEqual(true)
		local hard =
			RaidPremade.validate(listing({ difficulty = "hard", gearScore = 500 }), NOW).listing
		local under = RaidPremade.canJoin(hard, player(2, "healer", { gearScore = 0 }), NOW)
		expect(under.allowed).toEqual(true)
		expect(hard.gearScore).toEqual(500)
		local story = RaidPremade.validate(listing(), NOW).listing
		expect(RaidPremade.canJoin(story, player(2, "healer", { gearScore = 0 }), NOW).allowed).toEqual(
			true
		)
		expect(RaidPremade.canJoin(listing(), player(2, "healer"), NOW).allowed).toEqual(true)
	end)

	it("reports full, expired, closed, and a duplicate", function()
		local row = RaidPremade.validate(listing(), NOW).listing
		local healer = RaidPremade.join(row, player(2, "healer", { clears = 1 }), NOW).listing
		local dps = RaidPremade.join(healer, player(3, "dps", { clears = 1 }), NOW).listing
		local last = RaidPremade.join(dps, player(4, "dps", { clears = 1 }), NOW)
		expect(last.allowed).toEqual(true)
		local state = RaidPremade.status(last.listing, NOW)
		expect(state.ok).toEqual(true)
		expect(state.full).toEqual(true)
		expect(state.expired).toEqual(false)
		expect(state.closed).toEqual(false)
		expect(state.active).toEqual(true)
		expect(state.openCount).toEqual(0)
		expect(state.memberCount).toEqual(4)
		expect(state.partySize).toEqual(4)
		local extra = RaidPremade.canJoin(last.listing, player(5, "flex", { clears = 9 }), NOW)
		expect(extra.allowed).toEqual(false)
		expect(extra.ok).toEqual(true)
		expect(extra.error).toEqual(ERRORS.full)
		expect(RaidPremade.open({ last.listing }, listing(), NOW).error).toEqual(ERRORS.taken)
		expect(RaidPremade.canJoin(row, player(1, "flex"), NOW).error).toEqual(ERRORS.duplicate)
		local old = RaidPremade.validate(listing({ createdAt = NOW - 1800 }), NOW).listing
		local aged = RaidPremade.status(old, NOW)
		expect(aged.expired).toEqual(true)
		expect(aged.active).toEqual(false)
		expect(aged.full).toEqual(false)
		expect(RaidPremade.canJoin(old, player(2, "healer"), NOW).error).toEqual(ERRORS.expired)
		local sooner = RaidPremade.validate(listing({ createdAt = NOW - 1799 }), NOW).listing
		expect(RaidPremade.status(sooner, NOW).expired).toEqual(false)
		expect(RaidPremade.status(sooner, NOW).active).toEqual(true)
		expect(RaidPremade.canJoin(sooner, player(2, "healer"), NOW).allowed).toEqual(true)
		local shut = RaidPremade.validate(listing({ closed = true }), NOW).listing
		expect(RaidPremade.status(shut, NOW).closed).toEqual(true)
		expect(RaidPremade.status(shut, NOW).active).toEqual(false)
		expect(RaidPremade.canJoin(shut, player(2, "healer"), NOW).error).toEqual(ERRORS.closed)
		local both =
			RaidPremade.validate(listing({ createdAt = NOW - 1800, closed = true }), NOW).listing
		expect(RaidPremade.canJoin(both, player(2, "healer"), NOW).error).toEqual(ERRORS.closed)
		local bad = RaidPremade.status(nil, NOW)
		expect(bad.ok).toEqual(false)
		expect(bad.full).toEqual(false)
		expect(bad.expired).toEqual(false)
		expect(bad.active).toEqual(false)
		expect(bad.openCount).toEqual(0)
		expect(RaidPremade.canJoin(row, nil, NOW).error).toEqual(ERRORS.player)
		expect(RaidPremade.canJoin(row, player(2, "bard"), NOW).error).toEqual(ERRORS.role)
		expect(RaidPremade.canJoin(row, player(2, "healer", { clears = -1 }), NOW).ok).toEqual(
			false
		)
		expect(RaidPremade.canJoin(row, player(2, "healer", { clears = -1 }), NOW).error).toEqual(
			ERRORS.clears
		)
		expect(RaidPremade.canJoin("nope", player(2, "healer"), NOW).ok).toEqual(false)
	end)

	it("closes when the host leaves and frees a slot when someone else leaves", function()
		local row = RaidPremade.validate(listing(), NOW).listing
		local joined = RaidPremade.join(row, player(2, "healer"), NOW)
		expect(#row.members).toEqual(1)
		local left = RaidPremade.depart(joined.listing, 2, NOW)
		expect(left.ok).toEqual(true)
		expect(left.hostLeft).toEqual(false)
		expect(left.closed).toEqual(false)
		expect(#left.listing.members).toEqual(1)
		expect(#joined.listing.members).toEqual(2)
		expect(joined.listing.closed).toEqual(false)
		local refill = RaidPremade.canJoin(left.listing, player(3, "healer"), NOW)
		expect(refill.allowed).toEqual(true)
		expect(refill.slot).toEqual(2)
		expect(RaidPremade.depart(joined.listing, 9, NOW).error).toEqual(ERRORS.absent)
		local closed = RaidPremade.depart(joined.listing, 1, NOW)
		expect(closed.ok).toEqual(true)
		expect(closed.hostLeft).toEqual(true)
		expect(closed.closed).toEqual(true)
		expect(closed.listing.closed).toEqual(true)
		expect(#closed.listing.members).toEqual(2)
		expect(joined.listing.closed).toEqual(false)
		expect(RaidPremade.canJoin(closed.listing, player(3, "dps"), NOW).error).toEqual(
			ERRORS.closed
		)
		expect(RaidPremade.open({ closed.listing }, listing(), NOW).ok).toEqual(true)
		local second = RaidPremade.depart(closed.listing, 1, NOW)
		expect(second.ok).toEqual(true)
		expect(second.hostLeft).toEqual(true)
		expect(second.listing.closed).toEqual(true)
		expect(second.listing == closed.listing).toEqual(false)
		expect(RaidPremade.depart(closed.listing, 2, NOW).error).toEqual(ERRORS.closed)
		expect(RaidPremade.depart(joined.listing, 0, NOW).error).toEqual(ERRORS.player)
	end)
end)
