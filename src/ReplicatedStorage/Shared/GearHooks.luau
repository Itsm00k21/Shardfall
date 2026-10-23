--!strict
-- Ghost-side text for Echo's gear stages. Pure. No remotes, no writes.
--
--   revealNote(result)  the reveal-card line for a merged dupe or an
--                       auto-salvaged drop, or nil.
--   bagFull(ok, result) true when a roll was refused for a full Bag.
--   nudgeLabel(nudge)   "Salvage now" button text for a nudge answer, or
--                       nil when the server found nothing to salvage.

local GearHooks = {}

GearHooks.SALVAGE_NOW = "Salvage now"

local function whole(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then
		return nil
	end
	return math.floor(value)
end

function GearHooks.revealNote(result: any): string?
	if type(result) ~= "table" then
		return nil
	end
	if result.merged == true then
		local text = result.levelText
		if type(text) ~= "string" or text == "" then
			local old = whole(result.oldLevel)
			local new = whole(result.newLevel)
			if old ~= nil and new ~= nil then
				text = string.format("★%d -> ★%d", old, new)
			else
				text = "Merged into your copy"
			end
		end
		local essence = whole(result.essence)
		if essence ~= nil and essence > 0 then
			text = string.format("%s  +%d Essence", text :: string, essence)
		end
		return text
	end
	if result.autoSalvaged == true then
		local gained = whole(result.essenceGained) or 0
		return string.format("Auto-salvaged  +%d Essence", gained)
	end
	return nil
end

local function reason(_ok: any, result: any): string?
	if type(result) == "string" then
		return result
	end
	if type(result) == "table" and type(result.error) == "string" then
		return result.error
	end
	return nil
end

function GearHooks.bagFull(ok: any, result: any): boolean
	local text = reason(ok, result)
	if text == nil then
		return false
	end
	local lower = string.lower(text)
	if string.find(lower, "full", 1, true) == nil then
		return false
	end
	return string.find(lower, "inventory", 1, true) ~= nil
		or string.find(lower, "bag", 1, true) ~= nil
end

function GearHooks.nudgeLabel(nudge: any): string?
	if type(nudge) ~= "table" or type(nudge.token) ~= "string" or nudge.token == "" then
		return nil
	end
	local count = whole(nudge.count) or 0
	if count <= 0 then
		return nil
	end
	local gain = whole(nudge.gain) or 0
	return string.format("%s  (%d for +%d Essence)", GearHooks.SALVAGE_NOW, count, gain)
end

return GearHooks
