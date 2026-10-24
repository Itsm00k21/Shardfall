--!strict

--[[
	Studio buttons for Stage A. Both mutate only through the caller's
	profile table. Fill adds new rows. It does not delete or edit an
	item that was already in the bag. Grant-a-dupe feeds one 100% quality
	copy into an owned piece (one star) and otherwise inserts one piece
	at ★0. It does not write item.upgrade or item.level.
]]

local Accept = require("./Accept")

local Dev = {}

local function countItems(profile: any): number
	local count = 0
	local bags = { profile.inventory, profile.pets }
	for _, bag in ipairs(bags) do
		if type(bag) == "table" then
			for _ in pairs(bag) do
				count += 1
			end
		end
	end
	return count
end

local function owns(profile: any, uid: string): boolean
	if type(profile.inventory) == "table" and profile.inventory[uid] ~= nil then
		return true
	end
	if type(profile.pets) == "table" and profile.pets[uid] ~= nil then
		return true
	end
	return false
end

local function insert(profile: any, item: any)
	if item.kind == "Pet" then
		if type(profile.pets) ~= "table" then
			profile.pets = {}
		end
		profile.pets[item.uid] = item
		return
	end
	if type(profile.inventory) ~= "table" then
		profile.inventory = {}
	end
	profile.inventory[item.uid] = item
end

local function firstOwned(profile: any): any
	local best = nil
	local bestUid = nil
	local bags = { profile.inventory, profile.pets }
	for _, bag in ipairs(bags) do
		if type(bag) == "table" then
			for uid, item in pairs(bag) do
				if type(uid) == "string" and type(item) == "table" and type(item.templateId) == "string" then
					if bestUid == nil or uid < bestUid then
						best = item
						bestUid = uid
					end
				end
			end
		end
	end
	return best
end

local function starterBase(bases: { any }): any
	local fallback = nil
	for _, base in ipairs(bases) do
		if type(base) == "table" and type(base.id) == "string" then
			if base.id == "bramble_fang" then
				return base
			end
			if fallback == nil and base.kind == "Weapon" then
				fallback = base
			end
		end
	end
	return fallback
end

function Dev.grantDupe(profile: any, bases: { any }, config: any, cap: number?, starsMod: any): (boolean, string)
	if type(profile) ~= "table" then
		return false, "Profile is not loaded."
	end
	local room = 100
	if type(cap) == "number" and cap == cap and cap >= 1 and cap < math.huge then
		room = math.floor(cap)
	end
	local owned = firstOwned(profile)
	if owned == nil then
		local base = starterBase(bases)
		if base == nil then
			return false, "No gear to grant."
		end
		if countItems(profile) >= room then
			return false, "Bag is full."
		end
		local item = {
			uid = "dev-dupe-1",
			templateId = base.id,
			name = base.name,
			kind = base.kind,
			rarity = base.rarity,
			traits = {},
			stats = {},
			poolId = "dev",
			obtainedAt = 0,
		}
		if owns(profile, item.uid) then
			return false, "Could not grant that."
		end
		insert(profile, item)
		return true, string.format("Granted %s at ★0.", tostring(base.name))
	end
	local before = countItems(profile)
	local upgradeBefore = owned.upgrade
	local landing = Accept.accept(profile, {
		templateId = owned.templateId,
		name = owned.name,
		kind = owned.kind,
		rarity = owned.rarity,
		uid = "dev-dupe-incoming",
		quality = 1,
	}, true, config, nil, starsMod)
	if countItems(profile) ~= before then
		return false, "A dupe must not take a Bag slot."
	end
	if landing.merged ~= true then
		return false, "Could not grant that."
	end
	if owned.upgrade ~= upgradeBefore or owned.level ~= nil then
		owned.upgrade = upgradeBefore
		owned.level = nil
		return false, "Could not grant that."
	end
	if landing.action == "essence" then
		return true, string.format(
			"%s is at ★%d. Essence +%d (now %d).",
			tostring(owned.name),
			landing.newLevel or 0,
			landing.essence or 0,
			if type(profile.gearEssence) == "number" then profile.gearEssence else 0
		)
	end
	if type(landing.levelText) == "string" then
		return true, landing.levelText .. "."
	end
	return true, string.format("%s ★%d.", tostring(owned.name), landing.newLevel or 0)
end

function Dev.fillBag(profile: any, bases: { any }, cap: number): (boolean, string)
	if type(profile) ~= "table" then
		return false, "Profile is not loaded."
	end
	if type(cap) ~= "number" or cap < 1 then
		cap = 100
	end
	cap = math.floor(cap)
	if #bases == 0 then
		return false, "No gear to grant."
	end
	local before = countItems(profile)
	if before >= cap then
		return true, string.format("Bag is already full (%d/%d).", before, cap)
	end
	local added = 0
	local serial = 0
	local limit = cap + before + 2
	while countItems(profile) < cap and added < cap and serial < limit do
		serial += 1
		local base = bases[((serial - 1) % #bases) + 1]
		if type(base) ~= "table" or type(base.id) ~= "string" then
			return false, "No gear to grant."
		end
		local uid = string.format("devfill-%d", serial)
		if not owns(profile, uid) then
			insert(profile, {
				uid = uid,
				templateId = base.id,
				name = base.name,
				kind = base.kind,
				rarity = base.rarity,
				traits = {},
				stats = {},
				poolId = "dev",
				obtainedAt = 0,
			})
			added += 1
		end
	end
	return true, string.format("Filled the Bag with %d. Now %d/%d.", added, countItems(profile), cap)
end

return Dev
