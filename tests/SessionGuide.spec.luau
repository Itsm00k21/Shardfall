--!strict

--[[
	T3 first-session guide, server side.

	The flag ships off. Skip and Replay never pay twice. A rejoin resumes
	the saved step. A burst of Skip in one moment pays once.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local FirstSession = require("../src/ReplicatedStorage/Shared/FirstSession")
local FirstSessionKit = require("../src/ReplicatedStorage/Shared/FirstSessionKit")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Onboarding = require("../src/ReplicatedStorage/Shared/Onboarding")
local RollConfig = require("../src/ReplicatedStorage/Shared/RollConfig")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionGuide = require("../src/ReplicatedStorage/Shared/SessionGuide")
local OnboardingService = require("../src/ServerScriptService/ShardfallServer/OnboardingService")

local function withGuide(run: () -> ())
	local previous = LaunchGate.SHOW.firstSessionGuide
	LaunchGate.SHOW.firstSessionGuide = true
	local ok, err = pcall(run)
	LaunchGate.SHOW.firstSessionGuide = previous
	if not ok then
		error(err, 0)
	end
end

local function profile(step: string)
	local data = Schema.template()
	data.onboardStep = step
	data.onboardDone = false
	return data
end

local function tonic(data): number
	if type(data.consumables) ~= "table" then
		return 0
	end
	local count = data.consumables.healing_tonic
	if type(count) ~= "number" then
		return 0
	end
	return count
end

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("Session guide", function()
	it("validates the config and rejects a tampered copy", function()
		local ok, err = SessionGuide.validate()
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(LaunchGate.SHOW.firstSessionGuide).toEqual(false)
		expect(Schema.VERSION).toEqual(26)

		local steps = {}
		for _, row in ipairs(SessionGuide.steps()) do
			local clone = {}
			for key, value in pairs(row) do
				clone[key] = value
			end
			table.insert(steps, clone)
		end
		steps[2].tokens = 9
		local broken, why = SessionGuide.check({
			steps = steps,
			timing = SessionGuide.TIMING,
		})
		expect(broken).toEqual(false)
		expect(why).toEqual("tokens")
		steps[2].tokens = 3
		steps[2].productId = 1
		local robbed, robux = SessionGuide.check({
			steps = steps,
			timing = SessionGuide.TIMING,
		})
		expect(robbed).toEqual(false)
		expect(robux).toEqual("robux")
	end)

	it("keeps the cold open while the flag is off", function()
		expect(LaunchGate.on("firstSessionGuide")).toEqual(false)
		expect(Onboarding.next("open")).toEqual("class")
		expect(Onboarding.pillText("class")).toEqual("Shardfall: Choose a class")
		local data = profile("roll1")
		local gold = data.gold
		local tokens = data.shardTokens
		expect(SessionGuide.claimFree(data)).toBeNil()
		expect(SessionGuide.unusedRollTokens(data)).toEqual(0)
		expect(SessionGuide.advancePad(data, 0, 120.5, 46)).toEqual(false)
		expect(SessionGuide.replay(data)).toEqual(false)
		OnboardingService.replay({} :: any)
		expect(data.onboardStep).toEqual("roll1")
		expect(data.onboardDone).toEqual(false)
		expect(data.gold).toEqual(gold)
		expect(data.shardTokens).toEqual(tokens)
		OnboardingService.applySkip(data)
		expect(data.shardTokens).toEqual(tokens)
		expect(data.onboardDone).toEqual(true)
		expect(data.gold).toEqual(gold + 250)
	end)

	it("walks the guide steps and the Wren pill when the flag is on", function()
		withGuide(function()
			expect(Onboarding.next("open")).toEqual("roll1")
			expect(Onboarding.next("roll1")).toEqual("roll2")
			expect(Onboarding.next("roll2")).toEqual("roll3")
			expect(Onboarding.next("roll3")).toEqual("gate")
			expect(Onboarding.next("gate")).toEqual("wave1")
			expect(Onboarding.next("wave1")).toBeNil()
			expect(Onboarding.next("class")).toEqual("swing")
			expect(Onboarding.pillText("roll1")).toEqual("Wren: Crack a shard")
			expect(Onboarding.pillText("gate")).toEqual("Wren: Follow the arrow")
			local goals = Onboarding.goals("roll2")
			expect(#goals).toEqual(5)
			expect(goals[1].text).toEqual("Crack shard 1")
			expect(goals[1].done).toEqual(true)
			expect(goals[2].id).toEqual("roll2")
			expect(goals[2].done).toEqual(false)
			expect(goals[4].text).toEqual("Step on the Gate")
			local done, total = Onboarding.goalCount(Onboarding.goals("wave1"))
			expect(total).toEqual(5)
			expect(done).toEqual(4)
			local fresh = profile("open")
			OnboardingService.applyNote(fresh, "open")
			expect(fresh.onboardStep).toEqual("roll1")
			expect(fresh.onboardDone).toEqual(false)
			expect(fresh.gold).toEqual(0)
		end)
	end)

	it("pays Skip once, then Replay and more Skips add nothing", function()
		withGuide(function()
			local data = profile("roll2")
			data.classId = "warden"
			local tokens = data.shardTokens
			OnboardingService.applySkip(data)
			expect(data.shardTokens).toEqual(tokens + 2)
			expect(data.gold).toEqual(250)
			expect(data.shardKeys).toEqual(40)
			expect(tonic(data)).toEqual(3)
			expect(data.onboardDone).toEqual(true)
			expect(data.onboardStep).toEqual("haven")
			expect(Schema.countItems(data)).toEqual(2)
			expect(#data.companions).toEqual(1)
			OnboardingService.replay({} :: any)
			SessionGuide.replay(data)
			expect(SessionGuide.claimFree(data)).toBeNil()
			for _ = 1, 5 do
				OnboardingService.applySkip(data)
				OnboardingService.replay({} :: any)
			end
			expect(data.shardTokens).toEqual(tokens + 2)
			expect(data.gold).toEqual(250)
			expect(data.shardKeys).toEqual(40)
			expect(tonic(data)).toEqual(3)
			expect(Schema.countItems(data)).toEqual(2)
			expect(#data.companions).toEqual(1)
			expect(SessionGuide.grantTokens(data, 3)).toEqual(0)
		end)
	end)

	it("treats a burst of Skip as one grant", function()
		withGuide(function()
			local data = profile("roll2")
			data.classId = "warden"
			local tokens = data.shardTokens
			for _ = 1, 25 do
				OnboardingService.applySkip(data)
			end
			expect(data.shardTokens).toEqual(tokens + 2)
			expect(data.gold).toEqual(250)
			expect(data.shardKeys).toEqual(40)
			expect(tonic(data)).toEqual(3)
			expect(Schema.countItems(data)).toEqual(2)
			expect(data.onboardDone).toEqual(true)
		end)
	end)

	it("resumes a rejoin on the saved step without repeating a resolved roll", function()
		withGuide(function()
			local data = profile("roll1")
			local first = SessionGuide.claimFree(data)
			expect(first ~= nil).toBeTrue()
			expect((first :: any).stepId).toEqual("roll1")
			expect((first :: any).floor).toBeNil()
			expect(data.onboardStep).toEqual("roll2")
			expect(data.firstSession.granted.roll).toEqual(false)
			local saved = Schema.deepCopy(data)
			local resumed = Schema.deepCopy(saved)
			local second = SessionGuide.claimFree(resumed)
			expect(second ~= nil).toBeTrue()
			expect((second :: any).stepId).toEqual("roll2")
			expect(resumed.onboardStep).toEqual("roll3")
			local other = Schema.deepCopy(saved)
			expect((SessionGuide.claimFree(other) :: any).stepId).toEqual("roll2")
			local paying = Schema.deepCopy(saved)
			local tokens = paying.shardTokens
			OnboardingService.applySkip(paying)
			expect(paying.shardTokens).toEqual(tokens + 2)
			expect(paying.gold).toEqual(250)
			OnboardingService.applySkip(paying)
			OnboardingService.replay({} :: any)
			expect(paying.shardTokens).toEqual(tokens + 2)
			expect(paying.gold).toEqual(250)
			expect(paying.shardKeys).toEqual(40)
			expect(tonic(paying)).toEqual(3)
		end)
	end)

	it("refuses a second rollFree in the same moment and never repeats roll1", function()
		withGuide(function()
			local data = profile("roll1")
			local tokens = data.shardTokens
			local now = 50
			local previous: number? = nil
			local function roll(at: number): string
				if previous ~= nil and at - (previous :: number) < RollConfig.COOLDOWN then
					return "refused"
				end
				local seen = data.onboardStep
				local claim = SessionGuide.claimFree(data)
				if data.onboardStep == seen and claim ~= nil then
					error("claimFree returned without moving the step", 0)
				end
				previous = at
				if claim ~= nil then
					return "free"
				end
				data.shardTokens -= 1
				return "paid"
			end
			expect(roll(now)).toEqual("free")
			expect(roll(now)).toEqual("refused")
			expect(data.onboardStep).toEqual("roll2")
			expect(data.shardTokens).toEqual(tokens)
			expect(roll(now + 1)).toEqual("free")
			expect(data.onboardStep).toEqual("roll3")
			expect(roll(now + 2)).toEqual("free")
			expect(data.onboardStep).toEqual("gate")
			expect(SessionGuide.claimFree(data)).toBeNil()
			expect(data.onboardStep).toEqual("gate")
			-- The three guide rolls are spent. The next crack pays a token.
			expect(roll(now + 3)).toEqual("paid")
			expect(data.onboardStep).toEqual("gate")
			expect(data.shardTokens).toEqual(tokens - 1)
			local stuck = profile("roll1")
			OnboardingService.applyNote(stuck, "roll1")
			expect(stuck.onboardStep).toEqual("roll1")
		end)
	end)

	it("floors only the roll that leaves roll3 and does not floor a finished profile", function()
		withGuide(function()
			expect(SessionGuide.floorRarity("Common", "Rare")).toEqual("Rare")
			expect(SessionGuide.floorRarity("Epic", "Rare")).toEqual("Epic")
			expect(SessionGuide.floorRarity("Legendary", "Rare")).toEqual("Legendary")
			expect(SessionGuide.floorRarity("Common", nil)).toEqual("Common")
			local data = profile("roll3")
			local claim = SessionGuide.claimFree(data)
			expect(claim ~= nil).toBeTrue()
			expect((claim :: any).floor).toEqual("Rare")
			expect(data.onboardStep).toEqual("gate")
			expect(data.firstSession.granted.roll).toEqual(true)
			local again = SessionGuide.claimFree(data)
			expect(again).toBeNil()
			local state = data.firstSession
			expect(FirstSession.applies(state, "roll", nil).applies).toEqual(false)
			local done = profile("haven")
			done.onboardDone = true
			done.shardTokens = 4
			expect(SessionGuide.claimFree(done)).toBeNil()
			expect(SessionGuide.unusedRollTokens(done)).toEqual(0)
			done.shardTokens -= 1
			expect(done.shardTokens).toEqual(3)
			expect(done.onboardStep).toEqual("haven")
			expect(done.onboardDone).toEqual(true)
		end)
	end)

	it("pays no tokens for Skip at wave1 and finishes that step once", function()
		withGuide(function()
			local data = profile("wave1")
			local tokens = data.shardTokens
			OnboardingService.applySkip(data)
			expect(data.shardTokens).toEqual(tokens)
			expect(data.gold).toEqual(250)
			expect(data.shardKeys).toEqual(40)
			expect(tonic(data)).toEqual(3)
			OnboardingService.applySkip(data)
			expect(data.gold).toEqual(250)
			expect(data.shardTokens).toEqual(tokens)

			local clear = profile("wave1")
			OnboardingService.applyNote(clear, "wave1")
			expect(clear.onboardDone).toEqual(true)
			expect(clear.gold).toEqual(250)
			expect(clear.shardTokens).toEqual(tokens)
			OnboardingService.applyNote(clear, "wave1")
			expect(clear.gold).toEqual(250)
			expect(clear.shardTokens).toEqual(tokens)
		end)
	end)

	it("lets the kit wait for a class and pays that kit once", function()
		withGuide(function()
			local data = profile("roll1")
			expect(data.classId).toEqual("")
			OnboardingService.applySkip(data)
			expect(data.shardTokens).toEqual(Schema.STARTER_TOKENS + 3)
			expect(Schema.countItems(data)).toEqual(0)
			expect(data.firstSession.granted.chest).toEqual(false)
			data.classId = "warden"
			local paid = FirstSessionKit.grant(data)
			expect(paid.accepted).toEqual(true)
			expect(Schema.countItems(data)).toEqual(2)
			local again = FirstSessionKit.grant(data)
			expect(again.accepted).toEqual(false)
			OnboardingService.applyNote(data, "class")
			expect(Schema.countItems(data)).toEqual(2)
			expect(#data.companions).toEqual(1)
		end)
	end)

	it("advances the gate only from a server pad hit", function()
		withGuide(function()
			local data = profile("gate")
			local tokens = data.shardTokens
			expect(SessionGuide.advancePad(data, 0, 120.5, 30)).toEqual(false)
			expect(data.onboardStep).toEqual("gate")
			expect(SessionGuide.advancePad(data, 100, 120.5, 46)).toEqual(false)
			expect(SessionGuide.advancePad(data, 0, 120.5, 46)).toEqual(true)
			expect(data.onboardStep).toEqual("wave1")
			expect(data.gold).toEqual(0)
			expect(data.shardTokens).toEqual(tokens)
			expect(SessionGuide.advancePad(data, 0, 120.5, 46)).toEqual(false)
			expect(data.onboardStep).toEqual("wave1")
		end)
	end)

	it("wires the grant rules into skip, crack, and the pad", function()
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/OnboardingService.luau")
		local skip = between(service, "function OnboardingService.applySkip", "function OnboardingService.skip")
		local guard = string.find(skip, "if data.onboardDone ~= true then", 1, true)
		local owed = string.find(skip, "SessionGuide.unusedRollTokens(data)", 1, true)
		local pay = string.find(skip, "SessionGuide.grantTokens(data, tokens)", 1, true)
		local starter = string.find(skip, "Onboarding.starter(data)", 1, true)
		local kit = string.find(skip, "FirstSessionKit.grant(data)", 1, true)
		expect(guard ~= nil and owed ~= nil and pay ~= nil and starter ~= nil and kit ~= nil).toBeTrue()
		expect((guard :: number) < (owed :: number)).toBeTrue()
		expect((owed :: number) < (pay :: number)).toBeTrue()
		expect((pay :: number) < (starter :: number)).toBeTrue()
		expect((starter :: number) < (kit :: number)).toBeTrue()
		expect(string.find(service, "grantKit(data)", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "classId", 1, true)).toBeNil()
		local replay = between(service, "function OnboardingService.replay", "function OnboardingService.touch")
		expect(string.find(replay, "DataService", 1, true)).toBeNil()
		expect(string.find(replay, "starter", 1, true)).toBeNil()
		expect(string.find(replay, "grantTokens", 1, true)).toBeNil()
		local touch = between(service, "function OnboardingService.touch", "function OnboardingService.start")
		local closed = string.find(touch, 'LaunchGate.on("firstSessionGuide")', 1, true)
		local mutate = string.find(touch, "dataService().mutate", 1, true)
		expect(closed ~= nil and mutate ~= nil and (closed :: number) < (mutate :: number)).toBeTrue()

		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		local crack = between(roll, "local function crack(", "function RollService.rollFree")
		local cool = string.find(crack, "Roll cooling down.", 1, true)
		local crackMutate = string.find(crack, "DataService.mutate(player, function(data)", 1, true)
		local claim = string.find(crack, "SessionGuide.claimFree(data)", 1, true)
		local shard = string.find(crack, "currency == Currencies.SHARD", 1, true)
		local take = string.find(crack, "Currencies.take(data, currency)", 1, true)
		expect(cool ~= nil and crackMutate ~= nil and claim ~= nil and take ~= nil and shard ~= nil).toBeTrue()
		expect((cool :: number) < (crackMutate :: number)).toBeTrue()
		expect((crackMutate :: number) < (shard :: number)).toBeTrue()
		expect((shard :: number) < (claim :: number)).toBeTrue()
		expect((claim :: number) < (take :: number)).toBeTrue()
		expect(string.find(crack, "claimFree(data,", 1, true)).toBeNil()
		expect(string.find(crack, "tutorial", 1, true)).toBeNil()
		expect(string.find(crack, "freeCount", 1, true)).toBeNil()
		expect(string.find(crack, "replay", 1, true)).toBeNil()
		local _, claims = string.gsub(roll, "SessionGuide%.claimFree%(", "")
		expect(claims).toEqual(1)
		local free = between(roll, "function RollService.rollFree", "local function pityView")
		expect(string.find(free, "return crack(player, poolId, Currencies.SHARD, skip == true)", 1, true) ~= nil).toBeTrue()
		expect(string.find(free, "tutorial", 1, true)).toBeNil()

		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local onboard = between(remotes, 'functionRemote("Onboard")', 'functionRemote("SetClass")')
		local skipAt = string.find(onboard, "OnboardingService.skip(player)", 1, true)
		local replayAt = string.find(onboard, 'action == "replay"', 1, true)
		local advanceAt = string.find(onboard, "OnboardingService.advance(player)", 1, true)
		expect(skipAt ~= nil and replayAt ~= nil and advanceAt ~= nil).toBeTrue()
		expect((skipAt :: number) < (replayAt :: number)).toBeTrue()
		expect((replayAt :: number) < (advanceAt :: number)).toBeTrue()

		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		local wave = string.find(host, 'LaunchGate.on("firstSessionGuide")', 1, true)
		local clear = string.find(host, 'event.wave == 1', 1, true)
		local noted = string.find(host, 'OnboardingService.note(player, "wave1")', 1, true)
		expect(wave ~= nil and clear ~= nil and noted ~= nil).toBeTrue()
		expect((wave :: number) < (clear :: number) and (clear :: number) < (noted :: number)).toBeTrue()

		local gate = fs.readFile("src/ReplicatedStorage/Shared/LaunchGate.luau")
		expect(string.find(gate, "firstSessionGuide = false", 1, true) ~= nil).toBeTrue()
	end)
end)
