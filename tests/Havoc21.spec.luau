--!strict
local framework = require("./framework")
local describe, it, expect = framework.describe, framework.it, framework.expect
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Enemies = require("../src/ReplicatedStorage/Shared/Config/Enemies")
local EnemyPool = require("../src/ServerScriptService/ShardfallServer/EnemyPool")
local WaveFlow = require("../src/ReplicatedStorage/Shared/WaveFlow")
local WFS = require("../src/ServerScriptService/ShardfallServer/WaveFlowService")

local function flag(body)
	local p = LaunchGate.SHOW.enemyTypes
	LaunchGate.SHOW.enemyTypes = true
	local ok, e = pcall(body)
	LaunchGate.SHOW.enemyTypes = p
	if not ok then
		error(e, 0)
	end
end

local parts = {}
local function clearRun(run)
	local guard = 0
	while run.clear ~= true and guard < 500 do
		guard += 1
		local boxes = WaveFlow.boxes(run)
		if #boxes == 0 then
			break
		end
		for _, b in ipairs(boxes) do
			WFS.hurt(run, b.id, 1e9)
		end
	end
end

describe("Havoc DP21", function()
	it("flags off, schema 26, no cap symbols", function()
		for _, v in pairs(LaunchGate.SHOW) do
			expect(v == true).toEqual(false)
		end
		expect(Schema.VERSION).toEqual(26)
		expect((Enemies :: any).MAX_ALIVE).toEqual(nil)
		expect((Enemies :: any).PLATFORM_CAP).toEqual(nil)
		expect(WFS.start()).toEqual(nil)
	end)
	it("50 cleared runs leave 0 tracks", function()
		flag(function()
			local base = WFS.entries()
			for _ = 1, 50 do
				local run = WFS.start(nil)
				expect(run ~= nil).toEqual(true)
				clearRun(run)
				expect(run.clear).toEqual(true)
				expect(WFS.pool(run)).toEqual(nil)
			end
			expect(WFS.entries() - base).toEqual(0)
		end)
	end)
	it("wipe / PlayerRemoving / onClose each drop tracks", function()
		flag(function()
			local base = WFS.entries()
			for _ = 1, 50 do
				WFS.wipe(WFS.start(nil))
			end
			expect(WFS.entries() - base).toEqual(0)
			local p1, p2 = {}, {}
			local r1 = WFS.start({ player = p1, fire = function() end } :: any)
			local r2 = WFS.start({ player = p2, fire = function() end } :: any)
			WFS.onPlayerRemoving(p1)
			expect(WFS.pool(r1)).toEqual(nil)
			expect(WFS.pool(r2) ~= nil).toEqual(true)
			for _ = 1, 10 do
				WFS.start(nil)
			end
			WFS.onClose()
			expect(WFS.entries()).toEqual(0)
		end)
	end)
	it("pool.destroy destroys every made part (custom factory)", function()
		local made = {}
		local pool = EnemyPool.create(function(kind)
			local p = { Name = kind, destroyed = false, attributes = {}, children = {} }
			function p:Destroy()
				self.destroyed = true
			end
			table.insert(made, p)
			return p
		end)
		for i = 1, 6 do
			pool.bind(i, "chaser", nil)
		end
		pool.releaseExcept({ [1] = true })
		pool.destroy()
		local left = 0
		for _, p in ipairs(made) do
			if not p.destroyed then
				left += 1
			end
		end
		expect(#made).toEqual(6)
		expect(left).toEqual(0)
		expect(pool.stats().created).toEqual(0)
	end)
	it("reuse clears extra attributes and destroys children", function()
		local pool = EnemyPool.create()
		local b = pool.bind(1, "tank", nil) :: any
		local part = b.part
		part:SetAttribute("Burn", 5)
		part:SetAttribute("Owner", "x")
		local kid = { destroyed = false }
		function kid:Destroy()
			self.destroyed = true
		end
		table.insert(part.children, kid)
		pool.releaseExcept({})
		local b2 = pool.bind(2, "chaser", nil) :: any
		expect(b2.part == part).toEqual(true)
		local attrs = part:GetAttributes()
		expect(attrs.Burn).toEqual(nil)
		expect(attrs.Owner).toEqual(nil)
		expect(#part:GetChildren()).toEqual(0)
		expect(kid.destroyed).toEqual(true)
	end)
	it("stale hurt after stop does not resurrect a track", function()
		flag(function()
			local run = WFS.start(nil) :: any
			local boxes = WaveFlow.boxes(run)
			local base = WFS.entries()
			WFS.wipe(run)
			expect(WFS.entries()).toEqual(base - 1)
			WFS.hurt(run, boxes[1].id, 1)
			parts.resurrected = WFS.entries() - (base - 1)
			expect(parts.resurrected).toEqual(0) -- P3-422-4: fails (1) until the stopped-mark fix lands
			WFS.stop(run)
		end)
	end)
end)
