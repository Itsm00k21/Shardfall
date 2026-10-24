--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Build = require("../src/ReplicatedStorage/Shared/Build")

describe("Build stamp", function()
	it("prints the build stamp from the server and the client before any require", function()
		-- Lune has no BuildStamp ModuleScript, so tests see "unstamped".
		local stamp = Build.STAMP
		expect(Build.valid(stamp) or stamp == Build.UNSTAMPED).toBeTrue()
		expect(Build.line("server")).toEqual("[Shardfall] build " .. stamp .. " server")
		local server = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local client =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(server, '.line("server")', 1, true) ~= nil).toBeTrue()
		expect(string.find(client, '.line("client")', 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, '"[Rootvault] build " .. Build.STAMP', 1, true) ~= nil).toBeTrue()
		-- No hand-typed sha is left behind.
		expect(string.find(server, "b6c099e", 1, true)).toBeNil()
		expect(string.find(client, "b6c099e", 1, true)).toBeNil()
		expect(string.find(dungeon, "b6c099e", 1, true)).toBeNil()
		expect(string.find(server, "foreign script", 1, true) ~= nil).toBeTrue()
		local serverStart = string.find(server, "print(", 1, true)
		local serverRequire = string.find(server, "require(script", 1, true)
		expect(serverStart ~= nil and serverRequire ~= nil and serverStart < serverRequire).toBeTrue()
	end)

	it("reads the generated stamp and rejects junk", function()
		expect(Build.valid("297a447")).toEqual(true)
		expect(Build.valid("297a447+")).toEqual(true)
		expect(Build.valid("unstamped")).toEqual(false)
		expect(Build.valid(nil)).toEqual(false)
		local script = fs.readFile("scripts/stamp.sh")
		expect(string.find(script, "git rev-parse --short=7 HEAD", 1, true) ~= nil).toBeTrue()
		expect(string.find(script, "src/ReplicatedStorage/Shared/BuildStamp.luau", 1, true) ~= nil).toBeTrue()
		local ignore = fs.readFile(".gitignore")
		expect(string.find(ignore, "src/ReplicatedStorage/Shared/BuildStamp.luau", 1, true) ~= nil).toBeTrue()
	end)
end)
