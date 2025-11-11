-- luapack bundle v0.1.1 (auto-generated)
local __B_LOADED = {}
local __B_MODULES = {}

local function __B_REQUIRE(name)
  if __B_LOADED[name] ~= nil then
    return __B_LOADED[name] == true and nil or __B_LOADED[name]
  end
  local loader = __B_MODULES[name]
  if loader then
    local res = loader(__B_REQ_TO_PASS)
    __B_LOADED[name] = (res == nil) and true or res
    return res
  end
  error('module not found: ' .. name)
end

__B_REQ_TO_PASS = __B_REQUIRE

-- module: builtin_blueprints  (from lua/builtin_blueprints/init.lua)
__B_MODULES['builtin_blueprints'] = function(require)
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
end

-- module: builtin_blueprints.resources  (from lua/builtin_blueprints/resources.lua)
__B_MODULES['builtin_blueprints.resources'] = function(require)
local constants = require("core.constants")

---@type Blueprint[]
return {
	{
		id = "resource_waste",
		description = "Wasting a resource",
		defaultConfig = {
			category = "resource",
			priority = constants.NOTIFY_PRIORITY.WARNING,
			icon = "ℹ️",
			template = "You'r wasting %{kind}, current wasting is %<excess>.o",
			cooldown = 60,
			parameters = {
				kinds = { "metal", "energy" },
				threshold = 0.1, -- return self.excess >= (self.storage * threshold)
			},
		},

		Start = function(game, team, config, dispatch)
			local unsubs = {}

			for _, kind in ipairs(config.parameters.kinds) do
				local resource = team:GetResource(kind)

				local lastTriggered = game.startupSeconds
				table.insert(
					unsubs,
					resource:Subscribe(
						"resource_waste",
						"HasExcess",
						{ threshold = config.parameters.threshold },
						function()
							if
								lastTriggered > 0
								and config.cooldown > 0
								and game.seconds - lastTriggered < config.cooldown
							then
								return
							end

							dispatch({
								team = team,
								config = config,
								templateParams = {
									kind = kind,
									excess = resource.excess,
								},
							})

							lastTriggered = game.seconds
						end
					)
				)
			end

			return unsubs
		end,
	},
	{
		id = "resource_stale",
		description = "Staling a resource",
		defaultConfig = {
			category = "resource",
			priority = constants.NOTIFY_PRIORITY.WARNING,
			icon = "ℹ️",
			template = "You'r staling %{kind}",
			cooldown = 60 * 5, -- 5 minutes
			parameters = {
				kinds = { "metal", "energy" },
				threshold = 0.1,
			},
		},

		Start = function(game, team, config, dispatch)
			local unsubs = {}

			for _, kind in ipairs(config.parameters.kinds) do
				local resource = team:GetResource(kind)

				local lastTriggered = game.startupSeconds
				table.insert(
					unsubs,
					resource:Subscribe(
						"resource_stale",
						"IsBelow",
						{ threshold = config.parameters.threshold },
						function()
							if
								lastTriggered > 0
								and config.cooldown > 0
								and game.seconds - lastTriggered < config.cooldown
							then
								return
							end

							dispatch({
								team = team,
								config = config,
								templateParams = {
									kind = kind,
									threshold = config.parameters.threshold,
									ratio = resource:GetRatio(),
								},
							})

							lastTriggered = game.seconds
						end
					)
				)
			end

			return unsubs
		end,
	},
	{
		id = "resource_converter_level",
		description = "Inform about lowering the converter level",
		defaultConfig = {
			category = "resource",
			priority = constants.NOTIFY_PRIORITY.WARNING,
			icon = "ℹ️",
			template = "You'r converter slider of %<mmLevel>.f is to high, pull the yellow box in the E bar all the way down!",
			interval = 60 * 3, -- 3 minutes.
			parameters = {
				threshold = 0.75, -- seems to be the default
			},
		},

		Trigger = function(game, team, config, state, dispatch)
			-- local mmLevel = team:GetRulesParamNum("mmLevel", 0)
			local mmLevel = Spring.GetTeamRulesParam(team.id, "mmLevel")

			if mmLevel >= config.parameters.threshold then
				dispatch({
					team = team,
					config = config,
					templateParams = {
						mmLevel = mmLevel,
						threshold = config.parameters.threshold,
					},
				})

				return true
			end

			return false
		end,
	},
}
end

-- module: builtin_blueprints.units  (from lua/builtin_blueprints/units.lua)
__B_MODULES['builtin_blueprints.units'] = function(require)
local constants = require("core.constants")

local spGetUnitPosition = Spring.GetUnitPosition

---@type Blueprint[]
return {
	{
		id = "unit_new",
		description = "Watches for specific new units",
		defaultConfig = {
			category = "units",
			priority = constants.NOTIFY_PRIORITY.INFO,
			icon = "ℹ️",
			template = "You got a %{unitName}, current: +%{count}",
			cooldown = 0,
			parameters = {
				startupDelay = 60,
				commanders = false,
				watchFor = {},
			},
		},

		Start = function(game, team, config, dispatch)
			local unsubs = {}

			local lastTriggered = game.startupSeconds + config.parameters.startupDelay
			table.insert(
				unsubs,
				team:Subscribe("unit_got", "UnitFinished", function(data)
					if
						lastTriggered > 0
						and config.cooldown > 0
						and game.seconds - lastTriggered < config.cooldown
					then
						return
					end

					local defID = data.defID
					local unitDef = UnitDefs[defID]
					local defName = unitDef.name

					local hasWatch = config.parameters.watchFor
						and table.contains(config.parameters.watchFor, defName)
					local isCom = config.parameters.commanders
						and unitDef.customParams
						and unitDef.customParams.iscommander

					if not hasWatch and not isCom then
						return
					end

					dispatch({
						team = team,
						config = config,
						templateParams = {
							status = "UnitFinished",
							teamID = data.teamID,
							unitName = defName,
							count = team.unitCounts[defID],
						},
					})

					lastTriggered = game.seconds
				end)
			)

			return unsubs
		end,
	},
	{
		id = "unit_lost",
		description = "Watches for specific lost units",
		defaultConfig = {
			category = "units",
			priority = constants.NOTIFY_PRIORITY.WARNING,
			icon = "ℹ️",
			template = "You lost a %{unitName}, current: +%{count}",
			cooldown = 0,
			parameters = {
				commanders = false,
				watchFor = {},
			},
		},

		Start = function(game, team, config, dispatch)
			local unsubs = {}

			if not config.parameters.commanders and table.count(config.parameters.watchFor) < 1 then
				return
			end

			local lastTriggered = game.startupSeconds
			table.insert(
				unsubs,
				team:Subscribe("unit_lost", "UnitDestroyed", function(data)
					if
						lastTriggered > 0
						and config.cooldown > 0
						and game.seconds - lastTriggered < config.cooldown
					then
						return
					end

					local defID = data.defID
					local unitDef = UnitDefs[defID]
					local defName = unitDef.name

					local hasWatch = config.parameters.watchFor
						and table.contains(config.parameters.watchFor, defName)
					local isCom = config.parameters.commanders
						and unitDef.customParams
						and unitDef.customParams.iscommander

					if not hasWatch and not isCom then
						return
					end

					dispatch({
						team = team,
						config = config,
						templateParams = {
							status = "UnitDestroyed",
							teamID = data.teamID,
							unitName = defName,
							count = team.unitCounts[defID],
						},
					})

					lastTriggered = game.seconds
				end)
			)

			return unsubs
		end,
	},
	{
		id = "unit_lost_ping",
		description = "Pings lost units",
		defaultConfig = {
			category = "units",
			priority = constants.NOTIFY_PRIORITY.WARNING,
			icon = "ℹ️",
			template = "Lost %{unitName} here",
			cooldown = 0,
			parameters = {
				commanders = false,
				watchFor = {},
			},
		},

		Start = function(game, team, config, dispatch)
			local unsubs = {}

			if not config.parameters.commanders and table.count(config.parameters.watchFor) < 1 then
				return
			end

			local lastTriggered = game.startupSeconds
			table.insert(
				unsubs,
				team:Subscribe("unit_lost_ping", "UnitDestroyed", function(data)
					if
						lastTriggered > 0
						and config.cooldown > 0
						and game.seconds - lastTriggered < config.cooldown
					then
						return
					end

					local defID = data.defID
					local unitDef = UnitDefs[defID]
					local defName = unitDef.name

					local hasWatch = config.parameters.watchFor
						and table.contains(config.parameters.watchFor, defName)
					local isCom = config.parameters.commanders
						and unitDef.customParams
						and unitDef.customParams.iscommander

					if not hasWatch and not isCom then
						return
					end

					local x, y, z = spGetUnitPosition(data.id)
					if not x or not y or not z then
						return
					end

					dispatch({
						team = team,
						config = config,
						templateParams = {
							unitName = defName,
						},
						parameters = {
							x = x,
							y = y,
							z = z,
						},
					})

					lastTriggered = game.seconds
				end)
			)

			return unsubs
		end,
	},
	{
		id = "unit_watch",
		description = "Watches for specific units (combines unit_lost and unit_got)",
		defaultConfig = {
			category = "units",
			priority = constants.NOTIFY_PRIORITY.WARNING,
			icon = "ℹ️",
			template = "You %{state} a %{unitName}, current: +%{count}",
			cooldown = 1,
			parameters = {
				startupDelay = 60,
				commanders = false,
				watchFor = {},
			},
		},

		Start = function(game, team, config, dispatch)
			local unsubs = {}

			local lostLastTriggered = game.startupSeconds + config.parameters.startupDelay
			table.insert(
				unsubs,
				team:Subscribe("unit_watch_lost", "UnitDestroyed", function(data)
					if
						lostLastTriggered > 0
						and config.cooldown > 0
						and game.seconds - lostLastTriggered < config.cooldown
					then
						return
					end

					local defID = data.defID
					local unitDef = UnitDefs[defID]
					local defName = unitDef.name

					local hasWatch = config.parameters.watchFor
						and table.contains(config.parameters.watchFor, defName)
					local isCom = config.parameters.commanders
						and unitDef.customParams
						and unitDef.customParams.iscommander

					if not hasWatch and not isCom then
						return
					end

					dispatch({
						team = team,
						config = config,
						templateParams = {
							state = "lost",
							unitName = defName,
							count = team.unitCounts[defID],
						},
					})

					lostLastTriggered = game.seconds
				end)
			)

			local newLastTriggered = game.startupSeconds + config.parameters.startupDelay
			table.insert(
				unsubs,
				team:Subscribe("unit_watch_new", "UnitFinished", function(data)
					if
						newLastTriggered > 0
						and config.cooldown > 0
						and game.seconds - newLastTriggered < config.cooldown
					then
						return
					end

					local defID = data.defID
					local unitDef = UnitDefs[defID]
					local defName = unitDef.name

					local hasWatch = config.parameters.watchFor
						and table.contains(config.parameters.watchFor, defName)
					local isCom = config.parameters.commanders
						and unitDef.customParams
						and unitDef.customParams.iscommander

					if not hasWatch and not isCom then
						return
					end

					dispatch({
						team = team,
						config = config,
						templateParams = {
							state = "got",
							unitName = defName,
							count = team.unitCounts[defID],
						},
					})

					newLastTriggered = game.seconds
				end)
			)

			return unsubs
		end,
	},
	{
		id = "unit_limit",
		description = "Checks if you overflow the unit limit",
		defaultConfig = {
			category = "units",
			priority = constants.NOTIFY_PRIORITY.ERROR,
			icon = "ℹ️",
			template = "You are at the unit limit %{current} of %{maxUnits}",
			cooldown = 10,
		},

		Start = function(game, team, config, dispatch)
			local unsubs = {}

			local lastTriggered = game.startupSeconds
			table.insert(
				unsubs,
				team:Subscribe("unit_limit", "UnitFinished", function(data)
					if
						lastTriggered > 0
						and config.cooldown > 0
						and game.seconds - lastTriggered < config.cooldown
					then
						return
					end

					if team.unitCount < team.maxUnits then
						return
					end

					dispatch({
						team = team,
						config = config,
						templateParams = {
							current = team.unitCount,
							maxUnits = team.maxUnits,
						},
					})

					lastTriggered = game.seconds
				end)
			)

			return unsubs
		end,
	},
}
end

-- module: channels.command  (from lua/channels/command.lua)
__B_MODULES['channels.command'] = function(require)
local constants = require("core.constants")
local cutils = require("channels.cutils")

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

		local params = n.parameters or {}
		cutils.ApplyDefaults(params, myConfig.defaultParams)

		spSendCommands(params.command .. cutils.Interpolate(params.format, n))

		return true
	end,
}

return channel
end

-- module: channels.console  (from lua/channels/console.lua)
__B_MODULES['channels.console'] = function(require)
local constants = require("core.constants")
local cutils = require("channels.cutils")

local spEcho = Spring.Echo

local CONFIG_CATEGORY = "channels"
local NCID = "console"

local CONFIG_DEFAULTS = {
	enabled = true,
	format = "[%{ruleId}] %{message}",
	minPriority = constants.NOTIFY_PRIORITY.INFO,
	maxPriority = -1,
}

-- Vars
local logger ---@type Logger
-- local gameContext ---@type GameContext
local config ---@type Config
local myConfig = {} ---@type table<string, any>
-- local ui ---@type OverwatchUi

-- API
---@type Channel
local channel = {
	id = NCID,
	Init = function(l, _, c, _)
		logger = l:WithSection(l.section .. "::channel_" .. NCID)
		-- gameContext = g
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
		if not cutils.ShouldSend(n, NCID, myConfig) then
			if logger.level >= constants.LogLevel.TRACE3 then
				logger:Trace3("Not sending message: %s", n.config.id)
			end

			return true
		end

		spEcho(cutils.Interpolate(myConfig.format, n))

		return true
	end,
}

return channel
end

-- module: channels.cutils  (from lua/channels/cutils.lua)
__B_MODULES['channels.cutils'] = function(require)
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
end

-- module: channels.marquee  (from lua/channels/marquee.lua)
__B_MODULES['channels.marquee'] = function(require)
local cutils = require("channels.cutils")
local constants = require("core.constants")

local CONFIG_CATEGORY = "channels"
local NCID = "marquee"

local CONFIG_DEFAULTS = {
	enabled = true,
	minPriority = constants.NOTIFY_PRIORITY.ERROR,
	maxPriority = -1,
	defaultParams = {
		speed = 0.08,
		duration = 6,
		fontSize = 32,
		fontColor = { r = 1, g = 1, b = 0, a = 1 }, -- Yellow text.
		fontOutlineColor = { r = 0, g = 0, b = 0, a = 1 },
	},
}

-- Vars
local logger ---@type Logger
local gameContext ---@type GameContext
local config ---@type Config
local myConfig = {} ---@type table<string, any>
local ui ---@type OverwatchUi

-- API
---@type Channel
local channel = {
	id = NCID,
	Init = function(l, g, c, u)
		logger = l:WithSection(l.section .. "::channel_" .. NCID)
		gameContext = g
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

		-- Auto-disable in spec mode.
		if gameContext.inSpecMode then
			myConfig.enabled = false
		end

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
				logger:Trace3(
					"Not sending message: %s, %s",
					n.config.id,
					table.toString(n.channels)
				)
			end
			return true
		end

		n.parameters = n.parameters or {}
		cutils.ApplyDefaults(n.parameters, myConfig.defaultParams)

		ui.Marquee(n)

		return true
	end,
}

return channel
end

-- module: channels.ping  (from lua/channels/ping.lua)
__B_MODULES['channels.ping'] = function(require)
local cutils = require("channels.cutils")

local spMarkerAddPoint = Spring.MarkerAddPoint

local CONFIG_CATEGORY = "channels"
local NCID = "ping"

local CONFIG_DEFAULTS = {
	enabled = true,
	format = "%{message}",
	defaultParams = {
		x = 0,
		y = 0,
		z = 0,
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

		if not n.parameters or not n.parameters.x or not n.parameters.y or not n.parameters.z then
			return true
		end

		local m = cutils.Interpolate(myConfig.format, n)
		spMarkerAddPoint(n.parameters.x, n.parameters.y, n.parameters.z, m, false)

		return true
	end,
}

return channel
end

-- module: channels.sound  (from lua/channels/sound.lua)
__B_MODULES['channels.sound'] = function(require)
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
end

-- module: channels.uilog  (from lua/channels/uilog.lua)
__B_MODULES['channels.uilog'] = function(require)
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
end

-- module: core.config  (from lua/core/config.lua)
__B_MODULES['core.config'] = function(require)
local utils = require("core.utils")

-- Configuration helper and store.
--
---@class Config
---@field data table
---@field _logger Logger
local Config = {}
Config.__index = Config

---@param logger Logger
---@return Config
function Config.New(logger)
	---@type Config
	local self = setmetatable(
		{ data = {}, _logger = logger:WithSection(logger.section .. "::config") },
		Config
	)

	return self
end

-- Load config file using VFS.Include
--
-- Will return false only if no config has been found and no defaults have been specified.
--
---@param path string Path to the config file
---@param defaultConfig table? Default configuration if no config has been found
---@return boolean success Whether loading was successful
function Config:Load(path, defaultConfig)
	self._logger:Debug("Loading")

	if not VFS.FileExists(path) then
		if defaultConfig then
			self._logger:Info("Config not found, will create on first save")
			self.data = defaultConfig or {}
			return true
		end

		self._logger:Error("No config in '%s' found and no defaults", path)
		return false
	end

	local result = VFS.Include(path)
	if type(result) ~= "table" then
		return false
	end

	if defaultConfig then
		utils.ApplyDefaults(result, defaultConfig)
	end

	self.data = result

	utils.self._logger:Debug("Loaded config successfully")
	return true
end

---@param path string
---@param previous table
---@return table
local function loadOne(path, previous)
	local new = VFS.Include(path)
	if type(new) ~= "table" then
		return {}
	end

	return table.merge(previous, new)
end

-- Load config files using VFS.Include
--
-- Will return false only if no config has been found and no defaults have been specified.
--
---@param dir string Config directory to look for "pattern"
---@param pattern string Pattern of config files to load "last" will be excluded from that list
---@param last string Last config file to load
---@param defaultConfig table? Default configuration if no config has been found
---@return boolean success Whether loading was successful
function Config:LoadMany(dir, pattern, last, defaultConfig)
	local cFiles = VFS.DirList(dir, pattern)

	self._logger:Debug("Loading")

	if #cFiles == 0 then
		if defaultConfig then
			self._logger:Info("Config not found, will create on first save")
			self.data = defaultConfig or {}
			return true
		end

		self._logger:Error(
			"No config in '%s' found with pattern '%s' and no defaults",
			dir,
			pattern
		)
		return false
	end

	local lastPath = ""
	for _, p in ipairs(cFiles) do
		local filename = p:match("([^/]+)$")
		if filename ~= last then
			self._logger:Trace("Loading config %s", p)
			self.data = loadOne(p, self.data)
		else
			lastPath = p
		end
	end

	if #lastPath > 0 then
		self._logger:Trace("Loading last config %s", lastPath)
		self.data = loadOne(lastPath, self.data)
	end

	if defaultConfig then
		utils.ApplyDefaults(self.data, defaultConfig)
	end

	return true
end

-- Save config file using table.save
---@param path string Path to save the config file
---@param header string? Optional header comment
---@param removeRules boolean? should we remove rules from the output?
---@return boolean success Whether saving was successful
function Config:Save(path, header, removeRules)
	if not self.data then
		self._logger:Debug("Trying to save a nil config to %s", path)
		return false
	end

	if removeRules and self.data["rules"] then
		local data = table.copy(self.data)
		data["rules"] = nil
		table.save(data, path, header)
		return true
	end

	-- Save using table.save.
	table.save(self.data, path, header)

	return true
end

return Config
end

-- module: core.constants  (from lua/core/constants.lua)
__B_MODULES['core.constants'] = function(require)
local IS_RELEASE = false

local NAME = "Overwatch"
local VERSION = "2025-11-08"

---@see https://github.com/beyond-all-reason/RecoilEngine/blob/master/rts/System/Log/Level.h
---@enum MyLogLevel
local LogLevel = {
	ALL = 0,
	TRACE3 = 17, -- extra
	TRACE2 = 18, -- extra
	TRACE = 19, -- extra
	DEBUG = 20,
	INFO = 30,
	NOTICE = 35,
	DEPRECATED = 37,
	WARNING = 40,
	ERROR = 50,
	FATAL = 60,
	NONE = 255,
}

---@diagnostic disable-next-line: duplicate-doc-alias
---@enum NotifyPriority
local NotifyPriority = {
	TRACE = 1,
	DEBUG = 16,
	INFO = 256, -- 2^8
	WARNING = 4096, -- 2^12
	ERROR = 65536, -- 2^16
	CRITICAL = 1048576, -- 2^20
	NONE = 16777216, -- 2^24
}

local NOTIFY_PRIORITY_NAMES = {
	[NotifyPriority.TRACE] = "TRACE",
	[NotifyPriority.DEBUG] = "DEBUG",
	[NotifyPriority.INFO] = "INFO",
	[NotifyPriority.WARNING] = "WARNING",
	[NotifyPriority.ERROR] = "ERROR",
	[NotifyPriority.CRITICAL] = "CRITICAL",
	[NotifyPriority.NONE] = "NONE",
}

---@diagnostic disable-next-line: duplicate-doc-alias
---@enum ResourceType
local ResourceType = {
	METAL = "metal",
	ENERGY = "energy",
} ---@type ResourceType

return {
	CONFIG_DIR = "LuaUI/Config/",
	CONFIG_FILES_PATTERN = "OverwatchConfig*.lua",
	CONFIG_FILE = "OverwatchConfig.lua", -- Will be loaded after the above and we write to it
	IS_RELEASE = IS_RELEASE,
	NAME = NAME,
	VERSION = VERSION,
	LogLevel = LogLevel,
	ResourceType = ResourceType,
	NOTIFY_PRIORITY = NotifyPriority,
	NOTIFY_PRIORITY_NAMES = NOTIFY_PRIORITY_NAMES,
}
end

-- module: core.game_context  (from lua/core/game_context.lua)
__B_MODULES['core.game_context'] = function(require)
local utils = require("core.utils")

local topics = {
	Cleanup = "Cleanup",
	UnitFinished = "UnitFinished",
	UnitDestroyed = "UnitDestroyed",
	PlayerChanged = "PlayerChanged",
}
local knownTopics = {}
for k, _ in pairs(topics) do
	table.insert(knownTopics, k)
end

local spGetGameFrame = Spring.GetGameFrame
local spGetGameSeconds = Spring.GetGameSeconds
local spGetGameRulesParam = Spring.GetGameRulesParam

-- Global game state and context information
--
-- GameContext tracks game-wide state like time, PVE mode, boss status,
-- and provides utility methods for checking game conditions.
--
---@class GameContext
---@field myTeamID integer
---@field myAllyTeamID integer
---@field myPlayerID integer
---@field inSpecMode boolean
---@field modOptions table<string, string>
---@field maxUnits integer
---@field maxUnitsPerPlayer integer
---@field frame number Current game frame
---@field time number Current game time
---@field startupSeconds number Game time at startup
---@field seconds number Current game time in seconds
---@field pveMode string The PVE mode, currently one of: "raptors", "scavengers", or "none"
---@field bossAnger number Queen/Boss anger level (0-100)
---@field bossHealth number Queen/Boss health percentage (0-100)
---@field evolution number Queen/Tech evolution level
---@field gracePeriod number Grace period timestamp
---@field graceRemaining number? Remaining grace period in seconds
---@field unitCount integer
---@field unitCounts table<integer, integer>
--
---@field _logger Logger
---@field _subscribers table<string, function[]> Table of event subscribers by event type
---@field _cleanupInterval integer
---@field _lastCleanup number
local GameContext = {}
GameContext.__index = GameContext

---@return GameContext
function GameContext.New(cleanUpInterval, logger)
	---@type GameContext
	local self = setmetatable({
		myTeamID = 0,
		myAllyTeamID = 0,
		myPlayerID = 0,
		inSpecMode = false,
		modOptions = Spring.GetModOptions(),
		maxUnits = Game.maxUnits,
		frame = 0,
		startupSeconds = spGetGameSeconds() or 0,
		seconds = 0,
		bossAnger = 0,
		bossHealth = 0,
		evolution = 0,
		gracePeriod = 0,
		graceRemaining = 0,
		unitCount = 0,
		unitCounts = {},

		_logger = logger,
		_subscribers = {},
		_cleanupInterval = cleanUpInterval,
		_lastCleanup = 0,
	}, GameContext)

	-- Do not cleanup on start / recreation of widget
	self._lastCleanup = self.startupSeconds + cleanUpInterval

	return self
end

function GameContext:Shutdown()
	self._subscribers = {}
end

---@return string
function GameContext:__tostring()
	return utils.DumpClass(self, "GameContext", {
		"myTeamID",
		"myAllyTeamID",
		"myPlayerID",
		"inSpecMode",
		"frame",
		"seconds",
		"pveMode",
		"bossAnger",
		"bossHealth",
		"evolution",
		"gracePeriod",
		"graceRemaining",
	})
end

---@return boolean
function GameContext:Init()
	self.myTeamID = Spring.GetMyTeamID()
	self.myPlayerID = Spring.GetMyPlayerID()
	self.myAllyTeamID = Spring.GetMyAllyTeamID()
	self.inSpecMode = Spring.IsReplay() or Spring.GetSpectatingState()

	self.pveMode = "none"
	if Spring.Utilities.Gametype.IsRaptors() then
		self.pveMode = "raptors"
	elseif Spring.Utilities.Gametype.IsScavengers() then
		self.pveMode = "scavengers"
	end

	self:GameFrame()

	return true
end

-- Refreshes all game state information
function GameContext:GameFrame()
	-- Update game time
	self.frame = spGetGameFrame() or 0
	self.seconds = spGetGameSeconds() or 0

	-- Update boss/queen info if available
	if self.pveMode == "raptors" then
		self.bossAnger = spGetGameRulesParam("raptorQueenAnger") or 0
		self.bossHealth = spGetGameRulesParam("raptorQueenHealth") or 100
		self.evolution = spGetGameRulesParam("raptorTechAnger") or 0
		self.gracePeriod = spGetGameRulesParam("raptorGracePeriod") or 0
	elseif self.pveMode == "scavengers" then
		self.bossAnger = spGetGameRulesParam("scavBossAnger") or 0
		self.bossHealth = spGetGameRulesParam("scavBossHealth") or 100
		self.evolution = spGetGameRulesParam("scavTechAnger") or 0
		self.gracePeriod = spGetGameRulesParam("scavGracePeriod") or 0
	end

	-- Update grace period
	-- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/gui_raptorStatsPanel.lua#L212
	if self.pveMode ~= "none" and self.gracePeriod > 0 then
		self.graceRemaining = math.ceil(((self.seconds - self.gracePeriod) * -1) - 0.5)
	end

	if self.seconds - self._lastCleanup < self._cleanupInterval then
		self:publish(topics.Cleanup)
		self._lastCleanup = self.seconds
	end
end

---@private
---@param topic string
---@param data table<string, any>?
function GameContext:publish(topic, data)
	if not self._subscribers[topic] then
		return
	end

	for _, cb in ipairs(self._subscribers[topic]) do
		cb(data)
	end
end

-- Subscribe to TeamContext events
--
---@param caller string Caller reference for debugging and logging.
---@param topic string The event type to subscribe to
---@param callback fun(data : table<string, any>?) The callback function to be called when the event occurs
---@return function? Unsubscribe function to remove this subscription, nil on failure
function GameContext:Subscribe(caller, topic, callback)
	if not table.contains(knownTopics, topic) then
		self._logger:Warning("Unknown topic '%s' in a gamecontext for caller '%s'", topic, caller)
		return nil
	end

	if not self._subscribers[topic] then
		self._subscribers[topic] = {}
	end

	table.insert(self._subscribers[topic], callback)

	-- Return an unsubscribe function
	return function()
		-- safety
		if not self._subscribers[topic] then
			return
		end

		table.removeAll(self._subscribers[topic], callback)
	end
end

-- Whetever the player changed spec mode or ally team.
--
---@return boolean
function GameContext:HasPlayerChanged()
	local currentspec = Spring.GetSpectatingState()
	local currentAllyTeamID = Spring.GetMyAllyTeamID()

	if (currentspec ~= self.inSpecMode) or (currentAllyTeamID ~= self.myAllyTeamID) then
		self:publish(topics.PlayerChanged)
		return true
	end

	return false
end

-- Called at the moment the team unit is completed.
--
---@param id integer unitID
---@param defID integer unitDefID
---@param teamID integer unitTeamID
function GameContext:UnitFinished(id, defID, teamID)
	self.unitCount = self.unitCount + 1

	if not self.unitCounts[defID] then
		self.unitCounts[defID] = 1
	else
		self.unitCounts[defID] = self.unitCounts[defID] + 1
	end

	-- Runs after unitCounts so rules have these updated.
	self:publish(topics.UnitFinished, { id = id, teamID = teamID, defID = defID })
end

-- Called when a team unit is destroyed.
--
---@param id integer unitID
---@param defID integer unitDefID
---@param teamID integer unitTeamID
function GameContext:UnitDestroyed(id, defID, teamID)
	if self.unitCount > 0 then
		self.unitCount = self.unitCount - 1
	end

	if not self.unitCounts[defID] then
		return
	end

	if self.unitCounts[defID] > 0 then
		self.unitCounts[defID] = self.unitCounts[defID] - 1
	end

	-- Runs after unitCounts so rules have these updated.
	self:publish(topics.UnitDestroyed, { id = id, teamID = teamID, defID = defID })
end

-- Check if evolution is within range
--
---@param min number?
---@param max number?
---@return boolean
function GameContext:IsEvolutionInRange(min, max)
	min = min or 0
	max = max or 100
	return self.evolution >= min and self.evolution <= max
end

-- Check if boss anger is within range
--
---@param min number
---@param max number
---@return boolean
function GameContext:IsBossAngerInRange(min, max)
	min = min or 0
	max = max or 100
	return self.bossAnger >= min and self.bossAnger <= max
end

-- Check if grace period is within range
--
---@param min number
---@param max number
---@return boolean
function GameContext:IsGraceInRange(min, max)
	if not self.graceRemaining or self.graceRemaining <= 0 then
		return false
	end

	min = min or 0
	max = max or math.huge
	return self.graceRemaining >= min and self.graceRemaining <= max
end

return GameContext
end

-- module: core.logger  (from lua/core/logger.lua)
__B_MODULES['core.logger'] = function(require)
local constants = require("core.constants")

local spEcho = Spring.Echo
local spLog = Spring.Log

local LogLevel = constants.LogLevel

local levelNames = {
	[LogLevel.ALL] = "ALL",
	[LogLevel.TRACE3] = "TRACE3",
	[LogLevel.TRACE2] = "TRACE2",
	[LogLevel.TRACE] = "TRACE",
	[LogLevel.DEBUG] = "DEBUG",
	[LogLevel.INFO] = "INFO",
	[LogLevel.NOTICE] = "NOTICE",
	[LogLevel.DEPRECATED] = "DEPRECATED",
	[LogLevel.WARNING] = "WARNING",
	[LogLevel.ERROR] = "ERROR",
	[LogLevel.FATAL] = "FATAL",
	[LogLevel.NONE] = "NONE",
}

---@param level MyLogLevel
---@return string
local function levelName(level)
	-- Direct mapping
	if levelNames[level] then
		return levelNames[level]
	end

	-- Overflow.
	if level <= LogLevel.ALL then
		return "ALL"
	elseif level >= LogLevel.NONE then
		return "NONE"
	end

	-- Inbetween.
	if level > LogLevel.FATAL then
		return "FATAL+" .. (level - LogLevel.FATAL)
	end

	if level < LogLevel.DEBUG then
		return "DEBUG-" .. (LogLevel.DEBUG - level)
	end

	-- Unknown / unexpected value
	return "UNKN(" .. tostring(level) .. ")"
end

-- Logger
--
-- Example:
--
-- ```lua
-- local Logger = require("lib.logger")
-- local logger = Logger("MyWidget", LogLevel.ALL, true)
-- logger.Trace3("Trace me: %s", type(toTrace))
-- ```
--
---@class Logger
---@field section string
---@field level MyLogLevel
---@field useEcho boolean Use Spring.Echo instead of Spring.Log
local Logger = {}
Logger.__index = Logger

---@param section string
---@param level MyLogLevel
---@param useEcho boolean
---@return Logger
function Logger.New(section, level, useEcho)
	---@type Logger
	local self =
		setmetatable({ section = section, level = level, useEcho = useEcho or false }, Logger)

	return self
end

-- Creates a new logger with the given section and same level/useEcho as current.
--
---@param section string
---@return Logger
function Logger:WithSection(section)
	return Logger.New(section, self.level, self.useEcho)
end

-- Log a message auto switches to "Spring.Echo" when you specify a level < INFO as releases are limited to INFO.
--
---@param level MyLogLevel|integer
---@param msg string
function Logger:Log(level, msg, ...)
	-- This is first so developers get a info early.
	if type(msg) ~= "string" then
		spEcho("Error: got an invalid message", msg)
	end

	if not (self.level <= level) then
		return
	end

	if self.useEcho or (self.level < LogLevel.INFO) then
		if select("#", ...) > 0 then
			local status, msg2 = pcall(string.format, msg, ...)
			if status then
				msg = msg2
			else
				msg = msg .. ", failed to format!"
				level = LogLevel.ERROR
			end
		end

		msg = string.format("[%s::%s] ", self.section, levelName(level)) .. msg

		spEcho(msg)
	else
		if select("#", ...) > 0 then
			local status, msg2 = pcall(string.format, msg, ...)
			if status then
				msg = msg2
			else
				msg = msg .. ", failed to format!"
				level = LogLevel.ERROR
			end
		end

		spLog(self.section, level, msg)
	end
end

-- Helpers that wrap the above Log method

---@param msg string
function Logger:Info(msg, ...)
	self:Log(LogLevel.INFO, msg, ...)
end

---@param msg string
function Logger:Warning(msg, ...)
	self:Log(LogLevel.WARNING, msg, ...)
end

---@param msg string
function Logger:Error(msg, ...)
	self:Log(LogLevel.ERROR, msg, ...)
end

---@param msg string
function Logger:Fatal(msg, ...)
	self:Log(LogLevel.FATAL, msg, ...)
end

---@param msg string
function Logger:Debug(msg, ...)
	self:Log(LogLevel.DEBUG, msg, ...)
end

---@param msg string
function Logger:Trace(msg, ...)
	self:Log(LogLevel.TRACE, msg, ...)
end

function Logger:Trace2(msg, ...)
	self:Log(LogLevel.TRACE2, msg, ...)
end

function Logger:Trace3(msg, ...)
	self:Log(LogLevel.TRACE3, msg, ...)
end

---@return Logger
return Logger
end

-- module: core.team_context  (from lua/core/team_context.lua)
__B_MODULES['core.team_context'] = function(require)
local utils = require("core.utils")
local TeamResource = require("core.team_resource")

local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetTeamMaxUnits = Spring.GetTeamMaxUnits

local topics = {
	UnitFinished = "UnitFinished",
	UnitDestroyed = "UnitDestroyed",
}
local knownTopics = {}
for k, _ in pairs(topics) do
	table.insert(knownTopics, k)
end

---@alias RulesParam string|number

-- TeamContext provides access to team-specific data and resources.
--
---@class TeamContext
---@field id integer The team ID
---@field allyTeamId number
---@field leaderId number
---@field leaderName string
---@field color table<string, number>
---@field maxUnits integer
---@field unitCount integer
---@field unitCounts table<integer, integer>
--
---@field _logger Logger
---@field _resources table<string, TeamResource>
---@field _subscribers table<string, function[]> Table of event subscribers by event type
local TeamContext = {}
TeamContext.__index = TeamContext

---@param id number
---@param logger Logger
---@return TeamContext
function TeamContext.New(id, logger)
	---@type TeamContext
	local self = setmetatable({
		id = id,
		allyTeamId = 0,
		leaderId = 0,
		leaderName = "Unknown",
		color = {},
		maxUnits = 0,
		unitCount = 0,
		unitCounts = {},
		_logger = logger,
		_resources = {},
		_subscribers = {},
	}, TeamContext)

	local _, leaderId, _, _, _, allyTeamId = spGetTeamInfo(self.id, false)
	self.leaderId = leaderId
	self.allyTeamId = allyTeamId
	self.leaderName = (
		(WG and WG.playernames and WG.playernames.getPlayername)
		and WG.playernames.getPlayername(leaderId)
	)
		or spGetPlayerInfo(leaderId, false)
		or "Unknown"

	local r, g, b, a = Spring.GetTeamColor(self.id)
	self.color = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }

	local maxUnits, unitCount = spGetTeamMaxUnits(self.id)
	self.maxUnits = maxUnits
	self.unitCount = unitCount or 0

	return self
end

function TeamContext:Shutdown()
	for _, r in pairs(self._resources) do
		r:Shutdown()
	end

	self._subscribers = {}
end

---@return string
function TeamContext:__tostring()
	return utils.DumpClass(
		self,
		"TeamContext",
		{ "id", "leaderName", "maxUnits", "unitCount", "_resources" }
	)
end

-- Refreshes resources
function TeamContext:GameFrame()
	for _, r in pairs(self._resources) do
		r:GameFrame()
	end
end

---@private
---@param topic string
---@param data table<string, any>?
function TeamContext:publish(topic, data)
	if not self._subscribers[topic] then
		return
	end

	for _, cb in ipairs(self._subscribers[topic]) do
		cb(data)
	end
end

-- Subscribe to TeamContext events
--
---@param caller string Caller reference for debugging and logging.
---@param topic string The event type to subscribe to
---@param callback fun(data : table<string, any>?) The callback function to be called when the event occurs
---@return function? Unsubscribe function to remove this subscription, nil on failure
function TeamContext:Subscribe(caller, topic, callback)
	if not table.contains(knownTopics, topic) then
		self._logger:Warning("Unknown topic '%s' in a teamcontext for caller '%s'", topic, caller)
		return nil
	end

	if not self._subscribers[topic] then
		self._subscribers[topic] = {}
	end

	table.insert(self._subscribers[topic], callback)

	-- Return an unsubscribe function
	return function()
		-- safety
		if not self._subscribers[topic] then
			return
		end

		table.removeAll(self._subscribers[topic], callback)
	end
end

-- IsReal checks if the current team is real.
--.
---@return boolean
function TeamContext:IsReal()
	return utils.IsTeamReal(self.allyTeamId)
end

function TeamContext:updateUnitCount()
	local maxUnits, unitCount = spGetTeamMaxUnits(self.id)
	self.maxUnits = maxUnits
	self.unitCount = unitCount or 0
end

-- Called at the moment the team unit is completed.
--
---@param id integer unitID
---@param defID integer unitDefID
function TeamContext:UnitFinished(id, defID)
	self:updateUnitCount()

	if not self.unitCounts[defID] then
		self.unitCounts[defID] = 1
	else
		self.unitCounts[defID] = self.unitCounts[defID] + 1
	end

	-- Runs after unitCounts so rules have these updated.
	self:publish(topics.UnitFinished, { id = id, teamID = self.id, defID = defID })
end

-- Called when a team unit is destroyed.
--
---@param id integer unitID
---@param defID integer unitDefID
function TeamContext:UnitDestroyed(id, defID)
	self:updateUnitCount()

	if not self.unitCounts[defID] then
		return
	end

	if self.unitCounts[defID] > 0 then
		self.unitCounts[defID] = self.unitCounts[defID] - 1
	end

	-- Runs after unitCounts so rules have these updated.
	self:publish(topics.UnitDestroyed, { id = id, teamID = self.id, defID = defID })
end

-- Get team resources for a specific resource type
--
---@param resourceType ResourceType
function TeamContext:GetResource(resourceType)
	if not self._resources[resourceType] then
		self._resources[resourceType] = TeamResource.New(self, resourceType, self._logger)
	end

	return self._resources[resourceType]
end

-- Get team rules parameter
-- Returns a value from Spring.GetTeamRulesParam
--
---@param param string
---@return RulesParam?
function TeamContext:GetRulesParam(param)
	return spGetTeamRulesParam(self.id, param)
end

-- Same as GetRulesParam but makes sure to return a number, default is 0.
--
---@param param string
---@param default number?
---@return number
function TeamContext:GetRulesParamNum(param, default)
	local val = spGetTeamRulesParam(self.id, param)

	return tonumber(val) or (default and default or 0)
end

-- Get count of units by unit def name.
--
---@param unitName string
function TeamContext:GetUnitCountByDefName(unitName)
	local unitDefID = UnitDefNames[unitName].id
	return self.unitCounts[unitDefID] or 0
end

return TeamContext
end

-- module: core.team_resource  (from lua/core/team_resource.lua)
__B_MODULES['core.team_resource'] = function(require)
local constants = require("core.constants")
local utils = require("core.utils")

local spGetTeamResources = Spring.GetTeamResources

local RT_ENERGY = constants.ResourceType.ENERGY

local topics = {
	IsBetween = "IsBetween",
	IsBelow = "IsBelow",
	IsAbove = "IsAbove",
	IsFull = "IsFull",
	IsLow = "IsLow",
	HasExcess = "HasExcess",
}
local knownTopics = {}
for k, _ in pairs(topics) do
	table.insert(knownTopics, k)
end

---@alias teamResourceTopicsFilter fun(resource: TeamResource, options: table): boolean

---@type table<string, teamResourceTopicsFilter>
local topicsFilter = {
	IsBelow = function(resource, options)
		return resource:IsBelow(options.threshold)
	end,
	IsAbove = function(resource, options)
		return resource:IsAbove(options.threshold)
	end,
	IsBetween = function(resource, options)
		if not options.min or not options.max then
			return false
		end

		return resource:IsBetween(options.min, options.max)
	end,
	IsFull = function(resource, options)
		return resource:IsAbove()
	end,
	IsLow = function(resource, options)
		return resource:IsBelow()
	end,
	HasExcess = function(resource, options)
		return resource:HasExcess(options.threshold)
	end,
}

-- Resource information for a specific team
--
-- A wrapper for Spring.GetTeamResources
--
---@class TeamResource
---@field teamCtx TeamContext
---@field teamId number
---@field resourceType ResourceType
---@field current number
---@field storage number
---@field pull number
---@field income number
---@field expense number
---@field share number
---@field sent number
---@field received number
---@field excess number
---@field _logger Logger
---@field _subscribers table<string, table> Table of event subscribers by event type
local TeamResource = {}
TeamResource.__index = TeamResource

---@param team TeamContext
---@param resourceType ResourceType
---@param logger Logger
---@return TeamResource
function TeamResource.New(team, resourceType, logger)
	---@type TeamResource
	local self = setmetatable({
		teamCtx = team,
		teamId = team.id,
		resourceType = resourceType,
		current = 0,
		storage = 0,
		pull = 0,
		income = 0,
		expense = 0,
		share = 0,
		sent = 0,
		received = 0,
		excess = 0,
		_logger = logger,
		_subscribers = {},
	}, TeamResource)

	self:GameFrame()

	return self
end

function TeamResource:Shutdown()
	self._subscribers = {}
end

---@return string
function TeamResource:__tostring()
	return utils.DumpClass(self, "TeamResource", {
		"teamId",
		"resourceType",
		"current",
		"storage",
		"pull",
		"income",
		"expense",
		"share",
		"sent",
		"received",
		"excess",
	})
end

function TeamResource:GameFrame()
	local current, storage, pull, income, expense, share, sent, received, excess =
		spGetTeamResources(self.teamId, tostring(self.resourceType))

	self.current = current or 0
	self.storage = storage or 1
	self.pull = pull or 0
	self.income = income or 0
	self.expense = expense or 0
	self.share = share or 0
	self.sent = sent or 0
	self.received = received or 0
	self.excess = excess or 0

	if self.current > 0 then
		self:publish(topics.IsBelow)
		self:publish(topics.IsAbove)
		self:publish(topics.IsBetween)
		self:publish(topics.IsFull)
		self:publish(topics.IsLow)
		self:publish(topics.HasExcess)
	end
end

---@private
---@param topic string
function TeamResource:publish(topic)
	if not self._subscribers[topic] then
		return
	end

	local topicFilter = topicsFilter[topic]

	if topicFilter then
		for _, options in pairs(self._subscribers[topic]) do
			if topicFilter(self, options) then
				options._callback()
			end
		end
	else
		for _, options in pairs(self._subscribers[topic]) do
			options._callback()
		end
	end
end

-- Subscribe to TeamResource events
--
---@param caller string Caller reference for debugging and logging.
---@param topic string The event type to subscribe to
---@param options table
---@param callback fun() The callback function to be called when the event occurs
---@return function? Unsubscribe function to remove this subscription, nil on failure
function TeamResource:Subscribe(caller, topic, options, callback)
	if not table.contains(knownTopics, topic) then
		self._logger:Warning("Unknown topic '%s' in a teamcontext for caller '%s'", topic, caller)
		return nil
	end

	if not self._subscribers[topic] then
		self._subscribers[topic] = {}
	end

	options._callback = callback

	table.insert(self._subscribers[topic], options)

	-- Return an unsubscribe function
	return function()
		-- safety
		if not self._subscribers[topic] then
			return
		end

		table.removeAll(self._subscribers[topic], options)
	end
end

-- Get resource storage ratio
-- Returns the ratio of current amount to total storage (0-1)
function TeamResource:GetRatio()
	if self.resourceType == RT_ENERGY then
		local mmUse = self.teamCtx:GetRulesParamNum("mmUse", 0)
		return (self.current + mmUse) / self.storage
	end

	return self.current / self.storage
end

-- Get net resource income
-- Returns the difference between income and expense rates
function TeamResource:GetNetResource()
	return self.income - self.expense
end

-- Check if resource storage is nearly full
-- Returns true if storage ratio is above the threshold
--
---@param threshold number? (default 0.9)
function TeamResource:IsAbove(threshold)
	threshold = threshold or 0.9
	return self:GetRatio() >= threshold
end

-- Check if resource is below threshold
-- Returns true if storage ratio is below the threshold
--
---@param threshold number? (default 0.2)
function TeamResource:IsBelow(threshold)
	threshold = threshold or 0.2
	return self:GetRatio() <= threshold
end

-- Returns whether the resource between min and max
--
---@param min integer
---@param max integer
---@return boolean
function TeamResource:IsBetween(min, max)
	return self:GetRatio() <= min and self:GetRatio() >= max
end

-- Check if excess is above threshold.
---@param threshold number? (default 0.1)
function TeamResource:HasExcess(threshold)
	threshold = threshold or 0.1
	return self.excess >= (self.storage * threshold)
end

return TeamResource
end

-- module: core.utils  (from lua/core/utils.lua)
__B_MODULES['core.utils'] = function(require)
local spGetTeamList = Spring.GetTeamList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo

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
		local tt = type(target[k])

		if target[k] == nil then
			-- Apply default if key doesn't exist in target
			target[k] = v
		elseif vt == "table" and tt == "table" then
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
					target[k] = table.merge(target[k], validate[k])
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
					target[k] = table.merge(target[k], validate[k])
				else
					target[k] = validate[k]
				end
			end
		end
	end

	-- Success
	return nil
end

-- IsTeamReal checks if the given ally team id is a real team.
--
---@param allyTeamId number The ally team to query.
function utils.IsTeamReal(allyTeamId)
	if allyTeamId == nil then
		return false
	end
	local leaderID, isDead, leaderName
	local tids = spGetTeamList(allyTeamId)
	if not tids then
		return false
	end

	for _, tID in ipairs(tids) do
		_, leaderID, isDead = spGetTeamInfo(tID, false)
		leaderName = (
			(WG and WG.playernames and WG.playernames.getPlayername)
			and WG.playernames.getPlayername(leaderID)
		) or spGetPlayerInfo(leaderID, false)
		if leaderName ~= nil or isDead then
			return true
		end
	end
	return false
end

return utils
end

-- module: default_config  (from lua/default_config.lua)
__B_MODULES['default_config'] = function(require)
-- This config is shipped with the widget, no need to copy.

---@type ConfigFormat
return {
	rules = {
		resource_stale = {
			enabled = true,
			blueprint = "resource_stale",
			channels = { "marquee", "uilog" },
		},
		resource_stale_say = {
			enabled = false,
			blueprint = "resource_stale",
			template = "I'm staling %{kind} (auto-message)",
			channels = { "command" },
			parameters = {
				kind = { "metal" },
			},
		},
		resource_waste = {
			enabled = true,
			blueprint = "resource_waste",
			channels = { "marquee", "uilog" },
			parameters = {
				channels = {
					marquee = {
						fontColor = {
							a = 1,
							b = 0,
							g = 0,
							r = 1,
						},
					},
				},
			},
		},
		resource_waste_say = {
			enabled = false,
			blueprint = "resource_waste",
			template = "I'm excessing %{excess} of %{kind} (auto-message)",
			channels = { "command" },
		},
		unit_limit = {
			enabled = true,
			blueprint = "unit_limit",
		},
		resource_converter_level = {
			enabled = true,
			blueprint = "resource_converter_level",
		},
		unit_lost = {
			enabled = true,
			blueprint = "unit_lost",
			parameters = {
				commanders = true,
			},
		},
		unit_lost_ping = {
			enabled = true,
			blueprint = "unit_lost_ping",
			channels = { "ping", "sound" },
			parameters = {
				commanders = true,
			},
		},
	},
}
end

-- module: i18n.interpolate  (from vendor/lua/i18n/i18n/interpolate.lua)
__B_MODULES['i18n.interpolate'] = function(require)
local unpack = unpack or table.unpack -- lua 5.2 compat

local FORMAT_CHARS = { c=1, d=1, E=1, e=1, f=1, g=1, G=1, i=1, o=1, u=1, X=1, x=1, s=1, q=1, ['%']=1 }

-- matches a string of type %{age}
local function interpolateValue(string, variables)
  return string:gsub("(.?)%%{%s*(.-)%s*}",
    function (previous, key)
      if previous == "%" then
        return
      else
        return previous .. tostring(variables[key])
      end
    end)
end

-- matches a string of type %<age>.d
local function interpolateField(string, variables)
  return string:gsub("(.?)%%<%s*(.-)%s*>%.([cdEefgGiouXxsq])",
    function (previous, key, format)
      if previous == "%" then
        return
      else
        return previous .. string.format("%" .. format, variables[key] or "nil")
      end
    end)
end

local function escapePercentages(string)
  return string:gsub("(%%)(.?)", function(_, char)
    if FORMAT_CHARS[char] then
      return "%" .. char
    else
      return "%%" .. char
    end
  end)
end

local function unescapePercentages(string)
  return string:gsub("(%%%%)(.?)", function(_, char)
    if FORMAT_CHARS[char] then
      return "%" .. char
    else
      return "%%" .. char
    end
  end)
end

local function interpolate(pattern, variables)
  variables = variables or {}
  local result = pattern
  result = interpolateValue(result, variables)
  result = interpolateField(result, variables)
  result = escapePercentages(result)
  result = string.format(result, unpack(variables))
  result = unescapePercentages(result)
  return result
end

return interpolate
end

-- module: rule  (from lua/rule.lua)
__B_MODULES['rule'] = function(require)
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
end

-- module: rule_state  (from lua/rule_state.lua)
__B_MODULES['rule_state'] = function(require)
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
end

-- module: ui.rml_ui  (from lua/ui/rml_ui/init.lua)
__B_MODULES['ui.rml_ui'] = function(require)
-- RmlUi UI Rendering
local utils = require("core.utils")
local constants = require("core.constants")
local controls = require("ui.rml_ui.controls")

local RCSS_CHUNK = require("ui.rml_ui.overwatch-rcss")
local RML_CHUNK = require("ui.rml_ui.overwatch-rml")

local LogLevel = constants.LogLevel

local spGetViewGeometry = Spring.GetViewGeometry
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

-- Constants
local IS_RELEASE = constants.IS_RELEASE
local DEFAULT_TEXT_COLOR = "#ffffffff"
local DEFAULT_BG_COLOR = "#4a4a4a00"

local CONFIG_SECTION = "rmlUi"
local CONFIG_DEFAULTS = {
	show = true,
	autoSave = IS_RELEASE,
	teamColoring = true,
	prioColoring = true,

	panel = {
		height = "261px",
		left = "1545px",
		top = "1120px",
		width = "606px",
	},

	showButtons = true,

	columns = {
		time = { visible = true },
		playerName = { visible = true },
		priority = { visible = false },
		category = { visible = true },
		rule = { visible = false },
		icon = { visible = false },
		message = { visible = true },
	},

	logMax = IS_RELEASE and 100 or 500,
}

local MODEL_NAME = "overwatch"
local RML_PATH = "LuaUI/Widgets/overwatch.rml"
local RCSS_PATH = "LuaUI/Widgets/overwatch.rcss"

-- Vars
local logger ---@type Logger
local gameContext ---@type GameContext
local teamContexts ---@type TeamContext[]
local config ---@type Config

local uiConfig = {}

local logs = {} ---@type table[]

local viewSizeX, viewSizeY
local widgetScale
local font2
local marqueeMessage ---@type Notification?
local marqueeStartTime

local NOTIFY_PRIORITY = constants.NOTIFY_PRIORITY
local NOTIFY_PRIORITY_BACKGROUND_COLORS = {
	[NOTIFY_PRIORITY.TRACE] = "#4a4a4a00",
	[NOTIFY_PRIORITY.DEBUG] = "#2AC8CA00",
	[NOTIFY_PRIORITY.INFO] = "#4a4a4a00",
	[NOTIFY_PRIORITY.WARNING] = "#00FF48AA",
	[NOTIFY_PRIORITY.ERROR] = "#4a4a4a00",
	[NOTIFY_PRIORITY.CRITICAL] = "#4a4a4a00",
	[NOTIFY_PRIORITY.NONE] = "#4a4a4a00",
}

---@param r number
---@param g number
---@param b number
---@param a number
---@returns string
local function rgbaToHex(r, g, b, a)
	return string.format(
		"#%02x%02x%02x%02x",
		math.floor(r * 255),
		math.floor(g * 255),
		math.floor(b * 255),
		math.floor(a * 255)
	)
end

local function saveConfig()
	if IS_RELEASE then
		config:Save(
			constants.CONFIG_DIR .. constants.CONFIG_FILE,
			"-- " .. constants.NAME .. " config, auto-generated: DO NOT EDIT --\n"
		)
	else
		config:Save(
			constants.CONFIG_DIR .. constants.CONFIG_FILE,
			"-- " .. constants.NAME .. " debug config, auto-generated: DO NOT EDIT --\n",
			true
		)
	end
end

---@class (exact) OverwatchUiModel
---@field isDev boolean
---@field debugging boolean
---@field headerName string
---@field panelMode string
---@field panel table
---@field autoSave boolean
---@field showButtons boolean
---@field columns any
---@field numColumns integer
---@field logs table[]
---@field logCount integer
---@field logMax integer
local initModel = {
	isDev = not IS_RELEASE,
	debugging = false,

	panelMode = "log",

	-- start: Overwritten by config.
	panel = {},
	autoSave = IS_RELEASE,
	showButtons = true,
	logMax = 100,
	-- end

	columns = {
		[1] = { label = "Time", width = "3.5rem", visible = true, teamColor = false },
		[2] = { label = "Player Name", width = "14rem", visible = true, teamColor = true },
		[3] = { label = "Priority", width = "5rem", visible = true, teamColor = false },
		[4] = { label = "Category", width = "5rem", visible = true, teamColor = false },
		[5] = { label = "Rule", width = "17rem", visible = true, teamColor = false },
		[6] = { label = "Icon", width = "2rem", visible = false, teamColor = false },
		[7] = { label = "Message", width = "100%", visible = true, teamColor = false },
	},
	numColumns = 7, -- Haven't found a way to calculate that in RML.

	logs = {},
	logCount = 0,
}
local rmlContext ---@type RmlUi.Context?
local dmHandle ---@type RmlUi.SolLuaDataModel<OverwatchUiModel>?
local document ---@type RmlUi.Document?

-- Helper to check if file contents and chunk are the same.
--
---@param chunk string
---@param path string
---@return boolean tmp false if not else true
local function checkFile(chunk, path)
	local file = io.open(path, "r")
	if not file then
		return false
	end

	local fileChunk = file:read("*a")
	file:close()

	if chunk ~= fileChunk then
		return false
	end

	return true
end

-- Helper to overwrite file contents with the given chunk.
--
---@param chunk string
---@param path string
local function overwriteFile(chunk, path)
	local file = io.open(path, "w")

	if not file then
		logger:Error("unable to save file %s", path)
		return
	end

	if not file:write(chunk) then
		logger:Error("failed to write to file %s", path)
		file:close()
		return
	end

	file:close()
end

local function updateView()
	viewSizeX, viewSizeY = spGetViewGeometry()
	widgetScale = (0.75 + (viewSizeX * viewSizeY / 10000000))

	if WG and WG["fonts"] then
		-- font = WG["fonts"].getFont()
		font2 = WG["fonts"].getFont(nil, 1.5)
	end
end

local function drawMarqueeMessage()
	if not marqueeMessage or not marqueeStartTime or not font2 then
		return
	end

	Spring.Echo("in draw")

	local params = marqueeMessage.parameters
	if not params then
		return
	end

	local currentTimer = spGetTimer()
	local elapsed = spDiffTimers(currentTimer, marqueeStartTime)

	-- Check if message should be dismissed.
	if elapsed > params.duration then
		marqueeMessage = nil
		marqueeStartTime = nil
		return
	end

	local fc = params.fontColor
	local foc = params.fontOutlineColor

	-- Calculate vertical position (scroll up from bottom).
	local marqueeY = viewSizeY - (elapsed * params.speed * viewSizeY)

	if marqueeY > 0 then
		font2:Begin()
		font2:SetTextColor(fc.r, fc.g, fc.b, fc.a)
		font2:SetOutlineColor(foc.r, foc.g, foc.b, foc.a)
		font2:Print(
			marqueeMessage.message,
			viewSizeX / 2,
			marqueeY,
			params.fontSize * widgetScale,
			"co"
		)
		font2:End()
	else
		-- Message scrolled off screen.
		marqueeMessage = nil
		marqueeStartTime = nil
	end
end

-- API
---@type OverwatchUi
local ui = {
	Init = function(l, gctx, cfg)
		if l then
			logger = l:WithSection(l.section .. "::RmlUi")
		end

		if gctx then
			gameContext = gctx
			teamContexts = {}
		end

		if cfg then
			config = cfg
		end

		if not RmlUi then
			-- RmLUI not found, head out.
			logger:Warning("RmlUi not found, won't have an UI")
			return false
		end

		if not logger or not gameContext or not config then
			logger:Warning(
				"logger/gameContext/config not given, won't have an UI. logger=%s, gameContext=%s, config=%s",
				type(logger),
				type(gameContext),
				type(config)
			)
			return false
		end

		-- Our own section in the config
		if not config.data[CONFIG_SECTION] then
			config.data[CONFIG_SECTION] = {}
		end
		uiConfig = config.data[CONFIG_SECTION]

		-- Apply defaults
		utils.ApplyDefaults(uiConfig, CONFIG_DEFAULTS)

		-- Copy users panel config into the data model.
		initModel.panel = table.copy(uiConfig.panel)
		initModel.showButtons = uiConfig.showButtons
		initModel.autoSave = uiConfig.autoSave
		initModel.logMax = uiConfig.logMax

		initModel.columns[1].visible = uiConfig.columns.time.visible
		initModel.columns[2].visible = uiConfig.columns.playerName.visible
		initModel.columns[3].visible = uiConfig.columns.priority.visible
		initModel.columns[4].visible = uiConfig.columns.category.visible
		initModel.columns[5].visible = uiConfig.columns.rule.visible
		initModel.columns[6].visible = uiConfig.columns.icon.visible
		initModel.columns[7].visible = uiConfig.columns.message.visible

		-- Set Player Name column visibility
		-- initModel.columns[1].visible = false -- gameContext.inSpecMode

		rmlContext = RmlUi.GetContext("shared")
		if not rmlContext then
			logger:Error("failed to get RmlUi context")
			return false
		end

		updateView()

		controls.Init(logger, rmlContext)
		---@diagnostic disable-next-line: missing-parameter
		dmHandle = rmlContext:OpenDataModel(MODEL_NAME, initModel)
		controls.SetDmHandle(dmHandle)

		-- Write .rml and .rcss if needed
		if IS_RELEASE then
			if not checkFile(RML_CHUNK, RML_PATH) then
				logger:Debug("Writing .rml: %s", RML_PATH)
				overwriteFile(RML_CHUNK, RML_PATH)
			end

			if not checkFile(RCSS_CHUNK, RCSS_PATH) then
				logger:Debug("Writing .rcss: %s", RCSS_PATH)
				overwriteFile(RCSS_CHUNK, RCSS_PATH)
			end
		end

		---@diagnostic disable-next-line: redundant-parameter
		document = rmlContext:LoadDocument(RML_PATH, controls)
		document:ReloadStyleSheet()

		local widget = document:GetElementById("overwatch-widget")
		if not widget then
			logger:Error("failed to get my widget from the document")
			return false
		end

		local remember = { "left", "top", "width", "height" }
		widget:AddEventListener("blur", function()
			if not uiConfig["panel"] then
				uiConfig["panel"] = {}
			end

			local dirty = false
			for k, v in pairs(widget.style) do
				if table.contains(remember, k) then
					if uiConfig["panel"][k] ~= v then
						uiConfig["panel"][k] = v
						dirty = true
					end
				end
			end

			if dirty and uiConfig.autoSave then
				saveConfig()
			end
		end, true)

		if uiConfig.show then
			document:Show()
		end

		return true
	end,

	Shutdown = function()
		if not rmlContext then
			logger:Warning("shutdown has no rmlContext")
			return false
		end

		if dmHandle then
			rmlContext:RemoveDataModel(MODEL_NAME)
			dmHandle = nil
		end

		if document then
			document:Close()
			document = nil
		end

		rmlContext = nil

		return true
	end,

	Save = function()
		saveConfig()
	end,

	SetTeamContext = function(team)
		teamContexts[team.id] = team
	end,

	GetTeamContext = function(team_id)
		return teamContexts[team_id]
	end,

	Log = function(n)
		if not dmHandle then
			logger:Warning("adding a log without a handle")
			return
		end

		local logMax = dmHandle.logMax

		local teamColor = n.team.color
		local teamColorHex = rgbaToHex(teamColor.a, teamColor.g, teamColor.b, teamColor.a)
		local prioBgColor = NOTIFY_PRIORITY_BACKGROUND_COLORS[n.priority] or DEFAULT_BG_COLOR

		-- need to be aligned with the columns in init_model above.
		table.insert(logs, 1, {
			[1] = {
				value = string.formatTime(n.seconds),
				color = DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
			[2] = {
				value = n.team.leaderName,
				color = uiConfig.teamColoring and teamColorHex or DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
			[3] = {
				value = constants.NOTIFY_PRIORITY_NAMES[n.priority],
				color = DEFAULT_TEXT_COLOR,
				bgColor = uiConfig.prioColoring and prioBgColor or DEFAULT_BG_COLOR,
			},
			[4] = {
				value = n.category or "",
				color = DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
			[5] = {
				value = n.config.id or "",
				color = DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
			[6] = { value = n.icon or "", color = DEFAULT_TEXT_COLOR, bgColor = DEFAULT_BG_COLOR },
			[7] = {
				value = n.message or "",
				color = DEFAULT_TEXT_COLOR,
				bgColor = DEFAULT_BG_COLOR,
			},
		})

		while #logs > logMax do
			table.remove(logs)
		end

		dmHandle.logs = logs
		dmHandle.logCount = #logs
	end,

	Marquee = function(n)
		if marqueeMessage or marqueeStartTime or not font2 then
			if logger.level >= LogLevel.TRACE2 then
				logger:Trace2("Not sending marquee message: %s", n.message)
			end

			return
		end

		marqueeMessage = n
		marqueeStartTime = spGetTimer()
	end,

	PlayerHasChanged = function() end,

	-- Forwarded widget callins

	DrawScreen = function(viewSizeX, viewSizeY)
		drawMarqueeMessage()
	end,

	ViewResize = function()
		updateView()
	end,

	KeyPress = function(keyCode, mods, isRepeat, label, utf32char, scanCode, actionList)
		if not document then
			return false
		end

		if keyCode == 0x70 and mods.alt and not mods.ctrl and not mods.shift then -- Alt+'p' key
			if uiConfig.show then
				document:Hide()
				uiConfig.show = false
			else
				document:Show()
				uiConfig.show = true
			end

			-- Save
			if uiConfig.autoSave then
				saveConfig()
			end
		end

		return false
	end,

	KeyRelease = function(keyCode, mods, label, utf32char, scanCode, actionList)
		return false
	end,

	MousePress = function(x, y, button)
		return false
	end,

	MouseRelease = function(x, y, button)
		return false
	end,

	MouseMove = function(x, y, dx, dy, button) end,

	MouseWheel = function(up, value) end,
}
controls.SetUi(ui)

return ui
end

-- module: ui.rml_ui.controls  (from lua/ui/rml_ui/controls.lua)
__B_MODULES['ui.rml_ui.controls'] = function(require)
-- Controls available from RML.

local spSendCommands = Spring.SendCommands

local logger ---@type Logger
-- local rmlContext ---@type RmlUi.Context
local ui ---@type OverwatchUi
local dmHandle

local controls = {}

-- checkHandle is a safety helper to check we have required locals.
--
---@return boolean
local function checkHandle()
	if not ui or not dmHandle then
		logger:Warning("ui controls have no ui set, they won't work")
		return false
	end

	return true
end

---@param l Logger
---@param rmlCtx RmlUi.Context
function controls.Init(l, rmlCtx)
	logger = l
	-- rmlContext = rmlCtx
end

function controls.SetUi(u)
	ui = u
end

function controls.SetDmHandle(h)
	dmHandle = h
end

function controls:Save()
	ui.Save()
end

function controls:Reload()
	if not ui then
		logger:Warning("ui controls have no ui set, reload won't work")
		return
	end

	ui.Shutdown()
	ui.Init()
end

function controls:ToggleDebugger()
	if not checkHandle() then
		return
	end

	dmHandle.debugging = not dmHandle.debugging
	if dmHandle.debugging then
		RmlUi.SetDebugContext("shared")
	else
		---@diagnostic disable-next-line: param-type-mismatch
		RmlUi.SetDebugContext(nil)
	end
end

---@param mode string
function controls:SetPanelMode(mode)
	if not checkHandle() then
		return
	end

	dmHandle.panelMode = mode
end

---@param event RmlUi.Event
---@param global boolean
function controls:Say(event, global)
	if not checkHandle() then
		return
	end

	local player = event.parameters["player"]
	local message = event.parameters["message"]

	if global then
		spSendCommands(string.format("say %s: %s", player, message))
	else
		spSendCommands(string.format("say a: %s: %s", player, message))
	end
end

function controls:AtEnd(it_index, list)
	return it_index > #list
end

return controls
end

-- module: ui.rml_ui.overwatch-rcss  (from lua/ui/rml_ui/overwatch-rcss.lua)
__B_MODULES['ui.rml_ui.overwatch-rcss'] = function(require)
-- AUTO Generated: DO NOT EDIT
return [[
body {
    font-family: "Poppins";
    font-size: 10dp;
}

div {
    display: block;
}

p {
    display: block;
}

h1 {
    display: block;
    font-family: "Exo 2";
    font-size: 1.5rem;
    font-weight: bold;
}

.font-bold {
    font-weight: 700;
}

.text-sm {
    font-size: 14dp;
}

/* Color utilities */
.text-dark {
    color: #4a4a4a;
}

.bg-primary {
    background-color: #FDC04C;
}

#overwatch-widget {
    /* positional properties */
    position: absolute;
    bottom: 200dp;
    left: 300dp;
    width: 500dp;
    height: 500dp;
    background: #060606ba;
    border-radius: 5dp;
    padding: 12dp;
}

/* Draggable handle styles */
.move_handle {
    height: 1.5rem;
    width: 80%;
    cursor: move;
    text-align: left;
    position: absolute;
    top: 0;
    left: 0;
    z-index: 5;
    clip: always;
}

.size_handle {
    background-color: #000000ff;
    height: 1.5rem;
    width: 1.5rem;
    cursor: move;
    text-align: left;
    position: absolute;
    bottom: 0;
    right: 0;
    z-index: 5;
    clip: always;
}

#overwatch-panel {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
}

.log-container {
    width: 100%;
    height: 100%;
}

.log-container scrollbarvertical {
    position: absolute;
    top: 0;
    right: -12dp;
}

.logs {
    overflow: hidden scroll;
    width: 100%;
    height: 100%;
}

.logs td {
    padding: 4dp;
    border-right-width: 1px;
    border-right-color: #ffffff7F;
}

.logs thead td {
    font-family: "Exo 2";
    font-weight: 700;

    border-bottom-width: 1px;
    border-bottom-color: #ffffff7F;
}

.logs .log-buttons {
    display: inline;
    float: right;
}

.logs .form-button {
    cursor: pointer;
    text-align: center;
    padding: 2dp;
    color: #000000;
    margin-left: 4dp;
    border-radius: 2dp;
    background-color: #ffffff7F;
}

.logs .form-button:hover {
    background-color: #ffffffff;
}

.logsum {
    position: absolute;
    right: 16dp;
}

.settings-container {
    width: 100%;
    height: 100%;
}

/* Debug Controls Component */
.debug-controls {
    position: absolute;
    top: -20dp;
    right: 0dp;
    display: flex;
    gap: 3dp;
    z-index: 10;
}

.debug-btn {
    height: 20dp;
    padding: 0 4dp;
    cursor: pointer;
    text-align: center;
    line-height: 18dp;
    transition: all 0.1s;
}

.debug-btn:hover {
    transform: scale(1.1);
}

.debug-btn:active {
    transform: scale(0.95);
}

/* Header Component */
#overwatch-panel .header {
    display: flex;
    flex-direction: row;
    justify-content: space-between;

    background-color: #4a4a4a00;
    text-align: center;
    color: white;
    border-bottom-width: 1px;
    border-bottom-color: white;

    padding-bottom: 1rem;
    margin-bottom: 1rem;
}

.button {
    cursor: pointer;
    text-align: center;
    padding: 4dp 8dp;
}

.button:hover {
    color: #ebebeb;
}

/*
 * Table
 */
table {
	box-sizing: border-box;
	display: table;
}
tr {
	box-sizing: border-box;
	display: table-row;
}
td {
	box-sizing: border-box;
	display: table-cell;
}
col {
	box-sizing: border-box;
	display: table-column;
}
colgroup {
	display: table-column-group;
}
thead, tbody, tfoot {
	display: table-row-group;
}

/* === Rml Core Element Defaults === */
tabset tabs
{
	display: block;
}

/* Scrollbar */
scrollbarvertical,
scrollbarhorizontal
{
	width: 6dp;
}

scrollbarvertical slidertrack
{
	background-color: rgb(100, 100, 100);
    right: 0;
}

scrollbarvertical sliderbar,
scrollbarhorizontal sliderbar
{
	background-color: rgb(200, 200, 200);
	border-radius: 2dp;
}

sliderarrowinc:hover,
sliderarrowdec:hover
{
	background-color: rgb(150,150,150);
}
]]
end

-- module: ui.rml_ui.overwatch-rml  (from lua/ui/rml_ui/overwatch-rml.lua)
__B_MODULES['ui.rml_ui.overwatch-rml'] = function(require)
-- AUTO Generated: DO NOT EDIT
return [[
<rml>
<head>
    <title>Overwatch</title>

    <link rel="stylesheet" href="overwatch.rcss" type="text/rcss" />
</head>
<body id="overwatch-widget" data-model="overwatch" data-style-top="panel.top" data-style-left="panel.left" data-style-width="panel.width" data-style-height="panel.height">
    <div id="overwatch-panel" data-model="overwatch">
        <div class="debug-controls" data-if="isDev == true">
            <button class="debug-btn text-dark text-sm font-bold bg-primary" onclick="widget:Reload()" title="Reload Widget">reload</button>
            <button class="debug-btn text-dark text-sm font-bold bg-primary" onclick="widget:ToggleDebugger()" title="Toggle Debugger">debug</button>
        </div>

        <div class="header">
            <h1>Overwatch</h1>
            <div>
                <button class="button" onclick="widget:Save()" data-if="autoSave != true">Save</button>
                <button class="button"
                        data-if="panelMode == 'settings'"
                        onclick="widget:SetPanelMode('log')">Log</button>
                <button class="button"
                        data-if="panelMode == 'log'"
                        onclick="widget:SetPanelMode('settings')">Settings</button>
            </div>
        </div>

        <div class="log-container" data-if="panelMode == 'log'">
            <div class="logs">
                <table>
                    <thead>
                        <tr>
                            <td data-for="column : columns" data-if="column.visible" data-style-width="column.width">{{ column.label }}</td>
                        </tr>
                    </thead>
                    <tbody>
                        <tr data-for="log : logs">
                            <td data-for="column : columns" data-if="column.visible" data-style-color="log[it_index].color">{{ log[it_index].value }}
                                <div data-if="it_index + 1 == numColumns" class="log-buttons">
                                    <form onsubmit="widget:Say(event, true)">
                                        <input type="text" name="player" data-value="log[1].value" style="display: none" />
                                        <input type="text" name="message" data-value="log[6].value" style="display: none" />
                                        <input type="submit" class="form-button">G</input>
                                    </form>
                                    <form onsubmit="widget:Say(event, false)" data-if="it_index + 1 == numColumns">
                                        <input type="text" name="player" data-value="log[1].value" style="display: none" />
                                        <input type="text" name="message" data-value="log[6].value" style="display: none" />
                                        <input type="submit" class="form-button">T</input>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <div class="logsum">{{ logCount }} / {{ logMax }}</div>
        </div>

        <div class="settings-container" data-if="panelMode == 'settings'">
        </div>

        <div class="footer">
        </div>
    </div>

    <handle move_target="overwatch-widget" class="move_handle cursor-move">&nbsp;</handle>
    <handle size_target="overwatch-widget" class="size_handle cursor-move">&nbsp;</handle>
</body>
</rml>
]]
end

-- root module: __root
__B_MODULES['__root'] = function(require)
local constants = require("core.constants")
local Rule = require("rule")
local RuleState = require("rule_state")

local utils = require("core.utils")
local Logger = require("core.logger")
local Config = require("core.config")
local GameContext = require("core.game_context")
local TeamContext = require("core.team_context")

local interpolate = require("i18n.interpolate")

---@type OverwatchUi
local ui = require("ui.rml_ui")

---@type Channel[]
local channels = {
	require("channels.command"),
	require("channels.console"),
	require("channels.uilog"),
	require("channels.marquee"),
	require("channels.ping"),
	require("channels.sound"),
}

---@type Blueprint[]
local builtinBlueprints = require("builtin_blueprints")

local defaultConfig = require("default_config")

local LogLevel = constants.LogLevel

-- Builtin configuration
local IS_RELEASE = constants.IS_RELEASE
local NAME = constants.NAME
local VERSION = constants.VERSION
local LOG_LEVEL = IS_RELEASE and LogLevel.INFO or LogLevel.TRACE
local LOG_ECHO = true

local BP_FILES_PATTERN = "OverwatchBlueprints*.lua"

-- Interval for cleanups triggered by GameContext
local CLEANUP_INTERVAL = IS_RELEASE and 15 or 5

-- Per rule required fields
local CONFIG_RULE_REQS = { id = "string", enabled = "boolean" } -- 'blueprint = "string"' will be checked as well
-- Per rule optional fields
local CONFIG_RULE_OPTS = {
	enabled = "boolean",
	ownTeam = "boolean",
	interval = "number",
	cooldown = "number",
	category = "string",
	priority = "number",
	icon = "string",
	template = "string",
	parameters = "table",
	channels = "table",
	tags = "table",
}

--Per rule defaults
local CONFIG_RULE_DEFAULTS = {
	cooldown = IS_RELEASE and 10 or 0,
	interval = IS_RELEASE and 60 or 1,
}

-- Forward declarations
local spGetTeamList = Spring.GetTeamList

-- Vars
local initialized = false
---@type table<string, Blueprint> Available rules indexed by rule ID
local blueprints
---@type Rule[] Array of rule instances with their configurations
local rules
---@type table<number, table<string, RuleState>> States indexed by [teamID][ruleID]
local ruleStates
---@type table<number, table<string, function[]>>
local ruleStoppers
---@type table<number, TeamContext>
local teamContexts

---@type Logger
local logger
---@type Config
local config
---@type GameContext
local gameContext

---@type Widget
local widget = widget

function widget:GetInfo()
	return {
		name = NAME,
		desc = "Configurable monitoring and notification engine, press Alt+p to toggle the panel.",
		author = "Fast",
		date = VERSION,
		license = "GNU GPL, v2 or later",
		layer = -5,
		enabled = true,
	}
end

-- Helpers
---@param level MyLogLevel|integer
local function hasMinLogLevel(level)
	return LOG_LEVEL <= level
end

---@return number[]
local function getTeamlist()
	local r = {}
	local t = spGetTeamList()
	for _, teamId in ipairs(t) do
		local allyId = select(6, Spring.GetTeamInfo(teamId))
		if utils.IsTeamReal(allyId) then
			table.insert(r, teamId)
		end
	end

	return r
end

--- @param n Notification
local function dispatch(n)
	if not n.config then
		logger:Warning("Bad rule not getting a config: %s", table.toString(n))
		return
	end

	if not n.team then
		logger:Warning("Bad rule not getting a team: %s", table.toString(n))
		return
	end

	local nconf = n.config

	-- Template/interpolate the message.
	n.message = n.message or interpolate(nconf.template, n.templateParams)

	-- Apply config if not overriden.
	n.seconds = n.seconds or gameContext.seconds
	n.channels = n.channels or nconf.channels
	n.priority = n.priority or nconf.priority
	n.category = n.category or nconf.category
	n.icon = n.icon or nconf.icon

	-- Distribute
	for _, c in ipairs(channels) do
		if c.IsEnabled() then
			-- Notify and stop distributing if channel wants it.
			if not c.Notify(n) then
				return
			end
		end
	end
end

-- Helper to run a rule on interval.
--
---@param rule Rule
---@param teamId number
---@private
local function triggerRule(rule, teamId)
	-- No interval given = no run
	if not rule.config.interval or rule.config.interval < 0 then
		return
	end

	local now = gameContext.seconds
	local teamContext = teamContexts[teamId]
	local ruleConfig = rule.config
	local state = ruleStates[teamId][ruleConfig.id] or table.copy(rule.state)
	ruleStates[teamId][ruleConfig.id] = state

	local lastTriggered = state.lastTriggered or 0
	local cooldown = ruleConfig.cooldown or 0
	local interval = ruleConfig.interval

	-- Initialize lastTriggered and skip if wasn't initialized (first run)
	if lastTriggered < 1 then
		state.lastTriggered = now
		return
	end

	-- Skip if cooldown hasn't elapsed
	if cooldown > 0 and now - lastTriggered < cooldown then
		return
	end

	-- Skip if interval hasn't elapsed or interval-based monitoring is disabled for this rule.
	-- it's disabled when interval is < 0.
	if interval > 0 and now - lastTriggered < interval then
		return
	end

	-- Generate alert
	local triggered = rule.bp.Trigger(gameContext, teamContext, ruleConfig, state, dispatch)
	if triggered then
		-- Update state
		state.lastTriggered = now

		if hasMinLogLevel(LogLevel.TRACE2) then
			logger:Trace2("Rule: %s triggered", rule.config.id)
		end
	end
end

---@return Rule?
local function createRule(rConfig)
	if type(rConfig.blueprint) ~= "string" then
		logger:Warning(
			"Invalid rule config '%s', missing: 'blueprint', skipping it",
			table.toString(rConfig)
		)
		return
	end

	local bp = blueprints[rConfig.blueprint]
	if not bp then
		logger:Warning(
			"Blueprint '%s' for rule '%s' not found, skippping it",
			rConfig.blueprint,
			rConfig.id
		)
		return
	end

	local merged = table.copy(bp.defaultConfig)
	local missing = utils.MergeValidate(
		merged,
		rConfig,
		CONFIG_RULE_REQS,
		CONFIG_RULE_OPTS,
		CONFIG_RULE_DEFAULTS
	)
	if missing and table.count(missing) > 0 then
		logger:Warning(
			"Invalid rule config '%s', missing: '%s', skipping it",
			table.toString(rConfig),
			table.toString(missing)
		)
		return
	end

	-- -- Write back into users config
	-- if config.data and config.data.rules then
	-- 	config.data.rules[rConfig.id] = merged
	-- end

	if hasMinLogLevel(LogLevel.TRACE3) then
		logger:Trace3("Rule %s: merged config: %s", rConfig.id, table.toString(merged))
	end

	---@type Rule
	local ruleInstance = Rule.New(bp, merged, {
		lastTriggered = 0,
		lastChecked = 0,
		notified = false,
		data = {},
	})

	return ruleInstance
end

-- Loads a single rule file from VFS.
--
---@param path string
---@param env table
---@return number the number of rules loaded.
local function loadBlueprint(path, env)
	logger:Debug("Processing blueprint file: %s", path)

	local loaded = 0

	-- Load the file
	local r = VFS.Include(path, env)

	if type(r) ~= "table" then
		logger:Error("Loading blueprint file: %s", path)
		return 0
	end

	-- Register each blueprint
	for _, bp in ipairs(r) do
		if bp.id then
			if hasMinLogLevel(LogLevel.TRACE) then
				logger:Trace("Blueprint: %s", bp.id)
			end
			blueprints[bp.id] = bp
			loaded = loaded + 1
		end
	end
	logger:Debug("Loaded %d blueprints from %s", loaded, path)

	return loaded
end

-- Loads all rules from VFS.
--
---@param env table
---@return number the number of rules loaded.
local function loadBlueprints(env)
	logger:Debug("Loading rules from VFS")

	-- Find all rule files in LuaUI/Config directory
	local bpFiles = VFS.DirList(constants.CONFIG_DIR, BP_FILES_PATTERN)

	if #bpFiles == 0 then
		logger:Debug("No blueprint files found in %s", constants.CONFIG_DIR)
		return 0
	end

	logger:Debug("Found %d blueprint files", #bpFiles)

	-- Process each file
	local bpLoaded = 0
	for _, path in ipairs(bpFiles) do
		bpLoaded = bpLoaded + loadBlueprint(path, env)
	end

	return bpLoaded
end

---@param team TeamContext
local function cleanupTeam(team)
	if not team then
		return
	end

	local id = team.id

	-- Stop all rules listening.
	if ruleStoppers[id] then
		for _, trs in pairs(ruleStoppers[id]) do
			for _, rs in pairs(trs) do
				rs()
			end
		end
		ruleStoppers[id] = nil
	end

	-- Cleanup states
	ruleStates[id] = nil

	-- Stop contexts
	team:Shutdown()
	teamContexts[id] = nil
end

---@param msg string
local function fatalRemoveMe(msg, ...)
	logger:Fatal(msg, ...)
	widgetHandler:RemoveWidget()
end

-- Widget callins

function widget:Initialize()
	logger = Logger.New(NAME, LOG_LEVEL, LOG_ECHO)
	config = Config.New(logger)

	-- Load Config
	if
		not config:LoadMany(
			constants.CONFIG_DIR,
			constants.CONFIG_FILES_PATTERN,
			constants.CONFIG_FILE,
			defaultConfig
		)
	then
		fatalRemoveMe(
			"Loading config: %s/%s and %s/%s",
			constants.CONFIG_DIR,
			constants.CONFIG_FILE,
			constants.CONFIG_DIR,
			constants.CONFIG_FILES_PATTERN
		)
		return
	end

	if hasMinLogLevel(LogLevel.TRACE2) then
		logger:Trace2("Config: %s", table.toString(config.data))
	end

	-- Add internal blueprints.
	blueprints = {}

	for _, bp in ipairs(builtinBlueprints) do
		logger:Trace3("Blueprint: %s", bp.id)
		blueprints[bp.id] = table.copy(bp)
	end

	-- Load external blueprints.
	local blueprintsEnv = getfenv() --TODO(fast): Seems to be a big security risk, revisit this soon.
	blueprintsEnv.logger = logger:WithSection(NAME .. "::rules")
	blueprintsEnv.NotifyPriority = constants.NOTIFY_PRIORITY
	blueprintsEnv.ResourceType = constants.ResourceType

	local loaded = loadBlueprints(blueprintsEnv)
	logger:Debug("Blueprints: %d, loaded %d external blueprints", table.count(blueprints), loaded)

	if hasMinLogLevel(LogLevel.TRACE3) then
		logger:Trace3("Blueprints: %s", table.toString(blueprints))
	end

	-- Create and init the GameContext.
	gameContext = GameContext.New(CLEANUP_INTERVAL, logger)
	if not gameContext:Init() then
		fatalRemoveMe("While initializing GameContext")
		return
	end

	-- Initialize team context(s).
	teamContexts = {}
	ruleStates = {}
	local allTeams = getTeamlist()
	for _, teamID in ipairs(allTeams) do
		teamContexts[teamID] = TeamContext.New(teamID, logger)
		ruleStates[teamID] = RuleState.New()
	end

	-- Create rules from config.
	ruleStoppers = {}

	rules = {}
	if not config.data["rules"] then
		fatalRemoveMe("Invalid config: no rule config section")
		return
	end

	local myTeamID = gameContext.myTeamID

	logger:Trace("=== Creating rules ===")
	for id, rc in pairs(config.data["rules"]) do
		local rcfg = table.copy(rc)
		rcfg.id = id
		local rule = createRule(rcfg)

		if rule then
			table.insert(rules, rule)
			if logger.level > LogLevel.TRACE3 and logger.level <= LogLevel.TRACE then
				logger:Trace("Rule: %s, bp=%s", rule.config.id, rule.bp.id)
			end

			local rconf = rule.config

			-- Start the rule for all teams
			if rconf.enabled and rule.bp.Start then
				for _, team in pairs(teamContexts) do
					if not rconf.ownTeam or team.id == myTeamID then
						if not ruleStoppers[team.id] then
							ruleStoppers[team.id] = {}
						end

						ruleStoppers[team.id][rule.config.id] =
							rule.bp.Start(gameContext, team, rconf, dispatch)
					end
				end
			end
		end
	end
	logger:Trace("=== Total: %d rules ===", #rules)

	-- Initialize the UI.
	ui.Init(logger, gameContext, config)

	-- Initialize channels.
	for _, c in ipairs(channels) do
		if not c.Init(logger, gameContext, config, ui) then
			fatalRemoveMe("While initializing channel '%s'", c.id)
			return
		end

		logger:Debug("created channel: %s", c.id)
	end

	-- We have fresh TeamContext's add units to them.
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local teamID = Spring.GetUnitTeam(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)

		if teamID and unitDefID then
			gameContext:UnitFinished(unitID, unitDefID, teamID)

			if teamContexts[teamID] then
				teamContexts[teamID]:UnitFinished(unitID, unitDefID)
			end
		end
	end

	initialized = true
end

function widget:Shutdown()
	ui.Shutdown()

	for _, team in pairs(teamContexts) do
		cleanupTeam(team)
	end

	gameContext:Shutdown()

	initialized = false
end

function widget:GameFrame(n)
	if not initialized then
		return
	end

	-- Update game context
	gameContext:GameFrame()

	-- Cleanup teamcontexts
	for _, team in pairs(teamContexts) do
		if team then
			if not team:IsReal() then
				logger:Debug("Removing team %d it's not real anymore", team.id)

				cleanupTeam(team)
			end
		end
	end

	-- Process all rules for all teams
	local myTeamID = gameContext.myTeamID
	for id, team in pairs(teamContexts) do
		-- Update team context
		team:GameFrame()

		-- Process each rule instance
		for _, ruleInstance in ipairs(rules) do
			local rconf = ruleInstance.config
			if
				ruleInstance.bp.Trigger
				and rconf.enabled
				and (not rconf.ownTeam or id == myTeamID)
			then
				triggerRule(ruleInstance, id)
			end
		end
	end
end

function widget:PlayerChanged(playerID)
	if not gameContext:HasPlayerChanged() then
		return
	end

	gameContext:Init()

	-- Reinitialize team contexts for all teams
	local allTeams = spGetTeamList()
	for _, teamID in ipairs(allTeams) do
		teamContexts[teamID] = TeamContext.New(teamID, logger)
		ruleStates[teamID] = {}
	end

	ui.PlayerHasChanged()
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if not unitID or not unitDefID or not unitTeam then
		return
	end

	gameContext:UnitFinished(unitID, unitDefID, unitTeam)

	if teamContexts[unitTeam] then
		teamContexts[unitTeam]:UnitFinished(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(
	unitID,
	unitDefID,
	unitTeam,
	attackerID,
	attackerDefID,
	attackerTeam,
	weaponDefID
)
	if not unitID or not unitDefID or not unitTeam then
		return
	end

	gameContext:UnitDestroyed(unitID, unitDefID, unitTeam)

	if teamContexts[unitTeam] then
		teamContexts[unitTeam]:UnitDestroyed(unitID, unitDefID)
	end
end

-- UI Callins
function widget:DrawScreen(viewSizeX, viewSizeY)
	return ui.DrawScreen(viewSizeX, viewSizeY)
end

function widget:ViewResize(viewSizeX, viewSizeY)
	return ui.ViewResize(viewSizeX, viewSizeY)
end

function widget:KeyPress(keyCode, mods, isRepeat, label, utf32char, scanCode, actionList)
	return ui.KeyPress(keyCode, mods, isRepeat, label, utf32char, scanCode, actionList)
end

function widget:KeyRelease(keyCode, mods, label, utf32char, scanCode, actionList)
	return ui.KeyRelease(keyCode, mods, label, utf32char, scanCode, actionList)
end

function widget:MousePress(x, y, button)
	return ui.MousePress(x, y, button)
end

function widget:MouseRelease(x, y, button)
	return ui.MouseRelease(x, y, button)
end

function widget:MouseMove(x, y, dx, dy, button)
	return ui.MouseMove(x, y, dx, dy, button)
end

function widget:MouseWheel(up, value)
	return ui.MouseWheel(up, value)
end
end

return __B_REQUIRE('__root')
