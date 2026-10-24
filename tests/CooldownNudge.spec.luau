--!strict

--[[
	Cooldown nudge: one purple-hex chip over the slot instead of stacked grey
	"On cooldown" toasts, and no top-centre "Ultimate is still filling.".
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CooldownNudge = require("../src/ReplicatedStorage/Shared/CooldownNudge")

describe("Cooldown nudge", function()
	it("sorts cooldown and ultimate-charging messages from real errors", function()
		expect(CooldownNudge.kind("On cooldown")).toEqual("cooldown")
		expect(CooldownNudge.kind("Skill is cooling down.")).toEqual("cooldown")
		expect(CooldownNudge.kind("Ultimate is still filling.")).toEqual("charging")
		expect(CooldownNudge.kind("Out of range")).toEqual(nil)
		expect(CooldownNudge.kind(nil)).toEqual(nil)
	end)

	it("words the chip", function()
		expect(CooldownNudge.text("cooldown", 2.34)).toEqual("Ready in 2.3s")
		expect(CooldownNudge.text("cooldown", 0)).toEqual("On cooldown")
		expect(CooldownNudge.text("charging", 5)).toEqual("Ultimate charging")
	end)

	it("debounces mashing on one slot but answers a new slot", function()
		expect(CooldownNudge.fresh(nil, nil, 2, 10)).toBeTrue()
		expect(CooldownNudge.fresh(2, 10, 2, 10.2)).toBeFalse()
		expect(CooldownNudge.fresh(2, 10, 3, 10.2)).toBeTrue()
		expect(CooldownNudge.fresh(2, 10, 2, 10 + CooldownNudge.DEBOUNCE + 0.01)).toBeTrue()
	end)

	it("routes the action bar through the chip, not the toast", function()
		local bar = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau")
		expect(string.find(bar, "nudge(index, nudgeKind)", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "nudge(index, serverKind)", 1, true) ~= nil).toBeTrue()
	end)
end)
