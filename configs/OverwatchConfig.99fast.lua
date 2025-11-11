-- Fast's testing configuration.

return {
	rules = {
		resource_converter_level = {
			enabled = false,
			interval = 30,
			cooldown = 120,
			template = "You'r converter slider of %<mmLevel>.f is to high (%<threshold>.f), pull the yellow box in the E bar all the way down!",
		},
		debug_team_context = {
			enabled = false,
		},
		debug_game_context = {
			enabled = false,
		},
		debug_event_gamecontext_units = {
			enabled = false,
		},
		debug_unit_watch = {
			enabled = true,
			channels = { "uilog", "marquee" },
			parameters = {
				commanders = true,
				watchFor = {
					"corveng",
					"armham",
					"armdrag",
					"armfav",
					"armflea",
				},
			},
		},
		unit_lost_ping = {
			enabled = true,
			channels = { "sound", "ping" },
			parameters = {
				commanders = true,
			},
		},
	},
}
