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
	end)

	it("blocks the paid path when ArePaidRandomItemsRestricted is true", function()
		local decision = PaidRollPolicy.evaluate({
			ArePaidRandomItemsRestricted = true,
		})
		expect(decision.ok).toBeFalse()
		expect(decision.code).toEqual("restricted")
		expect(type(decision.error) == "string").toBeTrue()
	end)

	it("allows the caller to continue only when the flag is explicitly false", function()
		local decision = PaidRollPolicy.evaluate({
			ArePaidRandomItemsRestricted = false,
		})
		expect(decision.ok).toBeTrue()
		expect(decision.code).toEqual("allowed")
		expect(decision.error).toBeNil()
	end)
end)
