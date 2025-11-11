local cutils = require("channels.cutils")
local constants = require("core.constants")

local CONFIG_CATEGORY = "channels"
local NCID = "uilog"

local CONFIG_DEFAULTS = {
	enabled = true,
	minPriority = constants.NOTIFY_PRIORITY.TRACE,
	maxPriority = -1,
}

-- Vars
local logger ---@type Logger
-- local gameContext ---@type GameContext
local config ---@type Config
local myConfig = {} ---@type table<string, any>
local ui ---@type OverwatchUi

-- API
---@type Channel
local channel = {
	id = NCID,
	Init = function(l, _, c, u)
		logger = l:WithSection(l.section .. "::channel_" .. NCID)
		-- gameContext = g
		config = c
		ui = u

		-- Our own section in the config
		if not config.data[CONFIG_CATEGORY] then
			config.data[CONFIG_CATEGORY] = {}
		end
		if not config.data[CONFIG_CATEGORY][NCID] then
			config.data[CONFIG_CATEGORY][NCID] = {}
		end
		myConfig = config.data[CONFIG_CATEGORY][NCID]

		-- Apply defaults
		cutils.ApplyDefaults(myConfig, CONFIG_DEFAULTS)

		return true
	end,
	Shutdown = function()
		return true
	end,
	IsEnabled = function()
		return myConfig.enabled
	end,
	GetControls = function()
		---@type ChannelControls
		return {
			Enabled = function(state)
				if state == nil then
					return myConfig.enabled
				end

				myConfig.enabled = state
				return state
			end,
		}
	end,
	GameFrame = function() end,
	Notify = function(n)
		if not cutils.ShouldSend(n, NCID, myConfig) then
			if logger.level >= constants.LogLevel.TRACE3 then
				logger:Trace3("Not sending message: %s", n.config.id)
			end

			return true
		end

		ui.Log(n)

		return true
	end,
}

return channel
