--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ToastQueue = require("../src/ReplicatedStorage/Shared/ToastQueue")

local function slice(source: string, from: string, untilText: string): string
	local startAt = string.find(source, from, 1, true)
	expect(startAt ~= nil).toBeTrue()
	local stopAt = string.find(source, untilText, (startAt :: number) + 1, true)
	expect(stopAt ~= nil).toBeTrue()
	return string.sub(source, startAt :: number, (stopAt :: number) - 1)
end

describe("Equip prompt", function()
	it("shows one card and does not toast the drop already on screen", function()
		local state = ToastQueue.pushPrompt(ToastQueue.blank(), "Equip Oak?", "", "", "oak")
		local card = ToastQueue.currentPrompt(state)
		expect(card ~= nil).toBeTrue()
		if card ~= nil then
			expect(card.text).toEqual("Equip Oak?")
			expect(card.yes).toEqual("Equip")
			expect(card.no).toEqual("Keep")
			expect(card.uid).toEqual("oak")
		end
		expect(#ToastQueue.visibleToasts(state)).toEqual(0)
		local bare = ToastQueue.currentPrompt(
			ToastQueue.pushPrompt(ToastQueue.blank(), "Blade", "Equip", "Keep", "")
		)
		expect(bare ~= nil).toBeTrue()
		if bare ~= nil then
			expect(bare.uid).toBeNil()
		end
	end)

	it("drops the oldest prompt, keeps the newest, and toasts that drop", function()
		local state = ToastQueue.blank()
		for index = 1, ToastQueue.MAX + 1 do
			state = ToastQueue.pushPrompt(
				state,
				"Equip " .. tostring(index),
				"Equip",
				"Keep",
				"uid-" .. tostring(index)
			)
		end
		expect(#state.prompts).toEqual(ToastQueue.MAX)
		expect(state.prompts[1].text).toEqual("Equip 2")
		expect(state.prompts[1].uid).toEqual("uid-2")
		local last = state.prompts[#state.prompts]
		local newest = "Equip " .. tostring(ToastQueue.MAX + 1)
		expect(last.text).toEqual(newest)
		expect(last.uid).toEqual("uid-" .. tostring(ToastQueue.MAX + 1))
		local sawFirst = false
		for _, prompt in ipairs(state.prompts) do
			if prompt.uid == "uid-1" then
				sawFirst = true
			end
		end
		expect(sawFirst).toEqual(false)
		local toasts = ToastQueue.visibleToasts(state)
		expect(toasts[#toasts].text).toEqual(newest)
		state = ToastQueue.answer(state)
		local nextCard = ToastQueue.currentPrompt(state)
		expect(nextCard ~= nil).toBeTrue()
		if nextCard ~= nil then
			expect(nextCard.uid).toEqual("uid-3")
			expect(nextCard.yes).toEqual("Equip")
			expect(nextCard.no).toEqual("Keep")
		end
	end)

	it("keeps the newest drop toast when the toast stack is already full", function()
		local state = ToastQueue.blank()
		state = ToastQueue.pushToast(state, "Received One")
		state = ToastQueue.pushToast(state, "Received Two")
		state = ToastQueue.pushToast(state, "Received Three")
		state = ToastQueue.pushPrompt(state, "Equip Oak?", "Equip", "Keep", "oak")
		local shown = ToastQueue.visibleToasts(state)
		expect(#shown).toEqual(3)
		expect(shown[3].text).toEqual("Received Three")
		state = ToastQueue.pushPrompt(state, "Equip Elm?", "Equip", "Keep", "elm")
		shown = ToastQueue.visibleToasts(state)
		expect(shown[#shown].text).toEqual("Equip Elm?")
		expect(state.prompts[#state.prompts].uid).toEqual("elm")
		expect(ToastQueue.currentPrompt(state) ~= nil).toBeTrue()
		local current = ToastQueue.currentPrompt(state)
		if current ~= nil then
			expect(current.uid).toEqual("oak")
		end
	end)

	it("equips from the Equip button and lets Keep only dismiss", function()
		local shell =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau")
		local equipBody = slice(shell, "local function equipItem", "local function onYes()")
		local yesBody = slice(shell, "local function onYes()", "local function onNo()")
		local noBody = slice(shell, "local function onNo()", "promptYes.Activated:Connect(onYes)")
		expect(string.find(equipBody, '"EquipItem"', 1, true) ~= nil).toBeTrue()
		expect(string.find(equipBody, "InvokeServer", 1, true) ~= nil).toBeTrue()
		expect(string.find(equipBody, "task.spawn", 1, true) ~= nil).toBeTrue()
		expect(string.find(equipBody, "WaitForChild", 1, true)).toBeNil()
		expect(string.find(equipBody, "UnequipItem", 1, true)).toBeNil()
		local paintAt = string.find(yesBody, "paintNotices()", 1, true)
		local callAt = string.find(yesBody, "equipItem(", 1, true)
		expect(paintAt ~= nil).toBeTrue()
		expect(callAt ~= nil).toBeTrue()
		expect((paintAt :: number) < (callAt :: number)).toBeTrue()
		expect(string.find(yesBody, "ToastQueue.answer", 1, true) ~= nil).toBeTrue()
		expect(string.find(noBody, "ToastQueue.answer", 1, true) ~= nil).toBeTrue()
		expect(string.find(noBody, "equipItem", 1, true)).toBeNil()
		expect(string.find(noBody, "EquipItem", 1, true)).toBeNil()
		expect(string.find(noBody, "InvokeServer", 1, true)).toBeNil()
		expect(string.find(shell, "promptYes.Activated:Connect(onYes)", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, "promptNo.Activated:Connect(onNo)", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, "promptYes.Activated:Connect(onNo)", 1, true)).toBeNil()
		expect(string.find(shell, "Activated:Connect(answerPrompt)", 1, true)).toBeNil()
		expect(
			string.find(
				shell,
				'ToastQueue.pushPrompt(notices, text, "Equip", "Keep", uid)',
				1,
				true
			) ~= nil
		).toBeTrue()
	end)
end)
