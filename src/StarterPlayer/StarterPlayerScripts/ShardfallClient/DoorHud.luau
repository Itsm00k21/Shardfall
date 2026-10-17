--!strict

--[[
	The two doors after a cleared Rootvault room.

	The server already rolled them. These buttons only send the id.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rootvault = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rootvault"))
local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))
local MobileShell = require(script.Parent.MobileShell)

local DoorHud = {}
local player = Players.LocalPlayer
local invoke: ((string, ...any) -> any)? = nil
local row: Frame? = nil
local fadeHost: CanvasGroup? = nil
local shownKey = ""
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
	MobileShell.mount(screen)
	local frame = Instance.new("Frame")
	frame.Name = "Doors"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(16, 200)
	frame.Size = UDim2.fromOffset(420, 72)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = screen
	local function place()
		local vx, vy = MobileShell.view(screen)
		local box = ShellLayout.doorRect(vx, vy)
		frame.Position = UDim2.fromOffset(box.x, box.y)
		frame.Size = UDim2.fromOffset(box.w, box.h)
	end
	place()
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = frame
	local host = Instance.new("CanvasGroup")
	host.Name = "Fade"
	host.BackgroundTransparency = 1
	host.Size = UDim2.fromScale(1, 1)
	host.GroupTransparency = 1
	host.Parent = frame
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.Parent = host
	fadeHost = host
	row = frame
end

function DoorHud.setRun(run: any)
	lastRun = run
	local frame = row
	local host = fadeHost
	if frame == nil or host == nil then
		return
	end
	local doors = if type(run) == "table" then run.doors else nil
	if type(doors) ~= "table" or #doors == 0 then
		frame.Visible = false
		shownKey = ""
		return
	end
	local key = Rootvault.doorSignature(doors)
	frame.Visible = not suppressed
	if key == shownKey then
		return
	end
	shownKey = key
	for _, child in ipairs(host:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	host.GroupTransparency = 1
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
			button.Parent = host
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
	TweenService:Create(
		host,
		TweenInfo.new(Rootvault.DOOR_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 0 }
	):Play()
end

return DoorHud
