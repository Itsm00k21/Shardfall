--!strict

--[[
	T6 big-roll beam tunables. Data only.

	BIGROLL_MIN_TIER is Epic, separate from RarityConfig.reveal().announce
	(that path stays Legendary+). The server reads this module only while
	LaunchGate.bigRollBeam is on. Nothing here is saved, and nothing costs
	Robux.
]]

local Rarities = require("../Rarities")

local BigRoll = {}

-- Spec keys. MIN_TIER is the beam and the server line. announce stays Legendary+.
BigRoll.MIN_TIER = "Epic"
BigRoll.QUEUE = 3
BigRoll.GAP = 1
BigRoll.CHAT_MAX = 4
BigRoll.CHAT_WINDOW = 30
BigRoll.PLAYER_GAP = 8
-- Five Epic events in this window stop that player's Epic beams.
BigRoll.EPIC_BURST = 5
BigRoll.EPIC_WINDOW = 60
BigRoll.EPIC_MUTE = 60
BigRoll.BEAM_HOLD = table.freeze({
	Epic = 2.5,
	Legendary = 3.5,
})
BigRoll.BEAM_HEIGHT = table.freeze({
	Epic = 60,
	Legendary = 80,
})
BigRoll.FADE = 0.4
-- Reveal land plus this pad. A skipped reveal never fires before MIN_AFTER.
BigRoll.REVEAL_PAD = 0.2
BigRoll.MIN_AFTER = 0.6
-- Planar studs from spawn. Farther than this, or no character, uses FALLBACK.
-- Spawn xz matches Haven.SPAWN. FALLBACK is the Crackstone.
BigRoll.HUB_RADIUS = 96
BigRoll.SPAWN = table.freeze({ x = 0, z = 30 })
BigRoll.FALLBACK = table.freeze({ x = -12, z = 52 })

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function positive(value: any): boolean
	return finite(value) and value > 0
end

local function whole(value: any, maxValue: number): boolean
	return positive(value) and value <= maxValue and math.floor(value) == value
end

-- Rejects an unknown tier, a non-positive cap, and a reveal pad that could
-- fire before the roll. A different known MIN_TIER still passes, so the
-- threshold stays data.
function BigRoll.validate(config: any): (boolean, string?)
	if type(config) ~= "table" then
		return false, "config"
	end
	if type(config.MIN_TIER) ~= "string" or Rarities.INDEX[config.MIN_TIER] == nil then
		return false, "MIN_TIER"
	end
	if not whole(config.QUEUE, 8) then
		return false, "QUEUE"
	end
	if not positive(config.GAP) or config.GAP > 30 then
		return false, "GAP"
	end
	if not whole(config.CHAT_MAX, 20) then
		return false, "CHAT_MAX"
	end
	if not positive(config.CHAT_WINDOW) or config.CHAT_WINDOW > 120 then
		return false, "CHAT_WINDOW"
	end
	if not positive(config.PLAYER_GAP) or config.PLAYER_GAP > 120 then
		return false, "PLAYER_GAP"
	end
	if not whole(config.EPIC_BURST, 20) or config.EPIC_BURST < 2 then
		return false, "EPIC_BURST"
	end
	if not positive(config.EPIC_WINDOW) or config.EPIC_WINDOW > 300 then
		return false, "EPIC_WINDOW"
	end
	if not positive(config.EPIC_MUTE) or config.EPIC_MUTE > 300 then
		return false, "EPIC_MUTE"
	end
	local hold = config.BEAM_HOLD
	if type(hold) ~= "table" or not positive(hold.Epic) or not positive(hold.Legendary) then
		return false, "BEAM_HOLD"
	end
	local height = config.BEAM_HEIGHT
	if type(height) ~= "table" or not positive(height.Epic) or not positive(height.Legendary) then
		return false, "BEAM_HEIGHT"
	end
	if not positive(config.FADE) or config.FADE > 5 then
		return false, "FADE"
	end
	if not finite(config.REVEAL_PAD) or config.REVEAL_PAD < 0 or config.REVEAL_PAD > 5 then
		return false, "REVEAL_PAD"
	end
	if not finite(config.MIN_AFTER) or config.MIN_AFTER < 0.6 then
		return false, "MIN_AFTER"
	end
	if not positive(config.HUB_RADIUS) then
		return false, "HUB_RADIUS"
	end
	local spawn = config.SPAWN
	if type(spawn) ~= "table" or not finite(spawn.x) or not finite(spawn.z) then
		return false, "SPAWN"
	end
	local fallback = config.FALLBACK
	if type(fallback) ~= "table" or not finite(fallback.x) or not finite(fallback.z) then
		return false, "FALLBACK"
	end
	return true, nil
end

return table.freeze(BigRoll)
