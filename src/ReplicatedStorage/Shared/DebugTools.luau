--!strict

--[[
	Studio dev actions that only change the profile.

	apply() runs the Debug remote actions and grant() runs the DevGrant
	kinds. Each returns (ok, message), and the message says what changed
	and the new total ("+1000 Gold (now 1547)."), so the owner-only Dev
	Tools panel can toast it (Kevin, Oct 22: "have no way of knowing if
	something was added").

	Teleport, boss phase and the region toggle stay in their services.
	This module is the part the tests can run without a server.
]]

local ChestConfig = require("./ChestConfig")
local Currencies = require("./Currencies")
local Materials = require("./Materials")
local Pools = require("./Pools")
local RollConfig = require("./RollConfig")

local DebugTools = {}

-- Grant Materials bundle, in the order the toast lists it.
DebugTools.MATERIALS = table.freeze({
	{ "wood", 8 },
	{ "vine", 8 },
	{ "spore", 6 },
	{ "bark", 4 },
	{ "heartwood", 2 },
	{ "verdant_bark", 12 },
	{ "gnarl_seed", 1 },
	{ "scroll_thornbound", 1 },
})

local function count(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.floor(value)
end

-- Sets the Legendary pity counter and says what the next roll does.
local function setPity(data: any, value: number): string
	local cap = RollConfig.LEGENDARY_PITY
	local before = count(data.sinceLegendary)
	local after = math.clamp(value, 0, cap - 1)
	data.sinceLegendary = after
	local tail
	if after + 1 >= cap then
		tail = "next roll is a guaranteed Legendary"
	elseif RollConfig.softBonus(after) > 0 then
		tail = string.format(
			"soft pity on: next roll +%d%% Legendary chance",
			math.floor(RollConfig.softBonus(after) * 100 + 0.5)
		)
	else
		tail = RollConfig.pityText(after)
	end
	return string.format("Legendary pity %d/%d (was %d): %s.", after, cap, before, tail)
end

-- Adds up to `amount` under `cap` and says what landed.
local function addCapped(data: any, field: string, amount: number, cap: number?, name: string): string
	local before = count(data[field])
	local after = before + amount
	if cap ~= nil and after > cap then
		after = math.max(before, cap)
	end
	data[field] = after
	local gained = after - before
	if gained <= 0 then
		return string.format("%s already at the cap (%d).", name, after)
	end
	return string.format("+%d %s (now %d).", gained, name, after)
end

function DebugTools.apply(data, action: string): (boolean, string)
	if action == "level" then
		local before = count(data.level)
		data.level = 20
		data.xp = 0
		return true, string.format("Level 20 (was %d).", before)
	end
	if action == "gold" then
		return true, addCapped(data, "gold", 1000, nil, "Gold")
	end
	if action == "keys" then
		return true, addCapped(data, "shardKeys", 20, nil, "Shard Keys")
	end
	if action == "gems" then
		return true, addCapped(data, "gems", 50, nil, "Gems")
	end
	if action == "dust" then
		return true, addCapped(data, "shardDust", 50, nil, "Shard Dust")
	end
	if action == "tokens" then
		return true, addCapped(data, "eventTokens", 10, nil, "Event Tokens")
	end
	if action == "chest" then
		if type(data.chests) ~= "table" then
			data.chests = {}
		end
		data.chests.Rare = count(data.chests.Rare) + 1
		return true, string.format("+1 Rare chest (now %d).", data.chests.Rare)
	end
	if action == "eggs" then
		return true, addCapped(data, "eggs", 1, nil, "Egg")
	end
	return false, "Unknown debug action."
end

function DebugTools.grant(data, kind: string, now: number): (boolean, string)
	if kind == "tokens" then
		return true, addCapped(data, "shardTokens", 5, 9999, "Shards")
	end
	if kind == "tokens100" then
		return true, addCapped(data, "shardTokens", 100, 9999, "Shards")
	end
	if kind == "pity149" then
		return true, setPity(data, RollConfig.LEGENDARY_PITY - 1)
	end
	if kind == "pity120" then
		return true, setPity(data, 120)
	end
	if kind == "pity0" then
		return true, setPity(data, 0)
	end
	if kind == "prisms" then
		return true, addCapped(data, "prismTokens", 5, 9999, "Prism Tokens")
	end
	if kind == "luck" then
		return true, addCapped(data, "shardLuck", 25, 500, "Shard Luck")
	end
	if kind == "boost" then
		data.luckBoost = Currencies.LUCK_BOOST
		return true, string.format("Luck Boost on: +%d Shard Luck on rolls.", Currencies.LUCK_BOOST)
	end
	if kind == "forgeboost" then
		data.forgeBoostUntil = now + Currencies.FORGE_BOOST_SECONDS
		return true,
			string.format(
				"Forge Boost on: x%d Forge XP for %d min.",
				Currencies.FORGE_BOOST_MULT,
				math.floor(Currencies.FORGE_BOOST_SECONDS / 60)
			)
	end
	if kind == "ascension" then
		local before = count(data.ascension)
		data.ascension = math.min(Pools.MAX_ASCENSION, before + 1)
		if data.ascension == before then
			return true, string.format("Ascension already at the max (%d).", before)
		end
		return true, string.format("Ascension %d -> %d (max %d).", before, data.ascension, Pools.MAX_ASCENSION)
	end
	if kind == "materials" then
		if type(data.materials) ~= "table" then
			data.materials = Materials.empty()
		end
		local parts = {}
		local total = 0
		for _, pair in ipairs(DebugTools.MATERIALS) do
			local landed = Materials.add(data.materials, pair[1], pair[2])
			if landed > 0 then
				total += landed
				table.insert(parts, string.format("%s x%d", Materials.displayName(pair[1]), landed))
			end
		end
		if total == 0 then
			return true, "Materials already at the stack cap."
		end
		return true, string.format("+%d materials (see Bag): %s.", total, table.concat(parts, ", "))
	end
	if kind == "chests" then
		ChestConfig.ensure(data)
		for _, tier in ipairs(ChestConfig.TIERS) do
			data.chests[tier] = math.min(999, count(data.chests[tier]) + 5)
		end
		data.shardKeys = math.min(99999, count(data.shardKeys) + 1000)
		data.shardDust = math.min(999999, count(data.shardDust) + 20000)
		if type(data.materials) ~= "table" then
			data.materials = Materials.empty()
		end
		data.materials.verdant_bark = count(data.materials.verdant_bark) + 20
		data.materials.heartwood = count(data.materials.heartwood) + 20
		data.materials.gnarl_seed = count(data.materials.gnarl_seed) + 6
		return true, "+5 of each chest, +1000 Keys, +20000 Dust, +46 materials."
	end
	if kind == "quick" then
		data.quickRoll = data.quickRoll ~= true
		return true, if data.quickRoll then "Quick Roll on." else "Quick Roll off."
	end
	if kind == "vip" then
		data.vip = data.vip ~= true
		return true, if data.vip then "VIP flag on (test only)." else "VIP flag off."
	end
	return false, "Unknown dev grant."
end

return DebugTools
