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
local Quality = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quality"))

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
	local bloom = Lighting:FindFirstChild("VerdantBloom")
	if bloom ~= nil and bloom:IsA("BloomEffect") then
		bloom.Intensity = tier.bloom
	end
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
		local origin = if camera ~= nil then camera.CFrame.Position else Vector3.zero
		local trimIndex = 0
		local shown = 0
		local particleIndex = 0
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local lod = descendant:GetAttribute("ShardfallLod")
				local trim = descendant:GetAttribute("ShardfallTrim") == true or lod == "small"
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
	end)
end

return VerdantLod
