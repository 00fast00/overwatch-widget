local cutils = require("channels.cutils")

local spPlaySoundFile = Spring.PlaySoundFile

local CONFIG_CATEGORY = "channels"
local NCID = "sound"

local CONFIG_DEFAULTS = {
	enabled = true,
	defaultParams = {
		soundfile = "sounds/voice/en/winter/UnitLost.wav",
		volume = 1.0,
		channel = "sfx",
	},
}

-- Vars
--local logger ---@type Logger
--local gameContext ---@type GameContext
local config ---@type Config
local myConfig = {} ---@type table<string, any>
-- local ui ---@type OverwatchUi

-- API
---@type Channel
local channel = {
	id = NCID,
	Init = function(l, g, c, _)
		--logger = l:WithSection(l.section .. "::channel_" .. NCID)
		--gameContext = g
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
		if not cutils.HasChannel(n, NCID) then
			return true
		end

		local params = n.parameters or {}
		cutils.ApplyDefaults(params, myConfig.defaultParams)

		spPlaySoundFile(params.soundfile, params.volume, nil, params.channel)

		return true
	end,
}

return channel
