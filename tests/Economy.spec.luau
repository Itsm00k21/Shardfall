--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Economy = require("../src/ReplicatedStorage/Shared/Economy")

describe("Economy", function()
	it("prices Forge upgrades without destroying the item", function()
		expect(Economy.upgradeCost(0)).toEqual(150)
		expect(Economy.upgradeCost(1)).toEqual(300)
		local curve = { 1280, 2048, 3277, 5243, 8389, 13422, 21475, 34360 }
		for index, cost in ipairs(curve) do
			expect(Economy.upgradeCost(index + 1)).toEqual(cost)
		end
		local gold, mats = Economy.upgradeCost(7)
		expect(gold > Economy.upgradeCost(6)).toEqual(true)
		expect(mats).toEqual(1)
		local data = { gold = 150, materials = { bark = 0, gnarl_seed = 0 }, ledger = {} }
		local item = { name = "Sword", upgrade = 0 }
		local ok, note = Economy.upgrade(item, data)
		expect(ok).toEqual(true)
		expect(item.upgrade).toEqual(1)
		expect(data.gold).toEqual(0)
		expect(data.materials.gnarl_seed).toEqual(0)
		expect(note).toEqual("Sword +1")
		data.gold = 0
		local failed = Economy.upgrade(item, data)
		expect(failed).toEqual(false)
		expect(item.upgrade).toEqual(1)
	end)

	it("spends one Gnarl's Seed on +8, +9, and +10", function()
		local plus7 = Economy.upgradeCost(6)
		local early = {
			gold = plus7,
			materials = { bark = 5, gnarl_seed = 0 },
			ledger = {},
		}
		local sword = { name = "Sword", upgrade = 6 }
		local earlyOk = Economy.upgrade(sword, early)
		expect(earlyOk).toEqual(true)
		expect(sword.upgrade).toEqual(7)
		expect(early.materials.gnarl_seed).toEqual(0)
		expect(early.materials.bark).toEqual(5)

		local stepGold = Economy.upgradeCost(7)
		local short = {
			gold = stepGold,
			materials = { bark = 9, gnarl_seed = 0 },
			ledger = {},
		}
		local stuck = { name = "Sword", upgrade = 7 }
		local refused, reason = Economy.upgrade(stuck, short)
		expect(refused).toEqual(false)
		expect(reason).toEqual("Needs boss bark.")
		expect(stuck.upgrade).toEqual(7)
		expect(short.gold).toEqual(stepGold)
		expect(short.materials.bark).toEqual(9)
		expect(short.materials.gnarl_seed).toEqual(0)

		for _, level in ipairs({ 7, 8, 9 }) do
			local cost, needed = Economy.upgradeCost(level)
			expect(needed).toEqual(1)
			local bag = {
				gold = cost,
				materials = { bark = 4, gnarl_seed = 1 },
				ledger = {},
			}
			local piece = { name = "Sword", upgrade = level }
			local paid = Economy.upgrade(piece, bag)
			expect(paid).toEqual(true)
			expect(piece.upgrade).toEqual(level + 1)
			expect(bag.gold).toEqual(0)
			expect(bag.materials.gnarl_seed).toEqual(0)
			expect(bag.materials.bark).toEqual(4)
		end
	end)

	it("pays 150 gold for a finished daily or weekly", function()
		expect(Economy.QUEST_GOLD).toEqual(150)
		local loop = fs.readFile("src/ServerScriptService/ShardfallServer/LoopService.luau")
		expect(string.find(loop, "Economy.QUEST_GOLD * finished", 1, true) ~= nil).toBeTrue()
		expect(string.find(loop, "40 * finished", 1, true)).toBeNil()
	end)

	it("caps auto-farm, logs a grant, and ignores a repeated receipt", function()
		local paid, used, capped = Economy.farmPayout(1000, true, 10)
		expect(paid).toEqual(400)
		expect(used).toEqual(10)
		expect(capped).toEqual(false)
		local _none, _still, stopped = Economy.farmPayout(1000, true, Economy.FARM_SECONDS)
		expect(stopped).toEqual(true)
		local data = { gold = 0, gems = 0, ledger = {}, receipts = {} }
		Economy.grant(data, "gems", 25, "daily")
		expect(data.gems).toEqual(25)
		expect(data.ledger[1].reason).toEqual("daily")
		expect(Economy.receipt(data, "abc")).toEqual(false)
		expect(Economy.receipt(data, "abc")).toEqual(true)
		expect(#Economy.CURRENCIES).toEqual(6)
	end)
end)
