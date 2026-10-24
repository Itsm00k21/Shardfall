--!strict

--[[
	Havoc audit of #454 (Ghost DP31). One probe per fix.

	P2-454-1  Flag off: advance treats a saved guide step as open, and
	          Skip pays that step's token count once.
	P3-454-2  The open step owes 3 tokens on Skip while the flag is on.
	P3-454-3  x10 is refused on roll steps 1-3 with the free-roll notice.
	P3-454-4  The gate pad is checked at about 5 Hz.
	P2-457-1  Flag off: a fresh open step owes 0 tokens on Skip.
	          roll1, roll2, and roll3 stay 3, 2, and 1.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionGuide = require("../src/ReplicatedStorage/Shared/SessionGuide")
local OnboardingService = require("../src/ServerScriptService/ShardfallServer/OnboardingService")

local GUIDE_STEPS = { "open", "roll1", "roll2", "roll3", "gate", "wave1" }

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

local function stepRow(id: string): any
	for _, row in ipairs(SessionGuide.steps()) do
		if row.id == id then
			return row
		end
	end
	error("missing step " .. id, 0)
end

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("Guide hardening", function()
	it("P2-454-1 resumes a rolled-back guide step as open and Skip pays that step once", function()
		expect(LaunchGate.SHOW.firstSessionGuide).toEqual(false)
		expect(LaunchGate.SHOW.classes).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/OnboardingService.luau")
		local advance = between(service, "function OnboardingService.advance", "function OnboardingService.applySkip")
		expect(string.find(advance, "applyAdvance(data)", 1, true) ~= nil).toBeTrue()
		expect(string.find(advance, 'profile.onboardStep ~= "open"', 1, true)).toBeNil()

		for _, id in ipairs(GUIDE_STEPS) do
			local data = profile(id)
			local tokens = data.shardTokens
			local gold = data.gold
			local proceeded, why = OnboardingService.applyAdvance(data)
			expect(proceeded).toEqual(true)
			expect(why).toBeNil()
			-- classes is off, so the cold open walks past the class card.
			expect(data.onboardStep).toEqual("swing")
			expect(data.onboardDone).toEqual(false)
			expect(data.shardTokens).toEqual(tokens)
			expect(data.gold).toEqual(gold)
		end

		local legacy = profile("class")
		local stayed, blocked = OnboardingService.applyAdvance(legacy)
		expect(stayed).toEqual(false)
		expect(blocked).toEqual("Try it in the world first.")
		expect(legacy.onboardStep).toEqual("class")
		expect(legacy.onboardDone).toEqual(false)

		local finished = profile("haven")
		local havenGold = finished.gold
		local havenOk = OnboardingService.applyAdvance(finished)
		expect(havenOk).toEqual(true)
		expect(finished.onboardDone).toEqual(true)
		expect(finished.gold).toEqual(havenGold + 250)

		local function payOnce(stepId: string)
			local row = stepRow(stepId)
			local data = profile(stepId)
			local tokens = data.shardTokens
			expect(SessionGuide.claimFree(data)).toBeNil()
			expect(data.onboardStep).toEqual(stepId)
			expect(SessionGuide.unusedRollTokens(data)).toEqual(row.tokens)
			OnboardingService.applySkip(data)
			expect(data.shardTokens).toEqual(tokens + row.tokens)
			expect(data.onboardDone).toEqual(true)
			OnboardingService.applySkip(data)
			expect(data.shardTokens).toEqual(tokens + row.tokens)
			expect(SessionGuide.grantTokens(data, row.tokens)).toEqual(0)
		end

		expect(stepRow("roll1").tokens).toEqual(3)
		expect(stepRow("roll2").tokens).toEqual(2)
		expect(stepRow("roll3").tokens).toEqual(1)
		expect(stepRow("gate").tokens).toEqual(0)
		expect(stepRow("wave1").tokens).toEqual(0)
		payOnce("roll1")
		payOnce("roll2")
		payOnce("roll3")
		payOnce("gate")
		payOnce("wave1")

		withGuide(function()
			local guided = profile("roll2")
			local tokens = guided.shardTokens
			local refused, why = OnboardingService.applyAdvance(guided)
			expect(refused).toEqual(false)
			expect(why).toEqual("Try it in the world first.")
			expect(guided.onboardStep).toEqual("roll2")
			expect(guided.shardTokens).toEqual(tokens)
			OnboardingService.applySkip(guided)
			expect(guided.shardTokens).toEqual(tokens + stepRow("roll2").tokens)
			OnboardingService.applySkip(guided)
			expect(guided.shardTokens).toEqual(tokens + stepRow("roll2").tokens)
		end)
	end)

	it("fresh template, flag off, applySkip -> tokens +0", function()
		expect(LaunchGate.SHOW.firstSessionGuide).toEqual(false)
		expect(LaunchGate.on("firstSessionGuide")).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		local data = Schema.template()
		expect(data.onboardStep).toEqual("open")
		expect(data.onboardDone).toEqual(false)
		local tokens = data.shardTokens
		expect(tokens).toEqual(Schema.STARTER_TOKENS)
		expect(SessionGuide.unusedRollTokens(data)).toEqual(0)
		OnboardingService.applySkip(data)
		expect(data.shardTokens).toEqual(tokens + 0)
		expect(data.onboardDone).toEqual(true)
		expect(data.onboardStep).toEqual("haven")
		expect(stepRow("roll1").tokens).toEqual(3)
		expect(stepRow("roll2").tokens).toEqual(2)
		expect(stepRow("roll3").tokens).toEqual(1)
	end)

	it("P3-454-2 the open step owes 3 tokens on Skip", function()
		local openRow = stepRow("open")
		expect(openRow.tokens).toEqual(3)
		expect(openRow.tokens).toEqual(SessionGuide.TIMING.freeRolls)
		expect(LaunchGate.on("firstSessionGuide")).toEqual(false)
		local data = profile("open")
		local tokens = data.shardTokens
		expect(SessionGuide.unusedRollTokens(data)).toEqual(0)
		OnboardingService.applySkip(data)
		expect(data.shardTokens).toEqual(tokens + 0)
		expect(data.onboardDone).toEqual(true)
		OnboardingService.applySkip(data)
		expect(data.shardTokens).toEqual(tokens + 0)

		withGuide(function()
			local guided = profile("open")
			local base = guided.shardTokens
			expect(SessionGuide.unusedRollTokens(guided)).toEqual(openRow.tokens)
			OnboardingService.applySkip(guided)
			expect(guided.shardTokens).toEqual(base + 3)
			OnboardingService.applySkip(guided)
			expect(guided.shardTokens).toEqual(base + 3)
			expect(SessionGuide.claimFree(guided)).toBeNil()
		end)
	end)

	it("P3-454-3 blocks an x10 roll on guide steps 1-3 with the free-roll notice", function()
		expect(SessionGuide.FREE_ROLL_NOTICE).toEqual("use your free roll")
		expect(LaunchGate.SHOW.firstSessionGuide).toEqual(false)
		expect(SessionGuide.batchNotice(profile("roll1"))).toBeNil()
		withGuide(function()
			for _, id in ipairs({ "roll1", "roll2", "roll3" }) do
				local row = stepRow(id)
				expect(row.free).toEqual(true)
				expect(SessionGuide.batchNotice(profile(id))).toEqual(SessionGuide.FREE_ROLL_NOTICE)
			end
			for _, id in ipairs({ "open", "gate", "wave1" }) do
				expect(SessionGuide.batchNotice(profile(id))).toBeNil()
			end
			local done = profile("roll2")
			done.onboardDone = true
			expect(SessionGuide.batchNotice(done)).toBeNil()
		end)

		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		local batch = between(roll, "local function crackBatch", "function RollService.rollMany")
		local guard = string.find(batch, "SessionGuide.batchNotice(data)", 1, true)
		local spend = string.find(batch, "data.shardTokens -= price", 1, true)
		expect(guard ~= nil and spend ~= nil).toBeTrue()
		expect((guard :: number) < (spend :: number)).toBeTrue()
		local many = between(roll, "function RollService.rollMany", "function RollService.rollPaid")
		local noted = string.find(many, "notice = note", 1, true)
		local multi = string.find(many, "RollConfig.MULTI_COUNT", 1, true)
		expect(noted ~= nil and multi ~= nil).toBeTrue()
		expect((multi :: number) < (noted :: number)).toBeTrue()
		local menu = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local onboard = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/OnboardHud.luau")
		expect(string.find(menu, "use your free roll", 1, true)).toBeNil()
		expect(string.find(onboard, "use your free roll", 1, true)).toBeNil()
	end)

	it("P3-454-4 checks the gate pad at about 5 Hz", function()
		expect(SessionGuide.PAD_HZ).toEqual(5)
		local interval = 1 / SessionGuide.PAD_HZ
		local carry, due = SessionGuide.padClock(0, interval / 2)
		expect(due).toEqual(false)
		carry, due = SessionGuide.padClock(carry, interval / 2)
		expect(due).toEqual(true)
		carry = 0
		local fires = 0
		for _ = 1, SessionGuide.PAD_HZ do
			carry, due = SessionGuide.padClock(carry, interval)
			if due then
				fires += 1
			end
		end
		expect(fires).toEqual(SessionGuide.PAD_HZ)
		local _, frame = SessionGuide.padClock(0, 1 / 60)
		expect(frame).toEqual(false)

		local service = fs.readFile("src/ServerScriptService/ShardfallServer/OnboardingService.luau")
		local start = between(service, "function OnboardingService.start", "return OnboardingService")
		local flag = string.find(start, 'LaunchGate.on("firstSessionGuide")', 1, true)
		local clock = string.find(start, "SessionGuide.padClock", 1, true)
		local beat = string.find(start, "Heartbeat:Connect", 1, true)
		expect(flag ~= nil and clock ~= nil and beat ~= nil).toBeTrue()
		expect((beat :: number) < (flag :: number)).toBeTrue()
		expect((flag :: number) < (clock :: number)).toBeTrue()
	end)
end)
