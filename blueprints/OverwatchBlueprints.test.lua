-- Debug Rules
-- Testing and development rules
-- Copy this to LuaUI/Config/OverwatchBlueprints.test.lua to load these test rules

--- To allow us use injected globals
---@diagnostic disable undefined-global
---@type Logger
local logger = logger

---@enum NotfiyPriority
local NotifyPriority = NotifyPriority
	or {
		TRACE = 1,
		DEBUG = 16,
		INFO = 256,
		WARNING = 4096,
		ERROR = 65536,
		CRITICAL = 1048576,
	}

---@enum NotfiyPriority
local ResourceType = ResourceType or {
	METAL = "metal",
	ENERGY = "energy",
}
---@diagnostic enable undefined-global

---The Blueprints
---@type Blueprint[]
local list = {
	{
		id = "test_alert",
		description = "Very important test alert",
		defaultConfig = {
			category = "test",
			priority = NotifyPriority.CRITICAL,
			icon = "ℹ️",
			template = "TEST: I am important",
			interval = 10,
		},

		Trigger = function(game, team, config, state, notify)
			notify({
				team = team,
				config = config,
				templateParams = {},
			})

			return true
		end,
	},
}

return list
