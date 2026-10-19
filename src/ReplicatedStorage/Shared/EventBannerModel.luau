--!strict
--[[
	What the top-centre event banner shows. Pure, so the spec can drive it.
	Only real state is used: the Luck Boost and the timed Forge Boost on the
	profile. There is no world event feed yet, so with no boost the banner
	hides instead of inventing one.
]]

local EventBannerModel = {}

export type Chip = { id: string, text: string, kind: string }
export type View = { visible: boolean, title: string, chips: { Chip } }

local function whole(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 then
		return 0
	end
	return math.floor(value)
end

function EventBannerModel.clock(seconds: number): string
	local left = math.max(0, math.floor(seconds))
	local hours = left // 3600
	local minutes = (left % 3600) // 60
	local secs = left % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

function EventBannerModel.view(profile: any, now: number): View
	local chips: { Chip } = {}
	if type(profile) == "table" then
		local luck = whole(profile.luckBoost)
		if luck > 0 then
			table.insert(chips, { id = "luck", text = string.format("Luck +%d", luck), kind = "luck" })
		end
		local untilTime = whole(profile.forgeBoostUntil)
		if untilTime > now then
			table.insert(chips, {
				id = "forge",
				text = "Forge Boost " .. EventBannerModel.clock(untilTime - now),
				kind = "forge",
			})
		end
	end
	if #chips == 0 then
		return { visible = false, title = "", chips = chips }
	end
	return { visible = true, title = "Boosts Active", chips = chips }
end

-- True while a chip still counts down, so the client keeps ticking.
function EventBannerModel.ticking(profile: any, now: number): boolean
	return type(profile) == "table" and whole(profile.forgeBoostUntil) > now
end

return EventBannerModel
