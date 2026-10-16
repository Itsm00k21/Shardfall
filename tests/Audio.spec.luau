--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Audio = require("../src/ReplicatedStorage/Shared/Audio")

describe("Audio", function()
	it("keeps Kevin's Haven track id in one place", function()
		expect(Audio.TRACKS.haven).toEqual("rbxassetid://126726964341960")
		expect(Audio.trackFor("haven")).toEqual("rbxassetid://126726964341960")
		expect(Audio.HAVEN_VOLUME).toEqual(0.35)
		expect(Audio.FADE_SECONDS).toEqual(2)
	end)

	it("leaves other zones quiet until a track is filled in", function()
		expect(Audio.TRACKS.rootvault).toEqual("")
		expect(Audio.TRACKS.verdant).toEqual("")
		expect(Audio.trackFor("rootvault")).toBeNil()
		expect(Audio.trackFor("verdant")).toBeNil()
		expect(Audio.trackFor("nowhere")).toBeNil()
		expect(Audio.zoneFor(false)).toEqual("haven")
		expect(Audio.zoneFor(true)).toEqual("rootvault")
	end)

	it("multiplies the bed by the music slider and clamps both ends", function()
		expect(Audio.heard(Audio.HAVEN_VOLUME, 1)).toEqual(0.35)
		expect(Audio.heard(Audio.HAVEN_VOLUME, 0)).toEqual(0)
		expect(Audio.heard(Audio.HAVEN_VOLUME, 0.5)).toEqual(Audio.HAVEN_VOLUME * 0.5)
		expect(Audio.clampVolume(-2)).toEqual(0)
		expect(Audio.clampVolume(4)).toEqual(1)
		expect(Audio.clampVolume("no")).toEqual(1)
		expect(#Audio.GROUPS).toEqual(4)
	end)
end)
