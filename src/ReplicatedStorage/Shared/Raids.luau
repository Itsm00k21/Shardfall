--!strict

--[[
	The Heartwood, Story and Normal.

	Lockouts, Raid Marks, and bad-luck protection live on the profile.
	Reserved servers are decided by RaidService. This module only does the
	numbers, so a Studio session can run the same raid alone.
]]

local Raids = {}

Raids.MARK_CAP = 600
Raids.DROP_BASE = 0.2
Raids.DROP_STEP = 0.1
Raids.DROP_CAP = 0.8
Raids.SOLO_HP = 0.35

Raids.DIFFICULTIES = {
	story = { id = "story", level = 15, hp = 1, damage = 0.85, loot = "Rare" },
	normal = { id = "normal", level = 15, hp = 1.35, damage = 1, loot = "Epic" },
}

Raids.WINGS = {
	{ id = "twins", name = "Thornwarden Twins" },
	{ id = "sapwell", name = "Mother Sapwell" },
	{ id = "galecrown", name = "Galecrown" },
	{ id = "awakened", name = "Grandmother Gnarl Awakened" },
}

Raids.TAGS = { "Learning", "Farm", "Speedrun", "Achievement" }

Raids.SHOP = {
	rare_chest = { id = "rare_chest", marks = 80, chest = "Rare" },
	epic_chest = { id = "epic_chest", marks = 160, chest = "Epic" },
	title = { id = "title", marks = 200, title = "Heartwood Student" },
}

function Raids.difficulty(id: any)
	if type(id) == "string" then
		return Raids.DIFFICULTIES[id]
	end
	return nil
end

function Raids.weekNumber(now: number): number
	return math.floor(now / (86400 * 7))
end

function Raids.roleOk(classId: any, role: any): (boolean, string)
	if role == "flex" then
		return true, ""
	end
	if type(classId) ~= "string" or classId == "" then
		return false, "Pick a class at the Forge first."
	end
	if role == "tank" and classId == "warden" then
		return true, ""
	end
	if role == "healer" and classId == "tidecaller" then
		return true, ""
	end
	if role == "dps" then
		return true, ""
	end
	return false, "That class does not fill that role. Pick Flex."
end

-- HP follows the party size. A missing healer softens boss damage.
function Raids.combatScale(difficulty: any, players: number, healer: boolean): (number, number)
	local row = Raids.difficulty(difficulty) or Raids.DIFFICULTIES.story
	local count = players
	if count < 1 then
		count = 1
	end
	if count > 8 then
		count = 8
	end
	local hp = row.hp * (count / 8)
	if hp < Raids.SOLO_HP then
		hp = Raids.SOLO_HP
	end
	local damage = row.damage
	if not healer then
		damage *= 0.85
	end
	return hp, damage
end

local function bag(data, key)
	if type(data[key]) ~= "table" then
		data[key] = {}
	end
	return data[key]
end

-- One loot roll per boss per difficulty per week. Later clears still pay Marks.
function Raids.applyClear(
	data,
	bossId: string,
	difficulty: string,
	now: number,
	roll: number
): (number, boolean, boolean)
	local week = Raids.weekNumber(now)
	local locks = bag(data, "raidLock")
	local pity = bag(data, "raidPity")
	local key = bossId .. ":" .. difficulty
	local locked = locks[key] == week
	if data.raidMarkWeek ~= week then
		data.raidMarkWeek = week
		data.raidMarksEarned = 0
	end
	local grant = if difficulty == "normal" then 40 else 25
	local room = Raids.MARK_CAP - (data.raidMarksEarned or 0)
	if room < 0 then
		room = 0
	end
	local paid = math.min(room, grant)
	data.raidMarks = (data.raidMarks or 0) + paid
	data.raidMarksEarned = (data.raidMarksEarned or 0) + paid
	local dropped = false
	if not locked then
		local chance = Raids.DROP_BASE + (pity[key] or 0) * Raids.DROP_STEP
		if chance > Raids.DROP_CAP then
			chance = Raids.DROP_CAP
		end
		local row = Raids.difficulty(difficulty) or Raids.DIFFICULTIES.story
		if roll < chance and type(data.chests) == "table" then
			dropped = true
			pity[key] = 0
			data.chests[row.loot] = (data.chests[row.loot] or 0) + 1
		else
			pity[key] = (pity[key] or 0) + 1
		end
		locks[key] = week
	end
	if difficulty == "story" then
		data.raidStory = true
	end
	return paid, dropped, locked
end

function Raids.buy(data, itemId: string): (boolean, string)
	local row = Raids.SHOP[itemId]
	if row == nil then
		return false, "The vendor does not sell that."
	end
	if (data.raidMarks or 0) < row.marks then
		return false, "Not enough Raid Marks."
	end
	data.raidMarks -= row.marks
	if row.chest ~= nil and type(data.chests) == "table" then
		data.chests[row.chest] = (data.chests[row.chest] or 0) + 1
	end
	if row.title ~= nil then
		data.milestoneTitle = row.title
	end
	return true, "Bought."
end

function Raids.tagOk(tag: any): boolean
	if type(tag) ~= "string" then
		return false
	end
	for _, name in ipairs(Raids.TAGS) do
		if name == tag then
			return true
		end
	end
	return false
end

return Raids
