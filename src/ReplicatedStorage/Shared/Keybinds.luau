--!strict

--[[
	One table for every hotkey.

	Gameplay is what fires while the menu is closed: attacks, skills, and
	the letters that open a tab. Menu is what fires while the hub is open.
	Two actions in one of those sets must not share a key. R is the heavy
	attack, so the Roll tab is T. Skill 1 is 1. Shift stays sprint, because
	the default control script sinks Left Shift before a skill listener runs.
]]

local Keybinds = {}

Keybinds.COMBAT = {
	attack = "E",
	dodge = "Q",
	heavy = "R",
	skill1 = "One",
	skill2 = "Two",
	ult = "F",
}

-- Sprint is not a skill. A tab still cannot take it.
Keybinds.SPRINT = { "LeftShift", "RightShift" }

-- Heavy on a controller. Keyboard heavy stays R.
Keybinds.GAMEPAD = {
	heavy = "ButtonX",
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
	if key == "One" then
		return "1"
	end
	if key == "Two" then
		return "2"
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

return Keybinds
