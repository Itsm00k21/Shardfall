--!strict

--[[
	One table for every hotkey.

	Gameplay is what fires while the menu is closed: attacks, skills, and
	the letters that open a tab. Menu is what fires while the hub is open.
	Two actions in one of those sets must not share a key. R is the heavy
	attack, so the Roll tab is T.
]]

local Keybinds = {}

Keybinds.COMBAT = {
	attack = "E",
	dodge = "Q",
	heavy = "R",
	skill1 = "LeftShift",
	skill2 = "Two",
	ult = "F",
}

-- Right Shift is the same skill as Left Shift, not a second action.
Keybinds.ALIAS = {
	skill1 = "RightShift",
}

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
	if key == "Two" then
		return "2"
	end
	return key
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
			local previous = owner[key]
			if previous ~= nil then
				table.insert(found, { key, previous, id })
			else
				owner[key] = id
			end
		end
	end
	return found
end

local function combatLetter(letter: string): string?
	for id, key in pairs(Keybinds.COMBAT) do
		if key == letter or Keybinds.display(key) == letter then
			return id
		end
	end
	return nil
end

-- A letter already used by another menu tab swaps. A combat letter is refused.
function Keybinds.assign(
	hotkeys: { [string]: string },
	field: string,
	letter: string
): ({ [string]: string }, string?)
	local nextKeys = Keybinds.copyMenu(hotkeys)
	local upper = string.upper(letter)
	local blocked = combatLetter(upper)
	if blocked ~= nil then
		return nextKeys, string.format("%s is already %s", upper, blocked)
	end
	local previous = nextKeys[field]
	for _, other in ipairs(Keybinds.MENU_ORDER) do
		if other ~= field and nextKeys[other] == upper then
			if
				type(previous) == "string"
				and previous ~= upper
				and combatLetter(previous) == nil
			then
				nextKeys[other] = previous
			end
			nextKeys[field] = upper
			return nextKeys, nil
		end
	end
	nextKeys[field] = upper
	return nextKeys, nil
end

-- Saved letters that collide with combat, or with an earlier tab, fall back
-- to the default. This is what keeps an old Roll = R from opening the menu.
local function freeLetter(taken: { [string]: boolean }): string
	for code = string.byte("A"), string.byte("Z") do
		local candidate = string.char(code)
		if taken[candidate] ~= true then
			return candidate
		end
	end
	return "T"
end

function Keybinds.sanitize(hotkeys: { [string]: string }): { [string]: string }
	local taken: { [string]: boolean } = {}
	for _, key in pairs(Keybinds.COMBAT) do
		taken[key] = true
		taken[Keybinds.display(key)] = true
	end
	local copy = {}
	for _, field in ipairs(Keybinds.MENU_ORDER) do
		local key = hotkeys[field]
		local fallback = Keybinds.MENU[field]
		if type(key) ~= "string" or taken[key] == true then
			key = if taken[fallback] == true then freeLetter(taken) else fallback
		end
		copy[field] = key
		taken[key] = true
	end
	return copy
end

function Keybinds.sinkNames(menuHotkeys: { [string]: string }?): { string }
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
	for _, key in pairs(Keybinds.COMBAT) do
		add(key)
	end
	add(Keybinds.ALIAS.skill1)
	local menu = Keybinds.copyMenu(menuHotkeys)
	for _, field in ipairs(Keybinds.MENU_ORDER) do
		add(menu[field])
	end
	return names
end

return Keybinds
