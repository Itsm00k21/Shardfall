--!strict
--[[
	Generated 3D props (Studio generate_mesh, 2026-10-18). Each entry is a
	published mesh plus its baked texture. The server loads them with
	AssetService:CreateMeshPartAsync, so the hub stays code-built and
	Rojo-tracked. A prop that fails to load falls back to Neon parts.
	Blender twins of the crystals live in ~/ShardfallAudit/meshes on the Mac.
]]

export type Prop = {
	mesh: string,
	texture: string,
	glow: { number },
}

local PropAssets: { [string]: Prop } = {
	CrystalCluster = {
		mesh = "rbxassetid://115433302928240",
		texture = "rbxassetid://114503506891169",
		glow = { 150, 92, 255 },
	},
	CrystalBed = {
		mesh = "rbxassetid://132592454855430",
		texture = "rbxassetid://137982651648336",
		glow = { 64, 206, 255 },
	},
	CrystalSpire = {
		mesh = "rbxassetid://122042626358125",
		texture = "rbxassetid://97648419184205",
		glow = { 120, 140, 255 },
	},
	-- Quick Travel portal. A violet crystal ring with a cyan disc.
	CrystalPortal = {
		mesh = "rbxassetid://140354824566054",
		texture = "rbxassetid://118429274949949",
		glow = { 64, 206, 255 },
	},
	-- Starter crystal gear (worn pieces, see GearLook).
	CrystalSword = {
		mesh = "rbxassetid://76592850671373",
		texture = "rbxassetid://97340433005770",
		glow = { 64, 206, 255 },
	},
	CrystalStaff = {
		mesh = "rbxassetid://132906202608313",
		texture = "rbxassetid://81373311879921",
		glow = { 150, 92, 255 },
	},
	CrystalHelm = {
		mesh = "rbxassetid://130436477055805",
		texture = "rbxassetid://87486345241393",
		glow = { 150, 92, 255 },
	},
	CrystalChest = {
		mesh = "rbxassetid://117847447724611",
		texture = "rbxassetid://135956593000493",
		glow = { 150, 92, 255 },
	},
	CrystalPair = {
		mesh = "rbxassetid://122152631902431",
		texture = "rbxassetid://106727684664470",
		glow = { 170, 96, 255 },
	},
}

for _, prop in pairs(PropAssets) do
	table.freeze(prop.glow)
	table.freeze(prop)
end

return table.freeze(PropAssets)
