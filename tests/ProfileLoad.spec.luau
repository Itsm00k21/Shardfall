--!strict

--[[
	The Studio load that was stuck on "Profile is still loading."

	An older save has to come forward to the current schema. A DataStore
	that throws (API access off) has to resolve as a session profile instead
	of never returning.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local MemoryStore = require("../src/ReplicatedStorage/Shared/MemoryStore")
local ProfileLoad = require("../src/ReplicatedStorage/Shared/ProfileLoad")
local Progression = require("../src/ReplicatedStorage/Shared/Progression")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")

describe("Profile load", function()
	it("opens a missing key as a new profile", function()
		local now = 1_700_000_000
		local store = MemoryStore.new()
		local opened = ProfileLoad.open(
			store,
			"Player_new",
			now,
			"studio-test",
			0,
			SessionLock.TIMEOUT_SECONDS
		)
		expect(opened.session).toBeFalse()
		expect(opened.reason).toEqual("claimed")
		expect(opened.data.onboardDone).toEqual(false)
		expect(opened.data.onboardStep).toEqual("open")
		expect(opened.data.firstSession.returning).toEqual(false)
		expect(opened.data.schemaVersion).toEqual(Schema.VERSION)
		expect(opened.data.shardTokens).toEqual(Schema.STARTER_TOKENS)
		local held = nil
		store:updateAsync("Player_new", function(current)
			held = current
			return nil
		end)
		expect(held.Data.onboardDone).toEqual(false)
		expect(held.Data.onboardStep).toEqual("open")
		expect(held.Data.firstSession.returning).toEqual(false)
		expect(held.Data.shardTokens).toEqual(Schema.STARTER_TOKENS)
	end)

	it("keeps a versionless save and pays the welcome chest from its lastSeen", function()
		local now = 1_700_000_000
		local seen = now - Progression.WELCOME_GAP - 10
		local store = MemoryStore.new()
		local document = {
			Data = {
				gold = 40,
				shardTokens = 100,
				gems = 9,
				raidMarks = 12,
				lastSeen = seen,
				companions = {
					{ species = "shardjaw", name = "Shardjaw" },
				},
				codex = { unlocked = { attack = true } },
				inventory = {
					abc = { uid = "abc", name = "Wooden Sword", kind = "Weapon" },
				},
			},
			Lock = {
				jobId = "",
				placeId = 0,
				lockedAt = 0,
			},
		}
		store:updateAsync("Player_versionless", function()
			return document
		end)
		local opened = ProfileLoad.open(
			store,
			"Player_versionless",
			now,
			"studio-test",
			0,
			SessionLock.TIMEOUT_SECONDS
		)
		expect(opened.session).toBeFalse()
		expect(opened.reason).toEqual("claimed")
		expect(opened.data.gold).toEqual(40)
		expect(opened.data.shardTokens).toEqual(100)
		expect(opened.data.gems).toEqual(9)
		expect(opened.data.raidMarks).toEqual(12)
		expect(opened.data.companions[1].species).toEqual("shardjaw")
		expect(opened.data.codex.unlocked.attack).toEqual(true)
		expect(opened.data.inventory.abc.name).toEqual("Wooden Sword")
		expect(opened.data.chests.Rare).toEqual(1)
		expect(opened.data.welcomeCharges).toEqual(Progression.WELCOME_CHARGES)
		local held = nil
		store:updateAsync("Player_versionless", function(current)
			held = current
			return nil
		end)
		expect(held.Data.gold).toEqual(40)
		expect(held.Data.gems).toEqual(9)
		expect(held.Data.raidMarks).toEqual(12)
		expect(held.Data.companions[1].species).toEqual("shardjaw")
		expect(held.Data.codex.unlocked.attack).toEqual(true)
		expect(held.Data.inventory.abc.name).toEqual("Wooden Sword")
		expect(held.Data.chests.Rare).toEqual(1)
		expect(held.Lock.jobId).toEqual("studio-test")
	end)

	it("does not claim a profile whose bag is not a table", function()
		local now = 1_700_000_000
		local store = MemoryStore.new()
		local document = {
			Data = {
				schemaVersion = 26,
				gold = 10,
				inventory = "nope",
				equipped = { weapon = "abc" },
			},
			Lock = {
				jobId = "",
				placeId = 0,
				lockedAt = 0,
			},
		}
		store:updateAsync("Player_corrupt", function()
			return document
		end)
		local opened = ProfileLoad.open(
			store,
			"Player_corrupt",
			now,
			"studio-test",
			0,
			SessionLock.TIMEOUT_SECONDS
		)
		expect(opened.session).toBeFalse()
		expect(opened.reason).toEqual("corrupt")
		expect(opened.data).toBeNil()
		local held = nil
		store:updateAsync("Player_corrupt", function(current)
			held = current
			return nil
		end)
		expect(held.Data.gold).toEqual(10)
		expect(held.Data.inventory).toEqual("nope")
		expect(held.Data.equipped.weapon).toEqual("abc")
		expect(held.Data.schemaVersion).toEqual(26)
		expect(held.Lock.jobId).toEqual("")
	end)

	it("migrates an older schema and falls back when the DataStore throws", function()
		local now = 1_700_000_000
		local stored = {
			Data = {
				schemaVersion = 19,
				gold = 80,
				level = 6,
				shardTokens = 12,
				lastSeen = now - 10,
			},
			Lock = {
				jobId = "",
				placeId = 0,
				lockedAt = 0,
			},
		}
		local saved = {
			persistent = true,
			updateAsync = function(_self, _key, transform)
				local updated = transform(stored)
				if updated ~= nil then
					stored = updated
				end
				return stored
			end,
		}
		local opened =
			ProfileLoad.open(saved, "Player_1", now, "studio-test", 0, SessionLock.TIMEOUT_SECONDS)
		expect(opened.session).toBeFalse()
		expect(opened.reason).toEqual("claimed")
		expect(opened.data.schemaVersion).toEqual(Schema.VERSION)
		expect(opened.data.schemaVersion).toEqual(26)
		expect(opened.data.gold).toEqual(80)
		expect(opened.data.level).toEqual(6)
		expect(opened.data.shardTokens).toEqual(12)
		expect(opened.data.tradeDay).toEqual(0)
		expect(opened.data.tradeValueToday).toEqual(0)
		expect(opened.data.tradeLocked).toBeFalse()
		expect(opened.data.tradeFlagged).toBeFalse()
		expect(stored.Data.schemaVersion).toEqual(Schema.VERSION)
		expect(stored.Data.gold).toEqual(80)
		expect(stored.Lock.jobId).toEqual("studio-test")

		local failing = {
			persistent = true,
			updateAsync = function(_self, _key, _transform)
				error("StudioAccessToApisNotAllowed: API access is not enabled", 0)
			end,
		}
		local session = ProfileLoad.open(
			failing,
			"Player_1",
			now,
			"studio-test",
			0,
			SessionLock.TIMEOUT_SECONDS
		)
		expect(session.session).toBeTrue()
		expect(session.reason).toEqual("session")
		expect(string.find(session.error or "", "API access", 1, true) ~= nil).toBeTrue()
		expect(session.data.schemaVersion).toEqual(Schema.VERSION)
		expect(session.data.gold).toEqual(0)
		expect(session.data.shardTokens).toEqual(Schema.STARTER_TOKENS)
		expect(session.data.tradeLocked).toBeFalse()
		expect(session.data.level).toEqual(1)
	end)
end)
