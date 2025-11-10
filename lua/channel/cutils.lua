local utils = require("core.utils")
local constants = require("core.constants")
local interpolate = require("i18n.interpolate")

local cutils = {}

cutils.ApplyDefaults = utils.ApplyDefaults

---@param n Notification
---@param NCID string
---@param myConfig table
---@return boolean
function cutils.ShouldSend(n, NCID, myConfig)
	if not myConfig.enabled then
		return false
	end

	if n.forceChannels then
		if table.contains(n.forceChannels, NCID) then
			return true
		end

		return false
	end

	if
		(myConfig.minPriority > 0 and n.priority < myConfig.minPriority)
		or (myConfig.maxPriority > 0 and n.priority > myConfig.maxPriority)
	then
		return false
	end

	return true
end

-- Applys the given "defaultParams" to n.config.parameters["channels"][NCID]
--
---@param n Notification
---@param NCID string
---@param defaultParams table
function cutils.DefaultNotificationParams(n, NCID, defaultParams)
	if not n.config.parameters then
		n.config.parameters = {}
	end
	if not n.config.parameters["channels"] then
		n.config.parameters["channels"] = {}
	end
	if not n.config.parameters["channels"][NCID] then
		n.config.parameters["channels"][NCID] = {}
	end
	utils.ApplyDefaults(n.config.parameters["channels"][NCID], defaultParams)
end

function cutils.Interpolate(format, n)
	return interpolate(format, {
		ruleId = n.config.id,
		priorityName = constants.NOTIFY_PRIORITY_NAMES[n.priority],
		message = n.message or "",
	})
end

return cutils
