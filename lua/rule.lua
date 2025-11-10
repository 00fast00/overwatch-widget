---@class Rule
---@field bp Blueprint Logic
---@field config RuleConfig The specific configuration
---@field state RuleState The current state
local Rule = {}
Rule.__index = Rule

---@param bp Blueprint
---@param config RuleConfig
---@param state RuleState
---@return Rule
function Rule.New(bp, config, state)
	---@type Rule
	local self = setmetatable({ bp = bp, config = config, state = state }, Rule)

	return self
end

---@return string
function Rule:__tostring()
	local result = "<Rule{"
	result = result .. "id=" .. self.config.id
	result = result .. ",bp=" .. self.bp.id
	result = result .. "}>"

	return result
end

return Rule
