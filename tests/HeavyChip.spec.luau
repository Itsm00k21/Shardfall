--!strict

--[[
	HeavyChip is pure. The combat scripts do not run under Lune.
	The source lock checks the phone chip, the charged slash, and
	that a processed tap still returns before a swing.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local HeavyChip = require("../src/ReplicatedStorage/Shared/HeavyChip")

local BAR = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau"
local STAGE = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatStage.luau"
local HUD = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau"
local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau"
local CHIP = "src/ReplicatedStorage/Shared/HeavyChip.luau"

local PHONE = { x = 158, y = 480, w = 52, h = 52 }

local LOCKED = {
	{ 390, 844, PHONE },
	{ 844, 390, { x = 520, y = 262, w = 52, h = 52 } },
	{ 800, 380, { x = 476, y = 252, w = 52, h = 52 } },
	{ 1280, 720, { x = 956, y = 504, w = 52, h = 52 } },
}

local function same(box, want)
	expect(box.x).toEqual(want.x)
	expect(box.y).toEqual(want.y)
	expect(box.w).toEqual(want.w)
	expect(box.h).toEqual(want.h)
end

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("HeavyChip", function()
	it("sits above Dodge on the phone cluster", function()
		for _, row in ipairs(LOCKED) do
			local vx = row[1]
			local vy = row[2]
			local want = row[3]
			local box = HeavyChip.place(vx, vy)
			same(box, want)
			local bar = ActionSlots.placement(vx, vy, true)
			local dodge = ActionSlots.prompts(bar, vx, vy).dodge
			expect(box.x).toEqual(dodge.x)
			expect(box.y).toEqual(dodge.y - dodge.h - 8)
			expect(box.w).toEqual(dodge.w)
			expect(box.h).toEqual(dodge.h)
			expect(box.y >= 0).toBeTrue()
			expect(box.x + box.w <= vx).toBeTrue()
			expect(ActionSlots.overlaps(box, dodge)).toEqual(false)
			local barRect = { x = bar.x, y = bar.y, w = bar.w, h = bar.h }
			expect(ActionSlots.overlaps(box, barRect)).toEqual(false)
			expect(ActionSlots.overlaps(box, ActionSlots.joystick(vy))).toEqual(false)
			expect(ActionSlots.overlaps(box, ActionSlots.toastHost(vx))).toEqual(false)
		end
		same(HeavyChip.place(nil, nil), PHONE)
		same(HeavyChip.place("390", 844), PHONE)
		same(HeavyChip.place(390, 0 / 0), PHONE)
		same(HeavyChip.place(math.huge, 844), PHONE)
		same(HeavyChip.place(100, 844), PHONE)
	end)

	it("shows only on a phone layout", function()
		expect(HeavyChip.show(true)).toEqual(true)
		expect(HeavyChip.show(false)).toEqual(false)
		expect(HeavyChip.show(nil)).toEqual(false)
		expect(HeavyChip.show("true")).toEqual(false)
		expect(HeavyChip.show(1)).toEqual(false)
	end)

	it("ignores a third argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		same(HeavyChip.place(390, 844, { paid = true }), PHONE)
		same(HeavyChip.place(390, 844, paid), PHONE)
		same(HeavyChip.place(nil, nil, paid), PHONE)
		expect(HeavyChip.show(true, paid)).toEqual(true)
		expect(HeavyChip.show(false, { paid = true })).toEqual(false)
		expect(HeavyChip.show(nil, paid)).toEqual(false)
	end)

	it("does not write its arguments", function()
		local size = { x = 390, y = 844, paid = true }
		local extra = { paid = true, productId = 0, robux = 0, cost = 0, skip = false }
		table.freeze(size)
		table.freeze(extra)
		same(HeavyChip.place(size, size, extra), PHONE)
		expect(HeavyChip.show(size, extra)).toEqual(false)
		expect(size.x).toEqual(390)
		expect(size.y).toEqual(844)
		expect(size.paid).toEqual(true)
		expect(extra.paid).toEqual(true)
		expect(extra.productId).toEqual(0)
		expect(extra.robux).toEqual(0)
		expect(extra.cost).toEqual(0)
		expect(extra.skip).toEqual(false)
	end)

	it("does not use a clock, rng, or services", function()
		local source = fs.readFile(CHIP)
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		expect(string.find(source, "tick(", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
		expect(string.find(source, "ActionSlots", 1, true) ~= nil).toBeTrue()
	end)

	it("plays the heavy slash from R, ButtonX, and the phone chip", function()
		local bar = fs.readFile(BAR)
		local stage = fs.readFile(STAGE)
		local hud = fs.readFile(HUD)
		local client = fs.readFile(CLIENT)
		expect(string.find(bar, 'promptButton("Heavy", "Heavy")', 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "HeavyChip.place", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "HeavyChip.show", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "callbacks.onHeavy", 1, true) ~= nil).toBeTrue()
		expect(string.find(stage, "charged == true", 1, true) ~= nil).toBeTrue()
		expect(string.find(stage, "advanceCombo(chain, lastSwing, now, heavy)", 1, true) ~= nil).toBeTrue()
		local began = between(hud, "UserInputService.InputBegan:Connect", "return CombatHud")
		local processedAt = string.find(began, "if processed then", 1, true)
		local heavyAt = string.find(began, "CombatStage.swing(true)", 1, true)
		expect(processedAt ~= nil).toBeTrue()
		expect(heavyAt ~= nil).toBeTrue()
		expect((processedAt :: number) < (heavyAt :: number)).toBeTrue()
		expect(string.find(began, "CombatHud.swing(true)", 1, true) ~= nil).toBeTrue()
		expect(string.find(began, "CombatHud.swing(false)", 1, true) ~= nil).toBeTrue()
		local heavyCall = between(client, "onHeavy = function()", "onDodgeChip")
		expect(string.find(heavyCall, "CombatStage.swing(true)", 1, true) ~= nil).toBeTrue()
		expect(string.find(heavyCall, "CombatHud.swing(true)", 1, true) ~= nil).toBeTrue()
		local lightCall = between(client, "onLight = function()", "onHeavy = function()")
		expect(string.find(lightCall, "CombatStage.swing()", 1, true) ~= nil).toBeTrue()
		expect(string.find(lightCall, "CombatHud.swing(false)", 1, true) ~= nil).toBeTrue()
		expect(string.find(lightCall, "swing(true)", 1, true)).toBeNil()
	end)
end)
