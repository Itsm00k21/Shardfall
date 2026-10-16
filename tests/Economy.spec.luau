--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Economy = require("../src/ReplicatedStorage/Shared/Economy")

describe("Economy", function()
	it("prices Forge upgrades without destroying the item", function()
		expect(Economy.upgradeCost(0)).toEqual(500)
		local gold, mats = Economy.upgradeCost(7)
		expect(gold > Economy.upgradeCost(6)).toEqual(true)
		expect(mats).toEqual(1)
		local data = { gold = 500, materials = { bark = 0 }, ledger = {} }
		local item = { name = "Sword", upgrade = 0 }
		local ok, note = Economy.upgrade(item, data)
		expect(ok).toEqual(true)
		expect(item.upgrade).toEqual(1)
		expect(data.gold).toEqual(0)
		expect(note).toEqual("Sword +1")
		data.gold = 0
		local failed = Economy.upgrade(item, data)
		expect(failed).toEqual(false)
		expect(item.upgrade).toEqual(1)
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
