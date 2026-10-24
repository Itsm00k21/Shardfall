--!strict

--[[
	The slot a hero row or a bag row is dragging.

	The bar reads it on release. Nothing here talks to the server.
]]

local ActionDrag = {}

local current: { kind: string, id: string }? = nil

function ActionDrag.begin(slot: { kind: string, id: string })
	current = { kind = slot.kind, id = slot.id }
end

function ActionDrag.peek(): { kind: string, id: string }?
	return current
end

function ActionDrag.take(): { kind: string, id: string }?
	local slot = current
	current = nil
	return slot
end

function ActionDrag.clear()
	current = nil
end

return ActionDrag
