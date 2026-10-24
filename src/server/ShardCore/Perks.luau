--!strict

--[[
	Add Shard Core perks onto a finished Equip totals table.

	Call this after upgrade scaling, stars, elements, and base stats
	are already in the totals. The add is flat. It does not multiply
	the finished number, and it does not read item.upgrade or Stars.

	When the flag is off, the same table comes back unchanged.
	Only the equipped weapon's core counts. Pets do not.
]]

local Perks = {}

local function whole(value: any): number
	if type(value) ~= "number" or value ~= value or value <= 0 or value >= math.huge then
		return 0
	end
	return math.floor(value)
end

local function formatValue(unit: string, decimals: number, value: number): string
	local places = decimals
	if places < 0 then
		places = 0
	end
	if places > 4 then
		places = 4
	end
	if unit == "percent" then
		return string.format("%." .. tostring(places) .. "f%%", value * 100)
	end
	if places <= 0 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%." .. tostring(places) .. "f", value)
end

local function defOf(ctx: any, statId: string): any
	if type(ctx) ~= "table" or type(ctx.stats) ~= "table" or type(ctx.stats.DEFS) ~= "table" then
		return nil
	end
	local def = ctx.stats.DEFS[statId]
	if type(def) ~= "table" then
		return nil
	end
	return def
end

local function equippedWeapon(profile: any, loadout: any): string?
	if
		type(loadout) ~= "table"
		or type(profile) ~= "table"
		or type(profile.inventory) ~= "table"
	then
		return nil
	end
	local uid = loadout.weapon
	if type(uid) ~= "string" or uid == "" then
		return nil
	end
	local item = profile.inventory[uid]
	if type(item) ~= "table" or item.kind ~= "Weapon" then
		return nil
	end
	return uid
end

function Perks.apply(result: any, profile: any, loadout: any, ctx: any): any
	if type(result) ~= "table" or type(result.byId) ~= "table" or type(result.lines) ~= "table" then
		return result
	end
	if type(ctx) ~= "table" or ctx.coreEnabled ~= true or type(ctx.coreConfig) ~= "table" then
		return result
	end
	local config = ctx.coreConfig
	local uid = equippedWeapon(profile, loadout)
	if uid == nil or type(config.bonus) ~= "function" or type(config.PERKS) ~= "table" then
		return result
	end
	local level = 0
	if type(config.levelOf) == "function" then
		level = whole(config.levelOf(profile, uid))
	end
	if level <= 0 then
		return result
	end
	local indexById: { [string]: number } = {}
	for index, line in ipairs(result.lines) do
		if type(line) == "table" and type(line.id) == "string" then
			indexById[line.id] = index
		end
	end
	for _, perk in ipairs(config.PERKS) do
		if type(perk) == "table" and type(perk.id) == "string" and level >= (perk.level or 0) then
			local amount = perk.amount
			if
				type(amount) == "number"
				and amount == amount
				and amount > 0
				and amount < math.huge
			then
				local statId = perk.id
				local current = result.byId[statId]
				local base = 0
				if
					type(current) == "number"
					and current == current
					and current >= 0
					and current < math.huge
				then
					base = current
				end
				local total = base + amount
				local def = defOf(ctx, statId)
				local cap = nil
				if
					def ~= nil
					and type(def.cap) == "number"
					and def.cap == def.cap
					and def.cap >= 0
				then
					cap = def.cap
				end
				if cap ~= nil and total > cap then
					total = cap
				end
				result.byId[statId] = total
				local unit = if type(perk.unit) == "string" then perk.unit else "flat"
				local decimals = if type(perk.decimals) == "number" then perk.decimals else 0
				local name = if type(perk.name) == "string" then perk.name else statId
				if def ~= nil then
					if type(def.unit) == "string" then
						unit = def.unit
					end
					if type(def.decimals) == "number" then
						decimals = def.decimals
					end
					if type(def.name) == "string" then
						name = def.name
					end
				end
				local existing = indexById[statId]
				if existing ~= nil then
					local line = result.lines[existing]
					line.value = total
					line.text = formatValue(unit, decimals, total)
					line.fromGear = true
					line.fromCore = true
				else
					table.insert(result.lines, {
						id = statId,
						name = name,
						value = total,
						unit = unit,
						text = formatValue(unit, decimals, total),
						fromGear = true,
						fromCore = true,
					})
					indexById[statId] = #result.lines
				end
			end
		end
	end
	return result
end

return Perks
