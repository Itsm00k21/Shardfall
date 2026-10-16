--!strict

--[[
	Dailies, weeklies, the Shard Board, and the free Shard Pass.

	The client asks to reroll, claim, or start the daily boss. Progress is
	counted here when a room, dodge, hatch, forge, or pet action lands.
	Premium purchase stays refused until the pass is published.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChestConfig = require(ReplicatedStorage.Shared.ChestConfig)
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
	if after >= 1 and before < 1 then
		data.chests.Epic = (data.chests.Epic or 0) + 1
	end
	if after >= 2 and before < 2 then
		data.gems = (data.gems or 0) + 5
		data.shardKeys = (data.shardKeys or 0) + 3
	end
	if after >= 3 and before < 3 then
		data.chests.Legendary = (data.chests.Legendary or 0) + 1
	end
end

function LoopService.progress(player: Player, id: string, amount: number)
	DataService.mutate(player, function(data)
		local now = os.time()
		Loops.refresh(data, now, player.UserId)
		local finished = Loops.apply(data, id, amount)
		if finished > 0 then
			data.gold += 40 * finished
			data.shardKeys = (data.shardKeys or 0) + finished
			data.passXp = select(1, Loops.passXp(data.passXp or 0, 100 * finished))
			local lines = data.boardLines or 0
			if type(data.board) ~= "table" then
				data.board = Loops.board()
			end
			for _ = 1, finished do
				local total = Loops.sealNext(data.board)
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
			if type(data.chests) == "table" then
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
	local _open, reason = Loops.premium()
	return { ok = false, error = reason }
end

return LoopService
