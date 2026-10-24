-- Studio smoke plugin. Does nothing unless the open place carries
-- ServerStorage.StudioSmokeMarker (only the ops/studio-smoke build does),
-- so it is inert in any other place Studio has open.
local RunService = game:GetService("RunService")
if not RunService:IsEdit() then
	return
end
local ServerStorage = game:GetService("ServerStorage")
local marker
for _ = 1, 60 do
	marker = ServerStorage:FindFirstChild("StudioSmokeMarker")
	if marker then
		break
	end
	task.wait(0.5)
end
if not marker then
	return
end
local runId = marker:GetAttribute("RunId") or "?"
print("SMOKE|" .. runId .. "|plugin|START|starting play mode")
task.wait(3)
local StudioTestService = game:GetService("StudioTestService")
local ok, result = pcall(function()
	return StudioTestService:ExecutePlayModeAsync(runId)
end)
print("SMOKE|" .. runId .. "|plugin|RESULT|" .. tostring(ok) .. "|" .. (string.gsub(tostring(result), "[\r\n|]", " / ")))
