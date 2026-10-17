--!strict

--[[
	Cold open, tutorial steps, and the starter kit.

	The client can skip. Finishing and skipping pay the same rewards.
	An existing save is marked done so a playtest character is not tutored
	again.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirstSessionKit = require(ReplicatedStorage.Shared.FirstSessionKit)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local DataService = require(script.Parent.DataService)

local OnboardingService = {}

local function move(data, eventId: string)
	if data.onboardDone == true then
		return
	end
	if data.onboardStep ~= eventId then
		return
	end
	local following = Onboarding.next(data.onboardStep)
	if following == nil then
		Onboarding.starter(data)
		return
	end
	data.onboardStep = following
end

function OnboardingService.note(player: Player, eventId: string)
	DataService.mutate(player, function(data)
		move(data, eventId)
		return nil
	end)
end

function OnboardingService.advance(player: Player)
	local profile = DataService.get(player)
	if profile == nil or profile.onboardDone then
		return { ok = true, profile = DataService.snapshot(player) }
	end
	if profile.onboardStep ~= "open" and profile.onboardStep ~= "haven" then
		return { ok = false, error = "Try it in the world first." }
	end
	local saved, err = DataService.mutate(player, function(data)
		if data.onboardStep == "haven" then
			Onboarding.starter(data)
		else
			move(data, data.onboardStep)
		end
		return nil
	end)
	if not saved then
		return { ok = false, error = err or "Could not save." }
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function OnboardingService.skip(player: Player)
	local saved, err = DataService.mutate(player, function(data)
		if data.onboardDone ~= true then
			Onboarding.starter(data)
		end
		FirstSessionKit.grant(data)
		return nil
	end)
	if not saved then
		return { ok = false, error = err or "Could not save." }
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

return OnboardingService
