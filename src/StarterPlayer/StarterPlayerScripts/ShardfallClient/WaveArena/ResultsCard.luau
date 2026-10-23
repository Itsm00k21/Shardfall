--!strict

--[[
	[ECHO hook] Results card. It stays hidden during the death hold, because
	the server snapshot's card is nil until that pause ends. Leave asks the
	server to drop the run. Tokens on the card are not written here.
]]

local ResultsCard = {}

function ResultsCard.lines(card: any): { string }
	if typeof(card) ~= "table" then
		return {}
	end
	local loot = if typeof(card.loot) == "table" then card.loot else {}
	local tokens = if type(loot.tokens) == "number" then loot.tokens else 0
	local fragments = if type(loot.fragments) == "number" then loot.fragments else 0
	local title = "Run over"
	if card.died == true then
		title = "Defeated"
	elseif card.cleared == true then
		title = "Cleared"
	elseif card.leftEarly == true then
		title = "Left early"
	end
	return {
		title,
		string.format("Waves cleared %s", tostring(card.wavesCleared)),
		string.format("Tokens %d", tokens),
		string.format("Fragments %d", fragments),
	}
end

local gui: ScreenGui? = nil
local body: TextLabel? = nil
local onLeave: (() -> ())? = nil

local function mount(playerGui: PlayerGui)
	if gui ~= nil and gui.Parent ~= nil then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "WaveArenaResults"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 50
	screen.Enabled = false
	screen.Parent = playerGui
	local panel = Instance.new("Frame")
	panel.Name = "Card"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.55)
	panel.Size = UDim2.fromOffset(280, 180)
	panel.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
	panel.BorderSizePixel = 0
	panel.Parent = screen
	local label = Instance.new("TextLabel")
	label.Name = "Body"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(16, 12)
	label.Size = UDim2.new(1, -32, 1, -64)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = Color3.fromRGB(236, 228, 210)
	label.TextWrapped = true
	label.Text = ""
	label.Parent = panel
	local button = Instance.new("TextButton")
	button.Name = "Leave"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -12)
	button.Size = UDim2.fromOffset(120, 32)
	button.BackgroundColor3 = Color3.fromRGB(186, 140, 72)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 16
	button.TextColor3 = Color3.fromRGB(28, 22, 16)
	button.Text = "Leave"
	button.Parent = panel
	button.Activated:Connect(function()
		if onLeave ~= nil then
			onLeave()
		end
	end)
	gui = screen
	body = label
end

function ResultsCard.apply(playerGui: PlayerGui, hud: any, leave: () -> ())
	onLeave = leave
	local card = if typeof(hud) == "table" then hud.card else nil
	if typeof(card) ~= "table" then
		if gui ~= nil then
			gui.Enabled = false
		end
		return
	end
	mount(playerGui)
	if gui == nil or body == nil then
		return
	end
	body.Text = table.concat(ResultsCard.lines(card), "\n")
	gui.Enabled = true
end

return ResultsCard
