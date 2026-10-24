--!strict

--[[
	Gray-box pieces for the Gate Ring. Plain data, no Instances, no
	ProximityPrompt. The host applies the plan only while the flag is on.
]]

local PartyGatherConfig = require("../../ReplicatedStorage/Shared/Config/PartyGather")

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
