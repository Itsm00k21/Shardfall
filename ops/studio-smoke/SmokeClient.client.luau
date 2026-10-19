-- Studio smoke: client half. Only exists in the ops/studio-smoke build.
-- It calls the exact handlers the real buttons and keys connected (recorded
-- by SmokeShim) and reads what changed on screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local runId = ReplicatedStorage:GetAttribute("SmokeRunId")
local t0 = os.clock()
while runId == nil and os.clock() - t0 < 30 do
	task.wait(0.2)
	runId = ReplicatedStorage:GetAttribute("SmokeRunId")
end
runId = runId or "?"

local function clean(s)
	return (string.gsub(tostring(s), "[\r\n|]", " / "))
end
local function out(...)
	local parts = { ... }
	for i, p in ipairs(parts) do
		parts[i] = clean(p)
	end
	print("SMOKE|" .. runId .. "|client|" .. table.concat(parts, "|"))
end

local results = {} -- { name, status, detail }
local function record(name, status, detail)
	table.insert(results, { name = name, status = status, detail = detail })
	out(status, name, detail or "")
end

local errorsSince = 0
local errorLog = {}
LogService.MessageOut:Connect(function(message, kind)
	if string.sub(message, 1, 6) == "SMOKE|" then
		return
	end
	if kind == Enum.MessageType.MessageError then
		errorsSince += 1
		table.insert(errorLog, message)
		out("LOG", "error", message)
	elseif kind == Enum.MessageType.MessageWarning then
		out("LOG", "warning", message)
	elseif kind == Enum.MessageType.MessageInfo and string.find(message, "^Script '") then
		out("LOG", "stack", message)
	end
end)

out("START", "user=" .. player.UserId)

-- Wait for the shim, the character, and the UI.
local reg
t0 = os.clock()
while os.clock() - t0 < 40 do
	reg = shared.__smkReg
	if reg ~= nil and reg.count > 0 then
		break
	end
	task.wait(0.25)
end
if reg == nil then
	record("shim_loaded", "FAIL", "shared.__smkReg missing: the client entry never reached the shim require")
	ReplicatedStorage:WaitForChild("StudioSmokeDone"):FireServer("shim missing")
	return
end
local character = player.Character or player.CharacterAdded:Wait()
record("character_spawned", character and "PASS" or "FAIL", character and character:GetFullName() or "none")
task.wait(12)
record("shim_loaded", "PASS", "handlers recorded=" .. reg.count)

local playerGui = player:WaitForChild("PlayerGui")

-- Require every client + shared ModuleScript (cached ones just return).
do
	local ok, bad = 0, 0
	local roots = { player:WaitForChild("PlayerScripts"), ReplicatedStorage:FindFirstChild("Shared") }
	for _, root in ipairs(roots) do
		if root then
			for _, inst in ipairs(root:GetDescendants()) do
				if inst:IsA("ModuleScript") and inst.Name ~= "SmokeShim" then
					local good, err = pcall(require, inst)
					if good then
						ok += 1
					else
						bad += 1
						record("require " .. inst:GetFullName(), "FAIL", err)
					end
				end
			end
		end
	end
	record("client_require_all", bad == 0 and "PASS" or "FAIL", string.format("ok=%d fail=%d", ok, bad))
end

local function onScreen(gui)
	if not gui:IsA("GuiObject") then
		return false
	end
	local node = gui
	while node and node ~= playerGui do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") and not node.Enabled then
			return false
		end
		node = node.Parent
	end
	return node == playerGui and gui.AbsoluteSize.X > 0 and gui.AbsoluteSize.Y > 0
end

local function textOf(btn)
	local bits = {}
	if btn:IsA("TextButton") and btn.Text ~= "" then
		table.insert(bits, btn.Text)
	end
	for _, d in ipairs(btn:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible then
			table.insert(bits, d.Text)
		end
	end
	return table.concat(bits, " ")
end

local function short(inst)
	return (string.gsub(inst:GetFullName(), "^Players%.[^%.]+%.PlayerGui%.", ""))
end

local function handlerCount(btn, includeInput)
	local per = reg.signals[btn]
	if per == nil then
		return 0
	end
	local n = 0
	for sig, list in pairs(per) do
		if sig ~= "InputBegan" or includeInput then
			n += #list
		end
	end
	return n
end

local function buttons()
	local list = {}
	for _, d in ipairs(playerGui:GetDescendants()) do
		if d:IsA("GuiButton") and onScreen(d) then
			table.insert(list, d)
		end
	end
	return list
end

local function snapshot()
	local texts, objects = {}, {}
	for _, d in ipairs(playerGui:GetDescendants()) do
		if d:IsA("GuiObject") and onScreen(d) then
			objects[d] = true
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
				texts[d.Text] = (texts[d.Text] or 0) + 1
			end
		end
	end
	return { texts = texts, objects = objects }
end

local function diff(a, b)
	local added, removed, objAdded, objRemoved = {}, {}, 0, 0
	for t in pairs(b.texts) do
		if a.texts[t] == nil then
			table.insert(added, t)
		end
	end
	for t in pairs(a.texts) do
		if b.texts[t] == nil then
			table.insert(removed, t)
		end
	end
	for o in pairs(b.objects) do
		if not a.objects[o] then
			objAdded += 1
		end
	end
	for o in pairs(a.objects) do
		if not b.objects[o] then
			objRemoved += 1
		end
	end
	table.sort(added)
	return {
		added = added,
		removed = removed,
		objAdded = objAdded,
		objRemoved = objRemoved,
		changed = #added + #removed + objAdded + objRemoved > 0,
	}
end

local function sample(list, n)
	local s = {}
	for i = 1, math.min(n, #list) do
		s[i] = string.sub(list[i], 1, 40)
	end
	return table.concat(s, " ; ")
end

local function runGuarded(label, fn, ...)
	local args = table.pack(...)
	local finished = false
	task.spawn(function()
		local ok, err = xpcall(function()
			fn(table.unpack(args, 1, args.n))
		end, debug.traceback)
		if not ok then
			record("handler_error " .. label, "FAIL", err)
		end
		finished = true
	end)
	return finished
end

local function fakeClick(btn)
	local p = btn.AbsolutePosition + btn.AbsoluteSize / 2
	return {
		UserInputType = Enum.UserInputType.MouseButton1,
		UserInputState = Enum.UserInputState.Begin,
		KeyCode = Enum.KeyCode.Unknown,
		Position = Vector3.new(p.X, p.Y, 0),
		Delta = Vector3.zero,
	}
end

local function fakeKey(code)
	return {
		UserInputType = Enum.UserInputType.Keyboard,
		UserInputState = Enum.UserInputState.Begin,
		KeyCode = code,
		Position = Vector3.zero,
		Delta = Vector3.zero,
		IsModifierKeyDown = function()
			return false
		end,
	}
end

local GuiService = game:GetService("GuiService")

-- What sits on top of the button's centre. A real click lands on the
-- topmost Active object, so an overlay here means the click never arrives.
-- A player scrolls a list to reach a button before clicking it. Do the same,
-- so a button that is only scrolled out of its list is not reported BLOCKED?.
local function scrollIntoView(btn)
	local frame = btn:FindFirstAncestorWhichIsA("ScrollingFrame")
	while frame ~= nil do
		local top = frame.AbsolutePosition.Y
		local bottom = top + frame.AbsoluteWindowSize.Y
		local mid = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2
		if mid < top or mid > bottom then
			local shift = mid - (top + frame.AbsoluteWindowSize.Y / 2)
			local maxY = math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y)
			frame.CanvasPosition =
				Vector2.new(frame.CanvasPosition.X, math.clamp(frame.CanvasPosition.Y + shift, 0, maxY))
			task.wait(0.15)
		end
		frame = frame:FindFirstAncestorWhichIsA("ScrollingFrame")
	end
end

local function blockerFor(btn)
	scrollIntoView(btn)
	local c = btn.AbsolutePosition + btn.AbsoluteSize / 2
	local inset = GuiService:GetGuiInset()
	for _, offset in ipairs({ Vector2.zero, inset }) do
		local ok, list = pcall(function()
			return playerGui:GetGuiObjectsAtPosition(c.X + offset.X, c.Y + offset.Y)
		end)
		if ok and table.find(list, btn) then
			for _, o in ipairs(list) do
				if o == btn or o:IsDescendantOf(btn) then
					return nil
				end
				if o:IsA("GuiButton") or o.Active then
					return short(o)
				end
			end
			return nil
		end
	end
	return "unknown (button not hit-testable at its centre)"
end

local function fakeMouse(btn, state)
	local p = btn.AbsolutePosition + btn.AbsoluteSize / 2
	return {
		UserInputType = Enum.UserInputType.MouseButton1,
		UserInputState = state,
		KeyCode = Enum.KeyCode.Unknown,
		Position = Vector3.new(p.X, p.Y, 0),
		Delta = Vector3.zero,
	}
end

-- Press = what a real mouse click on this button reaches, in click order.
local blockers = {}
local function press(btn)
	local per = reg.signals[btn] or {}
	local label = short(btn)
	local blocked = blockerFor(btn)
	if blocked then
		blockers[label] = blocked
		out("BLOCKED?", label, "topmost at centre: " .. blocked)
	end
	local called = 0
	for _, fn in ipairs(per.InputBegan or {}) do
		runGuarded(label .. ".InputBegan", fn, fakeMouse(btn, Enum.UserInputState.Begin), false)
		called += 1
	end
	for _, fn in ipairs(per.MouseButton1Down or {}) do
		runGuarded(label .. ".MouseButton1Down", fn, 0, 0)
		called += 1
	end
	task.wait(0.05)
	for _, fn in ipairs(per.InputEnded or {}) do
		runGuarded(label .. ".InputEnded", fn, fakeMouse(btn, Enum.UserInputState.End), false)
	end
	for _, fn in ipairs(per.MouseButton1Click or {}) do
		runGuarded(label .. ".MouseButton1Click", fn)
		called += 1
	end
	for _, fn in ipairs(per.Activated or {}) do
		runGuarded(label .. ".Activated", fn, fakeClick(btn), 1)
		called += 1
	end
	return called
end

local function pressKey(codeName)
	local code = Enum.KeyCode[codeName]
	local called = 0
	for _, fn in ipairs(reg.global["UserInputService.InputBegan"] or {}) do
		runGuarded("UIS.InputBegan(" .. codeName .. ")", fn, fakeKey(code), false)
		called += 1
	end
	for name, action in pairs(reg.actions) do
		for _, k in ipairs(action.keys) do
			if k == code then
				runGuarded("CAS " .. name .. "(" .. codeName .. ")", action.fn, name, Enum.UserInputState.Begin, fakeKey(code))
				called += 1
			end
		end
	end
	return called
end

local function step(name, doIt, settle)
	local before = snapshot()
	local errBefore = errorsSince
	local called = doIt()
	task.wait(settle or 1.5)
	local d = diff(before, snapshot())
	local newErrors = errorsSince - errBefore
	local detail = string.format(
		"handlers=%d changed=%s +obj=%d -obj=%d errors=%d added=[%s] removed=[%s]",
		called,
		tostring(d.changed),
		d.objAdded,
		d.objRemoved,
		newErrors,
		sample(d.added, 14),
		sample(d.removed, 8)
	)
	local status = "PASS"
	if called == 0 or newErrors > 0 then
		status = "FAIL"
	elseif not d.changed then
		status = "WARN"
	end
	record(name, status, detail)
	return d, called, newErrors
end

local function find(word, opts)
	opts = opts or {}
	local lw = string.lower(word)
	local found = {}
	for _, b in ipairs(buttons()) do
		local hay = string.lower(b.Name .. " " .. textOf(b))
		local hit
		if opts.exactText then
			hit = string.lower(textOf(b)) == lw or string.lower(b.Name) == lw
		else
			hit = string.find(hay, lw, 1, true) ~= nil
		end
		if hit and (opts.except == nil or not string.find(hay, string.lower(opts.except), 1, true)) then
			table.insert(found, b)
		end
	end
	table.sort(found, function(a, b)
		local ah, bh = handlerCount(a, true) > 0, handlerCount(b, true) > 0
		if ah ~= bh then
			return ah
		end
		local ax = string.lower(textOf(a)) == lw or string.lower(a.Name) == lw
		local bx = string.lower(textOf(b)) == lw or string.lower(b.Name) == lw
		if ax ~= bx then
			return ax
		end
		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)
	return found
end

local function describeList(list, n)
	local s = {}
	for i = 1, math.min(n, #list) do
		local b = list[i]
		s[i] = string.format("%s{%s}h=%d", short(b), string.sub(textOf(b), 1, 24), handlerCount(b, true))
	end
	return table.concat(s, " ; ")
end

local function visibleTexts(limit)
	local s = {}
	local seen = {}
	for _, d in ipairs(playerGui:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and onScreen(d) and not seen[d.Text] then
			seen[d.Text] = true
			table.insert(s, string.sub(d.Text, 1, 40))
			if #s >= limit then
				break
			end
		end
	end
	return table.concat(s, " ; ")
end

-- 0. Discovery dump: every visible button and how many handlers it has.
do
	local list = buttons()
	local dead = {}
	for i, b in ipairs(list) do
		local h = handlerCount(b, true)
		if i <= 250 then
			out("DUMP", short(b), string.sub(textOf(b), 1, 40), "handlers=" .. h)
		end
		if h == 0 then
			table.insert(dead, b)
		end
	end
	record("hud_visible_buttons", "INFO", string.format("visible=%d without_recorded_handler=%d", #list, #dead))
	if #dead > 0 then
		record("hud_buttons_without_handler", "WARN", describeList(dead, 25))
	end
	out("TEXTS", "boot", visibleTexts(80))
end

-- Clear the intro overlay if it is up, the way a new player would.
for _, word in ipairs({ "Skip intro", "Continue", "Skip" }) do
	local hits = find(word, { exactText = true })
	if hits[1] then
		step("onboarding press " .. word, function()
			return press(hits[1])
		end)
	end
end

local function closeHub()
	for _, word in ipairs({ "CloseButton", "Close", "X", "\u{2715}", "\u{00D7}" }) do
		local hits = find(word, { exactText = true })
		for _, b in ipairs(hits) do
			if handlerCount(b) > 0 then
				press(b)
				task.wait(0.8)
				return short(b)
			end
		end
	end
	return nil
end

local function hubTitle()
	local hub = playerGui:FindFirstChild("ShardfallHub")
	local header = hub and hub:FindFirstChild("Panel") and hub.Panel:FindFirstChild("Header")
	if not header or not onScreen(header) then
		return "(hub closed)"
	end
	for _, d in ipairs(header:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text ~= "" and onScreen(d) and not d:FindFirstAncestorWhichIsA("GuiButton") then
			return d.Text
		end
	end
	return "(no title)"
end

local function bodyTexts(limit)
	local hub = playerGui:FindFirstChild("ShardfallHub")
	local body = hub and hub:FindFirstChild("Panel") and hub.Panel:FindFirstChild("Body")
	local s = {}
	if body then
		for _, d in ipairs(body:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and onScreen(d) then
				table.insert(s, string.sub(d.Text, 1, 40))
				if #s >= limit then
					break
				end
			end
		end
	end
	return s
end

local function hudNumber(word)
	for _, d in ipairs(playerGui:GetDescendants()) do
		if d:IsA("TextLabel") and onScreen(d) then
			local n = string.match(d.Text, "^" .. word .. "%s+([%d,]+)$")
			if n then
				return tonumber((string.gsub(n, ",", "")))
			end
		end
	end
	return nil
end

local function closeHub()
	for _, word in ipairs({ "CLOSE", "X" }) do
		for _, b in ipairs(find(word, { exactText = true })) do
			if handlerCount(b, true) > 0 then
				press(b)
				task.wait(0.8)
				return short(b)
			end
		end
	end
	return nil
end

local GOLD_SHOP = "Gold shop. A Healing Tonic and a bag slot."

local function rail(name)
	local railGui = playerGui:FindFirstChild("ShardfallRail")
	local button = railGui and railGui:FindFirstChild("Rail") and railGui.Rail:FindFirstChild(name)
	if button and onScreen(button) then
		return button
	end
	local hud = playerGui:FindFirstChild("ShardfallHud")
	local legacy = hud and hud:FindFirstChild("Chrome") and hud.Chrome:FindFirstChild("Rail") and hud.Chrome.Rail:FindFirstChild(name)
	if legacy and onScreen(legacy) then
		return legacy
	end
	for _, candidate in ipairs(buttons()) do
		if candidate.Name == name or string.lower(textOf(candidate)) == string.lower(name) then
			return candidate
		end
	end
	return nil
end

local function slotGlyph(index)
	local actions = playerGui:FindFirstChild("ShardfallActions")
	local slot = actions and actions:FindFirstChild("Slot" .. tostring(index), true)
	local glyph = slot and slot:FindFirstChild("Glyph")
	if glyph and glyph:IsA("TextLabel") then
		return glyph.Text
	end
	return ""
end

local function goldStatus()
	for _, desc in ipairs(playerGui:GetDescendants()) do
		if desc:IsA("TextLabel") and desc.Text ~= "" and onScreen(desc) and string.find(desc.Text, GOLD_SHOP, 1, true) then
			return desc.Text
		end
	end
	return nil
end

local function wardenButton()
	local hub = playerGui:FindFirstChild("ShardfallHub")
	local card = hub and hub:FindFirstChild("warden", true)
	local choose = card and card:FindFirstChild("Choose")
	if choose and onScreen(choose) then
		return choose
	end
	local classes = playerGui:FindFirstChild("ShardfallClasses")
	local panel = classes and classes:FindFirstChild("Classes")
	if panel and onScreen(panel) then
		for _, desc in ipairs(panel:GetDescendants()) do
			if desc:IsA("GuiButton") and onScreen(desc) and desc.Text == "Warden" then
				return desc
			end
		end
	end
	local exact = find("Warden", { exactText = true })[1]
	if exact then
		return exact
	end
	return nil
end

local function pickWarden()
	local glyph = slotGlyph(1)
	if glyph ~= "" then
		record("pick class Warden", "PASS", "slot 1 already filled: " .. glyph)
		return true
	end
	local choose = wardenButton()
	if not choose then
		local hero = rail("Hero")
		if hero then
			press(hero)
			task.wait(1.2)
		end
		local opener = find("Choose class", { exactText = true })[1]
		if opener then
			press(opener)
			task.wait(1.2)
		end
		choose = wardenButton()
	end
	if not choose then
		record("pick class Warden", "FAIL", "no Warden card on screen")
		return false
	end
	step("pick class Warden", function()
		return press(choose)
	end, 2)
	local filled = false
	for _ = 1, 16 do
		glyph = slotGlyph(1)
		if glyph ~= "" then
			filled = true
			break
		end
		task.wait(0.25)
	end
	record("pick class Warden fills slot 1", filled and "PASS" or "FAIL", "slot 1=" .. glyph)
	closeHub()
	return filled
end

-- 1. Pick Warden so the action bar has skills before any key 1-8 check.
pickWarden()

-- 2. The six live rail buttons, then Market and Pass must stay hidden.
local RAIL = {
	{ "Hero", "C", "hero" },
	{ "Bag", "B", "bag" },
	{ "Pets", "P", "pets" },
	{ "Roll", "T", "roll" },
	{ "Shop", nil, "shop" },
	{ "Settings", nil, "settings" },
}
for _, entry in ipairs(RAIL) do
	local name, key, expect = entry[1], entry[2], entry[3]
	closeHub()
	local b = rail(name)
	if not b then
		record("rail " .. name, "FAIL", "no visible rail button")
	else
		step("rail " .. name .. " click", function()
			return press(b)
		end)
		local title = hubTitle()
		local ok = string.find(string.lower(title), expect, 1, true) ~= nil
		record("rail " .. name .. " lands on its own screen", ok and "PASS" or "FAIL", "hub title=" .. title)
	end
	if key then
		closeHub()
		step("key " .. key .. " (" .. name .. ")", function()
			return pressKey(key)
		end)
		local title = hubTitle()
		record("key " .. key .. " lands on " .. name, string.find(string.lower(title), expect, 1, true) and "PASS" or "FAIL", "hub title=" .. title)
	end
end
for _, name in ipairs({ "Market", "Pass" }) do
	local hidden = rail(name)
	if hidden and onScreen(hidden) then
		record("rail " .. name, "FAIL", "still visible at " .. short(hidden))
	else
		record("rail " .. name, "PASS", "hidden")
	end
end
do
	closeHub()
	task.wait(0.4)
	local before = hubTitle()
	pressKey("M")
	task.wait(1.2)
	local title = hubTitle()
	local market = string.find(string.lower(title), "market", 1, true) ~= nil
	local closed = title == "(hub closed)"
	record("key M opens nothing", (closed and not market) and "PASS" or "FAIL", "before=" .. before .. " after=" .. title)
end

-- Market is not on the M1 rail, so the old Pass mix-up has nothing to press.
do
	closeHub()
	local b = rail("Market")
	if not b then
		record("BUG2 Market icon opens Shard Pass", "INFO", "Market is hidden")
	else
		press(b)
		task.wait(1.2)
		local title = hubTitle()
		local body = table.concat(bodyTexts(30), " ; ")
		local passy = string.find(string.lower(title), "pass", 1, true) ~= nil
		record("BUG2 Market icon opens Shard Pass", passy and "REPRO" or "NOT-REPRO", "title=" .. title .. " body=" .. string.sub(body, 1, 300))
	end
end

-- 3. Crack (BUG1): Roll tab, CRACK x1 twice, then CRACK x10.
do
	closeHub()
	local r = rail("Roll")
	if r then
		press(r)
		task.wait(1.2)
	end
	local hub = playerGui:FindFirstChild("ShardfallHub")
	local function crackButton(label)
		for _, b in ipairs(find("CRACK")) do
			if string.find(textOf(b), label, 1, true) and b:IsDescendantOf(hub) then
				return b
			end
		end
		return nil
	end
	local x1, x10 = crackButton("x1"), crackButton("x10")
	for _, pair in ipairs({ { "x1", x1, 4 }, { "x1 again", x1, 4 }, { "x10", x10, 9 } }) do
		local label, b, settle = pair[1], pair[2], pair[3]
		local want = if label == "x10" then "x10" else "x1"
		for _ = 1, 20 do
			for _, c in ipairs(find("CRACK")) do
				local t = textOf(c)
				local lt = string.lower(t)
				local isTen = string.find(lt, "x10", 1, true) ~= nil
				local isPet = string.find(lt, "pet", 1, true) ~= nil
				if c:IsDescendantOf(hub) and not isPet and ((want == "x10") == isTen) then
					b = c
				end
			end
			if b and onScreen(b) then
				break
			end
			task.wait(0.5)
		end
		if not b or not onScreen(b) then
			record("BUG1 CRACK " .. label, "FAIL", "button not on screen")
		else
			local shardsBefore = hudNumber("Shards")
			local d, called, errs = step("CRACK " .. label .. " (" .. short(b) .. ")", function()
				return press(b)
			end, settle)
			local shardsAfter = hudNumber("Shards")
			local spent = shardsBefore and shardsAfter and shardsBefore - shardsAfter or nil
			local fed = called > 0 and d.changed and errs == 0
			record(
				"BUG1 CRACK " .. label .. " gives feedback",
				fed and "NOT-REPRO" or "REPRO",
				string.format("handlers=%d screen_changed=%s errors=%d shards %s->%s (spent %s)", called, tostring(d.changed), errs, tostring(shardsBefore), tostring(shardsAfter), tostring(spent))
			)
		end
	end
	out("TEXTS", "roll body after cracks", table.concat(bodyTexts(60), " ; "))
end

-- 4. Pets (BUG3): crack a pet shard, then read the Pets body.
do
	closeHub()
	local p = rail("Pets")
	if p then
		press(p)
		task.wait(1.2)
	end
	local crackPet = find("CRACK PET SHARD")[1]
	if crackPet then
		step("Pets: CRACK PET SHARD shortcut", function()
			return press(crackPet)
		end, 2)
		local petTab = find("Pet Shards", { exactText = true })[1]
		if petTab then
			step("Roll: Pet Shards tab", function()
				return press(petTab)
			end)
		end
		local hub = playerGui:FindFirstChild("ShardfallHub")
		local x1
		for _, c in ipairs(find("CRACK")) do
			if c:IsDescendantOf(hub) and not string.find(textOf(c), "x10", 1, true) and not string.find(textOf(c), "PET", 1, true) then
				x1 = c
			end
		end
		if x1 then
			local shardsBefore = hudNumber("Shards")
			step("Roll: crack one Pet Shard", function()
				return press(x1)
			end, 5)
			out("INFO", "pet crack shards", tostring(shardsBefore) .. "->" .. tostring(hudNumber("Shards")))
		end
		closeHub()
		press(rail("Pets"))
		task.wait(1.5)
	end
	local texts = bodyTexts(120)
	local joined = string.lower(table.concat(texts, " ; "))
	local forgey = {}
	for _, w in ipairs({ "forge", "upgrade", "craft", "recipe", "salvage", "reroll", "material", "weapon", "armor", "sword", "blade" }) do
		if string.find(joined, w, 1, true) then
			table.insert(forgey, w)
		end
	end
	out("TEXTS", "pets body", table.concat(texts, " ; "))
	record("BUG3 Pets tab shows Forge/gear items", #forgey > 0 and "REPRO" or "NOT-REPRO", "gear/forge words in Pets body: " .. (#forgey > 0 and table.concat(forgey, ",") or "none"))
end

-- 5. Bag (BUG4): Equip/Lock must sit inside their item card.
local function checkCards(rootName, root)
	local inside, outside, total = 0, {}, 0
	for _, b in ipairs(root:GetDescendants()) do
		if b:IsA("GuiButton") and onScreen(b) then
			local t = string.lower(textOf(b))
			if t == "equip" or t == "lock" or t == "locked" or t == "unlock" or t == "wear" or b.Name == "Equip" or b.Name == "Lock" then
				total += 1
				local card = b.Parent
				local cp, cs = card.AbsolutePosition, card.AbsoluteSize
				local bp, bs = b.AbsolutePosition, b.AbsoluteSize
				local ok = card:IsA("GuiObject")
					and bp.X >= cp.X - 1
					and bp.Y >= cp.Y - 1
					and bp.X + bs.X <= cp.X + cs.X + 1
					and bp.Y + bs.Y <= cp.Y + cs.Y + 1
				if ok then
					inside += 1
				else
					table.insert(outside, string.format("%s btn@(%d,%d %dx%d) parent@(%d,%d %dx%d)", short(b), bp.X, bp.Y, bs.X, bs.Y, cp.X, cp.Y, cs.X, cs.Y))
				end
			end
		end
	end
	if total == 0 then
		record("BUG4 " .. rootName .. " Equip/Lock on cards", "INFO", "no Equip/Lock buttons visible (bag empty?)")
	else
		record("BUG4 " .. rootName .. " Equip/Lock detached from cards", #outside > 0 and "REPRO" or "NOT-REPRO", string.format("inside=%d outside=%d %s", inside, #outside, table.concat(outside, " ; ", 1, math.min(4, #outside))))
	end
	return total
end
do
	closeHub()
	local b = rail("Bag")
	if b then
		press(b)
		task.wait(1.5)
	end
	local hub = playerGui:FindFirstChild("ShardfallHub")
	out("TEXTS", "bag body", table.concat(bodyTexts(80), " ; "))
	if hub then
		checkCards("hub Bag", hub)
		local equip
		for _, x in ipairs(hub:GetDescendants()) do
			if x:IsA("GuiButton") and x.Name == "Equip" and onScreen(x) then
				equip = x
				break
			end
		end
		if equip then
			step("Bag card Equip " .. short(equip), function()
				return press(equip)
			end, 2)
		end
		local lock
		for _, x in ipairs(hub:GetDescendants()) do
			if x:IsA("GuiButton") and x.Name == "Lock" and onScreen(x) then
				lock = x
				break
			end
		end
		if lock then
			step("Bag card Lock " .. short(lock), function()
				return press(lock)
			end, 2)
		end
	end
	local full = find("Open full bag")[1]
	if full then
		step("Open full bag", function()
			return press(full)
		end, 2)
		local inv
		for _, g in ipairs(playerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g.Name ~= "ShardfallHub" and g.Name ~= "ShardfallHud" and g.Name ~= "ShardfallActions" then
				for _, x in ipairs(g:GetDescendants()) do
					if x:IsA("GuiButton") and onScreen(x) and (string.lower(textOf(x)) == "equip" or string.lower(textOf(x)) == "lock") then
						inv = g
						break
					end
				end
			end
			if inv then
				break
			end
		end
		if inv then
			checkCards("full bag (" .. inv.Name .. ")", inv)
		else
			record("BUG4 full bag Equip/Lock", "INFO", "no Equip/Lock visible in the full bag view")
		end
		closeHub()
	end
end

-- 6. Forge prompt (it is a world prompt, not a tab).
do
	closeHub()
	local prompt
	local listing = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			table.insert(listing, string.format("%s{%s/%s}", d:GetFullName(), d.ObjectText, d.ActionText))
			local hay = string.lower(d.ActionText .. " " .. d.ObjectText .. " " .. d:GetFullName())
			if string.find(hay, "forge", 1, true) and not string.find(hay, "realmarch", 1, true) and not string.find(hay, "sealed", 1, true) then
				prompt = prompt or d
			end
		end
	end
	out("INFO", "prompts", table.concat(listing, " ; "))
	local cam = workspace.CurrentCamera
	out("INFO", "viewport", cam and tostring(cam.ViewportSize) or "?")
	if not prompt then
		record("Forge prompt", "INFO", "no Forge ProximityPrompt streamed in near spawn")
	else
		local fired = 0
		local d = step("Forge prompt trigger " .. prompt:GetFullName(), function()
			for _, fn in ipairs(reg.global["ProximityPromptService.PromptTriggered"] or {}) do
				runGuarded("PromptTriggered(Forge)", fn, prompt, player)
				fired += 1
			end
			for _, fn in ipairs((reg.signals[prompt] or {}).Triggered or {}) do
				runGuarded("Forge.Triggered", fn, player)
				fired += 1
			end
			return fired
		end, 2)
		local joined = string.lower(table.concat(d.added, " "))
		record("Forge prompt opens craft (not Bag)", (string.find(joined, "craft", 1, true) or string.find(joined, "forge", 1, true)) and "PASS" or "WARN", "title=" .. hubTitle() .. " added=" .. sample(d.added, 10))
		closeHub()
	end
end

-- 6b. The other plaza station prompts (Market Board, Pet Garden). Dungeon
-- doors and realm arches are skipped on purpose: they teleport or start runs.
do
	for _, station in ipairs({ "RimShop", "PetGarden" }) do
		closeHub()
		local haven = workspace:FindFirstChild("Haven")
		local node = haven and haven:FindFirstChild(station)
		local prompt = node and node:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt then
			record("prompt " .. station, "INFO", "not streamed in")
		else
			local d = step("prompt " .. station .. " {" .. prompt.ObjectText .. "/" .. prompt.ActionText .. "}", function()
				local fired = 0
				for _, fn in ipairs(reg.global["ProximityPromptService.PromptTriggered"] or {}) do
					runGuarded("PromptTriggered(" .. station .. ")", fn, prompt, player)
					fired += 1
				end
				for _, fn in ipairs((reg.signals[prompt] or {}).Triggered or {}) do
					runGuarded(station .. ".Triggered", fn, player)
					fired += 1
				end
				return fired
			end, 2)
			local title = hubTitle()
			local lowTitle = string.lower(title)
			local passy = string.find(lowTitle, "pass", 1, true) ~= nil
			local bodyJoined = string.lower(table.concat(bodyTexts(80), " ; "))
			local forgey = station == "PetGarden" and (string.find(bodyJoined, "forge", 1, true) or string.find(bodyJoined, "craft", 1, true) or string.find(bodyJoined, "a plain", 1, true))
			local status = "PASS"
			local label
			local detail
			if station == "RimShop" then
				local line = goldStatus()
				local onShop = string.find(lowTitle, "shop", 1, true) ~= nil
				if passy or not onShop or line == nil then
					status = "FAIL"
				end
				label = "prompt RimShop lands on Shop"
				detail = string.format("hub title=%s status=%s added=[%s]", title, line or "(missing)", sample(d.added, 8))
			else
				if passy or forgey or not string.find(lowTitle, "pet", 1, true) then
					status = "FAIL"
				end
				label = "prompt PetGarden lands on pet"
				detail = string.format("hub title=%s added=[%s] body=[%s]", title, sample(d.added, 8), string.sub(table.concat(bodyTexts(25), " ; "), 1, 260))
			end
			record(label, status, detail)
		end
	end
	closeHub()
end

-- 7. Action bar keys 1-8 after Warden is picked, and Lock.
-- Slots 7 and 8 stay empty on a fresh Warden bar. An empty slot is not a failure.
if slotGlyph(1) == "" then
	pickWarden()
end
closeHub()
task.wait(0.5)
local slotKeys = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight" }
local barTexts = {}
local actions = playerGui:FindFirstChild("ShardfallActions")
for i = 1, 8 do
	barTexts[i] = slotGlyph(i)
end
out("INFO", "action bar slots", table.concat(barTexts, " | "))
for i, k in ipairs(slotKeys) do
	local glyph = barTexts[i]
	if glyph == nil or glyph == "" then
		record("key " .. i .. " (slot " .. i .. ")", "INFO", "empty slot")
	else
		step("key " .. i .. " (slot " .. i .. ": " .. glyph .. ")", function()
			return pressKey(k)
		end, 1.2)
	end
	closeHub()
end
do
	local lock = actions and actions:FindFirstChild("Lock", true)
	if lock then
		step("action bar Lock", function()
			return press(lock)
		end)
		step("action bar Lock again", function()
			return press(lock)
		end)
	else
		record("action bar Lock", "FAIL", "no Lock button in ShardfallActions")
	end
end

-- 8. Summary.
local counts = {}
for _, r in ipairs(results) do
	counts[r.status] = (counts[r.status] or 0) + 1
end
local nBlocked = 0
for _ in pairs(blockers) do
	nBlocked += 1
end
local summary = HttpService:JSONEncode({ counts = counts, clientErrors = errorsSince, possiblyBlocked = nBlocked })
out("DONE", summary)
ReplicatedStorage:WaitForChild("StudioSmokeDone"):FireServer(summary)
