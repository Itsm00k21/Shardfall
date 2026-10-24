--!strict

--[[
	[ECHO hook] Camera room. If the eye sits inside the padded boss box it
	is pushed out along the line from the boss. The numbers come from the
	server snapshot (WaveArenaConfig.camera). The camera is left alone when
	there is no living boss.
]]

local CameraRoom = {}

local function halves(size: { number }, pad: number): (number, number, number)
	return size[1] / 2 + pad, size[2] / 2 + pad, size[3] / 2 + pad
end

local function face(offset: number, half: number, dir: number): number
	local ad = math.abs(dir)
	if ad < 1e-6 then
		return math.huge
	end
	return (half - math.abs(offset)) / ad
end

function CameraRoom.correct(
	eye: { number },
	center: { number },
	size: { number },
	pad: number,
	gap: number
): { number }?
	if #size < 3 then
		return nil
	end
	local hx, hy, hz = halves(size, pad)
	local dx = eye[1] - center[1]
	local dy = eye[2] - center[2]
	local dz = eye[3] - center[3]
	if math.abs(dx) > hx or math.abs(dy) > hy or math.abs(dz) > hz then
		return { eye[1], eye[2], eye[3] }
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
	t += gap
	return {
		center[1] + ox + dirx * t,
		center[2] + oy + diry * t,
		center[3] + oz + dirz * t,
	}
end

function CameraRoom.apply(boss: any, cameraPad: any)
	if typeof(boss) ~= "table" or typeof(boss.size) ~= "table" then
		return
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local pad = 6
	local gap = 3
	if typeof(cameraPad) == "table" then
		if type(cameraPad.roomPad) == "number" then
			pad = cameraPad.roomPad
		end
		if type(cameraPad.minEyeGap) == "number" then
			gap = cameraPad.minEyeGap
		end
	end
	local eyePos = camera.CFrame.Position
	local moved = CameraRoom.correct(
		{ eyePos.X, eyePos.Y, eyePos.Z },
		{ boss.x, boss.y, boss.z },
		{ boss.size[1], boss.size[2], boss.size[3] },
		pad,
		gap
	)
	if moved == nil then
		return
	end
	local nextEye = Vector3.new(moved[1], moved[2], moved[3])
	if (nextEye - eyePos).Magnitude < 0.05 then
		return
	end
	camera.CFrame = CFrame.new(nextEye, Vector3.new(boss.x, boss.y, boss.z))
end

return CameraRoom
