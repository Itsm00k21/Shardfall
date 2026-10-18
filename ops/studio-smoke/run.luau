--!strict

--[[
	Lune half of the Studio smoke. The command-bar script is play.luau.
	`lune run ops/studio-smoke/run` from the repo root.
]]

local process = require("@lune/process")
local framework = require("../../tests/framework")

require("../../tests/StudioSmoke.spec")

process.exit(framework.run())
