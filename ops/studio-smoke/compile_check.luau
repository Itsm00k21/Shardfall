-- lune ops/studio-smoke/compile_check.luau <dir>: compile every .luau under dir.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local bad, ok = 0, 0
local function walk(dir)
	for _, name in ipairs(fs.readDir(dir)) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			walk(p)
		elseif name:match("%.luau$") then
			local good, err = pcall(luau.compile, fs.readFile(p))
			if good then ok += 1 else bad += 1; print("COMPILE FAIL " .. p .. ": " .. tostring(err)) end
		end
	end
end
for i = 1, #process.args do walk(process.args[i]) end
print(string.format("compiled ok=%d fail=%d", ok, bad))
if bad > 0 then process.exit(1) end
