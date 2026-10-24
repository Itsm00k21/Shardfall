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

	[Ghost] Clip 9 (Oct 23): the card and goals came back over the open Bag
	after a remote reply. "Covered" now comes from what is really on
	screen: init registers a check per menu (coverWhen) and every show()
	asks them, so a profile push can never paint over an open menu. A
	light Heartbeat recheck catches a menu that opens without a callback.
	setCovered stays for sources with no check.

	Kevin asked for both to collapse. The card's chevron folds it into a
	slim "Shardfall: <step>" pill at the top left; tapping the pill opens
	it again. The goals fold into a "Goals N/5" tab on the right edge.
	Both remember that for the session. Skip intro still closes for good.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
local coverChecks: { [string]: () -> boolean } = {}
local onResult: ((any) -> ())? = nil
local pill: TextButton? = nil
local goalsTab: TextButton? = nil
local goalsHeader: TextLabel? = nil
-- Session only: the collapsed state outlives profile pushes and menus.
local cardCollapsed = false
local goalsCollapsed = false

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

-- True when any registered menu is really on screen, or a source with no
-- check said so through setCovered.
local function isCovered(): boolean
	for source, check in pairs(coverChecks) do
		local ok, on = pcall(check)
		if ok and on == true then
			return true
		end
		covered[source] = nil
	end
	for _, on in pairs(covered) do
		if on then
			return true
		end
	end
	return false
end

-- Visible on screen: the object and every ancestor up to its ScreenGui.
function OnboardHud.shown(object: any): boolean
	local node = object
	while node ~= nil do
		if node:IsA("ScreenGui") then
			return node.Enabled
		end
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
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
	text.TextSize = 14
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
	local function small(name: string, label: string, parent: Instance): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.BackgroundColor3 = Color3.fromRGB(44, 38, 64)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 16
		button.TextColor3 = Color3.fromRGB(240, 236, 248)
		button.Text = label
		button.AutoButtonColor = true
		button.Parent = parent
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 8)
		round.Parent = button
		return button
	end
	local collapse = small("Collapse", "‹", frame)
	collapse.Size = UDim2.fromOffset(28, 28)
	local introPill = small("IntroPill", "Shardfall", screen)
	introPill.Visible = false
	introPill.TextSize = 14
	introPill.TextXAlignment = Enum.TextXAlignment.Left
	introPill.TextTruncate = Enum.TextTruncate.AtEnd
	introPill.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	introPill.BackgroundTransparency = 0.08
	introPill.TextColor3 = Color3.fromRGB(255, 214, 120)
	local pillPad = Instance.new("UIPadding")
	pillPad.PaddingLeft = UDim.new(0, 12)
	pillPad.PaddingRight = UDim.new(0, 12)
	pillPad.Parent = introPill
	local pillStroke = Instance.new("UIStroke")
	pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pillStroke.Thickness = 1
	pillStroke.Color = Color3.fromRGB(108, 78, 196)
	pillStroke.Transparency = 0.3
	pillStroke.Parent = introPill
	pill = introPill
	collapse.MouseButton1Click:Connect(function()
		cardCollapsed = true
		OnboardHud._show()
	end)
	introPill.MouseButton1Click:Connect(function()
		cardCollapsed = false
		OnboardHud._show()
	end)
	skip.MouseButton1Click:Connect(function()
		-- Skip always closes. The starter kit follows when the server answers.
		dismissed = true
		OnboardHud._show()
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

	local header = Instance.new("TextLabel")
	header.Name = "GoalsHeader"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(10, 6)
	header.Size = UDim2.new(1, -48, 0, 20)
	header.Font = Enum.Font.BuilderSansBold
	header.TextSize = 14
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.fromRGB(255, 214, 120)
	header.Text = "Goals"
	header.Parent = backing
	goalsHeader = header
	local fold = small("GoalsCollapse", "›", backing)
	fold.AnchorPoint = Vector2.new(1, 0)
	fold.Position = UDim2.new(1, -6, 0, 4)
	fold.Size = UDim2.fromOffset(28, 24)
	local tab = small("GoalsTab", "‹ Goals", screen)
	tab.Visible = false
	tab.TextSize = 14
	tab.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	tab.BackgroundTransparency = 0.08
	local tabStroke = Instance.new("UIStroke")
	tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tabStroke.Thickness = 1
	tabStroke.Color = Color3.fromRGB(108, 78, 196)
	tabStroke.Transparency = 0.3
	tabStroke.Parent = tab
	goalsTab = tab
	fold.MouseButton1Click:Connect(function()
		goalsCollapsed = true
		OnboardHud._show()
	end)
	tab.MouseButton1Click:Connect(function()
		goalsCollapsed = false
		OnboardHud._show()
	end)

	local tracker = Instance.new("TextLabel")
	tracker.Name = "GoalText"
	tracker.BackgroundTransparency = 1
	tracker.AnchorPoint = Vector2.new(0, 0)
	tracker.Position = UDim2.fromOffset(10, 28)
	tracker.Size = UDim2.new(1, -20, 1, -34)
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
		collapse.Position = UDim2.fromOffset(layout.collapse.x, layout.collapse.y)
		collapse.Size = UDim2.fromOffset(layout.collapse.w, layout.collapse.h)
		heading.Size = UDim2.new(1, -24 - layout.collapse.w, 0, 22)
		text.Size = UDim2.new(1, -24, 0, math.max(18, layout.continueButton.y - 34))
		introPill.Position = UDim2.fromOffset(layout.pill.x, layout.pill.y)
		introPill.Size = UDim2.fromOffset(layout.pill.w, layout.pill.h)
		tab.Position = UDim2.fromOffset(layout.goalsTab.x, layout.goalsTab.y)
		tab.Size = UDim2.fromOffset(layout.goalsTab.w, layout.goalsTab.h)
		local lines = 1
		for _ in string.gmatch(tracker.Text, "\n") do
			lines += 1
		end
		local gx, gy, gw, gh = OnboardHud.goalRect(layout, vx, lines)
		gh += 20 -- the "Goals N/5" header row
		backing.Position = UDim2.fromOffset(gx, gy)
		backing.Size = UDim2.fromOffset(gw, gh)
	end
	OnboardHud._layout = apply
	apply()
	-- Menus that open without telling us still hide the card within a
	-- few frames.
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since < 0.2 then
			return
		end
		since = 0
		OnboardHud._show()
	end)
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
end

OnboardHud._layout = nil :: (() -> ())?
OnboardHud._show = function() end :: () -> ()

local function show()
	local frame = card
	local panel = goalPanel
	local tracker = goals
	if frame == nil or panel == nil or tracker == nil then
		return
	end
	local active = stepId ~= nil and not dismissed and not isCovered()
	local hasGoals = tracker.Text ~= ""
	frame.Visible = active and not cardCollapsed
	panel.Visible = active and hasGoals and not goalsCollapsed
	local introPill = pill
	if introPill ~= nil then
		introPill.Visible = active and cardCollapsed
	end
	local tab = goalsTab
	if tab ~= nil then
		tab.Visible = active and hasGoals and goalsCollapsed
	end
end
OnboardHud._show = show

-- A menu that hides the card and goals while it is on screen. check is
-- asked on every show(); it should read real visibility.
function OnboardHud.coverWhen(source: string, check: () -> boolean)
	coverChecks[source] = check
	covered[source] = nil
	show()
end

-- [Ghost] Clip 7: the hub and the Inventory call this while open, so the
-- card and goals never sit on top of a panel (Choose a class, the Bag).
-- A source with a coverWhen check ignores this: what is on screen wins.
function OnboardHud.setCovered(source: string, on: boolean)
	if coverChecks[source] == nil then
		covered[source] = on == true
	end
	show()
end

-- Collapse state for tests and the Studio check.
function OnboardHud.collapsed(): (boolean, boolean)
	return cardCollapsed, goalsCollapsed
end

function OnboardHud.setCollapsed(cardOn: boolean?, goalsOn: boolean?)
	if cardOn ~= nil then
		cardCollapsed = cardOn
	end
	if goalsOn ~= nil then
		goalsCollapsed = goalsOn
	end
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
	local list = Onboarding.goals(step.id, profile)
	for _, goal in ipairs(list) do
		local mark = if goal.done then "x" else "o"
		table.insert(lines, mark .. "  " .. goal.text)
	end
	tracker.Text = table.concat(lines, "\n")
	local done, total = Onboarding.goalCount(list)
	local header = goalsHeader
	if header ~= nil then
		header.Text = string.format("Goals %d/%d", done, total)
	end
	local tab = goalsTab
	if tab ~= nil then
		tab.Text = string.format("‹ Goals %d/%d", done, total)
	end
	local introPill = pill
	if introPill ~= nil then
		introPill.Text = Onboarding.pillText(step.id, list) .. "  ›"
	end
	local relayout = OnboardHud._layout
	if relayout ~= nil then
		relayout()
	end
	show()
end

return OnboardHud
