--!strict

--[[
	RollRefuse is pure and MenuHub does not run under Lune. The source
	lock reads MenuHub and checks the beginRoll refuse branch leaves
	the streak alone. The miss branch still notes a miss.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RollRefuse = require("../src/ReplicatedStorage/Shared/RollRefuse")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("RollRefuse", function()
	it("treats a thrown invoke as a refusal", function()
		expect(RollRefuse.classify(false, "RollShard remote is not available")).toEqual("refuse")
		expect(RollRefuse.classify(false, { ok = true, item = { name = "Shard" } })).toEqual(
			"refuse"
		)
	end)

	it("treats not enough tokens as a refusal", function()
		expect(RollRefuse.classify(true, { ok = false, error = "not enough tokens" })).toEqual(
			"refuse"
		)
	end)

	it("treats the timeout string as a refusal", function()
		expect(RollRefuse.classify(true, {
			ok = false,
			error = "RollShard remote is not available",
		})).toEqual("refuse")
	end)

	it("treats an item as a land", function()
		expect(RollRefuse.classify(true, { ok = true, item = { name = "Shard" } })).toEqual("land")
	end)

	it("treats ok with no item and no error as a miss", function()
		expect(RollRefuse.classify(true, { ok = true })).toEqual("miss")
		expect(RollRefuse.classify(true, { ok = true, error = "" })).toEqual("miss")
		expect(RollRefuse.classify(true, { ok = true, error = "   " })).toEqual("miss")
	end)

	it("treats an error on an accepted roll as a refusal", function()
		local cracked = { ok = true, error = "Could not crack that shard." }
		expect(RollRefuse.classify(true, cracked)).toEqual("refuse")
	end)

	it("ignores paid, a product id, Robux, cost, and skip", function()
		local refused = {
			ok = false,
			error = "not enough tokens",
			paid = true,
			productId = 0,
			robux = 0,
			cost = 0,
			skip = true,
		}
		expect(RollRefuse.classify(true, refused, true)).toEqual("refuse")
		local paidMiss = { ok = true, paid = true, productId = 0, robux = 0 }
		expect(RollRefuse.classify(true, paidMiss)).toEqual("miss")
		expect(RollRefuse.classify(true, {
			ok = true,
			item = { name = "Shard" },
			paid = true,
			cost = 0,
			skip = true,
		})).toEqual("land")
	end)

	it("does not write its argument", function()
		local refused = { ok = false, error = "not enough tokens", paid = true }
		local missed = { ok = true }
		local landed = { ok = true, item = { name = "Shard" } }
		table.freeze(refused)
		table.freeze(missed)
		table.freeze(landed)
		table.freeze(landed.item)
		expect(RollRefuse.classify(true, refused)).toEqual("refuse")
		expect(RollRefuse.classify(true, missed)).toEqual("miss")
		expect(RollRefuse.classify(true, landed)).toEqual("land")
		expect(refused.error).toEqual("not enough tokens")
		expect(refused.paid).toEqual(true)
		expect(missed.ok).toEqual(true)
		expect(landed.item.name).toEqual("Shard")
	end)

	it("refuses a result that is not a table", function()
		expect(RollRefuse.classify(true, "not enough tokens")).toEqual("refuse")
		expect(RollRefuse.classify(true, nil)).toEqual("refuse")
	end)

	it("does not use a clock, rng, or services", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RollRefuse.luau")
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
	end)
end)

describe("MenuHub refused roll", function()
	it("does not note a miss on the refuse branch", function()
		local hub = fs.readFile(HUB)
		local beginRoll = between(hub, "beginRoll = function()", "function hubFn.pointerDown")
		local earlyFrom = 'if kind ~= "land" or record == nil then'
		local early = between(beginRoll, earlyFrom, "lastCrack = os.clock()")
		local refuse = between(early, 'if kind == "refuse" then', 'elseif kind == "miss" then')
		local miss = between(early, 'elseif kind == "miss" then', "Unusable land")
		local unusable = between(early, "Unusable land", "loop = RollLoop.idle()")
		local land = between(beginRoll, "lastCrack = os.clock()", "noted.ok ~= true")
		local _, earlyBlanks = string.gsub(early, "blankReveal%(%)", "")

		expect(string.find(refuse, "RollHype.note", 1, true)).toBeNil()
		expect(string.find(refuse, "lastMissed =", 1, true)).toBeNil()
		expect(string.find(refuse, "closeCall", 1, true)).toBeNil()
		expect(string.find(refuse, "hideCloseBeat", 1, true) ~= nil).toBeTrue()
		expect(string.find(refuse, "RollReveal.reelCaption", 1, true) ~= nil).toBeTrue()

		expect(string.find(miss, "RollHype.note", 1, true) ~= nil).toBeTrue()
		expect(string.find(miss, "landed = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(miss, "lastMissed = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(miss, "closeCall", 1, true)).toBeNil()

		expect(string.find(unusable, "RollHype.note", 1, true)).toBeNil()
		expect(string.find(unusable, "lastMissed =", 1, true)).toBeNil()
		expect(string.find(unusable, "closeCall", 1, true)).toBeNil()

		expect(earlyBlanks).toEqual(1)
		expect(string.find(early, "blankReveal()", 1, true) ~= nil).toBeTrue()
		expect(string.find(early, "RollLoop.idle()", 1, true) ~= nil).toBeTrue()
		local missCaption = "paintReelIdle(RollReveal.reelCaption(result))"
		expect(string.find(early, missCaption, 1, true) ~= nil).toBeTrue()
		local captionAt = string.find(early, "paintReelIdle", 1, true)
		local paintAt = string.find(early, "paintRoll()", 1, true)
		expect(captionAt ~= nil and paintAt ~= nil).toBeTrue()
		expect((captionAt :: number) < (paintAt :: number)).toBeTrue()

		expect(string.find(land, "RollHype.note", 1, true) ~= nil).toBeTrue()
		expect(string.find(land, "landed = true", 1, true) ~= nil).toBeTrue()
	end)
end)
