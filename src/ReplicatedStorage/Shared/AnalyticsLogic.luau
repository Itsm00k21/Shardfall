--!strict

--[[
	Phase 0.8 analytics rules. No Roblox services, no saves, no yields.

	AnalyticsService asks prepare() before it touches the engine.
	prepare validates the catalog, applies the sticky UserId sample,
	rate-limits per player, and keeps the last 20 rows for the dev print.
	A disabled call returns before any of that and does not touch state.

	safeCall is the pcall wrapper around the engine. The service spawns
	it so a slow or throwing call cannot stall gameplay.

	Custom fields carry catalog ids only. A name, display name, or
	UserId key is refused. The UserId stays on the player argument.
]]

local Analytics = require("./Config/Analytics")

local AnalyticsLogic = {}

local MAX_LINES = 20
local TOKEN = "^[%w_%-%.]+$"

local RANGE: { [string]: { number } } = {
	wave = { 1, 999 },
	seconds = { 0, 1000000000 },
	count = { 1, 100 },
	price = { 0, 1000000000 },
	amount = { 1, 1000000000 },
	balance = { 0, 1000000000 },
}

local RARITY: { [string]: boolean } = {
	Common = true,
	Uncommon = true,
	Rare = true,
	Epic = true,
	Legendary = true,
	Mythic = true,
	Secret = true,
}

-- Lowercased on purpose. A display name must not ride along as a field.
local FORBIDDEN: { [string]: boolean } = {
	username = true,
	name = true,
	displayname = true,
	ip = true,
	email = true,
	password = true,
	token = true,
	cookie = true,
	userid = true,
	user_id = true,
}

local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }

local events: { [string]: any } = {}
for _, row in ipairs(Analytics.EVENT_LIST) do
	if events[row.id] == nil then
		events[row.id] = row
	end
end

local funnels: { [string]: any } = table.clone(Analytics.FUNNELS) :: any

local currencies: { [string]: boolean } = {}
for _, id in ipairs(Analytics.CURRENCIES) do
	currencies[id] = true
end

local sourceReasons: { [string]: string } = table.clone(Analytics.SOURCE_REASONS) :: any
local sinkReasons: { [string]: string } = table.clone(Analytics.SINK_REASONS) :: any

export type Send = {
	kind: string,
	label: string,
	name: string,
	value: number,
	custom: { string },
	flow: string,
	currency: string,
	amount: number,
	balance: number,
	transaction: string,
	sku: string,
	roblox: string,
	funnelName: string,
	funnelId: string,
	step: number,
	stepName: string,
}

export type Outcome = {
	ok: boolean,
	status: string,
	send: Send?,
	rowId: number?,
}

export type RecentRow = {
	id: number,
	userId: number,
	name: string,
	status: string,
}

export type State = {
	hits: { [number]: { number } },
	seen: { [number]: { [string]: boolean } },
	recent: { RecentRow },
	seq: number,
}

export type Request = {
	gateOn: boolean,
	configOn: boolean,
	sampleRate: number,
	rateLimit: number,
	rateWindow: number,
	recentLimit: number,
	now: number,
	userId: number,
	eventName: string?,
	funnelId: string?,
	stepId: string?,
	fields: any,
}

function AnalyticsLogic.newState(): State
	return {
		hits = {},
		seen = {},
		recent = {},
		seq = 0,
	}
end

function AnalyticsLogic.disabledReason(gateOn: boolean, configOn: boolean): string?
	if gateOn ~= true then
		return "Analytics is off (LaunchGate.analytics)."
	end
	if configOn ~= true then
		return "Analytics is off (Config.Analytics.ENABLED)."
	end
	return nil
end

function AnalyticsLogic.userId(value: any): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	if value == math.huge or value == -math.huge then
		return nil
	end
	if value ~= math.floor(value) then
		return nil
	end
	return value
end

-- Same UserId always lands on the same side of the cut, so a funnel
-- is not split across sessions. rate 0 keeps nobody. rate 1 keeps all.
function AnalyticsLogic.inSample(userId: number, rate: number): boolean
	if type(rate) ~= "number" or rate ~= rate or rate <= 0 then
		return false
	end
	if rate >= 1 then
		return true
	end
	local bucket = math.abs(userId) % 10000
	return bucket < math.floor(rate * 10000 + 1e-6)
end

function AnalyticsLogic.safeCall(callback: () -> ()): (boolean, string?)
	local ok, err = pcall(callback)
	if ok then
		return true, nil
	end
	return false, tostring(err)
end

function AnalyticsLogic.customFields(values: { string }): { [string]: string }?
	if #values == 0 then
		return nil
	end
	local fields: { [string]: string } = {}
	local count = math.min(3, #values)
	for index = 1, count do
		fields[FIELD_KEYS[index]] = values[index]
	end
	return fields
end

function AnalyticsLogic.slots(state: State, userId: number): number
	local hits = state.hits[userId]
	if hits == nil then
		return 0
	end
	return #hits
end

-- Drops the rate window only. Funnel steps stay seen so a rejoin on
-- this server does not replay the onboarding steps.
function AnalyticsLogic.forget(state: State, userId: number)
	state.hits[userId] = nil
end

local function lineCap(limit: any): number
	if type(limit) ~= "number" or limit ~= limit or limit < 1 then
		return MAX_LINES
	end
	return math.min(MAX_LINES, math.floor(limit))
end

function AnalyticsLogic.note(
	state: State,
	userId: number,
	name: string,
	status: string,
	limit: any
): number
	state.seq += 1
	local rowId = state.seq
	table.insert(state.recent, {
		id = rowId,
		userId = userId,
		name = name,
		status = status,
	})
	local cap = lineCap(limit)
	while #state.recent > cap do
		table.remove(state.recent, 1)
	end
	return rowId
end

function AnalyticsLogic.mark(state: State, rowId: number, status: string)
	if type(rowId) ~= "number" then
		return
	end
	for _, row in ipairs(state.recent) do
		if row.id == rowId and row.status == "ok" then
			row.status = status
			return
		end
	end
end

function AnalyticsLogic.formatRecent(state: State, limit: any): string
	local cap = lineCap(limit)
	local startAt = math.max(1, #state.recent - cap + 1)
	local lines = {}
	for index = startAt, #state.recent do
		local row = state.recent[index]
		table.insert(lines, string.format("%s %d %s", row.status, row.userId, row.name))
	end
	return table.concat(lines, "\n")
end

local function clockOk(now: any): boolean
	return type(now) == "number" and now == now and now ~= math.huge and now ~= -math.huge
end

function AnalyticsLogic.takeSlot(
	state: State,
	userId: number,
	now: number,
	limit: any,
	window: any
): boolean
	if not clockOk(now) then
		return false
	end
	local cap = limit
	if type(cap) ~= "number" or cap ~= cap or cap < 1 then
		cap = 1
	else
		cap = math.floor(cap)
	end
	local span = window
	if type(span) ~= "number" or span ~= span or span <= 0 then
		span = 10
	end
	local kept = {}
	local hits = state.hits[userId]
	if hits ~= nil then
		for _, stamp in ipairs(hits) do
			if now - stamp < span then
				table.insert(kept, stamp)
			end
		end
	end
	if #kept >= cap then
		state.hits[userId] = kept
		return false
	end
	table.insert(kept, now)
	state.hits[userId] = kept
	return true
end

local function outcome(status: string, send: Send?, rowId: number?): Outcome
	return {
		ok = status == "ok",
		status = status,
		send = send,
		rowId = rowId,
	}
end

local function integer(value: any, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	if value == math.huge or value == -math.huge or value ~= math.floor(value) then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return value
end

local function token(value: any): string?
	if type(value) ~= "string" or #value < 1 or #value > 32 then
		return nil
	end
	if string.match(value, TOKEN) == nil then
		return nil
	end
	return value
end

local function hasPii(fields: any): boolean
	if type(fields) ~= "table" then
		return false
	end
	for key in pairs(fields) do
		if type(key) == "string" and FORBIDDEN[string.lower(key)] == true then
			return true
		end
	end
	return false
end

local function pack(key: string, text: string): string?
	local line = key .. "=" .. text
	if #line > 48 then
		return nil
	end
	return line
end

local function blank(): Send
	return {
		kind = "",
		label = "",
		name = "",
		value = 1,
		custom = {},
		flow = "",
		currency = "",
		amount = 0,
		balance = 0,
		transaction = "",
		sku = "",
		roblox = "",
		funnelName = "",
		funnelId = "",
		step = 0,
		stepName = "",
	}
end

local function readFields(event: any, fields: any): ({ [string]: any }?, string?)
	local allowed: { [string]: boolean } = {}
	for _, key in ipairs(event.fields) do
		allowed[key] = true
	end
	local source = fields
	if source == nil then
		source = {}
	end
	local got: { [string]: any } = {}
	for key, value in pairs(source) do
		if type(key) ~= "string" or allowed[key] ~= true then
			return nil, "invalid"
		end
		local span = RANGE[key]
		if span ~= nil then
			local number = integer(value, span[1], span[2])
			if number == nil then
				return nil, "invalid"
			end
			got[key] = number
		elseif key == "rarity" then
			local text = token(value)
			if text == nil or RARITY[text] ~= true then
				return nil, "invalid"
			end
			got[key] = text
		elseif key == "reason" and next(event.reasons) ~= nil then
			local text = token(value)
			if text == nil or event.reasons[text] ~= true then
				return nil, "invalid"
			end
			got[key] = text
		else
			local text = token(value)
			if text == nil then
				return nil, "invalid"
			end
			got[key] = text
		end
	end
	for _, key in ipairs(event.required) do
		if got[key] == nil then
			return nil, "invalid"
		end
	end
	return got, nil
end

local function compileEvent(event: any, fields: any): (Send?, string?)
	local got, err = readFields(event, fields)
	if got == nil then
		return nil, err or "invalid"
	end
	local send = blank()
	send.label = event.id
	send.name = event.id
	send.value = event.value
	if event.kind == "economy" then
		local currency = got.currency
		if type(currency) ~= "string" or currencies[currency] ~= true then
			return nil, "invalid"
		end
		local reason = got.reason
		local map = if event.flow == "sink" then sinkReasons else sourceReasons
		local transaction = if type(reason) == "string" then map[reason] else nil
		if transaction == nil then
			return nil, "invalid"
		end
		send.kind = "economy"
		send.flow = event.flow
		send.currency = currency
		send.amount = got.amount
		send.balance = got.balance
		send.transaction = transaction
		send.sku = reason
		return send, nil
	end
	local custom = {}
	for _, key in ipairs(event.fields) do
		local item = got[key]
		if item ~= nil and key == event.valueFrom then
			send.value = item
		elseif item ~= nil then
			local text = if type(item) == "number" then tostring(item) else item
			local line = pack(key, text)
			if line == nil then
				return nil, "invalid"
			end
			table.insert(custom, line)
		end
	end
	if #custom > 3 then
		return nil, "invalid"
	end
	send.kind = "custom"
	send.custom = custom
	return send, nil
end

local function compileFunnel(funnelId: string, stepId: string, fields: any): (Send?, string?)
	if type(fields) == "table" and next(fields) ~= nil then
		return nil, "invalid"
	end
	local funnel = funnels[funnelId]
	if funnel == nil then
		return nil, "unknown"
	end
	if type(stepId) ~= "string" then
		return nil, "invalid"
	end
	local found = nil
	for _, row in ipairs(funnel.steps) do
		if row.id == stepId then
			found = row
			break
		end
	end
	if found == nil then
		return nil, "invalid"
	end
	local send = blank()
	send.kind = "funnel"
	send.label = funnelId .. ":" .. stepId
	send.name = funnel.name
	send.roblox = funnel.roblox
	send.funnelName = funnel.name
	send.funnelId = funnelId
	send.step = found.step
	send.stepName = found.name
	return send, nil
end

local function compile(request: Request): (Send?, string?)
	local named = type(request.eventName) == "string"
	local funnel = type(request.funnelId) == "string"
	if named == funnel then
		return nil, "invalid"
	end
	if funnel then
		return compileFunnel(request.funnelId :: string, request.stepId :: string, request.fields)
	end
	local event = events[request.eventName :: string]
	if event == nil then
		return nil, "unknown"
	end
	return compileEvent(event, request.fields)
end

function AnalyticsLogic.prepare(state: State, request: Request): Outcome
	if AnalyticsLogic.disabledReason(request.gateOn, request.configOn) ~= nil then
		return outcome("disabled")
	end
	if AnalyticsLogic.userId(request.userId) == nil then
		return outcome("invalid")
	end
	local userId = request.userId
	if request.fields ~= nil and type(request.fields) ~= "table" then
		return outcome("invalid")
	end
	if hasPii(request.fields) then
		return outcome("pii")
	end
	local send, status = compile(request)
	if send == nil then
		return outcome(status or "invalid")
	end
	if not clockOk(request.now) then
		return outcome("invalid")
	end
	if not AnalyticsLogic.inSample(userId, request.sampleRate) then
		return outcome("sample")
	end
	if send.kind == "funnel" then
		local seen = state.seen[userId]
		if seen ~= nil and seen[send.label] == true then
			return outcome("duplicate")
		end
		if seen == nil then
			seen = {}
			state.seen[userId] = seen
		end
		seen[send.label] = true
	elseif
		not AnalyticsLogic.takeSlot(
			state,
			userId,
			request.now,
			request.rateLimit,
			request.rateWindow
		)
	then
		local rowId = AnalyticsLogic.note(state, userId, send.label, "rate", request.recentLimit)
		return outcome("rate", nil, rowId)
	end
	local rowId = AnalyticsLogic.note(state, userId, send.label, "ok", request.recentLimit)
	return outcome("ok", send, rowId)
end

return AnalyticsLogic
