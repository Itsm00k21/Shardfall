--!strict

--[[
	Rarity ladder for Shardfall.

	Colors are stored as 0-255 channels, not Color3, so this module can run
	inside Studio and inside the Lune test runner. The client turns them into
	Color3. Secret is white here and drawn as a moving rainbow in the UI.
]]

local Rarities = {}

export type RarityName = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

Rarities.ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local index: { [string]: number } = {}
for rank, name in ipairs(Rarities.ORDER) do
	index[name] = rank
end
Rarities.INDEX = index

-- Luck does not multiply every weight by the same amount (that would change
-- nothing). Each tier has an exponent: 0 leaves the weight alone, and higher
-- exponents gain more from the same luck stat.
-- effectiveWeight = baseWeight * (1 + luckPoints / 100) ^ exponent
-- PLACEHOLDER — tune these with the pool weights before launch.
Rarities.LUCK_EXPONENT = {
	Common = 0,
	Uncommon = 0.35,
	Rare = 0.7,
	Epic = 1.05,
	Legendary = 1.4,
	Mythic = 1.75,
	Secret = 2.1,
}

Rarities.COLOR = {
	Common = { 168, 168, 176 },
	Uncommon = { 64, 186, 98 },
	Rare = { 72, 142, 255 },
	Epic = { 186, 96, 240 },
	Legendary = { 255, 196, 64 },
	Mythic = { 230, 64, 78 },
	Secret = { 255, 255, 255 },
}

Rarities.RAINBOW = {
	Secret = true,
}

-- How many weapon traits a drop of this rarity rolls. Pets and materials
-- never roll weapon traits; see RollMath.
Rarities.TRAIT_SLOTS = {
	Common = 0,
	Uncommon = 0,
	Rare = 1,
	Epic = 1,
	Legendary = 2,
	Mythic = 2,
	Secret = 3,
}

-- Landing any of these clears the "guarantee a Legendary" pity counter.
-- Mythic and Secret count, so pity is not a downgrade from a better pull.
Rarities.PITY_RESET = {
	Legendary = true,
	Mythic = true,
	Secret = true,
}

-- The next rarity a craft can proc into. Secret is not a proc.
function Rarities.next(rarity: string): string?
	local rank = index[rarity]
	if rank == nil then
		return nil
	end
	local following = Rarities.ORDER[rank + 1]
	if following == nil or following == "Secret" then
		return nil
	end
	return following
end

function Rarities.rank(rarity: string): number
	local rank = index[rarity]
	if rank == nil then
		error("Unknown rarity '" .. rarity .. "'", 2)
	end
	return rank
end

function Rarities.isLegendaryOrBetter(rarity: string): boolean
	return Rarities.PITY_RESET[rarity] == true
end

function Rarities.rgb(rarity: string): (number, number, number)
	local color = Rarities.COLOR[rarity]
	if color == nil then
		return 255, 255, 255
	end
	return color[1], color[2], color[3]
end

function Rarities.isRainbow(rarity: string): boolean
	return Rarities.RAINBOW[rarity] == true
end

table.freeze(Rarities.ORDER)
table.freeze(Rarities.INDEX)
table.freeze(Rarities.LUCK_EXPONENT)
for _, color in pairs(Rarities.COLOR) do
	table.freeze(color)
end
table.freeze(Rarities.COLOR)
table.freeze(Rarities.RAINBOW)
table.freeze(Rarities.TRAIT_SLOTS)
table.freeze(Rarities.PITY_RESET)

return Rarities
