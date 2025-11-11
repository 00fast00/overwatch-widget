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
