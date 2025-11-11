-- Debug Rules
-- Testing and development rules
-- Copy this to LuaUI/Config/OverwatchBlueprints.debug.lua to load these debug rules

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

---@type Blueprint[]
local list = {
	{
		id = "debug_periodic",
		description = "Just a periodic alert for debugging",
		defaultConfig = {
			category = "debug",
			priority = NotifyPriority.DEBUG,
			icon = "ℹ️",
			template = "%{interval} secs periodic check fired @ %{time}",
			interval = 60,
		},

		Trigger = function(game, team, config, state, notify)
			notify({
				team = team,
				config = config,
				templateParams = {
					interval = config.interval,
					time = string.formatTime(game.seconds),
				},
			})

			return true
		end,
	},
	{
		id = "debug_game_context",
		description = "Print game context",
		defaultConfig = {
			category = "debug",
			priority = NotifyPriority.DEBUG,
			icon = "ℹ️",
			template = "%{game}",
			interval = 60,
			ownTeam = true,
		},

		Trigger = function(game, team, config, state, notify)
			notify({
				team = team,
				config = config,
				templateParams = { game = tostring(game) },
			})

			return true
		end,
	},
	{
		id = "debug_team_context",
		description = "Print team context",
		defaultConfig = {
			category = "debug",
			priority = NotifyPriority.DEBUG,
			icon = "ℹ️",
			template = "%{team}",
			interval = 60,
		},

		Trigger = function(game, team, config, state, notify)
			notify({
				team = team,
				config = config,
				templateParams = { team = tostring(team) },
			})

			return true
		end,
	},
	{
		id = "debug_resources",
		description = "Debug print resources",
		defaultConfig = {
			category = "debug",
			priority = NotifyPriority.DEBUG,
			icon = "ℹ️",
			template = "m=%{metal} : e=%{energy}",
			interval = 60,
		},

		Trigger = function(game, team, config, state, notify)
			notify({
				team = team,
				config = config,
				templateParams = {
					metal = tostring(team:GetResource(ResourceType.METAL)),
					energy = tostring(team:GetResource(ResourceType.ENERGY)),
				},
			})

			return true
		end,
	},
	{
		id = "debug_event_gamecontext_units",
		description = "Debug gamecontext units events",
		defaultConfig = {
			category = "debug",
			priority = NotifyPriority.DEBUG,
			icon = "ℹ️",
			template = "game(%{teamID}) %{status}: %{unitName}: %{count}",
			cooldown = 10,
			ownTeam = true,
		},

		Start = function(game, team, config, notify)
			local unsubs = {}

			table.insert(
				unsubs,
				game:Subscribe("debug_event_gamecontext_units", "UnitFinished", function(data)
					local defID = data.defID

					notify({
						team = team,
						config = config,
						templateParams = {
							status = "UnitFinished",
							teamID = data.teamID,
							unitName = UnitDefs[defID].name,
							count = game.unitCounts[defID],
						},
					})
				end)
			)

			table.insert(
				unsubs,
				game:Subscribe("debug_event_gamecontext_units", "UnitDestroyed", function(data)
					local defID = data.defID

					notify({
						team = team,
						config = config,
						templateParams = {
							status = "UnitDestroyed",
							teamID = data.teamID,
							unitName = UnitDefs[defID].name,
							count = game.unitCounts[defID],
						},
					})
				end)
			)

			return unsubs
		end,
	},
	{
		id = "debug_event_teamcontext_units",
		description = "Debug teamcontext units events",
		defaultConfig = {
			category = "debug",
			priority = NotifyPriority.DEBUG,
			icon = "ℹ️",
			template = "%{status}: %{unitName}: %{count}",
			cooldown = 10,
		},

		Start = function(game, team, config, notify)
			local unsubs = {}

			table.insert(
				unsubs,
				team:Subscribe("debug_event_teamcontext_units", "UnitFinished", function(data)
					local defID = data.defID

					notify({
						team = team,
						config = config,
						templateParams = {
							status = "UnitFinished",
							teamID = data.teamID,
							unitName = UnitDefs[defID].name,
							count = game.unitCounts[defID],
						},
					})
				end)
			)

			table.insert(
				unsubs,
				team:Subscribe("debug_event_teamcontext_units", "UnitDestroyed", function(data)
					local defID = data.defID

					notify({
						team = team,
						config = config,
						templateParams = {
							status = "UnitDestroyed",
							teamID = data.teamID,
							unitName = UnitDefs[defID].name,
							count = game.unitCounts[defID],
						},
					})
				end)
			)

			return unsubs
		end,
	},
	{
		id = "debug_event_resources",
		description = "Debug resource events",
		defaultConfig = {
			category = "debug",
			priority = NotifyPriority.DEBUG,
			icon = "ℹ️",
			template = "%{kind} current: %{current} - (%{ratio} %{event} %{threshold})",
			cooldown = 10,
			parameters = {
				min = 0.2,
				max = 0.8,
			},
		},

		Start = function(game, team, config, notify)
			local unsubs = {}

			for _, kind in ipairs({ ResourceType.METAL, ResourceType.ENERGY }) do
				local resource = team:GetResource(kind)

				local is_full_last_triggered = game.startupSeconds
				table.insert(
					unsubs,
					resource:Subscribe(
						"debug_event_resources",
						"IsFull",
						{ threshold = config.parameters.min },
						function()
							if
								is_full_last_triggered > 0
								and config.cooldown > 0
								and game.seconds - is_full_last_triggered < config.cooldown
							then
								return
							end

							notify({
								team = team,
								config = config,
								templateParams = {
									kind = kind,
									event = "IsFull",
									current = resource.current,
									ratio = resource:GetRatio(),
									threshold = config.parameters.min,
								},
							})

							is_full_last_triggered = game.seconds
						end
					)
				)

				local is_low_last_triggered = game.startupSeconds
				table.insert(
					unsubs,
					resource:Subscribe(
						"debug_event_resources",
						"IsLow",
						{ threshold = config.parameters.min },
						function()
							if
								is_low_last_triggered > 0
								and config.cooldown > 0
								and game.seconds - is_low_last_triggered < config.cooldown
							then
								return
							end

							notify({
								team = team,
								config = config,
								templateParams = {
									kind = kind,
									event = "IsLow",
									current = resource.current,
									ratio = resource:GetRatio(),
									threshold = config.parameters.min,
								},
							})

							is_low_last_triggered = game.seconds
						end
					)
				)

				local is_below_last_triggered = game.startupSeconds
				table.insert(
					unsubs,
					resource:Subscribe(
						"debug_event_resources",
						"IsBelow",
						{ threshold = config.parameters.min },
						function()
							if
								is_below_last_triggered > 0
								and config.cooldown > 0
								and game.seconds - is_below_last_triggered < config.cooldown
							then
								return
							end

							notify({
								team = team,
								config = config,
								templateParams = {
									kind = kind,
									event = "IsBelow",
									current = resource.current,
									ratio = resource:GetRatio(),
									threshold = config.parameters.min,
								},
							})

							is_below_last_triggered = game.seconds
						end
					)
				)

				local is_above_last_triggered = game.startupSeconds
				table.insert(
					unsubs,
					resource:Subscribe(
						"debug_event_resources",
						"IsAbove",
						{ threshold = config.parameters.max },
						function()
							if
								is_above_last_triggered > 0
								and config.cooldown > 0
								and game.seconds - is_above_last_triggered < config.cooldown
							then
								return
							end

							notify({
								team = team,
								config = config,
								templateParams = {
									kind = kind,
									event = "IsAbove",
									current = resource.current,
									ratio = resource:GetRatio(),
									threshold = config.parameters.max,
								},
							})

							is_above_last_triggered = game.seconds
						end
					)
				)

				local is_between_last_triggered = 0
				table.insert(
					unsubs,
					resource:Subscribe(
						"debug_event_resources",
						"IsBetween",
						{ min = config.parameters.min, max = config.parameters.max },
						function()
							if
								is_between_last_triggered > 0
								and config.cooldown > 0
								and game.seconds - is_between_last_triggered < config.cooldown
							then
								return
							end

							notify({
								team = team,
								config = config,
								templateParams = {
									kind = kind,
									event = "IsBetween",
									current = resource.current,
									ratio = "",
									threshold = config.parameters.min,
								},
							})

							is_between_last_triggered = game.seconds
						end
					)
				)

				local has_excess_last_triggered = game.startupSeconds
				local excess_treshold = 0.01
				table.insert(
					unsubs,
					resource:Subscribe(
						"debug_event_resources",
						"HasExcess",
						{ excess = excess_treshold },
						function()
							if
								has_excess_last_triggered > 0
								and config.cooldown > 0
								and game.seconds - has_excess_last_triggered < config.cooldown
							then
								return
							end

							notify({
								team = team,
								config = config,
								templateParams = {
									kind = kind,
									event = "HasExcess",
									current = resource.current,
									ratio = resource.storage * excess_treshold,
									threshold = excess_treshold,
								},
							})

							has_excess_last_triggered = game.seconds
						end
					)
				)
			end

			return unsubs
		end,
	},
	{
		id = "debug_converter",
		description = "Print converter infos",
		defaultConfig = {
			category = "debug",
			priority = NotifyPriority.DEBUG,
			icon = "ℹ️",
			template = "Converter: %<mmUse>.f/%<mmCapacity>.f (%<efficiency>.f) Level: %<mmLevel>.f",
			interval = 10,
		},

		Trigger = function(game, team, config, state, notify)
			local mmLevel = team:GetRulesParamNum("mmLevel", 0)
			local mmUse = team:GetRulesParamNum("mmUse", 0)
			local mmCapacity = team:GetRulesParamNum("mmCapacity", 0)

			if mmCapacity > 0 then
				local efficiency = (mmUse / mmCapacity) * 100
				notify({
					team = team,
					config = config,
					templateParams = {
						mmUse = mmUse,
						mmCapacity = mmCapacity,
						efficiency = efficiency,
						mmLevel = mmLevel,
					},
				})
				return true
			end

			return false
		end,
	},
}

return list
