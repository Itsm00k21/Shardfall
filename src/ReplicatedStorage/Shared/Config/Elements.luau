--!strict

--[[
	V1 elements (ROADMAP 2.3). Each element scales two stats. Data only;
	Phase 2.3 adds the element tag to items and applies the scaling.

	Stat ids match Shared/Stats DEFS. "luck" is not a gear stat yet;
	Phase 2.3 adds it.

	Ember, Frost and Void must stay close in value (ROADMAP balance rule).
	The ids match the live realm ids in Shared/Drops and Shared/Pools.
]]

local Elements = {}

Elements.ORDER = table.freeze({ "ember", "frost", "void" })

Elements.LIST = table.freeze({
	ember = table.freeze({
		id = "ember",
		name = "Ember",
		stats = table.freeze({ "damage", "crit_chance" }),
	}),
	frost = table.freeze({
		id = "frost",
		name = "Frost",
		stats = table.freeze({ "health", "defense" }),
	}),
	void = table.freeze({
		id = "void",
		name = "Void",
		stats = table.freeze({ "attack_speed", "luck" }),
	}),
})

return table.freeze(Elements)
