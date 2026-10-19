--!strict
--[[
	What crystal gear a profile wears, and how each piece fits a rig.
	Pure, so the spec covers it. The server (GearService) welds the pieces.

	Visual only. Stats, slots and the Bag equip flow are unchanged: an
	equipped sword-family weapon shows the Crystal Sword, any equipped
	helm shows the Crystal Helm, any equipped chest the Crystal Chest.

	Fit follows the actual body part, so R15 and Rthro proportions both
	work: the helm and chest are sized from Head and UpperTorso, and the
	sword is gripped at the same RightHand rest grip CombatStage uses.
]]

export type Look = {
	weapon: string?,
	weaponScale: number,
	helm: string?,
	chest: string?,
}

export type Vec = { x: number, y: number, z: number }

local GearLook = {}

-- Blade length in studs per weapon type, before body scale.
GearLook.SWORD_LENGTH = table.freeze({
	sword = 3.4,
	greatsword = 4.4,
	dagger = 2.2,
})

-- Matches CombatStage REST_GRIP: grip 0.2 below the hand centre, blade forward.
GearLook.GRIP = table.freeze({ x = 0, y = -0.2, z = 0 })
-- Where the hand closes on the mesh, as a fraction of its height from the bottom.
GearLook.GRIP_FRACTION = 0.1

local function owned(data: any, uid: any): any
	if type(uid) ~= "string" or type(data.inventory) ~= "table" then
		return nil
	end
	return data.inventory[uid]
end

function GearLook.forProfile(data: any): Look
	local look: Look = { weapon = nil, weaponScale = 1, helm = nil, chest = nil }
	if type(data) ~= "table" or type(data.equipped) ~= "table" then
		return look
	end
	local weapon = owned(data, data.equipped.weapon)
	if weapon ~= nil and weapon.kind == "Weapon" then
		local length = GearLook.SWORD_LENGTH[weapon.weaponType or ""]
		if length ~= nil then
			look.weapon = "CrystalSword"
			look.weaponScale = length
		end
	end
	local armor = data.equipped.armor
	if type(armor) == "table" then
		local helm = owned(data, armor.helm)
		if helm ~= nil and helm.kind == "Armor" and helm.slot == "helm" then
			look.helm = "CrystalHelm"
		end
		local chest = owned(data, armor.chest)
		if chest ~= nil and chest.kind == "Armor" and chest.slot == "chest" then
			look.chest = "CrystalChest"
		end
	end
	return look
end

function GearLook.signature(look: Look): string
	return string.format("%s|%.2f|%s|%s", look.weapon or "-", look.weaponScale, look.helm or "-", look.chest or "-")
end

-- Helm: a shell a little larger than the head, lifted so it caps the crown.
function GearLook.helmFit(head: Vec, mesh: Vec): (Vec, Vec)
	local s = math.max(head.x * 1.3 / mesh.x, head.z * 1.3 / mesh.z)
	local size = { x = mesh.x * s, y = mesh.y * s, z = mesh.z * s }
	-- Keep the brim at eye level: the bottom sits 30% down the head.
	local lift = head.y * 0.2 + (size.y - head.y) / 2
	return size, { x = 0, y = lift, z = 0 }
end

-- Chest: wraps the torso, slimmer in X so the arms swing clear.
function GearLook.chestFit(torso: Vec, _mesh: Vec): (Vec, Vec)
	local size = { x = torso.x * 1.08, y = torso.y * 1.04, z = torso.z * 1.35 }
	return size, { x = 0, y = torso.y * 0.02, z = 0 }
end

-- Sword: uniform scale to the blade length (scaled by the rig), grip offset.
function GearLook.swordFit(mesh: Vec, length: number, rigScale: number): (Vec, number)
	local s = length * rigScale / mesh.y
	local size = { x = mesh.x * s, y = mesh.y * s, z = mesh.z * s }
	local gripY = -size.y / 2 + size.y * GearLook.GRIP_FRACTION
	return size, gripY
end

return GearLook
