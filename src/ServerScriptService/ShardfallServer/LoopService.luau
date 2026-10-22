--!strict

--[[
	Dailies, weeklies, the Shard Board, and the Shard Pass.

	The client asks to reroll, claim, or start the daily boss. Progress is
	counted here when a room, dodge, hatch, forge, or pet action lands.
	Seals land on random cells, up to nine a week.

	Premium grants, claims, and tier skips refuse while
	Loops.PREMIUM_ENABLED is false. ProcessReceipt leaves every product
	pending. It does not grant the pass.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChestConfig = require(ReplicatedStorage.Shared.ChestConfig)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Loops = require(ReplicatedStorage.Shared.Loops)
local DataService = require(script.Parent.DataService)

local LoopService = {}

local ranks: { { name: string, userId: number, seconds: number } } = {}

local function reject(message: string)
	return { ok = false, error = message }
end

local function payLines(data, before: number, after: number)
	if after <= before or type(data.chests) ~= "table" then
		return
	end
	if after >= 1 and before < 1 and ChestConfig.dropsOn() then
		data.chests.Epic = (data.chests.Epic or 0) + 1
	end
	if after >= 2 and before < 2 then
		data.gems = (data.gems or 0) + 5
		data.shardKeys = (data.shardKeys or 0) + 3
	end
	if after >= 3 and before < 3 and ChestConfig.dropsOn() then
		data.chests.Legendary = (data.chests.Legendary or 0) + 1
	end
end

function LoopService.progress(player: Player, id: string, amount: number)
	DataService.mutate(player, function(data)
		local now = os.time()
		Loops.refresh(data, now, player.UserId)
		local finished = Loops.apply(data, id, amount)
		if finished > 0 then
			data.gold += Economy.QUEST_GOLD * finished
			data.shardKeys = (data.shardKeys or 0) + finished
			data.passXp = select(1, Loops.passXp(data.passXp or 0, 100 * finished))
			local lines = data.boardLines or 0
			if type(data.board) ~= "table" then
				data.board = Loops.board()
			end
			local stamp = player.UserId + Loops.dayNumber(now)
			for step = 1, finished do
				local total = Loops.placeSeal(data.board, stamp + step * 17)
				if total > lines then
					payLines(data, lines, total)
					lines = total
				end
			end
			data.boardLines = lines
		end
		local today = Loops.dayNumber(now)
		local allDone = type(data.dailies) == "table" and #data.dailies >= 3
		if allDone then
			for _, quest in ipairs(data.dailies) do
				if quest.done ~= true then
					allDone = false
				end
			end
		end
		if allDone and data.dailyBonusDay ~= today then
			data.dailyBonusDay = today
			ChestConfig.grantSource(data, "room", now)
			if ChestConfig.dropsOn() and type(data.chests) == "table" then
				data.chests.Rare = (data.chests.Rare or 0) + 1
			end
		end
		return nil
	end)
end

function LoopService.recordTime(name: string, userId: number, seconds: number)
	if seconds < 1 then
		return
	end
	local found = false
	for _, row in ipairs(ranks) do
		if row.userId == userId then
			found = true
			if seconds < row.seconds then
				row.seconds = seconds
				row.name = name
			end
		end
	end
	if not found then
		table.insert(ranks, { name = name, userId = userId, seconds = seconds })
	end
	table.sort(ranks, function(a, b)
		return a.seconds < b.seconds
	end)
	while #ranks > 10 do
		table.remove(ranks)
	end
end

function LoopService.leaderboard()
	local copy = {}
	for index, row in ipairs(ranks) do
		copy[index] = { name = row.name, seconds = row.seconds }
	end
	return copy
end

function LoopService.refresh(player: Player)
	local ok, err = DataService.mutate(player, function(data)
		Loops.refresh(data, os.time(), player.UserId)
		return nil
	end)
	if not ok then
		return reject(err or "The board is not ready.")
	end
	return {
		ok = true,
		profile = DataService.snapshot(player),
		leaderboard = LoopService.leaderboard(),
	}
end

function LoopService.reroll(player: Player, index: any)
	if type(index) ~= "number" or index < 1 or index > 3 then
		return reject("Pick a daily.")
	end
	local slot = math.floor(index)
	local ok, err = DataService.mutate(player, function(data)
		local now = os.time()
		local today = Loops.dayNumber(now)
		Loops.refresh(data, now, player.UserId)
		if data.dailyRerollDay == today then
			return "One free reroll a day."
		end
		local worked, text = Loops.reroll(data.dailies, slot, today, player.UserId + slot)
		if not worked then
			return text
		end
		data.dailyRerollDay = today
		return nil
	end)
	if not ok then
		return reject(err or "Could not reroll.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function LoopService.claim(player: Player)
	if not LaunchGate.on("pass") then
		return reject("That is closed.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local claimed, reward, ready = Loops.claimFree(data.passXp or 0, data.passClaimed or 0)
		if not ready then
			return "No free tier is ready."
		end
		data.passClaimed = claimed
		if type(reward) == "table" then
			if type(reward.gold) == "number" then
				data.gold += reward.gold
			end
			if type(reward.keys) == "number" then
				data.shardKeys = (data.shardKeys or 0) + reward.keys
			end
			if type(reward.dust) == "number" then
				data.shardDust = (data.shardDust or 0) + reward.dust
			end
			if type(reward.title) == "string" then
				data.milestoneTitle = reward.title
			end
		end
		return nil
	end)
	if not ok then
		return reject(err or "Could not claim that tier.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function LoopService.premium()
	if not LaunchGate.on("pass") then
		return reject("That is closed.")
	end
	local open, reason = Loops.premium()
	if not open then
		return { ok = false, error = reason }
	end
	if Loops.PASS_PRODUCT_ID <= 0 then
		return { ok = false, error = "The premium track is not for sale yet." }
	end
	return {
		ok = true,
		productId = Loops.PASS_PRODUCT_ID,
		archiveProductId = Loops.ARCHIVE_PRODUCT_ID,
		robux = Loops.PASS_ROBUX,
		archiveRobux = Loops.archiveRobux(),
	}
end

local function applyPremium(data, reward)
	if type(reward) ~= "table" then
		return
	end
	if type(reward.gems) == "number" and reward.gems > 0 then
		Economy.grant(data, "gems", reward.gems, "shard_pass")
	end
	if type(reward.id) == "string" and reward.id ~= "" then
		if type(data.passCosmetics) ~= "table" then
			data.passCosmetics = {}
		end
		data.passCosmetics[reward.id] = true
	end
end

local function raiseLines(data, before: number, total: number)
	if total > before then
		payLines(data, before, total)
		data.boardLines = total
	end
end

-- Server only. A client remote must not call this or players can mint points.
function LoopService.noteMentor(player: Player, allyUserId: any, allyLevel: any, allyNew: any)
	if not Loops.mentorCredit(player.UserId, allyUserId, allyLevel, allyNew) then
		return
	end
	DataService.mutate(player, function(data)
		Loops.refresh(data, os.time(), player.UserId)
		if type(data.board) ~= "table" then
			data.board = Loops.board()
		end
		local granted, points = Loops.grantChance(data.boardChance)
		if granted then
			data.boardChance = points
		end
		return nil
	end)
end

function LoopService.retry(player: Player)
	local ok, err = DataService.mutate(player, function(data)
		local now = os.time()
		Loops.refresh(data, now, player.UserId)
		if type(data.board) ~= "table" then
			data.board = Loops.board()
		end
		local before = data.boardLines or 0
		local worked, text, total, points =
			Loops.retry(data.board, player.UserId + now, data.boardChance)
		if not worked then
			return text
		end
		data.boardChance = points
		raiseLines(data, before, total)
		return nil
	end)
	if not ok then
		return reject(err or "Could not retry that seal.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function LoopService.shuffle(player: Player)
	local ok, err = DataService.mutate(player, function(data)
		local now = os.time()
		Loops.refresh(data, now, player.UserId)
		if type(data.board) ~= "table" then
			data.board = Loops.board()
		end
		local before = data.boardLines or 0
		local worked, text, total, points =
			Loops.shuffle(data.board, player.UserId + now, data.boardChance)
		if not worked then
			return text
		end
		data.boardChance = points
		raiseLines(data, before, total)
		return nil
	end)
	if not ok then
		return reject(err or "Could not shuffle the board.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

-- ProcessReceipt does not grant the pass from here. A false return writes
-- nothing, so the purchase stays pending. Never read ProcessReceipt here.
function LoopService.grantPremium(player: Player, receiptId: any, productId: any): boolean
	if Loops.PREMIUM_ENABLED ~= true then
		return false
	end
	local accepted = false
	local saved = DataService.mutate(player, function(data)
		local granted, _duplicate, reason = Loops.grantPremium(data, receiptId, productId)
		if not granted then
			return reason
		end
		accepted = true
		return nil
	end)
	return saved and accepted
end

function LoopService.claimPremium(player: Player)
	if not LaunchGate.on("pass") then
		return reject("That is closed.")
	end
	if Loops.PREMIUM_ENABLED ~= true then
		return reject("The premium track is not for sale yet.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local claimed, reward, ready, reason = Loops.claimPremium(
			data.passXp or 0,
			data.passPremiumClaimed or 0,
			data.passPremium == true,
			data.nightmareBest or 0
		)
		if not ready then
			return reason
		end
		data.passPremiumClaimed = claimed
		applyPremium(data, reward)
		return nil
	end)
	if not ok then
		return reject(err or "Could not claim that tier.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function LoopService.skipTier(player: Player)
	if Loops.PREMIUM_ENABLED ~= true then
		return reject("The premium track is not for sale yet.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local total, gemsLeft, ready, reason =
			Loops.skipTier(data.passXp or 0, data.gems or 0, data.passPremium == true)
		if not ready then
			return reason
		end
		data.passXp = total
		data.gems = gemsLeft
		Economy.log(data, "shard_pass_skip", "gems", -Loops.SKIP_GEMS, gemsLeft)
		return nil
	end)
	if not ok then
		return reject(err or "Could not skip that tier.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function LoopService.overflow(player: Player)
	local ok, err = DataService.mutate(player, function(data)
		local caches, gain, ready = Loops.overflow(data.passXp or 0, data.passOverflow or 0)
		if not ready then
			return "No key cache is ready."
		end
		data.passOverflow = caches
		Economy.grant(data, "shardKeys", gain, "pass_overflow")
		return nil
	end)
	if not ok then
		return reject(err or "No key cache is ready.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

return LoopService
