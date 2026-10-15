--!strict

--[[
	Shard pools. A pool is the list of things one shard can crack into.

	Weights are relative, not percentages. The starter pool sums to 10_000 on
	purpose, so at 0 Shard Luck the chance is weight / 100 percent. Luck and
	pity both change the real chance; the published odds table is computed by
	RollMath from these same weights.

	PLACEHOLDER ODDS. Every number below is a stand-in so the game can be
	playtested. Change them before anyone pays for a roll, and keep the
	in-game odds (RollMath.odds) in sync — they read this table, so editing
	here is enough.
]]

local Pools = {}

Pools.STARTER_ID = "starter_shard"

export type PoolEntry = {
	templateId: string,
	name: string,
	rarity: string,
	weight: number,
	kind: "Weapon" | "Pet" | "Material",
}

export type Pool = {
	id: string,
	name: string,
	pityLegendaryAt: number,
	placeholder: boolean,
	public: boolean,
	entries: { PoolEntry },
}

local starter: Pool = {
	id = Pools.STARTER_ID,
	name = "Starter Shard",
	-- The roll that would make rollsSinceLegendary hit this number is forced
	-- to Legendary or better. 50 is a placeholder.
	pityLegendaryAt = 50,
	placeholder = true,
	-- RollService rejects pools that are not public, so a future dev-only
	-- pool can live in this file without being callable from the client.
	public = true,
	entries = {
		-- Common — 60% at 0 luck (6000 / 10000)
		{
			templateId = "splinter",
			name = "Splinter",
			rarity = "Common",
			weight = 3500,
			kind = "Material",
		},
		{
			templateId = "wooden_sword",
			name = "Wooden Sword",
			rarity = "Common",
			weight = 2500,
			kind = "Weapon",
		},
		-- Uncommon — 25%
		{
			templateId = "training_pup",
			name = "Training Pup",
			rarity = "Uncommon",
			weight = 1500,
			kind = "Pet",
		},
		{
			templateId = "hunter_knife",
			name = "Hunter Knife",
			rarity = "Uncommon",
			weight = 1000,
			kind = "Weapon",
		},
		-- Rare — 10%
		{
			templateId = "storm_finch",
			name = "Storm Finch",
			rarity = "Rare",
			weight = 400,
			kind = "Pet",
		},
		{
			templateId = "arc_blade",
			name = "Arc Blade",
			rarity = "Rare",
			weight = 600,
			kind = "Weapon",
		},
		-- Epic — 4%
		{
			templateId = "void_kitten",
			name = "Void Kitten",
			rarity = "Epic",
			weight = 150,
			kind = "Pet",
		},
		{
			templateId = "grave_lance",
			name = "Grave Lance",
			rarity = "Epic",
			weight = 250,
			kind = "Weapon",
		},
		-- Legendary — 0.80%
		{
			templateId = "dawn_wolf",
			name = "Dawn Wolf",
			rarity = "Legendary",
			weight = 30,
			kind = "Pet",
		},
		{
			templateId = "oathbreaker",
			name = "Oathbreaker",
			rarity = "Legendary",
			weight = 50,
			kind = "Weapon",
		},
		-- Mythic — 0.18%
		{
			templateId = "ember_phoenix",
			name = "Ember Phoenix",
			rarity = "Mythic",
			weight = 8,
			kind = "Pet",
		},
		{
			templateId = "kingfall",
			name = "Kingfall",
			rarity = "Mythic",
			weight = 10,
			kind = "Weapon",
		},
		-- Secret — 0.02%
		{
			templateId = "unnamed_edge",
			name = "The Unnamed Edge",
			rarity = "Secret",
			weight = 2,
			kind = "Weapon",
		},
	},
}

local byId: { [string]: Pool } = {
	[starter.id] = starter,
}

for _, pool in pairs(byId) do
	for _, entry in ipairs(pool.entries) do
		table.freeze(entry)
	end
	table.freeze(pool.entries)
	table.freeze(pool)
end

function Pools.get(poolId: string): Pool?
	return byId[poolId]
end

function Pools.all(): { Pool }
	local list = {}
	for _, pool in pairs(byId) do
		table.insert(list, pool)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

return Pools
