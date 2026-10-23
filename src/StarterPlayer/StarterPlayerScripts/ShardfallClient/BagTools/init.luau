--!strict

--[[
	Bag salvage controls. Ghost mounts this next to the Bag. This module
	does not require the hub, the details panel, or a compare view.

	Mount API:

		BagTools.REMOTE = "GearSalvage"

		hooks.invoke(remoteName, action, payload)
			Same shape as init.client invoke (InvokeServer).

		hooks.getProfile()
			Optional. Used to paint the list.

		handle = BagTools.mount(parent, hooks)
		handle.root
		handle:destroy()
		handle:refresh(profile?)
		handle:setSelected(uids)
		handle:getSelected()
		handle:setStatus(text)

	The panel stays visible when the flag is off and shows the server's
	"That is closed." line. Equipped gear cannot be selected. Locked
	rows stay out of the salvage payload. Salvage all asks for a server
	token, then Confirm sends it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Rarities)

local BagTools = {}

BagTools.REMOTE = "GearSalvage"

local INK = Color3.fromRGB(236, 232, 220)
local PANEL = Color3.fromRGB(28, 32, 40)
local ACCENT = Color3.fromRGB(214, 168, 74)

type Hooks = {
	invoke: (string, string, { [string]: any }?) -> any,
	getProfile: (() -> any)?,
}

local function button(parent: Instance, name: string, text: string): TextButton
	local row = Instance.new("TextButton")
	row.Name = name
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundColor3 = PANEL
	row.BorderSizePixel = 0
	row.Font = Enum.Font.GothamMedium
	row.TextSize = 16
	row.TextColor3 = INK
	row.Text = text
	row.AutoButtonColor = true
	row.Parent = parent
	return row
end

local function label(parent: Instance, name: string, text: string): TextLabel
	local row = Instance.new("TextLabel")
	row.Name = name
	row.Size = UDim2.new(1, 0, 0, 24)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.GothamMedium
	row.TextSize = 16
	row.TextColor3 = INK
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = text
	row.Parent = parent
	return row
end

local function isEquipped(profile: any, uid: string): boolean
	if type(profile) ~= "table" then
		return false
	end
	local equipped = profile.equipped
	if type(equipped) == "table" then
		if equipped.weapon == uid or equipped.pet == uid then
			return true
		end
		if type(equipped.armor) == "table" then
			for _, slotUid in pairs(equipped.armor) do
				if slotUid == uid then
					return true
				end
			end
		end
		if type(equipped.accessories) == "table" then
			for _, slotUid in pairs(equipped.accessories) do
				if slotUid == uid then
					return true
				end
			end
		end
	end
	local loadout = profile.equipLoadout
	if type(loadout) == "table" then
		for _, slotUid in pairs(loadout) do
			if slotUid == uid then
				return true
			end
		end
	end
	return false
end

function BagTools.mount(parent: Instance, hooks: Hooks)
	local selected: { [string]: boolean } = {}
	local focused: string? = nil
	local token: string? = nil
	local autoOn = false
	local rarityIndex = 1
	local lastProfile: any = nil
	local dead = false

	local root = Instance.new("Frame")
	root.Name = "BagTools"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Visible = true
	root.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = root

	local essenceLabel = label(root, "EssenceLabel", "Essence: 0")
	essenceLabel.LayoutOrder = 1
	essenceLabel.TextColor3 = ACCENT

	local autoButton = button(root, "AutoButton", "Auto-salvage: Off")
	autoButton.LayoutOrder = 2

	local rarityButton = button(root, "RarityButton", "At or below: Common")
	rarityButton.LayoutOrder = 3

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.new(1, 0, 0, 160)
	list.BackgroundTransparency = 1
	list.LayoutOrder = 4
	list.Parent = root
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = list

	local lockButton = button(root, "LockButton", "Lock")
	lockButton.LayoutOrder = 5
	local salvageSelected = button(root, "SalvageSelected", "Salvage selected")
	salvageSelected.LayoutOrder = 6
	local salvageAll = button(root, "SalvageAll", "Salvage all at or below")
	salvageAll.LayoutOrder = 7
	local confirm = button(root, "Confirm", "Confirm salvage")
	confirm.LayoutOrder = 8
	confirm.Visible = false
	local status = label(root, "Status", "")
	status.LayoutOrder = 9
	status.TextWrapped = true

	local function rarityName(): string
		return Rarities.ORDER[rarityIndex] or "Common"
	end

	local function paintAuto()
		if autoOn then
			autoButton.Text = string.format("Auto-salvage: On (%s)", rarityName())
		else
			autoButton.Text = "Auto-salvage: Off"
		end
	end

	local function paintRarity()
		rarityButton.Text = string.format("At or below: %s", rarityName())
	end

	local function setStatus(text: string)
		status.Text = text
	end

	local function findRarity(name: string)
		for index, rarity in ipairs(Rarities.ORDER) do
			if rarity == name then
				rarityIndex = index
				return
			end
		end
	end

	local function apply(result: any, action: string)
		if type(result) ~= "table" then
			setStatus("No answer from the server.")
			return
		end
		if result.ok ~= true then
			local why = result.error
			setStatus(if type(why) == "string" then why else "Could not salvage that.")
			return
		end
		if type(result.gearEssence) == "number" then
			essenceLabel.Text = string.format("Essence: %d", math.floor(result.gearEssence))
		end
		autoOn = result.autoSalvage == true
		if
			type(result.autoSalvageRarity) == "string"
			and Rarities.INDEX[result.autoSalvageRarity] ~= nil
		then
			findRarity(result.autoSalvageRarity)
		end
		paintAuto()
		paintRarity()
		if action == "preview" or action == "nudge" then
			if type(result.token) == "string" then
				token = result.token
				confirm.Visible = true
			end
		elseif action == "confirm" or action == "salvageNow" or action == "salvage" then
			token = nil
			confirm.Visible = false
		end
		if type(result.message) == "string" then
			setStatus(result.message)
		end
	end

	local function rows(): { any }
		local found = {}
		if type(lastProfile) ~= "table" or type(lastProfile.inventory) ~= "table" then
			return found
		end
		for uid, item in pairs(lastProfile.inventory) do
			if
				type(uid) == "string"
				and type(item) == "table"
				and (item.kind == "Weapon" or item.kind == "Armor")
				and type(item.name) == "string"
			then
				table.insert(found, item)
			end
		end
		table.sort(found, function(left, right)
			if left.name == right.name then
				return left.uid < right.uid
			end
			return left.name < right.name
		end)
		return found
	end

	local function paint()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local alive: { [string]: boolean } = {}
		for _, item in ipairs(rows()) do
			local uid = item.uid
			alive[uid] = true
			if isEquipped(lastProfile, uid) then
				selected[uid] = nil
			end
			local marks = {}
			if selected[uid] == true then
				table.insert(marks, "Selected")
			end
			if item.locked == true then
				table.insert(marks, "Locked")
			end
			if isEquipped(lastProfile, uid) then
				table.insert(marks, "Equipped")
			end
			local suffix = ""
			if #marks > 0 then
				suffix = " · " .. table.concat(marks, " · ")
			end
			local row =
				button(list, uid, string.format("%s · %s%s", item.name, item.rarity, suffix))
			row.MouseButton1Click:Connect(function()
				if dead then
					return
				end
				if isEquipped(lastProfile, uid) then
					setStatus("Equipped gear stays.")
					return
				end
				focused = uid
				if selected[uid] == true then
					selected[uid] = nil
				else
					selected[uid] = true
				end
				paint()
			end)
		end
		for uid in pairs(selected) do
			if alive[uid] ~= true then
				selected[uid] = nil
			end
		end
	end

	local handle = {
		root = root,
	}

	function handle:destroy()
		dead = true
		root:Destroy()
	end

	function handle:refresh(profile: any?)
		local nextProfile = profile
		if nextProfile == nil and type(hooks.getProfile) == "function" then
			nextProfile = hooks.getProfile()
		end
		lastProfile = nextProfile
		paint()
	end

	function handle:setSelected(uids: { string })
		selected = {}
		if type(uids) == "table" then
			for _, uid in ipairs(uids) do
				if type(uid) == "string" then
					selected[uid] = true
				end
			end
		end
		paint()
	end

	function handle:getSelected(): { string }
		local uids = {}
		for uid, on in pairs(selected) do
			if on == true then
				table.insert(uids, uid)
			end
		end
		table.sort(uids)
		return uids
	end

	function handle:setStatus(text: string)
		setStatus(text)
	end

	local function call(action: string, payload: { [string]: any }?)
		if dead then
			return
		end
		local result = hooks.invoke(BagTools.REMOTE, action, payload)
		apply(result, action)
	end

	autoButton.MouseButton1Click:Connect(function()
		call("auto", { enabled = not autoOn, rarity = rarityName() })
	end)

	rarityButton.MouseButton1Click:Connect(function()
		if dead then
			return
		end
		rarityIndex = (rarityIndex % #Rarities.ORDER) + 1
		paintRarity()
		if autoOn then
			call("auto", { enabled = true, rarity = rarityName() })
		end
	end)

	lockButton.MouseButton1Click:Connect(function()
		if dead then
			return
		end
		if focused == nil then
			setStatus("Pick a piece.")
			return
		end
		local item = nil
		if type(lastProfile) == "table" and type(lastProfile.inventory) == "table" then
			item = lastProfile.inventory[focused]
		end
		local locked = true
		if type(item) == "table" and item.locked == true then
			locked = false
		end
		local result = hooks.invoke(BagTools.REMOTE, "lock", { uid = focused, locked = locked })
		apply(result, "lock")
		if type(result) == "table" and result.ok == true and type(item) == "table" then
			item.locked = locked
			paint()
		end
	end)

	salvageSelected.MouseButton1Click:Connect(function()
		if dead then
			return
		end
		local uids = {}
		for uid, on in pairs(selected) do
			if on ~= true or isEquipped(lastProfile, uid) then
				continue
			end
			local item = nil
			if type(lastProfile) == "table" and type(lastProfile.inventory) == "table" then
				item = lastProfile.inventory[uid]
			end
			if type(item) == "table" and item.locked ~= true then
				table.insert(uids, uid)
			end
		end
		table.sort(uids)
		if #uids == 0 then
			setStatus("Pick gear to salvage.")
			return
		end
		local result = hooks.invoke(BagTools.REMOTE, "salvage", { uids = uids })
		apply(result, "salvage")
		if type(result) == "table" and result.ok == true then
			for _, uid in ipairs(uids) do
				selected[uid] = nil
			end
			paint()
		end
	end)

	salvageAll.MouseButton1Click:Connect(function()
		call("preview", { rarity = rarityName() })
	end)

	confirm.MouseButton1Click:Connect(function()
		if token == nil then
			setStatus("Look again.")
			return
		end
		call("confirm", { token = token })
	end)

	call("state", {})
	if type(hooks.getProfile) == "function" then
		handle:refresh(hooks.getProfile())
	end

	return handle
end

return BagTools
