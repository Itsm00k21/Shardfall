--!strict

--[[
	Where the crack card sits on the Roll tab.

	layout(pageHeight, kindHeight) keeps the reel at the rollChrome
	height. The result card starts below the kind row (the Gear / Pets /
	x10 band, including the scroll's top pad) and ends above the Roll
	button. The name sits inside the card. A short reel uses a smaller
	stone so the shard does not fill the whole reel.

	A missing or bad page height is 320. A missing or bad kind height
	is 44. That includes nil, a string, NaN, infinity, and a page under
	80. A third argument, including paid = true, does not move the
	card. Each call reads its arguments and does not write them. No
	clock. No RNG. Nothing here costs Robux.
]]

local UiRouter = require("./UiRouter")
local UiTheme = require("./UiTheme")

local CrackCard = {}

local REEL_Y = UiTheme.PAD + 32
local CARD_GAP = 4
local FALLBACK_PAGE = 320
local FALLBACK_KIND = 44

export type Box = { y: number, h: number }

export type Layout = {
	reel: Box,
	button: number,
	listTop: number,
	kindBottom: number,
	card: Box,
	name: Box,
	rarity: { y: number, h: number, visible: boolean },
	fly: boolean,
	equipH: number,
	showEquip: boolean,
	stone: { w: number, h: number, y: number },
	compact: boolean,
}

local function pageOf(value: any): number
	if type(value) ~= "number" then
		return FALLBACK_PAGE
	end
	if value ~= value or value == math.huge or value == -math.huge or value < 80 then
		return FALLBACK_PAGE
	end
	return math.floor(value)
end

local function kindOf(value: any): number
	if type(value) ~= "number" then
		return FALLBACK_KIND
	end
	if value ~= value or value == math.huge or value == -math.huge or value < FALLBACK_KIND then
		return FALLBACK_KIND
	end
	return math.floor(value)
end

function CrackCard.layout(pageHeight: any, kindHeight: any, _extra: any?): Layout
	local height = pageOf(pageHeight)
	local kind = kindOf(kindHeight)
	local chrome = UiRouter.rollChrome(height)
	local reelH = chrome.reel
	local reelBottom = REEL_Y + reelH
	local kindBottom = reelBottom + UiTheme.PAD + kind
	local cardBottom = height - (chrome.button + UiTheme.PAD + CARD_GAP)
	local room = cardBottom - kindBottom
	if room < 0 then
		room = 0
	end
	local cardH = math.min(chrome.card, room)
	local cardY = cardBottom - cardH
	local nameY = 4
	local nameH = math.min(22, math.max(0, cardH - 8))
	local rarityY = 26
	local rarityH = 16
	local showRarity = cardH >= 48
	if cardH >= 72 then
		nameY = 8
		nameH = 28
		rarityY = 40
		rarityH = 20
		showRarity = true
	end
	local stoneW = 28
	local stoneH = 36
	local stoneY = 0.62
	if reelH < 52 then
		stoneW = 16
		stoneH = math.min(18, math.max(8, reelH - 8))
		stoneY = 0.7
	end
	return {
		reel = { y = REEL_Y, h = reelH },
		button = chrome.button,
		listTop = reelBottom,
		kindBottom = kindBottom,
		card = { y = cardY, h = cardH },
		name = { y = nameY, h = nameH },
		rarity = { y = rarityY, h = rarityH, visible = showRarity },
		fly = cardH >= 88,
		equipH = if cardH >= 88 then UiTheme.TOUCH else 36,
		showEquip = cardH >= 72,
		stone = { w = stoneW, h = stoneH, y = stoneY },
		compact = reelH < 52,
	}
end

return CrackCard
