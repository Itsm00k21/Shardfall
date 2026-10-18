--!strict

--[[
	A test-only Roblox GUI stand-in. MenuHub and ActionBar load against
	it, and tests fire Activated, MouseButton1Click, and InputBegan.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local GuiFake = {}

local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
local SHARED = "../src/ReplicatedStorage/Shared/"

local INHERITS: { [string]: { [string]: boolean } } = {
	Folder = { Instance = true },
	Model = { Instance = true },
	ModuleScript = { Instance = true, LuaSourceContainer = true },
	ScreenGui = { Instance = true, GuiBase2d = true, LayerCollector = true },
	Frame = { Instance = true, GuiObject = true, GuiBase2d = true },
	ScrollingFrame = { Instance = true, GuiObject = true, GuiBase2d = true },
	TextButton = { Instance = true, GuiObject = true, GuiButton = true, GuiBase2d = true },
	TextLabel = { Instance = true, GuiObject = true, GuiBase2d = true },
	ImageLabel = { Instance = true, GuiObject = true, GuiBase2d = true },
	ImageButton = { Instance = true, GuiObject = true, GuiButton = true, GuiBase2d = true },
	ViewportFrame = { Instance = true, GuiObject = true, GuiBase2d = true },
	UIListLayout = { Instance = true, UIComponent = true },
	UIGridLayout = { Instance = true, UIComponent = true },
	UIPadding = { Instance = true, UIComponent = true },
	UICorner = { Instance = true, UIComponent = true },
	UIStroke = { Instance = true, UIComponent = true },
	UIGradient = { Instance = true, UIComponent = true },
	UIScale = { Instance = true, UIComponent = true },
	Sound = { Instance = true },
	Camera = { Instance = true },
	WorldModel = { Instance = true },
	Player = { Instance = true },
	RemoteEvent = { Instance = true },
	Humanoid = { Instance = true },
	Part = { Instance = true, BasePart = true },
}

local GUI_OBJECT = {
	Frame = true,
	ScrollingFrame = true,
	TextButton = true,
	TextLabel = true,
	ImageLabel = true,
	ImageButton = true,
	ViewportFrame = true,
}

local BUTTON_EVENTS = {
	"Activated",
	"MouseButton1Click",
	"MouseEnter",
	"MouseLeave",
	"InputBegan",
	"InputEnded",
}

local enumCache: { [string]: any } = {}
local enumMeta = {
	__index = function(self, key)
		if key == "Name" then
			return string.match(self.__enum, "[^.]+$")
		end
		if key == "Value" then
			local total = 0
			for index = 1, #self.__enum do
				total += string.byte(self.__enum, index)
			end
			return total
		end
		return enumCache[self.__enum .. "." .. key] or enumNode(self.__enum .. "." .. key)
	end,
	__eq = function(a, b)
		return type(a) == "table" and type(b) == "table" and a.__enum ~= nil and a.__enum == b.__enum
	end,
	__tostring = function(self)
		return self.__enum
	end,
}

function enumNode(path: string)
	local existing = enumCache[path]
	if existing ~= nil then
		return existing
	end
	local node = setmetatable({ __enum = path }, enumMeta)
	enumCache[path] = node
	return node
end

local vector2Meta = {}
local function vector2(x: number?, y: number?)
	return setmetatable({
		X = x or 0,
		Y = y or 0,
		__type = "Vector2",
	}, vector2Meta)
end
vector2Meta.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	end
	return nil
end
vector2Meta.__sub = function(a, b)
	return vector2(a.X - b.X, a.Y - b.Y)
end

local vector3Meta = {}
local function vector3(x: number?, y: number?, z: number?)
	return setmetatable({
		X = x or 0,
		Y = y or 0,
		Z = z or 0,
		__type = "Vector3",
	}, vector3Meta)
end
vector3Meta.__index = vector3Meta
vector3Meta.__add = function(a, b)
	return vector3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

local function color3(red: number, green: number, blue: number)
	return { R = red, G = green, B = blue, __type = "Color3" }
end

local function udim(scale: number?, offset: number?)
	return { Scale = scale or 0, Offset = offset or 0 }
end

local UDim = {}
function UDim.new(scale: number?, offset: number?)
	return udim(scale, offset)
end

local UDim2 = {}
function UDim2.new(xScale: number?, xOffset: number?, yScale: number?, yOffset: number?)
	return { X = udim(xScale, xOffset), Y = udim(yScale, yOffset) }
end
function UDim2.fromOffset(x: number, y: number)
	return UDim2.new(0, x, 0, y)
end
function UDim2.fromScale(x: number, y: number)
	return UDim2.new(x, 0, y, 0)
end

local function makeSignal()
	local rows = {}
	local signal = {}
	function signal:Connect(fn)
		local conn = { Connected = true }
		function conn:Disconnect()
			self.Connected = false
		end
		table.insert(rows, { fn = fn, conn = conn })
		return conn
	end
	function signal:Fire(...)
		for _, row in ipairs(rows) do
			if row.conn.Connected then
				row.fn(...)
			end
		end
	end
	function signal:_count()
		local total = 0
		for _, row in ipairs(rows) do
			if row.conn.Connected then
				total += 1
			end
		end
		return total
	end
	return signal
end

local methods = {}
local instanceMeta = {
	__index = function(self, key)
		local signals = rawget(self, "_signals")
		if signals[key] ~= nil then
			return signals[key]
		end
		if methods[key] ~= nil then
			return methods[key]
		end
		local props = rawget(self, "_props")
		if props[key] ~= nil then
			return props[key]
		end
		if key == "ClassName" then
			return rawget(self, "_class")
		end
		if key == "Parent" then
			return rawget(self, "_parent")
		end
		if key == "AbsoluteSize" then
			return methods._measure(self)
		end
		if key == "AbsolutePosition" then
			return methods._origin(self)
		end
		local child = methods.FindFirstChild(self, key, false)
		if child ~= nil then
			return child
		end
		return nil
	end,
	__newindex = function(self, key, value)
		if key == "Parent" then
			methods._adopt(self, value)
			return
		end
		rawget(self, "_props")[key] = value
	end,
}

local function newInstance(className: string)
	local props = {
		Name = className,
		Visible = if GUI_OBJECT[className] then true else nil,
		Active = className == "TextButton" or className == "ImageButton",
		BackgroundTransparency = if GUI_OBJECT[className] then 0 else nil,
		ZIndex = if GUI_OBJECT[className] then 1 else nil,
		Modal = false,
		Text = if className == "TextButton" or className == "TextLabel" then "" else nil,
		TextSize = if className == "TextButton" or className == "TextLabel" then 14 else nil,
	}
	if className == "ScreenGui" then
		props.Enabled = true
		props.AbsoluteSize = vector2(1280, 800)
		props.AbsolutePosition = vector2(0, 0)
	end
	local signals = {}
	if className == "TextButton" or className == "ImageButton" then
		for _, eventName in ipairs(BUTTON_EVENTS) do
			signals[eventName] = makeSignal()
		end
	elseif GUI_OBJECT[className] then
		signals.InputBegan = makeSignal()
		signals.InputEnded = makeSignal()
		signals.MouseEnter = makeSignal()
		signals.MouseLeave = makeSignal()
	elseif className == "Player" then
		signals.CharacterAdded = makeSignal()
	elseif className == "RemoteEvent" then
		signals.OnClientEvent = makeSignal()
	end
	local object = setmetatable({
		_class = className,
		_props = props,
		_children = {},
		_signals = signals,
		_parent = nil,
		_attributes = {},
	}, instanceMeta)
	return object
end

function methods:_adopt(parent)
	local previous = rawget(self, "_parent")
	if previous ~= nil then
		local kids = rawget(previous, "_children")
		for index, child in ipairs(kids) do
			if child == self then
				table.remove(kids, index)
				break
			end
		end
	end
	rawset(self, "_parent", parent)
	if parent ~= nil then
		table.insert(rawget(parent, "_children"), self)
	end
end

function methods:IsA(className: string): boolean
	local own = rawget(self, "_class")
	if own == className or className == "Instance" then
		return true
	end
	local map = INHERITS[own]
	return map ~= nil and map[className] == true
end

function methods:GetChildren()
	local copy = {}
	for _, child in ipairs(rawget(self, "_children")) do
		table.insert(copy, child)
	end
	return copy
end

function methods:GetDescendants()
	local list = {}
	local function walk(node)
		for _, child in ipairs(node:GetChildren()) do
			table.insert(list, child)
			walk(child)
		end
	end
	walk(self)
	return list
end

function methods:FindFirstChild(name: string, recursive: boolean?)
	for _, child in ipairs(self:GetChildren()) do
		if child.Name == name then
			return child
		end
	end
	if recursive == true then
		for _, child in ipairs(self:GetChildren()) do
			local found = child:FindFirstChild(name, true)
			if found ~= nil then
				return found
			end
		end
	end
	return nil
end

function methods:FindFirstChildOfClass(className: string)
	for _, child in ipairs(self:GetChildren()) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

function methods:WaitForChild(name: string, _timeout: number?)
	local found = self:FindFirstChild(name, false)
	if found ~= nil then
		return found
	end
	if rawget(self, "_props").MakeMissing == true then
		local child = newInstance("ModuleScript")
		child.Name = name
		child.Parent = self
		return child
	end
	return nil
end

function methods:GetPropertyChangedSignal(prop: string)
	local key = "Changed:" .. prop
	local signals = rawget(self, "_signals")
	if signals[key] == nil then
		signals[key] = makeSignal()
	end
	return signals[key]
end

function methods:SetAttribute(name: string, value: any)
	rawget(self, "_attributes")[name] = value
end

function methods:GetAttribute(name: string): any
	return rawget(self, "_attributes")[name]
end

function methods:Destroy()
	for _, child in ipairs(self:GetChildren()) do
		child:Destroy()
	end
	self.Parent = nil
end

function methods:Play() end

function methods:Stop() end

function methods:Pause() end

function methods:_measure()
	local props = rawget(self, "_props")
	if props.AbsoluteSize ~= nil then
		return props.AbsoluteSize
	end
	local parent = rawget(self, "_parent")
	local parentW, parentH = 1280, 800
	if parent ~= nil then
		local parentSize = parent.AbsoluteSize
		parentW = parentSize.X
		parentH = parentSize.Y
	end
	local size = props.Size
	if type(size) == "table" and type(size.X) == "table" and type(size.Y) == "table" then
		return vector2(
			(size.X.Scale or 0) * parentW + (size.X.Offset or 0),
			(size.Y.Scale or 0) * parentH + (size.Y.Offset or 0)
		)
	end
	return vector2(parentW, parentH)
end

function methods:_origin()
	local props = rawget(self, "_props")
	if props.AbsolutePosition ~= nil then
		return props.AbsolutePosition
	end
	local parent = rawget(self, "_parent")
	local px, py = 0, 0
	if parent ~= nil and rawget(parent, "_class") ~= "ScreenGui" then
		local parentOrigin = parent.AbsolutePosition
		px = parentOrigin.X
		py = parentOrigin.Y
	end
	local pos = props.Position
	local parentSize = if parent ~= nil then parent.AbsoluteSize else vector2(1280, 800)
	if type(pos) == "table" and type(pos.X) == "table" and type(pos.Y) == "table" then
		px += (pos.X.Scale or 0) * parentSize.X + (pos.X.Offset or 0)
		py += (pos.Y.Scale or 0) * parentSize.Y + (pos.Y.Offset or 0)
	end
	return vector2(px, py)
end

local function tween()
	return {
		Play = function() end,
		Cancel = function() end,
		Pause = function() end,
	}
end

function GuiFake.connections(instance: any, eventName: string): number
	local signal = instance[eventName]
	if type(signal) == "table" and type(signal._count) == "function" then
		return signal:_count()
	end
	return 0
end

function GuiFake.activate(button: any)
	if GuiFake.connections(button, "Activated") > 0 then
		button.Activated:Fire()
	end
	if GuiFake.connections(button, "MouseButton1Click") > 0 then
		button.MouseButton1Click:Fire()
	end
end

function GuiFake.pointerClick(button: any, userInput: any)
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize
	local input = {
		UserInputType = enumNode("Enum.UserInputType.MouseButton1"),
		KeyCode = enumNode("Enum.KeyCode.Unknown"),
		UserInputState = enumNode("Enum.UserInputState.Begin"),
		Position = vector2((pos.X or 0) + (size.X or 0) / 2, (pos.Y or 0) + (size.Y or 0) / 2),
	}
	if GuiFake.connections(button, "InputBegan") > 0 then
		button.InputBegan:Fire(input)
	end
	if userInput ~= nil and userInput.InputEnded ~= nil then
		userInput.InputEnded:Fire(input)
	end
end

local function shown(node: any): boolean
	local current = node
	while current ~= nil do
		if current.Visible == false or current.Enabled == false then
			return false
		end
		current = current.Parent
	end
	return true
end

function GuiFake.buttons(root: any): { any }
	local list = {}
	local function walk(node)
		for _, child in ipairs(node:GetChildren()) do
			if child:IsA("TextButton") or child:IsA("ImageButton") then
				if shown(child) then
					table.insert(list, child)
				end
			end
			walk(child)
		end
	end
	walk(root)
	return list
end

function GuiFake.covers(root: any): { any }
	local rows = {}
	local function walk(node)
		for _, child in ipairs(node:GetChildren()) do
			if child:IsA("GuiObject") then
				local size = child.Size
				local full = false
				if type(size) == "table" and type(size.X) == "table" and type(size.Y) == "table" then
					full = (size.X.Scale or 0) >= 1 and (size.Y.Scale or 0) >= 1
				end
				local transparency = child.BackgroundTransparency
				if type(transparency) ~= "number" then
					transparency = 0
				end
				local z = child.ZIndex
				if type(z) ~= "number" then
					z = 1
				end
				table.insert(rows, {
					name = child.Name,
					visible = child.Visible ~= false,
					active = child.Active == true,
					transparency = transparency,
					z = z,
					modal = child.Modal == true,
					full = full,
				})
			end
			walk(child)
		end
	end
	walk(root)
	return rows
end

function GuiFake.findNamed(root: any, name: string): any
	return root:FindFirstChild(name, true)
end

function GuiFake.world()
	local EnumRoot = enumNode("Enum")
	local shared = newInstance("Folder")
	shared.Name = "Shared"
	shared.MakeMissing = true
	local replicated = newInstance("Folder")
	replicated.Name = "ReplicatedStorage"
	shared.Parent = replicated

	local player = newInstance("Player")
	player.Name = "Tester"
	local players = {
		LocalPlayer = player,
		PlayerAdded = makeSignal(),
		GetPlayers = function()
			return { player }
		end,
	}
	local userInput = {
		InputBegan = makeSignal(),
		InputEnded = makeSignal(),
		InputChanged = makeSignal(),
		WindowFocusReleased = makeSignal(),
		WindowFocused = makeSignal(),
		LastInputTypeChanged = makeSignal(),
		MouseBehavior = EnumRoot.MouseBehavior.Default,
		GetLastInputType = function()
			return EnumRoot.UserInputType.Keyboard
		end,
		IsGamepadButtonDown = function()
			return false
		end,
	}
	local binds = {}
	local context = {
		BindActionAtPriority = function(_self, name, callback, ...)
			binds[name] = callback
		end,
		BindAction = function(_self, name, callback)
			binds[name] = callback
		end,
		UnbindAction = function(_self, name)
			binds[name] = nil
		end,
	}
	local runService = {
		Heartbeat = makeSignal(),
		RenderStepped = makeSignal(),
		Stepped = makeSignal(),
		IsStudio = function()
			return false
		end,
		IsClient = function()
			return true
		end,
	}
	local tweenService = {
		Create = function()
			return tween()
		end,
	}
	local proximity = {
		PromptShown = makeSignal(),
		PromptHidden = makeSignal(),
	}
	local soundService = newInstance("Folder")
	soundService.Name = "SoundService"
	local guiService = {
		GetGuiInset = function()
			return vector2(0, 36)
		end,
	}
	local haptic = {
		SetMotor = function() end,
		IsMotorSupported = function()
			return false
		end,
	}
	local camera = newInstance("Camera")
	camera.Name = "Camera"
	camera.ViewportSize = vector2(1280, 800)
	local workspace = {
		CurrentCamera = camera,
	}
	local services = {
		ContextActionService = context,
		Players = players,
		ReplicatedStorage = replicated,
		RunService = runService,
		TweenService = tweenService,
		UserInputService = userInput,
		ProximityPromptService = proximity,
		SoundService = soundService,
		GuiService = guiService,
		HapticService = haptic,
		Workspace = workspace,
	}
	local game = {
		GetService = function(_game, name)
			local service = services[name]
			if service == nil then
				error("no service " .. tostring(name), 2)
			end
			return service
		end,
	}

	local folder = newInstance("Folder")
	folder.Name = "ShardfallClient"
	local scripts = {}
	for _, name in ipairs({ "MenuHub", "ClassHud", "MobileShell", "ActionBar" }) do
		local moduleScript = newInstance("ModuleScript")
		moduleScript.Name = name
		moduleScript.Parent = folder
		scripts[name] = moduleScript
	end

	local loadedClient = {}
	local base = {
		assert = assert,
		error = error,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		xpcall = xpcall,
		print = print,
		select = select,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		typeof = function(value)
			if type(value) == "table" and type(value.__type) == "string" then
				return value.__type
			end
			return type(value)
		end,
		warn = warn,
		math = math,
		string = string,
		table = table,
		os = os,
		coroutine = coroutine,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		unpack = unpack,
		tick = os.clock,
		game = game,
		workspace = workspace,
		Enum = EnumRoot,
		Color3 = {
			fromRGB = function(red, green, blue)
				return color3(red, green, blue)
			end,
			new = function(red, green, blue)
				return color3((red or 0) * 255, (green or 0) * 255, (blue or 0) * 255)
			end,
		},
		UDim = UDim,
		UDim2 = UDim2,
		Vector2 = {
			new = vector2,
			zero = vector2(0, 0),
		},
		Vector3 = {
			new = vector3,
			zero = vector3(0, 0, 0),
		},
		ColorSequence = {
			new = function(...)
				return { keypoints = { ... } }
			end,
		},
		NumberSequence = {
			new = function(...)
				return { keypoints = { ... } }
			end,
		},
		NumberSequenceKeypoint = {
			new = function(time, value)
				return { Time = time, Value = value }
			end,
		},
		TweenInfo = {
			new = function(...)
				return { args = { ... } }
			end,
		},
		CFrame = {
			new = function(...)
				return { args = { ... }, __type = "CFrame" }
			end,
			Angles = function()
				return { __type = "CFrame" }
			end,
			lookAt = function()
				return { __type = "CFrame" }
			end,
		},
		Instance = { new = newInstance },
		task = {
			spawn = function(fn, ...)
				if type(fn) == "function" then
					fn(...)
				end
			end,
			defer = function() end,
			delay = function() end,
			wait = function()
				return 0
			end,
		},
	}

	local function loadClient(name: string)
		if loadedClient[name] ~= nil then
			return loadedClient[name]
		end
		local source = fs.readFile(CLIENT .. name .. ".luau")
		local env = {}
		for key, value in pairs(base) do
			env[key] = value
		end
		env.script = scripts[name]
		env.require = function(module)
			if type(module) ~= "table" then
				error("require " .. tostring(module), 2)
			end
			local moduleName = module.Name
			if moduleName == "MenuHub" or moduleName == "ClassHud" or moduleName == "MobileShell" or moduleName == "ActionBar" then
				return loadClient(moduleName)
			end
			return require(SHARED .. moduleName)
		end
		local bytecode = luau.compile(source, { debugLevel = 2 })
		local chunk = luau.load(bytecode, {
			debugName = name,
			environment = env,
		})
		local result = chunk()
		loadedClient[name] = result
		return result
	end

	local playerGui = newInstance("Folder")
	playerGui.Name = "PlayerGui"

	return {
		playerGui = playerGui,
		player = player,
		userInput = userInput,
		binds = binds,
		enum = EnumRoot,
		load = loadClient,
		vector2 = vector2,
	}
end

return GuiFake
