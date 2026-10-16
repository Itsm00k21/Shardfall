--!strict

--[[
	ProcessReceipt, idempotent by purchase id.

	No product is on sale in this beta. An unknown product is left
	unprocessed so a later publish can grant it. A repeated id never pays
	twice. Session locking still lives in DataService.
]]

local DataService = require(script.Parent.DataService)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)

local ReceiptService = {}

function ReceiptService.grant(player: Player, receiptId: string, _productId: number)
	local duplicate = false
	local saved = DataService.mutate(player, function(data)
		duplicate = Economy.receipt(data, receiptId)
		return nil
	end)
	if not saved then
		return false
	end
	return not duplicate
end

function ReceiptService.start()
	local ok, marketplace = pcall(function()
		return game:GetService("MarketplaceService")
	end)
	if not ok or marketplace == nil or marketplace.ProcessReceipt == nil then
		return
	end
	marketplace.ProcessReceipt = function(receipt)
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
end

return ReceiptService
