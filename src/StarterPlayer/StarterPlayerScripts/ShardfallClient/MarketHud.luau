--!strict

--[[
	Haven Market Board and the direct trade window.

	The server owns every sale and every swap. This panel only sends the
	action and draws what came back, including the lopsided-value warning
	and the 3 second lock. Buttons stay at least 64px for a thumb.

	init.client.luau has to call MarketHud.start(invoke). That file is
	Ghost's, so the panel stays dark until that hook lands.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobileShell = require(script.Parent.MobileShell)

local MarketHud = {}

local player = Players.LocalPlayer
local statusLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local panel: Frame? = nil
local toggleButton: TextButton? = nil
local lastTradeId = ""

function MarketHud.open()
	if panel == nil then
		return
	end
	panel.Visible = true
	if toggleButton ~= nil then
		toggleButton.Position = UDim2.new(0, 384, 1, -16)
	end
end

local function setStatus(text: string)
	if statusLabel ~= nil then
		statusLabel.Text = text
	end
end

local function setBody(text: string)
	if bodyLabel ~= nil then
		bodyLabel.Text = text
	end
end

local function readBox(parent: Instance, name: string): string
	local box = parent:FindFirstChild(name, true)
	if box ~= nil and box:IsA("TextBox") then
		return box.Text
	end
	return ""
end

local function splitUids(text: string): { string }
	local items = {}
	for uid in string.gmatch(text, "[%w%-]+") do
		table.insert(items, uid)
	end
	return items
end

local function showTrade(trade: any)
	if type(trade) ~= "table" then
		return
	end
	local lines = {}
	table.insert(lines, "Trade " .. tostring(trade.id))
	table.insert(lines, "Lock " .. tostring(trade.lockRemaining or 0) .. "s")
	if type(trade.warning) == "string" then
		table.insert(lines, trade.warning)
	end
	if type(trade.previewError) == "string" then
		table.insert(lines, trade.previewError)
	end
	local function side(title: string, row: any)
		if type(row) ~= "table" or type(row.offer) ~= "table" then
			return
		end
		local mark = if row.confirmed == true then "confirmed" else "open"
		if row.committed == true then
			mark = "committed"
		end
		table.insert(
			lines,
			string.format(
				"%s (%s) gold %s gems %s items %d",
				title,
				mark,
				tostring(row.offer.gold or 0),
				tostring(row.offer.gems or 0),
				if type(row.offer.items) == "table" then #row.offer.items else 0
			)
		)
	end
	side("You", trade.you)
	side("Them", trade.them)
	setBody(table.concat(lines, "\n"))
end

local function showListings(listings: any)
	if type(listings) ~= "table" then
		return
	end
	local lines = {}
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local board = if shared ~= nil then require(shared:WaitForChild("MarketBoard")) else nil
	for _, row in ipairs(listings) do
		if board ~= nil then
			table.insert(lines, board.line(row))
		else
			table.insert(lines, tostring(row.id))
		end
	end
	if #lines == 0 then
		table.insert(lines, "The board is empty.")
	end
	setBody(table.concat(lines, "\n"))
end

local function showHistory(history: any)
	if type(history) ~= "table" then
		return
	end
	local lines = {}
	for _, entry in ipairs(history) do
		if type(entry) == "table" then
			table.insert(lines, string.format("%s  %s", tostring(entry.id), tostring(entry.kind)))
			if type(entry.id) == "string" then
				lastTradeId = entry.id
			end
		end
	end
	if #lines == 0 then
		table.insert(lines, "No trades yet.")
	end
	setBody(table.concat(lines, "\n"))
end

function MarketHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallMarket"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 14
	screen.Parent = player:WaitForChild("PlayerGui")
	MobileShell.mount(screen)

	local root = Instance.new("Frame")
	root.Name = "Market"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 16, 1, -16)
	root.Size = UDim2.fromOffset(360, 420)
	root.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
	root.BackgroundTransparency = 0.15
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = screen
	panel = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = root

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(8, 8)
	status.Size = UDim2.new(1, -16, 0, 36)
	status.Font = Enum.Font.BuilderSansBold
	status.TextSize = 16
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.TextColor3 = Color3.fromRGB(255, 196, 64)
	status.Text = "Haven Market"
	status.Parent = root
	statusLabel = status

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(8, 48)
	body.Size = UDim2.new(1, -16, 0, 120)
	body.Font = Enum.Font.BuilderSans
	body.TextSize = 14
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextColor3 = Color3.fromRGB(240, 236, 248)
	body.Text = "Board, sell, trade, and your own history."
	body.Parent = root
	bodyLabel = body

	local function field(name: string, placeholder: string, x: number, y: number)
		local box = Instance.new("TextBox")
		box.Name = name
		box.PlaceholderText = placeholder
		box.Text = ""
		box.ClearTextOnFocus = false
		box.Position = UDim2.fromOffset(x, y)
		box.Size = UDim2.fromOffset(168, 32)
		box.BackgroundColor3 = Color3.fromRGB(40, 34, 58)
		box.BorderSizePixel = 0
		box.Font = Enum.Font.BuilderSans
		box.TextSize = 14
		box.TextColor3 = Color3.fromRGB(240, 236, 248)
		box.PlaceholderColor3 = Color3.fromRGB(176, 168, 198)
		box.Parent = root
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, 8)
		boxCorner.Parent = box
		return box
	end

	field("Search", "Search", 8, 176)
	field("ListingId", "Listing id", 184, 176)
	field("Price", "Price", 8, 214)
	field("Currency", "gold or gems", 184, 214)
	field("ItemUids", "Item uids", 8, 252)
	field("TargetId", "Player id", 184, 252)
	field("Gold", "Gold offer", 8, 290)
	field("Gems", "Gem offer", 184, 290)

	local function call(remoteName: string, action: string, payload: any?)
		local ok, result = pcall(invoke, remoteName, action, payload)
		if not ok then
			setStatus(tostring(result))
			return
		end
		if type(result) ~= "table" then
			setStatus("No answer from the server.")
			return
		end
		if result.ok ~= true then
			setStatus(tostring(result.error or "That did not work."))
			return
		end
		if type(result.auditId) == "string" then
			lastTradeId = result.auditId
		end
		if type(result.warning) == "string" then
			setStatus(result.warning)
		elseif type(result.trade) == "table" and type(result.trade.warning) == "string" then
			setStatus(result.trade.warning)
		elseif type(result.trade) == "table" and type(result.trade.previewError) == "string" then
			setStatus(result.trade.previewError)
		else
			setStatus("Done.")
		end
		if type(result.listings) == "table" then
			showListings(result.listings)
		end
		if type(result.trade) == "table" then
			showTrade(result.trade)
		end
		if type(result.history) == "table" then
			showHistory(result.history)
		end
		if type(result.listing) == "table" and type(result.listing.id) == "string" then
			local box = root:FindFirstChild("ListingId")
			if box ~= nil and box:IsA("TextBox") then
				box.Text = result.listing.id
			end
		end
	end

	local row = Instance.new("Frame")
	row.Name = "Actions"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(8, 330)
	row.Size = UDim2.new(1, -16, 0, 80)
	row.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Wraps = true
	layout.Parent = row

	local function button(name: string, text: string, color: Color3, callback: () -> ())
		local hit = Instance.new("TextButton")
		hit.Name = name
		hit.Size = UDim2.fromOffset(64, 64)
		hit.BackgroundColor3 = color
		hit.BorderSizePixel = 0
		hit.Font = Enum.Font.BuilderSansBold
		hit.TextSize = 13
		hit.TextWrapped = true
		hit.TextColor3 = Color3.fromRGB(16, 14, 24)
		hit.Text = text
		hit.Parent = row
		local hitCorner = Instance.new("UICorner")
		hitCorner.CornerRadius = UDim.new(0, 12)
		hitCorner.Parent = hit
		hit.Activated:Connect(callback)
	end

	local gold = Color3.fromRGB(214, 176, 92)
	local green = Color3.fromRGB(120, 186, 96)
	local red = Color3.fromRGB(186, 96, 86)
	local ink = Color3.fromRGB(176, 168, 198)

	button("Board", "Board", gold, function()
		call("Market", "browse", { search = readBox(root, "Search") })
	end)
	button("Sell", "Sell", green, function()
		local countBox = readBox(root, "Price")
		local price = tonumber(countBox)
		call("Market", "list", {
			price = price,
			currency = if readBox(root, "Currency") == "gems" then "gems" else "gold",
			items = splitUids(readBox(root, "ItemUids")),
		})
	end)
	button("Buy", "Buy", green, function()
		call("Market", "buy", { listingId = readBox(root, "ListingId") })
	end)
	button("Unlist", "Unlist", red, function()
		call("Market", "cancel", { listingId = readBox(root, "ListingId") })
	end)
	button("Invite", "Invite", ink, function()
		local target = tonumber(readBox(root, "TargetId"))
		call("Trade", "invite", { targetUserId = target })
	end)
	button("Offer", "Offer", gold, function()
		call("Trade", "offer", {
			gold = tonumber(readBox(root, "Gold")),
			gems = tonumber(readBox(root, "Gems")),
			items = splitUids(readBox(root, "ItemUids")),
		})
	end)
	button("Ready", "Ready", ink, function()
		call("Trade", "confirm", nil)
	end)
	button("Commit", "Commit", green, function()
		call("Trade", "commit", { acceptWarning = true })
	end)
	button("Walk", "Walk", red, function()
		call("Trade", "cancel", nil)
	end)
	button("Log", "Log", gold, function()
		call("Trade", "history", nil)
	end)
	button("Report", "Report", red, function()
		call("Trade", "report", { tradeId = lastTradeId })
	end)

	local toggle = Instance.new("TextButton")
	toggle.Name = "OpenMarket"
	toggle.AnchorPoint = Vector2.new(0, 1)
	toggle.Position = UDim2.new(0, 16, 1, -16)
	toggle.Size = UDim2.fromOffset(64, 64)
	toggle.BackgroundColor3 = gold
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.BuilderSansBold
	toggle.TextSize = 13
	toggle.TextWrapped = true
	toggle.TextColor3 = Color3.fromRGB(16, 14, 24)
	toggle.Text = "Market"
	toggle.Parent = screen
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggle
	toggleButton = toggle
	toggle.Activated:Connect(function()
		root.Visible = not root.Visible
		if root.Visible then
			toggle.Position = UDim2.new(0, 384, 1, -16)
		else
			toggle.Position = UDim2.new(0, 16, 1, -16)
		end
	end)
end

return MarketHud
