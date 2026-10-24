--!strict

--[[
	HeroView is pure and MenuHub does not run under Lune. The source
	lock reads the hero avatar spawn and checks the rig is requested
	before the model is built, a cleared viewport destroys that model,
	and a live viewport still parents it.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local HeroView = require("../src/ReplicatedStorage/Shared/HeroView")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("HeroView", function()
	it("requests R6 and R15 by name", function()
		expect(HeroView.rig("R6")).toEqual("R6")
		expect(HeroView.rig("R15")).toEqual("R15")
	end)

	it("falls back to R15 for a missing, blank, or other name", function()
		expect(HeroView.rig(nil)).toEqual("R15")
		expect(HeroView.rig("")).toEqual("R15")
		expect(HeroView.rig("Rthro")).toEqual("R15")
		expect(HeroView.rig(true)).toEqual("R15")
		expect(HeroView.rig(false)).toEqual("R15")
		expect(HeroView.rig("r6")).toEqual("R15")
	end)

	it("ignores a second argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(HeroView.rig("R6", paid)).toEqual("R6")
		expect(HeroView.rig("R6", true)).toEqual("R6")
		expect(HeroView.rig(nil, paid)).toEqual("R15")
		expect(HeroView.rig(nil, true)).toEqual("R15")
		expect(HeroView.rig("R15", { paid = true })).toEqual("R15")
	end)

	it("parents a built model in a live viewport", function()
		expect(HeroView.place(true, true, true)).toEqual("parent")
	end)

	it("destroys a built model when the viewport is gone", function()
		expect(HeroView.place(true, true, false)).toEqual("destroy")
		expect(HeroView.place(true, true, nil)).toEqual("destroy")
		expect(HeroView.place(true, true, 1)).toEqual("destroy")
		expect(HeroView.place(true, true, "true")).toEqual("destroy")
	end)

	it("skips a failed build or a missing model", function()
		expect(HeroView.place(false, true, true)).toEqual("skip")
		expect(HeroView.place(true, false, false)).toEqual("skip")
		expect(HeroView.place(false, true, false)).toEqual("skip")
		expect(HeroView.place(true, false, true)).toEqual("skip")
		expect(HeroView.place("true", "true", "true")).toEqual("skip")
	end)

	it("ignores a fourth argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(HeroView.place(true, true, false, paid)).toEqual("destroy")
		expect(HeroView.place(true, true, false, true)).toEqual("destroy")
		expect(HeroView.place(true, true, false, { paid = true })).toEqual("destroy")
		expect(HeroView.place(true, true, true, paid)).toEqual("parent")
	end)

	it("does not write its arguments", function()
		local name = { paid = true, n = "R6" }
		local extra = { paid = true, productId = 0, robux = 0, cost = 0, skip = false }
		local built = { paid = true, value = true }
		local hasModel = { paid = true, value = true }
		local alive = { paid = true, value = false }
		table.freeze(name)
		table.freeze(extra)
		table.freeze(built)
		table.freeze(hasModel)
		table.freeze(alive)
		expect(HeroView.rig(name, extra)).toEqual("R15")
		expect(HeroView.rig("R6", extra)).toEqual("R6")
		expect(HeroView.place(built, hasModel, alive, extra)).toEqual("skip")
		expect(HeroView.place(true, true, false, extra)).toEqual("destroy")
		expect(name.paid).toEqual(true)
		expect(name.n).toEqual("R6")
		expect(extra.paid).toEqual(true)
		expect(extra.productId).toEqual(0)
		expect(extra.robux).toEqual(0)
		expect(extra.cost).toEqual(0)
		expect(extra.skip).toEqual(false)
		expect(built.paid).toEqual(true)
		expect(built.value).toEqual(true)
		expect(hasModel.paid).toEqual(true)
		expect(hasModel.value).toEqual(true)
		expect(alive.paid).toEqual(true)
		expect(alive.value).toEqual(false)
	end)

	it("does not use a clock, rng, or services", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/HeroView.luau")
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		expect(string.find(source, "tick(", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
	end)
end)

describe("MenuHub hero avatar", function()
	it("requests the returned rig and destroys a late model", function()
		local hub = fs.readFile(HUB)
		local avatar = between(
			hub,
			'local camera = Instance.new("Camera")',
			'local classCard = Instance.new("Frame")'
		)
		local call = between(avatar, "CreateHumanoidModelFromDescription(", ")")
		local parentBranch =
			between(avatar, 'if action == "parent" then', 'elseif action == "destroy"')
		local destroyBranch = between(avatar, 'elseif action == "destroy" then', "end")
		local beginRoll = between(hub, "beginRoll = function()", "function hubFn.pointerDown")

		local rigAt = string.find(avatar, "HeroView.rig(humanoid.RigType.Name)", 1, true)
		local createAt = string.find(avatar, "CreateHumanoidModelFromDescription", 1, true)
		local nilAt = string.find(avatar, "if humanoid == nil then", 1, true)
		local describedAt = string.find(avatar, "GetAppliedDescription", 1, true)
		local placeAt = string.find(
			avatar,
			"HeroView.place(built, model ~= nil, viewport.Parent ~= nil)",
			1,
			true
		)
		expect(nilAt ~= nil and describedAt ~= nil and rigAt ~= nil).toBeTrue()
		expect(createAt ~= nil and placeAt ~= nil).toBeTrue()
		expect((nilAt :: number) < (describedAt :: number)).toBeTrue()
		expect((describedAt :: number) < (rigAt :: number)).toBeTrue()
		expect((rigAt :: number) < (createAt :: number)).toBeTrue()
		expect((createAt :: number) < (placeAt :: number)).toBeTrue()
		local beforeDescription = string.sub(avatar, nilAt :: number, (describedAt :: number) - 1)
		expect(string.find(beforeDescription, "return", 1, true) ~= nil).toBeTrue()

		expect(string.find(call, "rigType", 1, true) ~= nil).toBeTrue()
		expect(string.find(call, "Enum.HumanoidRigType.R15", 1, true)).toBeNil()
		expect(string.find(call, "Enum.HumanoidRigType.R6", 1, true)).toBeNil()
		expect(string.find(avatar, 'rigName == "R6"', 1, true) ~= nil).toBeTrue()
		expect(string.find(avatar, "Enum.HumanoidRigType.R6", 1, true) ~= nil).toBeTrue()
		expect(string.find(avatar, "Enum.HumanoidRigType.R15", 1, true) ~= nil).toBeTrue()

		expect(string.find(parentBranch, "model.Parent = world", 1, true) ~= nil).toBeTrue()
		expect(string.find(parentBranch, ":Destroy()", 1, true)).toBeNil()
		expect(string.find(destroyBranch, "model:Destroy()", 1, true) ~= nil).toBeTrue()
		expect(string.find(destroyBranch, "model.Parent", 1, true)).toBeNil()
		local _, parentWrites = string.gsub(avatar, "model%.Parent", "")
		expect(parentWrites).toEqual(1)

		local cameraAt = string.find(avatar, "camera.CFrame", 1, true)
		local spawnAt = string.find(avatar, "task.spawn(function()", 1, true)
		expect(cameraAt ~= nil and spawnAt ~= nil).toBeTrue()
		expect((cameraAt :: number) < (spawnAt :: number)).toBeTrue()
		expect(string.find(avatar, "Vector3.new(0, 2, -6)", 1, true) ~= nil).toBeTrue()
		expect(string.find(beginRoll, "HeroView", 1, true)).toBeNil()
		local spawnBody = string.sub(avatar, spawnAt :: number)
		expect(string.find(spawnBody, 'WaitForChild("HeroView")', 1, true)).toBeNil()
		expect(string.find(hub, 'WaitForChild("HeroView")', 1, true) ~= nil).toBeTrue()
	end)
end)
