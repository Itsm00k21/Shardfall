--!strict

--[[
	Kevin's Oct 19 playtest: loot toasts read "1 Spore Cap x2". The lead
	"+ " looked like a stray 1 in the small toast font. Loot lines now read
	"Loot: Spore Cap x2" and still route to the loot toast.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CombatFeel = require("../src/ReplicatedStorage/Shared/CombatFeel")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")

describe("Loot toast text", function()
	it("names the loot with no stray lead character", function()
		local line = Materials.lootHint({ "Spore Cap x2", "Verdant Bark x1" }, "Spore Puff")
		expect(line).toEqual("Loot: Spore Cap x2, Verdant Bark x1")
		expect(string.match(line, "^[%d%+]")).toBeNil()
		expect(string.sub(line, 1, #CombatFeel.LOOT_PREFIX)).toEqual(CombatFeel.LOOT_PREFIX)
	end)

	it("routes loot lines to the toast, not the gold banner", function()
		expect(CombatFeel.isLootLine("Loot: Spore Cap x2")).toBeTrue()
		expect(CombatFeel.hintOnBanner("Loot: Spore Cap x2")).toBeFalse()
		expect(CombatFeel.hintOnBanner("Room clear. Next room in 3s.")).toBeTrue()
		local client = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		expect(string.find(client, 'string.sub(text, 1, 6) == "Loot: "', 1, true) ~= nil).toBeTrue()
		expect(#CombatFeel.LOOT_PREFIX).toEqual(6)
	end)
end)
