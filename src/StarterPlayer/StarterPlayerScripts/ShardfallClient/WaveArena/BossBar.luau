--!strict

--[[
	[ECHO hook] Boss HP bar and wave label. Nothing is parented until a
	fight snapshot arrives, and the bar stays hidden while the boss is down.
]]

local BossBar = {}

function BossBar.shown(hud: any): boolean
	return typeof(hud) == "table" and typeof(hud.boss) == "table" and hud.boss.shown == true
end

function BossBar.ratio(hud: any): number
	if not BossBar.shown(hud) then
		return 0
	end
	local ratio = hud.boss.ratio
	if type(ratio) ~= "number" or ratio ~= ratio then
		return 0
	end
	if ratio < 0 then
		return 0
	end
	if ratio > 1 then
		return 1
	end
	return ratio
end

local gui: ScreenGui? = nil
local fill: Frame? = nil
local wave: TextLabel? = nil

local function mount(playerGui: PlayerGui)
	if gui ~= nil and gui.Parent ~= nil then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "WaveArenaBossBar"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 40
	screen.Parent = playerGui
	local label = Instance.new("TextLabel")
	label.Name = "Wave"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.08)
	label.Size = UDim2.fromOffset(280, 22)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(236, 228, 210)
	label.Text = ""
	label.Parent = screen
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.5, 0.12)
	track.Size = UDim2.fromOffset(280, 14)
	track.BackgroundColor3 = Color3.fromRGB(40, 32, 28)
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = screen
	local bar = Instance.new("Frame")
	bar.Name = "Fill"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(176, 64, 48)
	bar.BorderSizePixel = 0
	bar.Parent = track
	gui = screen
	fill = bar
	wave = label
end

function BossBar.apply(playerGui: PlayerGui, hud: any)
	if typeof(hud) ~= "table" then
		if gui ~= nil then
			gui.Enabled = false
		end
		return
	end
	mount(playerGui)
	if gui == nil or fill == nil or wave == nil then
		return
	end
	gui.Enabled = true
	wave.Text = if type(hud.text) == "string" then hud.text else ""
	local track = fill.Parent
	if track ~= nil and track:IsA("GuiObject") then
		track.Visible = BossBar.shown(hud)
	end
	fill.Size = UDim2.fromScale(BossBar.ratio(hud), 1)
end

return BossBar
