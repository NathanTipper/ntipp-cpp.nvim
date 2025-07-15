local M = {}

M._inclDir = ""
M._srcDir = ""

M._as_windows_path = function(path)
	return string.gsub(path, "/", "\\")
end

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
---@param path string? optional field for sub directories
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
	local current_buf = vim.api.nvim_buf_get_name(0)

	local dir = ""
	for i = current_buf:len(), 1, -1 do
		local char = current_buf:sub(i, i)
		if char == "\\" then
			dir = current_buf:sub(1, i)
			if dir == M._as_windows_path(M._srcDir) then
				dir = M._as_windows_path(M._inclDir) .. current_buf:sub(i + 1, -4) .. "hpp"
				break
			elseif dir == M._as_windows_path(M._inclDir) then
				dir = M._as_windows_path(M._srcDir) .. current_buf:sub(i + 1, -4) .. "cpp"
				break
			end
		end
	end

	vim.cmd("e " .. dir)
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
	local line = vim.api.nvim_buf_get_lines(0, line_num, line_num + 1, true)
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
	local return_type = current_line:sub(1, first_space_ind - 1)

	local func_name_end = current_line:find("%(")
	local func_name = current_line:sub(first_space_ind + 1, func_name_end - 1)

	local class_def = ""
	for _, str in ipairs(file) do
		class_def = str:match("class%s-.-%s-{")
		if class_def ~= "" and class_def ~= nil then
			break
		end
	end

	if class_def ~= "" and class_def ~= nil then
		print("ERROR: Could not find class definition!")
		return
	end

	local class_name = string.gsub(class_def:match("%s.-%s"), " ", "")

	local arg_list_begin = func_name_end
	local arg_list_end = current_line:find("%)")
	if arg_list_begin == nil or arg_list_end == nil then
		return
	end

	local func_imp = return_type
		.. " "
		.. class_name
		.. "::"
		.. func_name
		.. current_line:sub(arg_list_begin, arg_list_end)
		.. "\n{"
		.. "\n"
		.. "}\n"
	-- for now we will ignore putting default parameter names. Not sure how to tell 100% if there is no name
	print(func_imp)
end

M.setup = function(opts)
	M.set_incl_dir(opts.incl_path)
	M.set_src_dir(opts.src_path)

	vim.keymap.set("n", "<leader>cc", M.issuePromptCreateClass, { desc = "Create C++ class" })
	vim.keymap.set("n", "<leader>cs", M.switchClassFile, { desc = "Switch class file" })
end

return M
