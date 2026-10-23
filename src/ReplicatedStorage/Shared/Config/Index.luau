--!strict

--[[
	Config index (roadmap milestone 0.3). One require gives every tunable
	area of the game:

		Items, Rarities, Elements, SetBonuses, Dungeons, Enemies, Rewards,
		Economy, Strings

	Studio:  require(ReplicatedStorage.Shared.Config.Index)
	Lune:    require("../src/ReplicatedStorage/Shared/Config/Index")

	Areas that already had a module point at it, so every old require path
	still works and nothing moved. Areas that were missing (Rarities V1,
	Elements, Economy V1, Strings) are new data modules in this folder.

	Rarities and Economy here are the V1 numbers (Echo's economy sheet rev 2,
	Kevin-approved Oct 22, 2026). They are data only. The live game still
	reads the older modules, listed under Config.Live, until Phase 1.3 and
	Phase 4.1 switch over.

	IDs are stable. Never rename or reuse one; saved player data points at
	them. Add a new id and migrate instead.

	The roadmap names this folder src/shared/Config/. Rojo serves
	src/ReplicatedStorage/Shared as ReplicatedStorage.Shared, so the folder
	lives at src/ReplicatedStorage/Shared/Config/.

	Nothing here costs Robux or touches saves. No services are required.
]]

local Dungeons = require("../Dungeons")

local Config = {}

-- The nine areas.
Config.Items = require("../ItemBases")
Config.Rarities = require("./Rarities")
Config.Elements = require("./Elements")
Config.SetBonuses = require("../RelicSets")
Config.Dungeons = Dungeons
Config.Enemies = Dungeons.ENEMIES
Config.Rewards = require("../Drops")
Config.Economy = require("./Economy")
Config.Strings = require("./Strings")

-- Phase 2, Stage A, and Stage C. Extra tables, not a tenth area.
Config.EquipSlots = require("./EquipSlots")
Config.EquipStats = require("./EquipStats")
Config.GearLevels = require("./GearLevels")
Config.ShardCore = require("./ShardCore")

Config.AREAS = table.freeze({
	"Items",
	"Rarities",
	"Elements",
	"SetBonuses",
	"Dungeons",
	"Enemies",
	"Rewards",
	"Economy",
	"Strings",
})

-- What the game runs on today. Phase 1.3 moves rolls onto Config.Rarities,
-- and Phase 4.1 moves run pay onto Config.Economy.
Config.Live = table.freeze({
	Rarities = require("../Rarities"), -- 7-tier ladder, colors, luck exponents
	RarityConfig = require("../RarityConfig"), -- 7-tier 1-in-N odds, pity, disclosure
	RollConfig = require("../RollConfig"), -- roll costs, Epic/Legendary pity
	Economy = require("../Economy"), -- gold, farm, upgrade costs
	Currencies = require("../Currencies"), -- wallets
	Stats = require("../Stats"), -- gear stat ids and rarity scale
	Difficulties = require("../Rootvault").DIFFICULTIES, -- normal/hard/nightmare
	LoadingTips = require("../LoadingTips"), -- tip strings (screen is off)
})

return table.freeze(Config)
