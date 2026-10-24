--!strict

--[[
	Stage C Shard Core. Data only. Nothing here is for sale, and nothing
	here is Robux.

	One core per weapon. Feeding spends profile.gearEssence and raises
	that weapon's core level. The level lives in profile.shardCores.
	A missing level is 0. The item itself is not written: no coreLevel,
	and item.upgrade is not read. Stars and gold upgrades can change
	the finished totals later. These perks are added on top of those.

	Pets have no core. There is no pet feeder.

	Costs are the Essence to buy the next level: 5, 15, 40, 100, 250.
	Cap is 5. Perks are cumulative and modest. Level 1 keeps perk 1,
	level 2 keeps perks 1 and 2, and so on.
]]

local ShardCore = {}

ShardCore.CAP = 5

-- Dev Tools "Grant Essence". Not a product.
ShardCore.DEV_GRANT = 100

-- Same ceiling Schema uses for gearEssence.
ShardCore.WALLET_CAP = 1000000000

-- Index 1 is the cost of level 0 -> 1.
ShardCore.COST = table.freeze({ 5, 15, 40, 100, 250 })

ShardCore.PERKS = table.freeze({
	table.freeze({
		level = 1,
		id = "crit_chance",
		name = "Crit Chance",
		amount = 0.01,
		unit = "percent",
		decimals = 1,
		text = "+1% crit chance",
	}),
	table.freeze({
		level = 2,
		id = "shard_find",
		name = "Shard Find",
		amount = 0.02,
		unit = "percent",
		decimals = 0,
		text = "+2% shard find",
	}),
	table.freeze({
		level = 3,
		id = "move_speed",
		name = "Move Speed",
		amount = 0.02,
		unit = "percent",
		decimals = 0,
		text = "+2% move speed",
	}),
	table.freeze({
		level = 4,
		id = "crit_damage",
		name = "Crit Damage",
		amount = 0.05,
		unit = "multiplier",
		decimals = 2,
		text = "+5% crit damage",
	}),
	table.freeze({
		level = 5,
		id = "luck",
		name = "Luck",
		amount = 1,
		unit = "flat",
		decimals = 0,
		text = "+1 luck",
	}),
})

local function whole(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then
		return nil
	end
	return math.floor(value)
end

function ShardCore.validId(value: any): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= 64
		and string.match(value, "^[%w_%-]+$") ~= nil
end

function ShardCore.sanitize(value: any): { [string]: number }
	local clean: { [string]: number } = {}
	if type(value) ~= "table" then
		return clean
	end
	local cap = ShardCore.CAP
	if type(cap) ~= "number" or cap < 1 then
		cap = 5
	end
	for key, level in pairs(value) do
		if ShardCore.validId(key) then
			local stored = whole(level)
			if stored ~= nil and stored > 0 then
				if stored > cap then
					stored = cap
				end
				clean[key] = stored
			end
		end
	end
	return clean
end

function ShardCore.levelOf(profile: any, itemId: any): number
	if type(profile) ~= "table" or not ShardCore.validId(itemId) then
		return 0
	end
	local map = profile.shardCores
	if type(map) ~= "table" then
		return 0
	end
	local stored = whole(map[itemId])
	if stored == nil or stored <= 0 then
		return 0
	end
	if stored > ShardCore.CAP then
		return ShardCore.CAP
	end
	return stored
end

function ShardCore.essenceOf(profile: any): number
	if type(profile) ~= "table" then
		return 0
	end
	local amount = whole(profile.gearEssence)
	if amount == nil then
		return 0
	end
	if amount > ShardCore.WALLET_CAP then
		return ShardCore.WALLET_CAP
	end
	return amount
end

function ShardCore.costToNext(level: any): number?
	local current = whole(level) or 0
	if current < 0 then
		current = 0
	end
	if current >= ShardCore.CAP then
		return nil
	end
	local cost = ShardCore.COST[current + 1]
	if type(cost) ~= "number" or cost ~= cost or cost < 1 or cost >= math.huge then
		return nil
	end
	return math.floor(cost)
end

function ShardCore.perkRows(level: any): { any }
	local current = whole(level) or 0
	local rows: { any } = {}
	for _, perk in ipairs(ShardCore.PERKS) do
		table.insert(rows, {
			level = perk.level,
			id = perk.id,
			name = perk.name,
			text = perk.text,
			amount = perk.amount,
			unlocked = current >= perk.level,
		})
	end
	return rows
end

-- Flat adds for the unlocked perks. Not a multiplier.
function ShardCore.bonus(level: any): { [string]: number }
	local current = whole(level) or 0
	local sums: { [string]: number } = {}
	for _, perk in ipairs(ShardCore.PERKS) do
		if
			type(perk.id) == "string"
			and type(perk.amount) == "number"
			and current >= perk.level
		then
			sums[perk.id] = (sums[perk.id] or 0) + perk.amount
		end
	end
	return sums
end

function ShardCore.status(level: any, essence: any): (string, boolean)
	local cost = ShardCore.costToNext(level)
	local wallet = whole(essence) or 0
	if cost == nil then
		return "That core is at its cap.", false
	end
	if wallet < cost then
		return "Not enough Essence.", false
	end
	return string.format("Feed %d Essence", cost), true
end

local function weaponName(item: any): string
	if type(item) == "table" and type(item.name) == "string" and item.name ~= "" then
		return item.name
	end
	return "Weapon"
end

function ShardCore.preview(profile: any, selectedUid: any): any
	local weapons: { any } = {}
	local essence = ShardCore.essenceOf(profile)
	if type(profile) == "table" and type(profile.inventory) == "table" then
		for uid, item in pairs(profile.inventory) do
			if ShardCore.validId(uid) and type(item) == "table" and item.kind == "Weapon" then
				local level = ShardCore.levelOf(profile, uid)
				local cost = ShardCore.costToNext(level)
				local status, canFeed = ShardCore.status(level, essence)
				local rarity = ""
				if type(item.rarity) == "string" then
					rarity = item.rarity
				end
				table.insert(weapons, {
					uid = uid,
					name = weaponName(item),
					rarity = rarity,
					level = level,
					nextCost = cost,
					capped = cost == nil,
					canFeed = canFeed,
					status = status,
					perks = ShardCore.perkRows(level),
				})
			end
		end
	end
	table.sort(weapons, function(left, right)
		if left.name == right.name then
			return left.uid < right.uid
		end
		return left.name < right.name
	end)
	local selected = nil
	if ShardCore.validId(selectedUid) then
		for _, row in ipairs(weapons) do
			if row.uid == selectedUid then
				selected = row
				break
			end
		end
	end
	if selected == nil then
		selected = weapons[1]
	end
	local status = "No weapon to feed."
	local canFeed = false
	local chosen = ""
	if selected ~= nil then
		status = selected.status
		canFeed = selected.canFeed
		chosen = selected.uid
	end
	return {
		essence = essence,
		cap = ShardCore.CAP,
		weapons = weapons,
		selected = chosen,
		status = status,
		canFeed = canFeed,
	}
end

return table.freeze(ShardCore)
