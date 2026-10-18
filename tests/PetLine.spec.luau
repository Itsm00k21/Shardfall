--!strict

--[[
	PetLine is pure and the Pets tab does not run under Lune. The
	source lock checks that the starter lines wrap from this module.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local PetLine = require("../src/ReplicatedStorage/Shared/PetLine")
local PetRoster = require("../src/ReplicatedStorage/Shared/PetRoster")
local TextFit = require("../src/ReplicatedStorage/Shared/TextFit")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

local SCALES = { 1, 1.1, 1.2, 1.3, 1.4 }
local WIDTHS = { 100, 160, 240, 400 }

describe("PetLine", function()
	it("keeps every starter line inside the width at every text scale", function()
		for _, companion in ipairs(PetRoster.STARTER) do
			local text = companion.name .. "  " .. companion.ability
			for _, scale in ipairs(SCALES) do
				for _, width in ipairs(WIDTHS) do
					local box = PetLine.box(text, width, scale)
					expect(box.w <= width).toBeTrue()
					expect(box.w).toEqual(width)
					expect(box.px).toEqual(TextFit.px(14, scale))
					expect(box.h >= box.px).toBeTrue()
					expect(box.h).toEqual(box.lines * box.px)
					expect(box.lines * box.chars >= #text).toBeTrue()
					expect(box.lines >= 1).toBeTrue()
				end
			end
		end
		local tight = PetLine.box("Shardjaw  Auto-collect drops", 100, 1.4)
		expect(tight.lines > 1).toBeTrue()
		expect(tight.h > 22).toBeTrue()
		local wide = PetLine.box("Shardjaw  Auto-collect drops", 400, 1)
		expect(wide.lines).toEqual(1)
		expect(wide.h).toEqual(TextFit.px(14, 1))
	end)

	it("uses 160 for a bad width and ignores paid", function()
		local text = "Shardjaw  Auto-collect drops"
		local fallback = PetLine.box(text, nil, 1.2)
		expect(fallback.w).toEqual(160)
		expect(PetLine.box(text, 0, 1).w).toEqual(160)
		expect(PetLine.box(text, "100", 1).w).toEqual(160)
		expect(PetLine.box(text, 0 / 0, 1.4).w).toEqual(160)
		expect(PetLine.box(text, math.huge, 1).w).toEqual(160)
		local paid = PetLine.box(text, 240, 1.4, { paid = true, cost = 25 })
		local free = PetLine.box(text, 240, 1.4)
		expect(paid).toEqual(free)
		expect(rawequal(paid, free)).toBeFalse()
		expect(PetLine.box(nil, 200, "big").px).toEqual(TextFit.px(14, 1))
	end)

	it("stays off the pets page, which no longer lists the whole roster", function()
		local hub = fs.readFile(HUB)
		local petsAt = string.find(hub, "function hubFn.paintPets()", 1, true)
		local poolAt = string.find(hub, "function hubFn.rollPoolId()", petsAt or 1, true)
		expect(petsAt ~= nil and poolAt ~= nil).toBeTrue()
		local pets = string.sub(hub, petsAt or 1, (poolAt or 1) - 1)
		expect(string.find(pets, "PetRoster.STARTER", 1, true)).toBeNil()
		expect(string.find(pets, "PetLine.box", 1, true)).toBeNil()
		expect(string.find(pets, "Crack a Pet Shard", 1, true) ~= nil).toBeTrue()
		local fit = fs.readFile("src/ReplicatedStorage/Shared/TextFit.luau")
		expect(
			string.find(
				fit,
				"function TextFit.px(base: any, scale: any, _extra: any?): number",
				1,
				true
			) ~= nil
		).toBeTrue()
	end)
end)
