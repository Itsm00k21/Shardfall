--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local HardMode = require("../src/ReplicatedStorage/Shared/HardMode")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Progression = require("../src/ReplicatedStorage/Shared/Progression")
local Rootvault = require("../src/ReplicatedStorage/Shared/Rootvault")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("Hard mode config", function()
	it("locks Hard to the Core Loop and leaves the other rows in the table", function()
		local hard = Economy.DIFFICULTIES.hard
		expect(hard.levelGate).toEqual(5)
		expect(hard.hpMultiplier).toEqual(2)
		expect(hard.damageMultiplier).toEqual(1.5)
		expect(hard.tokenMultiplier).toEqual(2)
		expect(hard.fragmentMultiplier).toEqual(2)
		expect(Rootvault.difficulty("hard").hp).toEqual(2)
		expect(Rootvault.difficulty("hard").damage).toEqual(1.5)
		expect(Rootvault.difficulty("hard").level).toEqual(5)
		local scaledHp, scaledDamage = Rootvault.scale("hard", 100, 10)
		expect(scaledHp).toEqual(200)
		expect(scaledDamage).toEqual(15)
		expect(HardMode.tokens("hard", 11)).toEqual(22)
		expect(HardMode.fragments("hard", 4)).toEqual(8)
		expect(HardMode.tokens("normal", 11)).toEqual(11)
		expect(HardMode.fragments("normal", 4)).toEqual(4)
		expect(Economy.DIFFICULTIES.medium.tokenMultiplier).toEqual(1.25)
		expect(Economy.DIFFICULTIES.nightmare.levelGate).toEqual(15)
		expect(Economy.DIFFICULTIES.nightmare.hpMultiplier).toEqual(2)
		expect(Economy.DIFFICULTIES.insane.tokenMultiplier).toEqual(3)
		expect(LaunchGate.on("extraDifficulties")).toEqual(false)
		expect(LaunchGate.on("hardMode")).toEqual(false)
		expect(HardMode.parked("medium")).toEqual(true)
		expect(HardMode.parked("nightmare")).toEqual(true)
		expect(HardMode.parked("insane")).toEqual(true)
		expect(HardMode.parked("hard")).toEqual(false)
		expect(HardMode.offered("medium")).toEqual(false)
		expect(HardMode.offered("nightmare")).toEqual(false)
		expect(HardMode.offered("insane")).toEqual(false)
		expect(HardMode.offered("hard")).toEqual(false)
		expect(HardMode.offered("normal")).toEqual(true)
	end)

	it("keeps schemaVersion 26 and does not add a difficulty save field", function()
		expect(Schema.VERSION).toEqual(26)
		local fresh = Schema.template()
		expect(fresh.schemaVersion).toEqual(26)
		expect((fresh :: any).difficulty).toBeNil()
		expect((fresh :: any).gateTier).toBeNil()
		expect((fresh :: any).lastDifficulty).toBeNil()
		expect((fresh :: any).fragmentMultiplier).toBeNil()
		local source = fs.readFile("src/ReplicatedStorage/Shared/HardMode.luau")
		expect(string.find(source, "DataService", 1, true)).toBeNil()
		expect(string.find(source, "DataStore", 1, true)).toBeNil()
	end)
end)

describe("Hard mode pad", function()
	it("stays on Normal and refuses Hard while hardMode is off", function()
		expect(LaunchGate.on("hardMode")).toEqual(false)
		HardMode.noteJoin(42)
		HardMode.noteJoin(43)
		expect(HardMode.joinTier()).toEqual("normal")
		expect(HardMode.sessionTier(42)).toEqual("normal")
		expect(HardMode.joinedTier(42)).toEqual("normal")
		expect(HardMode.accept(1, nil)).toEqual("normal")
		expect(HardMode.accept(4, "")).toEqual("normal")
		expect(HardMode.accept(4, "nope")).toEqual("normal")
		expect(HardMode.accept(3, "normal")).toEqual("normal")
		-- An unknown name is not a tier. The session stays on Normal.
		expect(HardMode.accept(9, " hard ")).toEqual("normal")

		local denied, why = HardMode.accept(4, "hard")
		expect(denied).toBeNil()
		expect(why).toEqual(HardMode.CLOSED)
		local shouted = HardMode.accept(99, "HARD")
		expect(shouted).toBeNil()
		expect(HardMode.accept(5, "hard")).toBeNil()

		local picked, pickWhy = HardMode.select(99, "hard", 42)
		expect(picked).toBeNil()
		expect(pickWhy).toEqual(HardMode.CLOSED)
		expect(HardMode.sessionTier(42)).toEqual("normal")
		expect(HardMode.sessionTier(43)).toEqual("normal")
		expect(HardMode.touch(4, 42)).toEqual("normal")
		expect(HardMode.touch(99, 43)).toEqual("normal")
		-- The old shared gate key still cannot store a tier.
		expect(HardMode.open(HardMode.GATE)).toEqual("normal")
		expect(HardMode.sessionTier(HardMode.GATE)).toEqual("normal")
		expect(HardMode.select(99, "normal", HardMode.GATE)).toBeNil()
		expect(HardMode.sessionTier(42)).toEqual("normal")
		HardMode.release(42)
		HardMode.release(43)
	end)

	it("one player's pick cannot lock out, drag along, or flip anyone else", function()
		local previous = LaunchGate.SHOW.hardMode
		LaunchGate.SHOW.hardMode = false
		local ok, err = pcall(function()
			local alpha = 101
			local beta = 202
			HardMode.noteJoin(alpha)
			HardMode.noteJoin(beta)

			-- Flag off: a Hard ask does not stick, and the other player stays Normal.
			expect(HardMode.select(20, "hard", alpha)).toBeNil()
			expect(HardMode.sessionTier(alpha)).toEqual("normal")
			expect(HardMode.sessionTier(beta)).toEqual("normal")
			expect(HardMode.touch(3, beta)).toEqual("normal")
			expect(HardMode.touch(20, alpha)).toEqual("normal")

			LaunchGate.SHOW.hardMode = true
			expect(HardMode.accept(4, "hard")).toBeNil()
			expect(HardMode.accept(5, "hard")).toEqual("hard")
			local low, lowWhy = HardMode.select(4, "hard", alpha)
			expect(low).toBeNil()
			expect(lowWhy).toEqual(HardMode.REFUSED)
			expect(HardMode.sessionTier(alpha)).toEqual("normal")
			expect(HardMode.sessionTier(beta)).toEqual("normal")

			expect(HardMode.select(8, "hard", alpha)).toEqual("hard")
			-- Beta is not locked out, dragged onto Hard, or flipped.
			expect(HardMode.sessionTier(beta)).toEqual("normal")
			expect(HardMode.touch(3, beta)).toEqual("normal")
			expect(HardMode.touch(12, beta)).toEqual("normal")
			expect(HardMode.touch(3, alpha)).toBeNil()
			expect(HardMode.sessionTier(alpha)).toEqual("hard")

			expect(HardMode.select(9, "normal", beta)).toEqual("normal")
			expect(HardMode.sessionTier(alpha)).toEqual("hard")
			expect(HardMode.select(9, "hard", beta)).toEqual("hard")
			expect(HardMode.sessionTier(alpha)).toEqual("hard")
			expect(HardMode.touch(9, beta)).toEqual("hard")
			expect(HardMode.select(8, "normal", alpha)).toEqual("normal")
			expect(HardMode.sessionTier(beta)).toEqual("hard")
			expect(HardMode.touch(8, alpha)).toEqual("normal")

			-- A shared key cannot write a tier that both players then share.
			expect(HardMode.select(20, "hard", HardMode.GATE)).toBeNil()
			expect(HardMode.sessionTier(alpha)).toEqual("normal")
			expect(HardMode.sessionTier(beta)).toEqual("hard")

			-- Flag off again: Hard is refused for the player on it, and the
			-- other player still walks in on Normal.
			LaunchGate.SHOW.hardMode = false
			expect(HardMode.touch(9, beta)).toBeNil()
			expect(HardMode.sessionTier(alpha)).toEqual("normal")
			expect(HardMode.touch(8, alpha)).toEqual("normal")
			expect(HardMode.sessionTier(beta)).toEqual("hard")
			LaunchGate.SHOW.hardMode = true

			expect(HardMode.noteJoin(beta)).toEqual("normal")
			expect(HardMode.sessionTier(alpha)).toEqual("normal")
			expect(HardMode.sessionTier(beta)).toEqual("normal")

			LaunchGate.SHOW.hardMode = false
			expect(HardMode.select(20, "hard", alpha)).toBeNil()
			expect(HardMode.touch(20, alpha)).toEqual("normal")
			expect(HardMode.touch(3, beta)).toEqual("normal")
		end)
		LaunchGate.SHOW.hardMode = previous
		HardMode.release(101)
		HardMode.release(202)
		if not ok then
			error(err, 0)
		end
	end)

	it("refuses Medium, Nightmare, and Insane while the flag is off", function()
		local previous = LaunchGate.SHOW.extraDifficulties
		LaunchGate.SHOW.extraDifficulties = false
		local ok, err = pcall(function()
			HardMode.open(HardMode.GATE)
			for _, id in ipairs({ "medium", "nightmare", "insane" }) do
				local tier, why = HardMode.accept(30, id)
				expect(tier).toBeNil()
				expect(why).toEqual(HardMode.CLOSED)
				local selected, selectWhy = HardMode.select(30, id)
				expect(selected).toBeNil()
				expect(selectWhy).toEqual(HardMode.CLOSED)
			end
			expect(HardMode.sessionTier()).toEqual("normal")
			expect(Economy.DIFFICULTIES.nightmare ~= nil).toBeTrue()
			expect(Rootvault.difficulty("nightmare").level).toEqual(15)
			local shown = Progression.unlocked(20)
			local sawNightmare = false
			for _, id in ipairs(shown) do
				if id == "nightmare" then
					sawNightmare = true
				end
			end
			expect(sawNightmare).toEqual(false)
			expect(Progression.UNLOCKS[5].id).toEqual("nightmare")

			LaunchGate.SHOW.extraDifficulties = true
			expect(HardMode.accept(15, "nightmare")).toEqual("nightmare")
			expect(HardMode.accept(14, "nightmare")).toBeNil()
			expect(HardMode.accept(5, "medium")).toEqual("medium")
			expect(HardMode.accept(4, "medium")).toBeNil()
			expect(HardMode.accept(20, "insane")).toEqual("insane")
			local nightHp = Rootvault.scale("nightmare", 50, 8)
			expect(nightHp).toEqual(100)
		end)
		LaunchGate.SHOW.extraDifficulties = previous
		HardMode.open(HardMode.GATE)
		if not ok then
			error(err, 0)
		end
	end)

	it("checks the pad and the enter path on the server without a save write", function()
		local service = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local enterBody = between(service, "function DungeonService.enter", "function DungeonService.tuneRaid")
		local checkAt = string.find(enterBody, "HardMode.accept", 1, true)
		local runAt = string.find(enterBody, "runs[player] = run", 1, true)
		expect(checkAt ~= nil and runAt ~= nil and (checkAt :: number) < (runAt :: number)).toBeTrue()
		expect(string.find(enterBody, "HardMode.REFUSED", 1, true) ~= nil).toBeTrue()

		local pick = between(service, "function DungeonService.setDifficulty", "local function enterFromPad")
		expect(string.find(pick, "HardMode.select", 1, true) ~= nil).toBeTrue()
		expect(string.find(pick, "DataService.mutate", 1, true)).toBeNil()
		expect(string.find(pick, "DataService.get", 1, true) ~= nil).toBeTrue()

		expect(string.find(service, "HardMode.touch(level, player.UserId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "HardMode.select(profile.level, tier, player.UserId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "HardMode.touch(level, HardMode.GATE)", 1, true)).toBeNil()
		expect(string.find(service, "HardMode.select(profile.level, tier, HardMode.GATE)", 1, true)).toBeNil()
		expect(string.find(service, "HardMode.open(HardMode.GATE)", 1, true)).toBeNil()
		expect(string.find(service, 'enterFromPad(player, descendant:GetAttribute("EnterDungeon"))', 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "enterFromPad(player, Dungeons.ROOTVAULT_ID)", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "HardMode.noteJoin(player.UserId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "HardMode.release(player.UserId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(service, "HardMode.tokens", 1, true) ~= nil).toBeTrue()

		local client = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		expect(string.find(client, "HardMode", 1, true)).toBeNil()
	end)
end)
