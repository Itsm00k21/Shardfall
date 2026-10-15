--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RemoteCaller = require("../src/ReplicatedStorage/Shared/RemoteCaller")

describe("RemoteCaller", function()
	it("rejects the string type() returns for a Roblox player", function()
		-- type(player) == "userdata" even when the value IsA("Player").
		-- That combination used to fail every remote and print nothing.
		local accepted, reason = RemoteCaller.accept("userdata", true)
		expect(accepted).toBeFalse()
		expect(string.find(reason, "userdata", 1, true) ~= nil).toBeTrue()
	end)

	it("accepts typeof(player) when the instance is a Player", function()
		local accepted, reason = RemoteCaller.accept("Instance", true)
		expect(accepted).toBeTrue()
		expect(reason).toEqual("")
	end)

	it("rejects an Instance that is not a Player", function()
		local accepted = RemoteCaller.accept("Instance", false)
		expect(accepted).toBeFalse()
	end)
end)
