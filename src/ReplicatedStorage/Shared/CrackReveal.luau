--!strict

--[[
	Crack-a-shard playback.

	The server has already drawn the item. This module only times the
	shake, the crack, and the burst for that rarity. It never names a
	different rarity, and it never builds a fake near-miss.

	Epic and above hold a tension beat on the real result before the
	burst. Quick and Skip shorten the same crack. They do not skip it.
	Reduced motion is the shortest crack that still plays.
]]

local Rarities = require("./Rarities")

local CrackReveal = {}

export type Plan = {
	rarity: string,
	mode: string,
	seconds: number,
	shakeEnd: number,
	crackEnd: number,
	tensionEnd: number,
	burstEnd: number,
	flash: boolean,
	glow: boolean,
	sound: string,
}

export type Sample = {
	shake: number,
	crack: number,
	burst: number,
	glow: number,
	flash: boolean,
	tension: boolean,
	showName: boolean,
	sound: string?,
}

-- Full playback. Common and Uncommon spend about a second on the
-- shake and the crack, then burst. Rare and above hold longer.
local FULL: { [string]: number } = {
	Common = 1.4,
	Uncommon = 1.6,
	Rare = 2.2,
	Epic = 2.75,
	Legendary = 3.1,
	Mythic = 3.5,
	Secret = 3.8,
}

local function rankOf(rarity: string): number
	local rank = Rarities.INDEX[rarity]
	if type(rank) ~= "number" then
		return 1
	end
	return rank
end

function CrackReveal.mode(value: any): string
	if value == "quick" or value == "skip" or value == "reduced" or value == "full" then
		return value
	end
	return "full"
end

function CrackReveal.plan(rarity: any, mode: any): Plan
	local name = "Common"
	if type(rarity) == "string" and Rarities.INDEX[rarity] ~= nil then
		name = rarity
	end
	local picked = CrackReveal.mode(mode)
	local seconds = FULL[name] or FULL.Common
	if picked == "quick" then
		seconds = math.max(0.28, seconds * 0.45)
	elseif picked == "skip" then
		seconds = math.max(0.22, seconds * 0.32)
	elseif picked == "reduced" then
		seconds = 0.2
	end
	local rank = rankOf(name)
	local rareUp = rank >= rankOf("Rare")
	local epicUp = rank >= rankOf("Epic")
	-- Anticipation is the shake plus the spreading crack. The burst is
	-- whatever is left, and Rare and above keep more of it.
	local crackEnd = seconds * (if rareUp then 0.52 else 0.72)
	local shakeEnd = crackEnd * 0.45
	local tensionEnd = if epicUp then seconds * 0.78 else crackEnd
	return {
		rarity = name,
		mode = picked,
		seconds = seconds,
		shakeEnd = shakeEnd,
		crackEnd = crackEnd,
		tensionEnd = tensionEnd,
		burstEnd = seconds,
		flash = rareUp and picked ~= "reduced",
		glow = picked ~= "reduced",
		sound = if epicUp then "stinger" elseif rareUp then "confirm" else "click",
	}
end

function CrackReveal.sample(plan: Plan, elapsed: number): Sample
	local t = elapsed
	if type(t) ~= "number" or t ~= t or t < 0 then
		t = 0
	end
	local shake = 0
	if plan.shakeEnd > 0 and t < plan.shakeEnd then
		shake = 0.35 + 0.65 * (t / plan.shakeEnd)
	end
	local crack = 0
	if t >= plan.shakeEnd then
		local span = math.max(0.001, plan.crackEnd - plan.shakeEnd)
		crack = math.clamp((t - plan.shakeEnd) / span, 0, 1)
	end
	local tension = plan.tensionEnd > plan.crackEnd and t >= plan.crackEnd and t < plan.tensionEnd
	local burst = 0
	if t >= plan.tensionEnd then
		local span = math.max(0.001, plan.burstEnd - plan.tensionEnd)
		burst = math.clamp((t - plan.tensionEnd) / span, 0, 1)
	end
	return {
		shake = shake,
		crack = crack,
		burst = burst,
		glow = if plan.glow then math.clamp(crack * 0.35 + burst, 0, 1) else 0,
		flash = plan.flash and burst > 0 and burst < 0.4,
		tension = tension,
		showName = burst >= 0.35 or t >= plan.seconds,
		sound = if burst > 0 and burst < 0.18 then plan.sound else nil,
	}
end

return CrackReveal
