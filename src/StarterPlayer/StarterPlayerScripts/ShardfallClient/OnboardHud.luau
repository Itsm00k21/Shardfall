--!strict

--[[
	Cold-open card and the goal line.

	Continue only advances the text beats. Skip pays the starter kit and
	hides the card for good.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Onboarding = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Onboarding"))
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local MobileShell = require(script.Parent.MobileShell)

local OnboardHud = {}
local player = Players.LocalPlayer
local callRemote: ((string, ...any) -> any)? = nil
local title: TextLabel? = nil
local body: TextLabel? = nil
local card: Frame? = nil
local goals: TextLabel? = nil

function OnboardHud.start(invoke: (string, ...any) -> any)
	callRemote = invoke
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallOnboard"
	screen.ResetOnSpawn = false
	-- Above the hub (80), the rail (85), and the equip prompt (90).
	-- The banner stays at 100. A new player can still press Skip.
	screen.DisplayOrder = 95
	screen.Parent = player:WaitForChild("PlayerGui")
	MobileShell.mount(screen)

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(16, 96)
	frame.Size = UDim2.fromOffset(460, 144)
	frame.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen
	card = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Position = UDim2.fromOffset(12, 8)
	heading.Size = UDim2.new(1, -24, 0, 22)
	heading.Font = Enum.Font.BuilderSansBold
	heading.TextSize = 16
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Color3.fromRGB(255, 214, 120)
	heading.Text = "Shardfall"
	heading.Parent = frame
	title = heading

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(12, 32)
	text.Size = UDim2.new(1, -24, 0, 44)
	text.Font = Enum.Font.BuilderSans
	text.TextSize = 15
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextColor3 = Color3.fromRGB(240, 236, 248)
	text.Text = ""
	text.Parent = frame
	body = text

	local function press(name: string, label: string, x: number)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(x, 84)
		button.Size = UDim2.fromOffset(140, 52)
		button.BackgroundColor3 = Color3.fromRGB(108, 78, 196)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 16
		button.TextColor3 = Color3.fromRGB(240, 236, 248)
		button.Text = label
		button.Parent = frame
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 10)
		buttonCorner.Parent = button
		return button
	end
	local advance = press("Continue", "Continue", 12)
	advance.MouseButton1Click:Connect(function()
		local invokeNow = callRemote
		if invokeNow ~= nil then
			task.spawn(function()
				pcall(invokeNow, "Onboard", "advance")
			end)
		end
	end)
	local skip = press("Skip", "Skip intro", 164)
	skip.MouseButton1Click:Connect(function()
		local invokeNow = callRemote
		if invokeNow ~= nil then
			task.spawn(function()
				pcall(invokeNow, "Onboard", "skip")
			end)
		end
	end)

	local tracker = Instance.new("TextLabel")
	tracker.BackgroundTransparency = 1
	tracker.AnchorPoint = Vector2.new(0, 0)
	tracker.Position = UDim2.fromOffset(16, 248)
	tracker.Size = UDim2.fromOffset(280, 72)
	tracker.Font = Enum.Font.BuilderSans
	tracker.TextSize = 14
	tracker.TextWrapped = true
	tracker.TextXAlignment = Enum.TextXAlignment.Left
	tracker.TextYAlignment = Enum.TextYAlignment.Top
	tracker.TextColor3 = Color3.fromRGB(240, 236, 248)
	tracker.Text = ""
	tracker.Parent = screen
	goals = tracker

	local function apply()
		local vx, vy = MobileShell.view(screen)
		local layout = HudLayout.onboard(vx, vy)
		frame.Position = UDim2.fromOffset(layout.card.x, layout.card.y)
		frame.Size = UDim2.fromOffset(layout.card.w, layout.card.h)
		advance.Position = UDim2.fromOffset(layout.continueButton.x, layout.continueButton.y)
		advance.Size = UDim2.fromOffset(layout.continueButton.w, layout.continueButton.h)
		skip.Position = UDim2.fromOffset(layout.skip.x, layout.skip.y)
		skip.Size = UDim2.fromOffset(layout.skip.w, layout.skip.h)
		tracker.Position = UDim2.fromOffset(layout.tracker.x, layout.tracker.y)
		tracker.Size = UDim2.fromOffset(layout.tracker.w, layout.tracker.h)
	end
	apply()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
end

function OnboardHud.setProfile(profile: any)
	local frame = card
	local heading = title
	local text = body
	local tracker = goals
	if frame == nil or heading == nil or text == nil or tracker == nil then
		return
	end
	if type(profile) ~= "table" or profile.onboardDone == true then
		frame.Visible = false
		tracker.Text = ""
		return
	end
	local step = Onboarding.step(profile.onboardStep)
	frame.Visible = true
	heading.Text = "Shardfall"
	text.Text = step.text
	local lines = {}
	for _, goal in ipairs(Onboarding.goals(step.id)) do
		local mark = if goal.done then "x" else "o"
		table.insert(lines, mark .. "  " .. goal.text)
	end
	tracker.Text = table.concat(lines, "\n")
end

return OnboardHud
