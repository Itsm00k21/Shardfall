--!strict

--[[
	The gate in front of any paid shard roll.

	PolicyService:GetPolicyInfoForPlayerAsync returns ArePaidRandomItemsRestricted.
	Roblox requires that check before a player can buy a random item. This
	function only interprets the result. RollService calls PolicyService, then
	calls evaluate(), and only then would a real purchase be allowed to run.

	A missing or non-boolean flag fails closed. The purchase stub still
	refuses after an "allowed" decision — nothing is charged and nothing is rolled.
]]

local PaidRollPolicy = {}

export type Decision = {
	ok: boolean,
	code: string,
	error: string?,
}

function PaidRollPolicy.evaluate(policyInfo: any): Decision
	if
		type(policyInfo) ~= "table"
		or type(policyInfo.ArePaidRandomItemsRestricted) ~= "boolean"
	then
		return {
			ok = false,
			code = "policy_unavailable",
			error = "Could not check purchase policy. Try again.",
		}
	end
	if policyInfo.ArePaidRandomItemsRestricted then
		return {
			ok = false,
			code = "restricted",
			error = "Paid random items are restricted on this account.",
		}
	end
	return {
		ok = true,
		code = "allowed",
	}
end

return PaidRollPolicy
