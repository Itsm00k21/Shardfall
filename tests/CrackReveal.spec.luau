--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CrackReveal = require("../src/ReplicatedStorage/Shared/CrackReveal")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")

describe("CrackReveal", function()
	it("cracks the server rarity and never names another", function()
		for _, rarity in ipairs(Rarities.ORDER) do
			local plan = CrackReveal.plan(rarity, "full")
			expect(plan.rarity).toEqual(rarity)
			expect(plan.seconds > 0).toBeTrue()
			local sample = CrackReveal.sample(plan, plan.seconds * 0.5)
			expect(sample.shake >= 0).toBeTrue()
			expect(plan.rarity).toEqual(rarity)
		end
		local unknown = CrackReveal.plan("Godly", "full")
		expect(unknown.rarity).toEqual("Common")
	end)

	it("keeps a crack when Quick or Skip shortens it", function()
		local full = CrackReveal.plan("Legendary", "full")
		local quick = CrackReveal.plan("Legendary", "quick")
		local skip = CrackReveal.plan("Legendary", "skip")
		local reduced = CrackReveal.plan("Legendary", "reduced")
		expect(quick.seconds > 0 and quick.seconds < full.seconds).toBeTrue()
		expect(skip.seconds > 0 and skip.seconds < quick.seconds).toBeTrue()
		expect(reduced.seconds > 0).toBeTrue()
		expect(CrackReveal.sample(skip, 0).showName).toEqual(false)
		expect(CrackReveal.sample(skip, skip.seconds).showName).toEqual(true)
	end)

	it("gives Common a short crack and Epic a real tension beat", function()
		local common = CrackReveal.plan("Common", "full")
		local rare = CrackReveal.plan("Rare", "full")
		local epic = CrackReveal.plan("Epic", "full")
		expect(common.seconds < rare.seconds).toBeTrue()
		expect(rare.seconds < epic.seconds).toBeTrue()
		expect(common.flash).toEqual(false)
		expect(common.glow).toEqual(false)
		expect(common.tensionEnd).toEqual(common.crackEnd)
		expect(rare.flash).toEqual(true)
		expect(rare.glow).toEqual(true)
		expect(epic.tensionEnd > epic.crackEnd).toBeTrue()
		local held = CrackReveal.sample(epic, (epic.crackEnd + epic.tensionEnd) / 2)
		expect(held.tension).toEqual(true)
		expect(held.showName).toEqual(false)
		expect(CrackReveal.sample(common, common.seconds * 0.5).tension).toEqual(false)
	end)

	it("is what the roll tab plays", function()
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		expect(string.find(hub, "CrackReveal.plan", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "CrackReveal.sample", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "RollSpot.place", 1, true) ~= nil).toBeTrue()
		local spot = fs.readFile("src/ReplicatedStorage/Shared/RollSpot.luau")
		expect(string.find(spot, "Gear Shards", 1, true) ~= nil).toBeTrue()
		expect(string.find(spot, "Pet Shards", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Crack a Pet Shard", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, '"RollShards"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Next Epic in", 1, true)).toBeNil()
		expect(string.find(hub, "RollMath", 1, true)).toBeNil()
		local client = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		expect(string.find(client, "rollReel.request", 1, true)).toBeNil()
		expect(string.find(client, 'menuHub.open("roll")', 1, true) ~= nil).toBeTrue()
	end)
end)
