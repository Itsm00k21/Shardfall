--!strict

--[[
	Enemy element glow. Every element has a valid color in Config.
	LaunchGate.elementGlow defaults off, and a closed flag builds no glow.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local ElementGlow = require("../src/ReplicatedStorage/Shared/ElementGlow")
local Elements = require("../src/ReplicatedStorage/Shared/Config/Elements")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

local function slice(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("Element glow", function()
	it("gives every element a valid color and reads the glow from that row", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/ElementGlow.luau")
		expect(string.find(source, "Elements.LIST", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "Elements.GLOW", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "255, 112, 36", 1, true)).toBeNil()
		local seen: { [string]: boolean } = {}
		expect(#Elements.ORDER > 0).toBeTrue()
		for _, id in ipairs(Elements.ORDER) do
			local color = Elements.LIST[id].color
			expect(type(color) == "table" and #color == 3).toBeTrue()
			for _, channel in ipairs(color) do
				expect(type(channel) == "number" and channel == channel).toBeTrue()
				expect(channel >= 0 and channel <= 255 and channel == math.floor(channel)).toBeTrue()
			end
			local key = string.format("%d,%d,%d", color[1], color[2], color[3])
			expect(seen[key]).toBeNil()
			seen[key] = true
			local on = ElementGlow.visual(id, true)
			expect(on ~= nil).toBeTrue()
			assert(on ~= nil)
			expect(on.elementId).toEqual(id)
			expect(on.color).toEqual({ color[1], color[2], color[3] })
			expect(on.fillTransparency).toEqual(Elements.GLOW.fillTransparency)
			expect(on.outlineTransparency).toEqual(Elements.GLOW.outlineTransparency)
			expect(on.lightBrightness).toEqual(Elements.GLOW.lightBrightness)
			expect(on.lightRange).toEqual(Elements.GLOW.lightRange)
			expect(on.lightRange >= Dungeons.CAMERA_MAX_ZOOM).toBeTrue()
			expect(on.name).toEqual(Elements.GLOW.name)
		end
		expect(ElementGlow.visual("nope", true)).toBeNil()
	end)

	it("builds no glow while the launch flag is off", function()
		expect(LaunchGate.SHOW.elementGlow).toEqual(false)
		expect(LaunchGate.on("elementGlow")).toEqual(false)
		for _, id in ipairs(Elements.ORDER) do
			expect(ElementGlow.visual(id, false)).toBeNil()
			expect(ElementGlow.visual(id, LaunchGate.on("elementGlow"))).toBeNil()
		end
		for index = 1, #Elements.ORDER do
			expect(ElementGlow.forEnemy(index, false)).toBeNil()
			expect(ElementGlow.forEnemy(index, LaunchGate.on("elementGlow"))).toBeNil()
		end
	end)

	it("assigns every element once on wave 4 and only parents a glow behind the flag", function()
		local kinds = Dungeons.waveKinds(4)
		expect(#kinds).toEqual(#Elements.ORDER)
		local assigned = {}
		for index = 1, #kinds do
			assigned[index] = ElementGlow.assign(index)
			local glow = ElementGlow.forEnemy(index, true)
			expect(glow ~= nil).toBeTrue()
			assert(glow ~= nil)
			expect(glow.elementId).toEqual(Elements.ORDER[index])
		end
		expect(assigned).toEqual(Elements.ORDER)

		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local spawnBody = slice(dungeon, "local function spawnEnemy", "local function spawnRoom")
		local gate = string.find(spawnBody, 'ElementGlow.forEnemy(ordinal, LaunchGate.on("elementGlow"))', 1, true)
		local apply = string.find(spawnBody, "applyElementGlow(part, rimHost, glow)", 1, true)
		local attribute = string.find(spawnBody, '"ShardfallElement"', 1, true)
		expect(gate ~= nil and apply ~= nil and attribute ~= nil).toBeTrue()
		expect((gate :: number) < (apply :: number)).toBeTrue()
		expect((apply :: number) < (attribute :: number)).toBeTrue()
		local waveBody = slice(dungeon, "local function spawnWave", "local function storyEcho")
		expect(string.find(waveBody, "spawnEnemy(run, kind, offset, run.wave, index)", 1, true) ~= nil).toBeTrue()
	end)
end)
