--!strict
-- Ghost-side text for Echo's gear stages. Pure. No remotes, no writes.
--
--   revealNote(result)  the reveal-card line for a merged dupe or an
--                       auto-salvaged drop, or nil.
--   bagFull(ok, result) true when a roll was refused for a full Bag.
--   nudgeLabel(nudge)   "Salvage now" button text for a nudge answer, or
--                       nil when the server found nothing to salvage.
--
-- Full-bag salvage (GearBar) reads these too. Every one reads the server
-- snapshot it is given and never keeps its own copy of the setting:
--
--   autoRarity(profile)  the saved cap when auto-salvage is on, else nil.
--   autoLabel(profile)   "Auto-salvage: Off" / "Auto-salvage: Commons and below".
--   autoToggle(profile)  the explicit {enabled, rarity} a toggle press sends.
--   autoCap(profile)     the explicit {enabled, rarity} a cap press sends. It
--                        keeps enabled as the server has it.
--   pickBlock(profile, item)  why an item cannot be picked, else nil.
--   estimate(profile, uids)   count and Essence for the picked items.
--   salvageLabel(count, gain) the action bar text.
--   markBatch(items, profile) flags x10 rows that are not in the Bag.
--   batchLine(total, gone, gain) the line after an x10 with auto-salvage.

local Essence = require("./Config/Essence")
local InventoryView = require("./InventoryView")

local GearHooks = {}

GearHooks.SALVAGE_NOW = "Salvage now"

local function whole(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then
		return nil
	end
	return math.floor(value)
end

function GearHooks.revealNote(result: any): string?
	if type(result) ~= "table" then
		return nil
	end
	if result.merged == true then
		local text = result.levelText
		if type(text) ~= "string" or text == "" then
			local old = whole(result.oldLevel)
			local new = whole(result.newLevel)
			if old ~= nil and new ~= nil then
				text = string.format("★%d -> ★%d", old, new)
			else
				text = "Merged into your copy"
			end
		end
		local essence = whole(result.essence)
		if essence ~= nil and essence > 0 then
			text = string.format("%s  +%d Essence", text :: string, essence)
		end
		return text
	end
	if result.autoSalvaged == true then
		local gained = whole(result.essenceGained) or 0
		return string.format("Auto-salvaged  +%d Essence", gained)
	end
	return nil
end

local function reason(_ok: any, result: any): string?
	if type(result) == "string" then
		return result
	end
	if type(result) == "table" and type(result.error) == "string" then
		return result.error
	end
	return nil
end

function GearHooks.bagFull(ok: any, result: any): boolean
	local text = reason(ok, result)
	if text == nil then
		return false
	end
	local lower = string.lower(text)
	if string.find(lower, "full", 1, true) == nil then
		return false
	end
	return string.find(lower, "inventory", 1, true) ~= nil
		or string.find(lower, "bag", 1, true) ~= nil
end

function GearHooks.nudgeLabel(nudge: any): string?
	if type(nudge) ~= "table" or type(nudge.token) ~= "string" or nudge.token == "" then
		return nil
	end
	local count = whole(nudge.count) or 0
	if count <= 0 then
		return nil
	end
	local gain = whole(nudge.gain) or 0
	return string.format("%s  (%d for +%d Essence)", GearHooks.SALVAGE_NOW, count, gain)
end

-- The caps the Bag offers for auto-salvage. Rare is the highest; anything
-- above stays a manual choice.
GearHooks.AUTO_CAPS = table.freeze({ "Common", "Uncommon", "Rare" })
GearHooks.AUTO_OFF = "Auto-salvage: Off"
GearHooks.PICK_NONE = "Select items to salvage"

local function knownCap(rarity: any): boolean
	return type(rarity) == "string" and Essence.amount(rarity) ~= nil
end

function GearHooks.autoRarity(profile: any): string?
	if type(profile) ~= "table" or profile.autoSalvage ~= true then
		return nil
	end
	local rarity = profile.autoSalvageRarity
	if not knownCap(rarity) then
		return nil
	end
	return rarity
end

-- The saved cap even while auto-salvage is off. Common when none is saved.
function GearHooks.autoCapName(profile: any): string
	if type(profile) == "table" and knownCap(profile.autoSalvageRarity) then
		return profile.autoSalvageRarity
	end
	return "Common"
end

function GearHooks.autoLabel(profile: any): string
	local rarity = GearHooks.autoRarity(profile)
	if rarity == nil then
		return GearHooks.AUTO_OFF
	end
	return string.format("Auto-salvage: %ss and below", rarity)
end

function GearHooks.capLabel(profile: any): string
	return string.format("Auto cap: %s", GearHooks.autoCapName(profile))
end

function GearHooks.autoToggle(profile: any): { enabled: boolean, rarity: string }
	return {
		enabled = GearHooks.autoRarity(profile) == nil,
		rarity = GearHooks.autoCapName(profile),
	}
end

function GearHooks.autoCap(profile: any): { enabled: boolean, rarity: string }
	local current = GearHooks.autoCapName(profile)
	local nextCap = GearHooks.AUTO_CAPS[1]
	for index, rarity in ipairs(GearHooks.AUTO_CAPS) do
		if rarity == current then
			nextCap = GearHooks.AUTO_CAPS[(index % #GearHooks.AUTO_CAPS) + 1]
		end
	end
	return {
		enabled = GearHooks.autoRarity(profile) ~= nil,
		rarity = nextCap,
	}
end

local function itemFor(profile: any, uid: any): any
	if type(profile) ~= "table" or type(profile.inventory) ~= "table" or type(uid) ~= "string" then
		return nil
	end
	local item = profile.inventory[uid]
	if type(item) ~= "table" then
		return nil
	end
	return item
end

-- Short reason shown on a dimmed card. The server checks again on confirm.
function GearHooks.pickBlock(profile: any, item: any): string?
	if type(item) ~= "table" then
		return "Gone"
	end
	if item.kind ~= "Weapon" and item.kind ~= "Armor" then
		return "Not gear"
	end
	if item.favorite == true then
		return "Favorite"
	end
	local why = InventoryView.salvageBlock(profile, item)
	if why == nil then
		return nil
	end
	if item.locked == true then
		return "Locked"
	end
	if string.find(why, "Unequip", 1, true) ~= nil then
		return "Equipped"
	end
	return why
end

function GearHooks.estimate(profile: any, uids: any): (number, number)
	local count, gain = 0, 0
	if type(uids) ~= "table" then
		return 0, 0
	end
	for _, uid in ipairs(uids) do
		local item = itemFor(profile, uid)
		if item ~= nil and GearHooks.pickBlock(profile, item) == nil then
			count += 1
			gain += Essence.amount(item.rarity) or 0
		end
	end
	return count, gain
end

function GearHooks.salvageLabel(count: any, gain: any): string
	local n = whole(count) or 0
	if n <= 0 then
		return GearHooks.PICK_NONE
	end
	return string.format("Salvage %d for +%d Essence", n, whole(gain) or 0)
end

-- An x10 row whose item is not in the returned Bag and did not merge was
-- auto-salvaged on the server. Older servers leave that flag off the batch
-- rows, so the client marks it. Returns how many and the Essence.
function GearHooks.markBatch(items: any, profile: any): (number, number)
	if type(items) ~= "table" or type(profile) ~= "table" or type(profile.inventory) ~= "table" then
		return 0, 0
	end
	local gone, gain = 0, 0
	for _, row in ipairs(items) do
		if type(row) == "table" and row.merged ~= true then
			local item = row.item
			local uid = if type(item) == "table" then item.uid else nil
			if row.autoSalvaged ~= true and type(uid) == "string" and profile.inventory[uid] == nil then
				row.autoSalvaged = true
				if row.essenceGained == nil then
					row.essenceGained = Essence.amount(row.rarity or item.rarity) or 0
				end
			end
			if row.autoSalvaged == true then
				gone += 1
				gain += whole(row.essenceGained) or 0
			end
		end
	end
	return gone, gain
end

function GearHooks.batchLine(total: any, gone: any, gain: any): string?
	local n = whole(total) or 0
	local salvaged = whole(gone) or 0
	if n <= 0 or salvaged <= 0 then
		return nil
	end
	return string.format(
		"x%d done: %d auto-salvaged (+%d Essence), %d kept.",
		n,
		salvaged,
		whole(gain) or 0,
		math.max(0, n - salvaged)
	)
end

return GearHooks
