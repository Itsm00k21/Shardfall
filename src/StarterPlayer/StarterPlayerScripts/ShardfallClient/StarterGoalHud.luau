--!strict

--[[
	Starter-goal tracker.

	Paints up to three rows from a caller-supplied show result.
	Each row is that goal's sentence and its progress out of the
	goal. Progress above the goal is drawn at the goal. An empty
	list, or a result that is not ok, hides the tracker.

	The server sends the rows. This module does not count, and it
	does not load the rules module. The frame starts hidden.
]]

local StarterGoalHud = {}

local ROW_COUNT = 3
local ROW_H = 18
local WIDTH = 320
-- Under the portrait and HP row, clear of the left rail.
local ORIGIN_X = 88
local ORIGIN_Y = 80

export type Row = {
	text: string,
	progress: number,
	goal: number,
	line: string,
}

local labels: { TextLabel } = {}
local frameRef: Frame? = nil
local held: any = nil

local function whole(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < 0 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function readGoal(goal: any): Row?
	if type(goal) ~= "table" then
		return nil
	end
	local text = goal.text
	if type(text) ~= "string" or string.match(text, "%S") == nil then
		return nil
	end
	local progress = whole(goal.progress)
	local target = whole(goal.goal)
	if progress == nil or target == nil or target < 1 then
		return nil
	end
	if progress > target then
		progress = target
	end
	return {
		text = text,
		progress = progress,
		goal = target,
		line = string.format("%s %d/%d", text, progress, target),
	}
end

function StarterGoalHud.rows(result: any): { Row }
	local rows: { Row } = {}
	if type(result) ~= "table" or result.ok ~= true or type(result.goals) ~= "table" then
		return rows
	end
	local goals = result.goals
	for index = 1, ROW_COUNT do
		local row = readGoal(goals[index])
		if row ~= nil then
			table.insert(rows, row)
		end
	end
	return rows
end

local function apply(rows: { Row })
	local frame = frameRef
	if frame == nil then
		return
	end
	local show = #rows > 0
	frame.Visible = show
	if show then
		frame.Size = UDim2.fromOffset(WIDTH, #rows * ROW_H + 8)
	end
	for index = 1, ROW_COUNT do
		local label = labels[index]
		local row = rows[index]
		if label ~= nil then
			if row ~= nil then
				label.Visible = true
				label.Text = row.line
			else
				label.Visible = false
				label.Text = ""
			end
		end
	end
end

function StarterGoalHud.present(result: any)
	held = result
	apply(StarterGoalHud.rows(result))
end

function StarterGoalHud.start(playerGui: PlayerGui)
	local host = playerGui:FindFirstChild("ShardfallHud")
	if host == nil or not host:IsA("ScreenGui") then
		return
	end
	local previous = host:FindFirstChild("StarterGoals")
	if previous ~= nil then
		previous:Destroy()
	end
	labels = {} :: { TextLabel }

	local frame = Instance.new("Frame")
	frame.Name = "StarterGoals"
	frame.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Active = false
	frame.Position = UDim2.fromOffset(ORIGIN_X, ORIGIN_Y)
	frame.Size = UDim2.fromOffset(WIDTH, ROW_COUNT * ROW_H + 8)
	frame.ZIndex = 2
	frame.Parent = host

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	for index = 1, ROW_COUNT do
		local label = Instance.new("TextLabel")
		label.Name = "Row" .. tostring(index)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Position = UDim2.fromOffset(8, 4 + (index - 1) * ROW_H)
		label.Size = UDim2.new(1, -16, 0, ROW_H)
		label.Font = Enum.Font.BuilderSans
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextColor3 = Color3.fromRGB(244, 240, 252)
		label.Text = ""
		label.Visible = false
		label.Active = false
		label.ZIndex = 2
		label.Parent = frame
		labels[index] = label
	end

	frameRef = frame
	apply(StarterGoalHud.rows(held))
end

return StarterGoalHud
