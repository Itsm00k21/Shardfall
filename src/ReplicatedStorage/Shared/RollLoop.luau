--!strict

--[[
	The roll tab stays open. One press starts a reveal. A second press
	while the card is morphing queues one more roll. A third press does
	nothing until that queued roll starts.

	Durations follow Settings (Full / Short / Instant) and reduced motion.
	Commons stay near 0.6s. Epic and above keep the longer path.
	The tint is the real rarity. Nothing teases a higher one.
	The drip is the one item that entered the bag, not invented XP.
	"Next Epic" is the real pity remainder. Rare has no countdown.
]]

local InventoryView = require("./InventoryView")
local ItemBases = require("./ItemBases")
local Rarities = require("./Rarities")
local RarityConfig = require("./RarityConfig")
local RollConfig = require("./RollConfig")
local RollBoard = require("./RollBoard")
local RollReveal = require("./RollReveal")
local Schema = require("./Schema")
local Settings = require("./Settings")
local UiMotion = require("./UiMotion")

local RollLoop = {}

export type Phase = "idle" | "revealing"

export type Queue = {
	phase: Phase,
	queued: boolean,
}

export type StopInput = {
	auto: boolean,
	tokens: number,
	bagFull: boolean,
	rarity: string,
	stopAt: string,
	isNew: boolean,
	isUpgrade: boolean,
}

RollLoop.QUICK_COMMON = 0.6

function RollLoop.idle(): Queue
	return { phase = "idle", queued = false }
end

function RollLoop.press(state: Queue): Queue
	if state.phase ~= "revealing" then
		return { phase = "revealing", queued = false }
	end
	return { phase = "revealing", queued = true }
end

function RollLoop.finish(state: Queue): Queue
	if state.queued then
		return { phase = "revealing", queued = false }
	end
	return { phase = "idle", queued = false }
end

local function rankOf(rarity: string): number
	local rank = Rarities.INDEX[rarity]
	if type(rank) ~= "number" then
		return 0
	end
	return rank
end

function RollLoop.seconds(
	settings: Settings.Data,
	rarity: string,
	quick: boolean,
	reduced: boolean
): number
	if reduced then
		return 0
	end
	local base = RollReveal.duration(settings, rarity, false)
	if base <= 0 then
		return 0
	end
	local rank = rankOf(rarity)
	if rank <= rankOf("Uncommon") then
		return RollLoop.QUICK_COMMON
	end
	if rank == rankOf("Rare") then
		if settings.rolls.animation == "short" then
			return math.min(base, 0.7)
		end
		if quick then
			return 0.9
		end
		return 1.1
	end
	if settings.rolls.animation == "short" then
		return math.min(base, 0.7)
	end
	if quick then
		return math.min(base, 1.1)
	end
	return base
end

-- Rolls left before the free Legendary guarantee (Phase 1.3: the only
-- pity). 0 means the guarantee is spent on the next roll.
function RollLoop.nextLegendary(sinceLegendary: any): number
	local since = 0
	if type(sinceLegendary) == "number" and sinceLegendary == sinceLegendary and sinceLegendary > 0 then
		since = math.floor(sinceLegendary)
	end
	local left = RarityConfig.LEGENDARY_PITY - since
	if left < 0 then
		return 0
	end
	return left
end

function RollLoop.nearGuarantee(sinceLegendary: any): boolean
	local left = RollLoop.nextLegendary(sinceLegendary)
	return left <= math.floor(RarityConfig.LEGENDARY_PITY * RollConfig.NEAR_SHARE)
end

function RollLoop.tint(elapsed: number, duration: number, rarity: string): string?
	if duration <= 0 then
		return nil
	end
	local progress = RollReveal.spinProgress(elapsed, duration)
	if progress >= 0.72 and progress < 1 then
		return rarity
	end
	return nil
end

function RollLoop.slowmo(
	elapsed: number,
	duration: number,
	rarity: string,
	reduced: boolean
): boolean
	if reduced or duration <= 0 or rankOf(rarity) < rankOf("Epic") then
		return false
	end
	local progress = RollReveal.spinProgress(elapsed, duration)
	return progress >= 0.92 and progress < 1
end

function RollLoop.flash(rarity: string, reduced: boolean, photosensitive: boolean): boolean
	if reduced or photosensitive then
		return false
	end
	return rankOf(rarity) >= rankOf("Epic")
end

function RollLoop.stinger(rarity: string, reduced: boolean): boolean
	if reduced then
		return false
	end
	return rankOf(rarity) >= rankOf("Epic")
end

function RollLoop.anticipates(rarity: string, reduced: boolean): boolean
	if reduced then
		return false
	end
	return rankOf(rarity) >= rankOf("Rare")
end

function RollLoop.drip(): { amount: number, text: string }
	return { amount = 1, text = "+1" }
end

function RollLoop.streak(current: number, ok: boolean): number
	if not ok then
		return 0
	end
	if type(current) ~= "number" or current ~= current or current < 0 then
		return 1
	end
	return math.floor(current) + 1
end

function RollLoop.isNew(templateId: any, owned: { [string]: boolean }): boolean
	if type(templateId) ~= "string" or templateId == "" then
		return false
	end
	return owned[templateId] ~= true
end

function RollLoop.ownedTemplates(profile: any, exceptUid: string?): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	if type(profile) ~= "table" then
		return owned
	end
	local function take(bag: any)
		if type(bag) ~= "table" then
			return
		end
		for _, item in pairs(bag) do
			if
				type(item) == "table"
				and type(item.templateId) == "string"
				and item.uid ~= exceptUid
			then
				owned[item.templateId] = true
			end
		end
	end
	take(profile.inventory)
	take(profile.pets)
	return owned
end

function RollLoop.discoveries(profile: any, extra: { string }?): number
	local owned = RollLoop.ownedTemplates(profile, nil)
	if type(extra) == "table" then
		for _, templateId in ipairs(extra) do
			if type(templateId) == "string" and templateId ~= "" then
				owned[templateId] = true
			end
		end
	end
	local count = 0
	for _ in pairs(owned) do
		count += 1
	end
	return count
end

function RollLoop.indexTotal(): number
	return #ItemBases.all()
end

function RollLoop.indexText(have: number, total: number): string
	local owned = if have > 0 then math.floor(have) else 0
	local cap = if total > 0 then math.floor(total) else 0
	return string.format("Index  %d/%d", owned, cap)
end

function RollLoop.isUpgrade(profile: any, item: any): boolean
	if type(item) ~= "table" then
		return false
	end
	local kind = item.kind
	if kind ~= "Weapon" and kind ~= "Armor" and kind ~= "Accessory" then
		return false
	end
	if type(profile) ~= "table" or type(profile.equipped) ~= "table" then
		return true
	end
	local equipped = profile.equipped
	local uid = nil
	if kind == "Weapon" then
		uid = equipped.weapon
	elseif kind == "Armor" and type(item.slot) == "string" and type(equipped.armor) == "table" then
		uid = equipped.armor[item.slot]
	elseif
		kind == "Accessory"
		and type(item.slot) == "string"
		and type(equipped.accessories) == "table"
	then
		uid = equipped.accessories[item.slot]
	end
	if type(uid) ~= "string" or uid == "" then
		return true
	end
	if uid == item.uid then
		return false
	end
	local worn = InventoryView.counterpart(profile, item)
	if type(worn) ~= "table" then
		return true
	end
	return InventoryView.powerOf(item) > InventoryView.powerOf(worn)
end

function RollLoop.bagFull(profile: any, pendingUid: string?): boolean
	if
		type(profile) ~= "table"
		or type(profile.inventory) ~= "table"
		or type(profile.pets) ~= "table"
	then
		return false
	end
	local count = Schema.countItems(profile)
	if type(pendingUid) == "string" and pendingUid ~= "" then
		local present = profile.inventory[pendingUid] ~= nil or profile.pets[pendingUid] ~= nil
		if not present then
			count += 1
		end
	end
	return count >= Schema.inventoryCap(profile)
end

function RollLoop.junkAction(rarity: string, below: string, mode: string): string
	if mode ~= "keep" and mode ~= "salvage" then
		return "show"
	end
	local gate = Rarities.INDEX[below]
	local got = Rarities.INDEX[rarity]
	if type(gate) ~= "number" or type(got) ~= "number" then
		return "show"
	end
	if got < gate then
		return mode
	end
	return "show"
end

-- An upgrade is never auto-salvaged. The Equip arrow does not pause the queue.
function RollLoop.resolve(rarity: string, below: string, mode: string, upgrade: boolean): string
	if upgrade then
		return "equip"
	end
	return RollLoop.junkAction(rarity, below, mode)
end

function RollLoop.blocked(tokens: number, full: boolean): string?
	if tokens < 1 then
		return "tokens"
	end
	if full then
		return "bag"
	end
	return nil
end

export type ChainInput = {
	open: boolean,
	onRoll: boolean,
	alive: boolean,
	queued: boolean,
	holding: boolean,
	auto: boolean,
	tokens: number,
	bagFull: boolean,
	rarity: string,
	stopAt: string,
	isNew: boolean,
	isUpgrade: boolean,
}

-- Auto-roll and hold-to-chain run only on the open roll page, and only
-- while the player is alive. Closing the hub, leaving the tab, or dying
-- fails this gate before another RollShard is sent.
function RollLoop.canChain(input: ChainInput): boolean
	if input.open ~= true or input.onRoll ~= true or input.alive ~= true then
		return false
	end
	if RollLoop.blocked(input.tokens, input.bagFull) ~= nil then
		return false
	end
	if input.queued == true then
		return true
	end
	if input.auto ~= true and input.holding ~= true then
		return false
	end
	return RollLoop.stopReason({
		auto = true,
		tokens = input.tokens,
		bagFull = input.bagFull,
		rarity = input.rarity,
		stopAt = input.stopAt,
		isNew = input.isNew,
		isUpgrade = input.isUpgrade,
	}) == nil
end

-- Seconds the server waits after a crack before it accepts another.
-- The floor is the tap cooldown. A longer reveal wins, so a request that
-- arrives while that card should still be on screen is ignored.
function RollLoop.gap(
	settings: Settings.Data,
	previousRarity: string?,
	previousQuick: boolean,
	nextQuick: boolean
): number
	local floor = RarityConfig.cooldown(nextQuick == true)
	if type(previousRarity) ~= "string" or previousRarity == "" then
		return floor
	end
	local reveal = RollLoop.seconds(
		settings,
		previousRarity,
		previousQuick == true,
		UiMotion.reduced(settings)
	)
	if reveal > floor then
		return reveal
	end
	return floor
end

function RollLoop.stopReason(input: StopInput): string?
	if input.auto ~= true then
		return nil
	end
	local hard = RollLoop.blocked(input.tokens, input.bagFull)
	if hard ~= nil then
		return hard
	end
	if not RollBoard.shouldRollAgain(true, input.stopAt, input.rarity, input.tokens) then
		return "rarity"
	end
	if input.isNew then
		return "new"
	end
	if input.isUpgrade then
		return "upgrade"
	end
	return nil
end

function RollLoop.best(current: any, item: any): any
	if type(item) ~= "table" then
		return current
	end
	if type(current) ~= "table" then
		return item
	end
	local left = rankOf(tostring(current.rarity or ""))
	local right = rankOf(tostring(item.rarity or ""))
	if right > left then
		return item
	end
	if right < left then
		return current
	end
	if InventoryView.powerOf(item) > InventoryView.powerOf(current) then
		return item
	end
	return current
end

return RollLoop
