--!strict

--[[
	Haven bed and the four sound groups.

	Music, SFX, UI, and Ambience live under SoundService. The Haven track
	loops while the character is in the hub and fades out over two seconds
	in Rootvault or any other zone. TRACKS in Audio is the place to add a
	bed for a zone later. An empty id stays silent.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared:WaitForChild("Audio"))
local Dungeons = require(Shared:WaitForChild("Dungeons"))

local MusicController = {}

local function ensureGroup(name: string): SoundGroup
	local found = SoundService:FindFirstChild(name)
	if found ~= nil and found:IsA("SoundGroup") then
		return found
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = 1
	group.Parent = SoundService
	return group
end

local function inCrawl(): boolean
	local player = Players.LocalPlayer
	if player == nil then
		return false
	end
	local character = player.Character
	if character == nil then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return Dungeons.inCrawl(root.Position.X, root.Position.Z)
end

function MusicController.start()
	local groups = {}
	for _, name in ipairs(Audio.GROUPS) do
		groups[name] = ensureGroup(name)
	end
	local musicGroup = groups.Music
	local sfxGroup = groups.SFX
	local uiGroup = groups.UI
	local ambienceGroup = groups.Ambience

	local bed = Instance.new("Sound")
	bed.Name = "HavenBed"
	bed.Looped = true
	bed.Volume = 0
	bed.SoundGroup = musicGroup
	bed.Parent = SoundService

	local armed = false
	local heardZone = false
	local currentZone = ""
	local derivedZone = ""
	local overrideZone: string? = nil
	local overrideAnchor = ""
	local activeTween: Tween? = nil
	local fadeToken = 0

	local function assignAmbience(sound: Instance)
		if sound:IsA("Sound") and string.find(sound.Name, "Ambience", 1, true) ~= nil then
			sound.SoundGroup = ambienceGroup
		end
	end
	for _, descendant in ipairs(workspace:GetDescendants()) do
		assignAmbience(descendant)
	end
	workspace.DescendantAdded:Connect(assignAmbience)

	local function fadeTo(goal: number, done: (() -> ())?)
		if activeTween ~= nil then
			activeTween:Cancel()
			activeTween = nil
		end
		fadeToken += 1
		local token = fadeToken
		local tween = TweenService:Create(
			bed,
			TweenInfo.new(Audio.FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Volume = goal }
		)
		activeTween = tween
		tween.Completed:Connect(function(state)
			if token ~= fadeToken then
				return
			end
			activeTween = nil
			if state == Enum.PlaybackState.Completed and done ~= nil then
				done()
			end
		end)
		tween:Play()
	end

	local function playBed(zoneId: string, fadeIn: boolean)
		local id = Audio.trackFor(zoneId)
		if id == nil then
			if bed.IsPlaying and bed.Volume > 0 then
				fadeTo(0, function()
					bed:Stop()
				end)
			else
				bed.Volume = 0
				bed:Stop()
			end
			return
		end
		local function rise()
			bed.SoundId = id
			if fadeIn then
				bed.Volume = 0
				if not bed.IsPlaying then
					bed:Play()
				end
				fadeTo(Audio.HAVEN_VOLUME, nil)
			else
				if activeTween ~= nil then
					activeTween:Cancel()
					activeTween = nil
				end
				fadeToken += 1
				bed.Volume = Audio.HAVEN_VOLUME
				if not bed.IsPlaying then
					bed:Play()
				end
			end
		end
		if bed.IsPlaying and bed.SoundId ~= id and bed.Volume > 0.01 then
			fadeTo(0, rise)
			return
		end
		rise()
	end

	local function applyZone(zoneId: string, fadeIn: boolean)
		if zoneId == currentZone then
			return
		end
		currentZone = zoneId
		print("[Music] zone " .. zoneId)
		playBed(zoneId, fadeIn)
	end

	local function watch()
		local positionZone = Audio.zoneFor(inCrawl())
		if overrideZone ~= nil and positionZone ~= overrideAnchor then
			overrideZone = nil
		end
		local zone = if overrideZone ~= nil then overrideZone else positionZone
		if not armed then
			return
		end
		if zone == derivedZone and heardZone then
			return
		end
		derivedZone = zone
		applyZone(zone, heardZone)
		heardZone = true
	end

	RunService.Heartbeat:Connect(watch)

	print(
		string.format("[Music] groups ready haven=%s", tostring(Audio.trackFor(Audio.HAVEN_ZONE)))
	)

	return {
		setVolumes = function(music: number, sfx: number)
			local musicVolume = Audio.clampVolume(music)
			local sfxVolume = Audio.clampVolume(sfx)
			musicGroup.Volume = musicVolume
			sfxGroup.Volume = sfxVolume
			uiGroup.Volume = sfxVolume
			ambienceGroup.Volume = sfxVolume
			if not armed then
				armed = true
				watch()
			end
		end,
		-- Later zones call this. The position watch takes over again when
		-- the character actually changes between Haven and a crawl.
		setZone = function(zoneId: string)
			if type(zoneId) ~= "string" or zoneId == "" then
				return
			end
			overrideZone = zoneId
			overrideAnchor = Audio.zoneFor(inCrawl())
			derivedZone = ""
			if armed then
				watch()
			end
		end,
	}
end

return MusicController
