--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local EchoVitals = require("../src/ServerScriptService/ShardfallServer/EchoVitals")
local RaidEcho = require("../src/ReplicatedStorage/Shared/RaidEcho")
local RaidEchoFight = require("../src/ReplicatedStorage/Shared/RaidEchoFight")

describe("Echo vitals", function()
	it("keeps a bad scale result off the bar and the heal", function()
		expect(EchoVitals.maxHp(1000, 1050)).toEqual(1050)
		expect(EchoVitals.maxHp(1000, 1000.9)).toEqual(1000)
		expect(EchoVitals.maxHp(1000, 0 / 0)).toEqual(1000)
		expect(EchoVitals.maxHp(1000, math.huge)).toEqual(1000)
		expect(EchoVitals.maxHp(1000, nil)).toEqual(1000)
		expect(EchoVitals.maxHp(1000, -5)).toEqual(1000)
		expect(EchoVitals.maxHp(0, nil)).toEqual(1)
		expect(EchoVitals.maxHp("nope", "nope")).toEqual(1)

		expect(EchoVitals.heal(80, 84)).toEqual(84)
		expect(EchoVitals.heal(80, 0 / 0)).toEqual(80)
		expect(EchoVitals.heal(80, nil)).toEqual(80)
		expect(EchoVitals.heal(80, -1)).toEqual(0)
		expect(EchoVitals.heal(80, 0)).toEqual(0)
		expect(EchoVitals.heal(0, nil)).toEqual(0)
	end)

	it("publishes echoed max HP from the unbuffed base once", function()
		local fight = RaidEchoFight.open("story", false, "1")
		RaidEchoFight.notePull(fight, "twins")
		RaidEchoFight.setAlive(fight, "1", false)
		RaidEchoFight.setAlive(fight, "1", true)
		local step = 1 + RaidEcho.CONFIG.perWipe
		local scaled = RaidEchoFight.applyBase(fight, "1", "maxHp", 1000)
		local shown = EchoVitals.maxHp(1000, scaled)
		expect(shown).toEqual(math.floor(1000 * step))
		local again = RaidEchoFight.applyBase(fight, "1", "maxHp", 1000)
		expect(EchoVitals.maxHp(1000, again)).toEqual(shown)
		expect(fight.bases["1"].maxHp).toEqual(1000)

		local healed = RaidEchoFight.applyBase(fight, "1", "healing", 80)
		expect(EchoVitals.heal(80, healed)).toEqual(math.floor(80 * step + 0.5))
		expect(fight.bases["1"].healing).toEqual(80)
	end)
end)
