--!strict

--[[
	Duplicate landing for Stage A.

	An exact duplicate is the same templateId. The new copy is not
	inserted and does not take a Bag slot. The owned copy gains 1
	forge upgrade (item.upgrade). At Economy.UPGRADE_MAX the upgrade
	stays and the overflow amount from config is recorded. Nothing
	else on the owned item changes: stats, uid, and equipped stay put.
	item.level is never written.

	enabled false does not read or write the profile. The caller inserts
	the new item the way it always has.

	migrate() copies first. The caller's table is not edited. That is
	the #381 shape. item.upgrade is already saved, so this step does
	not add a level field. It only fills gearEssence on the copy.
	schemaVersion stays 26. After #381 lands, a future step can call
	migrate on the copy. Do not bump the version here.
]]

local Accept = {}

export type Landing = {
	action: string,
	item: any,
	oldLevel: number?,
	newLevel: number?,
	essence: number?,
	levelText: string?,
	merged: boolean,
}

local function blankInsert(item: any): Landing
	return {
		action = "insert",
		item = item,
		oldLevel = nil,
		newLevel = nil,
		essence = nil,
		levelText = nil,
		merged = false,
	}
end

local function eachItem(profile: any, visit: (string, any) -> ())
	local bags = { profile.inventory, profile.pets }
	for _, bag in ipairs(bags) do
		if type(bag) == "table" then
			for uid, item in pairs(bag) do
				if type(uid) == "string" and type(item) == "table" then
					visit(uid, item)
				end
			end
		end
	end
end

function Accept.spareRoom(profile: any, enabled: boolean): boolean
	if enabled ~= true or type(profile) ~= "table" then
		return false
	end
	local found = false
	eachItem(profile, function(_uid, item)
		if type(item.templateId) == "string" and item.templateId ~= "" then
			found = true
		end
	end)
	return found
end

local function equippedSet(profile: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local equipped = profile.equipped
	if type(equipped) == "table" then
		if type(equipped.weapon) == "string" then
			set[equipped.weapon] = true
		end
		if type(equipped.pet) == "string" then
			set[equipped.pet] = true
		end
		local groups = { equipped.armor, equipped.accessories }
		for _, group in ipairs(groups) do
			if type(group) == "table" then
				for _, uid in pairs(group) do
					if type(uid) == "string" then
						set[uid] = true
					end
				end
			end
		end
	end
	if type(profile.equipLoadout) == "table" then
		for _, uid in pairs(profile.equipLoadout) do
			if type(uid) == "string" and uid ~= "" then
				set[uid] = true
			end
		end
	end
	return set
end

local function stored(config: any, item: any): number
	return config.storedUpgrade(item.upgrade)
end

local function better(cand: any, current: any, equipped: { [string]: boolean }, config: any): boolean
	if current == nil then
		return true
	end
	local cap = config.capFor(cand.item.rarity)
	local level = stored(config, cand.item)
	local curCap = config.capFor(current.item.rarity)
	local curLevel = stored(config, current.item)
	local candUnder = level < cap
	local curUnder = curLevel < curCap
	if candUnder ~= curUnder then
		return candUnder
	end
	if candUnder then
		local candEq = equipped[cand.uid] == true
		local curEq = equipped[current.uid] == true
		if candEq ~= curEq then
			return candEq
		end
		if level ~= curLevel then
			return level < curLevel
		end
	end
	return cand.uid < current.uid
end

local function findOwned(profile: any, templateId: string, config: any): any
	local equipped = equippedSet(profile)
	local best = nil
	eachItem(profile, function(uid, item)
		if item.templateId == templateId then
			local cand = { uid = uid, item = item }
			if better(cand, best, equipped, config) then
				best = cand
			end
		end
	end)
	return best
end

-- Adds the overflow onto profile.gearEssence unless hook replaces that.
function Accept.record(profile: any, amount: number, hook: ((any, number) -> ())?): number
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount >= math.huge then
		return 0
	end
	local whole = math.floor(amount)
	if type(hook) == "function" then
		hook(profile, whole)
		return whole
	end
	local current = profile.gearEssence
	if type(current) ~= "number" or current ~= current or current < 0 or current >= math.huge then
		current = 0
	end
	profile.gearEssence = math.floor(current) + whole
	return whole
end

function Accept.accept(profile: any, item: any, enabled: boolean, config: any, hook: ((any, number) -> ())?): Landing
	if enabled ~= true or type(config) ~= "table" then
		return blankInsert(item)
	end
	if type(profile) ~= "table" or type(item) ~= "table" or type(item.templateId) ~= "string" then
		return blankInsert(item)
	end
	if item.templateId == "" then
		return blankInsert(item)
	end
	local owned = findOwned(profile, item.templateId, config)
	if owned == nil then
		return blankInsert(item)
	end
	local oldLevel = stored(config, owned.item)
	local cap = config.capFor(owned.item.rarity)
	if oldLevel >= cap then
		local amount = Accept.record(profile, config.essenceFor(owned.item.rarity), hook)
		return {
			action = "essence",
			item = owned.item,
			oldLevel = oldLevel,
			newLevel = oldLevel,
			essence = amount,
			levelText = nil,
			merged = true,
		}
	end
	local newLevel = oldLevel + 1
	owned.item.upgrade = newLevel
	return {
		action = "level",
		item = owned.item,
		oldLevel = oldLevel,
		newLevel = newLevel,
		essence = 0,
		levelText = config.levelText(owned.item.name, oldLevel, newLevel),
		merged = true,
	}
end

local function deepCopy(value: any, depth: number): any
	if type(value) ~= "table" then
		return value
	end
	if depth > 32 then
		return nil
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child, depth + 1)
	end
	return copy
end

-- Copy first. Upgrade values stay as they were saved. No item.level.
function Accept.migrate(raw: any): (any?, string?)
	if type(raw) ~= "table" then
		return nil, "corrupt"
	end
	local copy = deepCopy(raw, 0)
	local essence = copy.gearEssence
	if type(essence) ~= "number" or essence ~= essence or essence < 0 or essence >= math.huge then
		copy.gearEssence = 0
	else
		copy.gearEssence = math.floor(essence)
	end
	return copy, nil
end

return Accept
