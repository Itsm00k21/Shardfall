--!strict

--[[
	The launch Gold shop. Three offers: a healing tonic, one bag slot,
	and one pet slot. Prices are Gold. A paid flag does not change them,
	and this module never reads a product id.
]]

local Materials = require("./Materials")

local GoldShop = {}

GoldShop.PET_BASE = 3
GoldShop.PET_BONUS_CAP = 5
GoldShop.BAG_BONUS_CAP = 500

export type Offer = {
	id: string,
	label: string,
	price: number,
}

local OFFERS: { Offer } = {
	{ id = "tonic", label = "Healing Tonic", price = 40 },
	{ id = "bag", label = "Bag slot", price = 250 },
	{ id = "pet", label = "Pet slot", price = 400 },
}

local BY_ID: { [string]: Offer } = {}
for _, offer in ipairs(OFFERS) do
	BY_ID[offer.id] = offer
end

function GoldShop.offers(): { Offer }
	return OFFERS
end

function GoldShop.offer(id: string): Offer?
	return BY_ID[id]
end

local function whole(value: any): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	if value == math.huge or value == -math.huge then
		return nil
	end
	return math.floor(value)
end

function GoldShop.petCap(data: any): number
	local bonus = 0
	if type(data) == "table" then
		local count = whole(data.petSlotBonus)
		if count ~= nil and count > 0 then
			bonus = math.min(count, GoldShop.PET_BONUS_CAP)
		end
	end
	return GoldShop.PET_BASE + bonus
end

-- nil when the buy lands. Otherwise a sentence the shop can show.
-- Mutates data only on success. `extra` is ignored, including paid.
function GoldShop.apply(data: any, offerId: any, _extra: any?): string?
	if type(data) ~= "table" then
		return "That is not for sale."
	end
	if type(offerId) ~= "string" then
		return "That is not for sale."
	end
	local offer = BY_ID[offerId]
	if offer == nil then
		return "That is not for sale."
	end
	local gold = whole(data.gold)
	if gold == nil or gold < offer.price then
		return "You need more Gold."
	end
	if offerId == "tonic" then
		if type(data.consumables) ~= "table" then
			data.consumables = {}
		end
		local owned = whole(data.consumables[Materials.TONIC_ID]) or 0
		if owned >= Materials.TONIC_CAP then
			return "You cannot carry more tonics."
		end
		data.gold = gold - offer.price
		data.consumables[Materials.TONIC_ID] = owned + 1
		return nil
	end
	if offerId == "bag" then
		local bonus = whole(data.inventoryBonus) or 0
		if bonus >= GoldShop.BAG_BONUS_CAP then
			return "Your bag cannot grow more."
		end
		data.gold = gold - offer.price
		data.inventoryBonus = bonus + 1
		return nil
	end
	local bonus = whole(data.petSlotBonus) or 0
	if bonus >= GoldShop.PET_BONUS_CAP then
		return "You cannot equip more pets."
	end
	data.gold = gold - offer.price
	data.petSlotBonus = bonus + 1
	return nil
end

return GoldShop
