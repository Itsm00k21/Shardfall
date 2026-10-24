--!strict

--[[
	Classes parked: the cold open must not stop on the class card.
	Flag on, that card is still the step a class pick advances.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Onboarding = require("../src/ReplicatedStorage/Shared/Onboarding")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local OnboardingService = require("../src/ServerScriptService/ShardfallServer/OnboardingService")

local function profile(step: string)
	local data = Schema.template()
	data.onboardStep = step
	data.onboardDone = false
	return data
end

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

local function withClasses(run: () -> ())
	local previous = LaunchGate.SHOW.classes
	LaunchGate.SHOW.classes = true
	local ok, err = pcall(run)
	LaunchGate.SHOW.classes = previous
	if not ok then
		error(err, 0)
	end
end

describe("Class step skip", function()
	it("skips the class card while classes are off", function()
		expect(LaunchGate.SHOW.classes).toEqual(false)
		expect(LaunchGate.on("classes")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		-- The shared list still names the card. The server is what walks past it.
		expect(Onboarding.next("open")).toEqual("class")
		expect(Onboarding.next("class")).toEqual("swing")

		local data = profile("open")
		local gold = data.gold
		local tokens = data.shardTokens
		local keys = data.shardKeys
		local proceeded, why = OnboardingService.applyAdvance(data)
		expect(proceeded).toEqual(true)
		expect(why).toBeNil()
		expect(data.onboardStep).toEqual("swing")
		expect(data.onboardDone).toEqual(false)
		expect(data.gold).toEqual(gold)
		expect(data.shardTokens).toEqual(tokens)
		expect(data.shardKeys).toEqual(keys)

		OnboardingService.applyNote(data, "swing")
		expect(data.onboardStep).toEqual("dodge")
		expect(data.onboardDone).toEqual(false)
		expect(data.gold).toEqual(gold)

		local stuck = profile("class")
		local stayed, blocked = OnboardingService.applyAdvance(stuck)
		expect(stayed).toEqual(false)
		expect(blocked).toEqual("Try it in the world first.")
		expect(stuck.onboardStep).toEqual("class")
		expect(OnboardingService.skipParkedClass(stuck)).toEqual(true)
		expect(stuck.onboardStep).toEqual("swing")
		expect(stuck.onboardDone).toEqual(false)
		expect(stuck.gold).toEqual(gold)
		expect(stuck.shardTokens).toEqual(tokens)
		expect(stuck.shardKeys).toEqual(keys)
		expect(OnboardingService.skipParkedClass(stuck)).toEqual(false)
		expect(stuck.onboardStep).toEqual("swing")

		local noted = profile("class")
		OnboardingService.applyNote(noted, "class")
		expect(noted.onboardStep).toEqual("swing")
		expect(noted.onboardDone).toEqual(false)
		expect(noted.gold).toEqual(gold)

		local done = profile("class")
		done.onboardDone = true
		expect(OnboardingService.skipParkedClass(done)).toEqual(false)
		expect(done.onboardStep).toEqual("class")
		expect(done.onboardDone).toEqual(true)
		expect(OnboardingService.skipParkedClass(profile("swing"))).toEqual(false)
		expect(OnboardingService.skipParkedClass(profile("open"))).toEqual(false)

		local service = fs.readFile("src/ServerScriptService/ShardfallServer/OnboardingService.luau")
		local start = between(service, "function OnboardingService.start", "RunService.Heartbeat")
		local gate = string.find(start, 'LaunchGate.on("classes")', 1, true)
		local skip = string.find(start, "skipParkedClass(data)", 1, true)
		expect(gate ~= nil and skip ~= nil).toBeTrue()
		expect((gate :: number) < (skip :: number)).toBeTrue()
	end)

	it("keeps the class card while classes are on", function()
		expect(Schema.VERSION).toEqual(26)
		withClasses(function()
			expect(LaunchGate.on("classes")).toEqual(true)
			local data = profile("open")
			local gold = data.gold
			local tokens = data.shardTokens
			local keys = data.shardKeys
			local proceeded, why = OnboardingService.applyAdvance(data)
			expect(proceeded).toEqual(true)
			expect(why).toBeNil()
			expect(data.onboardStep).toEqual("class")
			expect(data.onboardDone).toEqual(false)
			expect(data.gold).toEqual(gold)
			expect(data.shardTokens).toEqual(tokens)
			expect(data.shardKeys).toEqual(keys)

			local stayed, blocked = OnboardingService.applyAdvance(data)
			expect(stayed).toEqual(false)
			expect(blocked).toEqual("Try it in the world first.")
			expect(data.onboardStep).toEqual("class")
			expect(OnboardingService.skipParkedClass(data)).toEqual(false)
			expect(data.onboardStep).toEqual("class")
			expect(data.gold).toEqual(gold)

			OnboardingService.applyNote(data, "class")
			expect(data.onboardStep).toEqual("swing")
			expect(data.onboardDone).toEqual(false)
			expect(data.gold).toEqual(gold)
			expect(data.shardTokens).toEqual(tokens)
			OnboardingService.applyNote(data, "class")
			expect(data.onboardStep).toEqual("swing")
			OnboardingService.applyNote(data, "swing")
			expect(data.onboardStep).toEqual("dodge")
			expect(data.onboardDone).toEqual(false)
			expect(data.gold).toEqual(gold)
		end)
		expect(LaunchGate.SHOW.classes).toEqual(false)
		expect(LaunchGate.on("classes")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
	end)
end)
