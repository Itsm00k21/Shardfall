--!strict

--[[
	Loading and teleport screen.

	Paints one G-020 tip, then replaces that line with the next
	tip from LoadingTips.line. A normal join and a teleport both
	show that same sequence, starting at step 0. A paid hop is
	not a different list. This screen does not look up a pass
	or a purchase.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LoadingTips = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LoadingTips"))

local LoadingHud = {}

local LINE_SECONDS = 2.5

local screenGui: ScreenGui? = nil
local tipLabel: TextLabel? = nil
local generation = 0

local function showAt(generationNow: number, index: number)
	if generationNow ~= generation then
		return
	end
	local label = tipLabel
	if label == nil then
		return
	end
	local row = LoadingTips.line(index)
	if row == nil then
		return
	end
	label.Text = row.text
end

local function present()
	local gui = screenGui
	if gui == nil or tipLabel == nil then
		return
	end
	generation += 1
	local generationNow = generation
	showAt(generationNow, 0)
	gui.Enabled = true
	task.delay(LINE_SECONDS, function()
		showAt(generationNow, 1)
	end)
	task.delay(LINE_SECONDS * 2, function()
		if generationNow ~= generation then
			return
		end
		gui.Enabled = false
	end)
end

local function hide()
	generation += 1
	local gui = screenGui
	if gui ~= nil then
		gui.Enabled = false
	end
end

function LoadingHud.start(playerGui: PlayerGui)
	local existing = playerGui:FindFirstChild("ShardfallLoading")
	if existing ~= nil then
		existing:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallLoading"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 110
	screen.Enabled = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	screenGui = screen

	local frame = Instance.new("Frame")
	frame.Name = "Shade"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = screen

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.new(0.8, 0, 0, 28)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 214, 120)
	title.Text = "Shardfall"
	title.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Tip"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.46)
	label.Size = UDim2.new(0.86, 0, 0, 72)
	label.Font = Enum.Font.BuilderSans
	label.TextSize = 20
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = Color3.fromRGB(240, 236, 248)
	label.Text = ""
	label.Parent = frame
	tipLabel = label

	-- Join, and a teleport that has already landed, both start here.
	present()

	TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
		present()
	end)

	local player = Players.LocalPlayer
	if player ~= nil then
		player.OnTeleport:Connect(function(state)
			if state == Enum.TeleportState.Failed then
				hide()
				return
			end
			present()
		end)
	end
end

return LoadingHud
