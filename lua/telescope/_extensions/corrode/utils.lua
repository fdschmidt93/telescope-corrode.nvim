local M = {}
-- `rg` highlighting with `AND` can be too greedy
-- M.find_all_offsets = function(line, matches)
-- 	local offsets = {}
-- 	for _, match in ipairs(matches) do
-- 		local match_
-- 		if match:sub(-1, -1) == "$" then
-- 			match_ = match:sub(1, -2)
-- 		else
-- 			match_ = match
-- 		end
-- 		local start = 1
-- 		while start do
-- 			local s, e = string.find(line, match_, start, true) -- true makes the search plain (no pattern matching)
-- 			if s then
-- 				table.insert(offsets, { start = s - 1, end_ = e })
-- 				start = e + 1
-- 			else
-- 				break
-- 			end
-- 		end
-- 	end
-- 	return offsets
-- end
M.find_all_offsets = function(line, matches)
	local offsets = {}

	for _, match in ipairs(matches) do
		local match_
		if match:sub(-1, -1) == "$" then
			match_ = match:sub(1, -2)
		else
			match_ = match
		end
		if match_ ~= "" then
			local is_case_sensitive = match_:lower() ~= match_ -- true if match_ has any uppercase characters

			local pattern = is_case_sensitive and match_ or string.lower(match_)
			local search_line = is_case_sensitive and line or string.lower(line)

			local start = 1
			while start do
				local s, e = string.find(search_line, pattern, start, true) -- true makes the search plain (no pattern match_ing)
				if s then
					table.insert(offsets, { match_ = match_, start = s - 1, end_ = e })
					start = e + 1
				else
					break -- This will exit the while loop immediately
				end
			end
		end
	end

	return offsets
end

--- Tokenizes the `prompt` into space-separated tokens (i.e. words)
--- @param prompt string: the prompt to tokenize
--- @return table: the tokens in the prompt
M.tokenize = function(prompt)
	local tokens = {}
	for token in prompt:gmatch("%S+") do
		tokens[#tokens + 1] = token
	end
	return tokens
end

return M
