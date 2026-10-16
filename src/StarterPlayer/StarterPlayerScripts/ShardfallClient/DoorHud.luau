--!strict

--[[
	The two doors after a cleared Rootvault room.

	The server already rolled them. These buttons only send the id.
]]

local Players = game:GetService("Players")

local DoorHud = {}
local player = Players.LocalPlayer
local invoke: ((string, ...any) -> any)? = nil
local row: Frame? = nil

function DoorHud.start(callRemote: (string, ...any) -> any)
	invoke = callRemote
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallDoors"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 14
	screen.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Name = "Doors"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -96)
	frame.Size = UDim2.fromOffset(420, 72)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = screen
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.Parent = frame
	row = frame
end

function DoorHud.setRun(run: any)
	local frame = row
	if frame == nil then
		return
	end
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local doors = if type(run) == "table" then run.doors else nil
	if type(doors) ~= "table" or #doors == 0 then
		frame.Visible = false
		return
	end
	frame.Visible = true
	for _, door in ipairs(doors) do
		if type(door) == "table" and type(door.id) == "string" then
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(180, 64)
			button.BackgroundColor3 = Color3.fromRGB(92, 140, 78)
			button.BorderSizePixel = 0
			button.Font = Enum.Font.BuilderSansBold
			button.TextSize = 16
			button.TextColor3 = Color3.fromRGB(16, 14, 24)
			button.Text = if type(door.name) == "string" then door.name else door.id
			button.Parent = frame
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = button
			local doorId = door.id
			button.MouseButton1Click:Connect(function()
				local call = invoke
				if call ~= nil then
					task.spawn(function()
						pcall(call, "Dungeon", "door", doorId)
					end)
				end
			end)
		end
	end
end

return DoorHud
