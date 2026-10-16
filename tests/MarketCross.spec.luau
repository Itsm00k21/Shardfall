--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local MarketBoard = require("../src/ReplicatedStorage/Shared/MarketBoard")
local MarketCross = require("../src/ReplicatedStorage/Shared/MarketCross")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Trading = require("../src/ReplicatedStorage/Shared/Trading")

local function actor(id: number): Trading.Actor
	return {
		userId = id,
		name = "P" .. tostring(id),
		level = 20,
		accountAgeDays = 30,
		cleanHistoryDays = 30,
		verifiedSpender = false,
		patron = false,
		verifiedTrader = false,
		flagged = false,
		tradeLocked = false,
		recentHandoff = false,
		connected = nil,
	}
end

local function profile(gold: number, inventory: any?): any
	return {
		level = 20,
		gold = gold,
		gems = 0,
		inventory = inventory or {},
		pets = {},
		materials = {},
		chests = {},
		equipped = {
			weapon = nil,
			pet = nil,
			armor = {},
			accessories = {},
		},
		ledger = {},
		marketClaims = {},
	}
end

local function weapon(uid: string, name: string, rarity: string, paid: boolean?): any
	return {
		uid = uid,
		templateId = "blade",
		name = name,
		kind = "Weapon",
		rarity = rarity,
		traits = {},
		poolId = "verdant",
		obtainedAt = 0,
		paid = paid,
	}
end

local function context(): Trading.Context
	return {
		spent = {},
		log = {},
		server = "test-server",
		paidTradingAllowed = true,
	}
end

local function actions(log: { any }, action: string): number
	local count = 0
	for _, entry in ipairs(log) do
		if entry.action == action then
			count += 1
		end
	end
	return count
end

local function saleCount(box: any): number
	local count = 0
	if type(box) ~= "table" or type(box.entries) ~= "table" then
		return 0
	end
	for _, entry in ipairs(box.entries) do
		if entry.kind == "sale" then
			count += 1
		end
	end
	return count
end

describe("MarketCross", function()
	it("sorts by price, searches, and escrows the goods", function()
		Trading.reset()
		MarketCross.MARKET_XSERVER_ENABLED = true
		local now = 1_000_000
		local world = MarketCross.memory()
		local ctx = context()
		local seller = profile(5000, {
			["blade"] = weapon("blade", "Blade", "Rare"),
			["shield"] = weapon("shield", "Shield", "Common"),
		})
		local who = actor(11)
		local cheap = MarketCross.list(
			world,
			seller,
			who,
			{ price = 50, currency = "gold", items = { "shield" } },
			ctx,
			now
		)
		local rich = MarketCross.list(
			world,
			seller,
			who,
			{ price = 200, currency = "gold", items = { "blade" } },
			ctx,
			now + 1
		)
		expect(cheap.ok).toEqual(true)
		expect(rich.ok).toEqual(true)
		expect(Schema.findItem(seller, "blade")).toBeNil()
		expect(Schema.findItem(seller, "shield")).toBeNil()
		expect(seller.gold < 5000).toBeTrue()
		local rows = MarketCross.browse(world, { sort = "asc", kind = "Weapon" }, ctx, now + 1)
		expect(#rows).toEqual(2)
		expect(rows[1].price).toEqual(50)
		expect(rows[2].price).toEqual(200)
		local found = MarketCross.browse(world, { search = "Shield" }, ctx, now + 1)
		expect(#found).toEqual(1)
		expect(found[1].name:find("Shield", 1, true) ~= nil).toBeTrue()
		expect(actions(ctx.log, "list")).toEqual(2)
	end)

	it("lets one buyer win a double buy and pays an offline seller once", function()
		Trading.reset()
		MarketCross.MARKET_XSERVER_ENABLED = true
		local now = 2_000_000
		local world = MarketCross.memory()
		local ctx = context()
		local seller = profile(5000, { blade = weapon("blade", "Blade", "Rare") })
		local who = actor(11)
		local listed = MarketCross.list(
			world,
			seller,
			who,
			{ price = 100, currency = "gold", items = { "blade" } },
			ctx,
			now
		)
		expect(listed.ok).toEqual(true)
		local feeGold = seller.gold
		local first = profile(1000, {})
		local second = profile(1000, {})
		local won = MarketCross.buy(world, listed.listing.id, first, actor(22), ctx, now + 5)
		local lost = MarketCross.buy(world, listed.listing.id, second, actor(33), ctx, now + 6)
		expect(won.ok).toEqual(true)
		expect(lost.ok).toEqual(false)
		expect(Schema.findItem(first, "blade") ~= nil).toBeTrue()
		expect(Schema.findItem(second, "blade")).toBeNil()
		expect(first.gold).toEqual(900)
		expect(second.gold).toEqual(1000)
		expect(seller.gold).toEqual(feeGold)
		local box = world.mailbox:getAsync(tostring(who.userId))
		expect(saleCount(box)).toEqual(1)
		expect(#world.bus.published >= 1).toBeTrue()
		local paid = MarketCross.settle(world, seller, who.userId, ctx, now + 7)
		expect(paid.ok).toEqual(true)
		expect(seller.gold).toEqual(feeGold + 100)
		expect(MarketCross.ack(world, who.userId, paid.applied)).toEqual(true)
		local again = MarketCross.settle(world, seller, who.userId, ctx, now + 8)
		expect(again.ok).toEqual(true)
		expect(seller.gold).toEqual(feeGold + 100)
		expect(actions(ctx.log, "buy")).toEqual(1)
		expect(actions(ctx.log, "payout")).toEqual(1)
	end)

	it("keeps the buy when the payout mailbox fails, then pays once", function()
		Trading.reset()
		MarketCross.MARKET_XSERVER_ENABLED = true
		local now = 3_000_000
		local world = MarketCross.memory()
		local ctx = context()
		local seller = profile(5000, { blade = weapon("blade", "Blade", "Rare") })
		local who = actor(11)
		local listed = MarketCross.list(
			world,
			seller,
			who,
			{ price = 100, currency = "gold", items = { "blade" } },
			ctx,
			now
		)
		expect(listed.ok).toEqual(true)
		local feeGold = seller.gold
		world.mailbox.throws = 20
		local buyer = profile(1000, {})
		local bought = MarketCross.buy(world, listed.listing.id, buyer, actor(22), ctx, now + 5)
		expect(bought.ok).toEqual(true)
		expect(bought.payoutPending).toEqual(true)
		expect(Schema.findItem(buyer, "blade") ~= nil).toBeTrue()
		expect(seller.gold).toEqual(feeGold)
		expect(saleCount(world.mailbox:getAsync(tostring(who.userId)))).toEqual(0)
		world.mailbox.throws = 0
		expect(MarketCross.flushPayout(world, bought.record, now + 6)).toEqual(true)
		expect(seller.gold).toEqual(feeGold)
		local paid = MarketCross.settle(world, seller, who.userId, ctx, now + 7)
		expect(seller.gold).toEqual(feeGold + 100)
		MarketCross.ack(world, who.userId, paid.applied)
		local again = MarketCross.settle(world, seller, who.userId, ctx, now + 8)
		expect(again.ok).toEqual(true)
		expect(seller.gold).toEqual(feeGold + 100)
	end)

	it("returns expired goods to an offline seller and refuses the late buy", function()
		Trading.reset()
		MarketCross.MARKET_XSERVER_ENABLED = true
		local now = 4_000_000
		local world = MarketCross.memory()
		local ctx = context()
		local seller = profile(5000, { blade = weapon("blade", "Blade", "Rare") })
		local who = actor(11)
		local listed = MarketCross.list(
			world,
			seller,
			who,
			{ price = 100, currency = "gold", items = { "blade" } },
			ctx,
			now
		)
		expect(listed.ok).toEqual(true)
		local feeGold = seller.gold
		local later = now + MarketBoard.LISTING_SECONDS + 5
		local expired = MarketCross.expire(world, listed.listing.id, ctx, later)
		expect(expired.ok).toEqual(true)
		expect(Schema.findItem(seller, "blade")).toBeNil()
		local buyer = profile(1000, {})
		local missed = MarketCross.buy(world, listed.listing.id, buyer, actor(22), ctx, later)
		expect(missed.ok).toEqual(false)
		expect(Schema.findItem(buyer, "blade")).toBeNil()
		local back = MarketCross.settle(world, seller, who.userId, ctx, later)
		expect(Schema.findItem(seller, "blade") ~= nil).toBeTrue()
		expect(seller.gold).toEqual(feeGold)
		MarketCross.ack(world, who.userId, back.applied)
		local twice = MarketCross.settle(world, seller, who.userId, ctx, later + 1)
		expect(twice.ok).toEqual(true)
		expect(seller.gold).toEqual(feeGold)
		expect(actions(ctx.log, "expire") >= 1).toBeTrue()
	end)

	it("releases a claim when the buyer save fails so the goods sell once", function()
		Trading.reset()
		MarketCross.MARKET_XSERVER_ENABLED = true
		local now = 5_000_000
		local world = MarketCross.memory()
		local ctx = context()
		local seller = profile(5000, { blade = weapon("blade", "Blade", "Rare") })
		local listed = MarketCross.list(
			world,
			seller,
			actor(11),
			{ price = 100, currency = "gold", items = { "blade" } },
			ctx,
			now
		)
		expect(listed.ok).toEqual(true)
		local buyer = profile(1000, {})
		local snap = Trading.capture(buyer)
		local reserved =
			MarketCross.reserveBuy(world, listed.listing.id, buyer, actor(22), ctx, now + 5)
		expect(reserved.ok).toEqual(true)
		expect(Schema.findItem(buyer, "blade") ~= nil).toBeTrue()
		Trading.restore(buyer, snap)
		expect(Schema.findItem(buyer, "blade")).toBeNil()
		expect(MarketCross.releaseClaim(world, listed.listing.id, 22, now + 6)).toEqual(true)
		local other = profile(1000, {})
		local sold = MarketCross.buy(world, listed.listing.id, other, actor(33), ctx, now + 7)
		expect(sold.ok).toEqual(true)
		expect(Schema.findItem(other, "blade") ~= nil).toBeTrue()
		expect(Schema.findItem(buyer, "blade")).toBeNil()
	end)

	it(
		"retries a throttled listing write and restores the bag when the store stays down",
		function()
			Trading.reset()
			MarketCross.MARKET_XSERVER_ENABLED = true
			local now = 6_000_000
			local world = MarketCross.memory()
			local ctx = context()
			local seller = profile(5000, { blade = weapon("blade", "Blade", "Rare") })
			world.listings.throws = 2
			local listed = MarketCross.list(
				world,
				seller,
				actor(11),
				{ price = 100, currency = "gold", items = { "blade" } },
				ctx,
				now
			)
			expect(listed.ok).toEqual(true)
			expect(Schema.findItem(seller, "blade")).toBeNil()

			local again = profile(5000, { blade = weapon("blade", "Blade", "Rare") })
			world.listings.throws = 20
			local failed = MarketCross.list(
				world,
				again,
				actor(11),
				{ price = 100, currency = "gold", items = { "blade" } },
				ctx,
				now + 1
			)
			expect(failed.ok).toEqual(false)
			expect(Schema.findItem(again, "blade") ~= nil).toBeTrue()
			expect(again.gold).toEqual(5000)
		end
	)

	it("refuses a Robux item and stays quiet when the kill switch is off", function()
		Trading.reset()
		MarketCross.MARKET_XSERVER_ENABLED = true
		local now = 7_000_000
		local world = MarketCross.memory()
		local ctx = context()
		local seller = profile(5000, { blade = weapon("blade", "Blade", "Rare", true) })
		local refused = MarketCross.list(
			world,
			seller,
			actor(11),
			{ price = 100, currency = "gold", items = { "blade" } },
			ctx,
			now
		)
		expect(refused.ok).toEqual(false)
		expect(Schema.findItem(seller, "blade") ~= nil).toBeTrue()
		expect(seller.gold).toEqual(5000)

		MarketCross.MARKET_XSERVER_ENABLED = false
		local plain = profile(5000, { blade = weapon("blade", "Blade", "Rare") })
		local blocked = MarketCross.list(
			world,
			plain,
			actor(11),
			{ price = 100, currency = "gold", items = { "blade" } },
			ctx,
			now
		)
		expect(blocked.ok).toEqual(false)
		expect(Schema.findItem(plain, "blade") ~= nil).toBeTrue()
		MarketCross.MARKET_XSERVER_ENABLED = true
	end)

	it("cancels into the mailbox and strips a duplicated escrowed item", function()
		Trading.reset()
		MarketCross.MARKET_XSERVER_ENABLED = true
		local now = 8_000_000
		local world = MarketCross.memory()
		local ctx = context()
		local seller = profile(5000, { blade = weapon("blade", "Blade", "Rare") })
		local copy = Schema.deepCopy(seller.inventory.blade)
		local who = actor(11)
		local listed = MarketCross.list(
			world,
			seller,
			who,
			{ price = 80, currency = "gold", items = { "blade" } },
			ctx,
			now
		)
		expect(listed.ok).toEqual(true)
		Trading.giveItem(seller, copy)
		expect(Schema.findItem(seller, "blade") ~= nil).toBeTrue()
		local settled = MarketCross.settle(world, seller, who.userId, ctx, now + 1)
		expect(settled.ok).toEqual(true)
		expect(Schema.findItem(seller, "blade")).toBeNil()
		local cancelled = MarketCross.cancel(world, who, listed.listing.id, ctx, now + 2)
		expect(cancelled.ok).toEqual(true)
		local back = MarketCross.settle(world, seller, who.userId, ctx, now + 3)
		expect(Schema.findItem(seller, "blade") ~= nil).toBeTrue()
		expect(actions(ctx.log, "cancel")).toEqual(1)
		MarketCross.ack(world, who.userId, back.applied)
	end)
end)
