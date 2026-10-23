--!strict

--[[
	Read-time scale for gold forge upgrades (item.upgrade).

	Stars already write their percent into stat.value (Stars.applyStats).
	This module does not write. It multiplies that saved number when a
	caller asks, so a later star feed cannot bake the gold upgrade into
	baseValue and then stack it a second time.

	+0 is ×1. The percent lives in Config/GearLevels.PER_LEVEL.

	LaunchGate.upgradeScale defaults off. Pass enabled = true to preview
	the on-state without flipping the live flag. Omit it to follow the flag,
	which is what combat and Item Power do.
]]

local GearLevels = require("./Config/GearLevels")
local LaunchGate = require("./LaunchGate")
local Stats = require("./Stats")

local UpgradeScale = {}

-- Same step Item Power already gives one star, so +1 sorts like ★1.
UpgradeScale.POWER_STEP = 10

export type Line = {
	id: string,
	value: number,
	base: number,
	text: string,
}

export type Preview = {
	upgrade: number,
	multiplier: number,
	enabled: boolean,
	lines: { Line },
}

function UpgradeScale.enabled(): boolean
	return LaunchGate.on("upgradeScale")
end

local function flagOn(enabled: boolean?): boolean
	if enabled == nil then
		return UpgradeScale.enabled()
	end
	return enabled == true
end

function UpgradeScale.multiplier(upgrade: any, enabled: boolean?): number
	if not flagOn(enabled) then
		return 1
	end
	return GearLevels.multiplier(upgrade, nil)
end

function UpgradeScale.apply(value: any, upgrade: any, enabled: boolean?): number
	if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then
		return 0
	end
	return value * UpgradeScale.multiplier(upgrade, enabled)
end

-- Item Power bonus from the forge upgrade. 0 while upgradeScale is off,
-- so today's sort order stays put until the flag is on.
function UpgradeScale.powerBonus(item: any, enabled: boolean?): number
	if not flagOn(enabled) or type(item) ~= "table" then
		return 0
	end
	local step = UpgradeScale.POWER_STEP
	if type(step) ~= "number" or step ~= step or step < 0 or step >= math.huge then
		return 0
	end
	return GearLevels.storedUpgrade(item.upgrade) * step
end

-- Bag helper. Does not mutate the item. `lines` are the stat rows to draw.
-- `base` is the saved stat.value (stars already included). `value` is what
-- to show. `text` is that value formatted with Stats.formatValue.
function UpgradeScale.preview(item: any, enabled: boolean?): Preview
	local on = flagOn(enabled)
	local upgrade = 0
	if type(item) == "table" then
		upgrade = GearLevels.storedUpgrade(item.upgrade)
	end
	local multiplier = if on then GearLevels.multiplier(upgrade, nil) else 1
	local lines: { Line } = {}
	if type(item) == "table" and type(item.stats) == "table" then
		for _, stat in ipairs(item.stats) do
			if type(stat) == "table" and type(stat.id) == "string" then
				local base = stat.value
				if type(base) == "number" and base == base and base >= 0 and base < math.huge then
					local shown = if on then base * multiplier else base
					local text = Stats.formatValue({
						id = stat.id,
						name = if type(stat.name) == "string" then stat.name else stat.id,
						value = shown,
						min = 0,
						max = shown,
						unit = if type(stat.unit) == "string" then stat.unit else "flat",
						roll = 0,
					})
					table.insert(lines, {
						id = stat.id,
						value = shown,
						base = base,
						text = text,
					})
				end
			end
		end
	end
	return {
		upgrade = upgrade,
		multiplier = multiplier,
		enabled = on,
		lines = lines,
	}
end

return UpgradeScale
