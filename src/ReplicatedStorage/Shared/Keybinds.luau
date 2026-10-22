--!strict

--[[
	One table for every hotkey.

	Gameplay is what fires while the menu is closed: the action bar, dodge,
	heavy, interact, and the letters that open a tab. Menu is what fires
	while the hub is open. Two actions in one of those sets must not share
	a key. R is the heavy attack, so the Roll tab is T. 	Slots are 1 through
	8. Shift is dodge. The bar binds it above the control script, which
	would otherwise sink Left Shift as sprint. F is interact, and only while
	a prompt is showing. 	On a gamepad the D-pad fires slots 1-4, and holding
	LB fires 5-8. ButtonY dodges. Jump, the camera, ButtonX, and Shift
	stay off that map. Display keeps the name ButtonY so the letter Y
	is not a combat key. The Dodge chip shortens the glyph to Y.
]]

local Keybinds = {}

Keybinds.COMBAT = {
	dodge = "LeftShift",
	heavy = "R",
	interact = "F",
	slot1 = "One",
	slot2 = "Two",
	slot3 = "Three",
	slot4 = "Four",
	slot5 = "Five",
	slot6 = "Six",
	slot7 = "Seven",
	slot8 = "Eight",
}

-- Sprint is not a skill. A tab still cannot take it.
Keybinds.SPRINT = { "LeftShift", "RightShift" }

-- Heavy on a controller is ButtonX. Keyboard heavy stays R.
-- Dodge on a controller is ButtonY. ButtonX stays heavy.
Keybinds.GAMEPAD = {
	heavy = "ButtonX",
	dodge = "ButtonY",
}

-- Direct fire for the eight slots. The four directions are slots 1-4,
-- clockwise from up. Holding the modifier adds 4, so the same press
-- reaches slots 5-8 and does not also return the base slot. ButtonL1 is
-- a gamepad button, so the chord is read from that pad, not from a
-- keyboard key query. ButtonL1 is free while the menu is closed.
-- ButtonR1 still changes tabs while the menu is open, so it is not the
-- modifier.
local padButtons: { [string]: number } = {
	DPadUp = 1,
	DPadRight = 2,
	DPadDown = 3,
	DPadLeft = 4,
}

local PAD_ARROW: { [string]: string } = {
	DPadUp = "\u{2191}",
	DPadRight = "\u{2192}",
	DPadDown = "\u{2193}",
	DPadLeft = "\u{2190}",
}

Keybinds.PAD = {
	modifier = "ButtonL1",
	buttons = padButtons,
}

local padGlyphs: { [number]: string } = {}
for button, slot in pairs(padButtons) do
	local arrow = PAD_ARROW[button]
	if type(arrow) == "string" then
		padGlyphs[slot] = arrow
		padGlyphs[slot + 4] = "LB" .. arrow
	end
end
Keybinds.PAD_GLYPH = padGlyphs

-- Already owned. The slot map must not use these.
-- ButtonA jumps. ButtonX is heavy and the proximity prompt (F on a keyboard).
-- ButtonY dodges. ButtonL2 and ButtonR2 zoom the camera. Thumbstick2 looks.
-- Shift dodges.
-- ButtonB closes the menu. ButtonR1 moves between tabs while it is open.
local padReserved: { [string]: string } = {
	ButtonA = "jump",
	ButtonX = "interact",
	ButtonY = "dodge",
	ButtonL2 = "camera",
	ButtonR2 = "camera",
	ButtonL3 = "camera",
	ButtonR3 = "camera",
	Thumbstick1 = "move",
	Thumbstick2 = "camera",
	ButtonB = "menu",
	ButtonR1 = "menu",
	LeftShift = "dodge",
	RightShift = "dodge",
	Space = "jump",
	F = "interact",
}
Keybinds.PAD_RESERVED = padReserved

Keybinds.MENU_ORDER = { "hero", "bag", "pets", "roll", "raids", "market" }

Keybinds.MENU = {
	hero = "C",
	bag = "B",
	pets = "P",
	roll = "T",
	raids = "I",
	market = "M",
}

local MOVEMENT = { "W", "A", "S", "D", "Space", "Thumbstick1" }

function Keybinds.display(key: string): string
	if key == "LeftShift" or key == "RightShift" then
		return "Shift"
	end
	if key == "One" then
		return "1"
	end
	if key == "Two" then
		return "2"
	end
	if key == "Three" then
		return "3"
	end
	if key == "Four" then
		return "4"
	end
	if key == "Five" then
		return "5"
	end
	if key == "Six" then
		return "6"
	end
	if key == "Seven" then
		return "7"
	end
	if key == "Eight" then
		return "8"
	end
	return key
end

local function same(letter: string, key: string): boolean
	local want = string.upper(letter)
	if string.upper(key) == want then
		return true
	end
	return string.upper(Keybinds.display(key)) == want
end

-- The combat action, or "sprint", that already owns this letter.
function Keybinds.owner(letter: string): string?
	if type(letter) ~= "string" or letter == "" then
		return nil
	end
	for id, key in pairs(Keybinds.COMBAT) do
		if same(letter, key) then
			return id
		end
	end
	for _, key in ipairs(Keybinds.SPRINT) do
		if same(letter, key) then
			return "sprint"
		end
	end
	for id, key in pairs(Keybinds.GAMEPAD) do
		if same(letter, key) then
			return id
		end
	end
	return nil
end

function Keybinds.face(letter: string): string
	for _, key in pairs(Keybinds.COMBAT) do
		if same(letter, key) then
			return Keybinds.display(key)
		end
	end
	for _, key in ipairs(Keybinds.SPRINT) do
		if same(letter, key) then
			return Keybinds.display(key)
		end
	end
	for _, key in pairs(Keybinds.GAMEPAD) do
		if same(letter, key) then
			return Keybinds.display(key)
		end
	end
	return string.upper(string.sub(letter, 1, 1))
end

function Keybinds.copyMenu(source: { [string]: string }?): { [string]: string }
	local copy = {}
	local from = if source ~= nil then source else Keybinds.MENU
	for _, field in ipairs(Keybinds.MENU_ORDER) do
		local key = from[field]
		copy[field] = if type(key) == "string" then key else Keybinds.MENU[field]
	end
	return copy
end

-- Keys that fire during play. Menu letters are included because they open
-- the hub while the player is in combat.
function Keybinds.gameplay(menuHotkeys: { [string]: string }?): { [string]: string }
	local map = table.clone(Keybinds.COMBAT)
	local menu = Keybinds.copyMenu(menuHotkeys)
	for _, field in ipairs(Keybinds.MENU_ORDER) do
		map[field] = menu[field]
	end
	return map
end

function Keybinds.conflicts(map: { [string]: string }): { { string } }
	local owner: { [string]: string } = {}
	local found = {}
	local ids = {}
	for id in pairs(map) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local key = map[id]
		if type(key) == "string" then
			local token = string.upper(Keybinds.display(key))
			local previous = owner[token]
			if previous ~= nil then
				table.insert(found, { token, previous, id })
			else
				owner[token] = id
			end
		end
	end
	return found
end

local function reserve(taken: { [string]: boolean }, key: string)
	taken[key] = true
	taken[string.upper(key)] = true
	local shown = Keybinds.display(key)
	taken[shown] = true
	taken[string.upper(shown)] = true
end

local function freeLetter(taken: { [string]: boolean }): string
	for code = string.byte("A"), string.byte("Z") do
		local candidate = string.char(code)
		if taken[candidate] ~= true then
			return candidate
		end
	end
	return "T"
end

local function reserved(): { [string]: boolean }
	local taken: { [string]: boolean } = {}
	for _, key in pairs(Keybinds.COMBAT) do
		reserve(taken, key)
	end
	for _, key in ipairs(Keybinds.SPRINT) do
		reserve(taken, key)
	end
	for _, key in pairs(Keybinds.GAMEPAD) do
		reserve(taken, key)
	end
	return taken
end

-- A letter already used by another menu tab swaps. A combat letter,
-- Shift, or a skill key is refused. The result never has two tabs on one key.
function Keybinds.assign(
	hotkeys: { [string]: string },
	field: string,
	letter: string
): ({ [string]: string }, string?)
	local nextKeys = Keybinds.copyMenu(hotkeys)
	local upper = string.upper(letter)
	local blocked = Keybinds.owner(upper)
	if blocked ~= nil then
		return nextKeys, string.format("%s is already %s", Keybinds.face(upper), blocked)
	end
	local previous = nextKeys[field]
	local gavePrevious = false
	for _, other in ipairs(Keybinds.MENU_ORDER) do
		if other ~= field and string.upper(nextKeys[other]) == upper then
			if
				not gavePrevious
				and type(previous) == "string"
				and string.upper(previous) ~= upper
				and Keybinds.owner(previous) == nil
			then
				nextKeys[other] = string.upper(previous)
				gavePrevious = true
			else
				nextKeys[other] = ""
			end
		end
	end
	nextKeys[field] = upper
	local taken = reserved()
	reserve(taken, upper)
	for _, other in ipairs(Keybinds.MENU_ORDER) do
		if other ~= field then
			local key = string.upper(nextKeys[other])
			if key == "" or taken[key] == true then
				key = freeLetter(taken)
			end
			nextKeys[other] = key
			reserve(taken, key)
		end
	end
	return nextKeys, nil
end

-- Saved letters that collide with combat, Shift, a skill key, or an
-- earlier tab fall back to the default. This is what keeps an old Roll = R
-- from opening the menu.

function Keybinds.sanitize(hotkeys: { [string]: string }): { [string]: string }
	local taken = reserved()
	local copy = {}
	for _, field in ipairs(Keybinds.MENU_ORDER) do
		local raw = hotkeys[field]
		local key = if type(raw) == "string" then string.upper(raw) else ""
		local fallback = string.upper(Keybinds.MENU[field])
		if key == "" or taken[key] == true or Keybinds.owner(key) ~= nil then
			key = if taken[fallback] == true then freeLetter(taken) else fallback
		end
		copy[field] = key
		reserve(taken, key)
	end
	return copy
end

-- Movement, sprint, and combat stay sunk while the hub is open.
-- Tab letters are left out so they can switch tabs.
function Keybinds.sinkNames(): { string }
	local seen: { [string]: boolean } = {}
	local names = {}
	local function add(name: string)
		if seen[name] == true then
			return
		end
		seen[name] = true
		table.insert(names, name)
	end
	for _, name in ipairs(MOVEMENT) do
		add(name)
	end
	for _, key in ipairs(Keybinds.SPRINT) do
		add(key)
	end
	for _, key in pairs(Keybinds.COMBAT) do
		add(key)
	end
	for _, key in pairs(Keybinds.GAMEPAD) do
		add(key)
	end
	return names
end

-- Which hub pages stop the character (Kevin, Oct 21). The Hero, Bag,
-- Pets, Shop, Settings and Roll pages leave the world playable, so the
-- player can walk with them open (Kevin, Oct 22: browsing Roll walks too).
-- Only full-screen moments lock: the class picker, and a roll reveal while
-- it plays (see worldMode's revealing arg). A page that is not listed
-- locks, so a new screen is safe by default.
Keybinds.LOCK_MOVEMENT = table.freeze({
	hero = false,
	bag = false,
	pets = false,
	shop = false,
	settings = false,
	roll = false,
	class = true,
})

function Keybinds.locksMovement(page: any): boolean
	if type(page) ~= "string" then
		return true
	end
	return Keybinds.LOCK_MOVEMENT[page] ~= false
end

-- "free" (hub closed), "walk" (movement keys and controls stay live; only
-- combat keys are sunk), or "lock" (the full sink and controls off). A
-- gamepad always locks an open hub: the stick drives pad focus there.
-- revealing (optional) is true while a roll reveal plays; it locks the
-- open hub until the reveal ends, is skipped or the hub closes.
function Keybinds.worldMode(open: boolean, page: any, gamepad: boolean, revealing: boolean?): string
	if not open then
		return "free"
	end
	if gamepad or revealing == true or Keybinds.locksMovement(page) then
		return "lock"
	end
	return "walk"
end

-- Walk mode: combat keys only, so a click or a key on the panel does not
-- swing or cast. Movement, Space, and Shift (sprint and dodge) stay free.
function Keybinds.walkSinkNames(): { string }
	local free: { [string]: boolean } = {}
	for _, name in ipairs(MOVEMENT) do
		free[name] = true
	end
	for _, key in ipairs(Keybinds.SPRINT) do
		free[key] = true
	end
	local seen: { [string]: boolean } = {}
	local names = {}
	for _, key in pairs(Keybinds.COMBAT) do
		if free[key] ~= true and seen[key] ~= true then
			seen[key] = true
			table.insert(names, key)
		end
	end
	table.sort(names)
	return names
end

local SLOT_KEYS = {
	Keybinds.COMBAT.slot1,
	Keybinds.COMBAT.slot2,
	Keybinds.COMBAT.slot3,
	Keybinds.COMBAT.slot4,
	Keybinds.COMBAT.slot5,
	Keybinds.COMBAT.slot6,
	Keybinds.COMBAT.slot7,
	Keybinds.COMBAT.slot8,
}

function Keybinds.usesGamepad(inputTypeName: string): boolean
	return type(inputTypeName) == "string" and string.match(inputTypeName, "^Gamepad[1-8]$") ~= nil
end

-- Key label, or the controller glyph when a gamepad was the last input.
function Keybinds.slotFace(index: number, inputTypeName: string): string
	if Keybinds.usesGamepad(inputTypeName) then
		local glyph = Keybinds.PAD_GLYPH[index]
		if type(glyph) == "string" then
			return glyph
		end
		return ""
	end
	local key = SLOT_KEYS[index]
	if type(key) ~= "string" then
		return ""
	end
	return Keybinds.display(key)
end

function Keybinds.padSlot(button: string, modified: boolean): number?
	if type(button) ~= "string" then
		return nil
	end
	local base = Keybinds.PAD.buttons[button]
	if type(base) ~= "number" then
		return nil
	end
	if modified then
		return base + 4
	end
	return base
end

-- True only when this D-pad event came from a gamepad and that pad's LB
-- is down. ButtonL1 is not a keyboard key, so a keyboard, mouse, or touch
-- event stays unshifted even if the caller reports the modifier as down.
function Keybinds.padModified(inputTypeName: string, modifierDown: boolean): boolean
	return Keybinds.usesGamepad(inputTypeName) and modifierDown == true
end

-- One slot for a D-pad press. LB on that gamepad reaches 5-8. The same
-- direction without LB stays on 1-4. The chord never returns both.
function Keybinds.padChordSlot(
	button: string,
	inputTypeName: string,
	modifierDown: boolean
): number?
	return Keybinds.padSlot(button, Keybinds.padModified(inputTypeName, modifierDown))
end

local function clashes(button: string, problems: { string })
	local why = padReserved[button]
	if why ~= nil then
		table.insert(problems, button .. " is " .. why)
	end
	for id, key in pairs(Keybinds.GAMEPAD) do
		if key == button then
			table.insert(problems, button .. " clashes with " .. id)
		end
	end
	for id, key in pairs(Keybinds.COMBAT) do
		if key == button then
			table.insert(problems, button .. " clashes with " .. id)
		end
	end
	for _, key in ipairs(Keybinds.SPRINT) do
		if key == button then
			table.insert(problems, button .. " clashes with sprint")
		end
	end
end

-- Empty when every slot is reachable and no pad key is already owned.
function Keybinds.padCollisions(): { string }
	local problems = {}
	local seenSlot: { [number]: boolean } = {}
	local covered: { [number]: boolean } = {}
	local seenGlyph: { [string]: boolean } = {}
	for button, slot in pairs(Keybinds.PAD.buttons) do
		if type(slot) ~= "number" or slot < 1 or slot > 4 or slot ~= math.floor(slot) then
			table.insert(problems, button .. " is not a base slot")
		else
			if seenSlot[slot] == true then
				table.insert(problems, "slot " .. tostring(slot) .. " is duplicated")
			end
			seenSlot[slot] = true
			covered[slot] = true
			covered[slot + 4] = true
		end
		clashes(button, problems)
		if button == Keybinds.PAD.modifier then
			table.insert(problems, "modifier clashes with " .. button)
		end
	end
	local modifier = Keybinds.PAD.modifier
	if type(modifier) ~= "string" or modifier == "" then
		table.insert(problems, "modifier is missing")
	else
		clashes(modifier, problems)
	end
	for index = 1, 8 do
		if covered[index] ~= true then
			table.insert(problems, "slot " .. tostring(index) .. " is unreachable")
		end
		local glyph = Keybinds.PAD_GLYPH[index]
		if type(glyph) ~= "string" or glyph == "" then
			table.insert(problems, "slot " .. tostring(index) .. " has no glyph")
		elseif seenGlyph[glyph] == true then
			table.insert(problems, "glyph duplicated for slot " .. tostring(index))
		else
			seenGlyph[glyph] = true
		end
	end
	table.sort(problems)
	return problems
end

return Keybinds
