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

-- Timed crafting XP. No developer product yet. The buy remote refuses and
-- shows this pitch. A Studio dev grant can set the timestamp so the bench
-- can be tested.
Currencies.FORGE_BOOST_SECONDS = 60 * 60
Currencies.FORGE_BOOST_MULT = 2

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

-- Extra bag slots. No developer product yet. The buy remote refuses and
-- shows this pitch. The base cap stays in Schema.
Currencies.INVENTORY_EXPAND_SLOTS = 10
Currencies.INVENTORY_EXPAND_ROBUX = 80

function Currencies.inventoryPitch(bonus: any): string
	local extra = bonus
	if type(extra) ~= "number" or extra ~= extra or extra < 0 then
		extra = 0
	end
	return string.format(
		"Inventory expansion adds %d slots for %d Robux. You have %d extra slots. Not for sale yet.",
		Currencies.INVENTORY_EXPAND_SLOTS,
		Currencies.INVENTORY_EXPAND_ROBUX,
		math.floor(extra)
	)
end

function Currencies.forgeBoostPitch(untilTime: any, now: any): string
	local stamp = untilTime
	local clock = now
	if type(stamp) ~= "number" or stamp ~= stamp then
		stamp = 0
	end
	if type(clock) ~= "number" or clock ~= clock then
		clock = 0
	end
	if stamp > clock then
		local left = math.floor(stamp - clock)
		return string.format(
			"Forge Boost is active: %dx Crafting XP for %d more minutes.",
			Currencies.FORGE_BOOST_MULT,
			math.max(1, math.ceil(left / 60))
		)
	end
	return string.format(
		"Forge Boost grants %dx Crafting XP for %d minutes. Not for sale yet. Daily login can grant it later.",
		Currencies.FORGE_BOOST_MULT,
		math.floor(Currencies.FORGE_BOOST_SECONDS / 60)
	)
end

return Currencies
