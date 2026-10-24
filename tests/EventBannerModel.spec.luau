--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local EventBannerModel = require("../src/ReplicatedStorage/Shared/EventBannerModel")

describe("EventBannerModel", function()
	it("hides with no boost and never invents an event", function()
		local view = EventBannerModel.view({ luckBoost = 0, forgeBoostUntil = 0 }, 1000)
		expect(view.visible).toBeFalse()
		expect(#view.chips).toEqual(0)
		expect(EventBannerModel.view(nil, 1000).visible).toBeFalse()
	end)
	it("shows a luck chip and a forge countdown only while active", function()
		local view = EventBannerModel.view({ luckBoost = 25, forgeBoostUntil = 1125 }, 1000)
		expect(view.visible).toBeTrue()
		expect(#view.chips).toEqual(2)
		expect(view.chips[1].text).toEqual("Luck +25")
		expect(view.chips[2].text).toEqual("Forge Boost 2:05")
		expect(EventBannerModel.ticking({ forgeBoostUntil = 1125 }, 1000)).toBeTrue()
		local expired = EventBannerModel.view({ luckBoost = 0, forgeBoostUntil = 900 }, 1000)
		expect(expired.visible).toBeFalse()
	end)
	it("ignores junk boost values", function()
		local view = EventBannerModel.view({ luckBoost = -5, forgeBoostUntil = 0 / 0 }, 1000)
		expect(view.visible).toBeFalse()
		expect(EventBannerModel.clock(3725)).toEqual("1:02:05")
	end)
end)
