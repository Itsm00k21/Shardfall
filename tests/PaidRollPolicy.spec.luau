--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local PaidRollPolicy = require("../src/ReplicatedStorage/Shared/PaidRollPolicy")

describe("PaidRollPolicy", function()
	it("fails closed when the policy payload is missing or incomplete", function()
		local missing = PaidRollPolicy.evaluate(nil)
		expect(missing.ok).toBeFalse()
		expect(missing.code).toEqual("policy_unavailable")

		local blank = PaidRollPolicy.evaluate({})
		expect(blank.ok).toBeFalse()
		expect(blank.code).toEqual("policy_unavailable")

		local oneFlag = PaidRollPolicy.evaluate({
			ArePaidRandomItemsRestricted = false,
		})
		expect(oneFlag.ok).toBeFalse()
		expect(oneFlag.code).toEqual("policy_unavailable")
		expect(PaidRollPolicy.canTrade({ ArePaidRandomItemsRestricted = false })).toBeFalse()
	end)

	it("blocks paid random items when ArePaidRandomItemsRestricted is true", function()
		local info = {
			ArePaidRandomItemsRestricted = true,
			IsPaidItemTradingAllowed = true,
		}
		local decision = PaidRollPolicy.evaluate(info)
		expect(decision.ok).toBeFalse()
		expect(decision.code).toEqual("restricted")
		expect(decision.error).toEqual(PaidRollPolicy.REGION_MESSAGE)
		local read = PaidRollPolicy.read(info)
		expect(read.restricted).toBeTrue()
		expect(read.tradingAllowed).toBeTrue()
	end)

	it("allows paid rolls only when the restricted flag is explicitly false", function()
		local decision = PaidRollPolicy.evaluate({
			ArePaidRandomItemsRestricted = false,
			IsPaidItemTradingAllowed = false,
		})
		expect(decision.ok).toBeTrue()
		expect(decision.code).toEqual("allowed")
		expect(decision.error).toBeNil()
	end)

	it("treats trading as its own flag and fails closed when it is absent", function()
		expect(PaidRollPolicy.canTrade({
			ArePaidRandomItemsRestricted = false,
			IsPaidItemTradingAllowed = true,
		})).toBeTrue()
		expect(PaidRollPolicy.canTrade({
			ArePaidRandomItemsRestricted = false,
			IsPaidItemTradingAllowed = false,
		})).toBeFalse()
		expect(PaidRollPolicy.canTrade(nil)).toBeFalse()
	end)
end)
