--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Keybinds = require("../src/ReplicatedStorage/Shared/Keybinds")

local function has(list: { string }, name: string): boolean
	return table.find(list, name) ~= nil
end

describe("Hub world mode", function()
	it("lets the player walk with Hero, Bag, Pets, Shop, Settings and Roll open", function()
		for _, page in ipairs({ "hero", "bag", "pets", "shop", "settings", "roll" }) do
			expect(Keybinds.locksMovement(page)).toEqual(false)
			expect(Keybinds.worldMode(true, page, false)).toEqual("walk")
		end
	end)

	it("locks the class picker and any unlisted page", function()
		expect(Keybinds.locksMovement("class")).toEqual(true)
		expect(Keybinds.worldMode(true, "class", false)).toEqual("lock")
		expect(Keybinds.worldMode(true, "someNewScreen", false)).toEqual("lock")
		expect(Keybinds.worldMode(true, nil, false)).toEqual("lock")
	end)

	it("frees everything when closed and locks an open hub on a gamepad", function()
		for _, page in ipairs({ "hero", "roll", "class" }) do
			expect(Keybinds.worldMode(false, page, false)).toEqual("free")
			expect(Keybinds.worldMode(false, page, true)).toEqual("free")
		end
		expect(Keybinds.worldMode(true, "bag", true)).toEqual("lock")
		expect(Keybinds.worldMode(true, "roll", true)).toEqual("lock")
		-- class -> bag on mouse releases movement
		expect(Keybinds.worldMode(true, "class", false)).toEqual("lock")
		expect(Keybinds.worldMode(true, "bag", false)).toEqual("walk")
	end)

	it("locks only while a roll reveal plays", function()
		expect(Keybinds.worldMode(true, "roll", false, false)).toEqual("walk")
		expect(Keybinds.worldMode(true, "roll", false, nil)).toEqual("walk")
		expect(Keybinds.worldMode(true, "roll", false, true)).toEqual("lock")
		-- reveal ends or is skipped: back to walk
		expect(Keybinds.worldMode(true, "roll", false, false)).toEqual("walk")
		-- gamepad still locks with or without a reveal
		expect(Keybinds.worldMode(true, "roll", true, false)).toEqual("lock")
		expect(Keybinds.worldMode(true, "roll", true, true)).toEqual("lock")
		-- closing the hub mid-reveal frees the controls
		expect(Keybinds.worldMode(false, "roll", false, true)).toEqual("free")
		expect(Keybinds.worldMode(false, "roll", true, true)).toEqual("free")
		-- the class picker stays locked either way
		expect(Keybinds.worldMode(true, "class", false, false)).toEqual("lock")
	end)

	it("sinks only combat keys in walk mode", function()
		local walk = Keybinds.walkSinkNames()
		for _, key in ipairs({
			"W",
			"A",
			"S",
			"D",
			"Space",
			"LeftShift",
			"RightShift",
			"Thumbstick1",
		}) do
			expect(has(walk, key)).toEqual(false)
		end
		for _, key in ipairs({ "R", "F", "One", "Eight" }) do
			expect(has(walk, key)).toEqual(true)
		end
		-- Tab letter hotkeys stay free so they still switch pages.
		for _, key in pairs(Keybinds.MENU) do
			expect(has(walk, key)).toEqual(false)
		end
		local full = Keybinds.sinkNames()
		expect(has(full, "W")).toEqual(true)
		expect(has(full, "LeftShift")).toEqual(true)
	end)
end)
