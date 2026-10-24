--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local NotifyBadges = require("../src/ReplicatedStorage/Shared/NotifyBadges")

describe("NotifyBadges", function()
	it("lights new items, a missing class, stat points, and a pass reward", function()
		local profile = {
			classId = "",
			level = 1,
			dailyBossReady = true,
			inventory = {
				a = { name = "Oak", obtainedAt = 5 },
			},
		}
		-- Classes off (live): no "Choose class" badge.
		local off = NotifyBadges.evaluate(profile, NotifyBadges.blank())
		expect(off.hero.on).toEqual(false)
		expect(off.hero.tip).toEqual("Hero")
		local saved = LaunchGate.SHOW.classes
		LaunchGate.SHOW.classes = true
		local ok, err = pcall(function()
			local on = NotifyBadges.evaluate(profile, NotifyBadges.blank())
			expect(on.hero.on).toEqual(true)
			expect(on.hero.tip).toEqual("Choose class")
		end)
		LaunchGate.SHOW.classes = saved
		if not ok then
			error(err, 0)
		end
		local badges = NotifyBadges.evaluate(profile, NotifyBadges.blank())
		expect(badges.bag.on).toEqual(true)
		expect(badges.pass.on).toEqual(true)
		local seen = NotifyBadges.view(NotifyBadges.blank(), "hero", profile)
		seen = NotifyBadges.view(seen, "bag", profile)
		seen = NotifyBadges.view(seen, "pass", profile)
		badges = NotifyBadges.evaluate(profile, seen)
		expect(badges.hero.on).toEqual(false)
		expect(badges.bag.on).toEqual(false)
		expect(badges.pass.on).toEqual(false)
		profile.inventory.b = { name = "Ash", obtainedAt = 9 }
		badges = NotifyBadges.evaluate(profile, seen)
		expect(badges.bag.on).toEqual(true)
	end)

	it("uses the unspent level-5 talent as stat points and clears it on Hero", function()
		local id = "warden"
		local profile = {
			classId = id,
			level = Classes.TALENT_LEVEL,
			classTalent = {},
			dailyBossReady = false,
			inventory = {},
		}
		local badges = NotifyBadges.evaluate(profile, NotifyBadges.blank())
		expect(badges.hero.on).toEqual(true)
		expect(badges.hero.tip).toEqual("Stat points")
		local seen = NotifyBadges.view(NotifyBadges.blank(), "hero", profile)
		badges = NotifyBadges.evaluate(profile, seen)
		expect(badges.hero.on).toEqual(false)
		profile.classTalent[id] = "taken"
		seen = NotifyBadges.prepare(seen, profile)
		profile.classTalent = {}
		badges = NotifyBadges.evaluate(profile, seen)
		expect(badges.hero.on).toEqual(true)
	end)
end)
