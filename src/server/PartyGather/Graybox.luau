--!strict

--[[
	Gray-box pieces for the Gate Ring. Plain data, no Instances, no
	ProximityPrompt. The host applies the plan only while the flag is on.
]]

-- Shared modules. Studio walks script to the server folder. Lune uses ./SharedRoot.
local SharedRequire
if game ~= nil and game.GetService ~= nil then
	local server = script:FindFirstAncestor("server")
	if server == nil then
		error("SharedRequire is not under server")
	end
	SharedRequire = require(server:WaitForChild("SharedRoot"))
else
	SharedRequire = require("./SharedRoot")
end

local PartyGatherConfig = SharedRequire.module("Config/PartyGather")

local Graybox = {}

export type Piece = {
	name: string,
	shape: string,
	size: { number },
	position: { number },
	rotation: { number },
	color: { number },
	canCollide: boolean,
	canTouch: boolean,
	canQuery: boolean,
	transparency: number,
	slotId: number?,
}

local function cfgOf(config: any): any
	return if config == nil then PartyGatherConfig else config
end

function Graybox.slotXZ(config: any, slot: any): (number, number)
	local cfg = cfgOf(config)
	return cfg.pad.x + slot.x, cfg.pad.z + slot.z
end

function Graybox.inPromptZone(x: number, z: number, config: any?): boolean
	local cfg = cfgOf(config)
	local dx = x - cfg.pad.x
	local dz = z - cfg.pad.z
	local radius = cfg.promptFreeRadius
	return dx * dx + dz * dz <= radius * radius
end

-- Haven portal prompts stay up. Only a prompt with no HavenAction is
-- silenced, and only while it stands inside the prompt-free zone.
function Graybox.suppressPrompt(havenAction: any, x: any, z: any, config: any?): boolean
	if type(havenAction) == "string" and havenAction ~= "" then
		return false
	end
	if type(x) ~= "number" or type(z) ~= "number" then
		return false
	end
	return Graybox.inPromptZone(x, z, config)
end

function Graybox.pieces(config: any?): { Piece }
	local cfg = cfgOf(config)
	local pad = cfg.pad
	local disc = cfg.slot
	local list: { Piece } = {}
	table.insert(list, {
		name = "GatherPad",
		shape = "Cylinder",
		size = { pad.thickness, pad.radius * 2, pad.radius * 2 },
		position = { pad.x, pad.y + pad.thickness / 2 + 0.05, pad.z },
		rotation = { 0, 0, math.rad(90) },
		color = pad.color,
		canCollide = false,
		canTouch = false,
		canQuery = false,
		transparency = 0.35,
		slotId = nil,
	})
	for _, slot in ipairs(cfg.slots) do
		local x, z = Graybox.slotXZ(cfg, slot)
		table.insert(list, {
			name = "GatherSlot" .. tostring(slot.id),
			shape = "Cylinder",
			size = { disc.height, disc.diameter, disc.diameter },
			position = { x, pad.y + disc.height / 2 + 0.08, z },
			rotation = { 0, 0, math.rad(90) },
			color = disc.openColor,
			canCollide = false,
			canTouch = false,
			canQuery = false,
			transparency = 0.15,
			slotId = slot.id,
		})
	end
	return list
end

return Graybox
