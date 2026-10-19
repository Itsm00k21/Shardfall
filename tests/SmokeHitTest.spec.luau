--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

describe("Studio smoke hit test", function()
	it("scrolls a listed button into view before testing its centre", function()
		local source = fs.readFile("ops/studio-smoke/SmokeClient.client.luau")
		local helper = string.find(source, "local function scrollIntoView", 1, true)
		local blocker = string.find(source, "local function blockerFor", 1, true)
		expect(helper ~= nil and blocker ~= nil).toBeTrue()
		expect((helper :: number) < (blocker :: number)).toBeTrue()
		local body = string.sub(source, blocker :: number, (blocker :: number) + 200)
		expect(string.find(body, "scrollIntoView(btn)", 1, true) ~= nil).toBeTrue()
	end)
end)
