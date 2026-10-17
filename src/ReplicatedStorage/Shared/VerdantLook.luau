--!strict

--[[
	Verdant lighting and the boss telegraph sizes.

	apply() writes Atmosphere, color, bloom, and sun rays. It does not touch
	StreamingEnabled. The marker table is what the boss room spawns for a
	root slam, a spore cloud, and the saplings.
]]

local VerdantLook = {}

VerdantLook.PRESET = {
	clockTime = 15.4,
	brightness = 1.25,
	ambient = { 96, 112, 84 },
	outdoorAmbient = { 128, 146, 112 },
	fogColor = { 156, 184, 142 },
	fogStart = 48,
	fogEnd = 320,
	atmosphere = {
		density = 0.32,
		offset = 0.18,
		color = { 168, 196, 150 },
		decay = { 196, 176, 120 },
		glare = 0.06,
		haze = 1.35,
	},
	colorCorrection = {
		brightness = 0.03,
		contrast = 0.08,
		saturation = 0.16,
		tint = { 255, 244, 220 },
	},
	bloom = {
		intensity = 0.045,
		size = 8,
		threshold = 2.05,
	},
	sunRays = {
		intensity = 0.05,
		spread = 0.22,
	},
}

VerdantLook.MARKERS = {
	slam = {
		name = "RootSlam",
		size = { 11, 0.28, 11 },
		color = { 120, 72, 36 },
		y = 0.55,
	},
	spore = {
		name = "SporeCloud",
		size = { 18, 7, 18 },
		color = { 140, 230, 176 },
		y = 3.2,
	},
	sapling = "tree_pine",
	saplingCount = 3,
	saplingScale = 0.55,
}

local function rgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local function effect(lighting: Instance, className: string, name: string): Instance
	local existing = lighting:FindFirstChild(name)
	if existing ~= nil then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = lighting
	return created
end

function VerdantLook.apply(lighting: Instance): boolean
	local preset = VerdantLook.PRESET
	local target = lighting :: any
	local ok = true
	local function assign(label: string, callback: () -> ())
		local passed, err = pcall(callback)
		if not passed then
			ok = false
			warn("[Shardfall] Verdant lighting " .. label .. " failed: " .. tostring(err))
		end
	end

	assign("sky", function()
		target.ClockTime = preset.clockTime
		target.Brightness = preset.brightness
		target.Ambient = rgb(preset.ambient)
		target.OutdoorAmbient = rgb(preset.outdoorAmbient)
		target.FogColor = rgb(preset.fogColor)
		target.FogStart = preset.fogStart
		target.FogEnd = preset.fogEnd
	end)
	assign("atmosphere", function()
		local air = effect(lighting, "Atmosphere", "VerdantAtmosphere") :: any
		air.Density = preset.atmosphere.density
		air.Offset = preset.atmosphere.offset
		air.Color = rgb(preset.atmosphere.color)
		air.Decay = rgb(preset.atmosphere.decay)
		air.Glare = preset.atmosphere.glare
		air.Haze = preset.atmosphere.haze
	end)
	assign("grade", function()
		local grade = effect(lighting, "ColorCorrectionEffect", "VerdantGrade") :: any
		grade.Brightness = preset.colorCorrection.brightness
		grade.Contrast = preset.colorCorrection.contrast
		grade.Saturation = preset.colorCorrection.saturation
		grade.TintColor = rgb(preset.colorCorrection.tint)
	end)
	assign("bloom", function()
		local bloom = effect(lighting, "BloomEffect", "VerdantBloom") :: any
		bloom.Intensity = preset.bloom.intensity
		bloom.Size = preset.bloom.size
		bloom.Threshold = preset.bloom.threshold
	end)
	assign("sun rays", function()
		local rays = effect(lighting, "SunRaysEffect", "VerdantSunRays") :: any
		rays.Intensity = preset.sunRays.intensity
		rays.Spread = preset.sunRays.spread
	end)
	assign("stacked bloom", function()
		for _, child in ipairs(lighting:GetChildren()) do
			local extraBloom = child:IsA("BloomEffect") and child.Name ~= "VerdantBloom"
			local extraRays = child:IsA("SunRaysEffect") and child.Name ~= "VerdantSunRays"
			if extraBloom or extraRays then
				(child :: any).Enabled = false
			end
		end
	end)
	return ok
end

return VerdantLook
