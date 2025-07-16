local M = {}

M._inclDir = ""
M._srcDir = ""

--- Sets the include path for newly created header files
--- @param incl_path string Path to be set as the project include folder. Expects forward slashes.
M.set_incl_dir = function(incl_path)
	M._inclDir = incl_path
	if M._inclDir:sub(-1, -1) ~= "/" then
		M._inclDir = M._inclDir .. "/"
	end
end

--- Sets the src path for new created source files
--- @param src_path string Path to be set as the project source folder. Expects forward slashes.
M.set_src_dir = function(src_path)
	M._srcDir = src_path
	if M._srcDir:sub(-1, -1) ~= "/" then
		M._srcDir = M._srcDir .. "/"
	end
end

--- Creates a class with a filename of the same name in the provided include and source directories
---@param name string name of the class to create
---@param path string? optional field for sub directories. They will created if they don't exist.
M.createClass = function(name, path)
	if M._inclDir == "" or M._srcDir == "" then
		return
	end

	local inclDirWin = M._as_windows_path(M._inclDir)
	local srcDirWin = M._as_windows_path(M._srcDir)

	local fullInclDir = inclDirWin
	local fullSrcDir = srcDirWin
	if path and path ~= "" then
		fullInclDir = fullInclDir .. M._as_windows_path(path)
		fullSrcDir = fullSrcDir .. M._as_windows_path(path)
	end

	os.execute("mkdir " .. fullInclDir)
	os.execute("mkdir " .. fullSrcDir)

	vim.cmd("e " .. fullSrcDir .. "\\" .. name .. ".cpp")
	local path_incl = '#include "'
	if not path or path == "" then
		path_incl = path_incl .. name .. '.hpp"'
	else
		path_incl = path_incl .. path .. "/" .. name .. '.hpp"'
	end

	vim.api.nvim_buf_set_lines(0, 0, -1, false, { path_incl, "" })
	vim.cmd("w")
	vim.cmd("e " .. fullInclDir .. "\\" .. name .. ".hpp")

	local classDef = {
		"#ifndef " .. name:upper() .. "_H",
		"#define " .. name:upper() .. "_H",
		"class " .. name,
		"{",
		"\tpublic:",
		"",
		"",
		"\tprivate:",
		"",
		"",
		"};",
		"",
		"#endif // " .. name:upper() .. "_H",
	}
	vim.api.nvim_buf_set_lines(0, 0, -1, false, classDef)
	vim.cmd("w")
end

M.switchClassFile = function()
	vim.cmd("e " .. M._findFileComplement())
end

M.issuePromptCreateClass = function()
	local path = vim.fn.input({ prompt = "Path for new class (does not have to exist): " })

	local pathConf = ""
	if path ~= "" then
		pathConf = vim.fn.input({ prompt = "Confirm path " .. path .. "? (y/n) " })
	end

	if pathConf == "n" then
		return
	end

	local fname = vim.fn.input({ prompt = "Class name: " })
	if fname == "" then
		print("Cannot make file with empty string")
		return
	end

	local conf = vim.fn.input({ prompt = "Create class " .. fname .. "? (y/n) " })
	if conf == "n" or conf == "" then
		return
	end

	M.createClass(fname, path)
end

M.createFuncFromProto = function()
	local line_num = vim.fn.line(".")
	local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)
	local file = vim.api.nvim_buf_get_lines(0, 0, -1, true)

	local next = next
	if next(line) == nil or next(file) == nil then
		return
	end

	local current_line = line[1]

	local keywords_to_ignore = {
		"override",
		"virtual",
		"static",
		"inline",
	}

	-- local default_arg_name = 97 -- 'a'

	for _, val in ipairs(keywords_to_ignore) do
		current_line = current_line:gsub(val, "")
	end

	local s = current_line:find("%S")
	local e = current_line:find("%s*;")

	if s == nil then
		print("Could not find anything on current line!")
		return
	end

	if e == nil then
		print("Could not find terminating character (;)")
		return
	end

	current_line = current_line:sub(s, e)

	local first_space_ind = current_line:find("%s")

	if first_space_ind == nil then
		print("Could not find a space on current line")
		return
	end

	local return_type = current_line:sub(1, first_space_ind - 1)

	local func_name_end = current_line:find("%(")
	local func_name = current_line:sub(first_space_ind + 1, func_name_end - 1)

	local class_name = ""
	do
		local found = false
		local pattern_to_match = "%s-class%s.-%s"
		local file_name = vim.fn.expand("%:p:t")
		file_name = file_name:sub(1, file_name:find(".") - 1)
		for _, str in ipairs(file) do
			class_name = str:match(pattern_to_match)
			if M._isValidString(class_name) then
				if str:find(";") == nil then
					class_name = class_name:gsub("class", ""):gsub(" ", "")
					if M._isValidString(class_name) then
						found = true
						break
					end
				else
					print("Found prototype: " .. class_name)
				end
			end
		end

		if not found then
			print("Could not find the class name. Expectation is that the file name can be found in the class name")
			return
		end
	end

	local arg_list_begin = func_name_end
	local arg_list_end = current_line:find("%)")
	if arg_list_begin == nil or arg_list_end == nil then
		return
	end

	local src_file = M._findFileComplement()
	vim.cmd("e " .. src_file)

	local src_lines = vim.api.nvim_buf_get_lines(0, -2, -1, true)
	if next(src_lines) == nil then
		print("Could not get last line of src file")
		return
	end

	local last_line = src_lines[1]
	if last_line ~= "" then
		vim.api.nvim_buf_set_lines(0, -2, -1, true, { last_line, "" })
	end

	local func_imp = {
		"",
		return_type .. " " .. class_name .. "::" .. func_name .. current_line:sub(arg_list_begin, arg_list_end),
		"{",
		"",
		"}",
	}

	-- for now we will ignore putting default parameter names. Not sure how to tell 100% if there is no name

	vim.api.nvim_buf_set_lines(0, -2, -1, true, func_imp)
	vim.cmd("w")
end

M.setup = function(opts)
	M.set_incl_dir(opts.incl_path)
	M.set_src_dir(opts.src_path)

	vim.keymap.set("n", "<leader>cc", M.issuePromptCreateClass, { desc = "Create C++ class" })
	vim.keymap.set("n", "<leader>cs", M.switchClassFile, { desc = "Switch class file" })
	vim.keymap.set(
		"n",
		"<leader>cp",
		M.createFuncFromProto,
		{ desc = "Create implementation of prototype on current line" }
	)
end

M._findFileComplement = function()
	local current_buf = vim.api.nvim_buf_get_name(0)

	local dir = ""
	local comp_file = ""

	if M._srcDir ~= "" and M._srcDir == M._inclDir then
		comp_file = (current_buf:sub(-4) == ".hpp" and current_buf:sub(1, -4) .. "cpp")
			or current_buf:sub(1, -4) .. "hpp"
	else
		for i = current_buf:len(), 1, -1 do
			local char = current_buf:sub(i, i)
			if char == "\\" then
				dir = current_buf:sub(1, i)
				if dir == M._as_windows_path(M._srcDir) then
					comp_file = M._as_windows_path(M._inclDir) .. current_buf:sub(i + 1, -4) .. "hpp"
					break
				elseif dir == M._as_windows_path(M._inclDir) then
					comp_file = M._as_windows_path(M._srcDir) .. current_buf:sub(i + 1, -4) .. "cpp"
					break
				end
			end
		end
	end

	return comp_file
end

M._as_windows_path = function(path)
	return string.gsub(path, "/", "\\")
end

M._isValidString = function(str)
	return type(str) == "string" and str ~= ""
end

return M
