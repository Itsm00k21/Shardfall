--!strict

--[[
	Drop values a DataStore cannot store, and keep every other field.

	Safe values are finite numbers, strings, booleans, and tables of those.
	NaN, infinity, functions, threads, and Roblox values (Instance, Vector3,
	Color3, CFrame, and any other userdata) are removed. Unknown keys that
	are safe stay, including fields this build does not read yet.

	Known wallets are clamped by Schema.reconcile before this runs. This
	pass does not replace a missing gold value with a default.
]]

local SaveSanitize = {}

local MAX_DEPTH = 32

local function keyOk(key: any): boolean
	local kind = type(key)
	if kind == "string" then
		return true
	end
	if kind ~= "number" then
		return false
	end
	if key ~= key or key >= math.huge or key <= -math.huge then
		return false
	end
	return key == math.floor(key)
end

local function valueOk(value: any): boolean
	local kind = type(value)
	if kind == "string" or kind == "boolean" or kind == "table" then
		return true
	end
	if kind ~= "number" then
		return false
	end
	return value == value and value < math.huge and value > -math.huge
end

local function scrubIn(value: any, depth: number)
	if type(value) ~= "table" or depth > MAX_DEPTH then
		return
	end
	local drop = {}
	for key, child in pairs(value) do
		if not keyOk(key) or not valueOk(child) then
			table.insert(drop, key)
		elseif type(child) == "table" then
			scrubIn(child, depth + 1)
		end
	end
	for _, key in ipairs(drop) do
		value[key] = nil
	end
end

function SaveSanitize.scrub(value: any): any
	scrubIn(value, 0)
	return value
end

return SaveSanitize
