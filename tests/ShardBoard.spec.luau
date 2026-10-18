--!strict

--[[
	ShardBoard is pure and the Roll tab does not run under Lune. The
	source lock checks that MenuHub stacks the pity rows from this
	module and still draws the shard as a Frame.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ShardBoard = require("../src/ReplicatedStorage/Shared/ShardBoard")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local function white(fill): boolean
	return fill[1] == 255 and fill[2] == 255 and fill[3] == 255
end

local function clear(stack)
	for index, row in ipairs(stack.rows) do
		expect(row.y >= 0).toBeTrue()
		expect(row.h >= 1).toBeTrue()
		expect(row.y + row.h <= stack.h).toBeTrue()
		if index > 1 then
			local previous = stack.rows[index - 1]
			expect(row.y >= previous.y + previous.h).toBeTrue()
		end
	end
end

local function sameRows(left, right)
	expect(#left.rows).toEqual(#right.rows)
	expect(left.h).toEqual(right.h)
	expect(left.w).toEqual(right.w)
	for index, row in ipairs(left.rows) do
		local other = right.rows[index]
		expect(other.id).toEqual(row.id)
		expect(other.y).toEqual(row.y)
		expect(other.h).toEqual(row.h)
		expect(other.bar).toEqual(row.bar)
		expect(other.text).toEqual(row.text)
	end
end

describe("ShardBoard", function()
	it("stacks gear and pet pity on the same rows", function()
		local counters = {
			Epic = { counter = 38, goal = 100 },
			Legendary = { counter = 28, goal = 1000 },
			Relic = { counter = 0, goal = "-" },
			Mythic = { counter = 0, goal = nil },
		}
		local gear = ShardBoard.stack("gear", counters, 320)
		local pets = ShardBoard.stack("pets", counters, 320)
		local back = ShardBoard.stack("gear", counters, 320)
		expect(gear.kind).toEqual("gear")
		expect(pets.kind).toEqual("pets")
		expect(back.kind).toEqual("gear")
		sameRows(gear, pets)
		sameRows(gear, back)
		expect(rawequal(gear, pets)).toBeFalse()
		expect(rawequal(gear.rows, pets.rows)).toBeFalse()
		clear(gear)
		clear(pets)
		expect(#gear.rows).toEqual(3)
		expect(gear.rows[1].id).toEqual("Epic")
		expect(gear.rows[1].h).toEqual(36)
		expect(gear.rows[1].y).toEqual(0)
		expect(gear.rows[1].text).toEqual("Epic  38 / 100")
		expect(gear.rows[2].id).toEqual("Legendary")
		expect(gear.rows[2].y).toEqual(44)
		expect(gear.rows[2].text).toEqual("Legendary  28 / 1000")
		expect(gear.rows[3].id).toEqual("Odds")
		expect(gear.rows[3].y).toEqual(88)
		expect(gear.rows[3].h).toEqual(28)
		expect(gear.rows[3].bar).toEqual(false)
		expect(gear.rows[3].text).toEqual("Odds")
		expect(gear.h).toEqual(116)
		for _, row in ipairs(gear.rows) do
			expect(string.find(row.text, " / -", 1, true)).toBeNil()
			expect(string.find(row.text, "0 / -", 1, true)).toBeNil()
		end
	end)

	it("hides a tier with no pity and never prints a dash denominator", function()
		expect(ShardBoard.caption("Legendary", 28, 1000)).toEqual("Legendary  28 / 1000")
		expect(ShardBoard.caption("Relic", 0, "-")).toEqual("Relic  no pity")
		expect(ShardBoard.caption("Mythic", 0, nil)).toEqual("Mythic  no pity")
		expect(ShardBoard.caption("Relic", 0, 0)).toEqual("Relic  no pity")
		expect(ShardBoard.caption("Epic", 0, -5)).toEqual("Epic  no pity")
		expect(ShardBoard.caption("Epic", 0, 0 / 0)).toEqual("Epic  no pity")
		local broken = {
			ShardBoard.caption("Relic", 0, "-"),
			ShardBoard.caption("Mythic", 0, nil),
			ShardBoard.caption("Relic", 0, 0),
		}
		for _, text in ipairs(broken) do
			expect(string.find(text, " / -", 1, true)).toBeNil()
			expect(string.find(text, "0 / -", 1, true)).toBeNil()
			expect(string.find(text, "no pity", 1, true) ~= nil).toBeTrue()
		end
		local hidden = ShardBoard.stack("pets", {
			Epic = { counter = 1, goal = 0 },
			Legendary = { counter = 28, goal = "-" },
			Relic = { counter = 0, goal = nil },
			Mythic = { counter = 0, goal = 0 / 0 },
		}, 280)
		expect(#hidden.rows).toEqual(1)
		expect(hidden.rows[1].id).toEqual("Odds")
		expect(hidden.rows[1].y).toEqual(0)
		expect(hidden.h).toEqual(28)
		clear(hidden)
		expect(ShardBoard.caption("Legendary", 28, 5000, { paid = true })).toEqual(
			"Legendary  28 / 5000"
		)
		local paid = ShardBoard.stack("pets", {
			Epic = { counter = 38, goal = 100 },
			Legendary = { counter = 28, goal = 1000 },
		}, 320, { paid = true, cost = 25 })
		local free = ShardBoard.stack("pets", {
			Epic = { counter = 38, goal = 100 },
			Legendary = { counter = 28, goal = 1000 },
		}, 320)
		sameRows(paid, free)
		expect(paid.kind).toEqual(free.kind)
	end)

	it("draws a crystal and refuses a white placeholder", function()
		local gear = ShardBoard.visual("gear")
		local pets = ShardBoard.visual("pets")
		local again = ShardBoard.visual("gear")
		expect(gear).toEqual({
			w = 28,
			h = 40,
			fill = { 132, 142, 156 },
			crack = { 18, 16, 22 },
			crackH = 14,
			image = "",
		})
		expect(pets.fill).toEqual({ 86, 150, 112 })
		expect(pets.image).toEqual("")
		expect(pets.crackH).toEqual(14)
		expect(white(gear.fill)).toBeFalse()
		expect(white(pets.fill)).toBeFalse()
		expect(gear.fill[1] == 198 and gear.fill[2] == 206 and gear.fill[3] == 214).toBeFalse()
		expect(pets.fill[1] == 198 and pets.fill[2] == 206 and pets.fill[3] == 214).toBeFalse()
		expect(ShardBoard.visual("pets", { paid = true })).toEqual(pets)
		expect(ShardBoard.visual("gear", true)).toEqual(gear)
		expect(rawequal(gear, again)).toBeFalse()
		local fallback = ShardBoard.stack(nil, nil, nil)
		expect(fallback.kind).toEqual("gear")
		expect(fallback.w).toEqual(280)
		expect(ShardBoard.stack("nope", {}, 0).w).toEqual(280)
		expect(ShardBoard.stack("pets", {}, "320").w).toEqual(280)
	end)

	it("keeps the pity counter clear of the lock on a phone and a desktop", function()
		for _, width in ipairs({ 280, 390, 720, 1280 }) do
			local place = ShardBoard.pityPlace(width, 1, 100)
			expect(place.text).toEqual("Pity 1/100")
			expect(place.lockX + place.lockW <= place.countX).toBeTrue()
			expect(place.countX + place.countW <= place.w).toBeTrue()
			expect(place.lockX >= 0).toBeTrue()
		end
		expect(ShardBoard.pityText(0, 1000)).toEqual("Pity 0/1000")
		expect(ShardBoard.pityPlace(280, 1, 100, { paid = true }).text).toEqual("Pity 1/100")
	end)

	it("is what the Roll tab uses for both kinds", function()
		local hub = fs.readFile(HUB)
		expect(string.find(hub, "ShardBoard.stack", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "ShardBoard.visual", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'shardStone = Instance.new("Frame")', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, 'shardStone.Name = "Shard"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "GuiImagePlaceholder", 1, true)).toBeNil()
		expect(string.find(hub, "198, 206, 214", 1, true)).toBeNil()
		local paintAt = string.find(hub, "function hubFn.paintRoll()", 1, true)
		local afterPaint = string.find(hub, "hubState.activeItem", paintAt or 1, true)
		expect(paintAt ~= nil and afterPaint ~= nil).toBeTrue()
		local paint = string.sub(hub, paintAt or 1, (afterPaint or 1) - 1)
		local fitAt = string.find(paint, "hubFn.fitRoll()", 1, true)
		local scaleAt = string.find(paint, "hubFn.applyTextScale()", (fitAt or 1) + 1, true)
		expect(fitAt ~= nil and scaleAt ~= nil and scaleAt > (fitAt :: number)).toBeTrue()
		local placeAt = string.find(hub, "function hubFn.place()", 1, true)
		local sized =
			string.find(hub, 'GetPropertyChangedSignal("AbsoluteSize")', placeAt or 1, true)
		expect(placeAt ~= nil and sized ~= nil).toBeTrue()
		local place = string.sub(hub, placeAt or 1, (sized or 1) - 1)
		local placeFit = string.find(place, "hubFn.fitRoll()", 1, true)
		local placeScale = string.find(place, "hubFn.applyTextScale()", (placeFit or 1) + 1, true)
		expect(placeFit ~= nil and placeScale ~= nil and placeScale > (placeFit :: number)).toBeTrue()
		expect(string.find(hub, 'rollButton:SetAttribute("BaseText", buttonText)', 1, true) ~= nil).toBeTrue()
		local module = fs.readFile("src/ReplicatedStorage/Shared/ShardBoard.luau")
		expect(string.find(module, "GetService", 1, true)).toBeNil()
	end)
end)
