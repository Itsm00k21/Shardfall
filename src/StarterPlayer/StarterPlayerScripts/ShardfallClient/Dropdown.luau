--!strict

--[[
	[Ghost] A small dropdown for the full inventory (filters, the bulk
	select cap and the auto-salvage cap). One button shows the current
	choice; tapping it opens a list under it on the popup host, so a row
	that clips its children cannot cut the list off.

	Dropdown.new(parent, opts) -> handle
	  opts.name      button name; the list is "<name>List" and each choice
	                 "<name>_<key>" (key is the value, or "All" for nil).
	  opts.prefix    "Rarity" -> "Rarity: All ▼". Optional.
	  opts.options   { { value = any, text = string } }
	  opts.value     the starting value.
	  opts.host      where the list is parented (the modal root).
	  opts.width, opts.height, opts.order
	  opts.onChange(value)
	  opts.colors    { button, buttonDim, text, panel, gold, ink }

	Opening one list closes every other list on the same host. No remotes.
]]

local Dropdown = {}

export type Option = { value: any, text: string }

local openLists: { [Instance]: { close: () -> () } } = setmetatable({} :: any, { __mode = "k" }) :: any

local DEFAULT = {
	button = Color3.fromRGB(54, 46, 78),
	panel = Color3.fromRGB(28, 24, 40),
	text = Color3.fromRGB(240, 236, 248),
	gold = Color3.fromRGB(255, 196, 64),
	ink = Color3.fromRGB(32, 22, 10),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function keyOf(value: any): string
	if value == nil then
		return "All"
	end
	return tostring(value)
end

function Dropdown.closeAll(host: Instance?)
	if host == nil then
		return
	end
	local current = openLists[host]
	if current ~= nil then
		openLists[host] = nil
		current.close()
	end
end

function Dropdown.new(parent: Instance, opts: any)
	local colors = if type(opts.colors) == "table" then opts.colors else DEFAULT
	local host: Instance = opts.host or parent
	local name: string = opts.name or "Dropdown"
	local height: number = opts.height or 36
	local width: number = opts.width or 140
	local options: { Option } = opts.options or {}
	local value: any = opts.value

	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(width, height)
	button.BackgroundColor3 = colors.button or DEFAULT.button
	button.BorderSizePixel = 0
	button.Font = Enum.Font.BuilderSansBold
	button.TextSize = 14
	button.TextColor3 = colors.text or DEFAULT.text
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.AutoButtonColor = true
	button.LayoutOrder = opts.order or 0
	button.Text = ""
	button.Parent = parent
	corner(button, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = button

	local list = Instance.new("Frame")
	list.Name = name .. "List"
	list.BackgroundColor3 = colors.panel or DEFAULT.panel
	list.BorderSizePixel = 0
	list.Size = UDim2.fromOffset(width, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.Visible = false
	list.ZIndex = 40
	list.Parent = host
	corner(list, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.gold or DEFAULT.gold
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = list
	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 4)
	listPad.PaddingBottom = UDim.new(0, 4)
	listPad.PaddingLeft = UDim.new(0, 4)
	listPad.PaddingRight = UDim.new(0, 4)
	listPad.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	local handle: any = { button = button, list = list }

	local function textFor(v: any): string
		for _, option in ipairs(options) do
			if option.value == v then
				return option.text
			end
		end
		return keyOf(v)
	end

	local function paint()
		local shown = textFor(value)
		if type(opts.prefix) == "string" and opts.prefix ~= "" then
			shown = opts.prefix .. ": " .. shown
		end
		button.Text = shown .. "  ▼"
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				local on = child:GetAttribute("Key") == keyOf(value)
				child.BackgroundColor3 = if on then (colors.gold or DEFAULT.gold) else (colors.button or DEFAULT.button)
				child.TextColor3 = if on then (colors.ink or DEFAULT.ink) else (colors.text or DEFAULT.text)
			end
		end
	end

	local function close()
		list.Visible = false
		if openLists[host] ~= nil and openLists[host].close == close then
			openLists[host] = nil
		end
	end

	local function place()
		local ok, at = pcall(function()
			local b = button.AbsolutePosition
			local h = (host :: any).AbsolutePosition
			local size = button.AbsoluteSize
			return Vector2.new(b.X - h.X, b.Y - h.Y + size.Y + 4)
		end)
		if ok and at ~= nil then
			list.Position = UDim2.fromOffset(at.X, at.Y)
		end
		list.Size = UDim2.fromOffset(math.max(width, 120), 0)
	end

	local function build()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for index, option in ipairs(options) do
			local row = Instance.new("TextButton")
			row.Name = name .. "_" .. keyOf(option.value)
			row:SetAttribute("Key", keyOf(option.value))
			row.Size = UDim2.new(1, 0, 0, math.max(32, height - 4))
			row.BorderSizePixel = 0
			row.Font = Enum.Font.BuilderSansBold
			row.TextSize = 14
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = "  " .. option.text
			row.AutoButtonColor = true
			row.LayoutOrder = index
			row.ZIndex = 41
			row.Parent = list
			corner(row, 6)
			local picked = option.value
			row.MouseButton1Click:Connect(function()
				close()
				local changed = picked ~= value
				value = picked
				paint()
				if opts.onChange ~= nil and (changed or opts.always == true) then
					opts.onChange(picked)
				end
			end)
		end
		paint()
	end

	button.MouseButton1Click:Connect(function()
		if list.Visible then
			close()
			return
		end
		Dropdown.closeAll(host)
		place()
		list.Visible = true
		openLists[host] = { close = close }
	end)

	function handle.set(v: any)
		value = v
		paint()
	end

	function handle.value(): any
		return value
	end

	function handle.setOptions(next: { Option })
		options = next
		build()
	end

	function handle.close()
		close()
	end

	function handle.isOpen(): boolean
		return list.Visible
	end

	function handle.setWidth(w: number, h: number?)
		width = w
		if type(h) == "number" then
			height = h
		end
		button.Size = UDim2.fromOffset(w, height)
	end

	build()
	return handle
end

return Dropdown
