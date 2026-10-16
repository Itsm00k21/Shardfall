--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Audio = require("../src/ReplicatedStorage/Shared/Audio")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")

describe("Audio", function()
	it("keeps Kevin's Haven track id in one place", function()
		expect(Audio.TRACKS.haven).toEqual("rbxassetid://126726964341960")
		expect(Audio.trackFor("haven")).toEqual("rbxassetid://126726964341960")
		expect(Audio.HAVEN_VOLUME).toEqual(0.35)
		expect(Audio.FADE_SECONDS).toEqual(2)
	end)

	it("gives Rootvault and Grandmother Gnarl separate entries on one asset", function()
		local crawl = "rbxassetid://122681644942798"
		expect(Audio.Rootvault).toEqual(crawl)
		expect(Audio.GnarlBoss).toEqual(crawl)
		expect(Audio.TRACKS.rootvault).toEqual(Audio.Rootvault)
		expect(Audio.TRACKS.gnarlBoss).toEqual(Audio.GnarlBoss)
		expect(Audio.trackFor("rootvault")).toEqual(crawl)
		expect(Audio.trackFor("gnarlBoss")).toEqual(crawl)
		expect(Audio.trackFor(Audio.GNARL_ZONE)).toEqual(Audio.GnarlBoss)
		expect(Audio.TRACKS.verdant).toEqual("")
		expect(Audio.trackFor("verdant")).toBeNil()
		expect(Audio.trackFor("nowhere")).toBeNil()
		expect(Audio.zoneFor(false)).toEqual("haven")
		expect(Audio.zoneFor(true)).toEqual("rootvault")
		expect(Audio.zoneForRun(true, false, Dungeons.ROOTVAULT_ID)).toEqual(Audio.ROOTVAULT_ZONE)
		expect(Audio.zoneForRun(true, true, Dungeons.ROOTVAULT_ID)).toEqual(Audio.GNARL_ZONE)
		expect(Audio.zoneForRun(true, false, Dungeons.WAVES_ID)).toEqual(Audio.ROOTVAULT_ZONE)
		expect(Audio.zoneForRun(true, true, Dungeons.WAVES_ID)).toEqual(Audio.GNARL_ZONE)
		expect(Audio.zoneForRun(false, true, Dungeons.ROOTVAULT_ID)).toBeNil()
		expect(Audio.zoneForRun(true, true, "tidecrypt")).toBeNil()
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
