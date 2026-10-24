--!strict

--[[
	Cold open, tutorial steps, and the starter kit.

	The client can skip. Finishing and skipping pay the same rewards.
	An existing save is marked done so a playtest character is not tutored
	again.

	The T3 guide is LaunchGate.firstSessionGuide. Off, note and free rolls
	stay as they were. advance() treats a saved guide step as the cold-open
	card, so a rollback is not stuck. Skip pays the saved step's tokens
	once either way, except a flag-off open step, which owes 0. Replay
	writes nothing.

	LaunchGate.classes off: the cold open does not stop on the class card.
	A save already sitting there moves to the next step. On, only a class
	pick leaves it. Neither path pays the starter kit.
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
local padCarry = 0

-- The class card stays in the cold-open list. While the classes switch
-- is off, nothing can pick one, so that card is not a step.
local function afterClass(): string?
	local following = Onboarding.next("class")
	if type(following) ~= "string" or following == "" or following == "class" then
		return nil
	end
	return following
end

local function nextStep(id: string): string?
	local following = Onboarding.next(id)
	if following == "class" and not LaunchGate.on("classes") then
		return afterClass()
	end
	return following
end

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
	local following = nextStep(data.onboardStep)
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

-- A profile parked on the class card moves on while classes are off.
-- Flag on, this writes nothing: the class pick is still the note.
function OnboardingService.skipParkedClass(data): boolean
	if LaunchGate.on("classes") then
		return false
	end
	if type(data) ~= "table" or data.onboardDone == true or data.onboardStep ~= "class" then
		return false
	end
	local following = afterClass()
	if following == nil then
		return false
	end
	data.onboardStep = following
	return true
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

-- A saved guide id is the cold-open card while the flag is off. The
-- live guide (flag on) still refuses a roll or gate step here.
local function continueId(step: any): string
	if not LaunchGate.on("firstSessionGuide") and SessionGuide.known(step) then
		return "open"
	end
	if type(step) ~= "string" then
		return ""
	end
	return step
end

function OnboardingService.applyAdvance(data): (boolean, string?)
	if type(data) ~= "table" then
		return false, "Try it in the world first."
	end
	if data.onboardDone == true then
		return true, nil
	end
	local step = continueId(data.onboardStep)
	if step ~= "open" and step ~= "haven" then
		return false, "Try it in the world first."
	end
	if step == "haven" then
		Onboarding.starter(data)
	else
		data.onboardStep = step
		move(data, step)
	end
	grantKit(data)
	return true, nil
end

function OnboardingService.advance(player: Player)
	local store = dataService()
	local profile = store.get(player)
	if profile == nil or profile.onboardDone then
		return { ok = true, profile = store.snapshot(player) }
	end
	local saved, err = store.mutate(player, function(data)
		local proceeded, why = OnboardingService.applyAdvance(data)
		if not proceeded then
			return why or "Try it in the world first."
		end
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
	-- Join still pushes a save that stopped on the class card. Move it
	-- before the player is stuck there. Flag on does not write.
	dataService().onChanged(function(player, snapshot)
		if LaunchGate.on("classes") then
			return
		end
		if type(snapshot) ~= "table" or snapshot.onboardDone == true then
			return
		end
		if snapshot.onboardStep ~= "class" then
			return
		end
		dataService().mutate(player, function(data)
			OnboardingService.skipParkedClass(data)
			return nil
		end)
	end)
	RunService.Heartbeat:Connect(function(dt)
		if not LaunchGate.on("firstSessionGuide") then
			return
		end
		local due
		padCarry, due = SessionGuide.padClock(padCarry, dt)
		if due ~= true then
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
