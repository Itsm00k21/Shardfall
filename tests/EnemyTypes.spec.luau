--!strict

--[[
	V1 enemy types (roadmap 3.3 and 3.4). Numbers live in Config/Enemies.
	The server service stays idle while LaunchGate.enemyTypes is off.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Config = require("../src/ReplicatedStorage/Shared/Config/Index")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Enemies = require("../src/ReplicatedStorage/Shared/Config/Enemies")
local EnemyTypeService = require("../src/ServerScriptService/ShardfallServer/EnemyTypeService")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local IDS = { "chaser", "ranged", "tank" }

local function withFlag(on: boolean, body: () -> ())
	local prior = LaunchGate.SHOW.enemyTypes
	LaunchGate.SHOW.enemyTypes = on
	local ok, err = pcall(body)
	LaunchGate.SHOW.enemyTypes = prior
	if not ok then
		error(err :: any, 0)
	end
end

local function copyRow(row: any): any
	local clone = {}
	for key, value in pairs(row) do
		if type(value) == "table" then
			local inner = {}
			for index, part in ipairs(value) do
				inner[index] = part
			end
			clone[key] = inner
		else
			clone[key] = value
		end
	end
	return clone
end

local function rosterWith(id: string, field: string, value: any): any
	local types = {}
	for _, kind in ipairs(Enemies.ORDER) do
		types[kind] = copyRow(Enemies.TYPES[kind])
	end
	types[id][field] = value
	return {
		ORDER = { "chaser", "ranged", "tank" },
		TYPES = types,
		SHARED = Enemies.SHARED,
		STEP_MAX = Enemies.STEP_MAX,
		PREVIEW_GAP = Enemies.PREVIEW_GAP,
		PREVIEW_LIFT = Enemies.PREVIEW_LIFT,
	}
end

local function readOk(path: string): boolean
	local ok = pcall(function()
		fs.readFile(path)
	end)
	return ok
end

describe("Config.Enemies V1 types", function()
	it("keeps the roster flag off", function()
		expect(LaunchGate.SHOW.enemyTypes).toEqual(false)
		expect(LaunchGate.on("enemyTypes")).toEqual(false)
		expect(EnemyTypeService.open()).toEqual(false)
	end)

	it("stores the three types in Shared/Config and on Config.Enemies", function()
		expect(readOk("src/ReplicatedStorage/Shared/Config/Enemies.luau")).toEqual(true)
		expect(readOk("src/shared/Config/Enemies.luau")).toEqual(false)
		expect(Config.Enemies == Dungeons.ENEMIES).toBeTrue()
		for _, id in ipairs(IDS) do
			local live = Config.Enemies[id]
			local row = Enemies.TYPES[id]
			expect(live ~= nil).toBeTrue()
			expect(live.id).toEqual(id)
			expect(live.name).toEqual(row.name)
			expect(live.maxHealth).toEqual(row.maxHealth)
			expect(live.damage).toEqual(row.damage)
			expect(live.defense).toEqual(row.defense)
			expect(live.attackSpeed).toEqual(row.attackSpeed)
			expect(live.moveSpeed).toEqual(row.moveSpeed)
			expect(live.range).toEqual(row.range)
			expect(live.style).toEqual(row.style)
			expect(live.minDot).toEqual(row.minDot)
			expect(live.projectileSpeed).toEqual(row.projectileSpeed)
			expect(live.hover).toEqual(Enemies.SHARED.hover)
			expect(live.boss).toEqual(false)
			expect(live.phase2At).toEqual(Enemies.SHARED.phase2At)
			expect(live.color[1]).toEqual(row.color[1])
			expect(live.color[2]).toEqual(row.color[2])
			expect(live.color[3]).toEqual(row.color[3])
			expect(live.size[1]).toEqual(row.size[1])
			expect(live.size[2]).toEqual(row.size[2])
			expect(live.size[3]).toEqual(row.size[3])
			expect(Config.Rewards.ENEMIES[id] ~= nil).toBeTrue()
		end
		expect(Config.Enemies.chaser.style).toEqual("melee")
		expect(Config.Enemies.tank.style).toEqual("melee")
		expect(Config.Enemies.ranged.style).toEqual("projectile")
	end)

	it("accepts the shipped roster and rejects broken numbers", function()
		local ok, err = Enemies.validate()
		expect(ok).toEqual(true)
		expect(err).toEqual("")

		local negative = Enemies.validate(rosterWith("chaser", "maxHealth", -1))
		expect(negative).toEqual(false)

		local nan = Enemies.validate(rosterWith("ranged", "damage", 0 / 0))
		expect(nan).toEqual(false)

		local shot = Enemies.validate(rosterWith("ranged", "projectileSpeed", 0))
		expect(shot).toEqual(false)

		local fastTank = Enemies.validate(rosterWith("tank", "moveSpeed", Enemies.TYPES.chaser.moveSpeed))
		expect(fastTank).toEqual(false)

		local order = Enemies.validate({
			ORDER = { "tank", "ranged", "chaser" },
			TYPES = Enemies.TYPES,
			SHARED = Enemies.SHARED,
			STEP_MAX = Enemies.STEP_MAX,
			PREVIEW_GAP = Enemies.PREVIEW_GAP,
			PREVIEW_LIFT = Enemies.PREVIEW_LIFT,
		})
		expect(order).toEqual(false)
	end)

	it("leaves rooms and waves on the old roster", function()
		local function absent()
			for _, dungeon in ipairs(Dungeons.all()) do
				for _, room in ipairs(dungeon.rooms) do
					for _, kind in ipairs(room.enemies) do
						expect(table.find(IDS, kind)).toBeNil()
					end
				end
			end
			for wave = 1, 12 do
				for _, kind in ipairs(Dungeons.waveKinds(wave)) do
					expect(table.find(IDS, kind)).toBeNil()
				end
			end
		end
		absent()
		withFlag(true, absent)
	end)

	it("does not bump the save or boot the service", function()
		expect(Schema.VERSION).toEqual(26)
		local server = fs.readFile("src/ServerScriptService/ShardfallServer/EnemyTypeService.luau")
		local roster = fs.readFile("src/ReplicatedStorage/Shared/EnemyRoster.luau")
		local config = fs.readFile("src/ReplicatedStorage/Shared/Config/Enemies.luau")
		for _, source in ipairs({ server, roster, config }) do
			expect(string.find(source, "schemaVersion", 1, true)).toBeNil()
			expect(string.find(source, "DataService", 1, true)).toBeNil()
			expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
		end
		local boot = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		expect(string.find(boot, "EnemyTypeService", 1, true)).toBeNil()
		expect(string.find(boot, "enemyTypes", 1, true)).toBeNil()
	end)
end)

describe("EnemyTypeService", function()
	it("does not move, hurt, or build while the flag is off", function()
		expect(EnemyTypeService.spawn("chaser", 0, 0)).toBeNil()
		local actor = {
			kind = "chaser",
			x = 3,
			z = 4,
			hp = 40,
			cooldown = 0,
		}
		expect(EnemyTypeService.step(actor, 20, 4, 1)).toEqual(0)
		expect(actor.x).toEqual(3)
		expect(actor.z).toEqual(4)
		expect(EnemyTypeService.hurt(actor, 10)).toEqual(0)
		expect(actor.hp).toEqual(40)
		local built = false
		local presented = EnemyTypeService.present(function()
			built = true
			return "box"
		end)
		expect(presented).toBeNil()
		expect(built).toEqual(false)
	end)

	it("chasers close and hit for the config damage", function()
		withFlag(true, function()
			local actor = EnemyTypeService.spawn("chaser", 0, 0)
			expect(actor ~= nil).toBeTrue()
			if actor == nil then
				return
			end
			expect(actor.hp).toEqual(Enemies.TYPES.chaser.maxHealth)
			local dealt = EnemyTypeService.step(actor, 8, 0, 1)
			expect(actor.x).toBeCloseTo(Enemies.TYPES.chaser.stop)
			expect(dealt).toEqual(Enemies.TYPES.chaser.damage)
			local second = EnemyTypeService.step(actor, 8, 0, 1)
			expect(second).toEqual(0)
		end)
	end)

	it("ranged backs out of retreat without shooting, and shoots from the band", function()
		withFlag(true, function()
			local close = EnemyTypeService.spawn("ranged", 0, 0)
			expect(close ~= nil).toBeTrue()
			if close == nil then
				return
			end
			local kite = EnemyTypeService.step(close, 10, 0, 1)
			expect(kite).toEqual(0)
			expect(close.x).toBeLessThan(0)

			local far = EnemyTypeService.spawn("ranged", 0, 0)
			expect(far ~= nil).toBeTrue()
			if far == nil then
				return
			end
			local shot = EnemyTypeService.step(far, 24, 0, 1)
			expect(shot).toEqual(Enemies.TYPES.ranged.damage)
			expect(far.x).toBeGreaterThan(0)
		end)
	end)

	it("tanks move slower and take a smaller cut of the same hit", function()
		withFlag(true, function()
			local chaser = EnemyTypeService.spawn("chaser", 0, 0)
			local tank = EnemyTypeService.spawn("tank", 0, 0)
			expect(chaser ~= nil and tank ~= nil).toBeTrue()
			if chaser == nil or tank == nil then
				return
			end
			EnemyTypeService.step(chaser, 40, 0, 10)
			EnemyTypeService.step(tank, 40, 0, 10)
			expect(chaser.x).toBeCloseTo(Enemies.TYPES.chaser.moveSpeed * Enemies.STEP_MAX)
			expect(tank.x).toBeCloseTo(Enemies.TYPES.tank.moveSpeed * Enemies.STEP_MAX)
			expect(tank.x).toBeLessThan(chaser.x)

			local raw = 20
			local tankHp = tank.hp
			local taken = EnemyTypeService.hurt(tank, raw)
			expect(taken).toBeCloseTo(raw * Enemies.TYPES.tank.damageTaken)
			expect(tank.hp).toBeCloseTo(tankHp - taken)
			local chaserHp = chaser.hp
			local full = EnemyTypeService.hurt(chaser, raw)
			expect(full).toBeCloseTo(raw)
			expect(chaser.hp).toBeCloseTo(chaserHp - raw)
		end)
	end)

	it("describes three gray blocks and does not build them until the flag is on", function()
		withFlag(true, function()
			local boxes = EnemyTypeService.present(nil)
			expect(boxes ~= nil).toBeTrue()
			if boxes == nil then
				return
			end
			expect(boxes.chaser.shape).toEqual("block")
			expect(boxes.ranged.shape).toEqual("block")
			expect(boxes.tank.shape).toEqual("block")
			expect(boxes.chaser.x).toEqual(0)
			expect(boxes.ranged.x).toEqual(Enemies.PREVIEW_GAP)
			expect(boxes.tank.x).toEqual(Enemies.PREVIEW_GAP * 2)
			expect(boxes.tank.y).toEqual(Enemies.PREVIEW_LIFT)
			expect(boxes.chaser.color[1]).toEqual(Enemies.TYPES.chaser.color[1])
			expect(boxes.tank.size[2]).toEqual(Enemies.TYPES.tank.size[2])

			local names = {}
			local built = EnemyTypeService.present(function(box)
				table.insert(names, box.id)
				expect(box.shape).toEqual("block")
				return box.id
			end)
			expect(built ~= nil).toBeTrue()
			expect(names).toEqual(IDS)
		end)
	end)
end)
