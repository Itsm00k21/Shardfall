--!strict

--[[
	Roll-tab numbers.

	Pity fill, the odds lines, whether auto-roll should fire again, the
	last results, and how big the celebration is. The reel still plays
	the spin. This module does not roll. A paid roll is not an input:
	pulse and payoff read only the counter the caller already has.
]]

local Rarities = require("./Rarities")
local RarityConfig = require("./RarityConfig")

local RollBoard = {}

RollBoard.HISTORY = 10
RollBoard.STOPS = { "Off", "Uncommon", "Rare", "Epic", "Legendary" }

export type Bars = {
	epic: number,
	legendary: number,
}

function RollBoard.fill(since: any, cap: number): number
	local value = if type(since) == "number" then since else 0
	if value ~= value or value < 0 then
		value = 0
	end
	if cap <= 0 then
		return 0
	end
	return math.clamp(value / cap, 0, 1)
end

-- A bar this full pulses. 0.9 is 90 of 100, and 900 of 1000.
RollBoard.NEAR = 0.9

function RollBoard.pulse(fill: any): boolean
	if type(fill) ~= "number" or fill ~= fill or fill == math.huge or fill == -math.huge then
		return false
	end
	return fill >= RollBoard.NEAR
end

-- The counter just cleared because this land met the bar's floor.
-- shown must be the server counter, not a client tally.
function RollBoard.payoff(shown: any, landed: any, floor: string): boolean
	if type(shown) ~= "number" or shown ~= 0 then
		return false
	end
	if type(landed) ~= "string" or type(floor) ~= "string" then
		return false
	end
	local landedRank = Rarities.INDEX[landed]
	local floorRank = Rarities.INDEX[floor]
	if landedRank == nil or floorRank == nil then
		return false
	end
	return landedRank >= floorRank
end

function RollBoard.bars(profile: any): Bars
	local epic = 0
	local legendary = 0
	if type(profile) == "table" then
		epic = profile.sinceEpic or 0
		legendary = profile.sinceLegendary or 0
	end
	return {
		epic = RollBoard.fill(epic, RarityConfig.EPIC_PITY),
		legendary = RollBoard.fill(legendary, RarityConfig.LEGENDARY_PITY),
	}
end

-- The draw is RarityConfig.pick / disclose, not the pool-weight table.
-- sinceLegendary stays in the signature so a pity counter cannot change
-- these lines. The hub and the reel both print RarityConfig.formatLine,
-- which keeps four decimals under 1% so a real drop is never shown as 0.0%.
-- disclose already gives the last rarity whatever remains, so the chances
-- sum to 100%. luck is a profile, or a shardLuck number with boost beside
-- it. Either way the multiplier is luckFromProfile, the same call the
-- server draw, GetOdds, and the reel use. A stored boost and vip follow
-- that path.
function RollBoard.oddsRows(
	pool: any,
	luck: any,
	boost: any,
	_sinceLegendary: any
): { { rarity: string, chance: number, text: string } }
	local rows = {}
	if type(pool) ~= "table" then
		return rows
	end
	local profile = if type(luck) == "table"
		then luck
		else {
			shardLuck = luck,
			luckBoost = boost,
		}
	local multiplier = RarityConfig.luckFromProfile(profile)
	local ok, odds = pcall(RarityConfig.disclose, pool, multiplier)
	if not ok or type(odds) ~= "table" or type(odds.rarities) ~= "table" then
		return rows
	end
	for _, row in ipairs(odds.rarities) do
		if
			type(row) == "table"
			and type(row.rarity) == "string"
			and type(row.chance) == "number"
			and type(row.oneIn) == "number"
			and row.chance > 0
		then
			table.insert(rows, {
				rarity = row.rarity,
				chance = row.chance,
				text = RarityConfig.formatLine(row),
			})
		end
	end
	return rows
end

function RollBoard.oddsLines(pool: any, luck: any, boost: any, sinceLegendary: any): { string }
	local lines = {}
	for _, row in ipairs(RollBoard.oddsRows(pool, luck, boost, sinceLegendary)) do
		table.insert(lines, row.text)
	end
	return lines
end

function RollBoard.shouldRollAgain(
	auto: boolean,
	stopAt: string,
	lastRarity: string,
	tokens: number
): boolean
	if not auto or tokens < 1 then
		return false
	end
	if stopAt == "" or stopAt == "Off" then
		return true
	end
	local stopRank = Rarities.INDEX[stopAt]
	if type(stopRank) ~= "number" then
		return false
	end
	local got = Rarities.INDEX[lastRarity]
	if type(got) ~= "number" then
		return true
	end
	return got < stopRank
end

function RollBoard.history(items: { any }, limit: number): { any }
	local copy = {}
	for _, item in ipairs(items) do
		if type(item) == "table" then
			table.insert(copy, item)
		end
	end
	table.sort(copy, function(a, b)
		local left = if type(a.obtainedAt) == "number" then a.obtainedAt else 0
		local right = if type(b.obtainedAt) == "number" then b.obtainedAt else 0
		if left ~= right then
			return left > right
		end
		return tostring(a.uid or "") < tostring(b.uid or "")
	end)
	local shown = {}
	local count = if limit > 0 then limit else 0
	for index = 1, math.min(count, #copy) do
		shown[index] = copy[index]
	end
	return shown
end

function RollBoard.celebrationScale(rarity: string): number
	local value = Rarities.INDEX[rarity]
	if type(value) ~= "number" then
		return 1
	end
	return 1 + (value - 1) * 0.08
end

function RollBoard.nextStop(current: string): string
	local index = 1
	for cursor, name in ipairs(RollBoard.STOPS) do
		if name == current then
			index = cursor
		end
	end
	return RollBoard.STOPS[(index % #RollBoard.STOPS) + 1]
end

return RollBoard
