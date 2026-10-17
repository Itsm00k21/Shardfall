--!strict

--[[
	Per-player options saved on the profile.

	Graphics quality still mirrors Schema.graphicsQuality so the existing
	tier resolver keeps working. "auto" stores an empty graphics tier.
]]

local Keybinds = require("./Keybinds")

local Settings = {}

export type Hotkeys = {
	hero: string,
	bag: string,
	pets: string,
	roll: string,
	raids: string,
	market: string,
}

export type Data = {
	graphics: {
		quality: string,
		vfx: number,
		shadows: boolean,
		fpsCap: number,
	},
	rolls: {
		animation: string,
		skipAt: string,
		autoConfirm: boolean,
		autoJunk: string,
		junkBelow: string,
	},
	camera: {
		shake: boolean,
		flash: string,
		sensitivity: number,
		fov: number,
	},
	audio: {
		master: number,
		music: number,
		sfx: number,
		ui: number,
	},
	hud: {
		hidden: boolean,
		scale: number,
		damageNumbers: boolean,
		otherVfx: boolean,
		nameplates: boolean,
	},
	controls: {
		hotkeys: Hotkeys,
		mobileScale: number,
		layoutEdit: boolean,
		layout: { [string]: { number } },
	},
	social: {
		trades: string,
		raidInvites: boolean,
		chatFilter: string,
	},
	access: {
		colorblind: boolean,
		textScale: number,
		holdToTap: boolean,
	},
}

local QUALITY = { auto = true, low = true, med = true, high = true }
local ANIM = { full = true, short = true, instant = true }
local SKIP = { off = true, rare = true, epic = true, legendary = true, mythic = true }
local JUNK = { ask = true, keep = true, salvage = true }
local BELOW = { Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true }
local FLASH = { normal = true, reduced = true }
local TRADES = { everyone = true, friends = true, off = true }
local FILTER = { default = true, strict = true, off = true }
local FPS = { [30] = true, [60] = true, [120] = true }

local HOTKEY_FIELDS = Keybinds.MENU_ORDER

function Settings.default(): Data
	return {
		graphics = { quality = "auto", vfx = 1, shadows = true, fpsCap = 60 },
		rolls = {
			animation = "full",
			skipAt = "legendary",
			autoConfirm = false,
			autoJunk = "ask",
			junkBelow = "Rare",
		},
		camera = { shake = true, flash = "normal", sensitivity = 1, fov = 70 },
		audio = { master = 1, music = 0.7, sfx = 1, ui = 1 },
		hud = {
			hidden = false,
			scale = 1,
			damageNumbers = true,
			otherVfx = true,
			nameplates = true,
		},
		controls = {
			hotkeys = Keybinds.copyMenu(nil),
			mobileScale = 1,
			layoutEdit = false,
			layout = {},
		},
		social = { trades = "everyone", raidInvites = true, chatFilter = "default" },
		access = { colorblind = false, textScale = 1, holdToTap = false },
	}
end

local function clamp(value: any, fallback: number, low: number, high: number): number
	local number = tonumber(value)
	if number == nil or number ~= number then
		return fallback
	end
	return math.clamp(number, low, high)
end

local function pick(value: any, allowed: { [string]: boolean }, fallback: string): string
	if type(value) == "string" and allowed[string.lower(value)] == true then
		return string.lower(value)
	end
	return fallback
end

local function junkMode(value: any): string
	if type(value) == "string" and JUNK[string.lower(value)] == true then
		return string.lower(value)
	end
	return "ask"
end

local function junkBelow(value: any): string
	if type(value) ~= "string" or value == "" then
		return "Rare"
	end
	local titled = string.upper(string.sub(value, 1, 1)) .. string.lower(string.sub(value, 2))
	if BELOW[titled] == true then
		return titled
	end
	return "Rare"
end

local function hotkey(value: any, fallback: string): string
	if type(value) ~= "string" then
		return fallback
	end
	local trimmed = string.upper(string.sub(value, 1, 1))
	if string.match(trimmed, "^%a$") == nil then
		return fallback
	end
	return trimmed
end

function Settings.normalize(raw: any): Data
	local base = Settings.default()
	if type(raw) ~= "table" then
		return base
	end
	local graphics = if type(raw.graphics) == "table" then raw.graphics else {}
	local rolls = if type(raw.rolls) == "table" then raw.rolls else {}
	local camera = if type(raw.camera) == "table" then raw.camera else {}
	local audio = if type(raw.audio) == "table" then raw.audio else {}
	local hud = if type(raw.hud) == "table" then raw.hud else {}
	local controls = if type(raw.controls) == "table" then raw.controls else {}
	local social = if type(raw.social) == "table" then raw.social else {}
	local access = if type(raw.access) == "table" then raw.access else {}
	local keys = if type(controls.hotkeys) == "table" then controls.hotkeys else {}
	local hotkeys = base.controls.hotkeys
	for _, field in ipairs(HOTKEY_FIELDS) do
		hotkeys[field] = hotkey(keys[field], hotkeys[field])
	end
	hotkeys = Keybinds.sanitize(hotkeys)
	local fpsNumber = tonumber(graphics.fpsCap)
	local fps = 60
	if
		fpsNumber ~= nil
		and fpsNumber == fpsNumber
		and fpsNumber == math.floor(fpsNumber)
		and FPS[fpsNumber] == true
	then
		fps = fpsNumber
	end
	local SKILL_SLOTS = { "Attack", "Dodge", "Skill1", "Skill2", "Ult", "Heavy" }
	local layout: { [string]: { number } } = {}
	if type(controls.layout) == "table" then
		for _, name in ipairs(SKILL_SLOTS) do
			local pair = controls.layout[name]
			if type(pair) == "table" then
				local x = tonumber(pair[1])
				local y = tonumber(pair[2])
				if x ~= nil and y ~= nil then
					layout[name] = {
						math.clamp(math.floor(x), -2000, 4000),
						math.clamp(math.floor(y), -2000, 4000),
					}
				end
			end
		end
	end
	return {
		graphics = {
			quality = pick(graphics.quality, QUALITY, "auto"),
			vfx = clamp(graphics.vfx, 1, 0, 1),
			shadows = graphics.shadows ~= false,
			fpsCap = fps,
		},
		rolls = {
			animation = pick(rolls.animation, ANIM, "full"),
			skipAt = pick(rolls.skipAt, SKIP, "legendary"),
			autoConfirm = rolls.autoConfirm == true,
			autoJunk = junkMode(rolls.autoJunk),
			junkBelow = junkBelow(rolls.junkBelow),
		},
		camera = {
			shake = camera.shake ~= false,
			flash = pick(camera.flash, FLASH, "normal"),
			sensitivity = clamp(camera.sensitivity, 1, 0.4, 2),
			fov = clamp(camera.fov, 70, 50, 90),
		},
		audio = {
			master = clamp(audio.master, 1, 0, 1),
			music = clamp(audio.music, 0.7, 0, 1),
			sfx = clamp(audio.sfx, 1, 0, 1),
			ui = clamp(audio.ui, 1, 0, 1),
		},
		hud = {
			hidden = hud.hidden == true,
			scale = clamp(hud.scale, 1, 0.9, 1.25),
			damageNumbers = hud.damageNumbers ~= false,
			otherVfx = hud.otherVfx ~= false,
			nameplates = hud.nameplates ~= false,
		},
		controls = {
			hotkeys = hotkeys,
			mobileScale = clamp(controls.mobileScale, 1, 0.9, 1.25),
			layoutEdit = controls.layoutEdit == true,
			layout = layout,
		},
		social = {
			trades = pick(social.trades, TRADES, "everyone"),
			raidInvites = social.raidInvites ~= false,
			chatFilter = pick(social.chatFilter, FILTER, "default"),
		},
		access = {
			colorblind = access.colorblind == true,
			textScale = clamp(access.textScale, 1, 1, 1.4),
			holdToTap = access.holdToTap == true,
		},
	}
end

-- Rank used by the roll skip threshold. Higher means rarer.
local RANK = { off = 99, common = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4, mythic = 5 }

function Settings.skipsCutscene(settings: Data, rarity: string): boolean
	local gate = RANK[settings.rolls.skipAt] or RANK.legendary
	local rank = RANK[string.lower(rarity)] or 0
	if settings.rolls.animation == "instant" then
		return true
	end
	return rank >= gate and gate < 99
end

function Settings.rollDuration(settings: Data): number
	if settings.rolls.animation == "instant" then
		return 0
	end
	if settings.rolls.animation == "short" then
		return 0.7
	end
	return 1.65
end

return Settings
