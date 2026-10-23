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
--
-- The full inventory header and the Shard Core card read these:
--
--   autoPill(profile)    pill text and whether auto-salvage is on.
--   coreGroups(preview, selectedUid)  Shard Core feed targets grouped by
--                        name, rarity and core level, with a count, so ten
--                        copies read "Beastbone Hammer x10", not ten rows.
--   coreHeader(level)    "Shard Core  Lv 2/5".
--   coreNext(level, essence)  the next-level line and whether it can feed.
--   levelLine(item)      "+3  ★★☆☆☆" for the detail header.

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

-- The header pill. On reads as a warning so a saved "On" cannot hide.
function GearHooks.autoPill(profile: any): (string, boolean)
	local rarity = GearHooks.autoRarity(profile)
	if rarity == nil then
		return "Auto-salvage: Off", false
	end
	return string.format("⚠ Auto-salvage ON: %ss and below", rarity), true
end

GearHooks.CORE_CAP = 5

export type CoreGroup = {
	key: string,
	name: string,
	rarity: string,
	level: number,
	count: number,
	uid: string,
	uids: { string },
	label: string,
	selected: boolean,
	canFeed: boolean,
	capped: boolean,
	nextCost: number?,
	status: string,
}

-- Groups the preview's weapons (one row per copy) by what the player can
-- tell apart: name, rarity and core level. uid is the copy a feed goes
-- to: the selected one when it is in the group, else the first by uid.
-- The selected weapon's group comes first, then by name, rarity, level.
function GearHooks.coreGroups(preview: any, selectedUid: any): { CoreGroup }
	local groups: { CoreGroup } = {}
	if type(preview) ~= "table" or type(preview.weapons) ~= "table" then
		return groups
	end
	local byKey: { [string]: CoreGroup } = {}
	for _, row in ipairs(preview.weapons) do
		if type(row) == "table" and type(row.uid) == "string" then
			local name = if type(row.name) == "string" and row.name ~= "" then row.name else "Weapon"
			local rarity = if type(row.rarity) == "string" then row.rarity else ""
			local level = whole(row.level) or 0
			local key = string.format("%s|%s|%d", name, rarity, level)
			local group = byKey[key]
			if group == nil then
				group = {
					key = key,
					name = name,
					rarity = rarity,
					level = level,
					count = 0,
					uid = row.uid,
					uids = {},
					label = "",
					selected = false,
					canFeed = row.canFeed == true,
					capped = row.capped == true,
					nextCost = whole(row.nextCost),
					status = if type(row.status) == "string" then row.status else "",
				}
				byKey[key] = group
				table.insert(groups, group)
			end
			local g = group :: CoreGroup
			g.count += 1
			table.insert(g.uids, row.uid)
			if row.uid == selectedUid then
				g.uid = row.uid
				g.selected = true
			elseif not g.selected and row.uid < g.uid then
				g.uid = row.uid
			end
		end
	end
	for _, group in ipairs(groups) do
		table.sort(group.uids)
		local copies = if group.count > 1 then string.format(" x%d", group.count) else ""
		group.label = string.format("%s%s  ·  Core Lv %d", group.name, copies, group.level)
	end
	table.sort(groups, function(a, b)
		if a.selected ~= b.selected then
			return a.selected
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		if a.rarity ~= b.rarity then
			return a.rarity < b.rarity
		end
		return a.level < b.level
	end)
	return groups
end

function GearHooks.coreHeader(level: any): string
	return string.format("Shard Core  Lv %d/%d", math.min(whole(level) or 0, GearHooks.CORE_CAP), GearHooks.CORE_CAP)
end

-- costs: Echo's ShardCore.COST. Returns the line and whether a feed fits.
function GearHooks.coreNext(level: any, essence: any, costs: any): (string, boolean)
	local current = whole(level) or 0
	local held = whole(essence) or 0
	if current >= GearHooks.CORE_CAP then
		return "Core is at its cap.", false
	end
	local cost = if type(costs) == "table" then whole(costs[current + 1]) else nil
	if cost == nil then
		return "Core is at its cap.", false
	end
	if held < cost then
		return string.format("Next level: %d Essence (you have %d)", cost, held), false
	end
	return string.format("Next level: %d Essence", cost), true
end

function GearHooks.levelLine(item: any): string
	if type(item) ~= "table" then
		return ""
	end
	local parts = {}
	local level = whole(tonumber(item.upgrade)) or 0
	if level > 0 then
		table.insert(parts, "+" .. tostring(level))
	end
	local stars = whole(tonumber(item.stars)) or 0
	if stars > 0 then
		stars = math.min(5, stars)
		table.insert(parts, string.rep("★", stars) .. string.rep("☆", 5 - stars))
	end
	return table.concat(parts, "  ")
end

-- Auto-salvage safety (Kevin, Oct 23). The client offers and sends only
-- these caps. A saved Rare+ cap is shown as-is (never rewritten quietly)
-- and the settings popover offers to lower it.
GearHooks.AUTO_SAFE = table.freeze({ "Common", "Uncommon" })

local CAP_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

function GearHooks.capRank(rarity: any): number
	return if type(rarity) == "string" and CAP_RANK[rarity] ~= nil then CAP_RANK[rarity] else 0
end

-- The cap the client may send: Common or Uncommon. Anything higher is
-- clamped to Uncommon; anything unknown reads as Common.
function GearHooks.safeCap(rarity: any): string
	local rank = GearHooks.capRank(rarity)
	if rank >= 2 then
		return "Uncommon"
	end
	return "Common"
end

-- True when the saved cap is above what the client allows.
function GearHooks.capUnsafe(profile: any): boolean
	return type(profile) == "table" and GearHooks.capRank(profile.autoSalvageRarity) > 2
end

-- The {enabled, rarity} a popover change sends, clamped. want.rarity is
-- what the player picked; nil keeps the saved (clamped) cap.
function GearHooks.autoWant(profile: any, enabled: boolean, rarity: any): { enabled: boolean, rarity: string }
	local pick = if rarity ~= nil then rarity else GearHooks.autoCapName(profile)
	return { enabled = enabled == true, rarity = GearHooks.safeCap(pick) }
end

-- The confirm text when a change turns auto-salvage on or raises its cap,
-- else nil (turning it off or lowering the cap never asks).
function GearHooks.autoAsk(profile: any, want: any): string?
	if type(want) ~= "table" or want.enabled ~= true then
		return nil
	end
	local cap = GearHooks.safeCap(want.rarity)
	local current = GearHooks.autoRarity(profile)
	if current == nil then
		return string.format("Auto-salvage will destroy new %s and lower drops. Turn on?", cap)
	end
	if GearHooks.capRank(cap) > GearHooks.capRank(current) then
		return string.format("Auto-salvage will destroy new %s and lower drops. Raise the cap?", cap)
	end
	return nil
end

-- The action-bar pill: short, and honest about a saved unsafe cap.
function GearHooks.autoChip(profile: any): (string, boolean)
	local rarity = GearHooks.autoRarity(profile)
	if rarity == nil then
		return "Auto-salvage: Off", false
	end
	return string.format("Auto-salvage: ≤ %s", rarity), true
end

local KIND_FOR_TAB = { weapons = "Weapon", armor = "Armor" }
local TAB_NAME = { weapons = "Weapons", armor = "Armor" }

-- Why "select all at or below cap" found nothing in this tab, or nil when
-- something qualifies. e.g. "No unlocked, unequipped Commons in Weapons."
function GearHooks.pickEmpty(profile: any, cap: any, tab: any): string?
	local capName = if type(cap) == "string" then cap else "Common"
	local where = TAB_NAME[tab] or "your Bag"
	local kind = KIND_FOR_TAB[tab]
	local noun = if capName == "Common" then "Commons" else capName .. "s or lower"
	local inventory = if type(profile) == "table" and type(profile.inventory) == "table"
		then profile.inventory
		else {}
	local limit = GearHooks.capRank(capName)
	local any, free = 0, 0
	local locked, worn, fav = 0, 0, 0
	for uid, item in pairs(inventory) do
		if type(item) == "table" and (item.kind == "Weapon" or item.kind == "Armor") then
			if (kind == nil or item.kind == kind) and GearHooks.capRank(item.rarity) <= limit and GearHooks.capRank(item.rarity) > 0 then
				any += 1
				local probe = item
				if type(probe.uid) ~= "string" then
					probe = table.clone(item)
					probe.uid = uid
				end
				local why = GearHooks.pickBlock(profile, probe)
				if why == nil then
					free += 1
				elseif why == "Locked" then
					locked += 1
				elseif why == "Equipped" then
					worn += 1
				elseif why == "Favorite" then
					fav += 1
				end
			end
		end
	end
	if free > 0 then
		return nil
	end
	if any == 0 then
		return string.format("No %s in %s.", noun, where)
	end
	local bits = {}
	if locked > 0 then
		table.insert(bits, string.format("%d locked", locked))
	end
	if worn > 0 then
		table.insert(bits, string.format("%d equipped", worn))
	end
	if fav > 0 then
		table.insert(bits, string.format("%d favorite", fav))
	end
	local tail = if #bits > 0 then " (" .. table.concat(bits, ", ") .. ")" else ""
	return string.format("No unlocked, unequipped %s in %s%s.", noun, where, tail)
end

return GearHooks
