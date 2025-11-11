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

		Start = function(game, team, config, notify)
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

							notify({
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
			template = "You'r staling %{kind}, ratio: %<ratio>.f, treshold: %<threshold>.f",
			cooldown = 60 * 5, -- 5 minutes
			parameters = {
				kinds = { "metal", "energy" },
				threshold = 0.1,
			},
		},

		Start = function(game, team, config, notify)
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

							notify({
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

		Trigger = function(game, team, config, state, notify)
			-- local mmLevel = team:GetRulesParamNum("mmLevel", 0)
			local mmLevel = Spring.GetTeamRulesParam(team.id, "mmLevel")

			if mmLevel >= config.parameters.threshold then
				notify({
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
