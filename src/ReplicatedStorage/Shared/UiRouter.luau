--!strict

--[[
	One owner for the menu.

	The rail, the inner tabs, and the hotkeys all call these functions.
	The dim is a number on the state, not a tween left running by the last
	close. Open sets it. Close and the roll hand-off clear it. The next
	open sets it again.
]]

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

return UiRouter
