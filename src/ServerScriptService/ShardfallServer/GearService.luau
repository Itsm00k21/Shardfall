--!strict
--[[
	Shows equipped crystal gear on the character. The look comes from
	GearLook.forProfile, so it follows the Bag's normal equip and unequip.
	Pieces are rigid-welded to RightHand, Head and UpperTorso (R15 and Rthro).
	They are massless and have no collision, touch or query, so
	movement, hit tests and combat are untouched.
	A worn helm hides hats and hair. A worn chest hides torso
	accessories, so nothing clips. Both come back when the piece
	comes off.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearLook = require(ReplicatedStorage.Shared.GearLook)
local DataService = require(script.Parent.DataService)
local PropService = require(script.Parent.PropService)

local GearService = {}

local applied: { [Model]: string } = {}

local HEAD_ATTACHMENTS = { HatAttachment = true, HairAttachment = true, FaceFrontAttachment = true }
local TORSO_ATTACHMENTS = {
	BodyFrontAttachment = true,
	BodyBackAttachment = true,
	NeckAttachment = true,
	LeftCollarAttachment = true,
	RightCollarAttachment = true,
}

local function vec(v: Vector3): GearLook.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function v3(v: GearLook.Vec): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function hideAccessories(character: Model, names: { [string]: boolean }, hidden: boolean, tag: string)
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			if handle ~= nil and handle:IsA("BasePart") then
				local attachment = handle:FindFirstChildWhichIsA("Attachment")
				if attachment ~= nil and names[attachment.Name] then
					if hidden and handle:GetAttribute(tag) == nil then
						handle:SetAttribute(tag, handle.Transparency)
						handle.LocalTransparencyModifier = 1
						handle.Transparency = 1
					elseif not hidden and handle:GetAttribute(tag) ~= nil then
						handle.Transparency = handle:GetAttribute(tag) :: number
						handle:SetAttribute(tag, nil)
					end
				end
			end
		end
	end
end

local function weld(piece: BasePart, body: BasePart, offset: CFrame, folder: Instance)
	piece.Anchored = false
	piece.Massless = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = true
	piece.CFrame = body.CFrame * offset
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = body
	joint.Part1 = piece
	joint.Parent = piece
	piece.Parent = folder
end

local function rigScale(character: Model): number
	-- A default R15 UpperTorso is about 1.7 studs tall; Rthro runs taller.
	local torso = character:FindFirstChild("UpperTorso")
	if torso ~= nil and torso:IsA("BasePart") then
		return math.clamp(torso.Size.Y / 1.7, 0.7, 1.5)
	end
	return 1
end

-- Dresses a character with a look. Exposed so Studio checks can dress a test rig.
function GearService.dress(character: Model, look: GearLook.Look)
	local old = character:FindFirstChild("ShardfallGear")
	if old ~= nil then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "ShardfallGear"
	folder.Parent = character

	local hand = character:FindFirstChild("RightHand")
	if look.weapon ~= nil and hand ~= nil and hand:IsA("BasePart") then
		local sword = PropService.load(look.weapon)
		if sword ~= nil then
			local size, gripY =
				GearLook.swordFit(vec(sword.Size), look.weaponScale, rigScale(character), look.weaponGrip)
			sword.Size = v3(size)
			sword.Name = "GearWeapon"
			local grip = GearLook.GRIP
			-- forward: the mesh top (+Y) points along the hand's -Z, like REST_GRIP.
			-- upright: the mesh top stays up along the arm, like a carried staff.
			local tilt = if look.weaponPose == "upright" then 0 else math.rad(-90)
			local offset = CFrame.new(grip.x, grip.y, grip.z)
				* CFrame.Angles(tilt, math.rad(look.weaponYaw), 0)
				* CFrame.new(0, -gripY, 0)
			weld(sword, hand, offset, folder)
		end
	end

	local head = character:FindFirstChild("Head")
	local wearsHelm = look.helm ~= nil and head ~= nil and head:IsA("BasePart")
	if wearsHelm and head ~= nil and head:IsA("BasePart") and look.helm ~= nil then
		local helm = PropService.load(look.helm)
		if helm ~= nil then
			local size, lift = GearLook.helmFit(vec(head.Size), vec(helm.Size))
			helm.Size = v3(size)
			helm.Name = "GearHelm"
			weld(helm, head, CFrame.new(lift.x, lift.y, lift.z), folder)
		end
	end
	hideAccessories(character, HEAD_ATTACHMENTS, wearsHelm, "GearHidHelm")

	local torso = character:FindFirstChild("UpperTorso")
	local wearsChest = look.chest ~= nil and torso ~= nil and torso:IsA("BasePart")
	if wearsChest and torso ~= nil and torso:IsA("BasePart") and look.chest ~= nil then
		local chest = PropService.load(look.chest)
		if chest ~= nil then
			local size, lift = GearLook.chestFit(vec(torso.Size), vec(chest.Size))
			chest.Size = v3(size)
			chest.Name = "GearChest"
			weld(chest, torso, CFrame.new(lift.x, lift.y, lift.z), folder)
		end
	end
	hideAccessories(character, TORSO_ATTACHMENTS, wearsChest, "GearHidChest")
end

local function refresh(player: Player)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local look = GearLook.forProfile(data)
	local signature = GearLook.signature(look)
	if applied[character] == signature and character:FindFirstChild("ShardfallGear") ~= nil then
		return
	end
	applied[character] = signature
	GearService.dress(character, look)
end

local function safeRefresh(player: Player)
	local ok, err = pcall(refresh, player)
	if not ok then
		warn("[Shardfall] Gear refresh failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function watch(player: Player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		applied[character] = nil
		character.Destroying:Connect(function()
			applied[character] = nil
		end)
		task.wait(0.2)
		safeRefresh(player)
	end)
	if player.Character ~= nil then
		task.spawn(safeRefresh, player)
	end
end

function GearService.start()
	DataService.onChanged(function(player)
		safeRefresh(player)
	end)
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return GearService
