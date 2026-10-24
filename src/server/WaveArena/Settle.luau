--!strict

--[[
	One settlement per run id.

	Run end, disconnect, teleport, shutdown, and a later save all call
	finish(). The first successful save pays. A failed save leaves the id
	unmarked so the retry pays once. PlayerRemoving before or after the
	run ends cannot pay a second time.
]]

local Loot = require("./Loot")
local Round = require("./Round")

local Settle = {}

local EMPTY = { tokens = 0, essence = 0, bag = 0 }
local TRIES = 3

function Settle.id(run: any): string
	if typeof(run) == "table" and type(run.receiptId) == "string" and run.receiptId ~= "" then
		return run.receiptId
	end
	return "run"
end

function Settle.book(): { done: { [string]: boolean } }
	return { done = {} }
end

function Settle.done(book: any, id: string): boolean
	return typeof(book) == "table" and typeof(book.done) == "table" and book.done[id] == true
end

-- save() returns true when the profile write stuck. A false return can
-- roll the profile back; the next try commits again, still only once
-- after a success.
function Settle.finish(
	book: any,
	profile: any,
	run: any,
	reason: string,
	options: any,
	save: (() -> boolean)?
): (string, { tokens: number, essence: number, bag: number })
	if typeof(book) ~= "table" then
		book = Settle.book()
	end
	if typeof(book.done) ~= "table" then
		book.done = {}
	end
	if typeof(run) ~= "table" or typeof(profile) ~= "table" then
		return "retry", EMPTY
	end
	local id = Settle.id(run)
	if book.done[id] == true then
		return "again", EMPTY
	end
	if run.settled ~= true then
		Round.settle(run, reason, options)
	end
	local grant = EMPTY
	local tries = 0
	while tries < TRIES do
		tries += 1
		grant = Loot.commit(profile, run)
		local stuck = true
		if save ~= nil then
			stuck = save() == true
		end
		if stuck then
			book.done[id] = true
			return "paid", grant
		end
	end
	return "retry", grant
end

return Settle
