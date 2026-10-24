--!strict

--[[
	Which rig the hero viewport requests, and where a late model goes.
	Pure.

	rig(name) returns the rig to request. "R6" returns "R6". "R15"
	returns "R15". nil, "", "Rthro", a boolean, and any other string
	return "R15". There is no third rig.

	place(built, hasModel, viewportAlive) returns "parent", "destroy",
	or "skip". A built model in a live viewport is "parent". A built
	model whose viewport was cleared is "destroy". A failed build or a
	missing model is "skip". A value that is not true counts as false.
	"destroy" is the only answer that means the model must be destroyed.
	"skip" has nothing to destroy.

	A second argument on rig, and a fourth on place, including
	paid = true, do not change the answer. Each call reads its
	arguments and does not write them. No clock. No RNG. No services.
	Nothing here costs Robux.
]]

local HeroView = {}

export type Rig = "R6" | "R15"
export type Place = "parent" | "destroy" | "skip"

function HeroView.rig(name: any, _extra: any?): Rig
	if name == "R6" then
		return "R6"
	end
	return "R15"
end

function HeroView.place(built: any, hasModel: any, viewportAlive: any, _extra: any?): Place
	if built == true and hasModel == true then
		if viewportAlive == true then
			return "parent"
		end
		return "destroy"
	end
	return "skip"
end

-- [Ghost] Clip 7: the Bag's worn preview frames the whole body. A narrow
-- field of view keeps the character from looking fish-eyed in a tall
-- column. frameDistance is how far back the camera sits so a body of
-- height h and width w fits the viewport with 12% air. Pure.
HeroView.WORN_FOV = 40
HeroView.WORN_AIR = 1.12

function HeroView.frameDistance(height: any, width: any, aspect: any, fov: any): number
	local h = if type(height) == "number" and height == height and height > 0 then height else 5
	local w = if type(width) == "number" and width == width and width > 0 then width else 2
	local a = if type(aspect) == "number" and aspect == aspect and aspect > 0.1 then aspect else 1
	local f = if type(fov) == "number" and fov > 1 and fov < 170 then fov else HeroView.WORN_FOV
	local half = math.tan(math.rad(f) / 2)
	local byHeight = (h * HeroView.WORN_AIR / 2) / half
	local byWidth = (w * HeroView.WORN_AIR / 2) / (half * a)
	return math.max(byHeight, byWidth) + w / 2
end

return HeroView
