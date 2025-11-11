---@type ConfigFormat
return {
	rules = {
		debug_periodic_1s = {
			blueprint = "debug_periodic",
			interval = 1,
			enabled = false,
		},
		debug_periodic_30s = {
			blueprint = "debug_periodic",
			interval = 30,
			enabled = false,
		},
		debug_periodic_1min = {
			blueprint = "debug_periodic",
			enabled = false,
		},
		debug_game_context = {
			blueprint = "debug_game_context",
			enabled = false,
		},
		debug_team_context = {
			blueprint = "debug_team_context",
			enabled = false,
		},
		debug_resources = {
			blueprint = "debug_resources",
			interval = 30,
			enabled = false,
		},
		debug_event_gamecontext_units = {
			blueprint = "debug_event_gamecontext_units",
			enabled = false,
		},
		debug_event_teamcontext_units = {
			blueprint = "debug_event_teamcontext_units",
			enabled = false,
		},
		debug_event_resources = {
			blueprint = "debug_event_resources",
			enabled = false,
		},
		debug_unit_lost_simple = {
			enabled = false,
			blueprint = "unit_lost",
			parameters = {
				watchFor = {
					[1] = "armflea",
					[2] = "corveng",
				},
			},
		},
		debug_unit_got_simple = {
			enabled = false,
			blueprint = "unit_got",
			parameters = {
				watchFor = {
					[1] = "armflea",
					[2] = "corveng",
				},
			},
		},
		debug_converter = {
			enabled = false,
			blueprint = "debug_converter",
		},
		debug_unit_watch = {
			enabled = false,
			blueprint = "unit_watch",
			parameters = {
				watchFor = {
					[1] = "armflea",
					[2] = "corveng",
				},
			},
		},
	},
}
