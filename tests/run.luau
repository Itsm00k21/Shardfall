--!strict

--[[
	Entry point: `lune run tests/run`

	Requires each spec so its describe/it calls register, then runs them.
	Exit code 0 means every assertion passed.
]]

local process = require("@lune/process")
local framework = require("./framework")

require("./RollMath.spec")
require("./Schema.spec")
require("./SessionLock.spec")
require("./PaidRollPolicy.spec")

process.exit(framework.run())
