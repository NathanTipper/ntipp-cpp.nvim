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
	if M._inclDir == nil or M._srcDir == nil then
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

M.setup = function(opts)
	M.set_incl_dir(opts.incl_path)
	M.set_src_dir(opts.src_path)

	vim.keymap.set("n", "<leader>cc", function()
		local path = vim.fn.input({ prompt = "Path for new class (does not have to exist): " })

		local pathConf = ""
		if path ~= "" then
			pathConf = vim.fn.input({ prompt = "Confirm path " .. path .. "? (y/n) " })
		end

		if pathConf == "" or pathConf == "n" then
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
	end, { desc = "Create C++ class" })

	vim.keymap.set("n", "<leader>cs", M.switchClassFile)
end

return M
