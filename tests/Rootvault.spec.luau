--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Rootvault = require("../src/ReplicatedStorage/Shared/Rootvault")

describe("Rootvault", function()
	it("scales Hard and Nightmare and gates them by level", function()
		expect(Rootvault.difficulty("nope").id).toEqual("normal")
		local hp, damage = Rootvault.scale("hard", 100, 10)
		expect(hp).toEqual(150)
		expect(damage).toEqual(15)
		expect(Rootvault.difficulty("nightmare").level).toEqual(15)
		expect(Rootvault.difficulty("nightmare").chest).toEqual("Rare")
		expect(Rootvault.difficulty("hard").chest).toEqual("Uncommon")
	end)

	it("splits Grandmother Gnarl into three phases", function()
		expect(Rootvault.gnarlPhase(200, 220)).toEqual(1)
		expect(Rootvault.gnarlPhase(130, 220)).toEqual(2)
		expect(Rootvault.gnarlPhase(50, 220)).toEqual(3)
		expect(Rootvault.phaseNote(3) ~= "").toEqual(true)
	end)

	it("does not land phase fog and a strike on the same beat", function()
		local fog, strike = Rootvault.sameBeat(true, true)
		expect(fog).toEqual(false)
		expect(strike).toEqual(true)
		fog, strike = Rootvault.sameBeat(true, false)
		expect(fog).toEqual(true)
		expect(strike).toEqual(false)
		fog, strike = Rootvault.sameBeat(false, false)
		expect(fog).toEqual(false)
		expect(strike).toEqual(false)
	end)

	it("offers two doors and always ends on the boss door", function()
		local doors = Rootvault.offer(1, 4, 1)
		expect(#doors).toEqual(2)
		expect(doors[1].id ~= doors[2].id).toEqual(true)
		local boss = Rootvault.offer(3, 4, 2)
		expect(#boss).toEqual(1)
		expect(boss[1].id).toEqual("boss")
		expect(Rootvault.ROLES.charger.kind).toEqual("thorn_sprite")
		expect(Rootvault.ROLES.mender.kind).toEqual("moss_crawler")
		expect(Rootvault.shrine(2)).toEqual("ward")
	end)

	it("pays 200 gold for the treasure door", function()
		expect(Rootvault.TREASURE_GOLD).toEqual(200)
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(service, "Rootvault.TREASURE_GOLD", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "data.gold += 25", 1, true)).toBeNil()
	end)
end)
