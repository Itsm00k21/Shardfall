--!strict

--[[
	Cold open, tutorial steps, and the starter kit.

	The client can skip. Finishing and skipping pay the same rewards.
	An existing save is marked done so a playtest character is not tutored
	again.

	The T3 guide is LaunchGate.firstSessionGuide. Off, skip and note behave
	as they always have: no guide tokens, no free-roll step. On, unused
	free rolls are paid once inside the same onboardDone check as the
	starter kit. Replay writes nothing.
]]

-- Lune has no DataModel. Studio requires go through ReplicatedStorage.
local FirstSessionKit
local LaunchGate
local Onboarding
local SessionGuide
if game ~= nil and game.GetService ~= nil then
	local Shared = game:GetService("ReplicatedStorage").Shared
	FirstSessionKit = require(Shared.FirstSessionKit)
	LaunchGate = require(Shared.LaunchGate)
	Onboarding = require(Shared.Onboarding)
	SessionGuide = require(Shared.SessionGuide)
else
	FirstSessionKit = require("../../ReplicatedStorage/Shared/FirstSessionKit")
	LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
	Onboarding = require("../../ReplicatedStorage/Shared/Onboarding")
	SessionGuide = require("../../ReplicatedStorage/Shared/SessionGuide")
end

local function dataService()
	if game ~= nil and game.GetService ~= nil then
		return require(script.Parent.DataService)
	end
	return require("./DataService")
end

local OnboardingService = {}

local watching = false

local function move(data, eventId: string)
	if data.onboardDone == true then
		return
	end
	if data.onboardStep ~= eventId then
		return
	end
	-- Roll steps move inside the crack mutate. A later note cannot
	-- advance them again or skip the item.
	if SessionGuide.freeStep(eventId) then
		return
	end
	local following = Onboarding.next(data.onboardStep)
	if following == nil then
		Onboarding.starter(data)
		return
	end
	data.onboardStep = following
end

local function grantKit(data)
	if data.onboardDone == true then
		FirstSessionKit.grant(data)
	end
end

function OnboardingService.applyNote(data, eventId: string)
	move(data, eventId)
	grantKit(data)
end

function OnboardingService.note(player: Player, eventId: string)
	dataService().mutate(player, function(data)
		OnboardingService.applyNote(data, eventId)
		return nil
	end)
end

function OnboardingService.advance(player: Player)
	local store = dataService()
	local profile = store.get(player)
	if profile == nil or profile.onboardDone then
		return { ok = true, profile = store.snapshot(player) }
	end
	if profile.onboardStep ~= "open" and profile.onboardStep ~= "haven" then
		return { ok = false, error = "Try it in the world first." }
	end
	local saved, err = store.mutate(player, function(data)
		if data.onboardStep == "haven" then
			Onboarding.starter(data)
		else
			move(data, data.onboardStep)
		end
		grantKit(data)
		return nil
	end)
	if not saved then
		return { ok = false, error = err or "Could not save." }
	end
	return { ok = true, profile = store.snapshot(player) }
end

-- R1. The token count is read from the saved step, then paid, then the
-- starter kit marks the guide done. All of that is one mutate in skip().
-- FirstSessionKit stays outside that check: it pays from its own flags,
-- once, and only after a class exists.
function OnboardingService.applySkip(data)
	if data.onboardDone ~= true then
		local tokens = SessionGuide.unusedRollTokens(data)
		SessionGuide.grantTokens(data, tokens)
		SessionGuide.record("skip", tostring(data.onboardStep))
		Onboarding.starter(data)
	end
	FirstSessionKit.grant(data)
end

function OnboardingService.skip(player: Player)
	local saved, err = dataService().mutate(player, function(data)
		OnboardingService.applySkip(data)
		return nil
	end)
	if not saved then
		return { ok = false, error = err or "Could not save." }
	end
	return { ok = true, profile = dataService().snapshot(player) }
end

-- Replay is pointing only. No kit, no tokens, no step write, no save.
function OnboardingService.replay(_player: Player)
	return { ok = true, replay = true }
end

function OnboardingService.touch(player: Player, x: number, y: number, z: number)
	if not LaunchGate.on("firstSessionGuide") then
		return
	end
	dataService().mutate(player, function(data)
		SessionGuide.advancePad(data, x, y, z)
		return nil
	end)
end

function OnboardingService.start()
	if watching then
		return
	end
	watching = true
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	RunService.Heartbeat:Connect(function()
		if not LaunchGate.on("firstSessionGuide") then
			return
		end
		for _, player in Players:GetPlayers() do
			local profile = dataService().get(player)
			if profile == nil or profile.onboardDone == true or profile.onboardStep ~= "gate" then
				continue
			end
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if root == nil or not root:IsA("BasePart") then
				continue
			end
			local position = root.Position
			if SessionGuide.padHit(position.X, position.Y, position.Z) then
				OnboardingService.touch(player, position.X, position.Y, position.Z)
			end
		end
	end)
end

return OnboardingService
