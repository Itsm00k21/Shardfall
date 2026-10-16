--!strict

--[[
	Sound ids and the volume rules.

	Swap a track by editing TRACKS. An empty id means that zone stays
	quiet until a track is added. The Haven bed plays at HAVEN_VOLUME.
	The Music slider multiplies that, and the SFX slider multiplies
	SFX, UI, and Ambience.
]]

local Audio = {}

Audio.GROUPS = { "Music", "SFX", "UI", "Ambience" }
Audio.HAVEN_ZONE = "haven"
Audio.FADE_SECONDS = 2
Audio.HAVEN_VOLUME = 0.35
Audio.DEFAULT_MUSIC = 1
Audio.DEFAULT_SFX = 1

Audio.TRACKS = {
	haven = "rbxassetid://126726964341960",
	rootvault = "",
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
		return "rootvault"
	end
	return Audio.HAVEN_ZONE
end

function Audio.heard(base: number, slider: number): number
	return Audio.clampVolume(base) * Audio.clampVolume(slider)
end

table.freeze(Audio.GROUPS)
table.freeze(Audio.TRACKS)

return Audio
