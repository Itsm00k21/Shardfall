--!strict

--[[
	Server entry for run payouts.

	The amount is decided here, from config, and only while
	LaunchGate.payouts is on. The flag stays off, so grant pays nothing
	and does not settle the run until Ghost turns it on.

	Pass the player's own UserId. Never pass an id from the client
	payload. Amounts on the request are ignored.

	This module does not read or write a profile. Ghost adds Roll Tokens
	to the existing shardTokens field from the returned delta, and only
	when paid is true. Fragments are returned and not saved. No Robux.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevTools = require(ReplicatedStorage.Shared.DevTools)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local Payouts = require(ReplicatedStorage.Shared.Config.Payouts)

local PayoutService = {}

local book = Payouts.newBook()

function PayoutService.grant(userId: any, runId: any, request: any): any
	if LaunchGate.on("payouts") ~= true then
		return Payouts.closed(runId, DevTools.offMessage("payouts"))
	end
	return Payouts.grant(book, userId, runId, request)
end

return PayoutService
