--!strict

--[[
	Shard Core panel. Ghost mounts this. It does not edit MenuHub,
	ActionBar, or the Bag details panel. There is no pet feeder.
	Nothing here is for sale, and nothing spends Robux.

	Mount API
	---------
	From a sibling of the ShardCore folder (MenuHub, for example):

		local ShardCore = require(script.Parent.ShardCore.Mount)
		local handle = ShardCore.mount(parent, hooks)

	parent: a GuiObject. The panel fills it.

	hooks (all optional):
		invoke(action: string, itemId: string?) -> any
			Default calls the RemoteFunction of the same name.
			action is "GetShardCore" or "FeedShardCore".
		profile() -> profile
			Used by refresh() when no table is passed.
		onResult(result) -> ()
			Called with the remote result after a feed, and after a get
			that the panel itself requested.
		enabled() -> boolean
			Default is LaunchGate.on("shardCore"). When false the panel
			stays invisible and does not call a remote.
		config
			The ShardCore config table. Default is
			ReplicatedStorage.Shared.Config.ShardCore.
		theme
			A UiTheme-shaped table (RGB rows). Default is UiTheme.

	handle:
		root      Frame named ShardCore
		destroy()
		refresh(profileOrPayload?)
			A profile (inventory / gearEssence / shardCores) is previewed.
			A remote payload (essence + weapons) is shown as-is.
			Nil uses hooks.profile, then GetShardCore.
		setWeapon(uid: string)
		feed()    spends Essence on the selected weapon

	The list is owned weapons only (kind == "Weapon"). Pets are omitted.
	Feed is server-authoritative: the button calls FeedShardCore, and
	the server spends profile.gearEssence.
]]

local View = require("./View")

local Mount = {}

local function blankHandle()
	return {
		root = nil,
		destroy = function() end,
		refresh = function() end,
		setWeapon = function() end,
		feed = function()
			return nil
		end,
	}
end

local function rgb(theme: any, name: string): Color3
	local row = nil
	if type(theme) == "table" and type(theme.RGB) == "table" then
		row = theme.RGB[name]
	end
	if type(row) ~= "table" then
		row = { 244, 240, 252 }
	end
	return Color3.fromRGB(row[1] or 244, row[2] or 240, row[3] or 252)
end

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function listLayout(parent: Instance)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = parent
end

local function loadShared(given: any): (any, any)
	local config = given.config
	local theme = given.theme
	if config ~= nil and theme ~= nil then
		return config, theme
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local shared = ReplicatedStorage:WaitForChild("Shared")
	if config == nil then
		config = require(shared:WaitForChild("Config"):WaitForChild("ShardCore"))
	end
	if theme == nil then
		theme = require(shared:WaitForChild("UiTheme"))
	end
	return config, theme
end

local function flagOn(given: any): boolean
	if type(given.enabled) == "function" then
		return given.enabled() == true
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LaunchGate = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LaunchGate"))
	return LaunchGate.on("shardCore")
end

function Mount.mount(parent: any, hooks: any): any
	if typeof(parent) ~= "Instance" then
		return blankHandle()
	end
	local given = if type(hooks) == "table" then hooks else {}
	local config, theme = loadShared(given)
	local selected = ""
	local alive = true
	local allowFeed = false
	local lastProfile: any = nil
	local refreshState: (any) -> () = function() end
	local minText = 14
	local cornerRadius = 10
	if type(theme) == "table" then
		if type(theme.MIN_TEXT) == "number" then
			minText = theme.MIN_TEXT
		end
		if type(theme.CORNER) == "number" then
			cornerRadius = theme.CORNER
		end
	end

	local root = Instance.new("Frame")
	root.Name = "ShardCore"
	root.BackgroundColor3 = rgb(theme, "body")
	root.BackgroundTransparency = 0
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent
	corner(root, cornerRadius)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = root

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = minText
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = rgb(theme, "text")
	title.Text = "Shard Core"
	title.LayoutOrder = 1
	title.Parent = root

	local essence = Instance.new("TextLabel")
	essence.Name = "Essence"
	essence.BackgroundTransparency = 1
	essence.Size = UDim2.new(1, 0, 0, 20)
	essence.Font = Enum.Font.BuilderSans
	essence.TextSize = minText
	essence.TextXAlignment = Enum.TextXAlignment.Left
	essence.TextColor3 = rgb(theme, "gold")
	essence.Text = "Essence: 0"
	essence.LayoutOrder = 2
	essence.Parent = root

	local weapons = Instance.new("Frame")
	weapons.Name = "Weapons"
	weapons.BackgroundTransparency = 1
	weapons.Size = UDim2.new(1, 0, 0, 96)
	weapons.LayoutOrder = 3
	weapons.Parent = root
	listLayout(weapons)

	local perks = Instance.new("Frame")
	perks.Name = "Perks"
	perks.BackgroundTransparency = 1
	perks.Size = UDim2.new(1, 0, 0, 110)
	perks.LayoutOrder = 4
	perks.Parent = root
	listLayout(perks)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, 0, 0, 20)
	status.Font = Enum.Font.BuilderSans
	status.TextSize = minText
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = rgb(theme, "muted")
	status.Text = "No weapon to feed."
	status.LayoutOrder = 5
	status.Parent = root

	local feed = Instance.new("TextButton")
	feed.Name = "Feed"
	feed.AutoButtonColor = true
	feed.Size = UDim2.new(1, 0, 0, 36)
	feed.BackgroundColor3 = rgb(theme, "button")
	feed.BorderSizePixel = 0
	feed.Font = Enum.Font.BuilderSansBold
	feed.TextSize = minText
	feed.TextColor3 = rgb(theme, "text")
	feed.Text = "Feed"
	feed.LayoutOrder = 6
	feed.Active = false
	feed.Parent = root
	corner(feed, cornerRadius)

	local function clearGui(frame: Frame)
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function callRemote(action: string, itemId: string?): any
		if type(given.invoke) == "function" then
			if itemId == nil then
				return given.invoke(action)
			end
			return given.invoke(action, itemId)
		end
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local folder = ReplicatedStorage:WaitForChild("Remotes")
		local remote = folder:WaitForChild(action)
		if itemId == nil then
			return remote:InvokeServer()
		end
		return remote:InvokeServer(itemId)
	end

	local function paint(state: any)
		local lines = View.lines(state)
		title.Text = lines.title
		essence.Text = lines.essenceText
		status.Text = lines.status
		feed.Text = lines.feedText
		allowFeed = lines.canFeed
		feed.Active = lines.canFeed
		selected = lines.selected
		clearGui(weapons)
		clearGui(perks)
		for index, row in ipairs(lines.weapons) do
			local button = Instance.new("TextButton")
			button.Name = row.uid
			button.Size = UDim2.new(1, 0, 0, 28)
			button.BackgroundColor3 = if row.selected
				then rgb(theme, "hover")
				else rgb(theme, "panel")
			button.BorderSizePixel = 0
			button.Font = Enum.Font.BuilderSans
			button.TextSize = minText
			button.TextColor3 = rgb(theme, "text")
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.Text = row.label
			button.LayoutOrder = index
			button.Parent = weapons
			corner(button, cornerRadius)
			local uid = row.uid
			button.MouseButton1Click:Connect(function()
				if not alive then
					return
				end
				selected = uid
				refreshState(nil)
			end)
		end
		for index, perk in ipairs(lines.perks) do
			local label = Instance.new("TextLabel")
			label.Name = "Perk" .. tostring(index)
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 0, 18)
			label.Font = Enum.Font.BuilderSans
			label.TextSize = minText
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = if perk.unlocked then rgb(theme, "ok") else rgb(theme, "muted")
			label.Text = perk.text
			label.LayoutOrder = index
			label.Parent = perks
		end
	end

	local handle = blankHandle()

	refreshState = function(value: any)
		if not alive then
			return
		end
		if not flagOn(given) then
			root.Visible = false
			return
		end
		root.Visible = true
		local state = nil
		if
			type(value) == "table"
			and type(value.weapons) == "table"
			and type(value.essence) == "number"
		then
			state = value
		elseif type(value) == "table" and type(config.preview) == "function" then
			lastProfile = value
			state = config.preview(value, selected)
		elseif type(given.profile) == "function" and type(config.preview) == "function" then
			state = config.preview(given.profile(), selected)
		elseif lastProfile ~= nil and type(config.preview) == "function" then
			state = config.preview(lastProfile, selected)
		else
			local result = callRemote("GetShardCore", nil)
			if type(given.onResult) == "function" then
				given.onResult(result)
			end
			if type(result) == "table" and result.ok == true then
				state = result
			end
		end
		paint(state)
	end

	function handle.refresh(value: any)
		refreshState(value)
	end

	function handle.setWeapon(uid: string)
		if type(uid) == "string" then
			selected = uid
		end
		handle.refresh(nil)
	end

	function handle.feed()
		if not alive or not flagOn(given) or not allowFeed or selected == "" then
			return nil
		end
		local result = callRemote("FeedShardCore", selected)
		if type(result) == "table" and result.ok == true and type(result.selected) == "string" then
			selected = result.selected
			handle.refresh(result)
		end
		if type(given.onResult) == "function" then
			given.onResult(result)
		end
		return result
	end

	function handle.destroy()
		alive = false
		root:Destroy()
	end

	handle.root = root
	feed.MouseButton1Click:Connect(function()
		handle.feed()
	end)
	handle.refresh(nil)
	return handle
end

return Mount
