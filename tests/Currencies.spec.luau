--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Currencies = require("../src/ReplicatedStorage/Shared/Currencies")

describe("Currencies", function()
	it("spends a Shard Token without touching Prism Tokens", function()
		local wallet = { shardTokens = 2, prismTokens = 4 }
		local ok, reason = Currencies.take(wallet, Currencies.SHARD)
		expect(ok).toBeTrue()
		expect(reason).toBeNil()
		expect(wallet.shardTokens).toEqual(1)
		expect(wallet.prismTokens).toEqual(4)
	end)

	it("spends a Prism Token without touching Shard Tokens", function()
		local wallet = { shardTokens = 2, prismTokens = 4 }
		local ok = Currencies.take(wallet, Currencies.PRISM)
		expect(ok).toBeTrue()
		expect(wallet.prismTokens).toEqual(3)
		expect(wallet.shardTokens).toEqual(2)
	end)

	it("refuses an empty wallet and an unknown currency", function()
		local wallet = { shardTokens = 0, prismTokens = 0 }
		local shardOk, shardReason = Currencies.take(wallet, Currencies.SHARD)
		expect(shardOk).toBeFalse()
		expect(type(shardReason) == "string").toBeTrue()
		local prismOk = Currencies.take(wallet, Currencies.PRISM)
		expect(prismOk).toBeFalse()
		expect(wallet.shardTokens).toEqual(0)
		expect(wallet.prismTokens).toEqual(0)
		local unknownOk = Currencies.take(wallet, "gold")
		expect(unknownOk).toBeFalse()
	end)

	it("adds a Luck Boost on top of earned luck and states the amount before purchase", function()
		expect(Currencies.effectiveLuck(10, 0)).toEqual(10)
		expect(Currencies.effectiveLuck(10, Currencies.LUCK_BOOST)).toEqual(35)
		expect(Currencies.LUCK_BOOST).toEqual(25)
		local pitch = Currencies.boostPitch(0)
		expect(string.find(pitch, "+25", 1, true) ~= nil).toBeTrue()
		local active = Currencies.boostPitch(25)
		expect(string.find(active, "active", 1, true) ~= nil).toBeTrue()
		local pack = Currencies.packPitch()
		expect(string.find(pack, "100", 1, true) ~= nil).toBeTrue()
		expect(string.find(pack, "10", 1, true) ~= nil).toBeTrue()
	end)
end)
