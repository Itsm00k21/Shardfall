--!strict

--[[
	Phase 0.8 analytics catalog. Data only.

	Nothing here sends an event, reads a profile, or writes a save.
	ENABLED stays false. LaunchGate.analytics stays false too.
	AnalyticsService sends only when both are true.

	SAMPLE_RATE is the share of UserIds whose session is kept, from 0
	to 1. It is sticky per UserId, so a funnel is all in or all out.
	1 records every player once the switches are on.

	Ids are stable. Add a new one; do not rename or reuse one.
	Field values are short catalog ids. Never a player name.
]]

local Analytics = {}

Analytics.VERSION = "v1"

Analytics.ENABLED = false
Analytics.SAMPLE_RATE = 1
Analytics.RATE_LIMIT = 30
Analytics.RATE_WINDOW_SEC = 10
Analytics.RECENT_LIMIT = 20

-- Earned wallets only. Five is the Roblox currency cap. No paid wallet.
Analytics.CURRENCIES = table.freeze({
	"shardTokens",
	"gold",
	"shardKeys",
	"shardDust",
	"fragments",
})

-- reason id -> engine transaction name. Gameplay, shop, and rewards only.
Analytics.SOURCE_REASONS = table.freeze({
	run = "Gameplay",
	wave = "Gameplay",
	free_roll = "Onboarding",
	daily = "TimedReward",
	tutorial = "Onboarding",
})

Analytics.SINK_REASONS = table.freeze({
	roll_x1 = "Gameplay",
	roll_x10 = "Gameplay",
	forge = "Gameplay",
	gold_shop = "Shop",
})

Analytics.LEAVE_REASONS = table.freeze({ "left", "died", "cleared" })

local leaveSet: { [string]: boolean } = {}
for _, reason in ipairs(Analytics.LEAVE_REASONS) do
	leaveSet[reason] = true
end
local LEAVE = table.freeze(leaveSet)
local NO_REASONS = table.freeze({} :: { [string]: boolean })

type Row = {
	id: string,
	kind: string,
	flow: string,
	fields: { string },
	required: { string },
	valueFrom: string,
	value: number,
	reasons: { [string]: boolean },
}

local function custom(
	id: string,
	fields: { string },
	required: { string },
	valueFrom: string,
	value: number,
	reasons: { [string]: boolean }?
): Row
	return table.freeze({
		id = id,
		kind = "custom",
		flow = "",
		fields = table.freeze(fields),
		required = table.freeze(required),
		valueFrom = valueFrom,
		value = value,
		reasons = if reasons ~= nil then reasons else NO_REASONS,
	})
end

local function economy(id: string, flow: string): Row
	return table.freeze({
		id = id,
		kind = "economy",
		flow = flow,
		fields = table.freeze({ "currency", "amount", "balance", "reason" }),
		required = table.freeze({ "currency", "amount", "balance", "reason" }),
		valueFrom = "",
		value = 1,
		reasons = NO_REASONS,
	})
end

Analytics.EVENT_LIST = table.freeze({
	custom("session_start", {}, {}, "", 1, nil),
	custom("session_end", { "seconds" }, { "seconds" }, "seconds", 0, nil),
	custom("roll_x1", { "pool" }, {}, "", 1, nil),
	custom("roll_x10", { "pool", "price" }, {}, "", 10, nil),
	custom("rarity_pulled", { "rarity", "pool", "count" }, { "rarity" }, "count", 1, nil),
	custom("dungeon_enter", { "dungeon", "difficulty" }, { "dungeon" }, "", 1, nil),
	custom("dungeon_clear", { "dungeon", "difficulty" }, { "dungeon" }, "", 1, nil),
	custom("dungeon_leave", { "dungeon", "reason" }, { "dungeon", "reason" }, "", 1, LEAVE),
	custom("wave_enter", { "dungeon", "wave" }, { "dungeon", "wave" }, "wave", 1, nil),
	custom("wave_clear", { "dungeon", "wave" }, { "dungeon", "wave" }, "wave", 1, nil),
	custom(
		"wave_leave",
		{ "dungeon", "wave", "reason" },
		{ "dungeon", "wave", "reason" },
		"wave",
		1,
		LEAVE
	),
	custom("element_equipped", { "element", "slot" }, { "element" }, "", 1, nil),
	custom("auto_equip_undo", { "slot" }, {}, "", 1, nil),
	custom("buff_picked", { "buff" }, { "buff" }, "", 1, nil),
	economy("currency_source", "source"),
	economy("currency_sink", "sink"),
})

export type FunnelStep = { step: number, id: string, name: string }
export type Funnel = { id: string, roblox: string, name: string, steps: { FunnelStep } }

local function step(index: number, id: string, label: string): FunnelStep
	return table.freeze({ step = index, id = id, name = label })
end

local function funnel(id: string, roblox: string, name: string, steps: { FunnelStep }): Funnel
	return table.freeze({
		id = id,
		roblox = roblox,
		name = name,
		steps = table.freeze(steps),
	})
end

-- roblox = "onboarding" is LogOnboardingFunnelStepEvent (one per experience).
-- roblox = "funnel" is LogFunnelStepEvent. Step numbers start at 1 and
-- stay put. Do not reuse a number.
local funnels: { [string]: Funnel } = {
	tutorial = funnel("tutorial", "funnel", "Tutorial", {
		step(1, "joined", "Joined"),
		step(2, "open", "Cold open"),
		step(3, "class", "Class"),
		step(4, "swing", "First swing"),
		step(5, "dodge", "Dodge"),
		step(6, "door", "Door"),
		step(7, "haven", "Haven"),
		step(8, "done", "Tutorial done"),
	}),
	first_roll = funnel("first_roll", "funnel", "FirstRoll", {
		step(1, "open", "Open roll"),
		step(2, "roll_x1", "First crack"),
		step(3, "reveal", "Reveal"),
		step(4, "equip", "Equip"),
	}),
	-- Roadmap onboarding funnel, in that order.
	first_session = funnel("first_session", "onboarding", "Onboarding", {
		step(1, "joined", "Joined"),
		step(2, "first_roll", "First roll"),
		step(3, "first_equip", "First equip"),
		step(4, "entered_gate", "Entered gate"),
		step(5, "cleared_wave_1", "Cleared wave 1"),
		step(6, "finished_first_run", "Finished first run"),
		step(7, "second_roll", "Second roll"),
		step(8, "second_run", "Second run"),
	}),
}

Analytics.FUNNELS = table.freeze(funnels)

return table.freeze(Analytics)
