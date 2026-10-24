--!strict

--[[
	One settle record per run id.

	A run used to write one receipts key per drop and keep every key.
	The profile now keeps the newest run ids, capped by settleKeep.
	Robux purchase receipts are not part of that list.
]]

local serde = require("@lune/serde")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ArenaSettle = require("../src/ReplicatedStorage/Shared/ArenaSettle")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Loot = require("../src/server/WaveArena/Loot")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")

local BUDGET = 4 * 1024 * 1024
local RUNS = 1200
local DROPS = 16

local function runId(index: number): string
	-- Same shape as a live id (userId:clock), padded so an uncapped list
	-- cannot hide under the DataStore budget.
	return string.format("%d:%.6f:%064d", index, index * 0.001, index)
end

local function runOf(id: string, drops: number, tokens: number): any
	local grantList = {}
	for index = 1, drops do
		table.insert(grantList, {
			key = "drop:" .. tostring(index),
			kind = "drop",
			dropId = "shard_chip",
			tokens = tokens,
			where = "bag",
		})
	end
	table.insert(grantList, {
		key = "purse:1",
		kind = "purse",
		tokens = tokens,
		where = "purse",
	})
	return {
		receiptId = id,
		grantList = grantList,
	}
end

local function receiptCount(receipts: any): number
	local count = 0
	if typeof(receipts) ~= "table" then
		return 0
	end
	for _ in pairs(receipts) do
		count += 1
	end
	return count
end

describe("Wave arena settle record", function()
	it("keeps the shipped cap at 50 and leaves the arena switches off", function()
		expect(Schema.VERSION).toEqual(26)
		expect(WaveArenaConfig.settleKeep).toEqual(50)
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(ArenaSettle.keep(nil)).toEqual(50)
		expect(ArenaSettle.keep({ settleKeep = 0 })).toEqual(50)
		expect(ArenaSettle.keep({ settleKeep = -3 })).toEqual(50)
		expect(ArenaSettle.keep({ settleKeep = 0 / 0 })).toEqual(50)
		expect(ArenaSettle.keep({ settleKeep = math.huge })).toEqual(50)
		expect(ArenaSettle.keep({ settleKeep = 2.9 })).toEqual(2)
		expect(ArenaSettle.oldRunId("GPA-8c1e2a")).toBeNil()
		expect(ArenaSettle.oldRunId("receipt-known")).toBeNil()
		expect(ArenaSettle.oldRunId("arena:not-a-drop")).toBeNil()
		expect(ArenaSettle.oldRunId("arena:77:10.5:drop:chip-1")).toEqual("77:10.5")
		expect(ArenaSettle.oldRunId("arena:77:10.5:purse:2")).toEqual("77:10.5")
	end)

	it("pays a run once and keeps only the configured number of ids", function()
		local saved = {
			shardTokens = 4,
			gearEssence = 7,
			gold = 8,
			receipts = {
				["GPA-8c1e2a"] = true,
			},
			ledger = {},
		}
		local config = { settleKeep = 2 }
		local first = Loot.commit(saved, runOf("only-1", 2, 1), config)
		expect(first.tokens).toEqual(3)
		expect(saved.shardTokens).toEqual(7)
		local again = Loot.commit(saved, runOf("only-1", 2, 9), config)
		expect(again.tokens).toEqual(0)
		expect(again.bag).toEqual(0)
		expect(saved.shardTokens).toEqual(7)
		expect(saved.gold).toEqual(8)
		expect(saved.receipts["GPA-8c1e2a"]).toEqual(true)
		expect(receiptCount(saved.receipts)).toEqual(1)
		for index = 2, 5 do
			Loot.commit(saved, runOf("only-" .. tostring(index), 1, 1), config)
		end
		expect(#saved.arenaSettle).toEqual(2)
		expect(saved.arenaSettle[1]).toEqual("only-4")
		expect(saved.arenaSettle[2]).toEqual("only-5")
		local held = saved.shardTokens
		Loot.commit(saved, runOf("only-5", 1, 9), config)
		Loot.commit(saved, runOf("only-4", 1, 9), config)
		expect(saved.shardTokens).toEqual(held)
		expect(saved.receipts["GPA-8c1e2a"]).toEqual(true)
		expect(saved.gold).toEqual(8)
	end)

	it("blocks a repeated run id after 1200 runs and stays under the DataStore budget", function()
		local robux = {
			["GPA-8c1e2a"] = true,
			["receipt-known"] = true,
		}
		local saved = {
			shardTokens = 0,
			gearEssence = 0,
			gold = 11,
			receipts = {
				["GPA-8c1e2a"] = true,
				["receipt-known"] = true,
			},
			ledger = {},
		}
		for index = 1, RUNS do
			local grant = Loot.commit(saved, runOf(runId(index), DROPS, 1))
			expect(grant.tokens).toEqual(DROPS + 1)
		end
		expect(#saved.arenaSettle).toEqual(WaveArenaConfig.settleKeep)
		expect(saved.arenaSettle[1]).toEqual(runId(RUNS - WaveArenaConfig.settleKeep + 1))
		expect(saved.arenaSettle[#saved.arenaSettle]).toEqual(runId(RUNS))
		expect(ArenaSettle.has(saved.arenaSettle, runId(1))).toEqual(false)
		local encoded = serde.encode("json", saved.arenaSettle)
		print(string.format("arena settle record %d bytes after %d runs (budget %d)", #encoded, RUNS, BUDGET))
		expect(#encoded < BUDGET).toBeTrue()
		expect(#encoded < 64 * 1024).toBeTrue()
		expect(#encoded * 100 < BUDGET).toBeTrue()
		expect(saved.receipts).toEqual(robux)
		expect(receiptCount(saved.receipts)).toEqual(2)
		expect(#saved.ledger <= 20).toBeTrue()
		expect(saved.gold).toEqual(11)
		local tokens = saved.shardTokens
		local oldestKept = saved.arenaSettle[1]
		local newest = saved.arenaSettle[#saved.arenaSettle]
		local repeatOld = Loot.commit(saved, runOf(oldestKept, DROPS, 5))
		local repeatNew = Loot.commit(saved, runOf(newest, DROPS, 5))
		expect(repeatOld.tokens).toEqual(0)
		expect(repeatNew.tokens).toEqual(0)
		expect(saved.shardTokens).toEqual(tokens)
		expect(#saved.arenaSettle).toEqual(WaveArenaConfig.settleKeep)
		expect(saved.receipts).toEqual(robux)
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect(LaunchGate.on("waveArena")).toEqual(false)
	end)

	it("loads an old save, keeps Robux receipts, and does not pay that run again", function()
		local raw = {
			schemaVersion = 26,
			gold = 42,
			shardTokens = 9,
			gearEssence = 3,
			milestoneTitle = "Keeper",
			receipts = {
				["GPA-8c1e2a"] = true,
				["receipt-known"] = true,
				["arena-pass"] = true,
				["arena:not-a-drop"] = true,
				["arena:77:10.5:drop:chip-1"] = true,
				["arena:77:10.5:drop:chip-2"] = true,
				["arena:77:10.5:purse:2"] = true,
			},
			arenaSettle = { "ok", "", "ok", 4, "second" },
		}
		local loaded = Schema.migrate(raw)
		expect(loaded ~= nil).toBeTrue()
		local data = loaded :: any
		expect(data.schemaVersion).toEqual(26)
		expect(data.gold).toEqual(42)
		expect(data.shardTokens).toEqual(9)
		expect(data.gearEssence).toEqual(3)
		expect(data.milestoneTitle).toEqual("Keeper")
		expect(data.receipts["GPA-8c1e2a"]).toEqual(true)
		expect(data.receipts["receipt-known"]).toEqual(true)
		expect(data.receipts["arena-pass"]).toEqual(true)
		expect(data.receipts["arena:not-a-drop"]).toEqual(true)
		expect(data.receipts["arena:77:10.5:drop:chip-1"]).toBeNil()
		expect(data.receipts["arena:77:10.5:purse:2"]).toBeNil()
		expect(data.arenaSettle[1]).toEqual("77:10.5")
		expect(data.arenaSettle[2]).toEqual("ok")
		expect(data.arenaSettle[3]).toEqual("second")
		expect(#data.arenaSettle).toEqual(3)
		local blocked = Loot.commit(data, runOf("77:10.5", 3, 5))
		expect(blocked.tokens).toEqual(0)
		expect(data.shardTokens).toEqual(9)
		expect(data.gold).toEqual(42)
		expect(data.receipts["GPA-8c1e2a"]).toEqual(true)
		expect(data.schemaVersion).toEqual(26)

		local fresh = {
			shardTokens = 4,
			gold = 8,
			receipts = {
				["GPA-8c1e2a"] = true,
				["arena:77:10.5:drop:chip-1"] = true,
				["arena:77:10.5:purse:2"] = true,
			},
			ledger = {},
		}
		local skipped = Loot.commit(fresh, runOf("77:10.5", 2, 5))
		expect(skipped.tokens).toEqual(0)
		expect(fresh.shardTokens).toEqual(4)
		expect(fresh.gold).toEqual(8)
		expect(fresh.receipts["GPA-8c1e2a"]).toEqual(true)
		expect(fresh.receipts["arena:77:10.5:drop:chip-1"]).toBeNil()
		expect(ArenaSettle.has(fresh.arenaSettle, "77:10.5")).toBeTrue()
		local paid = Loot.commit(fresh, runOf("88:1.000000", 1, 2))
		expect(paid.tokens).toEqual(4)
		expect(fresh.shardTokens).toEqual(8)
		expect(fresh.receipts["GPA-8c1e2a"]).toEqual(true)
		expect(fresh.receipts["arena:88:1.000000:drop:1"]).toBeNil()
		expect(receiptCount(fresh.receipts)).toEqual(1)
	end)

	it("folds a pile of old per-drop keys down to the cap without touching Robux receipts", function()
		local receipts: { [string]: boolean } = {
			["GPA-8c1e2a"] = true,
			["receipt-known"] = true,
		}
		for index = 1, 60 do
			local id = string.format("id-%04d", index)
			receipts["arena:" .. id .. ":drop:1"] = true
			receipts["arena:" .. id .. ":purse:1"] = true
		end
		local loaded = Schema.migrate({
			schemaVersion = 26,
			gold = 6,
			shardTokens = 2,
			receipts = receipts,
		})
		expect(loaded ~= nil).toBeTrue()
		local data = loaded :: any
		expect(data.schemaVersion).toEqual(26)
		expect(data.gold).toEqual(6)
		expect(data.shardTokens).toEqual(2)
		expect(#data.arenaSettle).toEqual(50)
		expect(ArenaSettle.has(data.arenaSettle, "id-0011")).toBeTrue()
		expect(ArenaSettle.has(data.arenaSettle, "id-0060")).toBeTrue()
		expect(ArenaSettle.has(data.arenaSettle, "id-0001")).toEqual(false)
		expect(data.receipts["GPA-8c1e2a"]).toEqual(true)
		expect(data.receipts["receipt-known"]).toEqual(true)
		expect(receiptCount(data.receipts)).toEqual(2)
		local blocked = Loot.commit(data, runOf("id-0060", 4, 7))
		expect(blocked.tokens).toEqual(0)
		expect(data.shardTokens).toEqual(2)
		expect(data.receipts["GPA-8c1e2a"]).toEqual(true)
		expect(data.receipts["receipt-known"]).toEqual(true)
		expect(data.schemaVersion).toEqual(26)
	end)
end)
