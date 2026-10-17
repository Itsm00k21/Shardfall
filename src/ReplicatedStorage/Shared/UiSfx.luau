--!strict

--[[
	One sound id per UI action. Volume is master times the UI slider.
	Reduced motion does not mute these. A zero UI volume does.
]]

local UiSfx = {}

UiSfx.ids = {
	open = "rbxasset://sounds/switch.wav",
	close = "rbxasset://sounds/switch.wav",
	tab = "rbxasset://sounds/switch.wav",
	press = "rbxasset://sounds/electronicpingshort.wav",
	click = "rbxasset://sounds/switch.wav",
	stinger = "rbxasset://sounds/electronicpingshort.wav",
	confirm = "rbxasset://sounds/electronicpingshort.wav",
	toast = "rbxasset://sounds/electronicpingshort.wav",
}

function UiSfx.clip(action: string): string
	local id = UiSfx.ids[action]
	if type(id) ~= "string" then
		return UiSfx.ids.press
	end
	return id
end

function UiSfx.volume(master: any, ui: any): number
	local function unit(value: any): number
		if type(value) ~= "number" or value ~= value then
			return 0
		end
		return math.clamp(value, 0, 1)
	end
	return unit(master) * unit(ui)
end

return UiSfx
