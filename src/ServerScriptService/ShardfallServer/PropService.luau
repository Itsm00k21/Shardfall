--!strict
--[[
	Dresses the Haven with generated crystal props after the hub is built.
	Meshes come from PropAssets through AssetService:CreateMeshPartAsync.
	Each load is cached, so repeats clone. A failed load stands a small
	Neon crystal made of parts instead, so the plaza is never bare.
	Props are decor: anchored, no collision, no touch, no query.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HavenProps = require(ReplicatedStorage.Shared.HavenProps)
local PropAssets = require(ReplicatedStorage.Shared.PropAssets)

local PropService = {}

local templates: { [string]: MeshPart | false } = {}

local function rgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

function PropService.load(kind: string): MeshPart?
	local cached = templates[kind]
	if cached == false then
		return nil
	end
	if cached ~= nil then
		return cached:Clone()
	end
	local asset = PropAssets[kind]
	if asset == nil then
		templates[kind] = false
		return nil
	end
	local AssetService = game:GetService("AssetService")
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(asset.mesh))
	end)
	if not ok or typeof(result) ~= "Instance" then
		warn("[Shardfall] Prop mesh " .. kind .. " did not load: " .. tostring(result))
		templates[kind] = false
		return nil
	end
	local mesh = result :: MeshPart
	mesh.TextureID = asset.texture
	mesh.Name = kind
	templates[kind] = mesh
	return mesh:Clone()
end

local function decor(piece: BasePart)
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = true
end

local function glow(piece: BasePart, channels: { number }, range: number)
	local light = Instance.new("PointLight")
	light.Color = rgb(channels)
	light.Range = range
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = piece
end

-- Path (c): a few leaning Neon blocks on a slate base.
local function fallback(parent: Instance, kind: string, ground: CFrame, height: number): Model
	local model = Instance.new("Model")
	model.Name = kind
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(height * 0.7, height * 0.12, height * 0.7)
	base.CFrame = ground * CFrame.new(0, base.Size.Y / 2, 0)
	base.Color = Color3.fromRGB(34, 30, 44)
	base.Material = Enum.Material.Slate
	decor(base)
	base.Parent = model
	local leans = { { 0, 0, 1 }, { 120, 22, 0.7 }, { 240, -20, 0.6 } }
	for index, lean in ipairs(leans) do
		local shard = Instance.new("Part")
		shard.Name = "Shard" .. index
		local h = height * lean[3]
		shard.Size = Vector3.new(h * 0.22, h, h * 0.22)
		shard.CFrame = ground
			* CFrame.Angles(0, math.rad(lean[1]), 0)
			* CFrame.Angles(math.rad(lean[2]), 0, 0)
			* CFrame.new(0, h / 2, 0)
		shard.Color = if index == 1 then Color3.fromRGB(150, 92, 255) else Color3.fromRGB(64, 206, 255)
		shard.Material = Enum.Material.Neon
		decor(shard)
		shard.Parent = model
	end
	glow(base, { 120, 140, 255 }, height * 1.4)
	model.Parent = parent
	return model
end

local function groundAt(x: number, z: number, ignore: { Instance }): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
	if hit == nil then
		return nil
	end
	return CFrame.new(hit.Position)
end

-- Stands one prop with its base on the ground, scaled to height.
function PropService.place(parent: Instance, kind: string, ground: CFrame, height: number, yaw: number): Instance
	local facing = ground * CFrame.Angles(0, math.rad(yaw), 0)
	local mesh = PropService.load(kind)
	if mesh == nil then
		return fallback(parent, kind, facing, height)
	end
	local scale = HavenProps.scaleFor(mesh.Size, height)
	mesh.Size = mesh.Size * scale
	-- Sink a hair so the rock base never floats on a bumpy floor.
	mesh.CFrame = facing * CFrame.new(0, mesh.Size.Y / 2 - 0.15, 0)
	decor(mesh)
	local asset = PropAssets[kind]
	if asset ~= nil then
		glow(mesh, asset.glow, math.max(8, height * 1.5))
	end
	mesh.Parent = parent
	return mesh
end

function PropService.start()
	task.spawn(function()
		local haven = workspace:WaitForChild("Haven", 30)
		if haven == nil then
			warn("[Shardfall] No Haven, crystal props skipped")
			return
		end
		task.wait(1)
		local folder = Instance.new("Folder")
		folder.Name = "CrystalProps"
		folder.Parent = haven
		local players = {}
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			if player.Character ~= nil then
				table.insert(players, player.Character)
			end
		end
		for _, spot in ipairs(HavenProps.SPOTS) do
			local ground = groundAt(spot.x, spot.z, players)
			if ground ~= nil then
				local ok, err = pcall(PropService.place, folder, spot.kind, ground, spot.height, spot.yaw)
				if not ok then
					warn("[Shardfall] Prop " .. spot.kind .. " failed: " .. tostring(err))
				end
			end
		end
	end)
end

return PropService
