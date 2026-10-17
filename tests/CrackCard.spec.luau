--!strict

--[[
	CrackCard is pure and the Roll tab does not run under Lune. The
	source lock checks that fitRoll uses this layout and no longer
	forces the reel to 72 or the card to 96.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CrackCard = require("../src/ReplicatedStorage/Shared/CrackCard")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local function misses(layout)
	local reelBottom = layout.reel.y + layout.reel.h
	expect(layout.listTop).toEqual(reelBottom)
	expect(layout.kindBottom >= reelBottom).toBeTrue()
	if layout.card.h > 0 then
		expect(layout.card.y >= layout.kindBottom).toBeTrue()
		expect(layout.card.y >= reelBottom).toBeTrue()
	end
	expect(layout.name.y >= 0).toBeTrue()
	expect(layout.name.y + layout.name.h <= layout.card.h).toBeTrue()
	if layout.rarity.visible then
		expect(layout.rarity.y + layout.rarity.h <= layout.card.h).toBeTrue()
	end
	local stoneBottom = layout.stone.y * layout.reel.h + layout.stone.h / 2
	expect(stoneBottom <= layout.reel.h + 0.01).toBeTrue()
end

describe("CrackCard", function()
	it("keeps the card below the pet row on a short page", function()
		local landscape = CrackCard.layout(240, 44)
		expect(landscape.reel).toEqual({ y = 40, h = 36 })
		expect(landscape.button).toEqual(44)
		expect(landscape.kindBottom).toEqual(128)
		expect(landscape.card).toEqual({ y = 128, h = 56 })
		expect(landscape.name).toEqual({ y = 4, h = 22 })
		expect(landscape.rarity.visible).toEqual(true)
		expect(landscape.fly).toEqual(false)
		expect(landscape.showEquip).toEqual(false)
		expect(landscape.stone).toEqual({ w = 16, h = 18, y = 0.7 })
		expect(landscape.compact).toEqual(true)
		misses(landscape)

		local narrow = CrackCard.layout(232, 44)
		expect(narrow.card).toEqual({ y = 128, h = 48 })
		expect(narrow.reel.h).toEqual(36)
		expect(narrow.kindBottom).toEqual(128)
		misses(narrow)
	end)

	it("keeps a full card on a tall page", function()
		local phone = CrackCard.layout(576, 96)
		expect(phone.reel).toEqual({ y = 40, h = 68 })
		expect(phone.button).toEqual(72)
		expect(phone.kindBottom).toEqual(212)
		expect(phone.card).toEqual({ y = 380, h = 112 })
		expect(phone.name).toEqual({ y = 8, h = 28 })
		expect(phone.rarity).toEqual({ y = 40, h = 20, visible = true })
		expect(phone.fly).toEqual(true)
		expect(phone.showEquip).toEqual(true)
		expect(phone.stone).toEqual({ w = 28, h = 36, y = 0.62 })
		misses(phone)

		local desktop = CrackCard.layout(497, 44)
		expect(desktop.card.h).toEqual(112)
		expect(desktop.card.y).toEqual(301)
		expect(desktop.kindBottom).toEqual(160)
		misses(desktop)
	end)

	it("uses 320 by 44 for a missing or bad size", function()
		local fallback = CrackCard.layout(320, 44)
		expect(fallback.card).toEqual({ y = 144, h = 108 })
		expect(fallback.reel.h).toEqual(52)
		expect(fallback.button).toEqual(56)
		misses(fallback)
		expect(CrackCard.layout(nil, nil)).toEqual(fallback)
		expect(CrackCard.layout("240", "44")).toEqual(fallback)
		expect(CrackCard.layout(0 / 0, 44)).toEqual(fallback)
		expect(CrackCard.layout(240, 0 / 0)).toEqual(CrackCard.layout(240, 44))
		expect(CrackCard.layout(math.huge, 44)).toEqual(fallback)
		expect(CrackCard.layout(79, 44)).toEqual(fallback)
		expect(CrackCard.layout(240, 12)).toEqual(CrackCard.layout(240, 44))
		local first = CrackCard.layout(240, 44)
		local second = CrackCard.layout(240, 44)
		expect(first).toEqual(second)
		expect(rawequal(first, second)).toBeFalse()
	end)

	it("ignores a third argument, including paid", function()
		expect(CrackCard.layout(240, 44, true)).toEqual(CrackCard.layout(240, 44))
		expect(CrackCard.layout(576, 96, { paid = true, cost = 25, robux = 25 })).toEqual(CrackCard.layout(576, 96))
	end)

	it("is what the roll tab uses to place the crack card", function()
		local hub = fs.readFile(HUB)
		expect(string.find(hub, "CrackCard.layout", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "math.max(96, chrome.card)", 1, true)).toBeNil()
		expect(string.find(hub, "math.max(72, chrome.reel)", 1, true)).toBeNil()
	end)
end)
