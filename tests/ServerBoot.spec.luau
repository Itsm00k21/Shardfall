--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local SERVER = "src/ServerScriptService/ShardfallServer/init.server.luau"

local function lastAt(source: string, needle: string): number
	local index = 1
	local found = nil
	while true do
		local nextAt = string.find(source, needle, index, true)
		if nextAt == nil then
			break
		end
		found = nextAt
		index = nextAt + 1
	end
	expect(found ~= nil).toBeTrue()
	return found :: number
end

describe("Server boot", function()
	it("loads profiles before trade and market, and guards the api services", function()
		local server = fs.readFile(SERVER)
		local profiles = lastAt(server, "DataService.start()")
		local guarded = {
			"RollService.bindAnnouncements()",
			"ReceiptService.start()",
			"DungeonService.start()",
			"TradeService.start()",
			"MarketService.start()",
			"RaidService.receive(player)",
		}
		for _, call in ipairs(guarded) do
			expect(profiles < lastAt(server, call)).toBeTrue()
		end
		local guards = {
			{ 'begin("DataService"', "DataService.start()" },
			{ 'begin("PolicyCache"', "PolicyCache.start()" },
			{ 'begin("RollService"', "RollService.bindAnnouncements()" },
			{ 'begin("ReceiptService"', "ReceiptService.start()" },
			{ 'begin("ClassService"', "ClassService.start()" },
			{ 'begin("CombatService"', "CombatService.start()" },
			{ 'begin("DungeonService"', "DungeonService.start()" },
			{ 'begin("TradeService"', "TradeService.start()" },
			{ 'begin("MarketService"', "MarketService.start()" },
		}
		local startCalls = 0
		for line in string.gmatch(server, "[^\n]+") do
			if string.find(line, ".start()", 1, true) ~= nil and string.find(line, "--", 1, true) == nil then
				startCalls += 1
				expect(string.byte(line, 1) == 9).toBeTrue()
			end
		end
		expect(startCalls >= 8).toBeTrue()
		for _, pair in ipairs(guards) do
			expect(lastAt(server, pair[1]) < lastAt(server, pair[2])).toBeTrue()
		end
		expect(string.find(server, "[Shardfall] RaidService failed:", 1, true) ~= nil).toBeTrue()
		expect(string.find(server, "local ok, err = pcall(start)", 1, true) ~= nil).toBeTrue()

		local trade = fs.readFile("src/ServerScriptService/ShardfallServer/TradeService.luau")
		local market = fs.readFile("src/ServerScriptService/ShardfallServer/MarketService.luau")
		local audit = fs.readFile("src/ServerScriptService/ShardfallServer/TradeAudit.luau")
		expect(string.find(trade, "trade audit unavailable, using an empty log", 1, true) ~= nil).toBeTrue()
		expect(string.find(market, "market could not watch leaving players", 1, true) ~= nil).toBeTrue()
		expect(string.find(audit, "trade audit unavailable, using an empty log", 1, true) ~= nil).toBeTrue()
	end)
end)
