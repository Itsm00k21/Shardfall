--!strict

--[[
	Dailies, the Shard Board, and the free Shard Pass.

	A missed day pauses the login calendar. Dailies last three days and can
	be rerolled once. Premium pass purchase stays off until it is published.
]]

local Loops = {}

Loops.PASS_TIERS = 50
Loops.PASS_XP = 1000
Loops.PREMIUM_ENABLED = false
Loops.DAILY_LIFE_DAYS = 3

Loops.POOL = {
	{ id = "rooms", text = "Clear 2 Rootvault rooms", goal = 2 },
	{ id = "dodge", text = "Dodge 5 attacks", goal = 5 },
	{ id = "hatch", text = "Hatch an egg", goal = 1 },
	{ id = "forge", text = "Upgrade a piece of gear", goal = 1 },
	{ id = "pet", text = "Pet or feed a companion", goal = 1 },
}

function Loops.dayNumber(now: number): number
	return math.floor(now / 86400)
end

function Loops.weekNumber(now: number): number
	return math.floor(now / (86400 * 7))
end

-- Missing a day pauses. Same day does not pay twice.
function Loops.login(streak: number, lastDay: number, today: number): (number, boolean)
	if lastDay == today then
		return streak, false
	end
	if lastDay >= 0 and today == lastDay + 1 then
		return streak + 1, true
	end
	if lastDay < 0 then
		return 1, true
	end
	return streak, true
end

function Loops.rollDailies(today: number, salt: number)
	local picked = {}
	local used = {}
	local cursor = salt
	while #picked < 3 do
		cursor += 1
		local row = Loops.POOL[((cursor - 1) % #Loops.POOL) + 1]
		if used[row.id] ~= true then
			used[row.id] = true
			table.insert(picked, {
				id = row.id,
				text = row.text,
				goal = row.goal,
				progress = 0,
				born = today,
				done = false,
			})
		end
	end
	return picked
end

function Loops.expire(dailies: { any }, today: number)
	local kept = {}
	for _, quest in ipairs(dailies) do
		if today - (quest.born or today) < Loops.DAILY_LIFE_DAYS and quest.done ~= true then
			table.insert(kept, quest)
		end
	end
	return kept
end

function Loops.reroll(
	dailies: { any },
	index: number,
	today: number,
	salt: number
): (boolean, string)
	local quest = dailies[index]
	if quest == nil then
		return false, "That daily is gone."
	end
	if quest.rerolled == true then
		return false, "One free reroll a day."
	end
	local replacement = Loops.rollDailies(today, salt)[1]
	replacement.rerolled = true
	dailies[index] = replacement
	return true, replacement.text
end

function Loops.board()
	local cells = {}
	for index = 1, 16 do
		cells[index] = false
	end
	return cells
end

function Loops.seal(cells: { boolean }, index: number): number
	if index < 1 or index > 16 then
		return 0
	end
	cells[index] = true
	local lines = 0
	for row = 0, 3 do
		local filled = true
		for col = 1, 4 do
			if cells[row * 4 + col] ~= true then
				filled = false
			end
		end
		if filled then
			lines += 1
		end
	end
	return lines
end

function Loops.passXp(xp: number, amount: number): (number, number)
	local total = math.max(0, xp) + math.max(0, amount)
	local tier = math.floor(total / Loops.PASS_XP)
	if tier > Loops.PASS_TIERS then
		tier = Loops.PASS_TIERS
	end
	return total, tier
end

function Loops.premium(): (boolean, string)
	if not Loops.PREMIUM_ENABLED then
		return false, "The premium track is not for sale yet."
	end
	return true, ""
end

-- First Rootvault clear of the day pays 3x XP and a Rare chest.
function Loops.firstClear(lastDay: number, today: number): (number, number, boolean)
	if lastDay == today then
		return 1, lastDay, false
	end
	return 3, today, true
end

function Loops.rollWeekly(week: number, salt: number)
	local picked = {}
	local used = {}
	local cursor = salt
	while #picked < 5 do
		cursor += 1
		local row = Loops.POOL[((cursor - 1) % #Loops.POOL) + 1]
		if used[row.id] ~= true then
			used[row.id] = true
			table.insert(picked, {
				id = row.id,
				text = row.text,
				goal = row.goal * 3,
				progress = 0,
				born = week,
				done = false,
			})
		end
	end
	return picked
end

function Loops.refresh(data: any, now: number, salt: number)
	local today = Loops.dayNumber(now)
	local week = Loops.weekNumber(now)
	if type(data.dailies) ~= "table" then
		data.dailies = {}
	end
	data.dailies = Loops.expire(data.dailies, today)
	local guard = 0
	while #data.dailies < 3 and guard < 8 do
		guard += 1
		for _, quest in ipairs(Loops.rollDailies(today, salt + guard * 3)) do
			local held = false
			for _, existing in ipairs(data.dailies) do
				if existing.id == quest.id then
					held = true
				end
			end
			if not held and #data.dailies < 3 then
				table.insert(data.dailies, quest)
			end
		end
	end
	if data.weeklyWeek ~= week then
		data.weekly = Loops.rollWeekly(week, salt)
		data.board = Loops.board()
		data.boardLines = 0
		data.weeklyWeek = week
	end
	if type(data.board) ~= "table" or #data.board < 16 then
		data.board = Loops.board()
	end
end

function Loops.apply(data: any, id: string, amount: number): number
	local finished = 0
	local function bump(list)
		if type(list) ~= "table" then
			return
		end
		for _, quest in ipairs(list) do
			if quest.id == id and quest.done ~= true then
				quest.progress = (quest.progress or 0) + amount
				if quest.progress >= quest.goal then
					quest.done = true
					finished += 1
				end
			end
		end
	end
	bump(data.dailies)
	bump(data.weekly)
	return finished
end

function Loops.sealNext(cells: { boolean }): number
	for index = 1, 16 do
		if cells[index] ~= true then
			return Loops.seal(cells, index)
		end
	end
	return 0
end

Loops.FREE_TRACK = {
	[1] = { gold = 150 },
	[5] = { keys = 4 },
	[10] = { dust = 25 },
	[20] = { gold = 400 },
	[30] = { title = "Boardwalker" },
	[50] = { keys = 20 },
}

function Loops.claimFree(xp: number, claimed: number): (number, any, boolean)
	local _, tier = Loops.passXp(xp, 0)
	if claimed >= tier then
		return claimed, nil, false
	end
	local nextClaim = claimed + 1
	return nextClaim, Loops.FREE_TRACK[nextClaim], true
end

return Loops
