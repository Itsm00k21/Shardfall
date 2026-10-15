--!strict

--[[
	Hides small Verdant props when they are far from the camera.

	Dressing is anchored and streams with the room. This only changes
	LocalTransparencyModifier, so the server parts stay put.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VerdantLod = {}

local HIDE_AT = 120
local tracked: { BasePart } = {}
local nextScan = 0

local function scan()
	table.clear(tracked)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("ShardfallLod") == "small" then
			table.insert(tracked, descendant)
		end
	end
end

function VerdantLod.start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 1.5
			scan()
		end
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local origin = camera.CFrame.Position
		for index = #tracked, 1, -1 do
			local part = tracked[index]
			if part.Parent == nil then
				table.remove(tracked, index)
			else
				local far = (part.Position - origin).Magnitude > HIDE_AT
				part.LocalTransparencyModifier = if far then 1 else 0
				for _, child in ipairs(part:GetChildren()) do
					if child:IsA("ParticleEmitter") then
						child.Enabled = not far
					end
				end
			end
		end
	end)
end

return VerdantLod
