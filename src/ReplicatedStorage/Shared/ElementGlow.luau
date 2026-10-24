--!strict

--[[
	Enemy element glow.

	The server assigns an element from spawn order (Elements.ORDER) and
	applies the visual from Config/Elements. Color is the element's
	`color`. Strength is `Elements.GLOW`. Passing enabled = false returns
	nil, so a LaunchGate that is off builds nothing.

	Combat stats do not change. Nothing is saved. Nothing costs Robux.
]]

local Elements = require("./Config/Elements")

local ElementGlow = {}

export type Visual = {
	elementId: string,
	color: { number },
	name: string,
	lightName: string,
	fillTransparency: number,
	outlineTransparency: number,
	lightBrightness: number,
	lightRange: number,
	depthMode: string,
}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function validColor(color: any): boolean
	if type(color) ~= "table" or #color ~= 3 then
		return false
	end
	for index = 1, 3 do
		local channel = color[index]
		if not finite(channel) or channel < 0 or channel > 255 then
			return false
		end
	end
	return true
end

local function validGlow(glow: any): boolean
	if type(glow) ~= "table" then
		return false
	end
	if type(glow.name) ~= "string" or glow.name == "" then
		return false
	end
	if type(glow.lightName) ~= "string" or glow.lightName == "" then
		return false
	end
	if type(glow.depthMode) ~= "string" or glow.depthMode == "" then
		return false
	end
	if not finite(glow.fillTransparency) or glow.fillTransparency < 0 or glow.fillTransparency > 1 then
		return false
	end
	if not finite(glow.outlineTransparency) or glow.outlineTransparency < 0 or glow.outlineTransparency > 1 then
		return false
	end
	if not finite(glow.lightBrightness) or glow.lightBrightness < 0 then
		return false
	end
	if not finite(glow.lightRange) or glow.lightRange <= 0 then
		return false
	end
	return true
end

-- Spawn index 1 is ORDER[1]. Wave 4 spawns one enemy per element, so
-- each color is on screen together.
function ElementGlow.assign(spawnIndex: number): string
	local order = Elements.ORDER
	local count = #order
	local n = math.floor(spawnIndex)
	if count < 1 or n ~= n or n < 1 then
		return order[1]
	end
	local slot = ((n - 1) % count) + 1
	return order[slot]
end

-- nil when the flag is off, the id is unknown, or the config row cannot
-- draw a glow. The caller parents instances only from a non-nil result.
function ElementGlow.visual(elementId: string, enabled: boolean): Visual?
	if enabled ~= true then
		return nil
	end
	if type(elementId) ~= "string" then
		return nil
	end
	local row = Elements.LIST[elementId]
	if type(row) ~= "table" or not validColor(row.color) or not validGlow(Elements.GLOW) then
		return nil
	end
	local glow = Elements.GLOW
	local color = row.color
	return {
		elementId = elementId,
		color = { color[1], color[2], color[3] },
		name = glow.name,
		lightName = glow.lightName,
		fillTransparency = glow.fillTransparency,
		outlineTransparency = glow.outlineTransparency,
		lightBrightness = glow.lightBrightness,
		lightRange = glow.lightRange,
		depthMode = glow.depthMode,
	}
end

-- Server entry. Flag off returns nil before an element is chosen, so
-- nothing is replicated.
function ElementGlow.forEnemy(spawnIndex: number, enabled: boolean): Visual?
	if enabled ~= true then
		return nil
	end
	return ElementGlow.visual(ElementGlow.assign(spawnIndex), true)
end

local function destroyNamed(owner: any, name: any, className: string)
	if owner == nil or type(name) ~= "string" or type(owner.FindFirstChild) ~= "function" then
		return
	end
	local child = owner:FindFirstChild(name)
	if child == nil or type(child.IsA) ~= "function" or not child:IsA(className) then
		return
	end
	if type(child.Destroy) == "function" then
		child:Destroy()
	end
end

-- Death keeps the rig as Remains until the next wave. Destroy the glow
-- Highlight immediately so a corpse does not hold a slot in the 31 cap.
-- The warm Rim is left alone. A missing glow is a no-op. Works on a real
-- Instance (userdata) and on a test stand-in.
function ElementGlow.detach(host: any, part: any)
	local glow = Elements.GLOW
	if type(glow) ~= "table" then
		return
	end
	destroyNamed(host, glow.name, "Highlight")
	destroyNamed(part, glow.lightName, "PointLight")
end

return ElementGlow
