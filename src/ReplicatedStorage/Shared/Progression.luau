--!strict

--[[
	Beta account level, unlocks, rest, and the XP cap.

	XP to next is 100 * level^1.6. The beta cap is 20. Every boost stack
	stops at +100%. Welcome Back and rest XP share that same cap.
]]

local Progression = {}

Progression.CAP = 20
Progression.REST_GAP = 8 * 3600
Progression.REST_CHARGES = 30 * 60
Progression.WELCOME_GAP = 14 * 86400
Progression.WELCOME_CHARGES = 3 * 3600
Progression.BOOST_CAP = 1

Progression.UNLOCKS = {
	{ level = 1, id = "class", text = "Class, rolls, pet, chest" },
	{ level = 5, id = "talent", text = "Level 5 talent and daily quests" },
	{ level = 8, id = "craft", text = "Crafting tab and chest merging" },
	{ level = 10, id = "hard", text = "Hard Rootvault" },
	{ level = 15, id = "nightmare", text = "Nightmare Rootvault and the weekly boss" },
	{ level = 20, id = "heartwood", text = "The Heartwood" },
}

function Progression.xpToNext(level: number): number
	local whole = math.floor(level)
	if whole < 1 then
		whole = 1
	end
	if whole >= Progression.CAP then
		return 0
	end
	return math.floor(100 * (whole ^ 1.6) + 0.5)
end

function Progression.unlocked(level: number): { string }
	local ids = {}
	for _, row in ipairs(Progression.UNLOCKS) do
		if level >= row.level then
			table.insert(ids, row.id)
		end
	end
	return ids
end

function Progression.boost(extra: { number }): number
	local sum = 0
	for _, part in ipairs(extra) do
		if part > 0 then
			sum += part
		end
	end
	if sum > Progression.BOOST_CAP then
		sum = Progression.BOOST_CAP
	end
	return 1 + sum
end

function Progression.addXp(data: any, amount: number): number
	if type(data) ~= "table" then
		return 0
	end
	local gain = math.max(0, math.floor(amount))
	local extras = {}
	if (data.restCharges or 0) > 0 then
		table.insert(extras, 1)
		data.restCharges = math.max(0, data.restCharges - 1)
	end
	if (data.welcomeCharges or 0) > 0 then
		table.insert(extras, 1)
		data.welcomeCharges = math.max(0, data.welcomeCharges - 1)
	end
	gain = math.floor(gain * Progression.boost(extras) + 0.5)
	data.xp = (data.xp or 0) + gain
	local levels = 0
	while data.level < Progression.CAP do
		local need = Progression.xpToNext(data.level)
		if need <= 0 or data.xp < need then
			break
		end
		data.xp -= need
		data.level += 1
		levels += 1
		if data.level % 5 == 0 then
			if type(data.chests) ~= "table" then
				data.chests = {}
			end
			data.chests.Rare = (data.chests.Rare or 0) + 1
			data.milestoneTitle = "Level " .. tostring(data.level)
		end
	end
	if data.level >= Progression.CAP then
		data.level = Progression.CAP
		data.xp = 0
	end
	return levels
end

function Progression.applyReturn(data: any, now: number)
	local seen = data.lastSeen
	if type(seen) ~= "number" or seen <= 0 then
		data.lastSeen = now
		return { rest = false, welcome = false }
	end
	local gap = now - seen
	local rest = false
	local welcome = false
	if gap >= Progression.REST_GAP then
		data.restCharges = Progression.REST_CHARGES
		rest = true
	end
	if gap >= Progression.WELCOME_GAP then
		data.welcomeCharges = Progression.WELCOME_CHARGES
		if type(data.chests) ~= "table" then
			data.chests = {}
		end
		data.chests.Rare = (data.chests.Rare or 0) + 1
		data.welcomeNote = "Welcome back. 2x XP for a while, and a Rare chest."
		welcome = true
	end
	data.lastSeen = now
	return { rest = rest, welcome = welcome }
end

function Progression.recap(
	beforeLevel: number,
	afterLevel: number,
	epics: number,
	setPct: number
): string
	return string.format(
		"This session: +%d levels, %d Epics, %d%% to your Relic Set",
		math.max(0, afterLevel - beforeLevel),
		epics,
		math.clamp(setPct, 0, 100)
	)
end

return Progression
