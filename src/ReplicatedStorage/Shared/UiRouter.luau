--!strict

--[[
	One owner for the menu.

	The rail, the inner tabs, and the hotkeys all call these functions.
	The dim is a number on the state, not a tween left running by the last
	close. Open sets it. Close and the roll hand-off clear it. The next
	open sets it again.

	The roll route also decides how the Roll screen presents a result the
	server already rolled. It does not roll, and it does not invent a
	rarity. The live legendary guarantee is profile sinceLegendary against
	RarityConfig.LEGENDARY_PITY. RollMath.rollsSinceLegendary and the pool
	pityLegendaryAt are a different counter, and the crack path does not
	use them. totalRolls is not pity.
]]

local Rarities = require("./Rarities")
local RarityConfig = require("./RarityConfig")
local RollLoop = require("./RollLoop")
local Settings = require("./Settings")

local UiRouter = {}

UiRouter.DIM = 0.5

UiRouter.TABS = { "hero", "bag", "pets", "roll", "raids", "market", "pass", "settings" }

export type State = {
	open: boolean,
	tab: string,
	stack: { string },
	dim: number,
	blocked: boolean,
	rollAway: boolean,
	generation: number,
}

local function known(tab: string): boolean
	for _, id in ipairs(UiRouter.TABS) do
		if id == tab then
			return true
		end
	end
	return false
end

local function cloneStack(stack: { string }): { string }
	local copy = {}
	for _, id in ipairs(stack) do
		table.insert(copy, id)
	end
	return copy
end

function UiRouter.initial(): State
	return {
		open = false,
		tab = "hero",
		stack = {},
		dim = 0,
		blocked = false,
		rollAway = false,
		generation = 0,
	}
end

local function publish(previous: State, open: boolean, tab: string, stack: { string }): State
	return {
		open = open,
		tab = tab,
		stack = stack,
		dim = if open then UiRouter.DIM else 0,
		blocked = open,
		rollAway = false,
		generation = previous.generation + 1,
	}
end

function UiRouter.open(state: State, tab: string): State
	local id = if known(tab) then tab else "hero"
	return publish(state, true, id, { id })
end

-- Inner tabs and the rail call this. The first click after open is enough.
-- Nothing has to "arm" the tabs with a rail switch first.
function UiRouter.switch(state: State, tab: string): State
	if not known(tab) then
		return state
	end
	if not state.open then
		return UiRouter.open(state, tab)
	end
	return publish(state, true, tab, { tab })
end

function UiRouter.push(state: State, id: string): State
	if not state.open or id == "" then
		return state
	end
	local stack = cloneStack(state.stack)
	if stack[#stack] ~= id then
		table.insert(stack, id)
	end
	return publish(state, true, id, stack)
end

function UiRouter.pop(state: State): State
	if not state.open then
		return state
	end
	if #state.stack > 1 then
		local stack = cloneStack(state.stack)
		table.remove(stack)
		return publish(state, true, stack[#stack], stack)
	end
	return UiRouter.close(state)
end

function UiRouter.close(state: State): State
	return publish(state, false, state.tab, {})
end

-- The reveal plays on its own screen. The menu dim is released here, and
-- the next open() puts it back. The reveal does not keep the dim.
function UiRouter.rollHandoff(state: State): State
	local closed = UiRouter.close(state)
	closed.rollAway = true
	return closed
end

function UiRouter.toggle(state: State, tab: string): State
	if not known(tab) then
		return state
	end
	local root = state.stack[1] or state.tab
	if state.open and root == tab and #state.stack <= 1 then
		return UiRouter.close(state)
	end
	return UiRouter.open(state, tab)
end

function UiRouter.hotkey(state: State, key: string, hotkeys: { [string]: string }): State
	local letter = string.upper(string.sub(key, 1, 1))
	if string.match(letter, "^%a$") == nil then
		return state
	end
	for _, tab in ipairs(UiRouter.TABS) do
		local bound = hotkeys[tab]
		if type(bound) == "string" and string.upper(bound) == letter then
			if state.open then
				return UiRouter.switch(state, tab)
			end
			return UiRouter.open(state, tab)
		end
	end
	return state
end

function UiRouter.key(state: State, keyName: string, hotkeys: { [string]: string }): State
	if keyName == "Escape" or keyName == "ButtonB" then
		if not state.open then
			return state
		end
		return UiRouter.pop(state)
	end
	return UiRouter.hotkey(state, keyName, hotkeys)
end

function UiRouter.shoulder(state: State, direction: number): State
	if not state.open or direction == 0 then
		return state
	end
	local root = state.stack[1] or state.tab
	local index = 1
	for cursor, tab in ipairs(UiRouter.TABS) do
		if tab == root then
			index = cursor
		end
	end
	local step = if direction > 0 then 1 else -1
	local nextIndex = ((index - 1 + step) % #UiRouter.TABS) + 1
	return UiRouter.switch(state, UiRouter.TABS[nextIndex])
end

function UiRouter.top(state: State): string
	return state.stack[#state.stack] or state.tab
end

-- Haven stalls open a hub tab. The legacy forge panel and MarketHud stay
-- mounted for the banner, and these prompts do not call them.
function UiRouter.havenTab(kind: string, areaId: string?): string?
	if kind == "market" then
		return "market"
	end
	if kind == "craft" then
		return "bag"
	end
	if areaId == "pets" or kind == "pets" then
		return "pets"
	end
	if kind == "shards" or kind == "armory" or areaId == "armory" then
		return "roll"
	end
	return nil
end

export type RollChrome = {
	reel: number,
	button: number,
	card: number,
}

export type ReelSlot = {
	name: string,
	rarity: string,
}

export type RollPace = {
	ok: boolean,
	buildUp: number?,
	rarity: string?,
	tier: number?,
}

-- Phone-height panels keep the reel, the card, and the Roll button from
-- stacking through each other. 20px is the pad the roll page adds around
-- those three. A non-positive height uses the desktop case.
function UiRouter.rollChrome(height: number): RollChrome
	local given = height
	local fallback = type(given) ~= "number" or given ~= given or given == math.huge or given <= 0
	local room = if fallback then 320 else given
	local button = 72
	local reel = 68
	local reserve = 20
	if not fallback and room < 340 then
		button = 56
		reel = 52
	end
	if not fallback and room < 260 then
		button = 44
		reel = 36
	end
	local card = math.floor(math.clamp(room - button - reel - reserve, 0, 112))
	local function used(): number
		return button + reel + card + reserve
	end
	while used() > room and (card > 0 or reel > 0 or button > 0) do
		if card > 0 then
			card -= 1
		elseif reel > 0 then
			reel -= 1
		else
			button -= 1
		end
	end
	return {
		reel = reel,
		button = button,
		card = card,
	}
end

-- Post-roll legendary counter. Prefer the server result's sinceLegendary,
-- then the profile field. Never read totalRolls, rollsSinceLegendary, or
-- pityLegendaryAt: those do not drive the guarantee in RollService.
function UiRouter.legendaryPity(profile: any, result: any): (any, number)
	local goal = RarityConfig.LEGENDARY_PITY
	if
		type(result) == "table"
		and type(result.pity) == "table"
		and result.pity.sinceLegendary ~= nil
	then
		return result.pity.sinceLegendary, goal
	end
	if type(profile) == "table" and profile.sinceLegendary ~= nil then
		return profile.sinceLegendary, goal
	end
	return 0, goal
end

-- Natural odds until the live guarantee is actually the next roll.
-- Passing sinceLegendary into RollMath early would light the pool's
-- pityLegendaryAt (50) and show a guarantee the server does not apply.
function UiRouter.oddsSince(sinceLegendary: any): number
	local since = 0
	if
		type(sinceLegendary) == "number"
		and sinceLegendary == sinceLegendary
		and sinceLegendary ~= math.huge
		and sinceLegendary >= 0
	then
		since = sinceLegendary
	end
	if since + 1 >= RarityConfig.LEGENDARY_PITY then
		return since
	end
	return 0
end

-- Full animation uses the hype build-up. Short, instant, skip, and reduced
-- motion stay on RollLoop.seconds. A refused tempo shows nothing.
function UiRouter.rollBuildUp(
	settings: any,
	rarity: string,
	quick: boolean,
	reduced: boolean,
	pace: RollPace
): number?
	if type(pace) ~= "table" or pace.ok ~= true or type(pace.buildUp) ~= "number" then
		return nil
	end
	if type(rarity) ~= "string" or rarity == "" then
		return nil
	end
	local motionReduced = reduced == true
	local seconds = 0
	if type(settings) == "table" then
		local ok, value = pcall(RollLoop.seconds, settings, rarity, quick == true, motionReduced)
		if ok and type(value) == "number" then
			seconds = value
		end
	end
	local full = type(settings) == "table"
		and type(settings.rolls) == "table"
		and settings.rolls.animation == "full"
	local skipped = false
	if type(settings) == "table" then
		local ok, value = pcall(Settings.skipsCutscene, settings, rarity)
		skipped = ok and value == true
	end
	if full and not motionReduced and not skipped and seconds > 0 then
		return pace.buildUp
	end
	return seconds
end

function UiRouter.rollPop(tier: any, reduced: boolean): number
	if reduced or type(tier) ~= "number" or tier ~= tier then
		return 1
	end
	local step = math.clamp(math.floor(tier), 1, 7)
	return 1 + step * 0.02
end

-- Milestone text is the callout only. The personal-best name is the rarity
-- that just landed, and only on the roll that beat the record.
function UiRouter.rollShout(noted: any): (string?, string?)
	if type(noted) ~= "table" or noted.ok ~= true then
		return nil, nil
	end
	local milestone = nil
	if noted.milestone ~= nil and type(noted.callout) == "string" and noted.callout ~= "" then
		milestone = noted.callout
	end
	local personal = nil
	if noted.newPersonalBest == true and type(noted.rarity) == "string" then
		personal = noted.rarity
	end
	return milestone, personal
end

-- The card is this roll. A miss and a bad rarity return nil, so state.best
-- cannot leak onto the card.
function UiRouter.rollCard(noted: any, item: any): ReelSlot?
	if type(noted) ~= "table" or noted.ok ~= true or type(noted.rarity) ~= "string" then
		return nil
	end
	if type(item) ~= "table" then
		return nil
	end
	local name = item.name
	if type(name) ~= "string" or name == "" then
		name = "Shard"
	end
	return {
		name = name,
		rarity = noted.rarity,
	}
end

function UiRouter.streakText(streak: any, missed: boolean): string
	local count = 0
	if type(streak) == "number" and streak == streak and streak > 0 then
		count = math.floor(streak)
	end
	if missed then
		return "Streak broke"
	end
	if count >= 2 then
		return string.format("Streak  %d in a row", count)
	end
	return string.format("Streak  %d", count)
end

function UiRouter.streakTone(streak: any, missed: boolean): string
	if missed then
		return "loss"
	end
	local count = 0
	if type(streak) == "number" and streak == streak and streak > 0 then
		count = math.floor(streak)
	end
	if count >= 5 then
		return "gold"
	end
	if count >= 2 then
		return "accent"
	end
	return "text"
end

-- Spin index. Progress 0 is the first honest slot. Progress 1 lands on the
-- last slot, which the caller keeps as the item that was actually rolled.
function UiRouter.reelCenter(count: number, progress: number): number
	if type(count) ~= "number" or count < 1 then
		return 1
	end
	local whole = math.floor(count)
	if whole < 1 then
		return 1
	end
	local along = progress
	if type(along) ~= "number" or along ~= along or along == math.huge then
		along = 1
	end
	along = math.clamp(along, 0, 1)
	if whole == 1 then
		return 1
	end
	local index = math.floor(along * (whole - 1) + 1e-6) + 1
	if index > whole then
		return whole
	end
	return index
end

-- Drop any filler above the rolled rarity. The last slot is the real item.
-- This does not add a near-miss.
function UiRouter.honestSlots(slots: any, name: string, rarity: string): { ReelSlot }
	local limit = Rarities.INDEX[rarity]
	local kept: { ReelSlot } = {}
	if type(limit) ~= "number" or type(name) ~= "string" or name == "" then
		return kept
	end
	if type(slots) == "table" then
		for _, row in ipairs(slots) do
			if type(row) == "table" and type(row.name) == "string" and row.name ~= "" then
				local shown = row.rarity
				local rank = if type(shown) == "string" then Rarities.INDEX[shown] else nil
				if type(rank) == "number" and rank <= limit then
					table.insert(kept, {
						name = row.name,
						rarity = shown :: string,
					})
				else
					table.insert(kept, {
						name = name,
						rarity = rarity,
					})
				end
			end
		end
	end
	if #kept == 0 then
		table.insert(kept, { name = name, rarity = rarity })
	end
	kept[#kept] = { name = name, rarity = rarity }
	return kept
end

return UiRouter
