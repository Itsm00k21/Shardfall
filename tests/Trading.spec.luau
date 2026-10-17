--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local MarketBoard = require("../src/ReplicatedStorage/Shared/MarketBoard")
local MemoryStore = require("../src/ReplicatedStorage/Shared/MemoryStore")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local TradeAudit = require("../src/ServerScriptService/ShardfallServer/TradeAudit")
local Trading = require("../src/ReplicatedStorage/Shared/Trading")

local function hasFlag(flags: any, name: string): boolean
	if type(flags) ~= "table" then
		return false
	end
	for _, flag in ipairs(flags) do
		if flag == name then
			return true
		end
	end
	return false
end

local function actor(id: number, level: number, age: number, extra: any?): Trading.Actor
	local more = extra or {}
	return {
		userId = id,
		name = "P" .. tostring(id),
		level = level,
		accountAgeDays = age,
		cleanHistoryDays = more.clean or age,
		verifiedSpender = more.spender == true,
		patron = more.patron == true,
		verifiedTrader = more.verified == true,
		flagged = more.flagged == true,
		tradeLocked = more.locked == true,
		recentHandoff = more.handoff == true,
		connected = more.connected,
	}
end

local function profile(
	gold: number,
	inventory: any?,
	materials: any?,
	chests: any?,
	gems: number?
): any
	return {
		level = 20,
		gold = gold,
		gems = gems or 0,
		inventory = inventory or {},
		pets = {},
		materials = materials or {},
		chests = chests or {},
		equipped = {
			weapon = nil,
			pet = nil,
			armor = {},
			accessories = {},
		},
		ledger = {},
	}
end

local function weapon(uid: string, rarity: string, obtained: number, extra: any?): any
	local more = extra or {}
	return {
		uid = uid,
		templateId = more.templateId or "blade",
		name = more.name or "Blade",
		kind = more.kind or "Weapon",
		rarity = rarity,
		traits = {},
		poolId = "verdant",
		obtainedAt = obtained,
		locked = more.locked,
		starter = more.starter,
		bound = more.bound,
		paid = more.paid,
		source = more.source,
		exploit = more.exploit,
		sockets = more.sockets,
		stats = more.stats,
		upgrade = more.upgrade,
		stars = more.stars,
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

local function spec(name: string, fn: () -> ())
	it(name, function()
		Trading.reset()
		Trading.GEM_TRADING_ENABLED = true
		Trading.ROBUX_ITEM_TRADING_ENABLED = false
		fn()
	end)
end

describe("Trading", function()
	spec("sorts trust tiers and daily caps", function()
		expect(Trading.tier(actor(1, 10, 3))).toEqual("New")
		expect(Trading.tier(actor(1, 15, 13))).toEqual("New")
		expect(Trading.tier(actor(1, 40, 10))).toEqual("New")
		expect(Trading.tier(actor(1, 15, 14))).toEqual("Standard")
		expect(Trading.tier(actor(1, 16, 20))).toEqual("Standard")
		expect(Trading.tier(actor(1, 40, 14))).toEqual("Trusted")
		expect(Trading.tier(actor(1, 10, 20, { spender = true }))).toEqual("Trusted")
		expect(Trading.tier(actor(1, 10, 3, { spender = true }))).toEqual("New")
		expect(Trading.tier(actor(1, 12, 80, { clean = 60 }))).toEqual("Trusted")
		expect(Trading.tier(actor(1, 4, 1, { patron = true }))).toEqual("Patron")
		expect(Trading.tier(actor(1, 10, 80, { verified = true, clean = 60 }))).toEqual("Patron")
		expect(Trading.dailyCap(actor(1, 15, 14))).toEqual(50000)
		expect(Trading.dailyCap(actor(1, 16, 20))).toEqual(55000)
		expect(Trading.dailyCap(actor(1, 39, 30))).toEqual(150000)
		expect(Trading.dailyCap(actor(1, 55, 30))).toEqual(2000000)
		expect(Trading.dailyCap(actor(1, 40, 14))).toEqual(2000000)
		expect(Trading.dailyCap(actor(1, 10, 20, { spender = true }))).toEqual(150000)
		expect(Trading.tradeCap(actor(1, 10, 20, { spender = true }))).toEqual(150000)
		expect(Trading.dailyCap(actor(1, 10, 3, { spender = true }))).toEqual(2000)
		expect(Trading.dailyCap(actor(1, 40, 14, { spender = true }))).toEqual(2000000)
		expect(Trading.dailyCap(actor(1, 12, 80, { clean = 60, spender = true }))).toEqual(2000000)
		expect(Trading.CAPS.Receipt).toEqual(150000)
		expect(Trading.CAPS.Receipt).toEqual(Trading.CAPS.StandardMax)
		expect(Trading.CAPS.Trusted).toEqual(2000000)
		expect(Trading.dailyCap(actor(1, 4, 1, { patron = true }))).toEqual(2000)
		expect(Trading.ROBUX_ITEM_TRADING_ENABLED).toEqual(false)
	end)

	spec("exploit: vip does not raise the patron daily cap", function()
		local function flags(extra: any?, patron: boolean): any
			local copy = { patron = patron }
			if type(extra) == "table" then
				for key, value in pairs(extra) do
					copy[key] = value
				end
			end
			copy.patron = patron
			return copy
		end

		local function sameCap(level: number, age: number, extra: any?)
			local paid = actor(1, level, age, flags(extra, true))
			local free = actor(1, level, age, flags(extra, false))
			local freeExtra = flags(extra, false)
			local cap = Trading.dailyCap(paid)
			expect(cap).toEqual(Trading.dailyCap(free))
			expect(cap < math.huge).toBeTrue()
			expect(cap <= Trading.CAPS.Trusted).toBeTrue()
			expect(cap).toEqual(Trading.tradeCap(paid))
			local earnedTrusted = age >= Trading.NEW_ACCOUNT_DAYS
				and (
					level >= Trading.TRUSTED_LEVEL
					or (freeExtra.clean or age) >= Trading.CLEAN_DAYS
				)
			if not earnedTrusted then
				expect(cap <= Trading.CAPS.Receipt).toBeTrue()
			end
		end

		expect(Trading.tier(actor(1, 4, 1, { patron = true }))).toEqual("Patron")
		expect(Trading.dailyCap(actor(1, 4, 1, { patron = true }))).toEqual(Trading.CAPS.New)
		expect(Trading.dailyCap(actor(1, 4, 1, { patron = true }))).toEqual(2000)
		sameCap(4, 1)
		sameCap(10, 30)
		sameCap(15, 14)
		sameCap(39, 30)
		sameCap(40, 14)
		sameCap(55, 30)
		sameCap(10, 20, { spender = true })
		sameCap(12, 80, { clean = 60 })
		sameCap(10, 80, { verified = true, clean = 60 })

		local opted = actor(1, 10, 80, { verified = true, clean = 60 })
		expect(Trading.tier(opted)).toEqual("Patron")
		expect(Trading.dailyCap(opted)).toEqual(Trading.CAPS.Trusted)
		expect(Trading.dailyCap(opted) < math.huge).toBeTrue()

		local youngVip = actor(1, 40, 13, { patron = true })
		expect(Trading.tier(youngVip)).toEqual("Patron")
		expect(Trading.dailyCap(youngVip)).toEqual(2000)

		local standardVip = actor(1, 39, 30, { patron = true })
		expect(Trading.dailyCap(standardVip)).toEqual(150000)
		expect(Trading.dailyCap(standardVip)).toEqual(Trading.CAPS.Receipt)
		expect(Trading.dailyCap(standardVip)).toEqual(Trading.dailyCap(actor(1, 39, 30)))

		local trustedVip = actor(1, 40, 14, { patron = true })
		local trustedFree = actor(1, 40, 14)
		expect(Trading.dailyCap(trustedVip)).toEqual(Trading.dailyCap(trustedFree))
		expect(Trading.dailyCap(trustedVip)).toEqual(Trading.CAPS.Trusted)
		expect(Trading.dailyCap(trustedVip) > Trading.CAPS.Receipt).toBeTrue()

		local now = 90_000
		local ctx = context()
		local other = actor(2, 40, 80)
		local serial = 0
		local function goldTrade(who: Trading.Actor, gold: number): Trading.Result
			serial += 1
			local left = profile(gold + 1000)
			local right = profile(0)
			local session = Trading.open("patron-cap-" .. tostring(serial), who.userId, 2, now)
			assert(session ~= nil)
			expect(Trading.setOffer(session, who.userId, { gold = gold }, now)).toEqual(true)
			local ready = now + Trading.LOCK_SECONDS
			expect(Trading.confirm(session, who.userId, ready)).toEqual(true)
			expect(Trading.confirm(session, 2, ready)).toEqual(true)
			return Trading.finish(session, who.userId, left, right, who, other, ctx, ready, true)
		end

		local overNew = goldTrade(actor(9, 4, 1, { patron = true }), 2001)
		expect(overNew.ok).toEqual(false)
		expect(overNew.error).toEqual("That trade is over today's limit.")
		local atNew = goldTrade(actor(9, 4, 1, { patron = true }), 2000)
		expect(atNew.ok).toEqual(true)

		local overReceipt = goldTrade(actor(8, 39, 30, { patron = true }), 150001)
		expect(overReceipt.ok).toEqual(false)
		expect(overReceipt.error).toEqual("That trade is over today's limit.")
		local atReceipt = goldTrade(actor(8, 39, 30, { patron = true }), 150000)
		expect(atReceipt.ok).toEqual(true)

		local overTrusted = goldTrade(actor(7, 40, 14, { patron = true }), 2000001)
		expect(overTrusted.ok).toEqual(false)
		expect(overTrusted.error).toEqual("That trade is over today's limit.")
		local atTrusted = goldTrade(actor(7, 40, 14, { patron = true }), 2000000)
		expect(atTrusted.ok).toEqual(true)
	end)

	spec("taxes gold at 10 percent and describes an item", function()
		expect(Trading.goldTax(1000)).toEqual(100)
		expect(Trading.goldTax(9)).toEqual(0)
		local text = Trading.tooltip({
			name = "Blade",
			rarity = "Rare",
			kind = "Weapon",
			sockets = 2,
			stats = { { display = "+4 damage" } },
		})
		expect(text).toEqual("Blade (Rare Weapon) sockets 2 +4 damage")
		expect(Trading.estimateItem(weapon("a", "Rare", 0))).toEqual(600)
	end)

	spec("swaps both sides once, sinks the gold tax, and writes an audit row", function()
		local now = 1_000_000
		local leftItem = weapon("left-item", "Rare", 0)
		local rightItem =
			weapon("right-item", "Common", 0, { name = "Shield", templateId = "shield" })
		local left = profile(5000, { ["left-item"] = leftItem })
		local right = profile(1000, { ["right-item"] = rightItem })
		local ctx = context()
		local leftActor = actor(11, 20, 30)
		local rightActor = actor(22, 22, 40)
		local session = Trading.open("deal", 11, 22, now)
		expect(session ~= nil).toBeTrue()
		assert(session ~= nil)
		expect(Trading.setOffer(session, 11, { gold = 1000, items = { "left-item" } }, now)).toEqual(
			true
		)
		expect(Trading.setOffer(session, 22, { items = { "right-item" } }, now + 1)).toEqual(true)
		local ready = now + 1 + Trading.LOCK_SECONDS
		expect(Trading.confirm(session, 11, ready)).toEqual(true)
		expect(Trading.confirm(session, 22, ready)).toEqual(true)
		local first =
			Trading.finish(session, 11, left, right, leftActor, rightActor, ctx, ready, true)
		expect(first.pending).toEqual(true)
		expect(Schema.findItem(left, "left-item") ~= nil).toBeTrue()
		local second =
			Trading.finish(session, 22, left, right, leftActor, rightActor, ctx, ready, true)
		expect(second.ok).toEqual(true)
		expect(second.auditId ~= nil).toBeTrue()
		expect(Schema.findItem(left, "left-item")).toBeNil()
		expect(Schema.findItem(right, "left-item") ~= nil).toBeTrue()
		expect(Schema.findItem(left, "right-item") ~= nil).toBeTrue()
		expect(Schema.findItem(right, "right-item")).toBeNil()
		expect(left.gold).toEqual(4000)
		expect(right.gold).toEqual(1900)
		local again =
			Trading.finish(session, 22, left, right, leftActor, rightActor, ctx, ready, true)
		expect(again.already).toEqual(true)
		expect(again.auditId).toEqual(second.auditId)
		expect(left.gold).toEqual(4000)
		expect(Schema.findItem(right, "left-item") ~= nil).toBeTrue()
		expect(Schema.findItem(left, "left-item")).toBeNil()
		local entry = Trading.findEntry(ctx.log, second.auditId :: string)
		expect(entry ~= nil).toBeTrue()
		assert(entry ~= nil)
		expect(entry.kind).toEqual("trade")
		expect(entry.server).toEqual("test-server")
		expect(entry.timestamp).toEqual(ready)
		expect(entry.left.userId).toEqual(11)
		expect(entry.right.userId).toEqual(22)
		expect(entry.left.level).toEqual(20)
		expect(entry.left.accountAgeDays).toEqual(30)
		expect(entry.right.accountAgeDays).toEqual(40)
		expect(entry.estimatedValue[11] > 0).toBeTrue()
		expect(entry.reversed).toEqual(false)
		local client = Trading.clientEntry(entry)
		expect(client.left.accountAgeDays).toBeNil()
		local found = Trading.search(ctx.log, { userId = 22, templateId = "blade" })
		expect(#found).toEqual(1)
		expect(left.ledger[#left.ledger].reason).toEqual("trade")
		expect(left.ledger[#left.ledger].currency).toEqual("gold")
	end)

	spec("restores both profiles when the commit fails halfway", function()
		local now = 1_000_000
		local leftItem = weapon("left-item", "Rare", 0)
		local rightItem =
			weapon("right-item", "Common", 0, { name = "Shield", templateId = "shield" })
		local left = profile(5000, { ["left-item"] = leftItem })
		local right = profile(1000, { ["right-item"] = rightItem })
		local ctx = context()
		local leftActor = actor(11, 20, 30)
		local rightActor = actor(22, 22, 40)
		local session = Trading.open("rollback", 11, 22, now)
		assert(session ~= nil)
		expect(Trading.setOffer(session, 11, { gold = 1000, items = { "left-item" } }, now)).toEqual(
			true
		)
		expect(Trading.setOffer(session, 22, { items = { "right-item" } }, now + 1)).toEqual(true)
		local ready = now + 1 + Trading.LOCK_SECONDS
		expect(Trading.confirm(session, 11, ready)).toEqual(true)
		expect(Trading.confirm(session, 22, ready)).toEqual(true)
		local first =
			Trading.finish(session, 11, left, right, leftActor, rightActor, ctx, ready, true)
		expect(first.pending).toEqual(true)
		local beforeLeft = Schema.deepCopy(left)
		local beforeRight = Schema.deepCopy(right)
		local original = Trading.giveMoney
		Trading.giveMoney = function()
			error("grant failed")
		end
		local callOk, result = pcall(function()
			return Trading.finish(session, 22, left, right, leftActor, rightActor, ctx, ready, true)
		end)
		Trading.giveMoney = original
		expect(callOk).toEqual(true)
		assert(type(result) == "table")
		expect(result.ok).toEqual(false)
		expect(left.gold).toEqual(beforeLeft.gold)
		expect(right.gold).toEqual(beforeRight.gold)
		expect(Schema.findItem(left, "left-item") ~= nil).toBeTrue()
		expect(Schema.findItem(right, "left-item")).toBeNil()
		expect(Schema.findItem(right, "right-item") ~= nil).toBeTrue()
		expect(Schema.findItem(left, "right-item")).toBeNil()
		expect(#ctx.log).toEqual(0)
		expect(session.status).toEqual("open")
		expect(session.left.committed).toEqual(false)
		expect(session.right.committed).toEqual(false)
	end)

	spec("drops the audit row when the commit fails after the log write", function()
		local now = 2_000_000
		local leftItem = weapon("left-item", "Rare", 0)
		local rightItem = weapon("right-item", "Common", 0)
		local left = profile(5000, { ["left-item"] = leftItem })
		local right = profile(1000, { ["right-item"] = rightItem })
		local ctx = context()
		local leftActor = actor(11, 20, 30)
		local rightActor = actor(22, 22, 40)
		local session = Trading.open("audit-fail", 11, 22, now)
		assert(session ~= nil)
		expect(Trading.setOffer(session, 11, { gold = 1000, items = { "left-item" } }, now)).toEqual(
			true
		)
		expect(Trading.setOffer(session, 22, { items = { "right-item" } }, now + 1)).toEqual(true)
		local ready = now + 1 + Trading.LOCK_SECONDS
		expect(Trading.confirm(session, 11, ready)).toEqual(true)
		expect(Trading.confirm(session, 22, ready)).toEqual(true)
		local first =
			Trading.finish(session, 11, left, right, leftActor, rightActor, ctx, ready, true)
		expect(first.pending).toEqual(true)
		local beforeLeft = Schema.deepCopy(left)
		local beforeRight = Schema.deepCopy(right)
		local original = Trading.append
		Trading.append = function(logContext, entry, stamp)
			original(logContext, entry, stamp)
			error("audit failed")
		end
		local callOk, result = pcall(function()
			return Trading.finish(session, 22, left, right, leftActor, rightActor, ctx, ready, true)
		end)
		Trading.append = original
		expect(callOk).toEqual(true)
		assert(type(result) == "table")
		expect(result.ok).toEqual(false)
		expect(left.gold).toEqual(beforeLeft.gold)
		expect(right.gold).toEqual(beforeRight.gold)
		expect(Schema.findItem(left, "left-item") ~= nil).toBeTrue()
		expect(Schema.findItem(right, "right-item") ~= nil).toBeTrue()
		expect(#ctx.log).toEqual(0)
		expect(session.status).toEqual("open")
	end)

	spec("round-trips the trade audit log through memory", function()
		local store = MemoryStore.new()
		TradeAudit.bind(store)
		local row = { id = "trade-1", kind = "trade" }
		expect(TradeAudit.save({ row })).toEqual(true)
		local loaded = TradeAudit.load()
		expect(#loaded).toEqual(1)
		expect(loaded[1].id).toEqual("trade-1")
		expect(loaded[1].kind).toEqual("trade")
		local again = TradeAudit.load()
		expect(again[1].id).toEqual("trade-1")
	end)

	spec("refuses a commit until both players confirm and the lock has passed", function()
		local now = 5000
		local left = profile(100, { a = weapon("a", "Common", 0) })
		local right = profile(100, {})
		local ctx = context()
		local leftActor = actor(1, 20, 30)
		local rightActor = actor(2, 20, 30)
		local session = Trading.open("lock", 1, 2, now)
		assert(session ~= nil)
		expect(Trading.confirm(session, 1, now)).toEqual(false)
		expect(Trading.setOffer(session, 1, { items = { "a" } }, now)).toEqual(true)
		expect(Trading.confirm(session, 1, now + 2)).toEqual(false)
		expect(Trading.confirm(session, 1, now + 3)).toEqual(true)
		local early =
			Trading.finish(session, 1, left, right, leftActor, rightActor, ctx, now + 3, true)
		expect(early.ok).toEqual(true)
		expect(early.pending).toEqual(true)
		local otherEarly =
			Trading.finish(session, 2, left, right, leftActor, rightActor, ctx, now + 3, true)
		expect(otherEarly.error).toEqual("Confirm the trade first.")
		expect(Schema.findItem(left, "a") ~= nil).toBeTrue()
		expect(Trading.setOffer(session, 1, { items = { "a" } }, now + 10)).toEqual(true)
		expect(session.left.confirmed).toEqual(false)
		expect(Trading.confirm(session, 1, now + 12)).toEqual(false)
		expect(Trading.confirm(session, 1, now + 13)).toEqual(true)
		expect(Trading.confirm(session, 2, now + 13)).toEqual(true)
		session.settling = true
		local racing =
			Trading.finish(session, 1, left, right, leftActor, rightActor, ctx, now + 13, true)
		expect(racing.error).toEqual("That trade is already finishing.")
		expect(Schema.findItem(left, "a") ~= nil).toBeTrue()
		session.settling = false
		expect(Trading.open("self", 1, 1, now)).toBeNil()
	end)

	spec("puts both profiles back when the bag changed after the offer", function()
		local now = 8000
		local item = weapon("a", "Rare", 0)
		local left = profile(100, { a = item })
		local right = profile(50, {})
		local ctx = context()
		local leftActor = actor(1, 20, 30)
		local rightActor = actor(2, 20, 30)
		local session = Trading.open("stale", 1, 2, now)
		assert(session ~= nil)
		Trading.setOffer(session, 1, { items = { "a" } }, now)
		Trading.setOffer(session, 2, { gold = 50 }, now)
		local ready = now + Trading.LOCK_SECONDS
		Trading.confirm(session, 1, ready)
		Trading.confirm(session, 2, ready)
		right.gold = 0
		local failed =
			Trading.finish(session, 1, left, right, leftActor, rightActor, ctx, ready, true)
		expect(failed.ok).toEqual(false)
		expect(failed.error).toEqual("Not enough gold.")
		expect(Schema.findItem(left, "a") ~= nil).toBeTrue()
		expect(right.gold).toEqual(0)
		expect(#ctx.log).toEqual(0)
		right.gold = 50
		left.equipped.weapon = "a"
		Trading.confirm(session, 1, ready)
		Trading.confirm(session, 2, ready)
		local equipped =
			Trading.finish(session, 1, left, right, leftActor, rightActor, ctx, ready, true)
		expect(equipped.error).toEqual("That item is equipped.")
		expect(right.gold).toEqual(50)
		left.equipped.weapon = nil
		left.inventory.a = nil
		Trading.confirm(session, 1, ready)
		Trading.confirm(session, 2, ready)
		local missing =
			Trading.finish(session, 2, left, right, leftActor, rightActor, ctx, ready, true)
		expect(missing.ok).toEqual(false)
		expect(Schema.findItem(right, "a")).toBeNil()
		expect(right.gold).toEqual(50)
	end)

	spec("blocks bound goods, new-tier gems, and flagged accounts", function()
		local now = 20_000
		local ctx = context()
		local function rejected(item: any, who: Trading.Actor, message: string)
			local left = profile(1000, { a = item }, nil, nil, 50)
			local right = profile(1000, {}, nil, nil, 50)
			local session = Trading.open(Trading.nextId("b", now), who.userId, 9, now)
			assert(session ~= nil)
			Trading.setOffer(session, who.userId, { items = { "a" }, gems = 0 }, now)
			local ready = now + Trading.LOCK_SECONDS
			Trading.confirm(session, who.userId, ready)
			Trading.confirm(session, 9, ready)
			local result = Trading.finish(
				session,
				who.userId,
				left,
				right,
				who,
				actor(9, 20, 30),
				ctx,
				ready,
				true
			)
			expect(result.error).toEqual(message)
			expect(Schema.findItem(left, "a") ~= nil).toBeTrue()
		end
		rejected(
			weapon("a", "Rare", 0, { starter = true }),
			actor(1, 20, 30),
			"Starter gear is bound."
		)
		rejected(
			weapon("a", "Rare", 0, { templateId = "starter_sword" }),
			actor(1, 20, 30),
			"Starter gear is bound."
		)
		rejected(
			weapon("a", "Rare", 0, { source = "robux" }),
			actor(1, 20, 30),
			"Robux items stay bound."
		)
		rejected(
			weapon("a", "Rare", 0, { locked = true }),
			actor(1, 20, 30),
			"That item is locked."
		)
		rejected(
			weapon("a", "Rare", 0, { exploit = true }),
			actor(1, 20, 30),
			"That item cannot be traded."
		)
		rejected(
			weapon("a", "Mythic", now - 10),
			actor(1, 20, 30),
			"Mythic shards bind for 7 days."
		)
		local aged = weapon("a", "Mythic", now - Trading.MYTHIC_BIND_SECONDS)
		local left = profile(0, { a = aged })
		local right = profile(0, {})
		local veteran = actor(1, 20, 30)
		local other = actor(9, 20, 30)
		local session = Trading.open("mythic-old", 1, 9, now)
		assert(session ~= nil)
		Trading.setOffer(session, 1, { items = { "a" } }, now)
		local ready = now + Trading.LOCK_SECONDS
		Trading.confirm(session, 1, ready)
		Trading.confirm(session, 9, ready)
		local moved = Trading.finish(session, 1, left, right, veteran, other, ctx, ready, true)
		expect(moved.pending).toEqual(true)
		local done = Trading.finish(session, 9, left, right, veteran, other, ctx, ready, true)
		expect(done.ok).toEqual(true)
		expect(Schema.findItem(right, "a") ~= nil).toBeTrue()

		local newbie = actor(3, 10, 2)
		local gemsLeft = profile(0, {}, nil, nil, 5)
		local gemsRight = profile(0, {}, nil, nil, 0)
		local gemSession = Trading.open("gems", 3, 9, now)
		assert(gemSession ~= nil)
		Trading.setOffer(gemSession, 3, { gems = 2 }, now)
		Trading.confirm(gemSession, 3, ready)
		Trading.confirm(gemSession, 9, ready)
		local gemTry =
			Trading.finish(gemSession, 3, gemsLeft, gemsRight, newbie, other, ctx, ready, true)
		expect(gemTry.error).toEqual("Gems unlock once your account is Standard.")
		expect(gemsLeft.gems).toEqual(5)

		local standard = actor(4, 18, 20)
		local payer = profile(0, {}, nil, nil, 5)
		local payee = profile(0, {}, nil, nil, 1)
		local okSession = Trading.open("gems-ok", 4, 9, now)
		assert(okSession ~= nil)
		Trading.setOffer(okSession, 4, { gems = 2 }, now)
		Trading.confirm(okSession, 4, ready)
		Trading.confirm(okSession, 9, ready)
		Trading.finish(okSession, 4, payer, payee, standard, other, ctx, ready, true)
		local gemDone =
			Trading.finish(okSession, 9, payer, payee, standard, other, ctx, ready, true)
		expect(gemDone.ok).toEqual(true)
		expect(payer.gems).toEqual(3)
		expect(payee.gems).toEqual(3)

		local gift = profile(0, {}, nil, nil, 4)
		local child = profile(0)
		local giftSession = Trading.open("gift-gems", 4, 3, now)
		assert(giftSession ~= nil)
		Trading.setOffer(giftSession, 4, { gems = 1 }, now)
		Trading.confirm(giftSession, 4, ready)
		Trading.confirm(giftSession, 3, ready)
		local gifted =
			Trading.finish(giftSession, 4, gift, child, standard, newbie, context(), ready, true)
		expect(gifted.error).toEqual("Gems unlock once your account is Standard.")
		expect(gift.gems).toEqual(4)
		expect(child.gems).toEqual(0)

		ctx.paidTradingAllowed = false
		local blocked = profile(0, {}, nil, nil, 5)
		local blockedSession = Trading.open("region", 4, 9, now)
		assert(blockedSession ~= nil)
		Trading.setOffer(blockedSession, 4, { gems = 1 }, now)
		Trading.confirm(blockedSession, 4, ready)
		Trading.confirm(blockedSession, 9, ready)
		local region =
			Trading.finish(blockedSession, 4, blocked, payee, standard, other, ctx, ready, true)
		expect(region.error).toEqual("Gem trades are off in this region.")
		expect(blocked.gems).toEqual(5)

		local flagged = actor(8, 40, 80, { flagged = true })
		local bag = profile(10, { a = weapon("a", "Common", 0) })
		local flagSession = Trading.open("flag", 8, 9, now)
		assert(flagSession ~= nil)
		Trading.setOffer(flagSession, 8, { items = { "a" } }, now)
		Trading.confirm(flagSession, 8, ready)
		Trading.confirm(flagSession, 9, ready)
		local stopped =
			Trading.finish(flagSession, 8, bag, profile(0), flagged, other, context(), ready, true)
		expect(stopped.error).toEqual("This account cannot trade.")
		expect(Schema.findItem(bag, "a") ~= nil).toBeTrue()
	end)

	spec("warns on a lopsided trade and still lets a trusted player through", function()
		local now = 40_000
		local left = profile(95)
		local right = profile(5)
		local ctx = context()
		local giver = actor(1, 40, 80)
		local taker = actor(2, 40, 80)
		local session = Trading.open("lop", 1, 2, now)
		assert(session ~= nil)
		Trading.setOffer(session, 1, { gold = 95 }, now)
		Trading.setOffer(session, 2, { gold = 5 }, now)
		local ready = now + Trading.LOCK_SECONDS
		Trading.confirm(session, 1, ready)
		Trading.confirm(session, 2, ready)
		local warned = Trading.finish(session, 1, left, right, giver, taker, ctx, ready, false)
		expect(warned.needsWarning).toEqual(true)
		expect(warned.error).toEqual("You're giving ~95% of the value. Continue?")
		expect(left.gold).toEqual(95)
		local pending = Trading.finish(session, 2, left, right, giver, taker, ctx, ready, false)
		expect(pending.pending).toEqual(true)
		local done = Trading.finish(session, 1, left, right, giver, taker, ctx, ready, true)
		expect(done.ok).toEqual(true)
		expect(hasFlag(done.flags, "lopsided")).toBeTrue()
		expect(left.gold).toEqual(5)
		expect(right.gold).toEqual(86)
	end)

	spec("flags a repeat loop and a funnel without blocking it", function()
		local now = 80_000
		local ctx = context()
		local function pass(id: number, templateId: string, stamp: number)
			local item = weapon("u" .. id, "Common", 0, { templateId = templateId, name = "Loop" })
			local left = profile(0, { ["u" .. id] = item })
			local right = profile(0, {})
			local a = actor(1, 40, 90)
			local b = actor(2, 40, 90)
			local session = Trading.open("r" .. id, 1, 2, stamp)
			assert(session ~= nil)
			Trading.setOffer(session, 1, { items = { "u" .. id } }, stamp)
			local ready = stamp + Trading.LOCK_SECONDS
			Trading.confirm(session, 1, ready)
			Trading.confirm(session, 2, ready)
			Trading.finish(session, 1, left, right, a, b, ctx, ready, true)
			return Trading.finish(session, 2, left, right, a, b, ctx, ready, true)
		end
		pass(1, "loop", now)
		pass(2, "loop", now + 10)
		local third = pass(3, "loop", now + 20)
		expect(hasFlag(third.flags, "repeat")).toBeTrue()
		expect(third.ok).toEqual(true)

		local history = context()
		for index = 1, 4 do
			table.insert(history.log, {
				id = "old-" .. index,
				kind = "trade",
				timestamp = now,
				server = "test-server",
				left = {
					userId = 7,
					name = "Whale",
					level = 40,
					accountAgeDays = 90,
					tier = "Trusted",
				},
				right = {
					userId = 100 + index,
					name = "New",
					level = 2,
					accountAgeDays = 1,
					tier = "New",
				},
				lines = {},
				estimatedValue = { [7] = 10, [101] = 10 },
				flags = {},
				warning = nil,
				reversed = false,
				reports = {},
				listingId = nil,
			})
		end
		local item = weapon("funnel", "Epic", 0)
		local left = profile(0, { funnel = item })
		local right = profile(0, {})
		local whale = actor(7, 40, 90)
		local mule = actor(5, 2, 1)
		local session = Trading.open("funnel", 7, 5, now)
		assert(session ~= nil)
		Trading.setOffer(session, 7, { items = { "funnel" } }, now)
		local ready = now + Trading.LOCK_SECONDS
		Trading.confirm(session, 7, ready)
		Trading.confirm(session, 5, ready)
		Trading.finish(session, 7, left, right, whale, mule, history, ready, true)
		local flagged = Trading.finish(session, 5, left, right, whale, mule, history, ready, true)
		expect(hasFlag(flagged.flags, "funnel")).toBeTrue()
		expect(hasFlag(flagged.flags, "new_receiver")).toBeTrue()
		expect(Schema.findItem(right, "funnel") ~= nil).toBeTrue()
	end)

	spec("reverses a trade once and keeps the audit searchable for 180 days", function()
		local now = 200_000
		local item = weapon("a", "Rare", 0, { name = "Blade", templateId = "blade" })
		local left = profile(1000, { a = item })
		local right = profile(0, {})
		local ctx = context()
		local a = actor(1, 20, 30)
		local b = actor(2, 20, 30)
		local session = Trading.open("undo", 1, 2, now)
		assert(session ~= nil)
		Trading.setOffer(session, 1, { items = { "a" }, gold = 100 }, now)
		local ready = now + Trading.LOCK_SECONDS
		Trading.confirm(session, 1, ready)
		Trading.confirm(session, 2, ready)
		Trading.finish(session, 1, left, right, a, b, ctx, ready, true)
		local done = Trading.finish(session, 2, left, right, a, b, ctx, ready, true)
		local entry = Trading.findEntry(ctx.log, done.auditId :: string)
		assert(entry ~= nil)
		expect(Trading.report(ctx.log, entry.id, 2)).toEqual(true)
		expect(Trading.report(ctx.log, entry.id, 2)).toEqual(true)
		expect(hasFlag(entry.flags, "report")).toBeTrue()
		expect(Trading.report(ctx.log, entry.id, 9)).toEqual(false)
		local reversed = Trading.rollback(entry, left, right)
		expect(reversed).toEqual(true)
		expect(Schema.findItem(left, "a") ~= nil).toBeTrue()
		expect(Schema.findItem(right, "a")).toBeNil()
		expect(left.gold).toEqual(1000)
		expect(right.gold).toEqual(0)
		expect(Trading.rollback(entry, left, right)).toEqual(false)
		expect(entry.reversed).toEqual(true)
		entry.timestamp = now - Trading.LOG_RETENTION_SECONDS - 5
		Trading.prune(ctx.log, now)
		expect(#ctx.log).toEqual(0)
	end)

	spec("moves materials, chests, and a full-bag swap without duplicating", function()
		local now = 300_000
		local left = profile(0, {}, { wood = 10 }, { Rare = 2 })
		local right = profile(0, {}, { wood = 1 }, { Rare = 0 })
		local ctx = context()
		local a = actor(1, 20, 30)
		local b = actor(2, 20, 30)
		local session = Trading.open("stacks", 1, 2, now)
		assert(session ~= nil)
		Trading.setOffer(session, 1, { materials = { wood = 4 }, chests = { Rare = 1 } }, now)
		local ready = now + Trading.LOCK_SECONDS
		Trading.confirm(session, 1, ready)
		Trading.confirm(session, 2, ready)
		Trading.finish(session, 1, left, right, a, b, ctx, ready, true)
		local done = Trading.finish(session, 2, left, right, a, b, ctx, ready, true)
		expect(done.ok).toEqual(true)
		expect(left.materials.wood).toEqual(6)
		expect(right.materials.wood).toEqual(5)
		expect(left.chests.Rare).toEqual(1)
		expect(right.chests.Rare).toEqual(1)

		local packed = {}
		for index = 1, Schema.INVENTORY_CAP do
			local uid = "pad" .. index
			packed[uid] = weapon(uid, "Common", 0, { name = "Pad", templateId = "pad" })
		end
		local sender = profile(0, { gift = weapon("gift", "Common", 0) })
		local receiver = profile(0, packed)
		local full = Trading.open("full", 1, 2, now)
		assert(full ~= nil)
		Trading.setOffer(full, 1, { items = { "gift" } }, now)
		Trading.confirm(full, 1, ready)
		Trading.confirm(full, 2, ready)
		Trading.finish(full, 1, sender, receiver, a, b, ctx, ready, true)
		local blocked = Trading.finish(full, 2, sender, receiver, a, b, ctx, ready, true)
		expect(blocked.error).toEqual("Inventory is full.")
		expect(Schema.findItem(sender, "gift") ~= nil).toBeTrue()
		expect(Schema.findItem(receiver, "gift")).toBeNil()
	end)

	spec("remembers today's value on the profile fields Ghost adds", function()
		local now = 400_000
		local day = math.floor(now / 86400)
		local left = profile(100, { a = weapon("a", "Common", 0) })
		left.tradeDay = day
		left.tradeValueToday = 40
		local right = profile(0)
		right.tradeDay = 0
		right.tradeValueToday = 0
		local ctx = context()
		local session = Trading.open("cap-save", 1, 2, now)
		assert(session ~= nil)
		Trading.setOffer(session, 1, { items = { "a" } }, now)
		local ready = now + Trading.LOCK_SECONDS
		Trading.confirm(session, 1, ready)
		Trading.confirm(session, 2, ready)
		local a = actor(1, 20, 30)
		local b = actor(2, 20, 30)
		Trading.finish(session, 1, left, right, a, b, ctx, ready, true)
		local done = Trading.finish(session, 2, left, right, a, b, ctx, ready, true)
		expect(done.ok).toEqual(true)
		expect(left.tradeDay).toEqual(day)
		expect(left.tradeValueToday).toEqual(90)
	end)

	spec("a forged or ungranted receipt does not lift the trade cap", function()
		expect(Schema.VERSION).toEqual(24)
		local saved = Schema.migrate({
			schemaVersion = 24,
			gold = 12,
			receipts = { legacy = true },
			verifiedSpender = true,
		})
		assert(saved ~= nil)
		expect(saved.schemaVersion).toEqual(24)
		expect(saved.gold).toEqual(12)
		expect(saved.receipts.legacy).toEqual(true)
		expect(Trading.verifiedFromReceipts(saved)).toEqual(false)
		expect(Trading.receiptCounts(true)).toEqual(false)
		expect(Trading.receiptCounts({ verified = true })).toEqual(false)
		expect(Trading.receiptCounts({ verified = true, granted = false })).toEqual(false)
		expect(Trading.receiptCounts({ granted = true })).toEqual(false)
		expect(Trading.receiptCounts({ verified = true, granted = true, cosmetic = true })).toEqual(
			false
		)
		expect(Trading.receiptCounts({ verified = true, granted = true })).toEqual(true)
		expect(Trading.receiptCounts({ verified = true, granted = true, cosmetic = false })).toEqual(
			true
		)

		local function fromSave(receipts: any, level: number, age: number): Trading.Actor
			local data = {
				receipts = receipts,
				verifiedSpender = true,
			}
			return actor(1, level, age, { spender = Trading.verifiedFromReceipts(data) })
		end

		expect(Trading.verifiedFromReceipts({ verifiedSpender = true })).toEqual(false)
		expect(Trading.verifiedFromReceipts({
			verifiedSpender = true,
			receipts = { forged = true, note = "paid", count = 1 },
		})).toEqual(false)

		local forged = fromSave({ forged = true }, 10, 20)
		expect(forged.verifiedSpender).toEqual(false)
		expect(Trading.tier(forged)).toEqual("New")
		expect(Trading.dailyCap(forged)).toEqual(2000)

		local ungranted = fromSave({
			id = { verified = true, granted = false },
		}, 30, 40)
		expect(ungranted.verifiedSpender).toEqual(false)
		expect(Trading.tier(ungranted)).toEqual("Standard")
		expect(Trading.dailyCap(ungranted)).toEqual(50000 + (30 - 15) * 5000)

		local cosmetic = fromSave({
			look = { verified = true, granted = true, cosmetic = true },
		}, 10, 20)
		expect(cosmetic.verifiedSpender).toEqual(false)
		expect(Trading.dailyCap(cosmetic)).toEqual(2000)

		local granted = fromSave({
			legacy = true,
			look = { verified = true, granted = true, cosmetic = true },
			pockets = { verified = true, granted = true, cosmetic = false },
		}, 10, 20)
		expect(granted.verifiedSpender).toEqual(true)
		expect(Trading.tier(granted)).toEqual("Trusted")
		expect(Trading.dailyCap(granted)).toEqual(150000)
		expect(Trading.tradeCap(granted)).toEqual(150000)
		expect(Trading.CAPS.Trusted).toEqual(2000000)

		local young = fromSave({
			pockets = { verified = true, granted = true },
		}, 40, 13)
		expect(young.verifiedSpender).toEqual(true)
		expect(Trading.tier(young)).toEqual("New")
		expect(Trading.dailyCap(young)).toEqual(2000)

		local now = 90_000
		local ctx = context()
		local other = actor(2, 40, 80)
		local serial = 0
		local function goldTrade(who: Trading.Actor, gold: number): (Trading.Result, any)
			serial += 1
			local left = profile(gold + 1000)
			local right = profile(0)
			local session = Trading.open("receipt-cap-" .. tostring(serial), who.userId, 2, now)
			assert(session ~= nil)
			expect(Trading.setOffer(session, who.userId, { gold = gold }, now)).toEqual(true)
			local ready = now + Trading.LOCK_SECONDS
			expect(Trading.confirm(session, who.userId, ready)).toEqual(true)
			expect(Trading.confirm(session, 2, ready)).toEqual(true)
			local result =
				Trading.finish(session, who.userId, left, right, who, other, ctx, ready, true)
			return result, left
		end

		local over, overBag = goldTrade(granted, 150001)
		expect(over.ok).toEqual(false)
		expect(over.error).toEqual("That trade is over today's limit.")
		expect(overBag.gold).toEqual(151001)

		local oldCap, oldBag = goldTrade(granted, 2000000)
		expect(oldCap.ok).toEqual(false)
		expect(oldCap.error).toEqual("That trade is over today's limit.")
		expect(oldBag.gold).toEqual(2001000)

		local held, heldBag = goldTrade(granted, 150000)
		expect(held.ok).toEqual(true)
		expect(held.pending).toEqual(true)
		expect(heldBag.gold).toEqual(151000)

		local earned = actor(3, 40, 14)
		local big, bigBag = goldTrade(earned, 150001)
		expect(big.ok).toEqual(true)
		expect(big.pending).toEqual(true)
		expect(bigBag.gold).toEqual(151001)

		local mule, muleBag = goldTrade(forged, 150000)
		expect(mule.ok).toEqual(false)
		expect(mule.error).toEqual("That trade is over today's limit.")
		expect(muleBag.gold).toEqual(151000)

		local tooYoung, youngBag = goldTrade(young, 2001)
		expect(tooYoung.ok).toEqual(false)
		expect(tooYoung.error).toEqual("That trade is over today's limit.")
		expect(youngBag.gold).toEqual(3001)

		local market = fs.readFile("src/ServerScriptService/ShardfallServer/MarketService.luau")
		local trade = fs.readFile("src/ServerScriptService/ShardfallServer/TradeService.luau")
		local receipts = fs.readFile("src/ServerScriptService/ShardfallServer/ReceiptService.luau")
		expect(string.find(market, "Trading.verifiedFromReceipts", 1, true) ~= nil).toBeTrue()
		expect(string.find(trade, "Trading.verifiedFromReceipts", 1, true) ~= nil).toBeTrue()
		expect(string.find(market, "data.verifiedSpender == true", 1, true)).toBeNil()
		expect(string.find(trade, "data.verifiedSpender == true", 1, true)).toBeNil()
		expect(string.find(market, "value == true", 1, true)).toBeNil()
		expect(string.find(trade, "value == true", 1, true)).toBeNil()
		expect(
			string.find(receipts, "duplicate = Economy.receipt(data, receiptId)", 1, true) ~= nil
		).toBeTrue()
		expect(string.find(receipts, "NotProcessedYet", 1, true) ~= nil).toBeTrue()
	end)
end)

describe("MarketBoard", function()
	local function sellerActor(): Trading.Actor
		return actor(4, 20, 40)
	end

	local function buyerActor(): Trading.Actor
		return actor(8, 20, 40)
	end

	spec("sinks a 5 percent listing fee and sells the goods once", function()
		local now = 500_000
		local ctx = context()
		local item = weapon("sale", "Rare", 0, { name = "Sale Blade", templateId = "blade" })
		local seller = profile(100, { sale = item })
		local board = MarketBoard.new()
		local listed = MarketBoard.list(board, seller, sellerActor(), {
			price = 100,
			currency = "gold",
			items = { "sale" },
		}, ctx, now)
		expect(listed.ok).toEqual(true)
		expect(seller.gold).toEqual(95)
		expect(Schema.findItem(seller, "sale") ~= nil).toBeTrue()
		expect(Trading.itemHold("sale") ~= nil).toBeTrue()
		expect(MarketBoard.fee(10, "gold")).toEqual(1)
		expect(MarketBoard.fee(40, "gold")).toEqual(2)
		expect(MarketBoard.fee(1, "gems")).toEqual(5)

		local buyer = profile(100, {})
		local bought = MarketBoard.buy(
			board,
			listed.listing.id,
			buyer,
			buyerActor(),
			seller,
			sellerActor(),
			ctx,
			now + 1
		)
		expect(bought.ok).toEqual(true)
		expect(buyer.gold).toEqual(0)
		expect(seller.gold).toEqual(195)
		expect(Schema.findItem(buyer, "sale") ~= nil).toBeTrue()
		expect(Schema.findItem(seller, "sale")).toBeNil()
		local entry = Trading.findEntry(ctx.log, bought.auditId :: string)
		assert(entry ~= nil)
		expect(entry.kind).toEqual("market")
		expect(entry.left.userId).toEqual(4)
		expect(entry.right.userId).toEqual(8)
		expect(entry.server).toEqual("test-server")
		local second = MarketBoard.buy(
			board,
			listed.listing.id,
			profile(500),
			buyerActor(),
			seller,
			sellerActor(),
			ctx,
			now + 2
		)
		expect(second.error).toEqual("That listing is gone.")
		expect(Schema.findItem(buyer, "sale") ~= nil).toBeTrue()

		local own = MarketBoard.list(board, seller, sellerActor(), {
			price = 20,
			currency = "gold",
			items = {},
			materials = { wood = 1 },
		}, ctx, now)
		seller.materials = { wood = 3 }
		seller.gold = 50
		local relist = MarketBoard.list(board, seller, sellerActor(), {
			price = 20,
			currency = "gold",
			materials = { wood = 1 },
		}, ctx, now)
		expect(relist.ok).toEqual(true)
		local selfish = MarketBoard.buy(
			board,
			relist.listing.id,
			seller,
			sellerActor(),
			seller,
			sellerActor(),
			ctx,
			now
		)
		expect(selfish.error).toEqual("You cannot buy your own listing.")
	end)

	spec("returns a reserved item on cancel and blocks a trade of it", function()
		local now = 600_000
		local ctx = context()
		local item = weapon("held", "Common", 0)
		local seller = profile(30, { held = item })
		local board = MarketBoard.new()
		local listed = MarketBoard.list(board, seller, sellerActor(), {
			price = 15,
			currency = "gold",
			items = { "held" },
		}, ctx, now)
		expect(listed.ok).toEqual(true)
		expect(seller.gold).toEqual(29)
		local partner = profile(0)
		local session = Trading.open("held-trade", 4, 8, now)
		assert(session ~= nil)
		Trading.setOffer(session, 4, { items = { "held" } }, now)
		local ready = now + Trading.LOCK_SECONDS
		Trading.confirm(session, 4, ready)
		Trading.confirm(session, 8, ready)
		local blocked = Trading.finish(
			session,
			4,
			seller,
			partner,
			sellerActor(),
			buyerActor(),
			ctx,
			ready,
			true
		)
		expect(blocked.error).toEqual("That item is listed on the Market Board.")
		expect(Schema.findItem(seller, "held") ~= nil).toBeTrue()
		local cancelled = MarketBoard.cancel(board, sellerActor(), listed.listing.id, now)
		expect(cancelled.ok).toEqual(true)
		expect(seller.gold).toEqual(29)
		expect(Trading.itemHold("held")).toBeNil()
		local again = Trading.open("after-cancel", 4, 8, now)
		assert(again ~= nil)
		Trading.setOffer(again, 4, { items = { "held" } }, now)
		Trading.confirm(again, 4, ready)
		Trading.confirm(again, 8, ready)
		Trading.finish(again, 4, seller, partner, sellerActor(), buyerActor(), ctx, ready, true)
		local moved =
			Trading.finish(again, 8, seller, partner, sellerActor(), buyerActor(), ctx, ready, true)
		expect(moved.ok).toEqual(true)
		expect(Schema.findItem(partner, "held") ~= nil).toBeTrue()
	end)

	spec("keeps the seller's goods when the buy cannot finish", function()
		local now = 700_000
		local ctx = context()
		local item = weapon("stay", "Common", 0, { name = "Stay", templateId = "stay" })
		local seller = profile(20, { stay = item })
		local board = MarketBoard.new()
		local listed = MarketBoard.list(board, seller, sellerActor(), {
			price = 50,
			currency = "gold",
			items = { "stay" },
		}, ctx, now)
		expect(seller.gold).toEqual(18)
		seller.inventory.stay = nil
		local buyer = profile(50)
		local failed = MarketBoard.buy(
			board,
			listed.listing.id,
			buyer,
			buyerActor(),
			seller,
			sellerActor(),
			ctx,
			now
		)
		expect(failed.ok).toEqual(false)
		expect(buyer.gold).toEqual(50)
		expect(seller.gold).toEqual(18)
		local rows = MarketBoard.browse(board, nil, now)
		expect(#rows).toEqual(1)

		local poor = profile(0, { other = weapon("other", "Common", 0) })
		local noFee = MarketBoard.list(board, poor, sellerActor(), {
			price = 100,
			currency = "gold",
			items = { "other" },
		}, ctx, now)
		expect(noFee.error).toEqual("Not enough gold for the listing fee.")
		expect(poor.gold).toEqual(0)
		expect(Schema.findItem(poor, "other") ~= nil).toBeTrue()
		expect(Trading.holdCountFor(4)).toEqual(1)
	end)

	spec("filters the board and expires a listing", function()
		local now = 800_000
		local ctx = context()
		local seller = profile(100, {}, { wood = 5 }, { Rare = 1 })
		local board = MarketBoard.new()
		local wood = MarketBoard.list(board, seller, sellerActor(), {
			price = 30,
			currency = "gold",
			materials = { wood = 2 },
		}, ctx, now)
		local chest = MarketBoard.list(board, seller, sellerActor(), {
			price = 40,
			currency = "gold",
			chests = { Rare = 1 },
		}, ctx, now + 1)
		expect(wood.ok).toEqual(true)
		expect(chest.ok).toEqual(true)
		local found = MarketBoard.browse(board, { search = "verdant" }, now + 2)
		expect(#found).toEqual(1)
		expect(found[1].currency).toEqual("gold")
		local rare = MarketBoard.browse(board, { rarity = "Rare" }, now + 2)
		expect(#rare).toEqual(1)
		local gone = MarketBoard.browse(board, nil, now + MarketBoard.LISTING_SECONDS + 5)
		expect(#gone).toEqual(0)
		expect(seller.materials.wood).toEqual(5)
		expect(Trading.itemHold("nope")).toBeNil()
		expect(Trading.heldCount(4, "material", "wood", nil)).toEqual(0)
	end)

	spec("stops a new account from pricing a listing in gems", function()
		local now = 900_000
		local ctx = context()
		local newbie = actor(4, 8, 2)
		local seller = profile(100, { a = weapon("a", "Common", 0) }, nil, nil, 10)
		local board = MarketBoard.new()
		local listed = MarketBoard.list(board, seller, newbie, {
			price = 2,
			currency = "gems",
			items = { "a" },
		}, ctx, now)
		expect(listed.error).toEqual("Gems unlock once your account is Standard.")
		expect(seller.gems).toEqual(10)
		expect(seller.gold).toEqual(100)
		local room = MarketBoard.LISTING_CAP.New
		for index = 1, room do
			local uid = "n" .. index
			seller.inventory[uid] = weapon(uid, "Common", 0)
			local row = MarketBoard.list(board, seller, newbie, {
				price = 5,
				currency = "gold",
				items = { uid },
			}, ctx, now + index)
			expect(row.ok).toEqual(true)
		end
		seller.inventory.extra = weapon("extra", "Common", 0)
		local overflow = MarketBoard.list(board, seller, newbie, {
			price = 5,
			currency = "gold",
			items = { "extra" },
		}, ctx, now + 20)
		expect(overflow.error).toEqual("Too many listings.")
	end)
end)
