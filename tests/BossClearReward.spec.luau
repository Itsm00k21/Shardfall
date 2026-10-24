--!strict

--[[
	Wave-5 boss clear. One grant per run id, saved before the client is
	told. A wipe does not pay and does not take a saved grant back.
	Disconnect and rejoin cannot pay the same run twice.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local BossClearReward = require("../src/ReplicatedStorage/Shared/BossClearReward")
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local WaveFlow = require("../src/ReplicatedStorage/Shared/WaveFlow")
local WaveFlowService = require("../src/ServerScriptService/ShardfallServer/WaveFlowService")

local function withFlag(on: boolean, body: () -> ())
	local prior = LaunchGate.SHOW.enemyTypes
	LaunchGate.SHOW.enemyTypes = on
	local ok, err = pcall(body)
	LaunchGate.SHOW.enemyTypes = prior
	if not ok then
		error(err :: any, 0)
	end
end

local function saveInto(disk: { any }): (any) -> boolean
	return function(profile)
		disk[1] = Schema.deepCopy(profile)
		return true
	end
end

describe("Boss clear reward", function()
	it("keeps the flag off, schema 26, and the boss token row", function()
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		expect(Economy.BOSS_CLEAR_TOKENS).toEqual(5)
		expect(Economy.BOSS_CLEAR_TOKENS < Economy.NORMAL_CLEAR_TOKENS).toBeTrue()
		expect(Economy.validate()).toEqual(true)
		local fresh = Schema.template()
		expect(fresh.schemaVersion).toEqual(26)
		expect(fresh.bossClearRuns).toEqual({})

		local missing = Schema.migrate({ schemaVersion = 26, gold = 1 })
		assert(missing ~= nil)
		expect(missing.schemaVersion).toEqual(26)
		expect(missing.bossClearRuns).toEqual({})
		expect(missing.gold).toEqual(1)

		local stuffed = { schemaVersion = 26, gold = 3, bossClearRuns = {} }
		for index = 1, Economy.BOSS_CLEAR_RUNS + 8 do
			stuffed.bossClearRuns[index] = string.format("run-%d", index)
		end
		stuffed.bossClearRuns[Economy.BOSS_CLEAR_RUNS + 9] = "robux"
		stuffed.bossClearRuns[Economy.BOSS_CLEAR_RUNS + 10] = { productId = 1 }
		local migrated = Schema.migrate(stuffed)
		assert(migrated ~= nil)
		expect(migrated.schemaVersion).toEqual(26)
		expect(#migrated.bossClearRuns).toEqual(Economy.BOSS_CLEAR_RUNS)
		expect(migrated.bossClearRuns[#migrated.bossClearRuns]).toEqual(string.format("run-%d", Economy.BOSS_CLEAR_RUNS + 8))
		local copy = Schema.snapshot(migrated)
		expect(copy.bossClearRuns[#copy.bossClearRuns]).toEqual(migrated.bossClearRuns[#migrated.bossClearRuns])
		local kept = migrated.bossClearRuns[1]
		copy.bossClearRuns[1] = "run-1"
		expect(migrated.bossClearRuns[1]).toEqual(kept)
		expect(kept == "run-1").toBeFalse()
	end)

	it("rejects a bad boss amount and any Robux price", function()
		local mismatch = {
			BOSS_CLEAR_TOKENS = 9,
			BOSS_CLEAR_RUNS = Economy.BOSS_CLEAR_RUNS,
			BOSS_CLEAR_TOKEN_CAP = Economy.BOSS_CLEAR_TOKEN_CAP,
			NORMAL_CLEAR_TOKENS = 5,
			WAVES = {
				{ id = "wave_5_boss", wave = 5, boss = true, tokens = 5 },
			},
		}
		local ok, err = Economy.validate(mismatch)
		expect(ok).toEqual(false)
		expect(string.find(err, "BOSS_CLEAR_TOKENS", 1, true) ~= nil).toBeTrue()

		local priced = {
			robux = 25,
			BOSS_CLEAR_TOKENS = 5,
			BOSS_CLEAR_RUNS = 16,
			BOSS_CLEAR_TOKEN_CAP = 1000000,
			NORMAL_CLEAR_TOKENS = 5,
			WAVES = {
				{ id = "wave_5_boss", wave = 5, boss = true, tokens = 5 },
			},
		}
		local pricedOk, pricedErr = Economy.validate(priced)
		expect(pricedOk).toEqual(false)
		expect(string.find(pricedErr, "Robux", 1, true) ~= nil).toBeTrue()

		local open = {
			BOSS_CLEAR_TOKENS = 5,
			BOSS_CLEAR_RUNS = 0,
			BOSS_CLEAR_TOKEN_CAP = 1000000,
			NORMAL_CLEAR_TOKENS = 5,
			WAVES = {
				{ id = "wave_5_boss", wave = 5, boss = true, tokens = 5 },
			},
		}
		expect(Economy.validate(open)).toEqual(false)
	end)

	it("grants once, and a failed save does not stick", function()
		local profile = Schema.template()
		local before = profile.shardTokens
		local denied = BossClearReward.commit(profile, { robux = 1, tokens = 99 }, function()
			return true
		end)
		expect(denied.granted).toEqual(false)
		expect(denied.saved).toEqual(false)
		expect(profile.shardTokens).toEqual(before)
		expect(BossClearReward.seen(profile, "run-1")).toEqual(false)

		local calls = 0
		local failed = BossClearReward.commit(profile, "run-4", function()
			calls += 1
			error("disk full")
		end)
		expect(calls).toEqual(1)
		expect(failed.saved).toEqual(false)
		expect(failed.granted).toEqual(false)
		expect(profile.shardTokens).toEqual(before)
		expect(BossClearReward.seen(profile, "run-4")).toEqual(false)

		local disk = {}
		local paid = BossClearReward.commit(profile, "run-4", saveInto(disk))
		expect(paid.granted).toEqual(true)
		expect(paid.already).toEqual(false)
		expect(paid.tokens).toEqual(Economy.BOSS_CLEAR_TOKENS)
		expect(paid.saved).toEqual(true)
		expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
		expect(disk[1].shardTokens).toEqual(profile.shardTokens)
		expect(disk[1].bossClearRuns[#disk[1].bossClearRuns]).toEqual("run-4")

		local againCalls = 0
		local again = BossClearReward.commit(profile, "run-4", function()
			againCalls += 1
			return true
		end)
		expect(againCalls).toEqual(0)
		expect(again.granted).toEqual(false)
		expect(again.already).toEqual(true)
		expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
	end)

	it("pays once across disconnect, rejoin, and wipe", function()
		local memory = Schema.template()
		local before = memory.shardTokens
		BossClearReward.wipe(memory, "run-7")
		expect(memory.shardTokens).toEqual(before)
		expect(BossClearReward.seen(memory, "run-7")).toEqual(false)

		local disk = {}
		local paid = BossClearReward.commit(memory, "run-7", saveInto(disk))
		expect(paid.granted).toEqual(true)
		expect(paid.tokens).toEqual(Economy.BOSS_CLEAR_TOKENS)
		local savedTokens = memory.shardTokens

		-- Disconnect after the save and before any client notice.
		memory = nil
		local rejoined = Schema.migrate(disk[1])
		assert(rejoined ~= nil)
		expect(rejoined.schemaVersion).toEqual(26)
		expect(rejoined.shardTokens).toEqual(savedTokens)
		expect(BossClearReward.seen(rejoined, "run-7")).toEqual(true)

		local calls = 0
		local replay = BossClearReward.commit(rejoined, "run-7", function()
			calls += 1
			return true
		end)
		expect(calls).toEqual(0)
		expect(replay.granted).toEqual(false)
		expect(replay.already).toEqual(true)
		expect(rejoined.shardTokens).toEqual(savedTokens)

		local wiped = BossClearReward.wipe(rejoined, "run-7")
		expect(wiped.granted).toEqual(false)
		expect(wiped.tokens).toEqual(0)
		expect(rejoined.shardTokens).toEqual(savedTokens)
		expect(BossClearReward.seen(rejoined, "run-7")).toEqual(true)

		local second = BossClearReward.commit(rejoined, "run-8", saveInto(disk))
		expect(second.granted).toEqual(true)
		expect(second.tokens).toEqual(Economy.BOSS_CLEAR_TOKENS)
		expect(rejoined.shardTokens).toEqual(savedTokens + Economy.BOSS_CLEAR_TOKENS)
		BossClearReward.wipe(rejoined, "run-8")
		expect(rejoined.shardTokens).toEqual(savedTokens + Economy.BOSS_CLEAR_TOKENS)
		expect(BossClearReward.commit(rejoined, "run-8", function()
			return true
		end).granted).toEqual(false)
	end)

	it("stops at the token cap and forgets only the oldest run ids", function()
		local full = Schema.template()
		full.shardTokens = Economy.BOSS_CLEAR_TOKEN_CAP
		local capped = BossClearReward.commit(full, "run-1", function()
			return true
		end)
		expect(capped.granted).toEqual(true)
		expect(capped.tokens).toEqual(0)
		expect(full.shardTokens).toEqual(Economy.BOSS_CLEAR_TOKEN_CAP)
		expect(BossClearReward.seen(full, "run-1")).toEqual(true)

		local profile = Schema.template()
		local first = "run-1"
		local last = ""
		for index = 1, Economy.BOSS_CLEAR_RUNS + 4 do
			local id = string.format("run-%d", index)
			last = id
			local result = BossClearReward.commit(profile, id, function()
				return true
			end)
			expect(result.granted).toEqual(true)
		end
		expect(#profile.bossClearRuns).toEqual(Economy.BOSS_CLEAR_RUNS)
		expect(profile.bossClearRuns[#profile.bossClearRuns]).toEqual(last)
		expect(BossClearReward.seen(profile, last)).toEqual(true)
		expect(BossClearReward.seen(profile, first)).toEqual(false)
	end)

	it("saves the wave-5 clear before the counter, and a rejoin does not pay again", function()
		withFlag(true, function()
			local profile = Schema.template()
			local before = profile.shardTokens
			local sent = {}
			local disk = {}
			local atSave = nil
			local sink = {
				player = "hero",
				profile = profile,
				fire = function(_player, payload)
					local fields = 0
					for key in pairs(payload) do
						fields += 1
						expect(key == "wave" or key == "left").toBeTrue()
					end
					expect(fields).toEqual(2)
					table.insert(sent, payload.left)
				end,
				persist = function(data)
					atSave = #sent
					disk[1] = Schema.deepCopy(data)
					return true
				end,
			}
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local guard = 0
			while run.clear ~= true and guard < 80 do
				local boxes = WaveFlow.boxes(run)
				expect(#boxes > 0).toBeTrue()
				expect(WaveFlowService.hurt(run, boxes[1].id, 100000, sink) > 0).toBeTrue()
				guard += 1
			end
			expect(run.clear).toEqual(true)
			expect(run.rewarded).toEqual(true)
			expect(atSave ~= nil).toBeTrue()
			expect(#sent).toEqual((atSave :: number) + 1)
			expect(sent[#sent]).toEqual(0)
			expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
			expect(disk[1].bossClearRuns[#disk[1].bossClearRuns]).toEqual(run.id)
			expect(BossClearReward.seen(profile, run.id)).toEqual(true)

			local fires = #sent
			expect(WaveFlowService.hurt(run, 1, 1, sink)).toEqual(0)
			expect(#sent).toEqual(fires)
			expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)

			local id = run.id
			local rejoined = Schema.migrate(disk[1])
			assert(rejoined ~= nil)
			local calls = 0
			local replay = BossClearReward.commit(rejoined, id, function()
				calls += 1
				return true
			end)
			expect(calls).toEqual(0)
			expect(replay.already).toEqual(true)
			expect(replay.granted).toEqual(false)
			expect(rejoined.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
			BossClearReward.wipe(rejoined, id)
			expect(rejoined.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
		end)
	end)

	it("does not tell the client when the save fails, then pays once on retry", function()
		withFlag(true, function()
			local profile = Schema.template()
			local before = profile.shardTokens
			local sent = {}
			local sink = {
				player = "hero",
				profile = profile,
				fire = function(_player, payload)
					table.insert(sent, payload.left)
				end,
				persist = function(_data)
					return false
				end,
			}
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local guard = 0
			while run ~= nil and run.clear ~= true and guard < 80 do
				local boxes = WaveFlow.boxes(run)
				expect(#boxes > 0).toBeTrue()
				WaveFlowService.hurt(run, boxes[1].id, 100000, sink)
				guard += 1
			end
			expect(run.clear).toEqual(true)
			expect(run.rewarded).toEqual(false)
			expect(profile.shardTokens).toEqual(before)
			expect(#sent == 0 or sent[#sent] ~= 0).toBeTrue()

			local fires = #sent
			local disk = {}
			sink.persist = function(data)
				disk[1] = Schema.deepCopy(data)
				expect(#sent).toEqual(fires)
				return true
			end
			expect(WaveFlowService.hurt(run, 1, 1, sink)).toEqual(0)
			expect(#sent).toEqual(fires + 1)
			expect(sent[#sent]).toEqual(0)
			expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
			expect(run.rewarded).toEqual(true)
			expect(disk[1].shardTokens).toEqual(profile.shardTokens)

			expect(WaveFlowService.hurt(run, 1, 1, sink)).toEqual(0)
			expect(#sent).toEqual(fires + 1)
			expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
		end)
	end)

	it("pays a new server guid when a saved run-1 would have collided", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/WaveFlow.luau")
		expect(string.find(source, "GenerateGUID", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "run-%d", 1, true)).toBeNil()

		local disk = {}
		local profile = Schema.template()
		local before = profile.shardTokens
		local firstServer = BossClearReward.commit(profile, "run-1", saveInto(disk))
		expect(firstServer.granted).toEqual(true)
		expect(firstServer.tokens).toEqual(Economy.BOSS_CLEAR_TOKENS)

		local rejoined = Schema.migrate(disk[1])
		assert(rejoined ~= nil)
		expect(rejoined.schemaVersion).toEqual(26)
		expect(BossClearReward.validId("run-1")).toEqual(true)
		expect(BossClearReward.seen(rejoined, "run-1")).toEqual(true)
		local collidedCalls = 0
		local collided = BossClearReward.commit(rejoined, "run-1", function()
			collidedCalls += 1
			return true
		end)
		expect(collidedCalls).toEqual(0)
		expect(collided.already).toEqual(true)
		expect(collided.granted).toEqual(false)
		expect(rejoined.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)

		local serverA = WaveFlow.start()
		local serverB = WaveFlow.start()
		expect(serverA ~= nil and serverB ~= nil).toBeTrue()
		if serverA == nil or serverB == nil then
			return
		end
		expect(serverA.id == serverB.id).toBeFalse()
		expect(serverA.id == "run-1").toBeFalse()
		expect(BossClearReward.validId(serverA.id)).toEqual(true)
		expect(BossClearReward.validId(serverB.id)).toEqual(true)
		expect(string.match(serverA.id, "^run%-%d+$")).toBeNil()
		expect(string.match(serverB.id, "^run%-%d+$")).toBeNil()
		expect(BossClearReward.validId(string.upper(serverA.id))).toEqual(true)

		local paidA = BossClearReward.commit(rejoined, serverA.id, saveInto(disk))
		expect(paidA.granted).toEqual(true)
		expect(paidA.tokens).toEqual(Economy.BOSS_CLEAR_TOKENS)
		local paidB = BossClearReward.commit(rejoined, serverB.id, saveInto(disk))
		expect(paidB.granted).toEqual(true)
		expect(rejoined.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS * 3)
		expect(#rejoined.bossClearRuns).toEqual(3)
		expect(#rejoined.bossClearRuns <= Economy.BOSS_CLEAR_RUNS).toBeTrue()

		local mixed = Schema.migrate({
			schemaVersion = 26,
			bossClearRuns = { "run-3", serverA.id, "{" .. serverA.id .. "}", "robux" },
		})
		assert(mixed ~= nil)
		expect(mixed.schemaVersion).toEqual(26)
		expect(BossClearReward.seen(mixed, "run-3")).toEqual(true)
		expect(BossClearReward.seen(mixed, serverA.id)).toEqual(true)
		expect(#mixed.bossClearRuns).toEqual(2)
	end)

	it("does not double-grant while the same run is still saving", function()
		local profile = Schema.template()
		local before = profile.shardTokens
		local id = "cccccccc-dddd-4eee-8fff-000000000001"
		expect(BossClearReward.validId(id)).toEqual(true)
		local calls = 0
		local inner = nil
		local outer = BossClearReward.commit(profile, id, function(data)
			calls += 1
			inner = BossClearReward.commit(profile, id, function()
				calls += 1
				return true
			end)
			expect(data.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
			return true
		end)
		expect(inner ~= nil).toBeTrue()
		if inner == nil then
			return
		end
		expect(calls).toEqual(1)
		expect(inner.granted).toEqual(false)
		expect(inner.saved).toEqual(false)
		expect(inner.already).toEqual(false)
		expect(outer.granted).toEqual(true)
		expect(outer.saved).toEqual(true)
		expect(outer.tokens).toEqual(Economy.BOSS_CLEAR_TOKENS)
		expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
		expect(#profile.bossClearRuns).toEqual(1)
	end)

	it("keeps a grant that lands while a save is in flight", function()
		local profile = Schema.template()
		local before = profile.shardTokens
		local first = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
		local second = "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff"
		local disk = {}
		local phase = 0
		local innerCalls = 0
		local inner = nil
		local outer = BossClearReward.commit(profile, first, function(data)
			phase += 1
			if phase == 1 then
				inner = BossClearReward.commit(profile, second, function()
					innerCalls += 1
					return true
				end)
				return false
			end
			disk[1] = Schema.deepCopy(data)
			return true
		end)
		expect(inner ~= nil).toBeTrue()
		if inner == nil then
			return
		end
		expect(innerCalls).toEqual(0)
		expect(phase).toEqual(2)
		expect(inner.saved).toEqual(false)
		expect(inner.granted).toEqual(false)
		expect(inner.already).toEqual(false)
		expect(outer.saved).toEqual(true)
		expect(outer.granted).toEqual(true)
		expect(outer.tokens).toEqual(Economy.BOSS_CLEAR_TOKENS)
		expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS * 2)
		expect(disk[1].shardTokens).toEqual(profile.shardTokens)
		expect(BossClearReward.seen(disk[1], first)).toEqual(true)
		expect(BossClearReward.seen(disk[1], second)).toEqual(true)
		expect(disk[1].schemaVersion).toEqual(26)

		local replayCalls = 0
		local replay = BossClearReward.commit(profile, second, function()
			replayCalls += 1
			return true
		end)
		expect(replayCalls).toEqual(0)
		expect(replay.already).toEqual(true)
		expect(replay.granted).toEqual(false)
		expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS * 2)

		local staleCalls = 0
		local staleDisk = {}
		local early = BossClearReward.commit(Schema.template(), first, function(data)
			staleCalls += 1
			if staleCalls == 1 then
				local stale = Schema.deepCopy(data)
				local nestedCalls = 0
				local nested = BossClearReward.commit(data, second, function()
					nestedCalls += 1
					return true
				end)
				expect(nestedCalls).toEqual(0)
				expect(nested.saved).toEqual(false)
				staleDisk[1] = stale
				return true
			end
			staleDisk[1] = Schema.deepCopy(data)
			return true
		end)
		expect(staleCalls).toEqual(2)
		expect(early.saved).toEqual(true)
		expect(BossClearReward.seen(staleDisk[1], first)).toEqual(true)
		expect(BossClearReward.seen(staleDisk[1], second)).toEqual(true)
		expect(staleDisk[1].shardTokens).toEqual(Schema.STARTER_TOKENS + Economy.BOSS_CLEAR_TOKENS * 2)
	end)

	it("does not tell the client while the boss-clear save is in flight", function()
		withFlag(true, function()
			local profile = Schema.template()
			local before = profile.shardTokens
			local sent = {}
			local disk = {}
			local run = nil
			local nestedSaved = nil
			local firesAtSave = nil
			local sink = {
				player = "hero",
				profile = profile,
				fire = function(_player, payload)
					table.insert(sent, payload.left)
				end,
				persist = function(data)
					if run == nil then
						return false
					end
					firesAtSave = #sent
					nestedSaved = BossClearReward.commit(profile, run.id, function()
						return true
					end).saved
					expect(WaveFlowService.hurt(run, 1, 1, sink)).toEqual(0)
					expect(#sent).toEqual(firesAtSave)
					expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
					disk[1] = Schema.deepCopy(data)
					return true
				end,
			}
			run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local guard = 0
			while run.clear ~= true and guard < 80 do
				local boxes = WaveFlow.boxes(run)
				expect(#boxes > 0).toBeTrue()
				expect(WaveFlowService.hurt(run, boxes[1].id, 100000, sink) > 0).toBeTrue()
				guard += 1
			end
			expect(run.clear).toEqual(true)
			expect(run.rewarded).toEqual(true)
			expect(nestedSaved).toEqual(false)
			expect(firesAtSave ~= nil).toBeTrue()
			expect(#sent).toEqual((firesAtSave :: number) + 1)
			expect(sent[#sent]).toEqual(0)
			expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
			expect(disk[1].bossClearRuns[#disk[1].bossClearRuns]).toEqual(run.id)
			expect(string.match(run.id, "^run%-%d+$")).toBeNil()
			expect(BossClearReward.validId(run.id)).toEqual(true)

			local fires = #sent
			expect(WaveFlowService.hurt(run, 1, 1, sink)).toEqual(0)
			expect(#sent).toEqual(fires)
			expect(profile.shardTokens).toEqual(before + Economy.BOSS_CLEAR_TOKENS)
		end)
	end)

	it("does not pay while the flag is off", function()
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		local profile = Schema.template()
		local before = profile.shardTokens
		local fired = 0
		local saved = 0
		local sink = {
			player = "hero",
			profile = profile,
			fire = function()
				fired += 1
			end,
			persist = function()
				saved += 1
				return true
			end,
		}
		expect(WaveFlowService.start(sink)).toBeNil()
		local run = WaveFlow.start()
		expect(run ~= nil).toBeTrue()
		if run == nil then
			return
		end
		expect(WaveFlowService.hurt(run, run.members[1].id, 100000, sink)).toEqual(0)
		expect(fired).toEqual(0)
		expect(saved).toEqual(0)
		expect(profile.shardTokens).toEqual(before)
		expect(profile.bossClearRuns).toEqual({})
		expect(run.rewarded).toEqual(false)
	end)
end)
