local units = require("builtin_blueprints.units")
local resources = require("builtin_blueprints.resources")

-- Merges all together without copies (no table.merge()).
local r = {}
for _, kind in ipairs({ units, resources }) do
	for _, v in ipairs(kind) do
		table.insert(r, v)
	end
end

return r
