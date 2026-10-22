--!strict

--[[
	Player-facing V1 text that other config refers to by id. Data only.
	Live UI text still sits in its own modules (for example LoadingTips);
	screens move here as each phase rebuilds them.

	Keys are stable ids. Change the text freely; never rename a key.
]]

local Strings = {}

local function entry(id: string, text: string)
	return table.freeze({ id = id, text = text })
end

Strings.LIST = table.freeze({
	currency_roll_tokens = entry("currency_roll_tokens", "Roll Tokens"),

	difficulty_normal = entry("difficulty_normal", "Normal"),
	difficulty_medium = entry("difficulty_medium", "Medium"),
	difficulty_hard = entry("difficulty_hard", "Hard"),
	difficulty_nightmare = entry("difficulty_nightmare", "Nightmare"),
	difficulty_insane = entry("difficulty_insane", "Insane"),

	element_ember = entry("element_ember", "Ember"),
	element_frost = entry("element_frost", "Frost"),
	element_void = entry("element_void", "Void"),

	rarity_common = entry("rarity_common", "Common"),
	rarity_uncommon = entry("rarity_uncommon", "Uncommon"),
	rarity_rare = entry("rarity_rare", "Rare"),
	rarity_epic = entry("rarity_epic", "Epic"),
	rarity_legendary = entry("rarity_legendary", "Legendary"),

	pity_legendary = entry("pity_legendary", "Legendary guaranteed in %d rolls"),
})

return table.freeze(Strings)
