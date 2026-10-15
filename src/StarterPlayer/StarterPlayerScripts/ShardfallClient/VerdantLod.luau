--!strict

--[[
	Client graphics tier.

	Hides trim props and small dressing, scales particles, and turns decor
	shadows off. LocalTransparencyModifier and emitter fields stay on this
	client, so another player's High setting still sees the full hub.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HavenLife = require(Shared:WaitForChild("HavenLife"))
local Quality = require(Shared:WaitForChild("Quality"))

local VerdantLod = {}

local tierId = "med"
local nextScan = 0
local bases: { [ParticleEmitter]: number } = {}

function VerdantLod.setTier(id: string)
	local known = Quality.normalize(id)
	if known ~= nil then
		tierId = known
	end
	nextScan = 0
end

function VerdantLod.tier(): string
	return tierId
end

local function applyLighting(tier: Quality.Tier)
	Lighting.FogEnd = tier.fogEnd
	if Lighting.FogStart > tier.fogEnd * 0.25 then
		Lighting.FogStart = tier.fogEnd * 0.15
	end
	local exposure = HavenLife.exposure(Lighting.ClockTime)
	local bloom = Lighting:FindFirstChild("VerdantBloom")
	if bloom ~= nil and bloom:IsA("BloomEffect") then
		bloom.Intensity = math.min(tier.bloom, exposure.bloomIntensity)
		bloom.Size = exposure.bloomSize
		bloom.Threshold = math.max(bloom.Threshold, exposure.bloomThreshold)
	end
	local rays = Lighting:FindFirstChild("VerdantSunRays")
	if rays ~= nil and rays:IsA("SunRaysEffect") then
		rays.Intensity = exposure.sunIntensity
		rays.Spread = exposure.sunSpread
	end
end

local artReported = false

local function reportArt(trimmed: number)
	if artReported then
		return
	end
	local haven = Workspace:FindFirstChild("Haven")
	if haven == nil then
		return
	end
	local parts = 0
	local waterfalls = 0
	local npcs = 0
	local waystones = 0
	for _, descendant in ipairs(haven:GetDescendants()) do
		if descendant:IsA("BasePart") then
			parts += 1
			if descendant.Name == "Waterfall" then
				waterfalls += 1
			end
			if
				descendant.Name == "Waystone"
				or type(descendant:GetAttribute("WaystoneId")) == "string"
			then
				waystones += 1
			end
		elseif descendant:IsA("Model") and descendant.Name == "Townsfolk" then
			npcs += 1
		end
	end
	if parts < 10 then
		return
	end
	artReported = true
	print(
		string.format(
			"[HavenArt] built %d parts: waterfalls %d, npcs %d, waystones %d; trimmed %d by tier %s",
			parts,
			waterfalls,
			npcs,
			waystones,
			trimmed,
			tierId
		)
	)
end

function VerdantLod.start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextScan then
			return
		end
		nextScan = now + 1.5
		local tier = Quality.get(tierId)
		applyLighting(tier)
		local camera = Workspace.CurrentCamera
		local trimIndex = 0
		local shown = 0
		local particleIndex = 0
		local trimmed = 0
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:IsA("BasePart") then
				if
					Quality.alwaysVisible(descendant.Name, descendant:GetAttribute("WaystoneId"))
				then
					descendant.LocalTransparencyModifier = 0
					continue
				end
				local lod = descendant:GetAttribute("ShardfallLod")
				local trim = descendant:GetAttribute("ShardfallTrim") == true or lod == "small"
				if camera == nil then
					if type(lod) == "string" or trim then
						descendant.LocalTransparencyModifier = 0
					end
					continue
				end
				local origin = camera.CFrame.Position
				if type(lod) == "string" or trim then
					local distance = (descendant.Position - origin).Magnitude
					local hide = false
					if trim then
						trimIndex += 1
						local kept = Quality.keepDecor(trimIndex, tierId)
							and shown < tier.partBudget
						if kept then
							shown += 1
							local limit = if lod == "small" then tier.lodHideAt else tier.lodFar
							hide = distance > limit
						else
							hide = true
						end
					elseif lod == "large" then
						hide = distance > tier.lodFar
					end
					if hide then
						trimmed += 1
					end
					descendant.LocalTransparencyModifier = if hide then 1 else 0
					local lodName = if type(lod) == "string" then lod else "large"
					descendant.CastShadow = (not hide) and Quality.castShadow(lodName, tierId)
					for _, child in ipairs(descendant:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							particleIndex += 1
							if bases[child] == nil then
								bases[child] = child.Rate
							end
							local allow = not hide
								and Quality.particleEnabled(particleIndex, tierId)
							child.Enabled = allow
							if allow then
								child.Rate = Quality.particleRate(bases[child] :: number, tierId)
							end
						end
					end
				end
			end
		end
		reportArt(trimmed)
	end)
end

return VerdantLod
