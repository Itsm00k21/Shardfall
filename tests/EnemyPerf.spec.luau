--!strict

--[[
	M10 stuck watchdog, alive cap, and pool. The live crawl reads these
	decisions only while LaunchGate.enemyPerf is on. The biggest wave is
	the one whose count has reached Dungeons.WAVE_MAX_COUNT.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local EnemyPerf = require("../src/ReplicatedStorage/Shared/Config/EnemyPerf")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function copyConfig(): { [string]: any }
	return {
		ALIVE_CAP = EnemyPerf.ALIVE_CAP,
		STUCK_SECONDS = EnemyPerf.STUCK_SECONDS,
		STUCK_PROGRESS = EnemyPerf.STUCK_PROGRESS,
		DISABLED_STATES = table.clone(EnemyPerf.DISABLED_STATES),
	}
end

describe("EnemyPerf", function()
	it("ships the cap, the 30 second clock, and the flag off", function()
		expect(Schema.VERSION).toEqual(26)
		expect(Schema.template().enemyPerf).toBeNil()
		expect(LaunchGate.SHOW.enemyPerf).toEqual(false)
		expect(LaunchGate.on("enemyPerf")).toEqual(false)
		expect(EnemyPerf.ALIVE_CAP).toEqual(22)
		expect(EnemyPerf.STUCK_SECONDS).toEqual(30)
		local ok, err = EnemyPerf.validate(EnemyPerf)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		expect(EnemyPerf.isBiggest(Dungeons.waveCount(4), Dungeons.WAVE_MAX_COUNT)).toBeFalse()
		expect(EnemyPerf.isBiggest(Dungeons.waveCount(13), Dungeons.WAVE_MAX_COUNT)).toBeTrue()
		expect(Dungeons.waveCount(13)).toEqual(Dungeons.WAVE_MAX_COUNT)
	end)

	it("rejects a cap other than 22 and a clock over 30 seconds", function()
		local eight = copyConfig()
		eight.ALIVE_CAP = 8
		expect(EnemyPerf.validate(eight)).toBeFalse()
		local high = copyConfig()
		high.ALIVE_CAP = 23
		local highOk, highErr = EnemyPerf.validate(high)
		expect(highOk).toBeFalse()
		expect(highErr).toEqual("ALIVE_CAP")
		local slow = copyConfig()
		slow.STUCK_SECONDS = 31
		local slowOk, slowErr = EnemyPerf.validate(slow)
		expect(slowOk).toBeFalse()
		expect(slowErr).toEqual("STUCK_SECONDS")
		local running = copyConfig()
		table.insert(running.DISABLED_STATES, "Running")
		expect(EnemyPerf.validate(running)).toBeFalse()
		local noDead = copyConfig()
		local kept = {}
		for _, name in ipairs(noDead.DISABLED_STATES) do
			if name ~= "Dead" then
				table.insert(kept, name)
			end
		end
		noDead.DISABLED_STATES = kept
		expect(EnemyPerf.validate(noDead)).toBeFalse()
	end)

	it("pools rigs and never keeps more than 22 alive", function()
		local pool = EnemyPerf.newPool()
		for _ = 1, EnemyPerf.ALIVE_CAP do
			expect(EnemyPerf.claim(pool, "vine_crawler")).toEqual("fresh")
		end
		expect(pool.alive).toEqual(22)
		expect(EnemyPerf.claim(pool, "root_brute")).toEqual("queued")
		expect(#pool.queued).toEqual(1)
		local retired = EnemyPerf.retire(pool, "vine_crawler")
		expect(retired.keep).toBeTrue()
		expect(retired.nextKind).toEqual("root_brute")
		expect(retired.nextAction).toEqual("fresh")
		expect(pool.alive).toEqual(22)
		expect(#pool.queued).toEqual(0)
		local again = EnemyPerf.retire(pool, "vine_crawler")
		expect(again.nextKind).toBeNil()
		expect(EnemyPerf.claim(pool, "vine_crawler")).toEqual("reuse")
		expect(#pool.idle).toEqual(1)
	end)

	it("reuses a parked rig when the queued kind matches", function()
		local pool = EnemyPerf.newPool()
		for _ = 1, EnemyPerf.ALIVE_CAP do
			expect(EnemyPerf.claim(pool, "spore_bat")).toEqual("fresh")
		end
		expect(EnemyPerf.claim(pool, "spore_bat")).toEqual("queued")
		local retired = EnemyPerf.retire(pool, "spore_bat")
		expect(retired.keep).toBeTrue()
		expect(retired.nextKind).toEqual("spore_bat")
		expect(retired.nextAction).toEqual("reuse")
		expect(pool.alive).toEqual(EnemyPerf.ALIVE_CAP)
		expect(#pool.idle).toEqual(0)
	end)

	it("does not park past the alive cap", function()
		local pool = EnemyPerf.newPool()
		for _ = 1, EnemyPerf.ALIVE_CAP do
			EnemyPerf.claim(pool, "vine_crawler")
		end
		for _ = 1, EnemyPerf.ALIVE_CAP do
			local row = EnemyPerf.retire(pool, "vine_crawler")
			expect(row.keep).toBeTrue()
		end
		local extra = EnemyPerf.retire(pool, "vine_crawler")
		expect(extra.keep).toBeFalse()
		expect(#pool.idle).toEqual(EnemyPerf.ALIVE_CAP)
		expect(pool.alive).toEqual(0)
	end)

	it("respawns every enemy on the biggest wave before the stall passes 30 seconds", function()
		local count = Dungeons.WAVE_MAX_COUNT
		expect(EnemyPerf.isBiggest(count, Dungeons.WAVE_MAX_COUNT)).toBeTrue()
		local pool = EnemyPerf.newPool()
		local members = {}
		for _ = 1, count do
			expect(EnemyPerf.claim(pool, "vine_crawler")).toEqual("fresh")
			table.insert(members, {
				x = -40,
				z = -12,
				clock = EnemyPerf.begin(-40, -12, 0),
				respawns = 0,
				firstAt = nil,
			})
		end
		expect(pool.alive).toEqual(count)
		expect(pool.alive <= EnemyPerf.ALIVE_CAP).toBeTrue()
		local half = Dungeons.FLOOR_SIZE / 2
		for step = 1, 160 do
			local now = step * 0.25
			for _, member in ipairs(members) do
				local clock, stuck = EnemyPerf.observe(member.clock, member.x, member.z, now, true)
				member.clock = clock
				if stuck then
					expect(now <= EnemyPerf.STUCK_SECONDS).toBeTrue()
					expect(now >= EnemyPerf.STUCK_SECONDS).toBeTrue()
					local padX, padZ = EnemyPerf.respawnPad(member.x, member.z, Dungeons.ENEMY_SPAWNS)
					expect(math.abs(padX) <= half).toBeTrue()
					expect(math.abs(padZ) <= half).toBeTrue()
					expect(padX ~= member.x or padZ ~= member.z).toBeTrue()
					member.x = padX
					member.z = padZ
					member.clock = EnemyPerf.begin(padX, padZ, now)
					member.respawns += 1
					if member.firstAt == nil then
						member.firstAt = now
					end
				end
			end
		end
		for _, member in ipairs(members) do
			expect(member.respawns).toEqual(1)
			expect(member.firstAt).toEqual(30)
			expect(member.x ~= -40 or member.z ~= -12).toBeTrue()
		end
		expect(pool.alive).toEqual(count)
	end)

	it("clears the stall when the enemy makes progress or stops to fight", function()
		local clock = EnemyPerf.begin(0, 0, 0)
		local moved, stuckEarly = EnemyPerf.observe(clock, 2, 0, 10, true)
		expect(stuckEarly).toBeFalse()
		-- Progress at t=10 starts a new 30s window, so t=30 is not a stall.
		local mid, stillClear = EnemyPerf.observe(moved, 2, 0, 30, true)
		expect(stillClear).toBeFalse()
		expect(mid.since).toEqual(10)
		local _, dueLater = EnemyPerf.observe(mid, 2, 0, 40, true)
		expect(dueLater).toBeTrue()
		local stalled = EnemyPerf.begin(-40, -12, 0)
		local still, notYet = EnemyPerf.observe(stalled, -40, -12, 29.75, true)
		expect(notYet).toBeFalse()
		expect(still.since).toEqual(0)
		local _, due = EnemyPerf.observe(still, -40, -12, 30, true)
		expect(due).toBeTrue()
		local fighting, fought = EnemyPerf.observe(stalled, -40, -12, 45, false)
		expect(fought).toBeFalse()
		expect(fighting.since).toEqual(45)
	end)

	it("gates the live rig path and trims Humanoid states with SetStateEnabled", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/EnemyPerfHost.luau")
		expect(string.find(dungeon, 'LaunchGate.on("enemyPerf")', 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "unstickEnemy", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "SetStateEnabled", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "DISABLED_STATES", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "PerfHumanoid", 1, true) ~= nil).toBeTrue()
		local schema = fs.readFile("src/ReplicatedStorage/Shared/Schema.luau")
		expect(string.find(schema, "enemyPerf", 1, true)).toBeNil()
	end)
end)
