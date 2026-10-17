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

return HeroView
