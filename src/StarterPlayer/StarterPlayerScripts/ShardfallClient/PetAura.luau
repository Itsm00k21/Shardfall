--!strict

--[[
	Equipped pet-shard effects.

	Shardjaw marks the character so drops can be collected. Thorn Lantern
	pings while a shard key is held. Glass Kestrel flashes on a dodge.
	This does not roll, spend, or change combat.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PetFlash = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetFlash"))
local PetRoster = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetRoster"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local PetAura = {}

function PetAura.start(playerGui: PlayerGui, getProfile: () -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallPetAura"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 40
	screen.IgnoreGuiInset = true
	screen.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Name = "Dodge"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(186, 230, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Active = false
	flash.Parent = screen

	local ping = Instance.new("TextLabel")
	ping.Name = "KeyPing"
	ping.AnchorPoint = Vector2.new(0.5, 0)
	ping.Position = UDim2.new(0.5, 0, 0, 72)
	ping.Size = UDim2.fromOffset(220, 32)
	ping.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
	ping.BackgroundTransparency = 0
	ping.Font = Enum.Font.BuilderSansBold
	ping.TextSize = UiTheme.MIN_TEXT
	ping.TextColor3 = Color3.fromRGB(255, 244, 214)
	ping.Text = "Shard Key"
	ping.Visible = false
	ping.Parent = screen
	local pingCorner = Instance.new("UICorner")
	pingCorner.CornerRadius = UDim.new(0, 8)
	pingCorner.Parent = ping

	local function profile(): any
		local ok, value = pcall(getProfile)
		if ok then
			return value
		end
		return nil
	end

	local generation = 0

	UserInputService.InputBegan:Connect(function(input, _processed)
		if not PetFlash.should(input.KeyCode.Name, PetRoster.equippedEffect(profile())) then
			return
		end
		-- Chat and other text boxes are not a dodge. ActionBar sinks a real
		-- dodge and does not focus a text box, so that press still flashes.
		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		generation = PetFlash.bump(generation)
		local token = generation
		flash.BackgroundTransparency = 0.45
		task.delay(0.12, function()
			-- A newer dodge bumped the counter. This delay must not clear it.
			if not PetFlash.holds(generation, token) then
				return
			end
			flash.BackgroundTransparency = 1
		end)
	end)

	RunService.Heartbeat:Connect(function()
		local data = profile()
		local effect = PetRoster.equippedEffect(data)
		local localPlayer = Players.LocalPlayer
		local character = if localPlayer ~= nil then localPlayer.Character else nil
		if character ~= nil then
			character:SetAttribute("ShardfallCollect", effect == "collect")
		end
		local keys = 0
		if type(data) == "table" and type(data.shardKeys) == "number" then
			keys = data.shardKeys
		end
		ping.Visible = effect == "ping" and keys > 0
	end)
end

return PetAura
