--!strict

--[[
	Reads PolicyService:GetPolicyInfoForPlayerAsync for one player.

	ArePaidRandomItemsRestricted gates paid random items (Prism Token cracks,
	Robux packs, luck boosts). IsPaidItemTradingAllowed is a separate flag
	for trading paid items. This game has no trade UI. canTrade() is the
	check a later trade path has to call.

	A missing flag or a failed lookup fails closed. Earned Shard Token
	cracks do not go through this module.
]]

local PaidRollPolicy = {}

PaidRollPolicy.REGION_MESSAGE = "Paid random items are unavailable in your region."

export type Read = {
	ok: boolean,
	restricted: boolean,
	tradingAllowed: boolean,
	code: string,
	error: string?,
}

export type Decision = {
	ok: boolean,
	code: string,
	error: string?,
}

function PaidRollPolicy.read(policyInfo: any): Read
	if
		type(policyInfo) ~= "table"
		or type(policyInfo.ArePaidRandomItemsRestricted) ~= "boolean"
		or type(policyInfo.IsPaidItemTradingAllowed) ~= "boolean"
	then
		return {
			ok = false,
			restricted = true,
			tradingAllowed = false,
			code = "policy_unavailable",
			error = "Could not check purchase policy. Try again.",
		}
	end
	local restricted = policyInfo.ArePaidRandomItemsRestricted
	return {
		ok = true,
		restricted = restricted,
		tradingAllowed = policyInfo.IsPaidItemTradingAllowed,
		code = if restricted then "restricted" else "allowed",
		error = if restricted then PaidRollPolicy.REGION_MESSAGE else nil,
	}
end

-- Paid random items only. Trading false does not block a Prism crack.
function PaidRollPolicy.evaluate(policyInfo: any): Decision
	local read = PaidRollPolicy.read(policyInfo)
	if not read.ok or read.restricted then
		return {
			ok = false,
			code = read.code,
			error = read.error,
		}
	end
	return {
		ok = true,
		code = "allowed",
	}
end

function PaidRollPolicy.canTrade(policyInfo: any): boolean
	local read = PaidRollPolicy.read(policyInfo)
	return read.ok and read.tradingAllowed
end

return PaidRollPolicy
