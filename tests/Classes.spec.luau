--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Classes = require("../src/ReplicatedStorage/Shared/Classes")

describe("Classes", function()
	it("lists five classes with a resource, a passive, and four skills", function()
		expect(#Classes.all()).toEqual(5)
		for _, row in ipairs(Classes.all()) do
			expect(Classes.get(row.id)).toEqual(row)
			expect(#row.skills).toEqual(4)
			expect(row.resource ~= "").toEqual(true)
			expect(row.passive ~= "").toEqual(true)
			expect(row.ultimate.name ~= "").toEqual(true)
			expect(#row.talents).toEqual(2)
			expect(row.sounds.swing).toEqual("")
		end
	end)

	it("reaches the level 5 talent and stops at 30", function()
		local level, rest, need = Classes.progress(0)
		expect(level).toEqual(1)
		expect(rest).toEqual(0)
		expect(need).toEqual(40)
		local total = 0
		for step = 1, 4 do
			total += 40 * step
		end
		level = Classes.progress(total)
		expect(level).toEqual(5)
		expect(Classes.progress(999999)).toEqual(30)
		expect(Classes.validTalent("warden", "thornmail")).toEqual(true)
		expect(Classes.validTalent("warden", "eternal_grove")).toEqual(false)
	end)

	it("prints ultimates as Ult and keeps fractional cooldowns", function()
		local tide = Classes.get("tidecaller")
		assert(tide ~= nil)
		expect(tide.passiveNote ~= "").toEqual(true)
		expect(Classes.skillLine(tide.ultimate)).toEqual("Monsoon  Ult  Rain heals the party.")
		expect(string.find(Classes.skillLine(tide.ultimate), "0s", 1, true)).toBeNil()
		local frost = Classes.get("frostblade")
		assert(frost ~= nil)
		expect(Classes.cooldownText(frost.skills[1])).toEqual("2.5s")
		local voidcaster = Classes.get("voidcaster")
		assert(voidcaster ~= nil)
		expect(Classes.cooldownText(voidcaster.skills[1])).toEqual("2.5s")
		for _, row in ipairs(Classes.all()) do
			expect(row.passiveNote ~= "").toEqual(true)
			for _, skill in ipairs(row.skills) do
				local line = Classes.skillLine(skill)
				expect(string.find(line, "  0s", 1, true)).toBeNil()
				expect(string.find(line, "  1s", 1, true)).toBeNil()
			end
			local ult = Classes.skillLine(row.ultimate)
			expect(string.find(ult, "Ult", 1, true) ~= nil).toBeTrue()
			expect(string.find(ult, "0s", 1, true)).toBeNil()
		end
	end)

	it("tunes the level 5 talent and the core passive", function()
		local warden = Classes.get("warden")
		local roots = Classes.tune(warden.skills[2], "overgrowth")
		expect(roots.radius > warden.skills[2].radius).toEqual(true)
		expect(Classes.takenMultiplier("warden", true, false) < 1).toEqual(true)
		expect(Classes.takenMultiplier("warden", false, true) < 0.5).toEqual(true)
		expect(Classes.dealtMultiplier("forgeborn", 20, 100, false) > 1).toEqual(true)
		expect(Classes.dealtMultiplier("forgeborn", 100, 100, false)).toEqual(1)
		expect(Classes.dealtMultiplier("voidcaster", 100, 100, true)).toEqual(1.2)
		expect(Classes.unstableTaken("voidcaster", true)).toEqual(1.2)
	end)
end)
