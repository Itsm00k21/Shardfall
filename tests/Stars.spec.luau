--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Stars = require("../src/ReplicatedStorage/Shared/Stars")

describe("Stars", function()
	it("gives a perfect feeder one star and a minimum feeder a fraction", function()
		expect(Stars.feedValue(1)).toEqual(1)
		expect(Stars.feedValue(0)).toBeCloseTo(0.34, 1e-12)
		expect(Stars.feedValue(nil)).toBeCloseTo(0.34, 1e-12)
		expect(Stars.feedValue(0.5)).toBeCloseTo(0.67, 1e-12)

		local perfect = Stars.advance(0, 0, 1)
		assert(perfect ~= nil)
		expect(perfect.stars).toEqual(1)
		expect(perfect.starProgress).toEqual(0)
		expect(perfect.gained).toEqual(1)
		expect(perfect.multiplier).toBeCloseTo(1.08, 1e-12)

		local stars = 0
		local progress = 0
		for _ = 1, 3 do
			local step = Stars.advance(stars, progress, 0)
			assert(step ~= nil)
			stars = step.stars
			progress = step.starProgress
		end
		expect(stars).toEqual(1)
		expect(progress).toBeCloseTo(0.02, 1e-9)
	end)

	it("carries leftover progress and stops at five stars", function()
		local step = Stars.advance(0, 0.2, 0.84)
		assert(step ~= nil)
		-- 0.34 + 0.66 * 0.84 = 0.8944; 0.2 + 0.8944 crosses one star.
		expect(step.feed).toBeCloseTo(0.8944, 1e-9)
		expect(step.stars).toEqual(1)
		expect(step.starProgress).toBeCloseTo(0.0944, 1e-9)

		local capped = Stars.advance(4, 0.5, 1)
		assert(capped ~= nil)
		expect(capped.stars).toEqual(5)
		expect(capped.starProgress).toEqual(0)
		expect(capped.gained).toEqual(1)
		expect(capped.perks).toEqual({ "starforged", "ascendant" })

		local blocked, reason = Stars.advance(5, 0, 1)
		expect(blocked).toBeNil()
		expect(reason).toEqual("That item is already at five stars.")
		expect(Stars.multiplier(5)).toBeCloseTo(1.4, 1e-12)
		expect(Stars.multiplier(9)).toBeCloseTo(1.4, 1e-12)
		expect(Stars.perkIds(2)).toEqual({})
		expect(Stars.perkIds(3)).toEqual({ "starforged" })
	end)

	it("multiplies rolled stats from the stored base and does not compound", function()
		local item = {
			uid = "kept",
			templateId = "nightbriar",
			name = "Nightbriar",
			stars = 0,
			starProgress = 0,
			stats = { { id = "damage", value = 10 } },
		}
		Stars.applyStats(item)
		expect(item.stats[1].baseValue).toEqual(10)
		expect(item.stats[1].value).toEqual(10)

		item.stars = 2
		Stars.applyStats(item)
		expect(item.stats[1].value).toBeCloseTo(11.6, 1e-9)
		Stars.applyStats(item)
		expect(item.stats[1].baseValue).toEqual(10)
		expect(item.stats[1].value).toBeCloseTo(11.6, 1e-9)

		item.stars = 5
		Stars.applyStats(item)
		expect(item.stats[1].value).toBeCloseTo(14, 1e-9)
	end)

	it("feeds a same-base duplicate into the kept copy, including pets", function()
		local kept = {
			uid = "stag",
			templateId = "fern_stag",
			name = "Fern Stag",
			kind = "Pet",
			stars = 2,
			starProgress = 0,
			stats = { { id = "pet_damage", value = 8 } },
		}
		local other = {
			uid = "blade",
			templateId = "nightbriar",
			quality = 1,
		}
		local allowed, why = Stars.canFeed(kept, other)
		expect(allowed).toEqual(false)
		expect(why).toEqual("Feed a duplicate of the same item.")

		local feeder = {
			uid = "otter",
			templateId = "fern_stag",
			name = "Fern Stag",
			quality = 1,
		}
		local preview, reason = Stars.commit(kept, feeder)
		expect(reason).toBeNil()
		assert(preview ~= nil)
		expect(preview.stars).toEqual(3)
		expect(kept.stars).toEqual(3)
		expect(kept.perks).toEqual({ "starforged" })
		expect(kept.stats[1].baseValue).toEqual(8)
		expect(kept.stats[1].value).toBeCloseTo(8 * 1.24, 1e-9)

		local again = Stars.commit(kept, { uid = "stag", templateId = "fern_stag" })
		expect(again).toBeNil()
	end)
end)
