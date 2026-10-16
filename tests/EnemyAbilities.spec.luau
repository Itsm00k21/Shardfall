--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local EnemyAbilities = require("../src/ReplicatedStorage/Shared/EnemyAbilities")
local Rootvault = require("../src/ReplicatedStorage/Shared/Rootvault")

local HASTE = EnemyAbilities.HASTE
local MENDER = EnemyAbilities.MENDER
local SHIELDER = EnemyAbilities.SHIELDER

local function fighter(
	id: string,
	kind: string,
	hp: number,
	maxHp: number,
	x: number,
	z: number,
	nextHeal: number?
): any
	return {
		id = id,
		kind = kind,
		hp = hp,
		maxHp = maxHp,
		x = x,
		z = z,
		nextHeal = nextHeal,
	}
end

local function shielder(hp: number, lookX: number, lookZ: number): any
	return {
		kind = SHIELDER.kind,
		hp = hp,
		x = 0,
		z = 0,
		lookX = lookX,
		lookZ = lookZ,
	}
end

describe("Enemy abilities", function()
	it("matches the Rootvault shrine id and role kinds", function()
		local listed = false
		for _, shrineId in ipairs(Rootvault.SHRINES) do
			if shrineId == HASTE.id then
				listed = true
			end
		end
		expect(listed).toEqual(true)
		expect(HASTE.id).toEqual("haste")
		expect(Rootvault.ROLES.shielder.kind).toEqual(SHIELDER.kind)
		expect(Rootvault.ROLES.mender.kind).toEqual(MENDER.kind)
		expect(SHIELDER.kind).toEqual("root_brute")
		expect(MENDER.kind).toEqual("moss_crawler")
		expect(MENDER.ignoreKind).toEqual("grandmother_gnarl")
	end)
end)

describe("Haste shrine", function()
	it("applies only for the haste shrine and then expires", function()
		expect(HASTE.duration).toEqual(30)
		expect(HASTE.attackSpeed).toEqual(1.2)
		expect(HASTE.moveSpeed).toEqual(1.15)
		expect(EnemyAbilities.applyHaste("might", 10)).toBeNil()
		expect(EnemyAbilities.applyHaste("ward", 10)).toBeNil()
		expect(EnemyAbilities.applyHaste("", 10)).toBeNil()
		expect(EnemyAbilities.applyHaste("haste", nil :: any)).toBeNil()
		expect(EnemyAbilities.applyHaste("haste", 0 / 0)).toBeNil()

		local buff = EnemyAbilities.applyHaste("haste", 10)
		expect(buff ~= nil).toEqual(true)
		if buff == nil then
			return
		end
		expect(buff.untilAt).toEqual(40)
		expect(buff.attackSpeed).toEqual(HASTE.attackSpeed)
		expect(buff.moveSpeed).toEqual(HASTE.moveSpeed)
		expect(EnemyAbilities.hasteActive(buff, 39.999)).toEqual(true)
		expect(EnemyAbilities.hasteActive(buff, 40)).toEqual(false)
		expect(EnemyAbilities.secondsLeft(buff, 25)).toBeCloseTo(15)
		expect(EnemyAbilities.secondsLeft(buff, 40)).toEqual(0)
		expect(EnemyAbilities.expireHaste(buff, 39)).toEqual(buff)
		expect(EnemyAbilities.expireHaste(buff, 40)).toBeNil()
		expect(EnemyAbilities.expireHaste(nil, 0)).toBeNil()
	end)

	it("scales attack and move speed until the deadline, without stacking", function()
		local buff = EnemyAbilities.applyHaste("haste", 0)
		expect(buff ~= nil).toEqual(true)
		if buff == nil then
			return
		end
		expect(EnemyAbilities.attackSpeed(2, buff, 0)).toBeCloseTo(2.4)
		expect(EnemyAbilities.moveSpeed(16, buff, 0)).toBeCloseTo(18.4)
		expect(EnemyAbilities.attackSpeed(2, buff, buff.untilAt)).toEqual(2)
		expect(EnemyAbilities.moveSpeed(16, nil, 0)).toEqual(16)
		expect(EnemyAbilities.attackSpeed(10, nil, 0)).toEqual(10)
		expect(EnemyAbilities.attackSpeed(10, buff, 0)).toEqual(HASTE.attackMax)
		expect(EnemyAbilities.moveSpeed(100, buff, 0)).toEqual(HASTE.moveMax)
		expect(EnemyAbilities.attackSpeed(0, buff, 0)).toEqual(0)
		expect(EnemyAbilities.moveSpeed(0 / 0, nil, 0)).toEqual(0)

		local again = EnemyAbilities.applyHaste("haste", 10)
		expect(again ~= nil).toEqual(true)
		if again == nil then
			return
		end
		expect(again.untilAt).toEqual(40)
		expect(again.attackSpeed).toEqual(HASTE.attackSpeed)
		expect(EnemyAbilities.hasteActive(buff, 35)).toEqual(false)
		expect(EnemyAbilities.hasteActive(again, 35)).toEqual(true)
		expect(EnemyAbilities.attackSpeed(2, again, 35)).toBeCloseTo(2.4)
	end)
end)

describe("Mender healing", function()
	it("heals the most wounded ally inside range and caps the pulse", function()
		local mender = fighter("m", MENDER.kind, 48, 48, 0, 0, nil)
		local worseRatio = fighter("far-hp", "vine_crawler", 30, 100, 4, 0, nil)
		local higherRatio = fighter("near-hp", "thorn_sprite", 40, 50, 4, 0, nil)
		local before = worseRatio.hp
		local pulses = EnemyAbilities.mend({ mender, higherRatio, worseRatio }, 5)
		expect(#pulses).toEqual(1)
		expect(pulses[1].targetId).toEqual("far-hp")
		expect(pulses[1].menderId).toEqual("m")
		expect(pulses[1].amount).toEqual(12)
		expect(pulses[1].hp).toEqual(42)
		expect(pulses[1].nextHeal).toEqual(9)
		expect(worseRatio.hp).toEqual(before)
		expect(mender.nextHeal).toBeNil()

		local almost = fighter("full", "vine_crawler", 95, 100, 1, 0, nil)
		local topped = EnemyAbilities.mend({ mender, almost }, 0)
		expect(topped[1].amount).toEqual(5)
		expect(topped[1].hp).toEqual(100)

		local huge = fighter("elite", "root_brute", 100, 1000, 1, 0, nil)
		local capped = EnemyAbilities.mend({ mender, huge }, 0)
		expect(capped[1].amount).toEqual(MENDER.maxHeal)
		expect(capped[1].hp).toEqual(124)

		local tiny = fighter("sprout", "vine_crawler", 1, 3, 1, 0, nil)
		local minimum = EnemyAbilities.mend({ mender, tiny }, 0)
		expect(minimum[1].amount).toEqual(MENDER.minHeal)
		expect(minimum[1].hp).toEqual(2)
	end)

	it("skips dead menders, dead allies, itself, Gnarl, and anyone out of range", function()
		local mender = fighter("m", MENDER.kind, 20, 48, 0, 0, nil)
		local deadAlly = fighter("dead", "vine_crawler", 0, 36, 1, 0, nil)
		local gnarl = fighter("boss", MENDER.ignoreKind, 10, 220, 1, 0, nil)
		local far = fighter("far", "vine_crawler", 1, 36, MENDER.range + 1, 0, nil)
		local edge = fighter("edge", "vine_crawler", 1, 36, MENDER.range, 0, nil)
		expect(#EnemyAbilities.mend({ mender, deadAlly, gnarl, far }, 0)).toEqual(0)
		expect(#EnemyAbilities.mend({ mender }, 0)).toEqual(0)

		local deadMender = fighter("m", MENDER.kind, 0, 48, 0, 0, nil)
		local hurt = fighter("hurt", "vine_crawler", 1, 36, 1, 0, nil)
		expect(#EnemyAbilities.mend({ deadMender, hurt }, 0)).toEqual(0)

		local reached = EnemyAbilities.mend({ mender, edge }, 0)
		expect(#reached).toEqual(1)
		expect(reached[1].targetId).toEqual("edge")

		local healer = fighter("m", MENDER.kind, 48, 48, 0, 0, nil)
		local other = fighter("other", MENDER.kind, 10, 48, 2, 0, nil)
		local between = EnemyAbilities.mend({ healer, other }, 0)
		expect(#between).toEqual(1)
		expect(between[1].menderId).toEqual("m")
		expect(between[1].targetId).toEqual("other")
	end)

	it("waits out the cooldown and does not start one when nobody needs healing", function()
		local mender = fighter("m", MENDER.kind, 48, 48, 0, 0, 12)
		local hurt = fighter("hurt", "vine_crawler", 1, 36, 1, 0, nil)
		expect(#EnemyAbilities.mend({ mender, hurt }, 11.9)).toEqual(0)
		local ready = EnemyAbilities.mend({ mender, hurt }, 12)
		expect(#ready).toEqual(1)
		expect(ready[1].nextHeal).toEqual(12 + MENDER.interval)

		local healthy = fighter("ok", "vine_crawler", 36, 36, 1, 0, nil)
		local idle = fighter("m", MENDER.kind, 48, 48, 0, 0, nil)
		expect(#EnemyAbilities.mend({ idle, healthy }, 3)).toEqual(0)
		expect(#EnemyAbilities.mend({}, 0)).toEqual(0)
		expect(#EnemyAbilities.mend({ hurt = hurt } :: any, 0)).toEqual(0)
		expect(EnemyAbilities.priority(nil :: any, 0)).toBeNil()
	end)

	it("lets a second mender see the first pulse and names a living priority", function()
		local first = fighter("a", MENDER.kind, 48, 48, 0, 0, nil)
		local second = fighter("b", MENDER.kind, 48, 48, 0, 1, nil)
		local ally = fighter("ally", "vine_crawler", 10, 100, 2, 0, nil)
		local pulses = EnemyAbilities.mend({ second, first, ally }, 1)
		expect(#pulses).toEqual(2)
		expect(pulses[1].menderId).toEqual("a")
		expect(pulses[1].hp).toEqual(22)
		expect(pulses[2].menderId).toEqual("b")
		expect(pulses[2].hp).toEqual(34)

		local nearly = fighter("ally", "vine_crawler", 95, 100, 2, 0, nil)
		local one = EnemyAbilities.mend({ second, first, nearly }, 1)
		expect(#one).toEqual(1)
		expect(one[1].hp).toEqual(100)

		expect(EnemyAbilities.priority({ ally }, 0)).toBeNil()
		local dead = fighter("m", MENDER.kind, 0, 48, 0, 0, nil)
		expect(EnemyAbilities.priority({ dead, ally }, 0)).toBeNil()
		expect(EnemyAbilities.priority({ first }, 0)).toEqual("a")

		local cooling = fighter("c", MENDER.kind, 10, 48, 0, 0, 50)
		local unplaced = fighter("d", MENDER.kind, 10, 48, nil :: any, nil :: any, nil)
		expect(EnemyAbilities.priority({ cooling, first }, 0)).toEqual("a")
		expect(EnemyAbilities.priority({ cooling, second }, 0)).toEqual("b")
		expect(EnemyAbilities.priority({ unplaced }, 0)).toEqual("d")
		expect(#EnemyAbilities.mend({ unplaced, ally }, 0)).toEqual(0)

		local tiedA = fighter("ally-a", "vine_crawler", 10, 100, 1, 0, nil)
		local tiedB = fighter("ally-b", "vine_crawler", 10, 100, 1, 0, nil)
		local tied = EnemyAbilities.mend({ first, tiedB, tiedA }, 0)
		expect(tied[1].targetId).toEqual("ally-a")
	end)
end)

describe("Shielder blocking", function()
	it("blocks the front arc and lets a flank through", function()
		expect(SHIELDER.frontDot).toEqual(0.5)
		expect(SHIELDER.frontMultiplier).toEqual(0)
		local front, blocked = EnemyAbilities.block(shielder(78, 0, 1), 0, 6, 14)
		expect(blocked).toEqual(true)
		expect(front).toEqual(0)

		local side, sideBlocked = EnemyAbilities.block(shielder(78, 0, 1), 6, 0, 14)
		expect(sideBlocked).toEqual(false)
		expect(side).toEqual(14)

		local rear, rearBlocked = EnemyAbilities.block(shielder(78, 0, 1), 0, -6, 14)
		expect(rearBlocked).toEqual(false)
		expect(rear).toEqual(14)

		local boundary, boundaryBlocked =
			EnemyAbilities.block(shielder(78, 0, 1), math.sqrt(3) / 2, 0.5, 14)
		expect(boundaryBlocked).toEqual(true)
		expect(boundary).toEqual(0)

		local outside, outsideBlocked = EnemyAbilities.block(shielder(78, 0, 1), 0.9, 0.4, 14)
		expect(outsideBlocked).toEqual(false)
		expect(outside).toEqual(14)
	end)

	it("does not block a dead shielder, another kind, or a hit with no direction", function()
		local dead, deadBlocked = EnemyAbilities.block(shielder(0, 0, 1), 0, 6, 14)
		expect(deadBlocked).toEqual(false)
		expect(dead).toEqual(14)

		local grunt, gruntBlocked = EnemyAbilities.block({
			kind = "vine_crawler",
			hp = 36,
			x = 0,
			z = 0,
			lookX = 0,
			lookZ = 1,
		}, 0, 6, 9)
		expect(gruntBlocked).toEqual(false)
		expect(grunt).toEqual(9)

		local stacked, stackedBlocked = EnemyAbilities.block(shielder(78, 0, 1), 0, 0, 14)
		expect(stackedBlocked).toEqual(false)
		expect(stacked).toEqual(14)

		local blind, blindBlocked = EnemyAbilities.block(shielder(78, 0, 0), 0, 6, 14)
		expect(blindBlocked).toEqual(false)
		expect(blind).toEqual(14)

		local missing, missingBlocked = EnemyAbilities.block({
			kind = SHIELDER.kind,
			hp = 78,
			x = 0,
			z = 0,
		}, 0, 6, 14)
		expect(missingBlocked).toEqual(false)
		expect(missing).toEqual(14)

		local bad, badBlocked = EnemyAbilities.block(shielder(78, 0, 1), 0, 6, -5)
		expect(badBlocked).toEqual(false)
		expect(bad).toEqual(0)
		local nanAmount, nanBlocked = EnemyAbilities.block(shielder(78, 0, 1), 0, 6, 0 / 0)
		expect(nanBlocked).toEqual(false)
		expect(nanAmount).toEqual(0)
		local none, noneBlocked = EnemyAbilities.block(nil, 0, 6, 14)
		expect(noneBlocked).toEqual(false)
		expect(none).toEqual(14)
	end)

	it("turns toward the player at the shield's turn speed", function()
		local heldX, heldZ = EnemyAbilities.turnShield(0, 1, 1, 0, 0)
		expect(heldX).toEqual(0)
		expect(heldZ).toEqual(1)
		local backX, backZ = EnemyAbilities.turnShield(0, 1, 1, 0, -1)
		expect(backX).toEqual(0)
		expect(backZ).toEqual(1)

		local snapX, snapZ = EnemyAbilities.turnShield(0, 0, 1, 0, 0.1)
		expect(snapX).toBeCloseTo(1)
		expect(snapZ).toBeCloseTo(0)

		local stayX, stayZ = EnemyAbilities.turnShield(0, 1, 0, 0, 2)
		expect(stayX).toEqual(0)
		expect(stayZ).toEqual(1)

		local fullX, fullZ = EnemyAbilities.turnShield(0, 1, 1, 0, 10)
		expect(fullX).toBeCloseTo(1)
		expect(fullZ).toBeCloseTo(0)

		local stepX, stepZ = EnemyAbilities.turnShield(0, 1, 1, 0, 0.1)
		local maxStep = SHIELDER.turnSpeed * 0.1
		expect(maxStep < math.pi / 2).toEqual(true)
		expect(stepX).toBeCloseTo(math.sin(maxStep))
		expect(stepZ).toBeCloseTo(math.cos(maxStep))
		expect(stepX * stepX + stepZ * stepZ).toBeCloseTo(1)
	end)
end)
