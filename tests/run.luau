--!strict

--[[
	Entry point: `lune run tests/run`

	Requires each spec so its describe/it calls register, then runs them.
	Exit code 0 means every assertion passed.
]]

local process = require("@lune/process")
local framework = require("./framework")

require("./Audio.spec")
require("./RollMath.spec")
require("./RarityConfig.spec")
require("./ChestConfig.spec")
require("./Schema.spec")
require("./SessionLock.spec")
require("./PaidRollPolicy.spec")
require("./Currencies.spec")
require("./RemoteCaller.spec")
require("./MemoryRoll.spec")
require("./InventoryStacks.spec")
require("./InventoryView.spec")
require("./Areas.spec")
require("./Stats.spec")
require("./Catalog.spec")
require("./CombatMath.spec")
require("./CombatFeel.spec")
require("./Crafting.spec")
require("./CraftingPhase.spec")
require("./Dungeons.spec")
require("./Haven.spec")
require("./Travel.spec")
require("./Quality.spec")
require("./ShellLayout.spec")
require("./Build.spec")
require("./ForeignScripts.spec")
require("./SavedWorld.spec")
require("./HavenLife.spec")
require("./HavenBuild.spec")
require("./VerdantVisuals.spec")
require("./RootvaultSpawn.spec")
require("./Stars.spec")

process.exit(framework.run())
