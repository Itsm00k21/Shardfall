--!strict

--[[
	SkillTip: Kevin's Oct 19 ask. Hovering a skill (long press on phone)
	shows name, one-line description, cooldown and effect, all read from
	the skill rows in Classes.luau; locked slots show the unlock level.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local SkillTip = require("../src/ReplicatedStorage/Shared/SkillTip")

local function firstClass()
	return Classes.all()[1]
end

describe("SkillTip text", function()
	it("reads name, note and cooldown from the skill row", function()
		local classDef = firstClass()
		local skill = classDef.skills[1]
		local tip = SkillTip.tip(classDef.id, { kind = "skill", id = skill.id }, { classXp = {} })
		expect(tip.title).toEqual(skill.name)
		expect(tip.desc).toEqual(skill.note)
		expect(tip.cooldown).toEqual("Cooldown " .. Classes.cooldownText(skill))
		expect(tip.locked).toEqual("")
	end)

	it("describes the effect from the numbers", function()
		expect(SkillTip.effect({ damage = 1.15, heal = 0, shield = 0, radius = 6 })).toEqual("Damage x1.15 weapon  ·  Area 6 studs")
		expect(SkillTip.effect({ damage = 0, heal = 0.08, shield = 0.2, radius = 0 })).toEqual("Heals 8% max HP  ·  Shield 20% max HP")
	end)

	it("shows the unlock level on a locked slot", function()
		local classDef = firstClass()
		local ult = classDef.ultimate
		local tip = SkillTip.tip(classDef.id, { kind = "skill", id = ult.id }, { classXp = {} })
		expect(tip.locked).toEqual(string.format("Unlocks at Lv %d", ActionSlots.UNLOCK[5]))
		expect(tip.locked).toEqual("Unlocks at Lv 10")
		expect(tip.cooldown).toEqual(SkillTip.LABELS.ultimate)
	end)

	it("leaves empty slots blank and sizes the card to its lines", function()
		local tip = SkillTip.tip(firstClass().id, { kind = "empty", id = "" }, nil)
		expect(tip.title).toEqual("")
		local full = SkillTip.tip(firstClass().id, { kind = "skill", id = firstClass().skills[1].id }, nil)
		expect(SkillTip.height(full)).toEqual(SkillTip.PAD * 2 + SkillTip.TITLE + #SkillTip.lines(full) * SkillTip.LINE)
	end)

	it("is wired to hover and long press in ActionBar", function()
		local bar = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau")
		expect(string.find(bar, "button.MouseEnter:Connect(function()", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "SkillTip.tip(classId(), slot, profile)", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "task.delay(0.45, function()", 1, true) ~= nil).toBeTrue()
	end)
end)
