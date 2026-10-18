--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("Swing accept", function()
	it("plays a slash only in a run and off cooldown", function()
		local stage = fs.readFile(CLIENT .. "CombatStage.luau")
		local swing = between(stage, "function CombatStage.swing", "function CombatStage.dodge")
		local gate = string.find(swing, "if not inRun then", 1, true)
		local cool = string.find(swing, "now < nextSwing", 1, true)
		local slash = string.find(swing, "slash(character, sparks)", 1, true)
		expect(gate ~= nil and cool ~= nil and slash ~= nil).toBeTrue()
		expect((gate :: number) < (slash :: number) and (cool :: number) < (slash :: number)).toBeTrue()
		expect(string.find(swing, "charged == true", 1, true) ~= nil).toBeTrue()
		local dodge = between(stage, "function CombatStage.dodge", "function CombatStage.skill")
		local spend = string.find(dodge, "CombatFeel.tryDodge", 1, true)
		local clip = string.find(dodge, 'playClip(character, "dodge")', 1, true)
		expect(spend ~= nil and clip ~= nil and (spend :: number) < (clip :: number)).toBeTrue()
		expect(string.find(dodge, "if not inRun then", 1, true) ~= nil).toBeTrue()
	end)

	it("slashes on a world click and stays quiet on an empty dodge", function()
		local hud = fs.readFile(CLIENT .. "CombatHud.luau")
		local click = between(hud, "UserInputType.MouseButton1", "end)")
		local stage = string.find(click, "CombatStage.swing(false)", 1, true)
		local send = string.find(click, "CombatHud.swing(false)", 1, true)
		expect(stage ~= nil and send ~= nil and (stage :: number) < (send :: number)).toBeTrue()
		local empty = between(hud, 'payload.kind == "dodge"', 'payload.kind == "kill"')
		local skip = string.find(empty, "charges == 0", 1, true)
		local cue = string.find(empty, "playCue", 1, true)
		expect(skip ~= nil and cue ~= nil and (skip :: number) < (cue :: number)).toBeTrue()
	end)

	it("counts a tutorial swing only when the server releases it", function()
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/CombatService.luau")
		local attack = between(service, "function CombatService.attack", "function CombatService.dodge")
		local released = string.find(attack, "if releaseSwing(", 1, true)
		local note = string.find(attack, 'OnboardingService.note(player, "swing")', 1, true)
		expect(released ~= nil and note ~= nil and (released :: number) < (note :: number)).toBeTrue()
		local limiter = fs.readFile("src/ServerScriptService/ShardfallServer/RateLimiter.luau")
		expect(string.find(limiter, "Attack = { capacity = 16, perSecond = 12 }", 1, true) ~= nil).toBeTrue()
	end)
end)
