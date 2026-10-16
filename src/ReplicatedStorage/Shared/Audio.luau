--!strict

--[[
	Sound ids and the volume rules.

	Swap a track by editing the named fields. TRACKS points at those
	fields. An empty id means that zone stays quiet. Rootvault rooms and
	the Grandmother Gnarl fight share one asset for now, on separate
	fields so they can be split later. The bed plays at HAVEN_VOLUME.
	The Music slider multiplies that, and the SFX slider multiplies
	SFX, UI, and Ambience. Zone changes crossfade over FADE_SECONDS.
]]

local Audio = {}

Audio.GROUPS = { "Music", "SFX", "UI", "Ambience" }
Audio.HAVEN_ZONE = "haven"
Audio.ROOTVAULT_ZONE = "rootvault"
Audio.GNARL_ZONE = "gnarlBoss"
Audio.FADE_SECONDS = 2
Audio.HAVEN_VOLUME = 0.35
Audio.DEFAULT_MUSIC = 1
Audio.DEFAULT_SFX = 1

-- Separate entries. Both point at the same id until the boss gets its own.
Audio.Rootvault = "rbxassetid://122681644942798"
Audio.GnarlBoss = "rbxassetid://122681644942798"

Audio.TRACKS = {
	haven = "rbxassetid://126726964341960",
	rootvault = Audio.Rootvault,
	gnarlBoss = Audio.GnarlBoss,
	verdant = "",
}

function Audio.clampVolume(value: any): number
	local numberValue = tonumber(value)
	if numberValue == nil or numberValue ~= numberValue then
		return Audio.DEFAULT_MUSIC
	end
	if numberValue < 0 then
		return 0
	end
	if numberValue > 1 then
		return 1
	end
	return numberValue
end

function Audio.trackFor(zoneId: any): string?
	if type(zoneId) ~= "string" then
		return nil
	end
	local id = Audio.TRACKS[zoneId]
	if type(id) ~= "string" or string.match(id, "^rbxassetid://%d+$") == nil then
		return nil
	end
	return id
end

function Audio.zoneFor(inCrawl: boolean): string
	if inCrawl then
		return Audio.ROOTVAULT_ZONE
	end
	return Audio.HAVEN_ZONE
end

-- Rootvault story rooms and Rootvault Waves. A living boss in either
-- uses the Gnarl bed. nil means the position watch owns the zone.
function Audio.zoneForRun(active: any, boss: any, dungeonId: any): string?
	if active ~= true then
		return nil
	end
	if dungeonId ~= "rootvault" and dungeonId ~= "rootvault_waves" then
		return nil
	end
	if boss == true then
		return Audio.GNARL_ZONE
	end
	return Audio.ROOTVAULT_ZONE
end

function Audio.heard(base: number, slider: number): number
	return Audio.clampVolume(base) * Audio.clampVolume(slider)
end

table.freeze(Audio.GROUPS)
table.freeze(Audio.TRACKS)

return Audio
