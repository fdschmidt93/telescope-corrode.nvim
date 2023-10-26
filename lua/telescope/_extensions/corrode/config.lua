local config = {}

-- TODO actually provide configuration
_TelescopeCorrodeConfig = {
	AND = true,
	permutations = true,
} or _TelescopeCorrodeConfig

config.values = _TelescopeCorrodeConfig

config.setup = function(opts)
	-- TODO maybe merge other keys as well from telescope.config
	config.values.mappings =
		vim.tbl_deep_extend("force", config.values.mappings, require("telescope.config").values.mappings)
	config.values = vim.tbl_deep_extend("force", config.values, opts)
end

return config
