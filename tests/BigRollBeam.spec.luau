--!strict

--[[
	T6 big-roll beam, server side. The tier comes from Config.BigRoll.
	LaunchGate.bigRollBeam stays off. A client payload cannot fire one.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local BigRoll = require("../src/ReplicatedStorage/Shared/Config/BigRoll")
local BigRollBeam = require("../src/ReplicatedStorage/Shared/BigRollBeam")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function tuned(tier: string, chatMax: number?): { [string]: any }
	return {
		MIN_TIER = tier,
		QUEUE = BigRoll.QUEUE,
		GAP = BigRoll.GAP,
		CHAT_MAX = chatMax or BigRoll.CHAT_MAX,
		CHAT_WINDOW = BigRoll.CHAT_WINDOW,
		PLAYER_GAP = BigRoll.PLAYER_GAP,
		EPIC_BURST = BigRoll.EPIC_BURST,
		EPIC_WINDOW = BigRoll.EPIC_WINDOW,
		EPIC_MUTE = BigRoll.EPIC_MUTE,
		BEAM_HOLD = BigRoll.BEAM_HOLD,
		BEAM_HEIGHT = BigRoll.BEAM_HEIGHT,
		FADE = BigRoll.FADE,
		REVEAL_PAD = BigRoll.REVEAL_PAD,
		MIN_AFTER = BigRoll.MIN_AFTER,
		HUB_RADIUS = BigRoll.HUB_RADIUS,
		SPAWN = BigRoll.SPAWN,
		FALLBACK = BigRoll.FALLBACK,
	}
end

local function withFlag(fn: () -> ())
	local previous = LaunchGate.SHOW.bigRollBeam
	LaunchGate.SHOW.bigRollBeam = true
	BigRollBeam.reset()
	local ok, err = pcall(fn)
	LaunchGate.SHOW.bigRollBeam = previous
	BigRollBeam.reset()
	if not ok then
		error(err, 0)
	end
end

local function bucket(): ({ any }, (any) -> ())
	local rows = {}
	local function sink(payload: any)
		table.insert(rows, payload)
	end
	return rows, sink
end

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("Big roll beam", function()
	it("ships the flag off, schema 26, and an Epic threshold", function()
		expect(Schema.VERSION).toEqual(26)
		expect(Schema.template().bigRoll).toBeNil()
		expect(Schema.template().bigRollBeam).toBeNil()
		expect(LaunchGate.SHOW.bigRollBeam).toEqual(false)
		expect(LaunchGate.on("bigRollBeam")).toEqual(false)
		expect(BigRoll.MIN_TIER).toEqual("Epic")
		expect(BigRoll.QUEUE).toEqual(3)
		expect(BigRoll.CHAT_MAX).toEqual(4)
		expect(BigRoll.PLAYER_GAP).toEqual(8)
		local ok, err = BigRoll.validate(BigRoll)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		local schema = fs.readFile("src/ReplicatedStorage/Shared/Schema.luau")
		expect(string.find(schema, "bigRoll", 1, true)).toBeNil()
		local beam = fs.readFile("src/ReplicatedStorage/Shared/BigRollBeam.luau")
		expect(string.find(beam, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(beam, "DataStore", 1, true)).toBeNil()
		expect(string.find(beam, "schemaVersion", 1, true)).toBeNil()
	end)

	it("reads the tier from config", function()
		local legendary = tuned("Legendary")
		expect(BigRoll.validate(legendary)).toBeTrue()
		expect(BigRollBeam.qualifies("Epic", legendary)).toBeFalse()
		expect(BigRollBeam.qualifies("Legendary", legendary)).toBeTrue()
		expect(BigRollBeam.qualifies("Rare", BigRoll)).toBeFalse()
		expect(BigRollBeam.qualifies("Epic", BigRoll)).toBeTrue()
		local broken = tuned("Nope")
		local ok, reason = BigRoll.validate(broken)
		expect(ok).toBeFalse()
		expect(reason).toEqual("MIN_TIER")
		local gap = tuned("Epic")
		gap.GAP = -1
		expect(BigRoll.validate(gap)).toBeFalse()
		withFlag(function()
			local rows, sink = bucket()
			local epic = BigRollBeam.serverRoll({
				userId = 4,
				displayName = "Ada",
				itemName = "Frostbite Edge",
				rarity = "Epic",
				quick = true,
			})
			BigRollBeam.offer(epic, 0, legendary)
			BigRollBeam.pump(10, sink, legendary)
			expect(#rows).toEqual(0)
			local fact = BigRollBeam.serverRoll({
				userId = 4,
				displayName = "Ada",
				itemName = "Frostbite Edge",
				rarity = "Legendary",
				quick = true,
			})
			BigRollBeam.offer(fact, 0, legendary)
			local due = BigRollBeam.delay("Legendary", true, legendary)
			BigRollBeam.pump(due, sink, legendary)
			expect(#rows).toEqual(1)
			expect(rows[1].rarity).toEqual("Legendary")
			BigRollBeam.offer(fact, 0, broken)
			BigRollBeam.pump(due + 30, sink, broken)
			expect(#rows).toEqual(1)
		end)
	end)

	it("fires one announce for a qualifying roll and not before the reveal", function()
		withFlag(function()
			local rows, sink = bucket()
			local fact = BigRollBeam.serverRoll({
				userId = 41,
				displayName = "Ada",
				itemName = "Frostbite Edge",
				rarity = "Epic",
				quick = false,
				x = 0,
				z = 30,
			})
			expect(fact ~= nil).toBeTrue()
			BigRollBeam.offer(fact, 10)
			local due = 10 + BigRollBeam.delay("Epic", false)
			expect(BigRollBeam.delay("Epic", false) > BigRollBeam.delay("Epic", true)).toBeTrue()
			expect(BigRollBeam.delay("Epic", true) >= 0.6).toBeTrue()
			BigRollBeam.pump(due - 0.05, sink)
			expect(#rows).toEqual(0)
			BigRollBeam.pump(due, sink)
			expect(#rows).toEqual(1)
			BigRollBeam.pump(due + 100, sink)
			expect(#rows).toEqual(1)
			local row = rows[1]
			expect(row.kind).toEqual("bigRoll")
			expect(row.userId).toEqual(41)
			expect(row.displayName).toEqual("Ada")
			expect(row.itemName).toEqual("Frostbite Edge")
			expect(row.rarity).toEqual("Epic")
			expect(row.count).toEqual(1)
			expect(row.at).toEqual(10)
			expect(row.beam).toEqual(true)
			expect(row.anchor).toEqual("roller")
			expect(row.height).toEqual(60)
			expect(row.crossServer).toEqual(false)
			expect(row.text).toEqual("✦ **Ada** pulled an **Epic** Frostbite Edge!")
			expect(row.odds).toBeNil()
			expect(row.luck).toBeNil()
			expect(row.x).toBeNil()
			expect(row.client).toBeNil()
		end)
	end)

	it("does not fire for a roll under the threshold", function()
		withFlag(function()
			local rows, sink = bucket()
			for _, rarity in ipairs({ "Common", "Uncommon", "Rare" }) do
				local fact = BigRollBeam.serverRoll({
					userId = 8,
					displayName = "Ada",
					itemName = "Pebble",
					rarity = rarity,
					quick = true,
					clientRarity = "Legendary",
				})
				expect(fact ~= nil).toBeTrue()
				BigRollBeam.offer(fact, 0)
			end
			BigRollBeam.pump(30, sink)
			expect(#rows).toEqual(0)
			local epic = BigRollBeam.serverRoll({
				userId = 8,
				displayName = "Ada",
				itemName = "Frostbite Edge",
				rarity = "Epic",
				quick = true,
			})
			BigRollBeam.offer(epic, 0)
			BigRollBeam.pump(BigRollBeam.delay("Epic", true), sink)
			expect(#rows).toEqual(1)
			expect(rows[1].rarity).toEqual("Epic")
			expect(rows[1].count).toEqual(1)
		end)
	end)

	it("ignores a client fire", function()
		withFlag(function()
			local rows, sink = bucket()
			expect(BigRollBeam.onClient({ UserId = 3, Name = "Ada" }, "Legendary", "Hack")).toBeNil()
			BigRollBeam.offer({
				userId = 3,
				displayName = "Ada",
				itemName = "Hack",
				rarity = "Legendary",
				count = 1,
			}, 0)
			expect(BigRollBeam.serverRoll({
				client = true,
				userId = 3,
				displayName = "Ada",
				itemName = "Hack",
				rarity = "Legendary",
			})).toBeNil()
			BigRollBeam.pump(30, sink)
			expect(#rows).toEqual(0)
			local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
			local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
			local project = fs.readFile("default.project.json")
			expect(string.find(roll, "OnServerEvent", 1, true)).toBeNil()
			expect(string.find(remotes, "RollAnnounce", 1, true)).toBeNil()
			expect(string.find(remotes, "bigRollBeam", 1, true)).toBeNil()
			expect(string.find(project, '"RollAnnounce"', 1, true) ~= nil).toBeTrue()
			expect(string.find(project, "BigRoll", 1, true)).toBeNil()
			local built = between(roll, "local fact = BigRollBeam.serverRoll", "BigRollBeam.offer")
			expect(string.find(built, "poolId", 1, true)).toBeNil()
			expect(string.find(built, "skip", 1, true)).toBeNil()
			expect(string.find(built, "captured", 1, true)).toBeNil()
			local gate = string.find(roll, 'if not LaunchGate.on("bigRollBeam") then', 1, true)
			local offer = string.find(roll, "BigRollBeam.offer", 1, true)
			expect(gate ~= nil and offer ~= nil and (gate :: number) < (offer :: number)).toBeTrue()
			expect(string.find(roll, "captured.rarity", 1, true) ~= nil).toBeTrue()
			expect(string.find(roll, "captured.item.name", 1, true) ~= nil).toBeTrue()
		end)
	end)

	it("caps beams, chat lines, and one player's repeats", function()
		withFlag(function()
			local rows, sink = bucket()
			local due = BigRollBeam.delay("Epic", true)
			for userId = 1, 20 do
				local fact = BigRollBeam.serverRoll({
					userId = userId,
					displayName = "P" .. tostring(userId),
					itemName = "Blade",
					rarity = "Epic",
					quick = true,
					x = 0,
					z = 30,
				})
				BigRollBeam.offer(fact, 0)
			end
			BigRollBeam.pump(due, sink)
			expect(#rows).toEqual(4)
			for _, row in ipairs(rows) do
				expect(row.beam).toEqual(true)
				expect(row.overflow).toBeNil()
			end
			expect(rows[1].beamAt).toEqual(due)
			expect(rows[2].beamAt > due).toBeTrue()
			BigRollBeam.pump(due + BigRoll.CHAT_WINDOW, sink)
			expect(#rows).toEqual(5)
			expect(rows[5].overflow).toEqual(true)
			expect(rows[5].text).toEqual("+16 more big rolls.")
			expect(rows[5].displayName).toBeNil()
			expect(rows[5].beam).toEqual(false)
			BigRollBeam.pump(due + BigRoll.CHAT_WINDOW, sink)
			expect(#rows).toEqual(5)
		end)
		withFlag(function()
			local rows, sink = bucket()
			local wide = tuned("Epic", 10)
			for userId = 1, 8 do
				local fact = BigRollBeam.serverRoll({
					userId = userId,
					displayName = "P" .. tostring(userId),
					itemName = "Blade",
					rarity = "Epic",
					quick = true,
				})
				BigRollBeam.offer(fact, 0, wide)
			end
			local due = BigRollBeam.delay("Epic", true, wide)
			BigRollBeam.pump(due, sink, wide)
			expect(#rows).toEqual(8)
			local beams = 0
			for _, row in ipairs(rows) do
				if row.beam == true then
					beams += 1
				end
			end
			expect(beams).toEqual(4)
		end)
		withFlag(function()
			local rows, sink = bucket()
			for step = 0, 5 do
				local fact = BigRollBeam.serverRoll({
					userId = 9,
					displayName = "Ada",
					itemName = "Frostbite Edge",
					rarity = "Epic",
					quick = true,
				})
				BigRollBeam.offer(fact, step * 0.1)
			end
			local due = BigRollBeam.delay("Epic", true)
			BigRollBeam.pump(due, sink)
			expect(#rows).toEqual(1)
			expect(rows[1].count).toEqual(6)
			expect(rows[1].text).toEqual("✦ **Ada** pulled 6 Epics!")
			BigRollBeam.pump(due + 100, sink)
			expect(#rows).toEqual(1)
		end)
		withFlag(function()
			local rows, sink = bucket()
			local epic = BigRollBeam.serverRoll({
				userId = 3,
				displayName = "Ada",
				itemName = "Frostbite Edge",
				rarity = "Epic",
				quick = true,
				x = 0,
				z = 30,
			})
			local legendary = BigRollBeam.serverRoll({
				userId = 3,
				displayName = "Ada",
				itemName = "Frostbite Edge",
				rarity = "Legendary",
				quick = true,
				x = 1000,
				z = 30,
			})
			BigRollBeam.offer(epic, 0)
			BigRollBeam.offer(legendary, 1)
			local epicDue = BigRollBeam.delay("Epic", true)
			BigRollBeam.pump(epicDue, sink)
			expect(#rows).toEqual(1)
			expect(rows[1].rarity).toEqual("Epic")
			BigRollBeam.pump(2, sink)
			expect(#rows).toEqual(1)
			BigRollBeam.pump(BigRoll.PLAYER_GAP, sink)
			expect(#rows).toEqual(2)
			expect(rows[2].rarity).toEqual("Legendary")
			expect(rows[2].beam).toEqual(true)
			expect(rows[2].anchor).toEqual("crackstone")
			expect(rows[2].height).toEqual(80)
			expect(rows[2].text).toEqual("★ **Ada** pulled a **LEGENDARY** Frostbite Edge!")
		end)
		withFlag(function()
			local rows, sink = bucket()
			local due = BigRollBeam.delay("Epic", true)
			for step = 0, 5 do
				local fact = BigRollBeam.serverRoll({
					userId = 12,
					displayName = "Ada",
					itemName = "Blade",
					rarity = "Epic",
					quick = true,
				})
				local at = step * BigRoll.PLAYER_GAP
				BigRollBeam.offer(fact, at)
				BigRollBeam.pump(at + due, sink)
			end
			expect(#rows).toEqual(6)
			expect(rows[5].beam).toEqual(true)
			expect(rows[6].beam).toEqual(false)
			expect(rows[6].text).toEqual("✦ **Ada** pulled an **Epic** Blade!")
		end)
	end)

	it("announces one x10 line for the best tier", function()
		withFlag(function()
			local rows, sink = bucket()
			local fact = BigRollBeam.serverRoll({
				userId = 15,
				displayName = "Ada",
				itemName = "Frostbite Edge",
				rarity = "Legendary",
				count = 3,
				epicCount = 2,
				quick = true,
			})
			BigRollBeam.offer(fact, 0)
			BigRollBeam.pump(BigRollBeam.delay("Legendary", true), sink)
			expect(#rows).toEqual(1)
			expect(rows[1].count).toEqual(3)
			expect(rows[1].text).toEqual("★ **Ada** pulled a **LEGENDARY** and 2 Epics!")
			BigRollBeam.pump(100, sink)
			expect(#rows).toEqual(1)
		end)
	end)

	it("does nothing while the flag is off, including a roll already queued", function()
		local previous = LaunchGate.SHOW.bigRollBeam
		LaunchGate.SHOW.bigRollBeam = false
		BigRollBeam.reset()
		local rows, sink = bucket()
		local early = BigRollBeam.serverRoll({
			userId = 6,
			displayName = "Ada",
			itemName = "Frostbite Edge",
			rarity = "Legendary",
			quick = true,
		})
		BigRollBeam.offer(early, 0)
		BigRollBeam.pump(30, sink)
		expect(#rows).toEqual(0)
		LaunchGate.SHOW.bigRollBeam = true
		BigRollBeam.offer(early, 0)
		local due = BigRollBeam.delay("Legendary", true)
		LaunchGate.SHOW.bigRollBeam = false
		BigRollBeam.pump(due + 5, sink)
		expect(#rows).toEqual(0)
		LaunchGate.SHOW.bigRollBeam = true
		BigRollBeam.pump(due + 5, sink)
		expect(#rows).toEqual(0)
		local again = BigRollBeam.serverRoll({
			userId = 6,
			displayName = "Ada",
			itemName = "Frostbite Edge",
			rarity = "Epic",
			quick = true,
		})
		BigRollBeam.offer(again, 0)
		BigRollBeam.pump(BigRollBeam.delay("Epic", true), sink)
		expect(#rows).toEqual(1)
		expect(rows[1].rarity).toEqual("Epic")
		LaunchGate.SHOW.bigRollBeam = previous
		BigRollBeam.reset()
		expect(LaunchGate.SHOW.bigRollBeam).toEqual(false)
	end)
end)
