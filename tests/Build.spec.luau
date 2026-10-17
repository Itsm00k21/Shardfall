--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Build = require("../src/ReplicatedStorage/Shared/Build")

describe("Build stamp", function()
	it("prints the build stamp from the server and the client before any require", function()
		local stamp = Build.STAMP
		expect(string.match(stamp, "^%x+$") ~= nil or string.match(stamp, "^%x+%+$") ~= nil).toBeTrue()
		expect(Build.line("server")).toEqual("[Shardfall] build " .. stamp .. " server")
		local server = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local client =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(server, "[Shardfall] build " .. stamp .. " server", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "[Shardfall] build " .. stamp .. " client", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "[Rootvault] build " .. stamp, 1, true) ~= nil).toBeTrue()
		expect(string.find(server, "foreign script", 1, true) ~= nil).toBeTrue()
		local serverStart = string.find(server, "print(", 1, true)
		local serverRequire = string.find(server, "require(script", 1, true)
		expect(serverStart ~= nil and serverRequire ~= nil and serverStart < serverRequire).toBeTrue()
	end)
end)
