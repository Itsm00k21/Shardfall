-- Studio smoke: server half. Only exists in the ops/studio-smoke build.
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")

local marker = ServerStorage:FindFirstChild("StudioSmokeMarker")
local runId = marker and marker:GetAttribute("RunId") or "?"
local function out(...)
	print("SMOKE|" .. runId .. "|server|" .. table.concat({ ... }, "|"))
end

local done = Instance.new("RemoteEvent")
done.Name = "StudioSmokeDone"
done.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("SmokeRunId", runId)

local logCounts = { error = 0, warning = 0 }
LogService.MessageOut:Connect(function(message, kind)
	if string.sub(message, 1, 6) == "SMOKE|" then
		return
	end
	if kind == Enum.MessageType.MessageError then
		logCounts.error += 1
		out("LOG", "error", (string.gsub(message, "\n", " / ")))
	elseif kind == Enum.MessageType.MessageWarning then
		logCounts.warning += 1
		out("LOG", "warning", (string.gsub(message, "\n", " / ")))
	end
end)

out("START", "isStudio=" .. tostring(RunService:IsStudio()), "args=" .. tostring(StudioTestService:GetTestArgs()))

-- Give init.server a moment to finish booting, then require every module.
task.wait(3)
local requireFails, requireOk = 0, 0
local function requireAll(root, label)
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("ModuleScript") then
			local ok, err = pcall(require, inst)
			if ok then
				requireOk += 1
			else
				requireFails += 1
				out("FAIL", "require", label, inst:GetFullName(), (string.gsub(tostring(err), "\n", " / ")))
			end
		end
	end
end
local shared = ReplicatedStorage:FindFirstChild("Shared")
local server = ServerScriptService:FindFirstChild("ShardfallServer")
if shared then
	requireAll(shared, "shared")
end
if server then
	requireAll(server, "server")
end
out(requireFails == 0 and "PASS" or "FAIL", "server_require_all", string.format("ok=%d fail=%d", requireOk, requireFails))
out(#game:GetService("Players"):GetPlayers() >= 0 and "INFO" or "INFO", "workspace_children", tostring(#workspace:GetChildren()))

local finished = false
local clientSummary = "client never reported"
done.OnServerEvent:Connect(function(_player, summary)
	clientSummary = tostring(summary)
	finished = true
end)

local deadline = os.clock() + 420
while not finished and os.clock() < deadline do
	task.wait(1)
end
out(finished and "INFO" or "FAIL", "client_finished", tostring(finished))
local summary = HttpService:JSONEncode({
	runId = runId,
	requireOk = requireOk,
	requireFails = requireFails,
	serverErrors = logCounts.error,
	serverWarnings = logCounts.warning,
	client = clientSummary,
})
out("END", summary)
task.wait(1)
StudioTestService:EndTest(summary)
