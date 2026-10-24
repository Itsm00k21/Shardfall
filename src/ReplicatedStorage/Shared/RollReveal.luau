--!strict

--[[
	One resolved roll, played once.

	The server mints the item and a roll id before the client animates.
	The spin lands on that id and the card reads the same record, so a
	later roll cannot paint the previous name over this one. A miss has
	no record. Its card is hidden and blank, so the previous name cannot
	stay on screen, and it does not invent a near-miss.

	Full playback is 1.65s. Short is 0.7s. Instant and the skip threshold
	are 0. A paid roll never runs longer than the free roll with the same
	settings. The strip does not tease a higher rarity in the landing slots.
]]

local HudLayout = require("./HudLayout")
local Rarities = require("./Rarities")
local RarityConfig = require("./RarityConfig")
local Settings = require("./Settings")

local RollReveal = {}

export type Record = {
	id: string,
	name: string,
	rarity: string,
}

export type Face = {
	visible: boolean,
	name: string,
	rarity: string,
}

export type Slot = {
	name: string,
	rarity: string,
}

RollReveal.FULL = 1.65
local DIM_END = 0.15
local FAST_END = 0.6
local SLOW_END = 1.3
local HOLD_END = 1.4
local GLOW_AT = 1.0
local FLASH_AT = 1.15
local FLASH_WINDOW = 0.5
local FLASH_GAP = 1 / 3
local FLASH_HOLD = 0.08

local function rankOf(rarity: string): number
	local rank = Rarities.INDEX[rarity]
	if rank == nil then
		return 0
	end
	return rank
end

local function epicOrBetter(rarity: string): boolean
	return rankOf(rarity) >= rankOf("Epic")
end

local function legendaryOrBetter(rarity: string): boolean
	return rankOf(rarity) >= rankOf("Legendary")
end

function RollReveal.capture(result: any): Record?
	if type(result) ~= "table" or type(result.item) ~= "table" then
		return nil
	end
	local item = result.item
	local id = result.rollId
	if type(id) ~= "string" or id == "" then
		id = item.uid
	end
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local name = item.name
	if type(name) ~= "string" or name == "" then
		name = "Shard"
	end
	local rarity = item.rarity
	if type(rarity) ~= "string" or rarity == "" then
		rarity = if type(result.rarity) == "string" then result.rarity else "Common"
	end
	return {
		id = id,
		name = name,
		rarity = rarity,
	}
end

-- Spin landing and the card both return this. They cannot disagree.
function RollReveal.present(record: Record): Record
	return {
		id = record.id,
		name = record.name,
		rarity = record.rarity,
	}
end

-- The card for this result. A miss is hidden and blank so the previous
-- name cannot stay up. A land shows that record only. No near-miss, no
-- odds, and paid is not a separate face.
function RollReveal.face(record: Record?): Face
	if record == nil then
		return {
			visible = false,
			name = "",
			rarity = "",
		}
	end
	return {
		visible = true,
		name = record.name,
		rarity = record.rarity,
	}
end

-- Reel caption when the roll did not land. The words are the server's
-- reason, unchanged. A missing reason, a blank reason, or a non-result
-- stays "Miss". paid does not rewrite it.
function RollReveal.reelCaption(result: any): string
	if type(result) ~= "table" then
		return "Miss"
	end
	local reason = result.error
	if type(reason) ~= "string" then
		return "Miss"
	end
	if string.find(reason, "\n", 1, true) ~= nil then
		return "Miss"
	end
	local trimmed = string.match(reason, "^%s*(.-)%s*$")
	if trimmed == nil or trimmed == "" then
		return "Miss"
	end
	return trimmed
end

function RollReveal.duration(settings: Settings.Data, rarity: string, paid: boolean): number
	local seconds = Settings.rollDuration(settings)
	if Settings.skipsCutscene(settings, rarity) then
		seconds = 0
	end
	if paid then
		local free = RollReveal.duration(settings, rarity, false)
		if seconds > free then
			seconds = free
		end
	end
	return seconds
end

function RollReveal.quadIn(t: number): number
	return t * t
end

function RollReveal.quintOut(t: number): number
	local inv = 1 - t
	return 1 - inv * inv * inv * inv * inv
end

function RollReveal.backOut(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local shifted = t - 1
	return 1 + c3 * shifted * shifted * shifted + c1 * shifted * shifted
end

local function scaled(elapsed: number, duration: number): number
	if duration <= 0 then
		return RollReveal.FULL
	end
	return elapsed / duration * RollReveal.FULL
end

local function fullTime(elapsed: number, duration: number): number
	return math.clamp(scaled(elapsed, duration), 0, RollReveal.FULL)
end

function RollReveal.dim(elapsed: number, duration: number): number
	if duration <= 0 then
		return 1
	end
	return math.clamp(fullTime(elapsed, duration) / DIM_END, 0, 1)
end

function RollReveal.skipReady(elapsed: number, duration: number): boolean
	return duration > 0 and elapsed >= 0
end

function RollReveal.spinProgress(elapsed: number, duration: number): number
	if duration <= 0 then
		return 1
	end
	local t = fullTime(elapsed, duration)
	if t <= DIM_END then
		return 0
	end
	if t >= SLOW_END then
		return 1
	end
	if t < FAST_END then
		local u = (t - DIM_END) / (FAST_END - DIM_END)
		return 0.72 * RollReveal.quadIn(u)
	end
	local u = (t - FAST_END) / (SLOW_END - FAST_END)
	return 0.72 + 0.28 * RollReveal.quintOut(u)
end

function RollReveal.glow(elapsed: number, duration: number, rarity: string): boolean
	if duration <= 0 or not epicOrBetter(rarity) then
		return false
	end
	local t = fullTime(elapsed, duration)
	return t >= GLOW_AT and t < HOLD_END
end

-- 0..1 while the model becomes the card. nil before that window.
function RollReveal.morph(elapsed: number, duration: number): number?
	if duration <= 0 then
		return 1
	end
	local t = fullTime(elapsed, duration)
	if t < HOLD_END then
		return nil
	end
	return math.clamp((t - HOLD_END) / (RollReveal.FULL - HOLD_END), 0, 1)
end

function RollReveal.morphScale(u: number): number
	return 0.85 + 0.15 * RollReveal.backOut(math.clamp(u, 0, 1))
end

function RollReveal.flashOn(elapsed: number, duration: number, rarity: string): boolean
	if duration <= 0 or not legendaryOrBetter(rarity) then
		return false
	end
	local localT = scaled(elapsed, duration) - FLASH_AT
	if localT < 0 or localT > FLASH_WINDOW then
		return false
	end
	local index = math.floor(localT / FLASH_GAP + 1e-6)
	local into = localT - index * FLASH_GAP
	return index < 2 and into <= FLASH_HOLD
end

function RollReveal.particles(elapsed: number, duration: number, rarity: string): boolean
	if duration <= 0 or not legendaryOrBetter(rarity) then
		return false
	end
	local localT = scaled(elapsed, duration) - FLASH_AT
	return localT >= 0 and localT <= FLASH_WINDOW
end

function RollReveal.strip(seed: number, pool: any, record: Record): { Slot }
	local slots = RarityConfig.reel(seed, pool, 1, record.name, record.rarity)
	local limit = rankOf(record.rarity)
	local standIn: Slot = { name = record.name, rarity = record.rarity }
	for _, row in ipairs(slots) do
		if rankOf(row.rarity) <= limit and row.name ~= record.name then
			standIn = { name = row.name, rarity = row.rarity }
			break
		end
	end
	local start = math.max(1, #slots - 4)
	for index = start, #slots - 1 do
		local row = slots[index]
		if rankOf(row.rarity) > limit then
			slots[index] = { name = standIn.name, rarity = standIn.rarity }
		end
	end
	slots[#slots] = { name = record.name, rarity = record.rarity }
	return slots
end

export type Rect = { x: number, y: number, w: number, h: number }

function RollReveal.nameRect(viewportX: number, viewportY: number, margin: number): Rect
	local health = HudLayout.health(margin)
	local width = math.min(360, math.max(160, viewportX - margin * 2))
	local x = math.floor((viewportX - width) / 2)
	local y = math.floor(viewportY * 0.62)
	local minY = health.y + health.h + 8
	if y < minY then
		y = minY
	end
	if y + 40 > viewportY - 8 then
		y = math.max(minY, viewportY - 48)
	end
	return { x = x, y = y, w = width, h = 40 }
end

function RollReveal.separated(a: Rect, b: Rect): boolean
	return a.y + a.h <= b.y or b.y + b.h <= a.y or a.x + a.w <= b.x or b.x + b.w <= a.x
end

-- What the reveal card shows, so no state is ever a bare "Shard" title on
-- an empty body (Kevin, Oct 22 9:55 PM). `icon` is an IconAssets key.
export type CardFace = {
	icon: string,
	title: string,
	rarity: string,
	detail: string,
}

local KIND_ICON = {
	Weapon = "ItemWeapon",
	Armor = "ItemArmor",
	Relic = "ItemRelic",
	Accessory = "ItemAccessory",
	Pet = "Pets",
}

-- The card while the crystal is still cracking: the shard itself, never a
-- blank. index/total give "Card 3 of 10" on an x10 or auto batch.
function RollReveal.pendingFace(index: any, total: any): CardFace
	local detail = "Cracking for gear"
	if type(total) == "number" and total > 1 and type(index) == "number" and index >= 1 then
		detail = string.format("Card %d of %d", math.min(math.floor(index), math.floor(total)), math.floor(total))
	end
	return {
		icon = "Shards",
		title = "Shard",
		rarity = "Cracking...",
		detail = detail,
	}
end

-- The landed card. Gear gets its kind icon and its first two stat lines.
-- A currency result (no templateId, a numeric amount) reads "+N Shards".
function RollReveal.cardFace(item: any, record: Record, statLines: { string }?): CardFace
	local rarity = RarityConfig.revealText(record.rarity)
	if type(item) == "table" and type(item.templateId) ~= "string" and type(item.amount) == "number" then
		local amount = math.max(0, math.floor(item.amount))
		return {
			icon = "Shards",
			title = string.format("+%d %s", amount, if amount == 1 then "Shard" else "Shards"),
			rarity = rarity,
			detail = "Added to your Shards",
		}
	end
	local kind = if type(item) == "table" and type(item.kind) == "string" then item.kind else ""
	local lines = {}
	for _, line in ipairs(statLines or {}) do
		if type(line) == "string" and line ~= "" and #lines < 2 then
			table.insert(lines, line)
		end
	end
	local detail = table.concat(lines, "  ·  ")
	if detail == "" then
		detail = if kind ~= "" then kind else "Gear"
	end
	return {
		icon = KIND_ICON[kind] or "ItemMisc",
		title = record.name,
		rarity = rarity,
		detail = detail,
	}
end

return RollReveal
