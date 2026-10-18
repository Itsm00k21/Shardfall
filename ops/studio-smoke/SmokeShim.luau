-- Studio smoke shim (ops/studio-smoke, never shipped).
-- The build copy rewrites `X.Activated:Connect(fn)` into
-- `shared.__smk(X, "Activated"):Connect(fn)` and
-- `ContextActionService:BindActionAtPriority(...)` into
-- `shared.__smkCas:BindActionAtPriority(...)`. Every handler still connects
-- to the real signal; this module only remembers it so SmokeClient can call
-- the same functions a real click or key press would reach.
local ContextActionService = game:GetService("ContextActionService")

if shared.__smkReg ~= nil then
	return shared.__smkReg
end

local reg = {
	signals = setmetatable({}, { __mode = "k" }), -- [Instance] = { [signal] = { fn } }
	global = {}, -- ["UserInputService.InputBegan"] = { fn }
	actions = {}, -- [name] = { fn = fn, keys = { KeyCode } }
	count = 0,
}
shared.__smkReg = reg

local function record(inst, sig, fn)
	reg.count += 1
	if typeof(inst) == "Instance" then
		local perInst = reg.signals[inst]
		if perInst == nil then
			perInst = {}
			reg.signals[inst] = perInst
		end
		perInst[sig] = perInst[sig] or {}
		table.insert(perInst[sig], fn)
	end
	local key = (typeof(inst) == "Instance" and inst.ClassName or tostring(inst)) .. "." .. sig
	reg.global[key] = reg.global[key] or {}
	table.insert(reg.global[key], fn)
end

shared.__smk = function(inst, sig)
	local real = inst[sig]
	return {
		Connect = function(_, fn)
			record(inst, sig, fn)
			return real:Connect(fn)
		end,
		Once = function(_, fn)
			record(inst, sig, fn)
			return real:Once(fn)
		end,
		Wait = function(_)
			return real:Wait()
		end,
	}
end

local function bindRecord(name, fn, keys)
	reg.actions[name] = { fn = fn, keys = keys }
end

shared.__smkCas = {
	BindAction = function(_, name, fn, touch, ...)
		bindRecord(name, fn, { ... })
		return ContextActionService:BindAction(name, fn, touch, ...)
	end,
	BindActionAtPriority = function(_, name, fn, touch, prio, ...)
		bindRecord(name, fn, { ... })
		return ContextActionService:BindActionAtPriority(name, fn, touch, prio, ...)
	end,
}

return reg
