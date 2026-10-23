--!strict

--[[
	Phase 0.8 analytics. Server only.

	track, funnel, and economy decide in this thread, then task.spawn
	the engine call inside AnalyticsLogic.safeCall. Gameplay does not
	wait on it. A thrown engine call is swallowed and the dev row is
	marked engine.

	Nothing is sent unless LaunchGate.analytics and the catalog ENABLED
	flag are both true. Both default off. Sampling, validation, and the
	per-player rate limit live in AnalyticsLogic.

	The only player field read here is UserId. Callers pass catalog ids.
	This module does not write a save. Session lines run from start();
	gameplay lines stay with the owning service until that service adds
	them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Analytics = require(ReplicatedStorage.Shared.Config.Analytics)
local AnalyticsLogic = require(ReplicatedStorage.Shared.AnalyticsLogic)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)

local AnalyticsService = {}

local state = AnalyticsLogic.newState()
local started = false
local joinedAt: { [number]: number } = {}

local function enabled(): boolean
	return AnalyticsLogic.disabledReason(LaunchGate.on("analytics"), Analytics.ENABLED) == nil
end

local function flowType(flow: string): any
	local kinds = (Enum :: any).AnalyticsEconomyFlowType
	if flow == "sink" then
		return kinds.Sink
	end
	return kinds.Source
end

local function emit(
	player: Player,
	eventName: string?,
	funnelId: string?,
	stepId: string?,
	fields: any
)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local userId = AnalyticsLogic.userId(player.UserId)
	if userId == nil then
		return
	end
	local outcome = AnalyticsLogic.prepare(state, {
		gateOn = LaunchGate.on("analytics"),
		configOn = Analytics.ENABLED == true,
		sampleRate = Analytics.SAMPLE_RATE,
		rateLimit = Analytics.RATE_LIMIT,
		rateWindow = Analytics.RATE_WINDOW_SEC,
		recentLimit = Analytics.RECENT_LIMIT,
		now = os.clock(),
		userId = userId,
		eventName = eventName,
		funnelId = funnelId,
		stepId = stepId,
		fields = fields,
	})
	if not outcome.ok or outcome.send == nil then
		return
	end
	local send = outcome.send
	local rowId = outcome.rowId
	task.spawn(function()
		local ok = AnalyticsLogic.safeCall(function()
			local analytics: any = game:GetService("AnalyticsService")
			local custom = AnalyticsLogic.customFields(send.custom)
			if send.kind == "custom" then
				analytics:LogCustomEvent(player, send.name, send.value, custom)
			elseif send.kind == "economy" then
				analytics:LogEconomyEvent(
					player,
					flowType(send.flow),
					send.currency,
					send.amount,
					send.balance,
					send.transaction,
					send.sku,
					custom
				)
			elseif send.roblox == "onboarding" then
				analytics:LogOnboardingFunnelStepEvent(player, send.step, send.stepName, custom)
			else
				analytics:LogFunnelStepEvent(
					player,
					send.funnelName,
					nil,
					send.step,
					send.stepName,
					custom
				)
			end
		end)
		if not ok and rowId ~= nil then
			AnalyticsLogic.mark(state, rowId, "engine")
		end
	end)
end

function AnalyticsService.track(player: Player, eventName: string, fields: { [string]: any }?)
	emit(player, eventName, nil, nil, fields)
end

function AnalyticsService.funnel(player: Player, funnelId: string, stepId: string)
	emit(player, nil, funnelId, stepId, nil)
end

function AnalyticsService.economy(
	player: Player,
	flow: string,
	currency: string,
	amount: number,
	balance: number,
	reason: string
)
	if flow ~= "source" and flow ~= "sink" then
		return
	end
	local eventName = if flow == "sink" then "currency_sink" else "currency_source"
	emit(player, eventName, nil, nil, {
		currency = currency,
		amount = amount,
		balance = balance,
		reason = reason,
	})
end

function AnalyticsService.printRecent(): string
	local why = AnalyticsLogic.disabledReason(LaunchGate.on("analytics"), Analytics.ENABLED)
	local body = AnalyticsLogic.formatRecent(state, Analytics.RECENT_LIMIT)
	local text = body
	if why ~= nil and body == "" then
		text = why
	elseif why ~= nil then
		text = why .. "\n" .. body
	elseif body == "" then
		text = "No analytics events yet."
	end
	print("[Analytics] " .. text)
	return text
end

-- Session start and end, plus the joined step of both funnels.
-- Gameplay events are not fired here.
function AnalyticsService.start()
	if started then
		return
	end
	started = true
	local Players = game:GetService("Players")

	local function added(player: Player)
		if not enabled() then
			return
		end
		local userId = AnalyticsLogic.userId(player.UserId)
		if userId ~= nil then
			joinedAt[userId] = os.clock()
		end
		AnalyticsService.track(player, "session_start", nil)
		AnalyticsService.funnel(player, "tutorial", "joined")
		AnalyticsService.funnel(player, "first_session", "joined")
	end

	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local userId = AnalyticsLogic.userId(player.UserId)
		local seconds = 0
		if userId ~= nil then
			local began = joinedAt[userId]
			if type(began) == "number" then
				seconds = math.max(0, math.floor(os.clock() - began))
			end
			joinedAt[userId] = nil
		end
		if enabled() then
			AnalyticsService.track(player, "session_end", { seconds = seconds })
		end
		-- Drop the rate window after the closing event is queued.
		if userId ~= nil then
			AnalyticsLogic.forget(state, userId)
		end
	end)
end

return AnalyticsService
