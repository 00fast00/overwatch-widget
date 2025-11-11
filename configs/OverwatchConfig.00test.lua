---@type ConfigFormat
return {
	rules = {
		-- Has a bad blueprint, will be skipped.
		test_bad_bp = {
			enabled = true,
			blueprint = "i_am_a_bad_bp",
		},
		-- interval is -1, should never been seen.
		test_false = {
			enabled = true,
			blueprint = "test_alert",
			template = "TEST: if you see this I have a bug",
			interval = -1,
		},
	},
}
