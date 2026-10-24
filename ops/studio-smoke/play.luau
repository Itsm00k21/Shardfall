--!strict

--[[
	Studio smoke for the six-button rail.

	Play the place, switch the command bar to Client, and paste this file.
	Market and Pass must be hidden. Key M must leave the hub closed.
	The RimShop prompt must open Shop, with the Gold shop status line.
	A new profile has an empty bar. This fills slot 1, closes the hub,
	and checks that key 1 uses it. A filled slot that stays silent is a fail.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
if player == nil then
	warn("[smoke] Run this on the client. Switch the command bar to Client.")
	return
end

local ActionSlots = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ActionSlots"))
local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))

local GOLD_SHOP = "Gold shop. A Healing Tonic and a bag slot."
local CRAWL = "Skills are for a crawl."
local fails = 0

local function report(name: string, ok: boolean, detail: string)
	if not ok then
		fails += 1
	end
	print(string.format("%s  %s  %s", if ok then "PASS" else "FAIL", name, detail))
end

local function tap(key: Enum.KeyCode)
	VirtualInputManager:SendKeyEvent(true, key, false, game)
	VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function waitFor(predicate: () -> boolean, seconds: number): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

local function gui(): PlayerGui
	return player:WaitForChild("PlayerGui") :: PlayerGui
end

local function hubScreen(): ScreenGui?
	local found = gui():FindFirstChild("ShardfallHub")
	if found ~= nil and found:IsA("ScreenGui") then
		return found
	end
	return nil
end

local function hubTitle(): string
	local screen = hubScreen()
	if screen == nil then
		return ""
	end
	local header = screen:FindFirstChild("Header", true)
	if header == nil then
		return ""
	end
	local title = header:FindFirstChild("Title")
	if title ~= nil and title:IsA("TextLabel") then
		return title.Text
	end
	return ""
end

local function banner(): TextLabel?
	local found = gui():FindFirstChild("Banner", true)
	if found ~= nil and found:IsA("TextLabel") then
		return found
	end
	return nil
end

local function slotButton(index: number): TextButton?
	local actions = gui():FindFirstChild("ShardfallActions")
	if actions == nil then
		return nil
	end
	local slot = actions:FindFirstChild("Slot" .. tostring(index), true)
	if slot ~= nil and slot:IsA("TextButton") then
		return slot
	end
	return nil
end

local function slotGlyph(index: number): string
	local slot = slotButton(index)
	if slot == nil then
		return ""
	end
	local glyph = slot:FindFirstChild("Glyph")
	if glyph ~= nil and glyph:IsA("TextLabel") then
		return glyph.Text
	end
	return ""
end

local function closeHub()
	for _ = 1, 4 do
		local screen = hubScreen()
		if screen == nil or screen.Enabled == false then
			return
		end
		tap(Enum.KeyCode.Escape)
		task.wait(0.15)
	end
end

local function hidden(root: Instance?, name: string): boolean
	if root == nil then
		return true
	end
	local node = root:FindFirstChild(name, true)
	if node == nil then
		return true
	end
	if node:IsA("GuiObject") then
		return node.Visible == false
	end
	return false
end

local railGui = gui():WaitForChild("ShardfallRail", 10)
local rail = if railGui ~= nil then railGui:FindFirstChild("Rail", true) else nil
report("rail Market", hidden(rail, "Market"), "hidden")
report("rail Pass", hidden(rail, "Pass"), "hidden")

local function profile(): any
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("GetProfile")
	local result = remote:InvokeServer()
	if type(result) == "table" then
		return result.profile
	end
	return nil
end

local function fillSlotOne(): string
	local data = profile()
	if type(data) ~= "table" then
		return "profile missing"
	end
	local classId = if type(data.classId) == "string" then data.classId else ""
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	if classId == "" or Classes.get(classId) == nil then
		local picked = remotes:WaitForChild("SetClass"):InvokeServer("warden")
		if type(picked) ~= "table" or picked.ok ~= true then
			local why = if type(picked) == "table" then tostring(picked.error) else "SetClass failed"
			return why
		end
		classId = "warden"
	end
	if
		not waitFor(function()
			return slotGlyph(1) ~= ""
		end, 2)
	then
		local bar = ActionSlots.defaults(classId)
		local saved = remotes:WaitForChild("SetActionBar"):InvokeServer(classId, bar.slots, false)
		if type(saved) ~= "table" or saved.ok ~= true then
			local why = if type(saved) == "table" then tostring(saved.error) else "SetActionBar failed"
			return why
		end
		if
			not waitFor(function()
				return slotGlyph(1) ~= ""
			end, 2)
		then
			return "slot 1 stayed empty"
		end
	end
	return ""
end

closeHub()
local filled = fillSlotOne()
report("key 1 equip", filled == "", if filled == "" then "slot 1 filled" else filled)

closeHub()
local beforeM = hubScreen()
local openBefore = beforeM ~= nil and beforeM.Enabled == true
tap(Enum.KeyCode.M)
task.wait(0.2)
local afterM = hubScreen()
local openAfter = afterM ~= nil and afterM.Enabled == true
local opened = not openBefore and openAfter
local onMarket = openAfter and hubTitle() == "Market"
report("key M opens nothing", not opened and not onMarket, if openAfter then hubTitle() else "hub stays closed")

local classSheet = gui():FindFirstChild("ShardfallClasses")
if classSheet ~= nil then
	local panel = classSheet:FindFirstChild("Classes")
	if panel ~= nil and panel:IsA("GuiObject") then
		panel.Visible = false
	end
end

local stall = workspace:FindFirstChild("RimShop", true)
local prompt: ProximityPrompt? = nil
if stall ~= nil then
	local found = stall:FindFirstChildWhichIsA("ProximityPrompt", true)
	if found ~= nil and found:IsA("ProximityPrompt") then
		prompt = found
	end
end
if prompt == nil then
	report("prompt RimShop lands on Shop", false, "RimShop prompt missing")
else
	fireproximityprompt(prompt)
	local landed = waitFor(function()
		local screen = hubScreen()
		return screen ~= nil and screen.Enabled == true and hubTitle() == "Shop"
	end, 2)
	local line = banner()
	local titled = line ~= nil and string.find(line.Text, "Gold shop", 1, true) ~= nil
	report(
		"prompt RimShop lands on Shop",
		landed and titled and line ~= nil and line.Text == GOLD_SHOP,
		if line ~= nil then hubTitle() .. " / " .. line.Text else hubTitle()
	)
end

closeHub()
local function responded(index: number): (boolean, string)
	local before = banner()
	if before ~= nil then
		before.Text = ""
		before.Visible = false
	end
	local key = ActionSlots.KEYS[index]
	local code = (Enum.KeyCode :: any)[key]
	tap(code)
	task.wait(0.25)
	local after = banner()
	local afterText = if after ~= nil then after.Text else ""
	if afterText ~= "" then
		return true, afterText
	end
	local slot = slotButton(index)
	local seconds = if slot ~= nil then slot:FindFirstChild("Seconds") else nil
	if seconds ~= nil and seconds:IsA("TextLabel") and seconds.Visible and seconds.Text ~= "" then
		return true, "cooldown " .. seconds.Text
	end
	return false, afterText
end

if slotGlyph(1) == "" then
	report("key 1 uses it", false, "slot 1 is empty")
else
	local screen = hubScreen()
	local hubClosed = screen == nil or screen.Enabled == false
	local ok, detail = responded(1)
	local used = ok and (detail == CRAWL or detail ~= "")
	report("key 1 uses it", hubClosed and used, detail)
end

for index = 2, 8 do
	local glyph = slotGlyph(index)
	if glyph == "" then
		print(string.format("SKIP  key %d  empty slot", index))
	else
		closeHub()
		local ok, detail = responded(index)
		report(string.format("key %d uses it", index), ok, detail)
	end
end

print(string.format("[smoke] %d fail", fails))
