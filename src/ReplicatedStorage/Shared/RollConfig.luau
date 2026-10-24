--!strict

--[[
	Crack-a-Shard tunables in one place.

	Every number the roll screen, the server crack and the odds sheet
	share lives here, so balancing is a data change, not a rewrite.
	RarityConfig re-exports the timing and pity fields under their old
	names, so older callers keep reading the same values.

	Economy (approved by Kevin, Oct 19 2026):
	  * x10 costs 10% less than ten singles. One crack is SINGLE_COST
	    Shard Tokens, so x10 is 9 tokens instead of 10.

	Pity (Phase 1.3, Echo's economy rev 2, Kevin Oct 22 2026):
	  * One free, visible meter: Legendary is guaranteed by roll
	    LEGENDARY_PITY (150). It is per player, saved in the existing
	    sinceLegendary field, never sold, and any Legendary or better
	    (natural, soft or forced) resets it. The numbers come from
	    Config/Rarities.PITY.legendary.
	  * There is no Epic pity any more. Old saves still carry sinceEpic;
	    nothing reads or writes it, so it is ignored harmlessly.

	Nothing here costs Robux. No clock, no RNG, no services.
]]

local V1 = require("./Config/Rarities")

local RollConfig = {}

-- Cost ----------------------------------------------------------------
RollConfig.SINGLE_COST = 1
RollConfig.MULTI_COUNT = 10
RollConfig.MULTI_DISCOUNT = 0.10
RollConfig.MAX_BATCH = 10

-- Pity and luck --------------------------------------------------------
RollConfig.LEGENDARY_PITY = V1.PITY.legendary.hard
-- Soft pity: from roll SOFT_FROM + 1 each roll adds SOFT_STEP (absolute)
-- to the Legendary chance, so roll 101 is about 2.1% and 125 about 50%.
RollConfig.SOFT_FROM = V1.PITY.legendary.softFrom
RollConfig.SOFT_STEP = V1.PITY.legendary.softStep
RollConfig.BONUS_EVERY = 10
-- The meter glows "close" once this share of the bar is left.
RollConfig.NEAR_SHARE = 0.1

-- Server pacing and reveal timings (seconds) ---------------------------
RollConfig.COOLDOWN = 0.6
RollConfig.QUICK_COOLDOWN = 1.0
RollConfig.BOUNCE = 0.15
RollConfig.REEL = 1.45
RollConfig.LAND = 0.4
RollConfig.CARD = 0.6
RollConfig.EPIC_EXTRA = 0.5
RollConfig.QUICK_POP = 0.25
RollConfig.LEGENDARY_SCENE = 1.5
RollConfig.MYTHIC_SCENE = 3
RollConfig.SKIP_AFTER = 1
RollConfig.SHAKE = 0.3
RollConfig.AUTO_DISMISS = 1.5

-- Roll screen layout (pixels). A and D in Kevin's Oct 19 build.
RollConfig.PHONE_PAGE_W = 420 -- page width at or under this uses the D stack
RollConfig.CTA_H = 64 -- desktop CRACK row height
RollConfig.PHONE_CRACK_H = 60 -- phone full-width CRACK
RollConfig.PHONE_ROW_H = 44 -- phone x10 / AUTO / ODDS row (touch minimum)
RollConfig.CRACK_SHARE = 0.56 -- desktop CRACK share of the row
RollConfig.TEN_SHARE = 0.24 -- desktop x10 share of the row
RollConfig.METER_H = 26 -- one meter line
RollConfig.EDGE = 8 -- page padding
RollConfig.GAP = 8 -- gap between CTA pieces

local function whole(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	if value < 0 then
		return 0
	end
	return math.floor(value)
end

-- Tokens for `count` cracks bought as one press. Exactly MULTI_COUNT gets
-- the discount; any other count is plain singles. Never below one crack.
function RollConfig.cost(count: any): number
	local n = whole(count)
	if n < 1 then
		return 0
	end
	local full = n * RollConfig.SINGLE_COST
	if n == RollConfig.MULTI_COUNT then
		local discounted = math.floor(full * (1 - RollConfig.MULTI_DISCOUNT) + 0.5)
		return math.max(RollConfig.SINGLE_COST, discounted)
	end
	return full
end

function RollConfig.multiCost(): number
	return RollConfig.cost(RollConfig.MULTI_COUNT)
end

-- Tokens saved by the x10 press versus ten singles.
function RollConfig.savings(count: any): number
	local n = whole(count)
	return n * RollConfig.SINGLE_COST - RollConfig.cost(n)
end

-- The tag on the x10 button, e.g. "-10%".
function RollConfig.discountTag(): string
	return string.format("-%d%%", math.floor(RollConfig.MULTI_DISCOUNT * 100 + 0.5))
end

function RollConfig.needText(count: any): string
	return string.format("Need %d shards", RollConfig.cost(count))
end

-- A batch must fit both the wallet and the Bag before anything is spent.
-- Returns nil when the press can go ahead, otherwise the reason to show.
function RollConfig.batchBlock(tokens: any, freeSlots: any, count: any): string?
	local n = whole(count)
	if n < 1 then
		return "Pick 1 to 10 cracks."
	end
	if whole(tokens) < RollConfig.cost(n) then
		return RollConfig.needText(n)
	end
	if whole(freeSlots) < n then
		return string.format("Bag needs %d free slots.", n)
	end
	return nil
end

-- Rolls left before the free Legendary guarantee fires. 1 means the
-- next roll is guaranteed Legendary or better.
function RollConfig.pityLeft(sinceLegendary: any): number
	local left = RollConfig.LEGENDARY_PITY - whole(sinceLegendary)
	if left < 1 then
		return 1
	end
	return left
end

function RollConfig.pityText(sinceLegendary: any): string
	local left = RollConfig.pityLeft(sinceLegendary)
	if left == 1 then
		return "Legendary guaranteed next roll"
	end
	return string.format("Legendary guaranteed in %d", left)
end

-- 0..1 fill for the pity bar.
function RollConfig.pityFill(sinceLegendary: any): number
	local since = math.min(whole(sinceLegendary), RollConfig.LEGENDARY_PITY)
	return since / RollConfig.LEGENDARY_PITY
end

-- Extra Legendary chance (0..1, absolute) on the next roll from soft
-- pity. 0 until roll SOFT_FROM + 1.
function RollConfig.softBonus(sinceLegendary: any): number
	local past = whole(sinceLegendary) + 1 - RollConfig.SOFT_FROM
	if past <= 0 then
		return 0
	end
	return math.min(1, past * RollConfig.SOFT_STEP)
end

return table.freeze(RollConfig)
