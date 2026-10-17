--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CombatFeel = require("../src/ReplicatedStorage/Shared/CombatFeel")

describe("Combat feel", function()
	it("times light, heavy, and kill juice", function()
		expect(CombatFeel.juice("light").hitstop).toEqual(0.03)
		expect(CombatFeel.juice("heavy").hitstop).toEqual(0.07)
		expect(CombatFeel.juice("heavy").shake).toEqual(0.15)
		expect(CombatFeel.juice("kill").shards).toEqual(true)
		expect(CombatFeel.juice("kill").hitstop).toEqual(0.1)
		expect(CombatFeel.particlesFor("low", CombatFeel.juice("kill"))).toEqual(6)
		expect(CombatFeel.shakeAllowed("low", true, CombatFeel.juice("heavy"))).toEqual(0)
		expect(CombatFeel.shakeAllowed("med", false, CombatFeel.juice("heavy"))).toEqual(0)
		expect(CombatFeel.shakeAllowed("high", true, CombatFeel.juice("heavy"))).toEqual(0.15)
	end)

	it("spends two dodge charges and refills one every 3s", function()
		local state = CombatFeel.blankDodge(0)
		expect(CombatFeel.tryDodge(state, 1)).toEqual(true)
		expect(state.charges).toEqual(1)
		expect(CombatFeel.tryDodge(state, 1.1)).toEqual(true)
		expect(state.charges).toEqual(0)
		expect(CombatFeel.tryDodge(state, 1.2)).toEqual(false)
		expect(CombatFeel.iframe(state, 1.2)).toEqual(true)
		expect(CombatFeel.iframe(state, 1.1 + CombatFeel.IFRAME_SECONDS)).toEqual(false)
		CombatFeel.refillDodge(state, 1 + CombatFeel.DODGE_RECHARGE)
		expect(state.charges).toEqual(1)
		CombatFeel.refillDodge(state, 1 + CombatFeel.DODGE_RECHARGE * 2)
		expect(state.charges).toEqual(2)
	end)

	it("calls a dodge perfect only inside the last 0.15s of a telegraph", function()
		expect(CombatFeel.perfect(10, 9.9)).toEqual(true)
		expect(CombatFeel.perfect(10, 9.84)).toEqual(false)
		expect(CombatFeel.perfect(10, 10.1)).toEqual(false)
	end)

	it("chains three hits, makes the third heavy, and resets after idle", function()
		local first = CombatFeel.advanceCombo(0, 0, 5, false)
		expect(first.index).toEqual(1)
		expect(first.heavy).toEqual(false)
		local third = CombatFeel.advanceCombo(2, 5.2, 5.4, false)
		expect(third.index).toEqual(3)
		expect(third.heavy).toEqual(true)
		expect(third.multiplier >= CombatFeel.HEAVY_MULT).toEqual(true)
		local charged = CombatFeel.advanceCombo(0, 0, 1, true)
		expect(charged.heavy).toEqual(true)
		expect(charged.multiplier >= CombatFeel.CHARGE_MULT).toEqual(true)
		local reset = CombatFeel.advanceCombo(2, 1, 1 + CombatFeel.COMBO_IDLE + 0.1, false)
		expect(reset.index).toEqual(1)
		expect(CombatFeel.comboBonus(10)).toEqual(0.05)
		expect(CombatFeel.comboBonus(50)).toEqual(0.15)
	end)

	it("fills a boss stagger bar into a stun and keeps a 0.8s normal telegraph", function()
		local bar = 0
		local stunned = false
		for _ = 1, 20 do
			bar, stunned = CombatFeel.applyStagger(bar, true, true)
			if stunned then
				break
			end
		end
		expect(stunned).toEqual(true)
		expect(bar).toEqual(0)
		local red = CombatFeel.telegraph("red", "normal")
		expect(red.verb).toEqual("dodge")
		expect(red.seconds).toEqual(0.8)
		expect(CombatFeel.telegraph("blue", "nightmare").verb).toEqual("interrupt")
		expect(CombatFeel.telegraph("blue", "nightmare").seconds).toEqual(0.5)
		expect(CombatFeel.telegraph("nope", "hard").verb).toEqual("dodge")
	end)

	it("scales particles, flinches, and keeps the camera off the target", function()
		local kill = CombatFeel.juice("kill")
		expect(CombatFeel.vfxBudget("low", 1, kill)).toEqual(6)
		expect(CombatFeel.vfxBudget("low", 0.5, kill)).toEqual(3)
		expect(CombatFeel.vfxBudget("low", 0, kill)).toEqual(0)
		expect(CombatFeel.FLINCH_SECONDS > 0 and CombatFeel.FLINCH_SECONDS < 0.2).toBeTrue()
		expect(CombatFeel.juice("heavy").hitstop >= 0.05).toBeTrue()
		expect(CombatFeel.DEATH_SECONDS <= 0.5).toBeTrue()
		local vx, vy, vz = CombatFeel.lootVelocity(1)
		expect(vy > 0).toBeTrue()
		expect(math.abs(vx) + math.abs(vz) > 0).toBeTrue()
		expect(CombatFeel.cooldownCover(0, 4)).toEqual(1)
		expect(CombatFeel.cooldownCover(4, 4)).toEqual(0)
		expect(CombatFeel.attackAnim(1)).toEqual("attack1")
		expect(CombatFeel.attackAnim(3)).toEqual("attack3")
		expect(CombatFeel.cameraDistance(2, 12) >= CombatFeel.CAMERA_MIN).toBeTrue()
		expect(CombatFeel.cameraDistance(0, 12)).toEqual(12)
		expect(CombatFeel.PRESS < 1).toBeTrue()
	end)
end)
