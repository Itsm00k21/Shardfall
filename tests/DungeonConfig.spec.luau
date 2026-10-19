--!strict

--[[
	DungeonConfig: Kevin's Oct 19 playtest. Cleared Rootvault rooms now
	count down 3 seconds and move on by themselves, never through a door
	that spends currency.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local DungeonConfig = require("../src/ReplicatedStorage/Shared/DungeonConfig")

local SERVICE = "src/ServerScriptService/ShardfallServer/DungeonService.luau"

describe("Room clear auto-advance", function()
	it("counts down three seconds with a Room clear banner", function()
		expect(DungeonConfig.ROOM_CLEAR_SECONDS).toEqual(3)
		expect(DungeonConfig.roomClearText()).toEqual("Room clear. Next room in 3s.")
	end)

	it("takes the first free door and never the shop", function()
		expect(DungeonConfig.autoDoor({ { id = "spring" }, { id = "elite" } })).toEqual("spring")
		expect(DungeonConfig.autoDoor({ { id = "shop" }, { id = "treasure" } })).toEqual("treasure")
		expect(DungeonConfig.autoDoor({ { id = "shop" } })).toBeNil()
		expect(DungeonConfig.autoDoor(nil)).toBeNil()
	end)

	it("arms the countdown when the doors open and resolves it on the tick", function()
		local source = fs.readFile(SERVICE)
		local offerAt = string.find(source, "run.offer = Rootvault.offer(", 1, true)
		expect(offerAt ~= nil).toBeTrue()
		local branch = string.sub(source, offerAt or 1, (offerAt or 1) + 500)
		expect(string.find(branch, "run.advanceAt = os.clock() + DungeonConfig.ROOM_CLEAR_SECONDS", 1, true) ~= nil).toBeTrue()
		local tickAt = string.find(source, "local function tickAdvance", 1, true)
		expect(tickAt ~= nil).toBeTrue()
		local tick = string.sub(source, tickAt or 1, (tickAt or 1) + 1000)
		expect(string.find(tick, "DungeonConfig.autoDoor(run.offer)", 1, true) ~= nil).toBeTrue()
		expect(string.find(tick, "DungeonService.chooseDoor(player, door)", 1, true) ~= nil).toBeTrue()
	end)
end)
