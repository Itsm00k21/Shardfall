--!strict

--[[
	V1 rarity ladder: 5 tiers (ROADMAP 1.3, Echo's economy sheet rev 2,
	docs/research/economy_v1.md section 3a on PR #369).

	Data only. The live game still rolls on the 7-tier ladder in
	Shared/Rarities + Shared/RarityConfig. Phase 1.3 switches the roll over.

	oneIn is checked rarest first. The commonest tier absorbs whatever is
	left, so Common's 1/2 is the remainder, not a separate check.

	Tier ids match the live ladder, so saved items keep their rarity.
	Mythic and Secret are reserved ids: in V1 they fold into Legendary and
	stay free for later content. Never reuse them for something else.
]]

local Rarities = {}

Rarities.VERSION = "v1"

Rarities.ORDER = table.freeze({ "Common", "Uncommon", "Rare", "Epic", "Legendary" })

Rarities.TIERS = table.freeze({
	Common = table.freeze({ id = "Common", rank = 1, oneIn = 2, remainder = true }),
	Uncommon = table.freeze({ id = "Uncommon", rank = 2, oneIn = 4, remainder = false }),
	Rare = table.freeze({ id = "Rare", rank = 3, oneIn = 15, remainder = false }),
	Epic = table.freeze({ id = "Epic", rank = 4, oneIn = 100, remainder = false }),
	Legendary = table.freeze({ id = "Legendary", rank = 5, oneIn = 1000, remainder = false }),
})

-- Free, never sold. Epic keeps the live 50 (RollConfig.EPIC_PITY).
-- Legendary: guaranteed by roll 150. From roll 101 on, each roll adds
-- softStep (absolute) to the Legendary chance: roll 101 ~2.1%, roll 125
-- ~50%, roll 150 guaranteed.
Rarities.PITY = table.freeze({
	epic = table.freeze({ id = "epic", tier = "Epic", hard = 50 }),
	legendary = table.freeze({
		id = "legendary",
		tier = "Legendary",
		hard = 150,
		softFrom = 100,
		softStep = 0.02,
	}),
})

-- Live 7-tier ids that fold into a V1 tier. Reserved; do not reuse.
Rarities.FOLD = table.freeze({
	Mythic = "Legendary",
	Secret = "Legendary",
})

return table.freeze(Rarities)
