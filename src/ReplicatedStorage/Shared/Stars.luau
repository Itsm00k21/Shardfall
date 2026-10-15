--!strict

--[[
	Duplicate feed. A kept item absorbs another copy of the same catalog id.

	Progress toward the next star is 0 to 1. A feeder contributes
	`feedValue(quality)`: 34% of a star at 0% quality, a full star at 100%.
	Five stars is the cap. Leftover progress at ★5 is dropped.

	Each star multiplies the rolled stats by a fixed percent. The unstarred
	roll is stored on each stat as `baseValue`, so feeding again does not
	compound. ★3 unlocks Starforged and ★5 unlocks Ascendant. Those perks
	are placeholders.

	STAT_PER_STAR, MIN_FEED, and MAX_FEED are the tuning knobs.
]]

local Stats = require("./Stats")

local Stars = {}

Stars.MAX = 5
-- +8% of the rolled stat per star. ★2 is ×1.16, not 1.08 × 1.08.
Stars.STAT_PER_STAR = 0.08
Stars.MIN_FEED = 0.34
Stars.MAX_FEED = 1
Stars.PERK_STARFORGED = "starforged"
Stars.PERK_ASCENDANT = "ascendant"

export type FeedPreview = {
	stars: number,
	starProgress: number,
	gained: number,
	feed: number,
	perks: { string },
	multiplier: number,
}

local function cleanStars(stars: any): number
	local count = 0
	if type(stars) == "number" and stars == stars then
		count = math.floor(stars)
	end
	if count < 0 then
		count = 0
	elseif count > Stars.MAX then
		count = Stars.MAX
	end
	return count
end

local function cleanProgress(progress: any, stars: number): number
	if stars >= Stars.MAX then
		return 0
	end
	local value = 0
	if type(progress) == "number" and progress == progress then
		value = progress
	end
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

function Stars.multiplier(stars: any): number
	return 1 + cleanStars(stars) * Stars.STAT_PER_STAR
end

function Stars.feedValue(quality: any): number
	local q = 0
	if type(quality) == "number" and quality == quality then
		q = quality
	end
	if q < 0 then
		q = 0
	elseif q > 1 then
		q = 1
	end
	return Stars.MIN_FEED + (Stars.MAX_FEED - Stars.MIN_FEED) * q
end

function Stars.formatProgress(progress: number): string
	local percent = progress * 100
	if percent ~= percent then
		percent = 0
	end
	local rounded = math.floor(percent + 0.5)
	if rounded < 0 then
		rounded = 0
	elseif rounded > 100 then
		rounded = 100
	end
	return string.format("%d%%", rounded)
end

function Stars.perkIds(stars: any): { string }
	local count = cleanStars(stars)
	local ids = {}
	if count >= 3 then
		table.insert(ids, Stars.PERK_STARFORGED)
	end
	if count >= 5 then
		table.insert(ids, Stars.PERK_ASCENDANT)
	end
	return ids
end

function Stars.perkName(id: string): string
	if id == Stars.PERK_STARFORGED then
		return "Starforged"
	end
	if id == Stars.PERK_ASCENDANT then
		return "Ascendant"
	end
	return id
end

-- Writes `value` from `baseValue` times the star multiplier. The first call
-- remembers the current value as the base so later feeds do not compound.
function Stars.applyStats(item: any)
	if type(item) ~= "table" or type(item.stats) ~= "table" then
		return
	end
	local mult = Stars.multiplier(item.stars)
	for _, stat in ipairs(item.stats) do
		if type(stat) == "table" then
			local base = stat.baseValue
			if type(base) ~= "number" or base ~= base then
				base = stat.value
			end
			if type(base) == "number" and base == base then
				stat.baseValue = base
				stat.value = base * mult
			end
		end
	end
end

function Stars.canFeed(kept: any, feeder: any): (boolean, string?)
	if type(kept) ~= "table" or type(feeder) ~= "table" then
		return false, "You do not have that item."
	end
	if type(kept.uid) ~= "string" or kept.uid == feeder.uid then
		return false, "Pick a duplicate to feed."
	end
	if type(kept.templateId) ~= "string" or kept.templateId ~= feeder.templateId then
		return false, "Feed a duplicate of the same item."
	end
	if cleanStars(kept.stars) >= Stars.MAX then
		return false, "That item is already at five stars."
	end
	return true, nil
end

function Stars.advance(stars: any, progress: any, quality: any): (FeedPreview?, string?)
	local current = cleanStars(stars)
	if current >= Stars.MAX then
		return nil, "That item is already at five stars."
	end
	local feed = Stars.feedValue(quality)
	local nextProgress = cleanProgress(progress, current) + feed
	local nextStars = current
	local gained = 0
	while nextProgress >= 1 and nextStars < Stars.MAX do
		nextProgress -= 1
		nextStars += 1
		gained += 1
	end
	if nextStars >= Stars.MAX then
		nextProgress = 0
	end
	return {
		stars = nextStars,
		starProgress = nextProgress,
		gained = gained,
		feed = feed,
		perks = Stars.perkIds(nextStars),
		multiplier = Stars.multiplier(nextStars),
	},
		nil
end

-- Mutates `kept`. Does not remove the feeder; the caller does that after
-- this returns, so a rejected feed leaves both items in the bag.
function Stars.commit(kept: any, feeder: any): (FeedPreview?, string?)
	local allowed, why = Stars.canFeed(kept, feeder)
	if not allowed then
		return nil, why
	end
	local preview, reason = Stars.advance(kept.stars, kept.starProgress, feeder.quality)
	if preview == nil then
		return nil, reason
	end
	kept.stars = preview.stars
	kept.starProgress = preview.starProgress
	kept.perks = preview.perks
	Stars.applyStats(kept)
	return preview, nil
end

function Stars.confirmText(
	kept: any,
	feeder: any,
	preview: FeedPreview,
	feederEquipped: boolean
): string
	local quality = "no quality"
	if type(feeder.quality) == "number" then
		quality = Stats.formatQuality(feeder.quality)
	end
	local beforeStars = cleanStars(kept.stars)
	local beforeProgress = cleanProgress(kept.starProgress, beforeStars)
	local lines = {
		string.format("Feed %s (%s) into %s.", tostring(feeder.name), quality, tostring(kept.name)),
		string.format(
			"★%d  %s  →  ★%d  %s",
			beforeStars,
			Stars.formatProgress(beforeProgress),
			preview.stars,
			Stars.formatProgress(preview.starProgress)
		),
		string.format(
			"Stats ×%.2f  (+%d%% each star)",
			preview.multiplier,
			math.floor(Stars.STAT_PER_STAR * 100 + 0.5)
		),
	}
	if beforeStars < 3 and preview.stars >= 3 then
		table.insert(lines, "Unlocks Starforged. Placeholder perk.")
	end
	if beforeStars < 5 and preview.stars >= 5 then
		table.insert(lines, "Unlocks Ascendant. Placeholder perk.")
	end
	if feederEquipped then
		table.insert(lines, "The feeder is equipped. It will be unequipped and consumed.")
	else
		table.insert(lines, "The feeder is consumed.")
	end
	return table.concat(lines, "\n")
end

return Stars
