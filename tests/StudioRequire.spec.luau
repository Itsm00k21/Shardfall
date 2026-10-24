--!strict

--[[
	Studio cannot resolve a require string that climbs out of src/server
	into ReplicatedStorage. Those modules read the DataModel instead.
	This scan fails if a string-literal require under src/server still
	climbs with .. or names ReplicatedStorage.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SharedRequire = require("../src/server/SharedRequire")
local WaveArena = require("../src/server/WaveArena")
local Gather = require("../src/server/PartyGather")

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

local function codeOf(line: string): string
	local comment = string.find(line, "%-%-")
	if comment == nil then
		return line
	end
	return string.sub(line, 1, comment - 1)
end

local function literalRequire(line: string): string?
	local code = codeOf(line)
	return string.match(code, "require%s*%(%s*[\"']([^\"']*)[\"']")
end

describe("Studio require paths", function()
	it("keeps flags off and loads shared modules without a relative ReplicatedStorage require", function()
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(LaunchGate.on("parties")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		local config = SharedRequire.module("Config/WaveArenaConfig")
		expect(config.enabled).toEqual(false)
		local party = SharedRequire.module("Config/PartyGather")
		expect(party.pad.y).toEqual(120)
		expect(WaveArena.hubPad(nil)).toBeNil()
		expect(Gather.plan(nil)).toBeNil()

		local root = SharedRequire.module("Config/WaveArenaConfig")
		expect(root.enabled).toEqual(false)
		local viaWave = require("../src/server/WaveArena/SharedRoot")
		local viaParty = require("../src/server/PartyGather/SharedRoot")
		expect(viaWave.module("LaunchGate").on("waveArena")).toEqual(false)
		expect(viaParty.module("LaunchGate").on("parties")).toEqual(false)
		expect(viaWave.module).toEqual(SharedRequire.module)
		expect(viaParty.module).toEqual(SharedRequire.module)

		local function requireTree(dir: string)
			require("../" .. dir)
			for _, name in ipairs(fs.readDir(dir)) do
				if string.sub(name, -5) == ".luau" and name ~= "init.luau" then
					require("../" .. dir .. "/" .. string.sub(name, 1, -6))
				end
			end
		end
		requireTree("src/server/WaveArena")
		requireTree("src/server/PartyGather")

		local copies = {}
		for _, path in ipairs(luaFiles("src/server")) do
			local body = fs.readFile(path)
			if string.find(body, "local function sharedRoot", 1, true) ~= nil then
				table.insert(copies, path)
			end
			if string.find(body, "debug.info", 1, true) ~= nil then
				table.insert(copies, path .. " debug.info")
			end
		end
		if #copies > 0 then
			error(table.concat(copies, "\n"), 0)
		end
		expect(#copies).toEqual(0)
		local helper = fs.readFile("src/server/SharedRoot.luau")
		expect(string.find(helper, "require(\"./SharedRequire\")", 1, true) ~= nil).toBeTrue()
		expect(string.find(helper, "debug.info", 1, true)).toBeNil()

		local hits = {}
		for _, path in ipairs(luaFiles("src/server")) do
			local lineNo = 0
			for line in string.gmatch(fs.readFile(path) .. "\n", "(.-)\n") do
				lineNo += 1
				local body = literalRequire(line)
				if body ~= nil then
					local climbs = string.find(body, "..", 1, true) ~= nil
					local storage = string.find(body, "ReplicatedStorage", 1, true) ~= nil
					if climbs or storage then
						table.insert(hits, string.format("%s:%d %s", path, lineNo, body))
					end
				end
			end
		end
		if #hits > 0 then
			error(table.concat(hits, "\n"), 0)
		end
		expect(#hits).toEqual(0)
	end)
end)
