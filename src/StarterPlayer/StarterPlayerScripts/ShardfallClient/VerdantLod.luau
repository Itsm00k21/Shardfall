--!strict

--[[
	Client graphics tier.

	Hides trim props and small dressing, scales particles, and turns decor
	shadows off. LocalTransparencyModifier and emitter fields stay on this
	client, so another player's High setting still sees the full hub.

	The scan only walks Haven. Dungeon parts also carry ShardfallLod, and
	counting those made "trimmed" climb as rooms streamed in. Landmarks are
	pinned every frame so a streaming fade cannot leave them at modifier 1.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HavenLife = require(Shared:WaitForChild("HavenLife"))
local Quality = require(Shared:WaitForChild("Quality"))
local ShellLayout = require(Shared:WaitForChild("ShellLayout"))

local VerdantLod = {}

local tierId = "med"
local nextScan = 0
local bases: { [ParticleEmitter]: number } = {}
local pinned: { BasePart } = {}
local reportedArt = false

function VerdantLod.setTier(id: string)
	local known = Quality.normalize(id)
	if known == nil or known == tierId then
		return
	end
	tierId = known
	nextScan = 0
end

function VerdantLod.tier(): string
	return tierId
end

local function applyLighting(tier: Quality.Tier)
	Lighting.FogEnd = tier.fogEnd
	if Lighting.FogStart > tier.fogEnd * 0.25 then
		Lighting.FogStart = tier.fogEnd * 0.15
	end
	local exposure = HavenLife.exposure(Lighting.ClockTime)
	local bloom = Lighting:FindFirstChild("VerdantBloom")
	if bloom ~= nil and bloom:IsA("BloomEffect") then
		bloom.Intensity = math.min(tier.bloom, exposure.bloomIntensity)
		bloom.Size = exposure.bloomSize
		bloom.Threshold = math.max(bloom.Threshold, exposure.bloomThreshold)
	end
	local rays = Lighting:FindFirstChild("VerdantSunRays")
	if rays ~= nil and rays:IsA("SunRaysEffect") then
		rays.Intensity = exposure.sunIntensity
		rays.Spread = exposure.sunSpread
	end
end

local function ancestorsOf(instance: Instance): { string }
	local names = {}
	local cursor: Instance? = instance.Parent
	local depth = 0
	while cursor ~= nil and depth < 6 do
		table.insert(names, cursor.Name)
		cursor = cursor.Parent
		depth += 1
	end
	return names
end

local function holdPinned()
	for _, part in ipairs(pinned) do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = 0
			if part.Transparency >= 0.45 then
				part.Transparency = 0.08
			end
		end
	end
end

local function isLandmark(part: BasePart, names: { string }): boolean
	return part:GetAttribute("ShardfallKeep") == true
		or Quality.alwaysVisible(part.Name, part:GetAttribute("WaystoneId"), names)
end

local function longest(part: BasePart): number
	return math.max(part.Size.X, part.Size.Y, part.Size.Z)
end

local function pair(before: number, after: number): string
	if math.abs(before - after) < 0.01 then
		return string.format("%.2f", before)
	end
	return string.format("%.2f>%.2f", before, after)
end

local function sizeText(size: Vector3): string
	return string.format("%.1f,%.1f,%.1f", size.X, size.Y, size.Z)
end

local function sizePair(before: Vector3, after: Vector3): string
	local left = sizeText(before)
	local right = sizeText(after)
	if left == right then
		return left
	end
	return left .. ">" .. right
end

local function describe(
	part: BasePart,
	origin: Vector3?,
	tBefore: number,
	ltmBefore: number,
	sizeBefore: Vector3
): string
	local stream = "nocam"
	if origin ~= nil then
		local cam = (part.Position - origin).Magnitude
		local radius = 512
		local ok, value = pcall(function()
			return Workspace.StreamingTargetRadius
		end)
		if ok and type(value) == "number" and value > 0 then
			radius = value
		end
		stream = if cam <= radius then "in" else "out"
	end
	local parentName = "nil"
	if part.Parent ~= nil then
		parentName = part.Parent:GetFullName()
	end
	return string.format(
		"%s t=%s ltm=%s y=%.1f size=%s parent=%s inWorkspace=%s stream=%s",
		part.Name,
		pair(tBefore, part.Transparency),
		pair(ltmBefore, part.LocalTransparencyModifier),
		part.Position.Y,
		sizePair(sizeBefore, part.Size),
		parentName,
		tostring(part:IsDescendantOf(Workspace)),
		stream
	)
end

local function fadeBillboards(origin: Vector3)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BillboardGui") then
			if descendant.Name == "ShardfallBar" or descendant.Name == "DropLabel" then
				continue
			end
			local host = descendant.Parent
			local point: Vector3? = nil
			if host ~= nil and host:IsA("BasePart") then
				point = host.Position
			end
			local adornee = descendant.Adornee
			if point == nil and adornee ~= nil and adornee:IsA("BasePart") then
				point = adornee.Position
			end
			if point ~= nil then
				local distance = (point - origin).Magnitude
				local visible = ShellLayout.zoneVisible(distance)
				descendant.Enabled = visible
				descendant.MaxDistance = ShellLayout.ZONE_MAX_DISTANCE
				descendant.AlwaysOnTop = false
				if visible and host ~= nil and host:GetAttribute("HavenLabel") ~= nil then
					local scale = math.max(ShellLayout.zoneScale(distance), 0.35)
					descendant.Size = UDim2.fromScale(
						ShellLayout.ZONE_WIDTH_STUDS * scale,
						ShellLayout.ZONE_HEIGHT_STUDS * scale
					)
				end
			end
		end
	end
end

local function savedSize(part: BasePart): Vector3?
	local x = part:GetAttribute("ShardfallSizeX")
	local y = part:GetAttribute("ShardfallSizeY")
	local z = part:GetAttribute("ShardfallSizeZ")
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return nil
	end
	return Vector3.new(x, y, z)
end

type Sample = {
	text: string,
	ok: boolean,
}

local function remember(slot: Sample?, ok: boolean): Sample
	if slot == nil or (slot.ok and not ok) then
		return { text = "", ok = ok }
	end
	return slot
end

function VerdantLod.start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextScan then
			holdPinned()
			return
		end
		nextScan = now + 1.5
		local tier = Quality.get(tierId)
		applyLighting(tier)
		local haven = Workspace:FindFirstChild("Haven")
		if haven == nil then
			return
		end
		local camera = Workspace.CurrentCamera
		local origin = if camera ~= nil then camera.CFrame.Position else nil
		if origin ~= nil then
			fadeBillboards(origin)
		end
		table.clear(pinned)
		local trimIndex = 0
		local shown = 0
		local particleIndex = 0
		local trimmed = 0
		local parts = 0
		local waterfalls = 0
		local waterfallsShown = 0
		local waystones = 0
		local waystonesShown = 0
		local forgeShown = 0
		local npcs = 0
		local npcShown = 0
		local skies = 0
		local skiesShown = 0
		local hearts = 0
		local heartsShown = 0
		local fallSample: Sample? = nil
		local waySample: Sample? = nil
		local npcSample: Sample? = nil
		local skySample: Sample? = nil
		local heartSample: Sample? = nil

		for _, descendant in ipairs(haven:GetDescendants()) do
			if descendant:IsA("BasePart") then
				parts += 1
				local names = ancestorsOf(descendant)
				local tBefore = descendant.Transparency
				local ltmBefore = descendant.LocalTransparencyModifier
				local sizeBefore = descendant.Size
				local remembered = savedSize(descendant)
				if remembered ~= nil then
					local current = longest(descendant)
					local stored = math.max(remembered.X, remembered.Y, remembered.Z)
					if current < 1 and stored > 1 then
						descendant.Size = remembered
					end
				end
				local span = longest(descendant)
				local inWorld = descendant:IsDescendantOf(Workspace)
				local y = descendant.Position.Y
				local visible = Quality.drawn(tBefore, ltmBefore, inWorld, y, span)
				local big = Quality.modelShown(tBefore, ltmBefore, inWorld, y, span)
				local landmark = isLandmark(descendant, names)
				if descendant.Name == "Waterfall" then
					waterfalls += 1
					if visible then
						waterfallsShown += 1
					end
					fallSample = remember(fallSample, visible)
				elseif descendant.Name == "Waystone" then
					waystones += 1
					if visible then
						waystonesShown += 1
					end
					waySample = remember(waySample, visible)
				elseif descendant.Name == "ForgeFlame" and visible then
					forgeShown += 1
				elseif descendant.Name == "SkyShard" then
					skies += 1
					if visible then
						skiesShown += 1
					end
					skySample = remember(skySample, visible)
				elseif descendant.Name == "LumenHeart" then
					hearts += 1
					if visible then
						heartsShown += 1
					end
					heartSample = remember(heartSample, visible)
				end
				local folk = false
				for _, ancestor in ipairs(names) do
					if ancestor == "Townsfolk" then
						folk = true
						break
					end
				end
				if folk and (descendant.Name == "Body" or descendant.Name == "TownsfolkFlag") then
					if descendant.Name == "Body" then
						npcs += 1
						if big then
							npcShown += 1
						end
					end
					npcSample = remember(npcSample, big)
				end

				if landmark then
					descendant.LocalTransparencyModifier = 0
					if descendant.Transparency >= 0.45 then
						descendant.Transparency = 0.08
					end
					table.insert(pinned, descendant)
					for _, child in ipairs(descendant:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							child.Enabled = true
						end
					end
				else
					local lod = descendant:GetAttribute("ShardfallLod")
					local trimAttr = descendant:GetAttribute("ShardfallTrim") == true
					local distance = if origin ~= nil
						then (descendant.Position - origin).Magnitude
						else 0
					local hide, nextTrim, nextShown = Quality.lodHide(
						descendant.Name,
						descendant:GetAttribute("WaystoneId"),
						names,
						false,
						lod,
						trimAttr,
						distance,
						tierId,
						trimIndex,
						shown
					)
					trimIndex = nextTrim
					shown = nextShown
					local tagged = type(lod) == "string" or trimAttr or lod == "small"
					if tagged then
						if hide then
							trimmed += 1
						end
						descendant.LocalTransparencyModifier = if hide then 1 else 0
						local lodName = if type(lod) == "string" then lod else "large"
						descendant.CastShadow = (not hide) and Quality.castShadow(lodName, tierId)
						for _, child in ipairs(descendant:GetChildren()) do
							if child:IsA("ParticleEmitter") then
								particleIndex += 1
								if bases[child] == nil then
									bases[child] = child.Rate
								end
								local allow = not hide
									and Quality.particleEnabled(particleIndex, tierId)
								child.Enabled = allow
								if allow then
									child.Rate =
										Quality.particleRate(bases[child] :: number, tierId)
								end
							end
						end
					end
				end
				local text = describe(descendant, origin, tBefore, ltmBefore, sizeBefore)
				if
					descendant.Name == "Waterfall"
					and fallSample ~= nil
					and fallSample.text == ""
				then
					fallSample = { text = text, ok = fallSample.ok }
				elseif
					descendant.Name == "Waystone"
					and waySample ~= nil
					and waySample.text == ""
				then
					waySample = { text = text, ok = waySample.ok }
				elseif
					descendant.Name == "SkyShard"
					and skySample ~= nil
					and skySample.text == ""
				then
					skySample = { text = text, ok = skySample.ok }
				elseif
					descendant.Name == "LumenHeart"
					and heartSample ~= nil
					and heartSample.text == ""
				then
					heartSample = { text = text, ok = heartSample.ok }
				elseif folk and npcSample ~= nil and npcSample.text == "" then
					if descendant.Name == "Body" or descendant.Name == "TownsfolkFlag" then
						npcSample = { text = text, ok = npcSample.ok }
					end
				end
			end
		end

		if parts < 10 then
			return
		end
		local function bit(slot: Sample?): string
			if slot == nil then
				return "missing"
			end
			return slot.text
		end
		local line = string.format(
			"[HavenArt] visible waterfalls %d/%d, npcs %d/%d, waystones %d/%d, forge %d, sky %d/%d, heart %d/%d; tier %s | %s | %s | %s | %s | %s",
			waterfallsShown,
			waterfalls,
			npcShown,
			npcs,
			waystonesShown,
			waystones,
			forgeShown,
			skiesShown,
			skies,
			heartsShown,
			hearts,
			tierId,
			bit(fallSample),
			bit(waySample),
			bit(npcSample),
			bit(skySample),
			bit(heartSample)
		)
		if not reportedArt then
			reportedArt = true
			print(line)
			print(
				string.format(
					"[HavenArt] haven cosmetics hidden %d by tier %s (hub only, not the whole place)",
					trimmed,
					tierId
				)
			)
		end
	end)
end

return VerdantLod
