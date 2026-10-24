--!strict

--[[
	Ground loot. A kill leaves a chip where the body fell. Walking inside
	the pickup radius takes it. The wave purse is tokens from the economy
	sheet, added when that wave is cleared.

	Each drop is taken once. A full Bag does not delete the chip: it goes
	to the mailbox. commit() copies those grants onto a profile once per
	receipt, so a wipe and a disconnect in the same moment cannot pay twice.
]]

local WaveArenaConfig = require("../../ReplicatedStorage/Shared/Config/WaveArenaConfig")

local Loot = {}

export type Payload = {
	dropId: string,
	fragments: number,
	tokens: number,
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

function Loot.payload(kind: string, config: any?): Payload
	local cfg = cfgOf(config)
	local drops = cfg.loot.drops
	local row = drops[kind]
	if typeof(row) ~= "table" then
		row = drops.chaser
	end
	return {
		dropId = row.id,
		fragments = row.fragments or 0,
		tokens = row.tokens or 0,
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

-- nil when this drop was already taken. Otherwise "bag" or "mailbox".
function Loot.take(earned: any, drop: any, cap: number): string?
	if typeof(drop) ~= "table" or drop.collected == true then
		return nil
	end
	drop.collected = true
	if typeof(earned.mailbox) ~= "table" then
		earned.mailbox = {}
	end
	if typeof(earned.drops) ~= "table" then
		earned.drops = {}
	end
	local slots = if finite(earned.bagCount) then math.floor(earned.bagCount) else #earned.drops
	local row = {
		id = drop.dropId,
		tokens = drop.tokens or 0,
		fragments = drop.fragments or 0,
		wave = drop.wave,
	}
	local where = "bag"
	if slots >= cap then
		where = "mailbox"
		table.insert(earned.mailbox, row)
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

local function stack(list: { any }, grant: any, where: string)
	for _, row in ipairs(list) do
		if row.id == grant.dropId and row.where == where then
			row.fragments += grant.fragments or 0
			row.tokens += grant.tokens or 0
			row.count += 1
			return
		end
	end
	table.insert(list, {
		id = grant.dropId,
		fragments = grant.fragments or 0,
		tokens = grant.tokens or 0,
		count = 1,
		where = where,
		wave = grant.wave or 0,
	})
end

local function gearCount(profile: any): number
	local held = 0
	if typeof(profile.inventory) == "table" then
		for _ in pairs(profile.inventory) do
			held += 1
		end
	end
	if typeof(profile.pets) == "table" then
		for _ in pairs(profile.pets) do
			held += 1
		end
	end
	return held
end

local function mailSlots(list: { any }, where: string): number
	local held = 0
	for _, row in ipairs(list) do
		if typeof(row) == "table" and row.where == where then
			local count = row.count
			held += if finite(count) and count > 0 then math.floor(count) else 1
		end
	end
	return held
end

-- Copies grants onto a profile table. A receipt that is already set adds nothing.
function Loot.commit(profile: any, run: any, capOverride: number?): { tokens: number, mailed: number, bag: number }
	local result = { tokens = 0, mailed = 0, bag = 0 }
	if typeof(profile) ~= "table" or typeof(run) ~= "table" or typeof(run.grantList) ~= "table" then
		return result
	end
	if typeof(profile.receipts) ~= "table" then
		profile.receipts = {}
	end
	if typeof(profile.arenaMail) ~= "table" then
		profile.arenaMail = {}
	end
	if typeof(profile.ledger) ~= "table" then
		profile.ledger = {}
	end
	local wallet = profile.shardTokens
	if not finite(wallet) or wallet < 0 then
		wallet = 0
	else
		wallet = math.floor(wallet)
	end
	local cap = 100
	if finite(capOverride) and capOverride >= 0 then
		cap = math.floor(capOverride)
	end
	local gear = gearCount(profile)
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
			if grant.dropId ~= nil then
				local where = if grant.where == "mailbox" then "mailbox" else "bag"
				if where == "bag" and gear + mailSlots(profile.arenaMail, "bag") >= cap then
					where = "mailbox"
				end
				stack(profile.arenaMail, grant, where)
				if where == "mailbox" then
					result.mailed += 1
				else
					result.bag += 1
				end
			end
			table.insert(profile.ledger, {
				reason = "arena_" .. tostring(grant.kind or "loot"),
				currency = if grant.dropId ~= nil then "arenaMail" else "shardTokens",
				amount = if grant.dropId ~= nil then (grant.fragments or 0) else add,
				balance = wallet,
				where = grant.where,
				id = grant.dropId,
			})
			while #profile.ledger > 20 do
				table.remove(profile.ledger, 1)
			end
		end
	end
	profile.shardTokens = wallet
	return result
end

return Loot
