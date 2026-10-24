--!strict

--[[
	Camera room around the boss. If the eye is inside the padded body, it
	is pushed out along the line from the boss so it cannot sit in the mesh.
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

local WaveArenaConfig = SharedRequire.module("Config/WaveArenaConfig")

local Camera = {}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

local function halves(size: { number }, pad: number): (number, number, number)
	return size[1] / 2 + pad, size[2] / 2 + pad, size[3] / 2 + pad
end

function Camera.inside(eye: any, center: any, size: { number }, config: any?): boolean
	local cfg = cfgOf(config)
	local hx, hy, hz = halves(size, cfg.camera.roomPad)
	local dx = eye.x - center.x
	local dy = eye.y - center.y
	local dz = eye.z - center.z
	return math.abs(dx) <= hx and math.abs(dy) <= hy and math.abs(dz) <= hz
end

local function face(offset: number, half: number, dir: number): number
	local ad = math.abs(dir)
	if ad < 1e-6 then
		return math.huge
	end
	return (half - math.abs(offset)) / ad
end

function Camera.correct(eye: any, center: any, size: { number }, config: any?): any
	local cfg = cfgOf(config)
	local pad = cfg.camera.roomPad
	local hx, hy, hz = halves(size, pad)
	local dx = eye.x - center.x
	local dy = eye.y - center.y
	local dz = eye.z - center.z
	if math.abs(dx) > hx or math.abs(dy) > hy or math.abs(dz) > hz then
		return { x = eye.x, y = eye.y, z = eye.z, moved = false }
	end
	local ox, oy, oz = dx, dy, dz
	local len = math.sqrt(ox * ox + oy * oy + oz * oz)
	if len < 1e-4 then
		ox, oy, oz = 0, 0, 1
		len = 1
	end
	local dirx = ox / len
	local diry = oy / len
	local dirz = oz / len
	local t = math.min(face(ox, hx, dirx), face(oy, hy, diry), face(oz, hz, dirz))
	if t ~= t or t < 0 or t == math.huge then
		t = 0
	end
	t += cfg.camera.minEyeGap
	return {
		x = center.x + ox + dirx * t,
		y = center.y + oy + diry * t,
		z = center.z + oz + dirz * t,
		moved = true,
	}
end

function Camera.room(center: any, size: { number }, config: any?): any
	local cfg = cfgOf(config)
	local pad = cfg.camera.roomPad
	return {
		name = "WaveArenaCameraRoom",
		shape = "Block",
		canCollide = false,
		size = { size[1] + pad * 2, size[2] + pad * 2, size[3] + pad * 2 },
		position = { center.x, center.y, center.z },
	}
end

return Camera
