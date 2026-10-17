--!strict

--[[
	One stack for "Received X" and one slot for Equip / Keep.

	Toasts show up to three at a time. Prompts show one. The queue holds
	at most ToastQueue.MAX cards. A newer drop drops the oldest card.
	The newest card always stays. If it is waiting behind the card on
	screen, its text is also a toast, so that drop is not silent.
]]

local ToastQueue = {}

ToastQueue.MAX = 3

export type Toast = {
	id: number,
	text: string,
}

export type Prompt = {
	id: number,
	text: string,
	yes: string,
	no: string,
	uid: string?,
}

export type State = {
	nextId: number,
	toasts: { Toast },
	prompts: { Prompt },
}

function ToastQueue.blank(): State
	return {
		nextId = 1,
		toasts = {},
		prompts = {},
	}
end

local function copy(state: State): State
	local toasts = {}
	for index, toast in ipairs(state.toasts) do
		toasts[index] = { id = toast.id, text = toast.text }
	end
	local prompts = {}
	for index, prompt in ipairs(state.prompts) do
		prompts[index] = {
			id = prompt.id,
			text = prompt.text,
			yes = prompt.yes,
			no = prompt.no,
			uid = prompt.uid,
		}
	end
	return {
		nextId = state.nextId,
		toasts = toasts,
		prompts = prompts,
	}
end

function ToastQueue.pushToast(state: State, text: string): State
	local nextState = copy(state)
	if text == "" then
		return nextState
	end
	table.insert(nextState.toasts, { id = nextState.nextId, text = text })
	nextState.nextId += 1
	while #nextState.toasts > ToastQueue.MAX do
		table.remove(nextState.toasts, 1)
	end
	return nextState
end

function ToastQueue.dropToast(state: State, id: number): State
	local nextState = copy(state)
	for index, toast in ipairs(nextState.toasts) do
		if toast.id == id then
			table.remove(nextState.toasts, index)
			break
		end
	end
	return nextState
end

function ToastQueue.pushPrompt(
	state: State,
	text: string,
	yes: string,
	no: string,
	uid: string?
): State
	local nextState = copy(state)
	local prompt: Prompt = {
		id = nextState.nextId,
		text = text,
		yes = if yes ~= "" then yes else "Equip",
		no = if no ~= "" then no else "Keep",
	}
	if type(uid) == "string" and uid ~= "" then
		prompt.uid = uid
	end
	table.insert(nextState.prompts, prompt)
	nextState.nextId += 1
	-- Drop the oldest card. Never drop the newest, even if MAX is lowered.
	while #nextState.prompts > ToastQueue.MAX and #nextState.prompts > 1 do
		table.remove(nextState.prompts, 1)
	end
	local newest = nextState.prompts[#nextState.prompts]
	local shown = nextState.prompts[1]
	if newest ~= nil and shown ~= nil and newest.id ~= shown.id and newest.text ~= "" then
		nextState = ToastQueue.pushToast(nextState, newest.text)
	end
	return nextState
end

function ToastQueue.answer(state: State): State
	local nextState = copy(state)
	if #nextState.prompts > 0 then
		table.remove(nextState.prompts, 1)
	end
	return nextState
end

function ToastQueue.visibleToasts(state: State): { Toast }
	return state.toasts
end

function ToastQueue.currentPrompt(state: State): Prompt?
	return state.prompts[1]
end

return ToastQueue
