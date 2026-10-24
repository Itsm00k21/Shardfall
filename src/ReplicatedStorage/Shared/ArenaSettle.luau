--!strict

--[[
	One settle mark per wave-arena run.

	profile.arenaSettle is a list of run ids, oldest first. The list keeps
	WaveArenaConfig.settleKeep ids (50). A new id pushes the oldest off.
	This list is not profile.receipts. Robux purchase receipts stay in
	receipts. They are not read, renamed, or removed.

	Older builds wrote one receipts key per drop:
	  arena:<run id>:drop:<uid>
	  arena:<run id>:purse:<wave>
	adopt() copies those run ids into the bounded list and removes only
	keys of that shape. Every other receipts key is left as it was.
	schemaVersion stays 26. A save that still has the old keys still loads.
]]

local WaveArenaConfig = require("./Config/WaveArenaConfig")

local ArenaSettle = {}

local DEFAULT_KEEP = 50
local PREFIX = "arena:"

local function normalizeCap(cap: any): number
	if typeof(cap) ~= "number" or cap ~= cap or cap == math.huge or cap < 1 then
		return DEFAULT_KEEP
	end
	return math.floor(cap)
end

function ArenaSettle.keep(config: any?): number
	local cfg = if config == nil then WaveArenaConfig else config
	local keep = if typeof(cfg) == "table" then cfg.settleKeep else nil
	return normalizeCap(keep)
end

function ArenaSettle.runId(run: any): string
	if typeof(run) == "table" and type(run.receiptId) == "string" and run.receiptId ~= "" then
		return run.receiptId
	end
	return "run"
end

-- Run id stored in an old per-drop key, or nil when the key is not one.
-- A Robux receipt id does not match this shape, so it is not a settle key.
function ArenaSettle.oldRunId(key: any): string?
	if type(key) ~= "string" or string.sub(key, 1, #PREFIX) ~= PREFIX then
		return nil
	end
	local from = #PREFIX + 1
	local dropAt = string.find(key, ":drop:", from, true)
	local purseAt = string.find(key, ":purse:", from, true)
	local at = dropAt
	if purseAt ~= nil and (at == nil or purseAt < at) then
		at = purseAt
	end
	if at == nil or at <= from then
		return nil
	end
	local id = string.sub(key, from, at - 1)
	if id == "" then
		return nil
	end
	return id
end

function ArenaSettle.has(list: any, id: string): boolean
	if typeof(list) ~= "table" or type(id) ~= "string" then
		return false
	end
	for _, saved in ipairs(list) do
		if saved == id then
			return true
		end
	end
	return false
end

-- Drops junk, duplicates, and ids past the cap. Does not read receipts.
function ArenaSettle.sanitize(value: any, cap: number): { string }
	local keep = normalizeCap(cap)
	local seen: { [string]: boolean } = {}
	local ordered = {}
	if typeof(value) == "table" then
		for _, saved in ipairs(value) do
			if type(saved) == "string" and saved ~= "" and seen[saved] ~= true then
				seen[saved] = true
				table.insert(ordered, saved)
			end
		end
	end
	while #ordered > keep do
		table.remove(ordered, 1)
	end
	return ordered
end

-- Newest id is last. The oldest id falls off once the list is past the cap.
function ArenaSettle.remember(profile: any, id: string, cap: number): { string }
	local keep = normalizeCap(cap)
	local list = ArenaSettle.sanitize(if typeof(profile) == "table" then profile.arenaSettle else nil, keep)
	if type(id) ~= "string" or id == "" then
		if typeof(profile) == "table" then
			profile.arenaSettle = list
		end
		return list
	end
	local nextList = {}
	for _, saved in ipairs(list) do
		if saved ~= id then
			table.insert(nextList, saved)
		end
	end
	table.insert(nextList, id)
	while #nextList > keep do
		table.remove(nextList, 1)
	end
	if typeof(profile) == "table" then
		profile.arenaSettle = nextList
	end
	return nextList
end

-- Keys for one run id, or every old per-drop key when id is nil.
-- The receipt value is not read. Non-matching keys are not returned.
local function matchingKeys(receipts: any, id: string?): { string }
	local clear = {}
	if typeof(receipts) ~= "table" then
		return clear
	end
	for key in pairs(receipts) do
		local found = ArenaSettle.oldRunId(key)
		if found ~= nil and (id == nil or found == id) then
			table.insert(clear, key)
		end
	end
	return clear
end

local function clearKeys(receipts: any, keys: { string })
	if typeof(receipts) ~= "table" then
		return
	end
	for _, key in ipairs(keys) do
		receipts[key] = nil
	end
end

-- Removes old per-drop keys for this run only. Returns how many were removed.
-- Other receipt keys, including Robux purchase ids, are not written.
function ArenaSettle.dropOld(profile: any, id: string): number
	if typeof(profile) ~= "table" or type(id) ~= "string" then
		return 0
	end
	local clear = matchingKeys(profile.receipts, id)
	clearKeys(profile.receipts, clear)
	return #clear
end

-- True when this run was already settled under the old per-drop keys.
-- Those keys are removed and the run id is kept, bounded. Nothing is paid.
function ArenaSettle.consumeOld(profile: any, id: string, cap: number): boolean
	if ArenaSettle.dropOld(profile, id) == 0 then
		return false
	end
	ArenaSettle.remember(profile, id, cap)
	return true
end

-- Fold every old per-drop key into the bounded list, then delete those keys.
-- Ids already stored stay. They are newer than the leftover keys, so a full
-- list does not give its slots to migrated ids. Robux receipts stay put.
function ArenaSettle.adopt(profile: any, cap: number): number
	if typeof(profile) ~= "table" then
		return 0
	end
	local keep = normalizeCap(cap)
	local list = ArenaSettle.sanitize(profile.arenaSettle, keep)
	local clear = matchingKeys(profile.receipts, nil)
	table.sort(clear)
	local seen: { [string]: boolean } = {}
	for _, saved in ipairs(list) do
		seen[saved] = true
	end
	local migrated = {}
	for _, key in ipairs(clear) do
		local id = ArenaSettle.oldRunId(key)
		if id ~= nil and seen[id] ~= true then
			seen[id] = true
			table.insert(migrated, id)
		end
	end
	local room = keep - #list
	if room < 0 then
		room = 0
	end
	if #migrated > room then
		local startAt = #migrated - room + 1
		local tail = {}
		for index = startAt, #migrated do
			table.insert(tail, migrated[index])
		end
		migrated = tail
	end
	local combined = {}
	for _, id in ipairs(migrated) do
		table.insert(combined, id)
	end
	for _, id in ipairs(list) do
		table.insert(combined, id)
	end
	while #combined > keep do
		table.remove(combined, 1)
	end
	profile.arenaSettle = combined
	clearKeys(profile.receipts, clear)
	return #clear
end

return ArenaSettle
