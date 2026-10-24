--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local DebugTools = require("../src/ReplicatedStorage/Shared/DebugTools")

describe("Debug tools", function()
	it("sets level 20 and grants currencies, a chest, and an egg", function()
		local data = {
			gold = 0,
			shardKeys = 0,
			gems = 0,
			shardDust = 0,
			eventTokens = 0,
			chests = {},
			eggs = 0,
			level = 1,
			xp = 40,
		}
		expect(DebugTools.apply(data, "level")).toEqual(true)
		expect(data.level).toEqual(20)
		expect(data.xp).toEqual(0)
		DebugTools.apply(data, "gold")
		DebugTools.apply(data, "keys")
		DebugTools.apply(data, "gems")
		DebugTools.apply(data, "dust")
		DebugTools.apply(data, "tokens")
		DebugTools.apply(data, "chest")
		DebugTools.apply(data, "eggs")
		expect(data.gold).toEqual(1000)
		expect(data.shardKeys).toEqual(20)
		expect(data.chests.Rare).toEqual(1)
		expect(data.eggs).toEqual(1)
		expect(DebugTools.apply(data, "nope")).toEqual(false)
	end)
end)
