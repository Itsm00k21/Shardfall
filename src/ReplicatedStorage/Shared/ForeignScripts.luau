--!strict

--[[
	Which scripts the startup scan is allowed to disable.

	StarterPlayer holds Roblox's camera and control scripts (PlayerModule,
	RbxCharacterSounds, and the rest). Disabling those leaves the camera
	dead and the screen gray. The scan never walks that service, and it
	also skips a built-in name if one shows up under Workspace.
]]

local ForeignScripts = {}

ForeignScripts.SERVICES = {
	"ServerScriptService",
	"Workspace",
	"StarterGui",
	"StarterPack",
	"ReplicatedFirst",
	"ServerStorage",
}

ForeignScripts.BUILT_IN = {
	PlayerModule = true,
	RbxCharacterSounds = true,
	PlayerScriptsLoader = true,
	ChatScript = true,
	BubbleChat = true,
	Animate = true,
	Health = true,
}

function ForeignScripts.shouldFlag(serviceName: string, names: { string }): boolean
	if serviceName == "StarterPlayer" then
		return false
	end
	local listed = false
	for _, service in ipairs(ForeignScripts.SERVICES) do
		if service == serviceName then
			listed = true
		end
	end
	if not listed then
		return false
	end
	for _, name in ipairs(names) do
		if name == "StarterPlayer" then
			return false
		end
		if ForeignScripts.BUILT_IN[name] == true then
			return false
		end
		if name == "ShardfallServer" or name == "ShardfallClient" then
			return false
		end
	end
	return true
end

return ForeignScripts
