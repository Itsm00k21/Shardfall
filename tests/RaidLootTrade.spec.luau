--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidLootTrade = require("../src/ReplicatedStorage/Shared/RaidLootTrade")

local ERRORS = RaidLootTrade.ERRORS
local BIND = RaidLootTrade.CONFIG.bindSeconds
local DROP = 10000

local function gear(patch: { [string]: any }?)
	local item = {
		templateId = "heartwood_blade",
		kind = "Weapon",
		source = "raid",
		droppedAt = DROP,
		runId = "run-a",
		bossId = "twins",
		droppedFor = 1,
		roster = { 1, 2, 3 },
		eligible = { 1, 2 },
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			item[key] = value
		end
	end
	return item
end

local function proposal(patch: { [string]: any }?)
	local row = {
		now = DROP,
		fromUserId = 1,
		toUserId = 2,
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			row[key] = value
		end
	end
	return row
end

local function check(item: any, patch: { [string]: any }?)
	return RaidLootTrade.check(item, proposal(patch))
end

-- A literal `{ key = nil }` drops the key before pairs runs, so a patch
-- cannot clear a field. Copy and leave those keys out.
local function without(source: { [string]: any }, keys: { string })
	local drop = {}
	for _, key in ipairs(keys) do
		drop[key] = true
	end
	local copy = {}
	for key, value in pairs(source) do
		if drop[key] ~= true then
			copy[key] = value
		end
	end
	return copy
end

local function shard(patch: { [string]: any }?)
	local item = {
		templateId = "heartshard_edge",
		kind = "Weapon",
		source = "forge",
		crafted = true,
		heartshard = true,
		crafterClears = 0,
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			item[key] = value
		end
	end
	return item
end

describe("RaidLootTrade config", function()
	it("pins the design thresholds", function()
		expect(BIND).toEqual(2 * 60 * 60)
		expect(BIND).toEqual(7200)
		expect(RaidLootTrade.CONFIG.heartshardClears).toEqual(1)
		expect(RaidLootTrade.HEARTSHARD).toEqual("heartshard")
		expect(RaidLootTrade.HEARTWOOD_PREFIX).toEqual("heartwood_")
	end)

	it("freezes the thresholds, the kinds, the sources, and the errors", function()
		expect(function()
			RaidLootTrade.CONFIG.bindSeconds = 1
		end).toThrow()
		expect(function()
			RaidLootTrade.GEAR_KINDS.weapon = false
		end).toThrow()
		expect(function()
			RaidLootTrade.RAID_SOURCES.raid = false
		end).toThrow()
		expect(function()
			RaidLootTrade.CRAFT_SOURCES.forge = false
		end).toThrow()
		expect(function()
			RaidLootTrade.ERRORS.bound = "open"
		end).toThrow()
		expect(RaidLootTrade.CONFIG.bindSeconds).toEqual(7200)
	end)

	it("has no Robux price and no combat power", function()
		local banned = {
			robux = true,
			productid = true,
			premium = true,
			damage = true,
			health = true,
			attack = true,
		}
		local bags = {
			RaidLootTrade.CONFIG,
			RaidLootTrade.GEAR_KINDS,
			RaidLootTrade.RAID_SOURCES,
			RaidLootTrade.CRAFT_SOURCES,
			RaidLootTrade.ERRORS,
		}
		for _, bag in ipairs(bags) do
			for key in pairs(bag) do
				expect(banned[string.lower(tostring(key))]).toBeNil()
			end
		end
		for _, value in pairs(RaidLootTrade.CONFIG) do
			expect(type(value)).toEqual("number")
		end
	end)
end)

describe("RaidLootTrade categories", function()
	it("sorts relics ahead of every raid bind", function()
		expect(RaidLootTrade.category({
			templateId = "verdant_warden_helm",
			kind = "Armor",
			source = "raid",
			raidCosmetic = true,
			heartshard = true,
			crafted = true,
			bound = true,
		})).toEqual("relic")
		expect(RaidLootTrade.category({ id = "verdant_tidecaller" })).toEqual("relic")
		expect(RaidLootTrade.category({ pieceId = "verdant_forgeborn_chest" })).toEqual("relic")
		expect(RaidLootTrade.category({ setId = "verdant_frostblade" })).toEqual("relic")
		expect(RaidLootTrade.category({ setId = "verdant_voidcaster_boots" })).toEqual("relic")
	end)

	it("does not treat grovewarden or a starter as a relic", function()
		expect(RaidLootTrade.category(gear({ templateId = "grovewarden_helm" }))).toEqual("gear")
		expect(RaidLootTrade.category({
			templateId = "starter_sword",
			kind = "Weapon",
			bound = true,
		})).toEqual("other")
	end)

	it("binds raid cosmetics and leaves other cosmetics alone", function()
		expect(RaidLootTrade.category({
			kind = "Cosmetic",
			source = "raid",
		})).toEqual("cosmetic")
		expect(RaidLootTrade.category({
			kind = "cosmetic",
			source = "Heartwood_Hard",
		})).toEqual("cosmetic")
		expect(RaidLootTrade.category({
			kind = "Pet",
			raidCosmetic = true,
			source = "shardbreaker",
		})).toEqual("cosmetic")
		expect(RaidLootTrade.category({
			kind = "Cosmetic",
			runId = "run-a",
		})).toEqual("cosmetic")
		expect(RaidLootTrade.category({
			kind = "Cosmetic",
			source = "haven",
		})).toEqual("other")
		expect(RaidLootTrade.category({
			kind = "Pet",
			source = "raid",
		})).toEqual("other")
	end)

	it("separates a crafted Heartshard from a resonant drop", function()
		expect(RaidLootTrade.category(shard())).toEqual("heartshard")
		expect(RaidLootTrade.category({
			kind = "Weapon",
			family = "Heartshard",
			origin = "Craft",
		})).toEqual("heartshard")
		expect(RaidLootTrade.category({
			id = "resonant_heartshard",
			weaponFamily = "heartshard",
			source = "forged",
		})).toEqual("other")
		expect(RaidLootTrade.category({
			templateId = "heartshard_edge",
			kind = "Weapon",
			source = "forge",
		})).toEqual("heartshard")
		expect(RaidLootTrade.category(gear({
			heartshard = true,
			crafted = false,
			templateId = "heartshard_drop",
		}))).toEqual("gear")
		expect(RaidLootTrade.category({
			name = "Heartshard Blade",
			kind = "Weapon",
			source = "forge",
			crafted = true,
		})).toEqual("other")
	end)

	it("treats raid weapons, armor, and accessories as gear", function()
		expect(RaidLootTrade.category(gear())).toEqual("gear")
		expect(RaidLootTrade.category(gear({
			kind = "ARMOR",
			source = "Heartwood_Hard",
		}))).toEqual("gear")
		expect(RaidLootTrade.category(gear({
			kind = "Accessory",
			source = "shardbreaker",
		}))).toEqual("gear")
		expect(RaidLootTrade.category(gear({
			source = "heartwood_heroic",
		}))).toEqual("gear")
		expect(RaidLootTrade.category(gear({
			source = "fracture",
		}))).toEqual("gear")
		expect(RaidLootTrade.category({
			kind = "Weapon",
			droppedAt = DROP,
			runId = "run-a",
		})).toEqual("gear")
	end)

	it("leaves vendor gear, materials, and haven weapons alone", function()
		expect(RaidLootTrade.category({
			kind = "Weapon",
			source = "vendor",
		})).toEqual("other")
		expect(RaidLootTrade.category({
			kind = "Weapon",
			source = "marks",
		})).toEqual("other")
		expect(RaidLootTrade.category({
			kind = "Material",
			source = "raid",
		})).toEqual("other")
		expect(RaidLootTrade.category({
			kind = "Weapon",
			source = "heartwoodvendor",
		})).toEqual("other")
		expect(RaidLootTrade.category(nil)).toEqual("invalid")
	end)
end)

describe("RaidLootTrade raid gear window", function()
	it("trades to an eligible player from the same run at the drop", function()
		local item = gear()
		table.freeze(item.roster)
		table.freeze(item.eligible)
		table.freeze(item)
		expect(check(item)).toEqual({
			ok = true,
			applies = true,
			category = "gear",
			bound = false,
			tradeable = true,
			windowOpen = true,
			remainingSeconds = BIND,
		})
		expect(item.bound).toBeNil()
	end)

	it("keeps the exact end inside the window", function()
		local result = check(gear(), { now = DROP + BIND })
		expect(result.ok).toBeTrue()
		expect(result.windowOpen).toBeTrue()
		expect(result.bound).toBeFalse()
		expect(result.remainingSeconds).toEqual(0)
		expect(result.reason).toBeNil()
	end)

	it("binds the piece one second after the window", function()
		expect(check(gear(), { now = DROP + BIND + 1 })).toEqual({
			ok = false,
			applies = true,
			category = "gear",
			bound = true,
			tradeable = false,
			windowOpen = false,
			remainingSeconds = 0,
			reason = ERRORS.bound,
		})
	end)

	it("does not bind a drop that is not live yet", function()
		local result = check(gear(), { now = DROP - 10 })
		expect(result.ok).toBeFalse()
		expect(result.bound).toBeFalse()
		expect(result.tradeable).toBeFalse()
		expect(result.windowOpen).toBeFalse()
		expect(result.remainingSeconds).toEqual(BIND + 10)
		expect(result.reason).toEqual(ERRORS.early)
	end)

	it("treats a zero drop time as already closed in the present", function()
		local result = check(gear({ droppedAt = 0 }), { now = 1700000000 })
		expect(result.ok).toBeFalse()
		expect(result.bound).toBeTrue()
		expect(result.reason).toEqual(ERRORS.bound)
	end)

	it("allows the trade at unix epoch when that is the clock", function()
		local result = check(gear({ droppedAt = 0 }), {
			now = 0,
			fromUserId = 1,
			toUserId = 2,
		})
		expect(result.ok).toBeTrue()
		expect(result.remainingSeconds).toEqual(BIND)
	end)

	it("refuses someone in the run who could not loot that boss", function()
		local atEnd = check(gear(), { now = DROP + BIND, toUserId = 3 })
		expect(atEnd.ok).toBeFalse()
		expect(atEnd.bound).toBeFalse()
		expect(atEnd.tradeable).toBeTrue()
		expect(atEnd.windowOpen).toBeTrue()
		expect(atEnd.reason).toEqual(ERRORS.ineligible)
		local after = check(gear(), { now = DROP + BIND + 1, toUserId = 3 })
		expect(after.reason).toEqual(ERRORS.bound)
		expect(after.windowOpen).toBeFalse()
	end)

	it("refuses a player who was not in the run", function()
		local result = check(gear(), { toUserId = 9 })
		expect(result.ok).toBeFalse()
		expect(result.bound).toBeFalse()
		expect(result.windowOpen).toBeTrue()
		expect(result.reason).toEqual(ERRORS.wrongRun)
	end)

	it("refuses a different run even when the id is eligible", function()
		local result = check(gear(), { toUserId = 2, runId = "run-b" })
		expect(result.ok).toBeFalse()
		expect(result.reason).toEqual(ERRORS.wrongRun)
		expect(result.windowOpen).toBeTrue()
		expect(check(gear(), { runId = "run-a" }).ok).toBeTrue()
	end)

	it("allows an eligible player the roster forgot", function()
		local result = check(gear({ roster = { 1 }, eligible = { 2 } }))
		expect(result.ok).toBeTrue()
		expect(result.reason).toBeNil()
	end)

	it("reads an eligible set as well as a list", function()
		local result = check(gear({ eligible = { [2] = true, [4] = true } }))
		expect(result.ok).toBeTrue()
		expect(check(gear({ eligible = { [4] = true } }), { toUserId = 2 }).reason).toEqual(
			ERRORS.ineligible
		)
	end)

	it("does not coerce a string user id in the roster", function()
		local result = check(gear({ roster = { "2" }, eligible = { "2" } }))
		expect(result.ok).toBeFalse()
		expect(result.reason).toEqual(ERRORS.wrongRun)
	end)

	it("refuses an open listing inside the window", function()
		local result = RaidLootTrade.check(gear(), without(proposal(), { "toUserId" }))
		expect(result.ok).toBeFalse()
		expect(result.bound).toBeFalse()
		expect(result.tradeable).toBeTrue()
		expect(result.windowOpen).toBeTrue()
		expect(result.reason).toEqual(ERRORS.name)
	end)

	it("lets the holder trade without being eligible", function()
		local result = check(gear({
			droppedFor = 1,
			roster = { 2 },
			eligible = { 2 },
		}))
		expect(result.ok).toBeTrue()
	end)

	it("binds a second trade inside the window", function()
		local moved = check(gear({ droppedFor = 1 }), { fromUserId = 2, toUserId = 3 })
		expect(moved.ok).toBeFalse()
		expect(moved.bound).toBeTrue()
		expect(moved.windowOpen).toBeTrue()
		expect(moved.reason).toEqual(ERRORS.traded)
		local flagged = check(gear({ traded = true, droppedFor = 1 }))
		expect(flagged.reason).toEqual(ERRORS.traded)
		expect(check(without(gear(), { "droppedFor" })).ok).toBeTrue()
	end)

	it("refuses a missing drop time and a missing run differently", function()
		local noTime = check(without(gear(), { "droppedAt" }))
		expect(noTime.ok).toBeFalse()
		expect(noTime.bound).toBeTrue()
		expect(noTime.windowOpen).toBeFalse()
		expect(noTime.reason).toEqual(ERRORS.dropTime)
		local badTime = check(gear({ droppedAt = 0 / 0 }))
		expect(badTime.reason).toEqual(ERRORS.dropTime)
		local noRun = check(without(gear(), { "runId" }))
		expect(noRun.ok).toBeFalse()
		expect(noRun.bound).toBeFalse()
		expect(noRun.windowOpen).toBeTrue()
		expect(noRun.reason).toEqual(ERRORS.run)
		local closed = check(without(gear(), { "runId" }), { now = DROP + BIND + 1 })
		expect(closed.reason).toEqual(ERRORS.bound)
	end)

	it("refuses a bad run id and a mismatched boss", function()
		expect(check(gear(), { runId = 5 }).reason).toEqual(ERRORS.runId)
		expect(check(gear(), { runId = "" }).reason).toEqual(ERRORS.runId)
		expect(check(gear(), { bossId = "sapwell" }).reason).toEqual(ERRORS.ineligible)
		local noBoss = without(gear(), { "bossId" })
		expect(check(noBoss, { bossId = "twins" }).reason).toEqual(ERRORS.ineligible)
		expect(check(gear(), { bossId = "twins" }).ok).toBeTrue()
		expect(check(noBoss).ok).toBeTrue()
	end)

	it("ignores bound and tradeable flags on the item", function()
		local item = gear({ bound = false, tradeable = true })
		local after = check(item, { now = DROP + BIND + 1 })
		expect(after.reason).toEqual(ERRORS.bound)
		expect(item.bound).toBeFalse()
		local open = gear({ bound = true, tradeable = false })
		table.freeze(open)
		expect(check(open).ok).toBeTrue()
	end)

	it("does not let crafter clears skip a resonant drop", function()
		local item = gear({
			heartshard = true,
			crafted = false,
			templateId = "heartshard_drop",
			crafterClears = 5,
			clears = 5,
		})
		expect(check(item).ok).toBeTrue()
		expect(check(item).category).toEqual("gear")
		expect(check(item, { toUserId = 9 }).reason).toEqual(ERRORS.wrongRun)
		expect(check(item, { now = DROP + BIND + 1 }).reason).toEqual(ERRORS.bound)
	end)

	it("matches remaining to the check while the stamp is gear", function()
		local item = gear()
		local times = { DROP - 10, DROP, DROP + BIND, DROP + BIND + 1 }
		for _, now in ipairs(times) do
			local left = RaidLootTrade.remaining(item, now)
			local result = check(item, { now = now })
			expect(left).toEqual(result.remainingSeconds)
		end
		local atEnd = RaidLootTrade.window(item, DROP + BIND)
		expect(atEnd.open).toBeTrue()
		expect(atEnd.remainingSeconds).toEqual(0)
		expect(atEnd.closesAt).toEqual(DROP + BIND)
		local after = RaidLootTrade.window(item, DROP + BIND + 1)
		expect(after.open).toBeFalse()
		expect(after.remainingSeconds).toEqual(0)
		expect(after.closesAt).toEqual(DROP + BIND)
	end)
end)

describe("RaidLootTrade crafted Heartshard", function()
	it("binds the weapon at zero clears", function()
		local item = shard()
		table.freeze(item)
		expect(check(item)).toEqual({
			ok = false,
			applies = true,
			category = "heartshard",
			bound = true,
			tradeable = false,
			windowOpen = false,
			remainingSeconds = 0,
			reason = ERRORS.heartshard,
		})
	end)

	it("becomes tradeable at one clear, including an open listing", function()
		local unlocked =
			RaidLootTrade.check(shard({ crafterClears = 1 }), without(proposal(), { "toUserId" }))
		expect(unlocked).toEqual({
			ok = true,
			applies = true,
			category = "heartshard",
			bound = false,
			tradeable = true,
			windowOpen = false,
			remainingSeconds = 0,
		})
		expect(check(shard({ crafterClears = 4 }), { toUserId = 9 }).ok).toBeTrue()
	end)

	it("prefers the call count over the item", function()
		local item = shard({ crafterClears = 3, clears = 3 })
		expect(check(item, { crafterClears = 0 }).reason).toEqual(ERRORS.heartshard)
		local stored = shard({ crafterClears = 0, clears = 4 })
		expect(check(stored).reason).toEqual(ERRORS.heartshard)
		local fromItem = without(shard(), { "crafterClears" })
		fromItem.clears = 1
		expect(check(fromItem).ok).toBeTrue()
		expect(check(without(shard(), { "crafterClears" })).reason).toEqual(ERRORS.heartshard)
	end)

	it("refuses a fractional, negative, or non-finite count", function()
		local bad = { -1, 1.5, 0 / 0, math.huge, -math.huge, "1" }
		for _, clears in ipairs(bad) do
			local result = check(shard(), { crafterClears = clears })
			expect(result.ok).toBeFalse()
			expect(result.category).toEqual("heartshard")
			expect(result.bound).toBeTrue()
			expect(result.reason).toEqual(ERRORS.clears)
		end
	end)

	it("does not open the two-hour window for a crafted weapon", function()
		local item = shard({
			droppedAt = DROP,
			runId = "run-a",
			eligible = { 2 },
			crafterClears = 0,
		})
		expect(check(item).reason).toEqual(ERRORS.heartshard)
		expect(check(item).windowOpen).toBeFalse()
		local later = shard({
			droppedAt = 1,
			runId = "run-a",
			crafterClears = 1,
		})
		local listed = RaidLootTrade.check(
			later,
			without(
				proposal({
					now = DROP + BIND + 50,
				}),
				{ "toUserId" }
			)
		)
		expect(listed.ok).toBeTrue()
		expect(RaidLootTrade.remaining(later, DROP)).toBeNil()
	end)
end)

describe("RaidLootTrade cosmetics and relics", function()
	it("keeps raid cosmetics bound inside the window", function()
		local item = {
			kind = "Cosmetic",
			source = "raid",
			droppedAt = DROP,
			runId = "run-a",
			eligible = { 2 },
			bound = false,
		}
		table.freeze(item)
		expect(check(item)).toEqual({
			ok = false,
			applies = true,
			category = "cosmetic",
			bound = true,
			tradeable = false,
			windowOpen = false,
			remainingSeconds = 0,
			reason = ERRORS.cosmetic,
		})
		expect(RaidLootTrade.remaining(item, DROP)).toBeNil()
		local pet = { kind = "Pet", raidCosmetic = true, source = "shardbreaker" }
		expect(check(pet).reason).toEqual(ERRORS.cosmetic)
	end)

	it("does not bind a haven cosmetic", function()
		local item = { kind = "Cosmetic", source = "haven" }
		expect(check(item)).toEqual({
			ok = true,
			applies = false,
			category = "other",
			bound = false,
			tradeable = true,
			windowOpen = false,
			remainingSeconds = 0,
		})
	end)

	it("lets a relic move with no run, no roster, and no window", function()
		local item = {
			templateId = "verdant_warden_helm",
			kind = "Armor",
			source = "heartwood_hard",
			bound = true,
			tradeable = false,
			droppedAt = 1,
			runId = "run-a",
			eligible = { 1 },
			raidCosmetic = true,
			heartshard = true,
			crafted = true,
			crafterClears = 0,
		}
		table.freeze(item)
		local result = check(item, {
			now = DROP + BIND + 999,
			toUserId = 99,
			runId = "somewhere-else",
		})
		expect(result).toEqual({
			ok = true,
			applies = true,
			category = "relic",
			bound = false,
			tradeable = true,
			windowOpen = false,
			remainingSeconds = 0,
		})
		expect(item.bound).toBeTrue()
		local listed = RaidLootTrade.check(item, without(proposal(), { "toUserId" }))
		expect(listed.ok).toBeTrue()
		expect(RaidLootTrade.remaining(item, DROP)).toBeNil()
		local closed = RaidLootTrade.window(item, DROP)
		expect(closed.ok).toBeTrue()
		expect(closed.applies).toBeFalse()
		expect(closed.open).toBeFalse()
	end)
end)

describe("RaidLootTrade bad input", function()
	it("refuses a missing proposal or a bad clock", function()
		expect(RaidLootTrade.check(gear(), nil).reason).toEqual(ERRORS.time)
		local clocks = { -1, 0 / 0, math.huge, -math.huge }
		for _, now in ipairs(clocks) do
			local result = RaidLootTrade.check(gear(), {
				now = now,
				fromUserId = 1,
				toUserId = 2,
			})
			expect(result.ok).toBeFalse()
			expect(result.applies).toBeTrue()
			expect(result.category).toEqual("invalid")
			expect(result.reason).toEqual(ERRORS.time)
		end
		expect(RaidLootTrade.check(gear(), { fromUserId = 1, toUserId = 2 }).reason).toEqual(
			ERRORS.time
		)
	end)

	it("refuses a bad item, trader, recipient, or self trade", function()
		expect(RaidLootTrade.check(nil, proposal()).reason).toEqual(ERRORS.item)
		expect(RaidLootTrade.check("verdant_warden_helm", proposal()).reason).toEqual(ERRORS.item)
		local traders = { 0, -2, 1.5, "1", false }
		for _, fromUserId in ipairs(traders) do
			expect(check(gear(), { fromUserId = fromUserId }).reason).toEqual(ERRORS.trader)
		end
		local noTrader = RaidLootTrade.check(gear(), without(proposal(), { "fromUserId" }))
		expect(noTrader.reason).toEqual(ERRORS.trader)
		local players = { 0, -5, 2.2, "2", false }
		for _, toUserId in ipairs(players) do
			expect(check(gear(), { toUserId = toUserId }).reason).toEqual(ERRORS.player)
		end
		local self = check(gear(), { toUserId = 1 })
		expect(self.reason).toEqual(ERRORS.self)
		expect(self.category).toEqual("invalid")
		local relic = check({ templateId = "verdant_warden_helm" }, { toUserId = 1 })
		expect(relic.reason).toEqual(ERRORS.self)
	end)

	it("returns no window for a bad clock, a non-item, or a non-gear row", function()
		local badClock = RaidLootTrade.window(gear(), -1)
		expect(badClock.ok).toBeFalse()
		expect(badClock.reason).toEqual(ERRORS.time)
		expect(RaidLootTrade.remaining(gear(), -1)).toBeNil()
		local missing = RaidLootTrade.window(nil, DROP)
		expect(missing.reason).toEqual(ERRORS.item)
		expect(RaidLootTrade.remaining(nil, DROP)).toBeNil()
		local noStampItem = without(gear(), { "droppedAt" })
		local noStamp = RaidLootTrade.window(noStampItem, DROP)
		expect(noStamp.ok).toBeFalse()
		expect(noStamp.applies).toBeTrue()
		expect(noStamp.reason).toEqual(ERRORS.dropTime)
		expect(RaidLootTrade.remaining(noStampItem, DROP)).toBeNil()
		expect(RaidLootTrade.remaining(shard({ crafterClears = 1 }), DROP)).toBeNil()
		expect(RaidLootTrade.remaining({ kind = "Weapon", source = "vendor" }, DROP)).toBeNil()
	end)

	it("does not govern a normal weapon", function()
		local item = { kind = "Weapon", templateId = "haven_blade", source = "haven" }
		expect(RaidLootTrade.check(item, without(proposal(), { "toUserId" }))).toEqual({
			ok = true,
			applies = false,
			category = "other",
			bound = false,
			tradeable = true,
			windowOpen = false,
			remainingSeconds = 0,
		})
	end)
end)
