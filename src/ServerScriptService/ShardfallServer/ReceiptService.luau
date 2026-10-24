--!strict

--[[
	ProcessReceipt, idempotent by purchase id.

	No product is on sale in this beta. An unknown product is left
	unprocessed so a later publish can grant it. A repeated id never pays
	twice. Session locking still lives in DataService.

	ProcessReceipt is assign-only. Reading it throws
	"you can only set the callback value, get is not available" and that
	used to abort server boot before the world or the profile load.
]]

local DataService = require(script.Parent.DataService)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)
local Loops = require(game:GetService("ReplicatedStorage").Shared.Loops)

local ReceiptService = {}

function ReceiptService.grant(player: Player, receiptId: string, productId: number)
	local duplicate = false
	local saved = DataService.mutate(player, function(data)
		-- The sku grant runs first. A refusal returns before the id is stored.
		local granted, already, reason = Loops.grantPremium(data, receiptId, productId)
		if granted ~= true then
			return reason
		end
		duplicate = already == true
		if type(data.receipts) ~= "table" or data.receipts[receiptId] ~= true then
			duplicate = Economy.receipt(data, receiptId)
		end
		return nil
	end)
	if not saved then
		return false
	end
	return not duplicate
end

function ReceiptService.start()
	local ok, err = pcall(function()
		-- Assign only. A read of ProcessReceipt throws and aborts boot.
		game:GetService("MarketplaceService").ProcessReceipt = function(receipt)
			if type(receipt) ~= "table" or type(receipt.PlayerId) ~= "number" then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local player = game:GetService("Players"):GetPlayerByUserId(receipt.PlayerId)
			if player == nil or type(receipt.PurchaseId) ~= "string" then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			-- Nothing is sold yet. Recording the id without a grant would swallow
			-- a real purchase, so leave it pending until a product map exists.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end)
	if not ok then
		warn("[Shardfall] ProcessReceipt was not set: " .. tostring(err))
	end
end

return ReceiptService
