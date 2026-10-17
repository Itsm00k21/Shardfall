--!strict

--[[
	Six currencies, Forge +0 to +10, the auto-farm cap, and receipt ids.

	Gold, Shard Keys, and Shard Dust already move through their own modules.
	Gems and Event Tokens live here. Upgrades never destroy the item.
	Trading and the Market Board stay post-beta.
]]

local Economy = {}

Economy.CURRENCIES = { "gold", "shardKeys", "shardDust", "gems", "eventTokens", "materials" }
Economy.FARM_SECONDS = 2 * 60 * 60
Economy.FARM_RATE = 0.4
Economy.UPGRADE_MAX = 10
Economy.SHOP_KEY_COST = 40
-- A finished daily and a finished weekly share this grant.
Economy.QUEST_GOLD = 150

function Economy.upgradeCost(level: number): (number, number)
	local whole = math.floor(level)
	if whole < 0 then
		whole = 0
	end
	-- +1 and +2 are flat. From +3 the live 1.6 curve stays.
	local gold = math.floor(500 * (1.6 ^ whole) + 0.5)
	if whole == 0 then
		gold = 150
	elseif whole == 1 then
		gold = 300
	end
	local bossMats = if whole >= 7 then 1 else 0
	return gold, bossMats
end

function Economy.upgrade(item: any, data: any): (boolean, string)
	if type(item) ~= "table" then
		return false, "That item is not in your bag."
	end
	local level = math.floor(tonumber(item.upgrade) or 0)
	if level >= Economy.UPGRADE_MAX then
		return false, "Already +10."
	end
	local gold, mats = Economy.upgradeCost(level)
	if (data.gold or 0) < gold then
		return false, "Not enough gold."
	end
	if mats > 0 and ((data.materials and data.materials.gnarl_seed) or 0) < mats then
		return false, "Needs boss bark."
	end
	data.gold -= gold
	if mats > 0 then
		data.materials.gnarl_seed -= mats
	end
	item.upgrade = level + 1
	Economy.log(data, "forge_upgrade", "gold", -gold, data.gold)
	return true, string.format("%s +%d", item.name or "Gear", item.upgrade)
end

function Economy.log(data: any, reason: string, currency: string, amount: number, balance: number)
	if type(data.ledger) ~= "table" then
		data.ledger = {}
	end
	table.insert(data.ledger, {
		reason = reason,
		currency = currency,
		amount = amount,
		balance = balance,
	})
	while #data.ledger > 20 do
		table.remove(data.ledger, 1)
	end
end

function Economy.grant(data: any, currency: string, amount: number, reason: string): boolean
	if amount == 0 or type(data) ~= "table" then
		return false
	end
	if
		currency ~= "gold"
		and currency ~= "gems"
		and currency ~= "eventTokens"
		and currency ~= "shardKeys"
		and currency ~= "shardDust"
	then
		return false
	end
	data[currency] = math.max(0, (data[currency] or 0) + amount)
	Economy.log(data, reason, currency, amount, data[currency])
	return true
end

function Economy.farmPayout(
	activeGold: number,
	farmed: boolean,
	secondsUsed: number
): (number, number, boolean)
	local used = math.max(0, secondsUsed)
	if not farmed then
		return activeGold, used, false
	end
	if used >= Economy.FARM_SECONDS then
		return 0, used, true
	end
	return math.floor(activeGold * Economy.FARM_RATE + 0.5), used, false
end

-- True when this receipt id was already granted.
function Economy.receipt(data: any, receiptId: string): boolean
	if type(data.receipts) ~= "table" then
		data.receipts = {}
	end
	if data.receipts[receiptId] == true then
		return true
	end
	data.receipts[receiptId] = true
	return false
end

return Economy
