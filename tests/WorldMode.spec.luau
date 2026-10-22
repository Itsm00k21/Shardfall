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
	it("lets the player walk with Hero, Bag, Pets, Shop and Settings open", function()
		for _, page in ipairs({ "hero", "bag", "pets", "shop", "settings" }) do
			expect(Keybinds.locksMovement(page)).toEqual(false)
			expect(Keybinds.worldMode(true, page, false)).toEqual("walk")
		end
	end)

	it("locks the Roll screen, the class picker and any unlisted page", function()
		expect(Keybinds.worldMode(true, "roll", false)).toEqual("lock")
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
		-- roll -> bag on mouse releases movement
		expect(Keybinds.worldMode(true, "roll", false)).toEqual("lock")
		expect(Keybinds.worldMode(true, "bag", false)).toEqual("walk")
	end)

	it("sinks only combat keys in walk mode", function()
		local walk = Keybinds.walkSinkNames()
		for _, key in ipairs({ "W", "A", "S", "D", "Space", "LeftShift", "RightShift", "Thumbstick1" }) do
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
