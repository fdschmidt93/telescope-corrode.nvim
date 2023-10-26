local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local corrode_config = require("telescope._extensions.corrode.config")
local corrode_picker = require("telescope._extensions.corrode.picker")

local corrode = function(opts)
	opts = opts or {}
	local defaults = (function()
		if corrode_config.values.theme then
			return require("telescope.themes")["get_" .. corrode_config.values.theme](corrode_config.values)
		end
		return vim.deepcopy(corrode_config.values)
	end)()

	if corrode_config.values.mappings then
		defaults.attach_mappings = function(prompt_bufnr, map)
			if corrode_config.values.attach_mappings then
				corrode_config.values.attach_mappings(prompt_bufnr, map)
			end
			for mode, tbl in pairs(corrode_config.values.mappings) do
				for key, action in pairs(tbl) do
					map(mode, key, action)
				end
			end
			return true
		end
	end

	if opts.attach_mappings then
		local opts_attach = opts.attach_mappings
		opts.attach_mappings = function(prompt_bufnr, map)
			defaults.attach_mappings(prompt_bufnr, map)
			return opts_attach(prompt_bufnr, map)
		end
	end

	local popts = vim.tbl_deep_extend("force", defaults, opts)

	corrode_picker(popts)
end

-- this pattern is required for lemmy-help
local M = telescope.register_extension({
	exports = {
		corrode = corrode,
	},
})

return M
