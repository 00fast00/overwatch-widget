-- Result
local utils = {}

-- Transfrom the given class with name and provided field list into:
--
---<%Name%{%k1=%v1, %k2=%v2, %k3=%v3}>
--
-- Intended for log dumping stuff.
--
-- WARNING: This is not recursion save.
--
---@param klass table
---@param name string
---@param fields string[]
---@return string
function utils.DumpClass(klass, name, fields)
	if type(klass) ~= "table" or type(fields) ~= "table" then
		return "<invalid>"
	end

	local parts = {}
	for i, field in ipairs(fields) do
		local value = klass[field]
		local valueStr

		if type(value) == "table" then
			-- Simple table representation (could be enhanced for recursion safety)
			local items = {}
			for k, v in pairs(value) do
				table.insert(items, tostring(k) .. "=" .. tostring(v))
			end
			valueStr = "{" .. table.concat(items, ", ") .. "}"
		else
			valueStr = tostring(value)
		end

		parts[i] = tostring(field) .. "=" .. valueStr
	end

	return "<" .. name .. "{" .. table.concat(parts, ", ") .. "}>"
end

---@param target table
---@param defaults table
function utils.ApplyDefaults(target, defaults)
	if not target or not defaults then
		return
	end

	for k, v in pairs(defaults) do
		local vt = type(v)

		if target[k] == nil then
			-- Apply default if key doesn't exist in target
			target[k] = v
		elseif vt == "table" and type(target[k]) == "table" then
			-- If both are tables, recursively apply defaults
			utils.ApplyDefaults(target[k], v)
		end
	end
end

-- Checks "validate" and updates target with defaults, reqs and then opts applied from "validate".
--
---@param target table
---@param validate table For example user provided config
---@param reqs table<string, string> Format {value = "type"}
---@param opts table<string, string> Format {value = "type"}
---@param defaults table<string, any> Format {value = default}
---@return string[]? missing When reqs are missing else nil
function utils.MergeValidate(target, validate, reqs, opts, defaults)
	-- Check Required values.
	local missed = false
	local missing = {}
	for k, v in pairs(reqs) do
		if type(validate[k]) ~= v then
			missed = true
			table.insert(missing, k)
		end
	end

	if missed then
		return missing
	end

	-- Apply defaults
	if type(defaults) == "table" then
		utils.ApplyDefaults(target, defaults)
	end

	-- Apply required fields
	if type(reqs) == "table" then
		for k, v in pairs(reqs) do
			if type(validate[k]) == v then
				if type(target[k]) == "table" then
					utils.ApplyDefaults(target[k], validate[k])
				else
					target[k] = validate[k]
				end
			end
		end
	end

	-- Apply optionals
	if type(opts) == "table" then
		for k, v in pairs(opts) do
			if type(validate[k]) == v then
				if type(target[k]) == "table" then
					utils.ApplyDefaults(target[k], validate[k])
				else
					target[k] = validate[k]
				end
			end
		end
	end

	-- Success
	return nil
end

return utils
