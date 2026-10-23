--!strict

--[[
	Phase 0.8 analytics. The rules live in AnalyticsLogic so they run
	without Studio. The service file is checked as source: it pcalls,
	it does not wait, and it does not read a player name or a save.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Analytics = require("../src/ReplicatedStorage/Shared/Config/Analytics")
local AnalyticsLogic = require("../src/ReplicatedStorage/Shared/AnalyticsLogic")
local DevTools = require("../src/ReplicatedStorage/Shared/DevTools")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Onboarding = require("../src/ReplicatedStorage/Shared/Onboarding")

local SERVICE = "src/ServerScriptService/ShardfallServer/AnalyticsService.luau"

local function call(state, request)
	local eventName = request.eventName
	if eventName == nil and request.funnelId == nil then
		eventName = "session_start"
	end
	return AnalyticsLogic.prepare(state, {
		gateOn = if request.gateOn ~= nil then request.gateOn else true,
		configOn = if request.configOn ~= nil then request.configOn else true,
		sampleRate = if request.sampleRate ~= nil then request.sampleRate else 1,
		rateLimit = if request.rateLimit ~= nil then request.rateLimit else 30,
		rateWindow = if request.rateWindow ~= nil then request.rateWindow else 10,
		recentLimit = if request.recentLimit ~= nil then request.recentLimit else 20,
		now = if request.now ~= nil then request.now else 1000,
		userId = if request.userId ~= nil then request.userId else 42,
		eventName = eventName,
		funnelId = request.funnelId,
		stepId = request.stepId,
		fields = request.fields,
	})
end

local function sendOf(result)
	local send = result.send
	if send == nil then
		error("expected a send payload", 0)
	end
	return send
end

describe("Analytics catalog", function()
	it("ships both switches off and a full sample", function()
		expect(Analytics.ENABLED).toEqual(false)
		expect(Analytics.SAMPLE_RATE).toEqual(1)
		expect(Analytics.RATE_LIMIT).toEqual(30)
		expect(Analytics.RATE_WINDOW_SEC).toEqual(10)
		expect(Analytics.RECENT_LIMIT).toEqual(20)
		expect(LaunchGate.SHOW.analytics).toEqual(false)
		expect(LaunchGate.on("analytics")).toEqual(false)
	end)

	it("lists the earned currencies and refuses a paid wallet", function()
		expect(Analytics.CURRENCIES).toEqual({
			"shardTokens",
			"gold",
			"shardKeys",
			"shardDust",
			"fragments",
		})
		local allowed = { Gameplay = true, Shop = true, TimedReward = true, Onboarding = true }
		for _, map in ipairs({ Analytics.SOURCE_REASONS, Analytics.SINK_REASONS }) do
			for _, transaction in pairs(map) do
				expect(allowed[transaction]).toEqual(true)
			end
		end
		expect(Analytics.SOURCE_REASONS.run).toEqual("Gameplay")
		expect(Analytics.SINK_REASONS.roll_x1).toEqual("Gameplay")
		expect(Analytics.SINK_REASONS.roll_x10).toEqual("Gameplay")
		expect(Analytics.LEAVE_REASONS).toEqual({ "left", "died", "cleared" })
		local catalog = fs.readFile("src/ReplicatedStorage/Shared/Config/Analytics.luau")
		expect(string.find(catalog, "prism", 1, true)).toBeNil()
		expect(string.find(catalog, "IAP", 1, true)).toBeNil()
	end)

	it("keeps event ids unique and required fields on the allowlist", function()
		local seen = {}
		local ids = {}
		for _, event in ipairs(Analytics.EVENT_LIST) do
			expect(seen[event.id]).toBeNil()
			seen[event.id] = true
			table.insert(ids, event.id)
			local allow = {}
			for _, key in ipairs(event.fields) do
				allow[key] = true
			end
			for _, key in ipairs(event.required) do
				expect(allow[key]).toEqual(true)
			end
			if event.valueFrom ~= "" then
				expect(allow[event.valueFrom]).toEqual(true)
			end
		end
		expect(ids).toEqual({
			"session_start",
			"session_end",
			"roll_x1",
			"roll_x10",
			"rarity_pulled",
			"dungeon_enter",
			"dungeon_clear",
			"dungeon_leave",
			"wave_enter",
			"wave_clear",
			"wave_leave",
			"element_equipped",
			"auto_equip_undo",
			"buff_picked",
			"currency_source",
			"currency_sink",
		})
	end)

	it("numbers each funnel from 1 and follows the live tutorial", function()
		local onboarding = 0
		for _, funnel in pairs(Analytics.FUNNELS) do
			if funnel.roblox == "onboarding" then
				onboarding += 1
				expect(funnel.id).toEqual("first_session")
			end
			local seen = {}
			for index, row in ipairs(funnel.steps) do
				expect(row.step).toEqual(index)
				expect(seen[row.id]).toBeNil()
				seen[row.id] = true
				expect(string.find(row.name, ",", 1, true)).toBeNil()
			end
		end
		expect(onboarding).toEqual(1)
		expect(Analytics.FUNNELS.tutorial.roblox).toEqual("funnel")
		expect(Analytics.FUNNELS.first_roll.roblox).toEqual("funnel")
		local tutorial = {}
		for _, row in ipairs(Analytics.FUNNELS.tutorial.steps) do
			tutorial[row.id] = true
		end
		for _, row in ipairs(Onboarding.STEPS) do
			expect(tutorial[row.id]).toEqual(true)
		end
		expect(tutorial.joined).toEqual(true)
		expect(tutorial.done).toEqual(true)
		local session = {}
		for _, row in ipairs(Analytics.FUNNELS.first_session.steps) do
			table.insert(session, row.id)
		end
		expect(session).toEqual({
			"joined",
			"first_roll",
			"first_equip",
			"entered_gate",
			"cleared_wave_1",
			"finished_first_run",
			"second_roll",
			"second_run",
		})
		local roll = {}
		for _, row in ipairs(Analytics.FUNNELS.first_roll.steps) do
			table.insert(roll, row.id)
		end
		expect(roll).toEqual({ "open", "roll_x1", "reveal", "equip" })
	end)
end)

describe("Analytics decisions", function()
	it("does nothing when either switch is off", function()
		local state = AnalyticsLogic.newState()
		local off = call(state, {
			gateOn = false,
			fields = { name = "Ada" },
			userId = nil,
			now = 0 / 0,
		})
		expect(off.status).toEqual("disabled")
		expect(off.ok).toEqual(false)
		expect(#state.recent).toEqual(0)
		expect(AnalyticsLogic.slots(state, 42)).toEqual(0)
		expect(call(state, { configOn = false }).status).toEqual("disabled")
		expect(AnalyticsLogic.disabledReason(false, true)).toEqual(
			"Analytics is off (LaunchGate.analytics)."
		)
		expect(AnalyticsLogic.disabledReason(true, false)).toEqual(
			"Analytics is off (Config.Analytics.ENABLED)."
		)
		expect(AnalyticsLogic.disabledReason(true, true)).toBeNil()
	end)

	it("refuses a name, a display name, and a UserId field", function()
		local state = AnalyticsLogic.newState()
		for _, fields in ipairs({
			{ name = "Ada" },
			{ DisplayName = "Ada" },
			{ username = "Ada" },
			{ userId = 42 },
			{ UserId = 42 },
		}) do
			local result = call(state, { eventName = "roll_x1", fields = fields })
			expect(result.status).toEqual("pii")
			expect(result.send).toBeNil()
		end
		expect(#state.recent).toEqual(0)
		expect(AnalyticsLogic.slots(state, 42)).toEqual(0)
	end)

	it("accepts a catalog event and packs at most three custom fields", function()
		local state = AnalyticsLogic.newState()
		local result = call(state, {
			eventName = "rarity_pulled",
			fields = { rarity = "Rare", pool = "verdant_armory", count = 2 },
		})
		expect(result.status).toEqual("ok")
		local send = sendOf(result)
		expect(send.kind).toEqual("custom")
		expect(send.name).toEqual("rarity_pulled")
		expect(send.value).toEqual(2)
		expect(send.custom).toEqual({ "rarity=Rare", "pool=verdant_armory" })
		expect(AnalyticsLogic.customFields(send.custom)).toEqual({
			CustomField01 = "rarity=Rare",
			CustomField02 = "pool=verdant_armory",
		})
		expect(AnalyticsLogic.customFields({})).toBeNil()
		expect(AnalyticsLogic.customFields({ "a", "b", "c", "d" })).toEqual({
			CustomField01 = "a",
			CustomField02 = "b",
			CustomField03 = "c",
		})
		local x10 = sendOf(call(state, {
			eventName = "roll_x10",
			fields = { pool = "verdant_armory", price = 9 },
		}))
		expect(x10.value).toEqual(10)
		expect(x10.custom).toEqual({ "pool=verdant_armory", "price=9" })
	end)

	it("rejects an unknown event, a bad rarity, and a non token", function()
		local state = AnalyticsLogic.newState()
		expect(call(state, { eventName = "not_an_event" }).status).toEqual("unknown")
		expect(call(state, { eventName = "rarity_pulled", fields = { rarity = "rare" } }).status).toEqual(
			"invalid"
		)
		expect(call(state, {
			eventName = "dungeon_enter",
			fields = { dungeon = "root vault" },
		}).status).toEqual("invalid")
		expect(call(state, { eventName = "session_end" }).status).toEqual("invalid")
		expect(call(state, { eventName = "session_end", fields = { seconds = 12 } }).status).toEqual(
			"ok"
		)
		expect(call(state, { userId = 1.5 }).status).toEqual("invalid")
		expect(call(state, { now = 0 / 0 }).status).toEqual("invalid")
		expect(#state.recent).toEqual(1)
	end)

	it("maps sources and sinks and drops a paid currency", function()
		local state = AnalyticsLogic.newState()
		local source = sendOf(call(state, {
			eventName = "currency_source",
			fields = { currency = "shardTokens", amount = 11, balance = 21, reason = "run" },
		}))
		expect(source.kind).toEqual("economy")
		expect(source.flow).toEqual("source")
		expect(source.currency).toEqual("shardTokens")
		expect(source.amount).toEqual(11)
		expect(source.balance).toEqual(21)
		expect(source.transaction).toEqual("Gameplay")
		expect(source.sku).toEqual("run")
		expect(source.custom).toEqual({})
		local sink = sendOf(call(state, {
			eventName = "currency_sink",
			fields = { currency = "gold", amount = 150, balance = 0, reason = "forge" },
		}))
		expect(sink.flow).toEqual("sink")
		expect(sink.transaction).toEqual("Gameplay")
		expect(call(state, {
			eventName = "currency_sink",
			fields = { currency = "prismTokens", amount = 1, balance = 0, reason = "roll_x1" },
		}).status).toEqual("invalid")
		expect(call(state, {
			eventName = "currency_source",
			fields = { currency = "gold", amount = 1, balance = 1, reason = "roll_x1" },
		}).status).toEqual("invalid")
		expect(call(state, {
			eventName = "currency_sink",
			fields = { currency = "shardTokens", amount = 0, balance = 0, reason = "roll_x1" },
		}).status).toEqual("invalid")
		expect(call(state, {
			eventName = "dungeon_leave",
			fields = { dungeon = "rootvault", reason = "left" },
		}).status).toEqual("ok")
		expect(call(state, {
			eventName = "wave_leave",
			fields = { dungeon = "rootvault", wave = 3, reason = "died" },
		}).status).toEqual("ok")
		expect(call(state, {
			eventName = "dungeon_leave",
			fields = { dungeon = "rootvault", reason = "quit" },
		}).status).toEqual("invalid")
	end)

	it("keeps a funnel step once and does not spend a rate slot on it", function()
		local state = AnalyticsLogic.newState()
		local first = call(state, { funnelId = "tutorial", stepId = "swing", rateLimit = 1 })
		expect(first.status).toEqual("ok")
		local send = sendOf(first)
		expect(send.kind).toEqual("funnel")
		expect(send.roblox).toEqual("funnel")
		expect(send.funnelName).toEqual("Tutorial")
		expect(send.step).toEqual(4)
		expect(send.stepName).toEqual("First swing")
		expect(send.label).toEqual("tutorial:swing")
		expect(call(state, { funnelId = "tutorial", stepId = "swing" }).status).toEqual("duplicate")
		expect(AnalyticsLogic.slots(state, 42)).toEqual(0)
		expect(#state.recent).toEqual(1)
		local session = sendOf(call(state, { funnelId = "first_session", stepId = "joined" }))
		expect(session.roblox).toEqual("onboarding")
		expect(session.step).toEqual(1)
		expect(call(state, { funnelId = "missing", stepId = "joined" }).status).toEqual("unknown")
		expect(call(state, { funnelId = "first_roll", stepId = "nope" }).status).toEqual("invalid")
		expect(call(state, {
			eventName = "session_start",
			funnelId = "tutorial",
			stepId = "open",
		}).status).toEqual("invalid")
		AnalyticsLogic.forget(state, 42)
		expect(call(state, { funnelId = "tutorial", stepId = "swing" }).status).toEqual("duplicate")
	end)
end)

describe("Analytics sampling and rate", function()
	it("samples by UserId and stays on that side", function()
		expect(AnalyticsLogic.inSample(1, 1)).toEqual(true)
		expect(AnalyticsLogic.inSample(9999, 1)).toEqual(true)
		expect(AnalyticsLogic.inSample(1, 0)).toEqual(false)
		expect(AnalyticsLogic.inSample(4999, 0.5)).toEqual(true)
		expect(AnalyticsLogic.inSample(5000, 0.5)).toEqual(false)
		expect(AnalyticsLogic.inSample(-4999, 0.5)).toEqual(true)
		expect(AnalyticsLogic.inSample(-5000, 0.5)).toEqual(false)
		expect(AnalyticsLogic.inSample(1, 0 / 0)).toEqual(false)
		local state = AnalyticsLogic.newState()
		expect(call(state, { userId = 5000, sampleRate = 0.5 }).status).toEqual("sample")
		expect(#state.recent).toEqual(0)
		expect(call(state, { userId = 5000, sampleRate = 0.5 }).status).toEqual("sample")
		expect(call(state, { userId = 4999, sampleRate = 0.5 }).status).toEqual("ok")
	end)

	it("drops the burst and accepts again after the window", function()
		local state = AnalyticsLogic.newState()
		expect(call(state, { now = 1000, rateLimit = 2, rateWindow = 10 }).status).toEqual("ok")
		expect(call(state, { now = 1001, rateLimit = 2, rateWindow = 10 }).status).toEqual("ok")
		local dropped = call(state, { now = 1002, rateLimit = 2, rateWindow = 10 })
		expect(dropped.status).toEqual("rate")
		expect(dropped.send).toBeNil()
		expect(AnalyticsLogic.slots(state, 42)).toEqual(2)
		expect(state.recent[3].status).toEqual("rate")
		-- 1000 is ten seconds old, so it leaves the window. 1001 stays.
		expect(call(state, { now = 1010, rateLimit = 2, rateWindow = 10 }).status).toEqual("ok")
		expect(AnalyticsLogic.slots(state, 42)).toEqual(2)
		local funnel = call(state, {
			funnelId = "first_roll",
			stepId = "roll_x1",
			now = 1010,
			rateLimit = 1,
		})
		expect(funnel.status).toEqual("ok")
		expect(AnalyticsLogic.slots(state, 42)).toEqual(2)
	end)

	it("keeps the last 20 rows and can mark an engine failure", function()
		local state = AnalyticsLogic.newState()
		local lastId = 0
		for index = 1, 25 do
			local result = call(state, { now = index, rateLimit = 100, recentLimit = 20 })
			expect(result.status).toEqual("ok")
			lastId = result.rowId or 0
		end
		expect(#state.recent).toEqual(20)
		expect(state.recent[1].id).toEqual(6)
		expect(state.recent[20].id).toEqual(25)
		expect(lastId).toEqual(25)
		local text = AnalyticsLogic.formatRecent(state, 20)
		expect(string.find(text, "ok 42 session_start\n", 1, true)).toEqual(1)
		local breaks = 0
		for _ in string.gmatch(text, "\n") do
			breaks += 1
		end
		expect(breaks).toEqual(19)
		AnalyticsLogic.mark(state, 25, "engine")
		expect(state.recent[20].status).toEqual("engine")
		expect(
			string.find(AnalyticsLogic.formatRecent(state, 20), "engine 42 session_start", 1, true)
				~= nil
		).toBeTrue()
		expect(AnalyticsLogic.safeCall(function() end)).toEqual(true)
		local ok, err = AnalyticsLogic.safeCall(function()
			error("boom")
		end)
		expect(ok).toEqual(false)
		expect(string.find(err or "", "boom", 1, true) ~= nil).toBeTrue()
	end)
end)

describe("Analytics service shell", function()
	it("pcalls the engine, never waits, and reads only the UserId", function()
		local source = fs.readFile(SERVICE)
		expect(string.find(source, "AnalyticsLogic.safeCall(", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "task.spawn(", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "LogCustomEvent", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "LogEconomyEvent", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "LogFunnelStepEvent", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "LogOnboardingFunnelStepEvent", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'LaunchGate.on("analytics")', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "Analytics.ENABLED", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'track(player, "session_start"', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'track(player, "session_end"', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'funnel(player, "tutorial", "joined")', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'funnel(player, "first_session", "joined")', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "function AnalyticsService.printRecent", 1, true) ~= nil).toBeTrue()
		local banned = {
			"task.wait",
			"wait(",
			"WaitForChild",
			"GetPlayerSegmentsAsync",
			"DataStore",
			"UpdateAsync",
			"DataService",
			"Schema",
			"player.Name",
			"DisplayName",
			"GetNameFromUserId",
			".Name",
			"HttpService",
			"RollService",
			"InventoryService",
			"DungeonService",
			"GearService",
			"Remotes",
		}
		for _, needle in ipairs(banned) do
			expect(string.find(source, needle, 1, true)).toBeNil()
		end
	end)

	it("hides the dev print while analytics is off", function()
		local found = nil
		for _, section in ipairs(DevTools.SECTIONS) do
			for _, item in ipairs(section.entries) do
				if item.id == "analytics" then
					found = item
				end
			end
		end
		expect(found ~= nil).toBeTrue()
		local button = found :: any
		expect(button.label).toEqual("Print last 20 events")
		expect(button.remote).toEqual("Debug")
		expect(button.arg).toEqual("analytics")
		expect(DevTools.visible(button)).toEqual(false)
		expect(DevTools.blocked("Debug", "analytics")).toEqual(
			"Analytics is off (LaunchGate.analytics), so this does nothing yet."
		)
		local function onlyAnalytics(flag: string): boolean
			return flag == "analytics"
		end
		expect(DevTools.visible(button, onlyAnalytics)).toEqual(true)
	end)
end)
