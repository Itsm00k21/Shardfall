--!strict

--[[
	Ground loot. A kill leaves a chip where the body fell. Walking inside
	the pickup radius takes it. The wave purse is tokens from the economy
	sheet, added when that wave is cleared.

	Each drop is taken once. Chips that fit in the Bag stay on the run.
	A full Bag holds the rest for this session only, up to overflowCap.
	Past that cap the salvage value is banked on the run, not deleted.
	commit() pays tokens and turns held overflow into Essence once per
	receipt. It does not write a new profile field.
]]

local Essence = require("../../ReplicatedStorage/Shared/Config/Essence")
local GearSalvage = require("../../ReplicatedStorage/Shared/GearSalvage")
local WaveArenaConfig = require("../../ReplicatedStorage/Shared/Config/WaveArenaConfig")

local Loot = {}

export type Payload = {
	dropId: string,
	fragments: number,
	tokens: number,
	rarity: string,
}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Loot.bagCap(config: any?): number
	local cfg = cfgOf(config)
	local loot = if typeof(cfg) == "table" then cfg.loot else nil
	local cap = if typeof(loot) == "table" then loot.bagSlots else nil
	if not finite(cap) or cap < 0 then
		return 100
	end
	return math.floor(cap)
end

function Loot.overflowCap(config: any?): number
	local cfg = cfgOf(config)
	local loot = if typeof(cfg) == "table" then cfg.loot else nil
	local cap = if typeof(loot) == "table" then loot.overflowCap else nil
	if not finite(cap) or cap < 0 then
		return 40
	end
	return math.floor(cap)
end

function Loot.rate(rarity: any): number
	local amount = Essence.amount(rarity)
	if amount == nil then
		amount = Essence.amount("Common")
	end
	if amount == nil then
		return 1
	end
	return amount
end

function Loot.payload(kind: string, config: any?): Payload
	local cfg = cfgOf(config)
	local drops = cfg.loot.drops
	local row = drops[kind]
	if typeof(row) ~= "table" then
		row = drops.chaser
	end
	local rarity = "Common"
	if Essence.amount(row.rarity) ~= nil then
		rarity = row.rarity
	end
	return {
		dropId = row.id,
		fragments = row.fragments or 0,
		tokens = row.tokens or 0,
		rarity = rarity,
	}
end

function Loot.purse(waveIndex: number, config: any?): number
	local cfg = cfgOf(config)
	local list = cfg.loot.waveTokens
	local amount = list[waveIndex]
	if not finite(amount) then
		return 0
	end
	return amount
end

function Loot.near(px: number, pz: number, drop: any, radius: number): boolean
	local dx = px - drop.x
	local dz = pz - drop.z
	return dx * dx + dz * dz <= radius * radius
end

local function heldCount(list: { any }): number
	local held = 0
	for _, row in ipairs(list) do
		local count = row.count
		held += if finite(count) and count > 0 then math.floor(count) else 1
	end
	return held
end

local function stack(list: { any }, row: any)
	for _, saved in ipairs(list) do
		if saved.id == row.id and saved.rarity == row.rarity then
			saved.fragments += row.fragments or 0
			saved.tokens += row.tokens or 0
			saved.count += 1
			return
		end
	end
	table.insert(list, {
		id = row.id,
		fragments = row.fragments or 0,
		tokens = row.tokens or 0,
		count = 1,
		rarity = row.rarity,
		wave = row.wave or 0,
	})
end

-- nil when this drop was already taken. Otherwise "bag", "overflow", or "bank".
function Loot.take(earned: any, drop: any, cap: number, overflowCap: number?): string?
	if typeof(drop) ~= "table" or drop.collected == true then
		return nil
	end
	drop.collected = true
	if typeof(earned.overflow) ~= "table" then
		earned.overflow = {}
	end
	if typeof(earned.drops) ~= "table" then
		earned.drops = {}
	end
	local rarity = "Common"
	if Essence.amount(drop.rarity) ~= nil then
		rarity = drop.rarity
	end
	local row = {
		id = drop.dropId,
		tokens = drop.tokens or 0,
		fragments = drop.fragments or 0,
		wave = drop.wave,
		rarity = rarity,
	}
	local slots = if finite(earned.bagCount) then math.floor(earned.bagCount) else #earned.drops
	local where = "bag"
	local limit = 40
	if finite(overflowCap) and overflowCap >= 0 then
		limit = math.floor(overflowCap)
	end
	if slots >= cap then
		if heldCount(earned.overflow) >= limit then
			where = "bank"
			local pending = earned.pendingEssence
			if not finite(pending) or pending < 0 then
				pending = 0
			end
			earned.pendingEssence = pending + Loot.rate(rarity)
		else
			where = "overflow"
			stack(earned.overflow, row)
		end
	else
		earned.bagCount = slots + 1
		table.insert(earned.drops, row)
	end
	earned.tokens += row.tokens
	earned.fragments += row.fragments
	return where
end

function Loot.remember(run: any, key: string, grant: any): boolean
	if typeof(run.grantKeys) ~= "table" then
		run.grantKeys = {}
		run.grantList = {}
	end
	if run.grantKeys[key] == true then
		return false
	end
	run.grantKeys[key] = true
	grant.key = key
	table.insert(run.grantList, grant)
	return true
end

function Loot.essenceDue(run: any): number
	if typeof(run) ~= "table" or typeof(run.grantList) ~= "table" then
		return 0
	end
	local total = 0
	for _, grant in ipairs(run.grantList) do
		if grant.where == "overflow" or grant.where == "bank" then
			local add = grant.essence
			if finite(add) and add > 0 then
				total += math.floor(add)
			end
		end
	end
	return total
end

-- Copies grants onto a profile table. A receipt that is already set adds nothing.
-- Overflow becomes Essence. The profile does not gain a mail field.
function Loot.commit(profile: any, run: any): { tokens: number, essence: number, bag: number }
	local result = { tokens = 0, essence = 0, bag = 0 }
	if typeof(profile) ~= "table" or typeof(run) ~= "table" or typeof(run.grantList) ~= "table" then
		return result
	end
	if typeof(profile.receipts) ~= "table" then
		profile.receipts = {}
	end
	if typeof(profile.ledger) ~= "table" then
		profile.ledger = {}
	end
	profile.arenaMail = nil
	local wallet = profile.shardTokens
	if not finite(wallet) or wallet < 0 then
		wallet = 0
	else
		wallet = math.floor(wallet)
	end
	local essence = 0
	local prefix = "arena:" .. tostring(run.receiptId or "run") .. ":"
	for _, grant in ipairs(run.grantList) do
		local key = prefix .. tostring(grant.key)
		if profile.receipts[key] ~= true then
			profile.receipts[key] = true
			local add = grant.tokens or 0
			if finite(add) and add > 0 then
				add = math.floor(add)
				wallet += add
				result.tokens += add
			else
				add = 0
			end
			if grant.where == "bag" then
				result.bag += 1
			end
			if grant.where == "overflow" or grant.where == "bank" then
				local salvage = grant.essence or 0
				if finite(salvage) and salvage > 0 then
					essence += math.floor(salvage)
				end
			end
			if add > 0 then
				table.insert(profile.ledger, {
					reason = "arena_" .. tostring(grant.kind or "loot"),
					currency = "shardTokens",
					amount = add,
					balance = wallet,
					id = grant.dropId,
				})
			end
			while #profile.ledger > 20 do
				table.remove(profile.ledger, 1)
			end
		end
	end
	if essence > 0 then
		GearSalvage.grant(profile, essence)
		result.essence = essence
		table.insert(profile.ledger, {
			reason = "arena_salvage",
			currency = "gearEssence",
			amount = essence,
			balance = profile.gearEssence,
		})
		while #profile.ledger > 20 do
			table.remove(profile.ledger, 1)
		end
	end
	profile.shardTokens = wallet
	return result
end

return Loot
