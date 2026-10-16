--!strict

--[[
	Graphics tiers for phones and desktops.

	Low is the touch default. It keeps fewer particles and trim props, a
	shorter view distance, less fog and bloom, and no decor shadows. Small
	parts never cast shadows on any tier. The client hides trim locally so
	one player's Low setting does not delete the world for everyone else.
]]

local Quality = {}

Quality.MIN_TAP = 44
Quality.THUMB = 64

export type Tier = {
	id: string,
	label: string,
	particleScale: number,
	particleBudget: number,
	partBudget: number,
	decorKeep: number,
	fogEnd: number,
	bloom: number,
	lodHideAt: number,
	lodFar: number,
	decorShadows: boolean,
}

local TIERS: { [string]: Tier } = {
	low = {
		id = "low",
		label = "Low",
		particleScale = 0.2,
		particleBudget = 16,
		partBudget = 120,
		decorKeep = 0.34,
		fogEnd = 480,
		bloom = 0.08,
		lodHideAt = 42,
		lodFar = 80,
		decorShadows = false,
	},
	med = {
		id = "med",
		label = "Med",
		particleScale = 0.55,
		particleBudget = 64,
		partBudget = 200,
		decorKeep = 0.67,
		fogEnd = 320,
		bloom = 0.28,
		lodHideAt = 90,
		lodFar = 160,
		decorShadows = false,
	},
	high = {
		id = "high",
		label = "High",
		particleScale = 1,
		particleBudget = 180,
		partBudget = 320,
		decorKeep = 1,
		fogEnd = 240,
		bloom = 0.45,
		lodHideAt = 150,
		lodFar = 260,
		decorShadows = true,
	},
}

function Quality.normalize(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local id = string.lower(value)
	if TIERS[id] == nil then
		return nil
	end
	return id
end

function Quality.get(id: string): Tier
	local tier = TIERS[Quality.normalize(id) or "med"]
	return tier
end

function Quality.label(id: string): string
	return Quality.get(id).label
end

-- A saved tier wins. An empty save uses Low on a touch device and Med elsewhere.
function Quality.resolve(saved: any, touchDevice: boolean): string
	local known = Quality.normalize(saved)
	if known ~= nil then
		return known
	end
	if touchDevice then
		return "low"
	end
	return "med"
end

function Quality.touchDevice(touchEnabled: boolean, preferred: string?): boolean
	if preferred == "touch" then
		return true
	end
	return touchEnabled == true
end

function Quality.keepDecor(index: number, id: string): boolean
	local tier = Quality.get(id)
	if tier.decorKeep >= 1 then
		return true
	end
	if tier.decorKeep <= 0 or index < 1 then
		return false
	end
	return ((index * 17) % 100) < math.floor(tier.decorKeep * 100 + 0.5)
end

function Quality.shownTrim(total: number, id: string): number
	local tier = Quality.get(id)
	local shown = 0
	local count = if type(total) == "number" then math.floor(total) else 0
	for index = 1, math.max(0, count) do
		if Quality.keepDecor(index, id) then
			shown += 1
			if shown >= tier.partBudget then
				break
			end
		end
	end
	return shown
end

function Quality.particleRate(base: number, id: string): number
	local tier = Quality.get(id)
	local scaled = math.floor((base * tier.particleScale) + 0.5)
	if scaled < 0 then
		return 0
	end
	return scaled
end

function Quality.particleEnabled(index: number, id: string): boolean
	return index >= 1 and index <= Quality.get(id).particleBudget
end

function Quality.castShadow(lod: string, id: string): boolean
	if lod == "small" then
		return false
	end
	return Quality.get(id).decorShadows
end

function Quality.ids(): { string }
	return { "low", "med", "high" }
end

-- Landmarks stay on every tier, at any distance. Trim only drops cosmetic extras.
local LANDMARKS = {
	Waystone = true,
	WaystoneCrystal = true,
	Waterfall = true,
	FallLip = true,
	Anvil = true,
	ForgeBasin = true,
	ForgeFlame = true,
	SkyShard = true,
	LumenHeart = true,
	CrystalShard = true,
	OrbitShard = true,
	LightBeam = true,
}

function Quality.alwaysVisible(name: string?, waystoneId: any, ancestors: { string }?): boolean
	if type(waystoneId) == "string" and waystoneId ~= "" then
		return true
	end
	if type(name) == "string" and LANDMARKS[name] == true then
		return true
	end
	if type(ancestors) == "table" then
		for _, ancestor in ipairs(ancestors) do
			if ancestor == "Townsfolk" or ancestor == "LumenHeart" then
				return true
			end
		end
	end
	return false
end

-- hide, next trim index, next shown count. Landmarks never hide.
function Quality.lodHide(
	name: string?,
	waystoneId: any,
	ancestors: { string }?,
	keep: boolean,
	lod: any,
	trimAttr: boolean,
	distance: number,
	tierId: string,
	trimIndex: number,
	shown: number
): (boolean, number, number)
	if keep == true or Quality.alwaysVisible(name, waystoneId, ancestors) then
		return false, trimIndex, shown
	end
	local trim = trimAttr == true or lod == "small"
	local tagged = type(lod) == "string" or trim
	if not tagged then
		return false, trimIndex, shown
	end
	local tier = Quality.get(tierId)
	if trim then
		local index = trimIndex + 1
		local kept = Quality.keepDecor(index, tierId) and shown < tier.partBudget
		if not kept then
			return true, index, shown
		end
		local limit = if lod == "small" then tier.lodHideAt else tier.lodFar
		return distance > limit, index, shown + 1
	end
	if lod == "large" then
		return distance > tier.lodFar, trimIndex, shown
	end
	return false, trimIndex, shown
end

-- True only when the client will actually draw the part. A Transparency of 1,
-- a LocalTransparencyModifier near 1, a part that is not under Workspace, or
-- a part sitting off the hub (the void under the islands) does not count.
function Quality.drawn(
	transparency: number,
	modifier: number,
	inWorkspace: boolean,
	y: number?
): boolean
	if inWorkspace ~= true then
		return false
	end
	if type(transparency) ~= "number" or transparency ~= transparency then
		return false
	end
	if type(modifier) ~= "number" or modifier ~= modifier then
		return false
	end
	if transparency < 0 or transparency >= 0.95 then
		return false
	end
	if modifier < 0 or modifier >= 0.5 then
		return false
	end
	if y ~= nil then
		if type(y) ~= "number" or y ~= y or y < 90 or y > 280 then
			return false
		end
	end
	return true
end

-- An NPC counts only when a real body-sized part is drawn. A 1-stud limb
-- with Transparency 0 is not a visible character.
function Quality.modelShown(
	transparency: number,
	modifier: number,
	inWorkspace: boolean,
	y: number?,
	longest: number
): boolean
	if not Quality.drawn(transparency, modifier, inWorkspace, y) then
		return false
	end
	return type(longest) == "number" and longest == longest and longest >= 4
end

return Quality
