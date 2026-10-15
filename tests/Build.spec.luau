--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Build = require("../src/ReplicatedStorage/Shared/Build")

describe("Build stamp", function()
	it("prints 917d688+ from the server and the client before any require", function()
		local stamp = "917d688+"
		expect(Build.STAMP).toEqual(stamp)
		expect(Build.line("server")).toEqual("[Shardfall] build " .. stamp .. " server")
		local server = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local client =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(server, "[Shardfall] build 917d688+ server", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "[Shardfall] build 917d688+ client", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "[Rootvault] build 917d688+", 1, true) ~= nil).toBeTrue()
		expect(string.find(server, "foreign script", 1, true) ~= nil).toBeTrue()
		local serverStart = string.find(server, "print(", 1, true)
		local serverRequire = string.find(server, "require(script", 1, true)
		expect(serverStart ~= nil and serverRequire ~= nil and serverStart < serverRequire).toBeTrue()
	end)
end)
