--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RAID = "src/ServerScriptService/ShardfallServer/RaidService.luau"

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

describe("Premade title filter", function()
	it("keeps a TextService failure refused in live servers and trimmed in Studio", function()
		local raid = fs.readFile(RAID)
		local filter = between(raid, "local function filterTitle", "local function copyStrings")
		local post = between(raid, "function RaidService.post", "function RaidService.join")

		local lengthAt = string.find(filter, "#title > TITLE_MAX", 1, true)
		local blankAt = string.find(filter, 'trimmed == ""', 1, true)
		local controlAt = string.find(filter, 'string.find(trimmed, "%c")', 1, true)
		local callAt = string.find(filter, "TextService:FilterStringAsync", 1, true)
		local broadcastAt = string.find(filter, "GetNonChatStringForBroadcastAsync", 1, true)
		local errorAt = string.find(filter, "if not filteredOk then", 1, true)
		local studioAt = string.find(filter, "if RunService:IsStudio() then", 1, true)
		local trimmedAt = string.find(filter, "return trimmed, nil", 1, true)
		local refuseAt = string.find(filter, 'return nil, "Could not filter that title."', 1, true)
		expect(lengthAt ~= nil and blankAt ~= nil and controlAt ~= nil).toBeTrue()
		expect(callAt ~= nil and broadcastAt ~= nil and errorAt ~= nil).toBeTrue()
		expect(studioAt ~= nil and trimmedAt ~= nil and refuseAt ~= nil).toBeTrue()
		expect((lengthAt :: number) < (callAt :: number)).toBeTrue()
		expect((blankAt :: number) < (callAt :: number)).toBeTrue()
		expect((controlAt :: number) < (callAt :: number)).toBeTrue()
		expect((callAt :: number) < (errorAt :: number)).toBeTrue()
		expect((errorAt :: number) < (studioAt :: number)).toBeTrue()
		expect((studioAt :: number) < (trimmedAt :: number)).toBeTrue()
		expect((trimmedAt :: number) < (refuseAt :: number)).toBeTrue()

		local studioBranch = string.sub(filter, errorAt :: number, refuseAt :: number)
		expect(string.find(studioBranch, "return trimmed, nil", 1, true) ~= nil).toBeTrue()
		expect(string.find(studioBranch, "return title", 1, true)).toBeNil()
		expect(string.find(filter, "return title,", 1, true)).toBeNil()
		expect(string.find(filter, "return title)", 1, true)).toBeNil()

		local afterRefuse = string.sub(filter, (refuseAt :: number) + 1)
		expect(string.find(afterRefuse, "RunService:IsStudio()", 1, true)).toBeNil()
		expect(string.find(afterRefuse, "return filtered, nil", 1, true) ~= nil).toBeTrue()
		expect(string.find(afterRefuse, 'type(filtered) ~= "string" or filtered == ""', 1, true) ~= nil).toBeTrue()
		expect(string.find(afterRefuse, "#filtered > TITLE_MAX", 1, true) ~= nil).toBeTrue()

		expect(string.find(post, "filterTitle(player, payload.title)", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "RaidPremade.open", 1, true) ~= nil).toBeTrue()
		expect(string.find(post, "title = title", 1, true) ~= nil).toBeTrue()
		local draft = between(raid, "local function buildDraft", "local function filterTitle")
		expect(string.find(draft, "title", 1, true)).toBeNil()
		local premade = fs.readFile("src/ReplicatedStorage/Shared/RaidPremade.luau")
		expect(string.find(premade, "FilterStringAsync", 1, true)).toBeNil()
		expect(string.find(raid, "schemaVersion", 1, true)).toBeNil()
	end)
end)
