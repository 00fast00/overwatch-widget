local constants = require("core.constants")
local cutils = require("channel.cutils")

local spSendCommands = Spring.SendCommands

local CONFIG_CATEGORY = "channels"
local NCID = "command"

local CONFIG_DEFAULTS = {
	enabled = true,
	minPriority = constants.NOTIFY_PRIORITY.NONE,
	maxPriority = -1,

	defaultParams = {
		command = "say a: ",
		format = "%{message}",
	},
}

-- Vars
local logger ---@type Logger
local gameContext ---@type GameContext
local config ---@type Config
local myConfig = {} ---@type table<string, any>
-- local ui ---@type OverwatchUi

-- API
---@type Channel
local channel = {
	id = NCID,
	Init = function(l, g, c, _)
		logger = l:WithSection(l.section .. "::channel_" .. NCID)
		gameContext = g
		config = c
		-- ui = nui

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
		-- Never send commands in spec mode.
		if gameContext.inSpecMode then
			return true
		end

		if not cutils.ShouldSend(n, NCID, myConfig) then
			if logger.level >= constants.LogLevel.TRACE3 then
				logger:Trace3("Not sending message: %s", n.config.id)
			end

			return true
		end

		cutils.DefaultNotificationParams(n, NCID, myConfig.defaultParams)
		local params = n.config.parameters["channels"][NCID]

		spSendCommands(params.command .. cutils.Interpolate(params.format, n))

		return true
	end,
}

return channel
