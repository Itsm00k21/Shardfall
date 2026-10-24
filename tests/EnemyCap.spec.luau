--!strict

--[[
	Gray-box pool. This branch does not cap how many enemies are alive
	and does not queue the rest. EnemyPool still reuses one block and
	clears health, target, and projectile. The flag stays off, so boot
	does not spawn, the HUD is untouched, and the save schema stays 26.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Enemies = require("../src/ReplicatedStorage/Shared/Config/Enemies")
local EnemyPool = require("../src/ServerScriptService/ShardfallServer/EnemyPool")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local WaveFlow = require("../src/ReplicatedStorage/Shared/WaveFlow")
local WaveFlowService = require("../src/ServerScriptService/ShardfallServer/WaveFlowService")

local CAP_WORDS = { "MAX_ALIVE", "PLATFORM_CAP", "aliveCap" }
local WAVE_SIZES = { 6, 8, 10, 12, 5 }

local function withFlag(on: boolean, body: () -> ())
	local prior = LaunchGate.SHOW.enemyTypes
	LaunchGate.SHOW.enemyTypes = on
	local ok, err = pcall(body)
	LaunchGate.SHOW.enemyTypes = prior
	if not ok then
		error(err :: any, 0)
	end
end

local function luaFiles(dir: string): { string }
	local found = {}
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			for _, child in ipairs(luaFiles(path)) do
				table.insert(found, child)
			end
		elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
			table.insert(found, path)
		end
	end
	return found
end

local function roster(patch: { [string]: any }?): any
	local source = {
		ORDER = Enemies.ORDER,
		TYPES = Enemies.TYPES,
		SHARED = Enemies.SHARED,
		STEP_MAX = Enemies.STEP_MAX,
		PREVIEW_GAP = Enemies.PREVIEW_GAP,
		PREVIEW_LIFT = Enemies.PREVIEW_LIFT,
		ARENA = {
			minX = Enemies.ARENA.minX,
			maxX = Enemies.ARENA.maxX,
			minZ = Enemies.ARENA.minZ,
			maxZ = Enemies.ARENA.maxZ,
		},
		SHOT_Y = Enemies.SHOT_Y,
		LOS_PAD = Enemies.LOS_PAD,
		WAVE_COUNTS = Enemies.WAVE_COUNTS,
		WAVE_ORDER = Enemies.WAVE_ORDER,
		WAVE_MIXES = Enemies.WAVE_MIXES,
		WAVE_GAP = Enemies.WAVE_GAP,
		WAVE_LIFT = Enemies.WAVE_LIFT,
		BOSS = Enemies.BOSS,
		BOSS_ADDS = Enemies.BOSS_ADDS,
		BOSS_WAVE = Enemies.BOSS_WAVE,
		BOSS_ADD_MIX = {
			chaser = Enemies.BOSS_ADD_MIX.chaser,
			ranged = Enemies.BOSS_ADD_MIX.ranged,
			tank = Enemies.BOSS_ADD_MIX.tank,
		},
	}
	if patch ~= nil then
		for key, value in pairs(patch) do
			source[key] = value
		end
	end
	return source
end

local function absent(source: string, needle: string)
	expect(string.find(source, needle, 1, true)).toBeNil()
end

describe("Config enemy pool", function()
	it("does not store or enforce an alive cap", function()
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		local enemies = Enemies :: any
		expect(enemies.MAX_ALIVE).toBeNil()
		expect(enemies.PLATFORM_CAP).toBeNil()
		expect(enemies.aliveCap).toBeNil()
		local ok, err = Enemies.validate()
		expect(ok).toEqual(true)
		expect(err).toEqual("")
		expect(Enemies.validate(roster())).toEqual(true)
		expect(Enemies.validate(roster({
			MAX_ALIVE = 1,
			PLATFORM_CAP = { mobile = 1 },
		}))).toEqual(true)

		local boot = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/WaveFlowService.luau")
		local pool = fs.readFile("src/ServerScriptService/ShardfallServer/EnemyPool.luau")
		local flow = fs.readFile("src/ReplicatedStorage/Shared/WaveFlow.luau")
		local config = fs.readFile("src/ReplicatedStorage/Shared/Config/Enemies.luau")
		absent(boot, "EnemyPool")
		absent(boot, "WaveFlowService")
		absent(service, "Instance.new")
		expect(string.find(service, "function WaveFlowService.stop", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "function WaveFlowService.wipe", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "PlayerRemoving", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "BindToClose", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "WaveFlowService.onPlayerRemoving", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "WaveFlowService.onClose", 1, true) ~= nil).toBeTrue()
		for _, source in ipairs({ service, pool, flow, config }) do
			for _, needle in ipairs(CAP_WORDS) do
				absent(source, needle)
			end
			absent(source, "schemaVersion")
			absent(source, "DataService")
			absent(source, "MarketplaceService")
		end
		for _, path in ipairs(luaFiles("src/StarterPlayer")) do
			local body = fs.readFile(path)
			absent(body, "EnemyPool")
			absent(body, "MAX_ALIVE")
		end

		local startAny = WaveFlow.start :: any
		local ignored = startAny(1)
		expect(ignored ~= nil).toBeTrue()
		if ignored ~= nil then
			expect(#WaveFlow.boxes(ignored)).toEqual(6)
			expect(WaveFlow.counter(ignored).left).toEqual(6)
			expect(ignored.cap).toBeNil()
			expect(ignored.queue).toBeNil()
		end
		expect(WaveFlowService.entries()).toEqual(0)
		expect(WaveFlowService.start({ player = "hero" })).toBeNil()
		WaveFlowService.stop(nil)
		WaveFlowService.wipe(nil)
		WaveFlowService.onPlayerRemoving(nil)
		WaveFlowService.onClose()
		expect(WaveFlowService.entries()).toEqual(0)
		expect(WaveFlowService.pool(nil)).toBeNil()
		expect(WaveFlowService.body(nil, 1)).toBeNil()
	end)
end)

describe("EnemyPool", function()
	it("reuses a block and resets health, target, and projectile", function()
		local destroyed = 0
		local pool = EnemyPool.create(function(kind: string)
			return {
				Name = kind,
				health = -1,
				target = "stale",
				projectile = { remaining = 1 },
				Destroy = function()
					destroyed += 1
				end,
			}
		end)
		local first = pool.acquire("chaser")
		local second = pool.acquire("tank")
		expect(first == second).toBeFalse()
		expect(pool.stats().created).toEqual(2)
		expect(pool.stats().inUse).toEqual(2)
		local firstPart = first.part
		local secondPart = second.part
		first.health = 1
		first.target = "hero"
		first.projectile = { remaining = 4 }
		first.part.health = 1
		first.part.target = "hero"
		first.part.projectile = { remaining = 4 }
		second.health = 2
		second.target = "other"
		second.projectile = { remaining = 8 }
		second.part.health = 2
		second.part.target = "other"
		second.part.projectile = { remaining = 8 }
		pool.release(first)
		pool.release(second)
		pool.release(second)
		expect(pool.stats().inUse).toEqual(0)
		expect(pool.stats().free).toEqual(2)
		expect(destroyed).toEqual(0)
		local again = pool.acquire("ranged")
		expect(again == first or again == second).toBeTrue()
		expect(again.part == firstPart or again.part == secondPart).toBeTrue()
		expect(pool.stats().created).toEqual(2)
		expect(again.health).toEqual(Enemies.TYPES.ranged.maxHealth)
		expect(again.target).toBeNil()
		expect(again.projectile).toBeNil()
		expect(again.part.health).toEqual(Enemies.TYPES.ranged.maxHealth)
		expect(again.part.target).toBeNil()
		expect(again.part.projectile).toBeNil()
		expect(again.part.Name).toEqual("ranged")
		expect(destroyed).toEqual(0)
	end)

	it("clears every attribute and child on reset and keeps the part", function()
		local child = {
			destroyed = false,
		}
		function child:Destroy()
			self.destroyed = true
		end
		local part = {
			Name = "stale",
			health = 4,
			target = "hero",
			projectile = { remaining = 2 },
			attributes = {
				Health = 1,
				Target = "hero",
				Stain = "mud",
			},
			children = { child },
			destroyed = false,
		}
		function part:GetAttributes(): { [string]: any }
			local copy = {}
			for key, value in pairs(self.attributes) do
				if value ~= nil then
					copy[key] = value
				end
			end
			return copy
		end
		function part:SetAttribute(name: string, value: any)
			self.attributes[name] = value
		end
		function part:GetChildren(): { any }
			return self.children
		end
		function part:Destroy()
			self.destroyed = true
		end
		local pool = EnemyPool.create(function(_kind: string)
			return part
		end)
		local body = pool.acquire("ranged")
		expect(part.destroyed).toEqual(false)
		expect(child.destroyed).toEqual(true)
		expect(#part.children).toEqual(0)
		expect(part.attributes.Stain).toBeNil()
		expect(part.attributes.Target).toBeNil()
		expect(part.attributes.Health).toEqual(Enemies.TYPES.ranged.maxHealth)
		expect(body.health).toEqual(Enemies.TYPES.ranged.maxHealth)
		expect(body.target).toBeNil()
		expect(body.projectile).toBeNil()
		expect(body.part).toEqual(part)
		pool.release(body)
		expect(part.destroyed).toEqual(false)
		expect(part.health).toEqual(0)
		local extra = { destroyed = false }
		function extra:Destroy()
			self.destroyed = true
		end
		part.attributes.Stain = "mud"
		part.attributes.Mark = 7
		table.insert(part.children, extra)
		local again = pool.acquire("tank")
		expect(again.part).toEqual(part)
		expect(part.destroyed).toEqual(false)
		expect(extra.destroyed).toEqual(true)
		expect(#part.children).toEqual(0)
		expect(part.attributes.Stain).toBeNil()
		expect(part.attributes.Mark).toBeNil()
		expect(part.attributes.Health).toEqual(Enemies.TYPES.tank.maxHealth)
		expect(again.health).toEqual(Enemies.TYPES.tank.maxHealth)
		expect(again.target).toBeNil()
		expect(again.projectile).toBeNil()
		expect(pool.stats().created).toEqual(1)
	end)
end)

describe("WaveFlowService enemy pool", function()
	it("reuses a parked block on the next wave and does not refill a death", function()
		withFlag(true, function()
			local sink: WaveFlowService.Sink = {
				player = "hero",
			}
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			expect(#WaveFlow.boxes(run)).toEqual(6)
			expect(WaveFlow.counter(run)).toEqual({ wave = 1, left = 6 })
			local box = WaveFlow.boxes(run)[1]
			local body = WaveFlowService.body(run, box.id)
			expect(body ~= nil).toBeTrue()
			if body == nil then
				return
			end
			local part = body.part
			body.health = 1
			body.target = "stale"
			body.projectile = { remaining = 9 }
			part.health = 1
			part.target = "stale"
			part.projectile = { remaining = 9 }
			local taken = WaveFlowService.hurt(run, box.id, 100000, sink)
			expect(taken > 0).toBeTrue()
			expect(#WaveFlow.boxes(run)).toEqual(5)
			expect(WaveFlow.counter(run)).toEqual({ wave = 1, left = 5 })
			expect(WaveFlowService.body(run, box.id)).toBeNil()
			expect(body.health).toEqual(0)
			expect(body.target).toBeNil()
			expect(body.projectile).toBeNil()
			expect(part.health).toEqual(0)
			expect(part.target).toBeNil()
			expect(part.projectile).toBeNil()
			local parked = WaveFlowService.pool(run)
			expect(parked ~= nil).toBeTrue()
			if parked ~= nil then
				expect(parked.created).toEqual(6)
				expect(parked.inUse).toEqual(5)
				expect(parked.free).toEqual(1)
			end
			for _ = 1, 5 do
				local nextBox = WaveFlow.boxes(run)[1]
				expect(nextBox ~= nil).toBeTrue()
				expect(WaveFlowService.hurt(run, nextBox.id, 100000, sink) > 0).toBeTrue()
			end
			expect(run.wave).toEqual(2)
			expect(#WaveFlow.boxes(run)).toEqual(8)
			expect(WaveFlow.counter(run)).toEqual({ wave = 2, left = 8 })
			local after = WaveFlowService.pool(run)
			expect(after ~= nil).toBeTrue()
			if after ~= nil then
				expect(after.created).toEqual(8)
				expect(after.inUse).toEqual(8)
				expect(after.free).toEqual(0)
			end
			local reused = false
			for _, nextBox in ipairs(WaveFlow.boxes(run)) do
				local again = WaveFlowService.body(run, nextBox.id)
				if again ~= nil and again.part == part then
					reused = true
					local row = Enemies.row(nextBox.kind)
					expect(row ~= nil).toBeTrue()
					if row ~= nil then
						expect(again.health).toEqual(row.maxHealth)
						expect(again.part.health).toEqual(row.maxHealth)
					end
					expect(again.target).toBeNil()
					expect(again.projectile).toBeNil()
					expect(again.part.target).toBeNil()
					expect(again.part.projectile).toBeNil()
					expect(again.part.Name).toEqual(nextBox.kind)
				end
			end
			expect(reused).toBeTrue()
			WaveFlowService.wipe(run)
			expect(part.destroyed).toEqual(true)
			expect(#part.children).toEqual(0)
			expect(WaveFlowService.pool(run)).toBeNil()
			expect(WaveFlowService.body(run, box.id)).toBeNil()
			expect(WaveFlowService.entries()).toEqual(0)
		end)
	end)

	it("spawns every enemy in wave 4 and the boss wave", function()
		withFlag(true, function()
			local wave5 = {}
			local sink: WaveFlowService.Sink = {
				player = "hero",
				build = function(box)
					if box.wave == 5 then
						table.insert(wave5, box.kind)
					end
				end,
			}
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local kills = { 0, 0, 0, 0, 0 }
			local opened = {}
			local guard = 0
			local sawEleven = false
			while run.clear ~= true do
				guard += 1
				expect(guard <= 41).toBeTrue()
				local wave = run.wave
				expect(wave >= 1 and wave <= 5).toBeTrue()
				local boxes = WaveFlow.boxes(run)
				local size = WAVE_SIZES[wave]
				expect(#boxes > 0 and #boxes <= size).toBeTrue()
				if opened[wave] == nil then
					opened[wave] = #boxes
					expect(#boxes).toEqual(size)
					expect(WaveFlow.counter(run).left).toEqual(size)
				end
				local stats = WaveFlowService.pool(run)
				expect(stats ~= nil).toBeTrue()
				if stats ~= nil then
					expect(stats.inUse).toEqual(#boxes)
					expect(stats.created <= 12).toBeTrue()
					expect(stats.created).toEqual(stats.inUse + stats.free)
				end
				local before = #boxes
				local taken = WaveFlowService.hurt(run, boxes[1].id, 100000, sink)
				expect(taken > 0).toBeTrue()
				kills[wave] += 1
				if wave == 4 and before == 12 and run.wave == 4 then
					expect(#WaveFlow.boxes(run)).toEqual(11)
					expect(WaveFlow.counter(run).left).toEqual(11)
					sawEleven = true
				end
			end
			expect(sawEleven).toBeTrue()
			expect(kills).toEqual({ 6, 8, 10, 12, 5 })
			expect(opened).toEqual({ 6, 8, 10, 12, 5 })
			expect(wave5).toEqual({ "boss", "chaser", "chaser", "ranged", "tank" })
			expect(run.clear).toEqual(true)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 5, left = 0 })
			expect(WaveFlowService.pool(run)).toBeNil()
			expect(WaveFlowService.body(run, 1)).toBeNil()
			expect(WaveFlowService.entries()).toEqual(0)
			expect(Schema.VERSION).toEqual(26)
		end)
	end)
end)

local function remember(run: WaveFlow.Run, seen: { [any]: boolean })
	for _, box in ipairs(WaveFlow.boxes(run)) do
		local body = WaveFlowService.body(run, box.id)
		if body ~= nil and body.part ~= nil then
			seen[body.part] = true
		end
	end
end

local function seenParts(seen: { [any]: boolean }): { any }
	local parts = {}
	for part in pairs(seen) do
		table.insert(parts, part)
	end
	return parts
end

local function expectBurned(parts: { any })
	expect(#parts > 0).toBeTrue()
	for _, part in ipairs(parts) do
		expect(part.destroyed).toEqual(true)
		expect(#part.children).toEqual(0)
		local left = 0
		for _ in pairs(part:GetAttributes()) do
			left += 1
		end
		expect(left).toEqual(0)
	end
end

local function expectRunGone(run: WaveFlow.Run)
	expect(WaveFlowService.pool(run)).toBeNil()
	expect(WaveFlowService.body(run, 1)).toBeNil()
end

describe("WaveFlowService pool release", function()
	it("destroys the pool when the run clears", function()
		withFlag(true, function()
			expect(WaveFlowService.entries()).toEqual(0)
			local sink: WaveFlowService.Sink = { player = "clear-hero" }
			local run = WaveFlowService.start(sink)
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local seen: { [any]: boolean } = {}
			local guard = 0
			while run.clear ~= true do
				guard += 1
				expect(guard <= 41).toBeTrue()
				remember(run, seen)
				local boxes = WaveFlow.boxes(run)
				expect(#boxes > 0).toBeTrue()
				expect(WaveFlowService.hurt(run, boxes[1].id, 100000, sink) > 0).toBeTrue()
			end
			local parts = seenParts(seen)
			expect(#parts).toEqual(12)
			expectBurned(parts)
			expectRunGone(run)
			expect(WaveFlowService.entries()).toEqual(0)
			expect(WaveFlowService.counter(run)).toEqual({ wave = 5, left = 0 })
			expect(Schema.VERSION).toEqual(26)
		end)
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
	end)

	it("destroys the pool when the run is wiped", function()
		withFlag(true, function()
			expect(WaveFlowService.entries()).toEqual(0)
			local run = WaveFlowService.start({ player = "wipe-hero" })
			expect(run ~= nil).toBeTrue()
			if run == nil then
				return
			end
			local seen: { [any]: boolean } = {}
			remember(run, seen)
			local parts = seenParts(seen)
			expect(#parts).toEqual(6)
			expect(WaveFlowService.pool(run) ~= nil).toBeTrue()
			WaveFlowService.wipe(run)
			expectBurned(parts)
			expectRunGone(run)
			expect(WaveFlowService.entries()).toEqual(0)
			WaveFlowService.wipe(run)
			expect(WaveFlowService.entries()).toEqual(0)
		end)
	end)

	it("destroys only the leaving player's pool", function()
		withFlag(true, function()
			expect(WaveFlowService.entries()).toEqual(0)
			local leaving = WaveFlowService.start({ player = "leaving" })
			local staying = WaveFlowService.start({ player = "staying" })
			expect(leaving ~= nil and staying ~= nil).toBeTrue()
			if leaving == nil or staying == nil then
				return
			end
			local leftSeen: { [any]: boolean } = {}
			local staySeen: { [any]: boolean } = {}
			remember(leaving, leftSeen)
			remember(staying, staySeen)
			local leftParts = seenParts(leftSeen)
			local stayParts = seenParts(staySeen)
			expect(#leftParts).toEqual(6)
			expect(#stayParts).toEqual(6)
			expect(WaveFlowService.entries()).toEqual(2)
			WaveFlowService.onPlayerRemoving("leaving")
			expectBurned(leftParts)
			expectRunGone(leaving)
			expect(WaveFlowService.pool(staying) ~= nil).toBeTrue()
			expect(WaveFlowService.entries()).toEqual(1)
			for _, part in ipairs(stayParts) do
				expect(part.destroyed).toEqual(false)
			end
			WaveFlowService.onPlayerRemoving("staying")
			expectBurned(stayParts)
			expectRunGone(staying)
			expect(WaveFlowService.entries()).toEqual(0)
		end)
	end)

	it("destroys every pool on close", function()
		withFlag(true, function()
			expect(WaveFlowService.entries()).toEqual(0)
			local first = WaveFlowService.start({ player = "close-a" })
			local second = WaveFlowService.start({ player = "close-b" })
			expect(first ~= nil and second ~= nil).toBeTrue()
			if first == nil or second == nil then
				return
			end
			local seen: { [any]: boolean } = {}
			remember(first, seen)
			remember(second, seen)
			local parts = seenParts(seen)
			expect(#parts).toEqual(12)
			expect(WaveFlowService.entries()).toEqual(2)
			WaveFlowService.onClose()
			expectBurned(parts)
			expectRunGone(first)
			expectRunGone(second)
			expect(WaveFlowService.entries()).toEqual(0)
			WaveFlowService.onClose()
			expect(WaveFlowService.entries()).toEqual(0)
			expect(Schema.VERSION).toEqual(26)
		end)
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
	end)
end)
