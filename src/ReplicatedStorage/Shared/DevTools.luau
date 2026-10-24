--!strict

--[[
	The owner-only Dev Tools panel (Kevin, Oct 22): its sections, which
	buttons a parked system hides, the text each press shows, and where
	the Dev button and the side panel sit.

	Settings keeps player settings only. The panel is a side panel, so
	the player can still walk with it open.

	Every press gets one line back. The server sends `message` on success
	and `error` on a refusal (DevAccess, LaunchGate, no boss up, ...).
	The client toasts it and prints the same line with the [Dev] prefix.

	A button whose system is switched off in LaunchGate is hidden, and the
	server refuses the same action with offMessage(), so a stale client
	still hears why nothing happened.
]]

local HudLayout = require("./HudLayout")
local LaunchGate = require("./LaunchGate")

local DevTools = {}

DevTools.PREFIX = "[Dev]"
DevTools.BUTTON_TEXT = "Dev"
DevTools.TITLE = "Dev Tools (owner only)"

export type Entry = { id: string, label: string, remote: string, arg: string }
export type Section = { id: string, title: string, entries: { Entry } }

local function entry(id: string, label: string, remote: string, arg: string): Entry
	return table.freeze({ id = id, label = label, remote = remote, arg = arg })
end

DevTools.SECTIONS = table.freeze({
	table.freeze({
		id = "currency",
		title = "Currency",
		entries = table.freeze({
			entry("gold", "+1000 Gold", "Debug", "gold"),
			entry("shards", "+5 Shards", "DevGrant", "tokens"),
			entry("keys", "+20 Keys", "Debug", "keys"),
			entry("dust", "+50 Dust", "Debug", "dust"),
			entry("gems", "+50 Gems", "Debug", "gems"),
			entry("prisms", "+5 Prisms", "DevGrant", "prisms"),
			entry("eventTokens", "+10 Event Tokens", "Debug", "tokens"),
		}),
	}),
	table.freeze({
		id = "rolls",
		title = "Rolls / Pity",
		entries = table.freeze({
			entry("shards100", "+100 Shards", "DevGrant", "tokens100"),
			entry("pity149", "Set pity 149", "DevGrant", "pity149"),
			entry("pitySoft", "Set pity 120", "DevGrant", "pity120"),
			entry("pityReset", "Reset pity", "DevGrant", "pity0"),
		}),
	}),
	table.freeze({
		id = "progress",
		title = "Progress",
		entries = table.freeze({
			entry("level", "Level 20", "Debug", "level"),
			entry("ascend", "+1 Ascension", "DevGrant", "ascension"),
			entry("materials", "Materials bundle", "DevGrant", "materials"),
			entry("luck", "+25 Shard Luck", "DevGrant", "luck"),
			entry("boost", "Luck Boost", "DevGrant", "boost"),
			entry("forge", "Forge Boost 1h", "DevGrant", "forgeboost"),
			entry("egg", "+1 Egg", "Debug", "eggs"),
			entry("chest", "+1 Rare chest", "Debug", "chest"),
			entry("chests", "Chest pack", "DevGrant", "chests"),
		}),
	}),
	table.freeze({
		id = "run",
		title = "Run / Dungeon",
		entries = table.freeze({
			entry("vault", "Enter Vault", "Debug", "dungeon"),
			entry("boss", "Skip to boss", "Dungeon", "skip"),
			entry("phase", "Boss phase 2", "Debug", "phase"),
			entry("raid", "Raid practice", "Debug", "raid"),
		}),
	}),
	table.freeze({
		id = "salvage",
		title = "Gear salvage",
		entries = table.freeze({
			entry("salvagefill", "Fill the Bag", "Debug", "salvagefill"),
		}),
	}),
	table.freeze({
		id = "testing",
		title = "Testing",
		entries = table.freeze({
			entry("region", "Toggle region lock", "DevGrant", "restrict"),
			entry("autosave", "Force autosave", "Debug", "autosave"),
			entry("saveVersion", "Print save version", "Debug", "saveversion"),
		}),
	}),
	-- [ECHO hook] Hidden while equip / gearLevels / shardCore are off.
	table.freeze({
		id = "gear",
		title = "Gear",
		entries = table.freeze({
			entry("equip", "Seat owned gear", "Debug", "equip"),
			entry("geardupe", "Grant a dupe", "Debug", "geardupe"),
			entry("fillbag", "Fill the Bag", "Debug", "fillbag"),
			entry("essence", "Grant Essence", "Debug", "essence"),
		}),
	}),
})

-- remote:arg to the LaunchGate switch that parks it.
local GATED: { [string]: string } = {
	["Debug:chest"] = "chests",
	["DevGrant:chests"] = "chests",
	["Debug:gems"] = "pass",
	["DevGrant:prisms"] = "paid",
	["Debug:tokens"] = "events",
	["Debug:raid"] = "raids",
	["Debug:autosave"] = "saveTools",
	["Debug:saveversion"] = "saveTools",
	["Debug:equip"] = "equip",
	["Debug:geardupe"] = "gearLevels",
	["Debug:fillbag"] = "gearLevels",
	["Debug:essence"] = "shardCore",
	["Debug:salvagefill"] = "gearSalvage",
}

local GATE_NAME: { [string]: string } = {
	chests = "The chest system",
	pass = "The Shard Pass (Gems)",
	paid = "Paid rolls (Prisms)",
	events = "The events system (Event Tokens)",
	raids = "The raid system",
	saveTools = "Save tools",
	equip = "Equip",
	gearLevels = "Gear levels",
	shardCore = "Shard Core",
	gearSalvage = "Gear salvage",
}

function DevTools.gateOf(remote: string, arg: any): string?
	if type(arg) ~= "string" then
		return nil
	end
	return GATED[remote .. ":" .. arg]
end

function DevTools.offMessage(flag: string): string
	return string.format(
		"%s is off (LaunchGate.%s), so this does nothing yet.",
		GATE_NAME[flag] or flag,
		flag
	)
end

-- nil when the action may run. Otherwise why it is refused.
function DevTools.blocked(remote: string, arg: any, isOn: ((string) -> boolean)?): string?
	local flag = DevTools.gateOf(remote, arg)
	if flag == nil then
		return nil
	end
	local on = if isOn ~= nil then isOn(flag) else LaunchGate.on(flag)
	if on then
		return nil
	end
	return DevTools.offMessage(flag)
end

function DevTools.visible(item: Entry, isOn: ((string) -> boolean)?): boolean
	return DevTools.blocked(item.remote, item.arg, isOn) == nil
end

-- Labels of the buttons a parked system hides, for the panel footer.
function DevTools.hiddenLabels(isOn: ((string) -> boolean)?): { string }
	local hidden = {}
	for _, section in ipairs(DevTools.SECTIONS) do
		for _, item in ipairs(section.entries) do
			if not DevTools.visible(item, isOn) then
				table.insert(hidden, item.label)
			end
		end
	end
	return hidden
end

-- The one line a press shows. `called` is false when InvokeServer threw.
function DevTools.resultText(label: string, called: boolean, result: any): (boolean, string)
	if not called then
		return false, string.format("%s failed: %s", label, tostring(result))
	end
	if type(result) ~= "table" then
		return false, string.format("%s: no answer from the server.", label)
	end
	if result.ok ~= true then
		local why = result.error
		if type(why) ~= "string" or why == "" then
			why = "the server refused."
		end
		return false, string.format("%s: %s", label, why)
	end
	local message = result.message
	if type(message) ~= "string" or message == "" then
		message = result.note
	end
	if type(message) ~= "string" or message == "" then
		return true, label .. ": done."
	end
	return true, message
end

function DevTools.outputLine(ok: boolean, text: string): string
	return string.format("%s %s %s", DevTools.PREFIX, if ok then "ok" else "FAIL", text)
end

export type Rect = { x: number, y: number, w: number, h: number }

-- The Dev button sits right-aligned just under the Gold / Mastery /
-- Shards pills, clear of the toast stack. The panel opens under it on
-- the right and stops above the action bar, so the middle of the screen
-- stays playable.
function DevTools.layout(viewportX: number, viewportY: number, margin: number): (Rect, Rect)
	local vx = if type(viewportX) == "number" and viewportX >= 200 then viewportX else 1280
	local vy = if type(viewportY) == "number" and viewportY >= 200 then viewportY else 800
	local pills = HudLayout.pills(vx, margin)
	local buttonW, buttonH = 56, 32
	local button = {
		x = vx - margin - buttonW,
		y = pills.y + pills.h + 8,
		w = buttonW,
		h = buttonH,
	}
	local width = math.min(300, vx - margin * 2)
	local top = button.y + buttonH + 8
	-- Leave the bottom band for the action bar and skills.
	local bottom = vy - math.max(margin, math.floor(vy * 0.22))
	local height = math.max(160, bottom - top)
	if top + height > vy - margin then
		height = math.max(0, vy - margin - top)
	end
	local panel = { x = vx - margin - width, y = top, w = width, h = height }
	return button, panel
end

return table.freeze(DevTools)
