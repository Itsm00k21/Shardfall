--!strict

--[[
	Cold-open card and the goal line.

	Continue only advances the text beats. Skip pays the starter kit and
	hides the card for good.

	[Ghost] Clip 7: Skip and Continue sat dead at the class step. Skip now
	closes the card on the press, whatever the server says. Continue on a
	step the world has to finish (class, swing, dodge, door) names what to
	do instead of sending a remote that can only refuse. The card and the
	goal panel hide while the hub or the Inventory is open, and the goals
	sit on a backing panel beside the card when there is room.
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
local goalPanel: Frame? = nil
local stepId: string? = nil
local dismissed = false
local covered: { [string]: boolean } = {}
local onResult: ((any) -> ())? = nil

-- Steps the Continue button can move on its own. Every other step is
-- finished in the world, and the server refuses "advance" there.
local TEXT_BEATS = { open = true, haven = true }

local HINTS = {
	class = "Open Hero and press Choose on a class. Or press Skip intro.",
	swing = "Hit the saplings with your weapon. Or press Skip intro.",
	dodge = "Dodge out of a red mark. Or press Skip intro.",
	door = "Walk through one of the two doors. Or press Skip intro.",
}

function OnboardHud.continueHint(id: any): string?
	if type(id) ~= "string" or TEXT_BEATS[id] == true then
		return nil
	end
	return HINTS[id] or "Finish this step in the world. Or press Skip intro."
end

-- Goals go beside the card when the row has room (clear of the character
-- under the card), else where HudLayout put them.
local GOAL_W = 280
local GOAL_LINE = 17

function OnboardHud.goalRect(
	layout: any,
	vx: number,
	lines: number
): (number, number, number, number)
	local box = layout.card
	local tracker = layout.tracker
	local h = math.max(tracker.h, lines * GOAL_LINE + 16)
	local besideX = box.x + box.w + 8
	local stacked = tracker.y >= box.y + box.h
	if stacked and besideX + GOAL_W <= vx - 16 - 72 then
		return besideX, box.y, GOAL_W, h
	end
	return tracker.x, tracker.y, tracker.w, h
end

local function isCovered(): boolean
	for _, on in pairs(covered) do
		if on then
			return true
		end
	end
	return false
end

function OnboardHud.start(invoke: (string, ...any) -> any, applyResult: ((any) -> ())?)
	callRemote = invoke
	onResult = applyResult
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
	local function take(ok: boolean, result: any): boolean
		local good = ok and type(result) == "table" and result.ok == true
		if good and onResult ~= nil then
			pcall(onResult :: any, result)
		end
		return good
	end
	local advance = press("Continue", "Continue", 12)
	advance.MouseButton1Click:Connect(function()
		local hint = OnboardHud.continueHint(stepId)
		if hint ~= nil then
			text.Text = hint
			return
		end
		local invokeNow = callRemote
		if invokeNow ~= nil then
			task.spawn(function()
				local ok, result = pcall(invokeNow, "Onboard", "advance")
				if not take(ok, result) then
					text.Text = if ok
							and type(result) == "table"
							and type(result.error) == "string"
						then result.error .. " Or press Skip intro."
						else "That did not go through. Press Skip intro to start."
				end
			end)
		end
	end)
	local skip = press("Skip", "Skip intro", 164)
	skip.MouseButton1Click:Connect(function()
		-- Skip always closes. The starter kit follows when the server answers.
		dismissed = true
		frame.Visible = false
		local panel = goalPanel
		if panel ~= nil then
			panel.Visible = false
		end
		local invokeNow = callRemote
		if invokeNow ~= nil then
			task.spawn(function()
				local ok, result = pcall(invokeNow, "Onboard", "skip")
				take(ok, result)
			end)
		end
	end)

	local backing = Instance.new("Frame")
	backing.Name = "OnboardGoals"
	backing.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	backing.BackgroundTransparency = 0.12
	backing.BorderSizePixel = 0
	backing.Position = UDim2.fromOffset(16, 248)
	backing.Size = UDim2.fromOffset(280, 72)
	backing.Visible = false
	backing.Parent = screen
	goalPanel = backing
	local backingCorner = Instance.new("UICorner")
	backingCorner.CornerRadius = UDim.new(0, 10)
	backingCorner.Parent = backing
	local backingStroke = Instance.new("UIStroke")
	backingStroke.Thickness = 1
	backingStroke.Color = Color3.fromRGB(108, 78, 196)
	backingStroke.Transparency = 0.3
	backingStroke.Parent = backing

	local tracker = Instance.new("TextLabel")
	tracker.Name = "GoalText"
	tracker.BackgroundTransparency = 1
	tracker.AnchorPoint = Vector2.new(0, 0)
	tracker.Position = UDim2.fromOffset(10, 8)
	tracker.Size = UDim2.new(1, -20, 1, -16)
	tracker.Font = Enum.Font.BuilderSans
	tracker.TextSize = 14
	tracker.TextWrapped = true
	tracker.TextXAlignment = Enum.TextXAlignment.Left
	tracker.TextYAlignment = Enum.TextYAlignment.Top
	tracker.TextColor3 = Color3.fromRGB(240, 236, 248)
	tracker.Text = ""
	tracker.Parent = backing
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
		local lines = 1
		for _ in string.gmatch(tracker.Text, "\n") do
			lines += 1
		end
		local gx, gy, gw, gh = OnboardHud.goalRect(layout, vx, lines)
		backing.Position = UDim2.fromOffset(gx, gy)
		backing.Size = UDim2.fromOffset(gw, gh)
	end
	OnboardHud._layout = apply
	apply()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
end

OnboardHud._layout = nil :: (() -> ())?

local function show()
	local frame = card
	local panel = goalPanel
	local tracker = goals
	if frame == nil or panel == nil or tracker == nil then
		return
	end
	local active = stepId ~= nil and not dismissed and not isCovered()
	frame.Visible = active
	panel.Visible = active and tracker.Text ~= ""
end

-- [Ghost] Clip 7: the hub and the Inventory call this while open, so the
-- card and goals never sit on top of a panel (Choose a class, the Bag).
function OnboardHud.setCovered(source: string, on: boolean)
	covered[source] = on == true
	show()
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
		stepId = nil
		tracker.Text = ""
		show()
		return
	end
	local step = Onboarding.step(profile.onboardStep)
	local moved = stepId ~= step.id
	stepId = step.id
	heading.Text = "Shardfall"
	if moved or OnboardHud.continueHint(step.id) == nil then
		text.Text = step.text
	end
	local lines = {}
	for _, goal in ipairs(Onboarding.goals(step.id)) do
		local mark = if goal.done then "x" else "o"
		table.insert(lines, mark .. "  " .. goal.text)
	end
	tracker.Text = table.concat(lines, "\n")
	local relayout = OnboardHud._layout
	if relayout ~= nil then
		relayout()
	end
	show()
end

return OnboardHud
