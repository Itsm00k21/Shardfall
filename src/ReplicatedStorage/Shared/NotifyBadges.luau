--!strict

--[[
	Rail and tab badges.

	New items, an unspent level-5 talent (the profile has no stat-point
	field), a missing class, and a pass reward. A badge clears when that
	tab is viewed, and it comes back when the reason is new again.
]]

local Classes = require("./Classes")

local NotifyBadges = {}

export type Seen = {
	bagAt: number,
	classViewed: boolean,
	statViewed: boolean,
	passViewed: boolean,
}

export type Badge = {
	on: boolean,
	tip: string,
}

function NotifyBadges.blank(): Seen
	return {
		bagAt = 0,
		classViewed = false,
		statViewed = false,
		passViewed = false,
	}
end

local function classMissing(profile: any): boolean
	if type(profile) ~= "table" then
		return false
	end
	return Classes.get(profile.classId) == nil
end

-- The level-5 talent is the only unspent choice on the profile.
local function talentReady(profile: any): boolean
	if type(profile) ~= "table" then
		return false
	end
	local level = profile.level
	if type(level) ~= "number" or level < Classes.TALENT_LEVEL then
		return false
	end
	local classId = profile.classId
	if type(classId) ~= "string" or Classes.get(classId) == nil then
		return false
	end
	local talents = profile.classTalent
	if type(talents) ~= "table" then
		return true
	end
	return talents[classId] == nil
end

local function newest(profile: any): number
	local best = 0
	if type(profile) ~= "table" or type(profile.inventory) ~= "table" then
		return 0
	end
	for _, item in pairs(profile.inventory) do
		if
			type(item) == "table"
			and type(item.obtainedAt) == "number"
			and item.obtainedAt > best
		then
			best = item.obtainedAt
		end
	end
	return best
end

function NotifyBadges.prepare(seen: Seen, profile: any): Seen
	local nextSeen: Seen = {
		bagAt = seen.bagAt,
		classViewed = seen.classViewed,
		statViewed = seen.statViewed,
		passViewed = seen.passViewed,
	}
	if not classMissing(profile) then
		nextSeen.classViewed = false
	end
	if not talentReady(profile) then
		nextSeen.statViewed = false
	end
	if type(profile) ~= "table" or profile.dailyBossReady ~= true then
		nextSeen.passViewed = false
	end
	return nextSeen
end

function NotifyBadges.evaluate(profile: any, seen: Seen): { [string]: Badge }
	local ready = NotifyBadges.prepare(seen, profile)
	local missing = classMissing(profile) and not ready.classViewed
	local stat = talentReady(profile) and not ready.statViewed
	local tip = "Hero"
	if missing then
		tip = "Choose class"
	elseif stat then
		tip = "Stat points"
	end
	local bagOn = newest(profile) > ready.bagAt
	local passOn = type(profile) == "table"
		and profile.dailyBossReady == true
		and not ready.passViewed
	return {
		hero = { on = missing or stat, tip = tip },
		bag = { on = bagOn, tip = if bagOn then "New items" else "Bag" },
		pass = { on = passOn, tip = if passOn then "Pass reward" else "Shard Pass" },
	}
end

function NotifyBadges.view(seen: Seen, tab: string, profile: any): Seen
	local nextSeen = NotifyBadges.prepare(seen, profile)
	if tab == "bag" or tab == "sets" then
		nextSeen.bagAt = math.max(nextSeen.bagAt, newest(profile))
	elseif tab == "hero" then
		if classMissing(profile) then
			nextSeen.classViewed = true
		end
		if talentReady(profile) then
			nextSeen.statViewed = true
		end
	elseif tab == "pass" then
		if type(profile) == "table" and profile.dailyBossReady == true then
			nextSeen.passViewed = true
		end
	end
	return nextSeen
end

return NotifyBadges
