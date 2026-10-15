--!strict

--[[
	Two wallets that never mix.

	Shard Tokens are earned (clears, vouchers, starter grant). Prism Tokens
	are the Robux currency. A roll names which wallet it spends. Buying Prism
	Tokens or a Luck Boost is still a stub: the pitches below are what the
	panel shows before the purchase button.
]]

local Currencies = {}

Currencies.SHARD = "shard"
Currencies.PRISM = "prism"

-- PLACEHOLDER pack. Not a live developer product.
Currencies.PRISM_PACK_ROBUX = 100
Currencies.PRISM_PACK_TOKENS = 10

-- Added to Shard Luck while a purchased boost is active. Odds use the sum.
Currencies.LUCK_BOOST = 25

export type Wallet = {
	shardTokens: number,
	prismTokens: number,
}

function Currencies.effectiveLuck(shardLuck: any, luckBoost: any): number
	local base = shardLuck
	if type(base) ~= "number" or base ~= base or base < 0 then
		base = 0
	end
	local extra = luckBoost
	if type(extra) ~= "number" or extra ~= extra or extra < 0 then
		extra = 0
	end
	return base + extra
end

-- Spends one token from the named wallet. The other wallet is left alone.
-- Returns false and a reason without changing the wallet when it is short.
function Currencies.take(wallet: Wallet, currency: string): (boolean, string?)
	if currency == Currencies.SHARD then
		if wallet.shardTokens < 1 then
			return false, "You need a Shard Token to crack a shard."
		end
		wallet.shardTokens -= 1
		return true, nil
	end
	if currency == Currencies.PRISM then
		if wallet.prismTokens < 1 then
			return false, "You need a Prism Token. Prism Tokens are bought with Robux."
		end
		wallet.prismTokens -= 1
		return true, nil
	end
	return false, "Unknown token."
end

function Currencies.packPitch(): string
	return string.format(
		"%d Robux for %d Prism Tokens. Placeholder price. Not for sale yet.",
		Currencies.PRISM_PACK_ROBUX,
		Currencies.PRISM_PACK_TOKENS
	)
end

function Currencies.boostPitch(active: any): string
	local amount = active
	if type(amount) ~= "number" or amount ~= amount or amount < 0 then
		amount = 0
	end
	if amount > 0 then
		return string.format(
			"Luck Boost is active: +%d Shard Luck. The Odds list includes it.",
			amount
		)
	end
	return string.format(
		"Luck Boost adds +%d Shard Luck to every roll. The Odds list updates while it is active. Not for sale yet.",
		Currencies.LUCK_BOOST
	)
end

return Currencies
