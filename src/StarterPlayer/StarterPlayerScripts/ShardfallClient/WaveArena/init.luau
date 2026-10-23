--!strict

--[[
	[ECHO hook] Client for the wave arena. start() returns immediately
	while LaunchGate.waveArena is off, so no ScreenGui and no remote poll
	exist in the default game.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossBar = require(script.BossBar)
local CameraRoom = require(script.CameraRoom)
local ResultsCard = require(script.ResultsCard)

local WaveArena = {}

local started = false

function WaveArena.start()
	if started then
		return
	end
	local LaunchGate = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LaunchGate"))
	if LaunchGate.on("waveArena") ~= true then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WaveArena") :: RemoteFunction
	task.spawn(function()
		local last = os.clock()
		while player.Parent ~= nil do
			local now = os.clock()
			local dt = math.clamp(now - last, 0.05, 0.2)
			last = now
			local stepOk, stepped = pcall(function()
				return remote:InvokeServer("step", { dt = dt, attack = true })
			end)
			local state = if stepOk and typeof(stepped) == "table" then stepped else nil
			if typeof(playerGui) == "Instance" then
				BossBar.apply(playerGui, if state ~= nil then state.hud else nil)
				ResultsCard.apply(playerGui, if state ~= nil then state.hud else nil, function()
					pcall(function()
						remote:InvokeServer("leave")
					end)
				end)
				if state ~= nil then
					CameraRoom.apply(state.boss, state.camera)
				end
			end
			task.wait(0.1)
		end
	end)
end

return WaveArena
