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

local lastArtLine = ""

local function shownPart(part: BasePart): boolean
	return part.Transparency < 0.95 and part.LocalTransparencyModifier < 0.5
end

local function reportArt(trimmed: number)
	local haven = Workspace:FindFirstChild("Haven")
	if haven == nil then
		return
	end
	local parts = 0
	local waterfalls = 0
	local waterfallsShown = 0
	local waystones = 0
	local waystonesShown = 0
	local forgeShown = 0
	local npcShown = 0
	local npcs = 0
	for _, descendant in ipairs(haven:GetDescendants()) do
		if descendant:IsA("BasePart") then
			parts += 1
			local visible = shownPart(descendant)
			if descendant.Name == "Waterfall" then
				waterfalls += 1
				if visible then
					waterfallsShown += 1
				end
			end
			if descendant.Name == "Waystone" then
				waystones += 1
				if visible then
					waystonesShown += 1
				end
			end
			if descendant.Name == "ForgeFlame" and visible then
				forgeShown += 1
			end
		elseif descendant:IsA("Model") and descendant.Name == "Townsfolk" then
			npcs += 1
			local visible = false
			for _, child in ipairs(descendant:GetDescendants()) do
				if child:IsA("BasePart") and shownPart(child) then
					visible = true
					break
				end
			end
			if visible then
				npcShown += 1
			end
		end
	end
	if parts < 10 then
		return
	end
	local line = string.format(
		"[HavenArt] visible waterfalls %d/%d, npcs %d/%d, waystones %d/%d, forge %d; trimmed %d by tier %s",
		waterfallsShown,
		waterfalls,
		npcShown,
		npcs,
		waystonesShown,
		waystones,
		forgeShown,
		trimmed,
		tierId
	)
	if line == lastArtLine then
		return
	end
	lastArtLine = line
	print(line)
end

local function ancestorsOf(instance: Instance): { string }
	local names = {}
	local cursor: Instance? = instance.Parent
	local depth = 0
	while cursor ~= nil and depth < 6 do
		table.insert(names, cursor.Name)
		cursor = cursor.Parent
		depth += 1
	end
	return names
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
				local lod = descendant:GetAttribute("ShardfallLod")
				local trimAttr = descendant:GetAttribute("ShardfallTrim") == true
				local keep = descendant:GetAttribute("ShardfallKeep") == true
				local names = ancestorsOf(descendant)
				if camera == nil then
					local tagged = type(lod) == "string" or trimAttr or lod == "small"
					local landmark = keep
						or Quality.alwaysVisible(
							descendant.Name,
							descendant:GetAttribute("WaystoneId"),
							names
						)
					if tagged or landmark then
						descendant.LocalTransparencyModifier = 0
					end
					continue
				end
				local origin = camera.CFrame.Position
				local distance = (descendant.Position - origin).Magnitude
				local hide, nextTrim, nextShown = Quality.lodHide(
					descendant.Name,
					descendant:GetAttribute("WaystoneId"),
					names,
					keep,
					lod,
					trimAttr,
					distance,
					tierId,
					trimIndex,
					shown
				)
				trimIndex = nextTrim
				shown = nextShown
				local landmark = keep
					or Quality.alwaysVisible(
						descendant.Name,
						descendant:GetAttribute("WaystoneId"),
						names
					)
				if landmark then
					descendant.LocalTransparencyModifier = 0
				end
				local tagged = type(lod) == "string" or trimAttr or lod == "small"
				if tagged or keep then
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
