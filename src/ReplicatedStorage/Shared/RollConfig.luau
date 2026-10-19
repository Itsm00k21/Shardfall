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
	  * A free, visible pity meter guarantees Epic or better after
	    EPIC_PITY cracks without one. It is per player, saved in the
	    existing sinceEpic field, never sold, and any Epic+ (natural or
	    forced) resets it.

	Why EPIC_PITY = 50: genre roll games put their first guaranteed tier
	at 50 (Anime Defenders and Anime Vanguards both guarantee Legendary at
	50; Anime Last Stand at 60). Shardfall's natural Epic+ chance is about
	0.44% a crack (0.48% with the x2 tenth roll), so only about 1 player in
	5 meets Epic+ naturally inside 50. The guarantee is the real promise,
	and 50 is exactly five x10 cracks, which reads cleanly on the meter.

	Nothing here costs Robux. No clock, no RNG, no services.
]]

local RollConfig = {}

-- Cost ----------------------------------------------------------------
RollConfig.SINGLE_COST = 1
RollConfig.MULTI_COUNT = 10
RollConfig.MULTI_DISCOUNT = 0.10
RollConfig.MAX_BATCH = 10

-- Pity and luck --------------------------------------------------------
RollConfig.EPIC_PITY = 50
RollConfig.LEGENDARY_PITY = 1000
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

-- Cracks left before the free Epic+ guarantee fires. 1 means the next
-- crack is guaranteed Epic or better.
function RollConfig.pityLeft(sinceEpic: any): number
	local left = RollConfig.EPIC_PITY - whole(sinceEpic)
	if left < 1 then
		return 1
	end
	return left
end

function RollConfig.pityText(sinceEpic: any): string
	return string.format("Epic+ guaranteed in %d", RollConfig.pityLeft(sinceEpic))
end

-- 0..1 fill for the pity bar.
function RollConfig.pityFill(sinceEpic: any): number
	local since = math.min(whole(sinceEpic), RollConfig.EPIC_PITY)
	return since / RollConfig.EPIC_PITY
end

return table.freeze(RollConfig)
