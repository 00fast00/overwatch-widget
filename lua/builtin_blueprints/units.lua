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
