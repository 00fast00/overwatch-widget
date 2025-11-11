local utils = require("core.utils")
local constants = require("core.constants")
local interpolate = require("i18n.interpolate")

local cutils = {}

cutils.ApplyDefaults = utils.ApplyDefaults

---@param n Notification
---@param NCID string
---@return boolean
function cutils.HasChannel(n, NCID)
	if not n.channels then
		return false
	end

	if table.contains(n.channels, NCID) then
		return true
	end

	return false
end

---@param n Notification
---@param NCID string
---@param myConfig table
---@return boolean
function cutils.ShouldSend(n, NCID, myConfig)
	if not myConfig.enabled then
		return false
	end

	-- Send if forced.
	if cutils.HasChannel(n, NCID) then
		return true
	end

	-- Do not send if channels exists but we are not in.
	if n.channels then
		return false
	end

	-- Check priority
	if
		(myConfig.minPriority > 0 and n.priority < myConfig.minPriority)
		or (myConfig.maxPriority > 0 and n.priority > myConfig.maxPriority)
	then
		return false
	end

	return true
end

function cutils.Interpolate(format, n)
	if not format then
		return "invalid empty format!"
	end

	return interpolate(format, {
		playerName = n.team.leaderName,
		teamId = n.team.id,
		ruleId = n.config.id,
		priorityName = constants.NOTIFY_PRIORITY_NAMES[n.priority],
		message = n.message or "",
	})
end

return cutils
