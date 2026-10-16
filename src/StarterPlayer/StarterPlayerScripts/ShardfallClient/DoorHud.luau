--!strict

--[[
	The two doors after a cleared Rootvault room.

	The server already rolled them. These buttons only send the id.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))

local DoorHud = {}
local player = Players.LocalPlayer
local invoke: ((string, ...any) -> any)? = nil
local row: Frame? = nil
local suppressed = false
local lastRun: any = nil

function DoorHud.suppress(hidden: boolean)
	suppressed = hidden
	if hidden then
		if row ~= nil then
			row.Visible = false
		end
		return
	end
	DoorHud.setRun(lastRun)
end

function DoorHud.start(callRemote: (string, ...any) -> any)
	invoke = callRemote
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallDoors"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 14
	screen.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Name = "Doors"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(16, 200)
	frame.Size = UDim2.fromOffset(420, 72)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = screen
	local function place()
		local camera = workspace.CurrentCamera
		local vx = if camera ~= nil then camera.ViewportSize.X else 1280
		local vy = if camera ~= nil then camera.ViewportSize.Y else 720
		if vx < 1 then
			vx = 1280
		end
		if vy < 1 then
			vy = 720
		end
		local box = ShellLayout.doorRect(vx, vy)
		frame.Position = UDim2.fromOffset(box.x, box.y)
		frame.Size = UDim2.fromOffset(box.w, box.h)
	end
	place()
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.Parent = frame
	row = frame
end

function DoorHud.setRun(run: any)
	lastRun = run
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
	frame.Visible = not suppressed
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
