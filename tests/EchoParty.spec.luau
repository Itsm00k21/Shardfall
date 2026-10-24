--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local EchoParty = require("../src/ServerScriptService/ShardfallServer/EchoParty")

describe("Echo party join", function()
	it("shares only a live matching pull", function()
		expect(EchoParty.samePull("story", false, "story")).toEqual(true)
		expect(EchoParty.samePull("normal", false, "normal")).toEqual(true)
		expect(EchoParty.samePull("story", false, "normal")).toEqual(false)
		expect(EchoParty.samePull("story", true, "story")).toEqual(false)
		expect(EchoParty.samePull("", false, "")).toEqual(false)
		expect(EchoParty.samePull(nil, false, "story")).toEqual(false)
		expect(EchoParty.samePull("story", false, nil)).toEqual(false)

		expect(EchoParty.route(true, true, true)).toEqual("backfill")
		expect(EchoParty.route(false, true, true)).toEqual("queue")
		expect(EchoParty.route(true, false, true)).toEqual("queue")
		expect(EchoParty.route(true, true, false)).toEqual("queue")
		expect(EchoParty.route(false, false, false)).toEqual("queue")
	end)
end)
