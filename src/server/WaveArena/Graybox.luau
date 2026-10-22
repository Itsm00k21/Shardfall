--!strict

--[[
	Round graybox. A cylinder floor, a ring of wall blocks with three gaps,
	a post on each side of a gap, and a flat pad in each gate.

	Pieces are plain data. No Instances, so the plan can be tested in lune
	and applied later when both guards are on. Coordinates are arena-local
	until Graybox.plan adds the origin.
]]

local WaveArenaConfig = require("../../shared/Config/WaveArenaConfig")

local Graybox = {}

export type Piece = {
	kind: string,
	name: string,
	shape: string,
	size: { number },
	x: number,
	z: number,
	y: number,
	rotation: { number },
	color: { number },
	canCollide: boolean,
	solid: boolean,
	hx: number,
	hz: number,
	yaw: number,
}

export type Solid = {
	x: number,
	z: number,
	hx: number,
	hz: number,
	yaw: number,
}

export type PartPlan = {
	kind: string,
	name: string,
	shape: string,
	size: { number },
	position: { number },
	rotation: { number },
	color: { number },
	canCollide: boolean,
}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

function Graybox.innerRadius(config: any?): number
	local cfg = cfgOf(config)
	return cfg.arena.diameter / 2 - cfg.arena.wallThickness
end

local function wrap(angle: number): number
	local turn = math.pi * 2
	local value = angle % turn
	if value < 0 then
		value += turn
	end
	return value
end

local function angleDelta(a: number, b: number): number
	local delta = math.abs(wrap(a) - wrap(b))
	if delta > math.pi then
		return math.pi * 2 - delta
	end
	return delta
end

function Graybox.gateAngles(config: any?): { number }
	local cfg = cfgOf(config)
	local angles = {}
	local step = (math.pi * 2) / cfg.gates.count
	for index = 0, cfg.gates.count - 1 do
		table.insert(angles, cfg.gates.facing + step * index)
	end
	return angles
end

local function push(list: { Piece }, piece: Piece)
	table.insert(list, piece)
end

function Graybox.pieces(config: any?): { Piece }
	local cfg = cfgOf(config)
	local arena = cfg.arena
	local gates = cfg.gates
	local inner = Graybox.innerRadius(cfg)
	local midR = arena.diameter / 2 - arena.wallThickness / 2
	local angles = Graybox.gateAngles(cfg)
	local opening = (gates.width / 2) / inner + math.pi / arena.wallSegments
	local list: { Piece } = {}

	push(list, {
		kind = "floor",
		name = "WaveArenaFloor",
		shape = "Cylinder",
		-- Cylinder axis is local X. A 90° roll stands it up.
		size = { arena.floorThickness, arena.diameter, arena.diameter },
		x = 0,
		z = 0,
		y = -arena.floorThickness / 2,
		rotation = { 0, 0, math.rad(90) },
		color = arena.floorColor,
		canCollide = true,
		solid = false,
		hx = 0,
		hz = 0,
		yaw = 0,
	})

	local segments = arena.wallSegments
	local arc = (math.pi * 2 * midR) / segments
	for index = 0, segments - 1 do
		local angle = index * (math.pi * 2) / segments
		local open = false
		for _, gate in ipairs(angles) do
			if angleDelta(angle, gate) <= opening then
				open = true
				break
			end
		end
		if not open then
			push(list, {
				kind = "wall",
				name = "WaveArenaWall",
				shape = "Block",
				size = { arc * 1.05, arena.wallHeight, arena.wallThickness },
				x = math.cos(angle) * midR,
				z = math.sin(angle) * midR,
				y = arena.wallHeight / 2,
				rotation = { 0, angle, 0 },
				color = arena.wallColor,
				canCollide = true,
				solid = true,
				hx = (arc * 1.05) / 2,
				hz = arena.wallThickness / 2,
				yaw = angle,
			})
		end
	end

	local half = (gates.width / 2) / inner
	local postHz = gates.postDepth / 2
	local postR = inner - gates.postInward + postHz
	for _, gate in ipairs(angles) do
		push(list, {
			kind = "gate",
			name = "WaveArenaGate",
			shape = "Block",
			size = { gates.width * 0.55, 0.2, 3 },
			x = math.cos(gate) * (inner - 2),
			z = math.sin(gate) * (inner - 2),
			y = 0.1,
			rotation = { 0, gate, 0 },
			color = arena.gateColor,
			canCollide = false,
			solid = false,
			hx = 0,
			hz = 0,
			yaw = gate,
		})
		for _, side in ipairs({ -1, 1 }) do
			local angle = gate + side * half
			push(list, {
				kind = "post",
				name = "WaveArenaPost",
				shape = "Block",
				size = { gates.postWidth, arena.wallHeight, gates.postDepth },
				x = math.cos(angle) * postR,
				z = math.sin(angle) * postR,
				y = arena.wallHeight / 2,
				rotation = { 0, angle, 0 },
				color = arena.postColor,
				canCollide = true,
				solid = true,
				hx = gates.postWidth / 2,
				hz = postHz,
				yaw = angle,
			})
		end
	end

	push(list, {
		kind = "stand",
		name = "WaveArenaStand",
		shape = "Block",
		size = { 4, 0.2, 4 },
		x = 0,
		z = 0,
		y = 0.1,
		rotation = { 0, 0, 0 },
		color = arena.standColor,
		canCollide = false,
		solid = false,
		hx = 0,
		hz = 0,
		yaw = 0,
	})

	return list
end

function Graybox.solids(config: any?): { Solid }
	local solids: { Solid } = {}
	for _, piece in ipairs(Graybox.pieces(config)) do
		if piece.solid then
			table.insert(solids, {
				x = piece.x,
				z = piece.z,
				hx = piece.hx,
				hz = piece.hz,
				yaw = piece.yaw,
			})
		end
	end
	return solids
end

function Graybox.plan(config: any?): { PartPlan }
	local cfg = cfgOf(config)
	local origin = cfg.arena.origin
	local parts: { PartPlan } = {}
	for _, piece in ipairs(Graybox.pieces(cfg)) do
		table.insert(parts, {
			kind = piece.kind,
			name = piece.name,
			shape = piece.shape,
			size = piece.size,
			position = { origin.x + piece.x, origin.y + piece.y, origin.z + piece.z },
			rotation = piece.rotation,
			color = piece.color,
			canCollide = piece.canCollide,
		})
	end
	return parts
end

return Graybox
