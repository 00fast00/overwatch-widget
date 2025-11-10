-- RuleState maintains the runtime state information for "interval-based" `run()` calls.
--
---@class RuleState
--
---@field lastTriggered integer Gametime in seconds of the last trigger
---@field data table Custom data for the rule
local RuleState = {}
RuleState.__index = RuleState

---@return RuleState
function RuleState.New()
	---@type RuleState
	local self = setmetatable({ lastTriggered = 0, data = {} }, RuleState)

	return self
end

return RuleState
