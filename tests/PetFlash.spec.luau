--!strict

--[[
	PetFlash is pure and PetAura does not run under Lune. The source
	lock reads PetAura and checks the dodge flash does not key off Q
	and does not return on processed before PetFlash.should.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Keybinds = require("../src/ReplicatedStorage/Shared/Keybinds")
local PetFlash = require("../src/ReplicatedStorage/Shared/PetFlash")

local AURA = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/PetAura.luau"

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("PetFlash", function()
	it("flashes on LeftShift when the effect is flash", function()
		expect(PetFlash.should("LeftShift", "flash")).toBeTrue()
	end)

	it("flashes on the combat dodge bind when the effect is flash", function()
		expect(PetFlash.should(Keybinds.COMBAT.dodge, "flash")).toBeTrue()
	end)

	it("flashes on RightShift when the effect is flash", function()
		expect(PetFlash.should("RightShift", "flash")).toBeTrue()
	end)

	it("does not flash on Q", function()
		expect(PetFlash.should("Q", "flash")).toBeFalse()
	end)

	it("does not flash a collect effect", function()
		expect(PetFlash.should("LeftShift", "collect")).toBeFalse()
		expect(PetFlash.should("RightShift", "collect")).toBeFalse()
	end)

	it("does not flash a ping effect", function()
		expect(PetFlash.should("LeftShift", "ping")).toBeFalse()
	end)

	it("does not flash when the effect is nil", function()
		expect(PetFlash.should("LeftShift", nil)).toBeFalse()
		expect(PetFlash.should("RightShift", nil)).toBeFalse()
	end)

	it("does not flash on ButtonX", function()
		expect(PetFlash.should("ButtonX", "flash")).toBeFalse()
	end)

	it("does not flash any other key or effect", function()
		expect(PetFlash.should("E", "flash")).toBeFalse()
		expect(PetFlash.should("Space", "flash")).toBeFalse()
		expect(PetFlash.should("LeftShift", "glow")).toBeFalse()
		expect(PetFlash.should("LeftShift", "")).toBeFalse()
	end)

	it("ignores a third argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(PetFlash.should("LeftShift", "flash", paid)).toBeTrue()
		expect(PetFlash.should("RightShift", "flash", { paid = true })).toBeTrue()
		expect(PetFlash.should(Keybinds.COMBAT.dodge, "flash", true)).toBeTrue()
		expect(PetFlash.should("Q", "flash", paid)).toBeFalse()
		expect(PetFlash.should("Q", "flash", true)).toBeFalse()
		expect(PetFlash.should("LeftShift", "collect", { paid = true })).toBeFalse()
		expect(PetFlash.should("ButtonX", "flash", { paid = true })).toBeFalse()
	end)

	it("does not write its arguments", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = false }
		table.freeze(paid)
		expect(PetFlash.should("LeftShift", "flash", paid)).toBeTrue()
		expect(PetFlash.should("Q", "flash", paid)).toBeFalse()
		expect(paid.paid).toEqual(true)
		expect(paid.productId).toEqual(0)
		expect(paid.robux).toEqual(0)
		expect(paid.cost).toEqual(0)
		expect(paid.skip).toEqual(false)
	end)

	it("bumps a finite generation by one", function()
		expect(PetFlash.bump(0)).toEqual(1)
		expect(PetFlash.bump(1)).toEqual(2)
		expect(PetFlash.bump(2)).toEqual(3)
		expect(PetFlash.bump(0)).toEqual(1)
	end)

	it("starts a bad generation at 1", function()
		expect(PetFlash.bump(nil)).toEqual(1)
		expect(PetFlash.bump("1")).toEqual(1)
		expect(PetFlash.bump(0 / 0)).toEqual(1)
		expect(PetFlash.bump(true)).toEqual(1)
		expect(PetFlash.bump(false)).toEqual(1)
		expect(PetFlash.bump(math.huge)).toEqual(1)
		expect(PetFlash.bump(-math.huge)).toEqual(1)
	end)

	it("ignores a third argument on bump, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(PetFlash.bump(0, paid)).toEqual(1)
		expect(PetFlash.bump(1, paid)).toEqual(2)
		expect(PetFlash.bump(0, true)).toEqual(1)
		expect(PetFlash.bump(1, { paid = true })).toEqual(2)
	end)

	it("holds only when both tokens are the same finite number", function()
		expect(PetFlash.holds(1, 1)).toBeTrue()
		expect(PetFlash.holds(2, 2)).toBeTrue()
		expect(PetFlash.holds(2, 1)).toBeFalse()
	end)

	it("does not hold nil, a string, NaN, or infinity", function()
		expect(PetFlash.holds(nil, nil)).toBeFalse()
		expect(PetFlash.holds(1, "1")).toBeFalse()
		expect(PetFlash.holds(0 / 0, 0 / 0)).toBeFalse()
		expect(PetFlash.holds(math.huge, math.huge)).toBeFalse()
		expect(PetFlash.holds(-math.huge, -math.huge)).toBeFalse()
		expect(PetFlash.holds(true, true)).toBeFalse()
	end)

	it("ignores a third argument on holds, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(PetFlash.holds(2, 1, paid)).toBeFalse()
		expect(PetFlash.holds(2, 1, true)).toBeFalse()
		expect(PetFlash.holds(2, 2, paid)).toBeTrue()
		expect(PetFlash.holds(1, 1, { paid = true })).toBeTrue()
	end)

	it("does not write bump or holds arguments", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = false }
		local generation = { n = 0, paid = true }
		local token = { n = 1, paid = true }
		table.freeze(paid)
		table.freeze(generation)
		table.freeze(token)
		expect(PetFlash.bump(generation, paid)).toEqual(1)
		expect(PetFlash.bump(0, paid)).toEqual(1)
		expect(PetFlash.holds(generation, token, paid)).toBeFalse()
		expect(PetFlash.holds(2, 2, paid)).toBeTrue()
		expect(paid.paid).toEqual(true)
		expect(paid.productId).toEqual(0)
		expect(paid.robux).toEqual(0)
		expect(paid.cost).toEqual(0)
		expect(paid.skip).toEqual(false)
		expect(generation.n).toEqual(0)
		expect(generation.paid).toEqual(true)
		expect(token.n).toEqual(1)
		expect(token.paid).toEqual(true)
	end)

	it("does not use a clock, rng, or services", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/PetFlash.luau")
		expect(string.find(source, "RightShift", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
	end)
end)

describe("PetAura dodge flash", function()
	it("calls PetFlash and does not return on processed before that call", function()
		local source = fs.readFile(AURA)
		expect(string.find(source, "KeyCode.Q", 1, true)).toBeNil()
		local listener = between(
			source,
			"UserInputService.InputBegan:Connect(function(",
			"RunService.Heartbeat:Connect"
		)
		local call = "PetFlash.should(input.KeyCode.Name, PetRoster.equippedEffect(profile()))"
		expect(string.find(listener, call, 1, true) ~= nil).toBeTrue()
		local callAt = string.find(listener, "PetFlash.should", 1, true)
		expect(callAt ~= nil).toBeTrue()
		local before = string.sub(listener, 1, (callAt :: number) - 1)
		expect(string.find(before, "return", 1, true)).toBeNil()
		expect(string.find(before, "if processed", 1, true)).toBeNil()
		expect(string.find(before, "processed or", 1, true)).toBeNil()
		expect(string.find(before, "processed then", 1, true)).toBeNil()
		expect(string.find(listener, "if processed", 1, true)).toBeNil()
		expect(string.find(listener, "processed or", 1, true)).toBeNil()
		expect(string.find(listener, "processed then", 1, true)).toBeNil()

		local after = string.sub(listener, callAt :: number)
		local returnAt = string.find(after, "return", 1, true)
		local writeAt = string.find(after, "BackgroundTransparency = 0.45", 1, true)
		expect(returnAt ~= nil and writeAt ~= nil).toBeTrue()
		expect((returnAt :: number) < (writeAt :: number)).toBeTrue()
		expect(string.find(listener, "task.delay(0.12", 1, true) ~= nil).toBeTrue()
		expect(string.find(listener, "BackgroundTransparency = 1", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "Color3.fromRGB(186, 230, 255)", 1, true) ~= nil).toBeTrue()
	end)

	it("skips the flash while a text box is focused", function()
		local source = fs.readFile(AURA)
		local listener = between(
			source,
			"UserInputService.InputBegan:Connect(function(",
			"RunService.Heartbeat:Connect"
		)
		local callAt = string.find(listener, "PetFlash.should", 1, true)
		local focus = "GetFocusedTextBox() ~= nil"
		local focusAt = string.find(listener, focus, 1, true)
		local writeAt = string.find(listener, "BackgroundTransparency = 0.45", 1, true)
		expect(callAt ~= nil and focusAt ~= nil and writeAt ~= nil).toBeTrue()
		expect((callAt :: number) < (focusAt :: number)).toBeTrue()
		expect((focusAt :: number) < (writeAt :: number)).toBeTrue()
		local guarded = string.sub(listener, focusAt :: number, (writeAt :: number) - 1)
		expect(string.find(guarded, "return", 1, true) ~= nil).toBeTrue()
		expect(string.find(listener, "if processed", 1, true)).toBeNil()
		expect(string.find(listener, "processed or", 1, true)).toBeNil()
		expect(string.find(listener, "processed then", 1, true)).toBeNil()
	end)

	it("clears the flash only while the bump token still holds", function()
		local source = fs.readFile(AURA)
		local listener = between(
			source,
			"UserInputService.InputBegan:Connect(function(",
			"RunService.Heartbeat:Connect"
		)
		local startAt = string.find(source, "function PetAura.start", 1, true)
		local counterAt = string.find(source, "local generation = 0", 1, true)
		local connectAt =
			string.find(source, "UserInputService.InputBegan:Connect(function(", 1, true)
		expect(startAt ~= nil and counterAt ~= nil and connectAt ~= nil).toBeTrue()
		expect((startAt :: number) < (counterAt :: number)).toBeTrue()
		expect((counterAt :: number) < (connectAt :: number)).toBeTrue()
		expect(string.find(source, "PetAura.generation", 1, true)).toBeNil()

		local focusAt = string.find(listener, "GetFocusedTextBox() ~= nil", 1, true)
		local bumpAt = string.find(listener, "generation = PetFlash.bump(generation)", 1, true)
		local writeAt = string.find(listener, "BackgroundTransparency = 0.45", 1, true)
		local delayAt = string.find(listener, "task.delay(0.12", 1, true)
		local holdsAt = string.find(listener, "PetFlash.holds(generation, token)", 1, true)
		local clearAt = string.find(listener, "BackgroundTransparency = 1", 1, true)
		expect(focusAt ~= nil and bumpAt ~= nil and writeAt ~= nil).toBeTrue()
		expect(delayAt ~= nil and holdsAt ~= nil and clearAt ~= nil).toBeTrue()
		expect((focusAt :: number) < (bumpAt :: number)).toBeTrue()
		expect((bumpAt :: number) < (writeAt :: number)).toBeTrue()
		expect((writeAt :: number) < (delayAt :: number)).toBeTrue()
		expect((delayAt :: number) < (holdsAt :: number)).toBeTrue()
		expect((holdsAt :: number) < (clearAt :: number)).toBeTrue()
		local guarded = string.sub(listener, holdsAt :: number, (clearAt :: number) - 1)
		expect(string.find(guarded, "return", 1, true) ~= nil).toBeTrue()
		expect(string.find(listener, "task.cancel", 1, true)).toBeNil()
		expect(string.find(source, "KeyCode.Q", 1, true)).toBeNil()
		expect(string.find(listener, "if processed", 1, true)).toBeNil()
		expect(string.find(listener, "processed or", 1, true)).toBeNil()
		expect(string.find(listener, "processed then", 1, true)).toBeNil()
		local shouldAt = string.find(listener, "PetFlash.should", 1, true)
		expect(shouldAt ~= nil).toBeTrue()
		expect((shouldAt :: number) < (focusAt :: number)).toBeTrue()
		local beforeShould = string.sub(listener, 1, (shouldAt :: number) - 1)
		expect(string.find(beforeShould, "return", 1, true)).toBeNil()
	end)
end)
