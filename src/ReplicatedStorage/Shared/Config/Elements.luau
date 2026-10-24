--!strict

--[[
	V1 elements (ROADMAP 2.3). Each element scales two stats. Data only;
	Phase 2.3 adds the element tag to items and applies the scaling.

	Stat ids match Shared/Stats DEFS. "luck" is not a gear stat yet;
	Phase 2.3 adds it.

	Ember, Frost and Void must stay close in value (ROADMAP balance rule).
	The ids match the live realm ids in Shared/Drops and Shared/Pools.

	`color` is the enemy glow. `GLOW` is how strong that glow is. The
	server reads both and applies them only while LaunchGate.elementGlow
	is on. Nothing here is saved, and nothing costs Robux.

	The numbers are for a phone at crawl zoom (Dungeons.CAMERA_MAX_ZOOM,
	18 studs) on wave 4, including Low graphics, where bloom is eased.
	A strong highlight fill, a solid outline, and a light that still
	reaches that camera. The three colors stay far apart so the three
	wave-4 enemies can be told apart at that size.
]]

local Elements = {}

Elements.ORDER = table.freeze({ "ember", "frost", "void" })

Elements.LIST = table.freeze({
	ember = table.freeze({
		id = "ember",
		name = "Ember",
		stats = table.freeze({ "damage", "crit_chance" }),
		color = table.freeze({ 255, 112, 36 }),
	}),
	frost = table.freeze({
		id = "frost",
		name = "Frost",
		stats = table.freeze({ "health", "defense" }),
		color = table.freeze({ 92, 214, 255 }),
	}),
	void = table.freeze({
		id = "void",
		name = "Void",
		stats = table.freeze({ "attack_speed", "luck" }),
		color = table.freeze({ 196, 92, 255 }),
	}),
})

-- Highlight and point light. `lightRange` stays above crawl max zoom so
-- the color still reaches a phone camera pulled all the way out.
Elements.GLOW = table.freeze({
	name = "ElementGlow",
	lightName = "ElementGlowLight",
	fillTransparency = 0.28,
	outlineTransparency = 0,
	lightBrightness = 3,
	lightRange = 22,
	depthMode = "AlwaysOnTop",
})

return table.freeze(Elements)
