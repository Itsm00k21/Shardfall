--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local StarterGoalPay = require("../src/ReplicatedStorage/Shared/StarterGoalPay")
local StarterGoals = require("../src/ReplicatedStorage/Shared/StarterGoals")

local ERRORS = StarterGoals.ERRORS

local function keysOf(data): number
	return data.shardKeys
end

describe("StarterGoalPay", function()
	it("pays 10 Shard Keys once for a goal and nothing on the second grant", function()
		local data = Schema.template()
		expect(keysOf(data)).toEqual(0)
		local first = StarterGoalPay.grant(data, "forge", { craft = true })
		expect(first.ok).toEqual(true)
		expect(first.accepted).toEqual(true)
		expect(first.keys).toEqual(10)
		expect(keysOf(data)).toEqual(10)
		expect(data.starterGoals.granted.forge).toEqual(true)
		expect(data.starterGoals.crafts).toEqual(1)
		expect(data.ledger[#data.ledger].reason).toEqual("starter_goal")
		expect(data.ledger[#data.ledger].currency).toEqual("shardKeys")
		expect(data.ledger[#data.ledger].amount).toEqual(10)

		local second = StarterGoalPay.grant(data, "forge", { craft = true })
		expect(second.ok).toEqual(true)
		expect(second.accepted).toEqual(false)
		expect(second.keys).toEqual(0)
		expect(keysOf(data)).toEqual(10)
		expect(data.starterGoals.granted.forge).toEqual(true)
	end)

	it("pays 50 Shard Keys across the five goals and not again after a rejoin", function()
		local data = Schema.template()
		data.level = 5
		data.shardRolls = 10
		expect(StarterGoalPay.grant(data, "forge", { craft = true }).keys).toEqual(10)
		expect(StarterGoalPay.grant(data, "rootvault", { rootvault = true }).keys).toEqual(10)
		expect(StarterGoalPay.grant(data, "rolls", nil).keys).toEqual(10)
		expect(StarterGoalPay.grant(data, "level", nil).keys).toEqual(10)
		data.level = 10
		expect(StarterGoalPay.grant(data, "guild", { browse = true }).keys).toEqual(10)
		expect(keysOf(data)).toEqual(50)
		expect(data.starterGoals.granted).toEqual({
			forge = true,
			rootvault = true,
			rolls = true,
			level = true,
			guild = true,
		})

		local rejoined = Schema.migrate({
			schemaVersion = 22,
			gold = 7,
			level = data.level,
			shardRolls = data.shardRolls,
			shardKeys = data.shardKeys,
			starterGoals = data.starterGoals,
		})
		assert(rejoined ~= nil)
		expect(rejoined.gold).toEqual(7)
		expect(rejoined.shardKeys).toEqual(50)
		for _, id in ipairs(StarterGoals.ORDER) do
			local again = StarterGoalPay.grant(rejoined, id, {
				craft = true,
				rootvault = true,
				browse = true,
			})
			expect(again.accepted).toEqual(false)
			expect(again.keys).toEqual(0)
		end
		expect(rejoined.shardKeys).toEqual(50)
	end)

	it("starts an alt unpaid and keeps a version 21 save unpaid until a real grant", function()
		local main = Schema.template()
		StarterGoalPay.grant(main, "forge", { craft = true })
		local alt = Schema.template()
		expect(alt.starterGoals.granted.forge).toEqual(false)
		expect(alt.starterGoals.returning).toEqual(false)
		expect(StarterGoalPay.grant(alt, "forge", { craft = true }).keys).toEqual(10)
		expect(alt.shardKeys).toEqual(10)
		expect(main.shardKeys).toEqual(10)

		local old = Schema.migrate({
			schemaVersion = 21,
			gold = 9,
			shardKeys = 3,
			onboardDone = true,
		})
		assert(old ~= nil)
		expect(old.schemaVersion).toEqual(23)
		expect(old.gold).toEqual(9)
		expect(old.shardKeys).toEqual(3)
		expect(old.onboardDone).toEqual(true)
		expect(old.starterGoals.returning).toEqual(false)
		expect(old.starterGoals.granted.forge).toEqual(false)
		expect(old.starterGoals.crafts).toEqual(0)
		expect(old.starterGoals.rootvaultClears).toEqual(0)
		expect(old.starterGoals.browsedGuild).toEqual(false)
		local tracker = Schema.snapshot(old).starterGoalTracker
		expect(tracker.ok).toEqual(true)
		expect(tracker.goals[1].id).toEqual("forge")
		expect(tracker.goals[1].text).toEqual("Craft your first item at the Forge")
		expect(#tracker.goals).toEqual(3)
		expect(StarterGoalPay.grant(old, "forge", { craft = true }).keys).toEqual(10)
		expect(old.shardKeys).toEqual(13)
	end)

	it("does not raise the payout when paid is set and refuses a skip or an id", function()
		local paid = Schema.template()
		local noted = StarterGoalPay.grant(paid, "forge", { craft = true, paid = true })
		expect(noted.keys).toEqual(StarterGoals.CONFIG.shardKeys)
		expect(paid.shardKeys).toEqual(10)

		local skipped = Schema.template()
		skipped.shardKeys = 4
		skipped.starterGoals.granted.forge = true
		local before = skipped.starterGoals
		for _, fact in ipairs({
			{ craft = true, productId = 1 },
			{ craft = true, robux = 0 },
			{ craft = true, cost = 0 },
			{ craft = true, skip = false },
			{ craft = true, userId = 9 },
			{ craft = true, guildId = "grove" },
			{ browse = true, host = 1 },
		}) do
			local refused = StarterGoalPay.grant(skipped, "forge", fact)
			expect(refused.ok).toEqual(false)
			expect(refused.accepted).toEqual(false)
			expect(refused.keys).toEqual(0)
		end
		expect(skipped.shardKeys).toEqual(4)
		expect(skipped.starterGoals).toEqual(before)
		expect(skipped.starterGoals.crafts).toEqual(0)
		expect(StarterGoalPay.grant(skipped, "forge", { craft = true, productId = 1 }).error).toEqual(
			ERRORS.paid
		)
		expect(StarterGoalPay.grant(skipped, "forge", { userId = 1 }).error).toEqual(ERRORS.id)
	end)

	it("ignores a guild browse below level 10 and does not pay a hidden goal", function()
		local data = Schema.template()
		data.level = 9
		data.shardRolls = 10
		local early = StarterGoalPay.grant(data, "guild", { browse = true })
		expect(early.accepted).toEqual(false)
		expect(early.keys).toEqual(0)
		expect(data.starterGoals.browsedGuild).toEqual(false)
		expect(data.shardKeys).toEqual(0)
		data.level = 5
		expect(StarterGoalPay.grant(data, "level", nil).accepted).toEqual(false)
		expect(data.shardKeys).toEqual(0)

		data.level = 10
		expect(StarterGoalPay.grant(data, "forge", { craft = true }).keys).toEqual(10)
		expect(StarterGoalPay.grant(data, "rootvault", { rootvault = true }).keys).toEqual(10)
		expect(StarterGoalPay.grant(data, "rolls", nil).keys).toEqual(10)
		expect(StarterGoalPay.grant(data, "level", nil).keys).toEqual(10)
		local browse = StarterGoalPay.grant(data, "guild", { browse = true })
		expect(browse.accepted).toEqual(true)
		expect(browse.keys).toEqual(10)
		expect(data.starterGoals.browsedGuild).toEqual(true)
		expect(data.shardKeys).toEqual(50)
		expect(StarterGoalPay.grant(data, "guild", { browse = true }).keys).toEqual(0)
		expect(data.shardKeys).toEqual(50)
	end)

	it("keeps show rows on the snapshot and leaves the pure module shape alone", function()
		local data = Schema.template()
		data.level = 5
		data.shardRolls = 10
		StarterGoalPay.grant(data, "forge", { craft = true })
		local tracker = Schema.snapshot(data).starterGoalTracker
		expect(tracker.ok).toEqual(true)
		expect(tracker.state.granted.forge).toEqual(true)
		expect(tracker.goals[1].id).toEqual("rootvault")
		expect(tracker.goals[1].progress).toEqual(0)
		expect(tracker.payout).toBeNil()
		local goals = fs.readFile("src/ReplicatedStorage/Shared/StarterGoals.luau")
		expect(string.find(goals, "function StarterGoals.show(state: any, progress: any)", 1, true) ~= nil).toBeTrue()
		expect(string.find(goals, "function StarterGoals.grant(state: any, goalId: any, progress: any)", 1, true) ~= nil).toBeTrue()
		expect(string.find(goals, "Economy", 1, true)).toBeNil()
	end)
end)

describe("StarterGoalPay wires", function()
	it("counts a craft that is not a reroll, a normal rootvault clear, a roll, and a level 10 guild browse", function()
		local craft = fs.readFile("src/ServerScriptService/ShardfallServer/CraftService.luau")
		local craftBody = string.sub(
			craft,
			string.find(craft, "function CraftService.craft", 1, true) :: number,
			(string.find(craft, "function CraftService.salvage", 1, true) :: number) - 1
		)
		expect(string.find(craftBody, 'StarterGoalPay.grant(data, "forge", { craft = true })', 1, true) ~= nil).toBeTrue()
		expect(string.find(craftBody, "summary.rerolled ~= true", 1, true) ~= nil).toBeTrue()
		local salvage = string.sub(
			craft,
			string.find(craft, "function CraftService.salvage", 1, true) :: number,
			(string.find(craft, "function CraftService.upgrade", 1, true) :: number) - 1
		)
		expect(string.find(salvage, "StarterGoalPay", 1, true)).toBeNil()

		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		local rollAt = string.find(roll, "data.shardRolls = math.min", 1, true)
		local grantAt = string.find(roll, 'StarterGoalPay.grant(data, "rolls", nil)', 1, true)
		expect(rollAt ~= nil and grantAt ~= nil and (rollAt :: number) < (grantAt :: number)).toBeTrue()

		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local blockAt = string.find(dungeon, 'StarterGoalPay.grant(data, "rootvault", { rootvault = true })', 1, true)
		expect(blockAt ~= nil).toBeTrue()
		local block = string.sub(dungeon, (blockAt :: number) - 280, blockAt :: number)
		expect(string.find(block, "Dungeons.ROOTVAULT_ID", 1, true) ~= nil).toBeTrue()
		expect(string.find(block, 'run.dungeon.endless ~= true', 1, true) ~= nil).toBeTrue()
		expect(string.find(block, "run.practice ~= true", 1, true) ~= nil).toBeTrue()
		expect(string.find(block, 'run.difficulty == "normal"', 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, 'StarterGoalPay.grant(data, "level", nil)', 1, true) ~= nil).toBeTrue()

		local haven = fs.readFile("src/ServerScriptService/ShardfallServer/HavenBuilder.luau")
		expect(
			string.find(haven, 'promptOn(closed, "Coming Soon", "Guild Hall", "soon", place.message, "guild")', 1, true)
				~= nil
		).toBeTrue()
		expect(string.find(haven, 'GetAttribute("HavenDistrict") == "guild"', 1, true) ~= nil).toBeTrue()
		expect(string.find(haven, 'StarterGoalPay.grant(data, "guild", { browse = true })', 1, true) ~= nil).toBeTrue()
		expect(string.find(haven, "guildId", 1, true)).toBeNil()
		expect(string.find(haven, "userId", 1, true)).toBeNil()
		local pay = fs.readFile("src/ReplicatedStorage/Shared/StarterGoalPay.luau")
		expect(string.find(pay, "Marketplace", 1, true)).toBeNil()
		expect(string.find(pay, "ProcessReceipt", 1, true)).toBeNil()
		expect(string.find(pay, "account flag", 1, true) ~= nil).toBeTrue()
	end)
end)
