--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("Playtest follow-up", function()
	it("does not set the crawl camera occlusion mode from the client", function()
		local lod = fs.readFile(CLIENT .. "VerdantLod.luau")
		expect(string.find(lod, "DevCameraOcclusionMode", 1, true)).toBeNil()
		expect(string.find(lod, "CameraMaxZoomDistance", 1, true) ~= nil).toBeTrue()
		expect(string.find(lod, "CameraMinZoomDistance", 1, true) ~= nil).toBeTrue()
	end)

	it("keeps GetOdds off the per-roll key and swallows the rate limit", function()
		local client = fs.readFile(CLIENT .. "init.client.luau")
		local keyFn = between(client, "local function oddsKey(profile: any): string", "local function flagBit")
		expect(string.find(keyFn, "shardRolls", 1, true)).toBeNil()
		expect(string.find(keyFn, "rollsSinceLegendary", 1, true)).toBeNil()
		expect(string.find(keyFn, "shardLuck", 1, true) ~= nil).toBeTrue()
		expect(string.find(keyFn, "luckBoost", 1, true) ~= nil).toBeTrue()
		local pull = between(client, "local function refreshOdds()", "local function oddsKey")
		local guardAt = string.find(pull, 'message ~= "Slow down a moment."', 1, true)
		local warnAt = string.find(pull, "warn(", 1, true)
		local statusAt = string.find(pull, "ui.setStatus", 1, true)
		local noticeAt = string.find(pull, "ui.setNotice", 1, true)
		expect(guardAt ~= nil).toBeTrue()
		expect(warnAt ~= nil and statusAt ~= nil and noticeAt ~= nil).toBeTrue()
		expect((guardAt :: number) < (warnAt :: number)).toBeTrue()
		expect((guardAt :: number) < (statusAt :: number)).toBeTrue()
		expect((guardAt :: number) < (noticeAt :: number)).toBeTrue()
		expect(string.find(pull, "oddsPull.again", 1, true) ~= nil).toBeTrue()
	end)

	it("gives every guarded remote a rate limit, including the Gold shop", function()
		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local limiter = fs.readFile("src/ServerScriptService/ShardfallServer/RateLimiter.luau")
		local seen: { [string]: boolean } = {}
		for action in string.gmatch(remotes, 'guard%(player, "([%w]+)"') do
			seen[action] = true
		end
		expect(seen.BuyGoldShop).toEqual(true)
		local count = 0
		for action in pairs(seen) do
			count += 1
			local rule = string.find(limiter, action .. " = {", 1, true)
			expect(rule ~= nil).toBeTrue()
		end
		expect(count > 10).toBeTrue()
		expect(string.find(limiter, "BuyGoldShop = { capacity = 3, perSecond = 1 }", 1, true) ~= nil).toBeTrue()
	end)

	it("hides launch craft recipes that are not rerolls", function()
		local ui = fs.readFile(CLIENT .. "Ui.luau")
		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		expect(string.find(ui, 'LaunchGate.on("forgeCraft")', 1, true) ~= nil).toBeTrue()
		expect(string.find(ui, 'recipe.result.kind ~= "reroll"', 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, 'LaunchGate.on("forgeCraft")', 1, true) ~= nil).toBeTrue()
		expect(string.find(remotes, '"That is closed."', 1, true) ~= nil).toBeTrue()
	end)
end)
