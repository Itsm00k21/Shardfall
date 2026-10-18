--!strict

--[[
	RollFocus is pure. MenuHub does not run under Lune.
	The source lock checks the live Roll tab, not the hidden RollReel.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RollFocus = require("../src/ReplicatedStorage/Shared/RollFocus")
local RollLoop = require("../src/ReplicatedStorage/Shared/RollLoop")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"
local REEL = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RollReel.luau"

local function chain(patch: { [string]: any }): RollLoop.ChainInput
	local input: RollLoop.ChainInput = {
		open = true,
		onRoll = true,
		alive = true,
		queued = false,
		holding = false,
		auto = true,
		tokens = 3,
		bagFull = false,
		rarity = "Common",
		stopAt = "Rare",
		isNew = false,
		isUpgrade = false,
	}
	for key, value in pairs(patch) do
		(input :: any)[key] = value
	end
	return input
end

describe("RollFocus", function()
	it("clears auto when the window is unfocused and does not turn it back on", function()
		expect(RollFocus.keep(true, true)).toEqual(true)
		expect(RollFocus.keep(true, false)).toEqual(false)
		expect(RollFocus.keep(false, true)).toEqual(false)
		expect(RollFocus.keep(false, false)).toEqual(false)
		expect(RollFocus.keep(nil, true)).toEqual(false)
		expect(RollFocus.keep(true, nil)).toEqual(false)
		expect(RollFocus.keep("true", true)).toEqual(false)
		expect(RollFocus.keep(true, "true")).toEqual(false)
		expect(RollFocus.keep(true, 1)).toEqual(false)
		-- A later focus event passes the flag that was already cleared.
		expect(RollFocus.keep(true, RollFocus.keep(false, true))).toEqual(false)
	end)

	it("refuses a chain while the window is unfocused", function()
		expect(RollFocus.chain(true)).toEqual(true)
		expect(RollFocus.chain(false)).toEqual(false)
		expect(RollFocus.chain(nil)).toEqual(false)
		expect(RollFocus.chain(1)).toEqual(false)
		expect(RollFocus.chain("true")).toEqual(false)
	end)

	it("ignores a third argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(RollFocus.keep(true, true, paid)).toEqual(true)
		expect(RollFocus.keep(true, false, paid)).toEqual(false)
		expect(RollFocus.keep(false, true, paid)).toEqual(false)
		expect(RollFocus.keep(true, true, true)).toEqual(true)
		expect(RollFocus.chain(true, paid)).toEqual(true)
		expect(RollFocus.chain(false, paid)).toEqual(false)
		expect(RollFocus.chain(true, true)).toEqual(true)
		expect(RollFocus.chain(nil, paid)).toEqual(false)
	end)

	it("does not write its arguments", function()
		local focused = { on = true, paid = true }
		local auto = { on = true, paid = false }
		local extra = { paid = true, productId = 0, robux = 0, cost = 0, skip = false }
		table.freeze(focused)
		table.freeze(auto)
		table.freeze(extra)
		expect(RollFocus.keep(focused, auto, extra)).toEqual(false)
		expect(RollFocus.chain(focused, extra)).toEqual(false)
		expect(RollFocus.keep(true, true, extra)).toEqual(true)
		expect(focused.on).toEqual(true)
		expect(focused.paid).toEqual(true)
		expect(auto.on).toEqual(true)
		expect(auto.paid).toEqual(false)
		expect(extra.paid).toEqual(true)
		expect(extra.productId).toEqual(0)
		expect(extra.robux).toEqual(0)
		expect(extra.cost).toEqual(0)
		expect(extra.skip).toEqual(false)
	end)

	it("does not use a clock, rng, or services", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RollFocus.luau")
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		expect(string.find(source, "tick(", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
	end)

	it("leaves the rarity stop, the queued press, and the alive check alone", function()
		expect(RollLoop.canChain(chain({}))).toEqual(true)
		expect(RollLoop.canChain(chain({ alive = false }))).toEqual(false)
		expect(RollLoop.canChain(chain({ auto = false, queued = true }))).toEqual(true)
		expect(RollLoop.canChain(chain({ rarity = "Rare", stopAt = "Rare" }))).toEqual(false)
		expect(RollLoop.canChain(chain({ auto = false }))).toEqual(false)
	end)

	it("stops the hub auto on focus loss and does not resume it", function()
		local hub = fs.readFile(HUB)
		local reel = fs.readFile(REEL)
		local released = string.find(hub, "WindowFocusReleased", 1, true)
		local gained = string.find(hub, "UserInputService.WindowFocused:Connect", 1, true)
		expect(released ~= nil).toBeTrue()
		expect(gained ~= nil and (gained :: number) > (released :: number)).toBeTrue()
		local cut = string.sub(hub, released :: number, (gained :: number) - 1)
		expect(string.find(cut, "RollFocus.keep(false, hubState.autoOn)", 1, true) ~= nil).toEqual(
			true
		)
		expect(string.find(cut, "hubState.focusCut = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(cut, "hubState.windowFocused = false", 1, true) ~= nil).toBeTrue()
		local resume = string.sub(hub, gained :: number, (gained :: number) + 160)
		expect(string.find(resume, "hubState.windowFocused = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(resume, "autoOn", 1, true)).toBeNil()
		expect(string.find(hub, "RollFocus.chain(hubState.windowFocused)", 1, true) ~= nil).toEqual(
			true
		)
		expect(string.find(hub, "RollFocus.keep(hubState.windowFocused", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "if hubState.focusCut == true then", 1, true) ~= nil).toBeTrue()
		local chainAt = string.find(hub, "function hubFn.chainAllowed", 1, true)
		expect(chainAt ~= nil).toBeTrue()
		local chainBody = string.sub(hub, chainAt :: number, (chainAt :: number) + 520)
		local focusAt = string.find(chainBody, "RollFocus.chain", 1, true)
		local canAt = string.find(chainBody, "RollLoop.canChain", 1, true)
		expect(focusAt ~= nil).toBeTrue()
		expect(canAt ~= nil).toBeTrue()
		expect((focusAt :: number) < (canAt :: number)).toBeTrue()
		expect(string.find(reel, "WindowFocusReleased", 1, true) ~= nil).toBeTrue()
		expect(string.find(reel, "RollFocus", 1, true)).toBeNil()
	end)
end)
