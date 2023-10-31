local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local utils = require("telescope.utils")
local conf = require("telescope.config").values
local sorters = require("telescope.sorters")
local corrode_utils = require("telescope._extensions.corrode.utils")

local prompt_tokens = {}

-- Sorter function for telescope
-- Activate the sorter
local sort_fn = sorters.Sorter:new({
	discard = true,
	scoring_function = function(_, _, line)
		if not line then
			return -1
		else
			return 0.99
		end
	end,
})

--- Return regex to match all permutations of tokens with wildcards inbetween
--- Example: this test -> (this.*test|test.*this)
--- Note: this is **almost** order invariant
--- @param tokens string[]: the prompt tokens
--- @return string: the regex pattern
local function permutations(tokens)
	local result = {}
	local function permute(tokens_, i, n)
		if i == n then
			table.insert(result, table.concat(tokens_, ".*"))
		else
			for j = i, n do
				tokens_[i], tokens_[j] = tokens_[j], tokens_[i]
				permute(tokens_, i + 1, n)
				tokens_[i], tokens_[j] = tokens_[j], tokens_[i]
			end
		end
	end
	permute(tokens, 1, #tokens)
	return string.format("%s%s%s", "(", table.concat(result, "|"), ")")
end

-- Lookup keys for file entries
local lookup_keys = {
	ordinal = 1,
	value = 1,
	filename = 1,
}

--- Generate a entry from a json stream of `rg`.
--- @param opts table: options for the file entry
--- @return function: a function that takes a stream and returns a file entry
local function gen_from_file(opts)
	opts = opts or {}

	local cwd = vim.fn.expand(vim.F.if_nil(opts.cwd, vim.loop.cwd()))

	local disable_devicons = opts.disable_devicons
	local mt_file_entry = {}
	mt_file_entry.cwd = cwd
	mt_file_entry.display = function(entry)
		local hl_group, icon
		local display = utils.transform_path(opts, entry.value)
		display, hl_group, icon = utils.transform_devicons(entry.value, display, disable_devicons)
		if hl_group then
			local begin = #icon
			local highlights = { { { 0, begin }, hl_group } }
			local offsets = corrode_utils.find_all_offsets(entry.value, prompt_tokens)
			begin = begin + 1 -- space between icon and filename
			-- for _, match in ipairs(entry["submatches"]) do
			--   highlights[#highlights + 1] = { { match["start"] + begin, match["end"] + begin }, "TelescopeMatching" }
			-- end
			for _, match in ipairs(offsets) do
				highlights[#highlights + 1] = { { match["start"] + begin, match["end_"] + begin }, "TelescopeMatching" }
			end
			return display, highlights
		else
			return display
		end
	end
	mt_file_entry.__index = function(t, k)
		local raw = rawget(mt_file_entry, k)
		if raw then
			return raw
		end
		if k == "path" then
			local retpath = vim.fs.joinpath(t.cwd, t.value)
			if vim.fn.filereadable(retpath) == 0 then
				retpath = t.value
			end
			return retpath
		end
		return rawget(t, rawget(lookup_keys, k))
	end

	return function(stream)
		local ok, json_line = pcall(vim.json.decode, stream)
		if not ok then
			return
		end
		if json_line["type"] ~= "match" then
			return
		end
		local line = json_line["data"]["lines"]["text"]:sub(1, -2) -- trim \n
		local entry = {
			[1] = line,
			len = line:len(),
		}
		entry.submatches = json_line["data"]["submatches"]
		return setmetatable(entry, mt_file_entry)
	end
end

--- Find files with `staged fd` using telescope that never blocks
--- Staged fd:
---     1. Run `fd`, output to file
---     2. Run `rg` with customizations on file
--- Customized `rg`:
---     - Match permutations for order-invariant AND operator, e.g. this test -> (this.*test|test.*this)
---     - Custom sorter to prefer shorter file names (i.e., light-loaded resorting `rg` output with telescope in lua)
---     - Use `rg` json to highlight matches
--- @param opts table: options for finding files
return function(opts)
	opts = opts or {}

	local cache = vim.fs.joinpath(vim.fn.stdpath("cache"), "telescope-corrode")
	if vim.fn.isdirectory(cache) == 0 then
		vim.fn.mkdir(cache)
	end
	local cwd = vim.uv.cwd()
	local filename = os.time() -- store each search by lua timestamp
	local path = vim.fs.joinpath(cache, filename)

	-- launch `fd` and output result to $NVIM_CACHE/telescope-corrode/$TIMESTAMP
	local fd = vim.uv.fs_open(path, "a", 438)
	vim.system({ "fd", "-t=f" }, {
		cwd = cwd,
		stdout = function(_, data)
			if data then
				if fd then
					pcall(vim.uv.fs_write, fd, data)
				end
			end
		end,
	}, function()
		if fd then
			pcall(vim.uv.fs_close, fd)
		end
	end)

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "TelescopePrompt",
		once = true,
		callback = function(args)
			vim.api.nvim_create_autocmd({ "BufLeave", "BufDelete" }, {
				buffer = args.buf,
				once = true,
				callback = function()
					prompt_tokens = {}
					if vim.fn.filereadable(path) == 1 then
						local ret = vim.fn.delete(path)
						if ret ~= 0 then
							vim.notify("Deletion failed!")
						end
					end
				end,
			})
		end,
	})

	local picker
	local find_command = finders.new_job(function(prompt)
		if not prompt or prompt == "" then
			return { "rg", "-N", "--color=never", "--smart-case", "--json", "--", "^", path }
		end
		local tokens = corrode_utils.tokenize(prompt)
		prompt_tokens = vim.deepcopy(tokens)
		local file_ext_ids = {}
		local file_ext = {}

		-- If tokens in prompt end in `$`
		--   1. Group them (i.e., py$ lua$ -> *.(py|lua)$)
		--   2. Move them to end of prompt such that they are not included in permutations
		for i, t in ipairs(tokens) do
			if t:sub(-1, -1) == "$" and not t:sub(-2, -2) == [[\]] then
				table.insert(file_ext_ids, i)
				if t ~= "$" then
					file_ext[#file_ext + 1] = vim.split(t:sub(1, -2), ",")
				end
			end
		end

		for i = #file_ext_ids, 1, -1 do
			table.remove(tokens, file_ext_ids[i])
		end
		prompt = permutations(tokens)
		if not vim.tbl_isempty(file_ext) then
			file_ext = vim.tbl_filter(function(x)
				return x ~= ""
			end, vim.tbl_flatten(file_ext))
			prompt = prompt .. string.format([[.*(%s)$]], table.concat(file_ext, "|"))
		end
		return { "rg", "-N", "--color=never", "--smart-case", "--json", "--", prompt, path }
	end, gen_from_file(opts), opts.max_results, cwd)

	picker = pickers.new(opts, {
		prompt_title = "Find Files",
		finder = find_command,
		previewer = conf.file_previewer(opts),
		sorter = sort_fn,
		tiebreak = function(current_entry, existing_entry)
			return current_entry.len < existing_entry.len
		end,
	})
	picker:find()
end
