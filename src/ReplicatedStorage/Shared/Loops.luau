--!strict

--[[
	Dailies, the Shard Board, and the Shard Pass.

	A missed day pauses the login calendar. Dailies last three days and can
	be rerolled once. The 4x4 board places up to nine seals at random.
	Rows, columns, and both diagonals count as lines. Second Chance points
	come from helping a new or low-level player. They live on boardChance,
	not on the board, so the sixteen cells stay booleans.

	The premium track is cosmetics and a Gem refund. It does not grant
	power. Loops.PREMIUM_ENABLED stays false, so a grant, a claim, and a
	tier skip all refuse until the pass is published.
]]

local Loops = {}

Loops.PASS_TIERS = 50
Loops.PASS_XP = 1000
Loops.PREMIUM_ENABLED = false
Loops.DAILY_LIFE_DAYS = 3

-- Unpublished developer products. A non-positive id never matches, so the
-- live game cannot grant the pass by accident. GHOST fills the real ids
-- before turning PREMIUM_ENABLED on.
Loops.PASS_PRODUCT_ID = 0
Loops.ARCHIVE_PRODUCT_ID = 0
Loops.PASS_ROBUX = 400
Loops.PASS_GEMS = 400
Loops.ARCHIVE_MARKUP = 20
Loops.SKIP_GEMS = 80
Loops.OVERFLOW_KEYS = 4
Loops.SEAL_CAP = 9
Loops.CHANCE_MAX = 9
Loops.RETRY_COST = 1
Loops.SHUFFLE_COST = 2

Loops.POOL = {
	{ id = "rooms", text = "Clear 2 Rootvault rooms", goal = 2 },
	{ id = "dodge", text = "Dodge 5 attacks", goal = 5 },
	{ id = "hatch", text = "Hatch an egg", goal = 1 },
	{ id = "forge", text = "Upgrade a piece of gear", goal = 1 },
	{ id = "pet", text = "Pet or feed a companion", goal = 1 },
	-- Far Glade beasts join Waves from wave 3 (Dungeons.GLADE_FROM_WAVE).
	{ id = "glade", text = "Defeat 4 Far Glade beasts in Waves", goal = 4 },
}

-- The first five daily ids (the Far Glade daily stays daily-only). The sentence matches
-- the goal. rollWeekly reads this table and does not multiply again.
Loops.WEEKLY = table.freeze({
	table.freeze({ id = "rooms", text = "Clear 6 Rootvault rooms", goal = 6 }),
	table.freeze({ id = "dodge", text = "Dodge 15 attacks", goal = 15 }),
	table.freeze({ id = "hatch", text = "Hatch 3 eggs", goal = 3 }),
	table.freeze({ id = "forge", text = "Upgrade 3 pieces of gear", goal = 3 }),
	table.freeze({ id = "pet", text = "Pet or feed a companion 3 times", goal = 3 }),
})

-- 4 rows, 4 columns, and both diagonals. Rewards still fire at 1, 2, and 3.
Loops.LINE_CELLS = {
	{ 1, 2, 3, 4 },
	{ 5, 6, 7, 8 },
	{ 9, 10, 11, 12 },
	{ 13, 14, 15, 16 },
	{ 1, 5, 9, 13 },
	{ 2, 6, 10, 14 },
	{ 3, 7, 11, 15 },
	{ 4, 8, 12, 16 },
	{ 1, 6, 11, 16 },
	{ 4, 7, 10, 13 },
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

function Loops.lineCount(cells: { any }): number
	if type(cells) ~= "table" then
		return 0
	end
	local lines = 0
	for _, line in ipairs(Loops.LINE_CELLS) do
		local filled = true
		for _, index in ipairs(line) do
			if cells[index] ~= true then
				filled = false
			end
		end
		if filled then
			lines += 1
		end
	end
	return lines
end

-- Cells that sit on a finished line. The HUD lights these.
function Loops.litCells(cells: { any }): { [number]: boolean }
	local lit = {}
	if type(cells) ~= "table" then
		return lit
	end
	for _, line in ipairs(Loops.LINE_CELLS) do
		local filled = true
		for _, index in ipairs(line) do
			if cells[index] ~= true then
				filled = false
			end
		end
		if filled then
			for _, index in ipairs(line) do
				lit[index] = true
			end
		end
	end
	return lit
end

function Loops.sealCount(cells: { any }): number
	if type(cells) ~= "table" then
		return 0
	end
	local count = 0
	for index = 1, 16 do
		if cells[index] == true then
			count += 1
		end
	end
	return count
end

function Loops.seal(cells: { any }, index: number): number
	if type(cells) ~= "table" or index < 1 or index > 16 then
		return 0
	end
	cells[index] = true
	return Loops.lineCount(cells)
end

local function openCells(cells: { any }): { number }
	local open = {}
	for index = 1, 16 do
		if cells[index] ~= true then
			table.insert(open, index)
		end
	end
	return open
end

local function pick(list: { number }, salt: number): number
	local count = #list
	if count < 1 then
		return 0
	end
	local cursor = math.floor(salt)
	if cursor < 0 then
		cursor = -cursor
	end
	return list[(cursor % count) + 1]
end

-- One seal on a random empty cell. Nine seals is the weekly cap.
function Loops.placeSeal(cells: { any }, salt: number): number
	if type(cells) ~= "table" then
		return 0
	end
	if Loops.sealCount(cells) >= Loops.SEAL_CAP then
		return Loops.lineCount(cells)
	end
	local index = pick(openCells(cells), salt)
	if index < 1 then
		return Loops.lineCount(cells)
	end
	return Loops.seal(cells, index)
end

-- A stored point count, separate from the board. Nil and junk read as 0.
function Loops.chance(amount: any): number
	if type(amount) ~= "number" or amount ~= amount then
		return 0
	end
	local whole = math.floor(amount)
	if whole < 0 then
		return 0
	end
	if whole > Loops.CHANCE_MAX then
		return Loops.CHANCE_MAX
	end
	return whole
end

-- Another player under level 10, or new to the content. Not yourself.
function Loops.mentorCredit(selfId: any, allyId: any, allyLevel: any, allyNew: any): boolean
	if type(selfId) ~= "number" or type(allyId) ~= "number" or allyId == selfId then
		return false
	end
	if allyNew == true then
		return true
	end
	return type(allyLevel) == "number" and allyLevel >= 1 and allyLevel < 10
end

-- Granted, and the count after the attempt. The board is not touched.
function Loops.grantChance(amount: any): (boolean, number)
	local current = Loops.chance(amount)
	if current >= Loops.CHANCE_MAX then
		return false, current
	end
	return true, current + 1
end

function Loops.retry(cells: { any }, salt: number, amount: any): (boolean, string, number, number)
	local points = Loops.chance(amount)
	if type(cells) ~= "table" then
		return false, "The board is not ready.", 0, points
	end
	if points < Loops.RETRY_COST then
		return false, "Retry costs 1 Second Chance.", Loops.lineCount(cells), points
	end
	local sealed = {}
	for index = 1, 16 do
		if cells[index] == true then
			table.insert(sealed, index)
		end
	end
	local open = openCells(cells)
	if #sealed < 1 or #open < 1 then
		return false, "Nothing to move.", Loops.lineCount(cells), points
	end
	local from = pick(sealed, salt)
	local destination = pick(open, salt + 1)
	cells[from] = false
	points -= Loops.RETRY_COST
	local lines = Loops.seal(cells, destination)
	return true, "", lines, points
end

function Loops.shuffle(cells: { any }, salt: number, amount: any): (boolean, string, number, number)
	local points = Loops.chance(amount)
	if type(cells) ~= "table" then
		return false, "The board is not ready.", 0, points
	end
	if points < Loops.SHUFFLE_COST then
		return false, "Shuffle costs 2 Second Chance.", Loops.lineCount(cells), points
	end
	local count = Loops.sealCount(cells)
	if count < 1 then
		return false, "Nothing to shuffle.", 0, points
	end
	if count > Loops.SEAL_CAP then
		count = Loops.SEAL_CAP
	end
	for index = 1, 16 do
		cells[index] = false
	end
	points -= Loops.SHUFFLE_COST
	local cursor = math.floor(salt)
	for _ = 1, count do
		cursor += 1
		Loops.placeSeal(cells, cursor)
	end
	return true, "", Loops.lineCount(cells), points
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

function Loops.archiveRobux(): number
	return Loops.PASS_ROBUX + math.floor(Loops.PASS_ROBUX * Loops.ARCHIVE_MARKUP / 100)
end

function Loops.productKind(productId: any): string?
	if type(productId) ~= "number" or productId ~= productId or productId <= 0 then
		return nil
	end
	local whole = math.floor(productId)
	if Loops.PASS_PRODUCT_ID > 0 and whole == Loops.PASS_PRODUCT_ID then
		return "pass"
	end
	if Loops.ARCHIVE_PRODUCT_ID > 0 and whole == Loops.ARCHIVE_PRODUCT_ID then
		return "archive"
	end
	return nil
end

-- Bought passes never expire and earned tiers are never re-locked.
function Loops.keepsPremium(owned: boolean, _seasonEnded: boolean): boolean
	return owned == true
end

-- ok, duplicate, reason. A refusal writes nothing, so a real purchase
-- stays pending instead of being swallowed.
function Loops.grantPremium(data: any, receiptId: any, productId: any): (boolean, boolean, string)
	if Loops.PREMIUM_ENABLED ~= true then
		return false, false, "The premium track is not for sale yet."
	end
	if type(data) ~= "table" then
		return false, false, "Profile is missing."
	end
	if Loops.productKind(productId) == nil then
		return false, false, "That product is not the Shard Pass."
	end
	if type(receiptId) ~= "string" or receiptId == "" then
		return false, false, "Missing receipt."
	end
	if type(data.receipts) == "table" and data.receipts[receiptId] == true then
		return true, true, ""
	end
	if type(data.receipts) ~= "table" then
		data.receipts = {}
	end
	data.passPremium = true
	if type(data.passPremiumClaimed) ~= "number" then
		data.passPremiumClaimed = 0
	end
	if type(data.passCosmetics) ~= "table" then
		data.passCosmetics = {}
	end
	data.receipts[receiptId] = true
	return true, false, ""
end

-- Cosmetics and the Gem refund only. No gold, keys, dust, or stats.
-- Ten skins, two pet hats, two trails, one weapon VFX, one emote.
-- Gem rows sum to PASS_GEMS. Tier 50 is the feat skin and pays no Gems.
Loops.PREMIUM_TRACK = {
	[2] = { cosmetic = "skin", id = "pass_skin_moss", name = "Mossweave" },
	[4] = { cosmetic = "skin", id = "pass_skin_fern", name = "Fernweave" },
	[5] = { gems = 40, cosmetic = "pet_hat", id = "pass_hat_moss", name = "Moss Cap" },
	[8] = { cosmetic = "skin", id = "pass_skin_bark", name = "Barkweave" },
	[10] = { gems = 40, cosmetic = "trail", id = "pass_trail_spores", name = "Spore Trail" },
	[12] = { cosmetic = "skin", id = "pass_skin_heartwood", name = "Heartwood" },
	[15] = { gems = 40, cosmetic = "skin", id = "pass_skin_lantern", name = "Lantern Glow" },
	[18] = { cosmetic = "skin", id = "pass_skin_sap", name = "Sapshine" },
	[20] = { gems = 40, cosmetic = "emote", id = "pass_emote_bow", name = "Root Bow" },
	[22] = { cosmetic = "skin", id = "pass_skin_root", name = "Rootbound" },
	[25] = { gems = 40, cosmetic = "weapon_vfx", id = "pass_vfx_sap", name = "Sap Glow" },
	[28] = { cosmetic = "skin", id = "pass_skin_shard", name = "Shardfall" },
	[30] = { gems = 40, cosmetic = "pet_hat", id = "pass_hat_crown", name = "Gnarl Crown" },
	[35] = { gems = 40, cosmetic = "trail", id = "pass_trail_lantern", name = "Lantern Trail" },
	[38] = { cosmetic = "skin", id = "pass_skin_veil", name = "Veil of Leaves" },
	[40] = { gems = 40 },
	[45] = { gems = 40 },
	[48] = { gems = 40 },
	[50] = {
		cosmetic = "skin",
		id = "pass_skin_nightmare",
		name = "Nightmare Bloom",
		feat = "nightmare",
	},
}

function Loops.premiumGemTotal(): number
	local total = 0
	for _, reward in pairs(Loops.PREMIUM_TRACK) do
		if type(reward) == "table" and type(reward.gems) == "number" then
			total += reward.gems
		end
	end
	return total
end

function Loops.claimPremium(
	xp: number,
	claimed: number,
	owned: boolean,
	nightmareBest: number
): (number, any, boolean, string)
	if Loops.PREMIUM_ENABLED ~= true then
		return claimed, nil, false, "The premium track is not for sale yet."
	end
	if owned ~= true then
		return claimed, nil, false, "The premium track is locked."
	end
	local _, tier = Loops.passXp(xp, 0)
	local held = math.floor(claimed)
	if held < 0 then
		held = 0
	end
	if held >= tier or held >= Loops.PASS_TIERS then
		return held, nil, false, "No premium tier is ready."
	end
	local nextClaim = held + 1
	local reward = Loops.PREMIUM_TRACK[nextClaim]
	if type(reward) == "table" and reward.feat == "nightmare" and nightmareBest < 1 then
		return held, nil, false, "Clear Nightmare to claim this."
	end
	return nextClaim, reward, true, ""
end

function Loops.skipTier(xp: number, gems: number, owned: boolean): (number, number, boolean, string)
	if Loops.PREMIUM_ENABLED ~= true then
		return xp, gems, false, "The premium track is not for sale yet."
	end
	if owned ~= true then
		return xp, gems, false, "The premium track is locked."
	end
	local _, tier = Loops.passXp(xp, 0)
	if tier >= Loops.PASS_TIERS then
		return xp, gems, false, "The pass is already finished."
	end
	if gems < Loops.SKIP_GEMS then
		return xp, gems, false, "Not enough Gems."
	end
	local total = select(1, Loops.passXp(xp, Loops.PASS_XP))
	return total, gems - Loops.SKIP_GEMS, true, ""
end

-- After tier 50, each extra tier of Pass XP is a Shard Key cache.
-- Live claim does not call this. The free track payout stays as it is.
function Loops.overflow(xp: number, caches: number): (number, number, boolean)
	local _, tier = Loops.passXp(xp, 0)
	local held = math.floor(caches)
	if held < 0 then
		held = 0
	end
	if tier < Loops.PASS_TIERS then
		return held, 0, false
	end
	local extra = math.floor(xp) - Loops.PASS_TIERS * Loops.PASS_XP
	if extra < 0 then
		extra = 0
	end
	local earned = math.floor(extra / Loops.PASS_XP)
	if held >= earned then
		return held, 0, false
	end
	return earned, (earned - held) * Loops.OVERFLOW_KEYS, true
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
		local row = Loops.WEEKLY[((cursor - 1) % #Loops.WEEKLY) + 1]
		if used[row.id] ~= true then
			used[row.id] = true
			table.insert(picked, {
				id = row.id,
				text = row.text,
				goal = row.goal,
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
		-- boardChance stays. Helping earns it, and the cap is CHANCE_MAX.
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

function Loops.sealNext(cells: { any }): number
	if type(cells) ~= "table" then
		return 0
	end
	if Loops.sealCount(cells) >= Loops.SEAL_CAP then
		return Loops.lineCount(cells)
	end
	for index = 1, 16 do
		if cells[index] ~= true then
			return Loops.seal(cells, index)
		end
	end
	return Loops.lineCount(cells)
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

for _, line in ipairs(Loops.LINE_CELLS) do
	table.freeze(line)
end
table.freeze(Loops.LINE_CELLS)
for _, reward in pairs(Loops.PREMIUM_TRACK) do
	table.freeze(reward)
end
table.freeze(Loops.PREMIUM_TRACK)
table.freeze(Loops.FREE_TRACK)

return Loops
