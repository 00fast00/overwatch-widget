---@type ConfigFormat
return {
	rules = {
		commander_lost = {
			enabled = true,
			blueprint = "commander_lost",
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
		commander_new = {
			enabled = true,
			blueprint = "commander_new",
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
		resource_stale = {
			enabled = true,
			blueprint = "resource_stale",
			forceChannels = {
				[1] = "marquee",
				[2] = "ui_log",
			},
		},
		resource_stale_say = {
			enabled = false,
			blueprint = "resource_stale",
			template = "I'm staling %{kind} (auto-message)",
			forceChannels = {
				[1] = "command",
			},
			parameters = {
				kind = {
					[1] = "metal",
				},
			},
		},
		resource_waste = {
			enabled = true,
			blueprint = "resource_waste",
			forceChannels = {
				[1] = "marquee",
				[2] = "ui_log",
			},
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
			forceChannels = {
				[1] = "command",
			},
		},
		unit_limit = {
			enabled = true,
			blueprint = "unit_limit",
		},
		resource_converter_level = {
			enabled = true,
			blueprint = "resource_converter_level",
		},
		unit_lost_ping = {
			enabled = true,
			blueprint = "unit_lost_ping",
			parameters = {
				commanders = true,
			},
		},
	},
}
