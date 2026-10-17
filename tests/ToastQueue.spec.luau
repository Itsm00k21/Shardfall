--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ToastQueue = require("../src/ReplicatedStorage/Shared/ToastQueue")

describe("ToastQueue", function()
	it("stacks three received toasts and keeps prompts one at a time", function()
		local state = ToastQueue.blank()
		state = ToastQueue.pushToast(state, "Received Oak")
		state = ToastQueue.pushToast(state, "Received Ash")
		state = ToastQueue.pushToast(state, "Received Yew")
		state = ToastQueue.pushToast(state, "Received Elm")
		local shown = ToastQueue.visibleToasts(state)
		expect(#shown).toEqual(3)
		expect(shown[1].text).toEqual("Received Ash")
		expect(shown[3].text).toEqual("Received Elm")
		state = ToastQueue.dropToast(state, shown[1].id)
		expect(#ToastQueue.visibleToasts(state)).toEqual(2)
		state = ToastQueue.pushPrompt(state, "Equip Oak?", "Equip", "Keep")
		state = ToastQueue.pushPrompt(state, "Equip Ash?", "Equip", "Keep")
		local first = ToastQueue.currentPrompt(state)
		expect(first ~= nil).toBeTrue()
		if first ~= nil then
			expect(first.text).toEqual("Equip Oak?")
		end
		state = ToastQueue.answer(state)
		local second = ToastQueue.currentPrompt(state)
		expect(second ~= nil).toBeTrue()
		if second ~= nil then
			expect(second.text).toEqual("Equip Ash?")
			expect(second.yes).toEqual("Equip")
			expect(second.no).toEqual("Keep")
		end
		state = ToastQueue.answer(state)
		expect(ToastQueue.currentPrompt(state)).toBeNil()
	end)
end)
