--!strict

--[[
	Action-bar tooltip text (Kevin, Oct 19: hover a skill on desktop, long
	press on phone). Every word comes from the skill definitions in
	Classes.luau and the unlock levels in ActionSlots, so a skill gains a
	better tooltip by editing its row, never the UI.

	tip(classId, slot, profile) -> { title, desc, cooldown, effect, locked }
	Empty strings mean "leave that line out". Pure; no Instances.
]]

local ActionSlots = require("./ActionSlots")
local Classes = require("./Classes")
local Materials = require("./Materials")

local SkillTip = {}

SkillTip.LABELS = table.freeze({
	cooldown = "Cooldown %s",
	ultimate = "Ultimate (fills with Ult charge)",
	damage = "Damage x%s weapon",
	heal = "Heals %d%% max HP",
	shield = "Shield %d%% max HP",
	radius = "Area %d studs",
	locked = "Unlocks at Lv %d",
	tonic = "Restores some health.",
})

-- Popover geometry (pixels).
SkillTip.WIDTH = 240
SkillTip.LINE = 18
SkillTip.TITLE = 22
SkillTip.PAD = 8

export type Tip = {
	title: string,
	desc: string,
	cooldown: string,
	effect: string,
	locked: string,
}

local function blank(): Tip
	return { title = "", desc = "", cooldown = "", effect = "", locked = "" }
end

local function trimNumber(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

local function skillOf(classId: string, skillId: string): (any, number)
	local classDef = Classes.get(classId)
	if classDef == nil or skillId == "" then
		return nil, 0
	end
	for index, skill in ipairs(classDef.skills) do
		if skill.id == skillId then
			return skill, index
		end
	end
	if classDef.ultimate.id == skillId then
		return classDef.ultimate, 5
	end
	return nil, 0
end

-- One "what it does" line from the numbers on the skill row.
function SkillTip.effect(skill: any): string
	if type(skill) ~= "table" then
		return ""
	end
	local parts = {}
	if type(skill.damage) == "number" and skill.damage > 0 then
		table.insert(parts, string.format(SkillTip.LABELS.damage, trimNumber(skill.damage)))
	end
	if type(skill.heal) == "number" and skill.heal > 0 then
		table.insert(parts, string.format(SkillTip.LABELS.heal, math.floor(skill.heal * 100 + 0.5)))
	end
	if type(skill.shield) == "number" and skill.shield > 0 then
		table.insert(parts, string.format(SkillTip.LABELS.shield, math.floor(skill.shield * 100 + 0.5)))
	end
	if type(skill.radius) == "number" and skill.radius > 0 then
		table.insert(parts, string.format(SkillTip.LABELS.radius, math.floor(skill.radius + 0.5)))
	end
	return table.concat(parts, "  ·  ")
end

function SkillTip.tip(classId: any, slot: any, profile: any): Tip
	local tip = blank()
	if type(slot) ~= "table" or slot.kind == "empty" or type(slot.id) ~= "string" or slot.id == "" then
		return tip
	end
	if slot.kind == "skill" and type(classId) == "string" then
		local skill, index = skillOf(classId, slot.id)
		if skill == nil then
			return tip
		end
		tip.title = skill.name
		tip.desc = skill.note
		tip.cooldown = if skill.kind == "ult"
			then SkillTip.LABELS.ultimate
			else string.format(SkillTip.LABELS.cooldown, Classes.cooldownText(skill))
		tip.effect = SkillTip.effect(skill)
		local need = ActionSlots.UNLOCK[index] or 1
		if ActionSlots.level(profile, classId) < need then
			tip.locked = string.format(SkillTip.LABELS.locked, need)
		end
		return tip
	end
	if slot.kind == "consumable" then
		tip.title = Materials.TONIC_NAME
		tip.desc = SkillTip.LABELS.tonic
		return tip
	end
	local name, note = ActionSlots.describe(if type(classId) == "string" then classId else "", slot, profile)
	tip.title = name
	tip.desc = note
	return tip
end

-- Lines in display order, skipping blanks.
function SkillTip.lines(tip: Tip): { string }
	local out = {}
	for _, key in ipairs({ "desc", "effect", "cooldown", "locked" }) do
		local value = (tip :: any)[key]
		if type(value) == "string" and value ~= "" then
			table.insert(out, value)
		end
	end
	return out
end

function SkillTip.height(tip: Tip): number
	return SkillTip.PAD * 2 + SkillTip.TITLE + #SkillTip.lines(tip) * SkillTip.LINE
end

return table.freeze(SkillTip)
