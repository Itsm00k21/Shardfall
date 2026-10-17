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
end)
