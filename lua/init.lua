local M = {}

M._inclDir = ""
M._srcDir = ""
M._rootDir = ""
M._DEBUG = nil
M._slo = nil -- Single Line syntax only
M._pretty_ml_comments = nil -- @NOTE: Cannot be used with _slo. _slo takes priority.
M._cc_preview_win_id = nil
M._buildErrMsgs = {}

M._setRootDir = function(root_dir)
	if M._isValidString(root_dir) then
		M._rootDir = root_dir
		if M._rootDir:sub(-1, -1) ~= "/" then
			M._rootDir = M._rootDir .. "/"
		end
	end
end
--- Sets the include path for newly created header files
--- @param incl_path string Path to be set as the project include folder. Expects forward slashes.
M.set_incl_dir = function(incl_path)
	if not M._rootDir then
		print("ERROR::set_src_dir : Root directory not set!")
		return
	end

	if not incl_path then
		return
	end

	M._inclDir = incl_path
	if M._inclDir ~= ""  and M._inclDir:sub(-1, -1) ~= "/" then
		M._inclDir = M._inclDir .. "/"
	end
end

--- Sets the src path for new created source files
--- @param src_path string Path to be set as the project source folder. Expects forward slashes.
M.set_src_dir = function(src_path)
	if not M._rootDir then
		print("ERROR::set_src_dir : Root directory not set!")
		return
	end

	if not src_path then
		return
	end

	M._srcDir = src_path
	if M._srcDir ~= "" and M._srcDir:sub(-1, -1) ~= "/" then
		M._srcDir = M._srcDir .. "/"
	end
end

--- Creates a class with a filename of the same name in the provided include and source directories
M.createClass = function()
	local cc_prompt = {
		prompts =
		{
			{
				prompt = "Path to store new class: ",
				default = "",
				completion = "dir",
				cancelreturn = "",
				reskey = "path"
			},
			{
				prompt = "Enter new class name: ",
				default = "",
				cancelreturn = "",
				reskey = "name"
			},
		},
		conf =
		{
			prompt = "Create new class {name} in " .. M._srcDir .. "{path}?: ",
			default = "",
			cancelreturn = "",
		}
	}

	local inputResponses = M._promptUser(cc_prompt)
	if M._isTableEmpty(inputResponses) then
		print("ERROR::createClass : Invalid inputs")
	end

	local path = inputResponses["path"]
	local name = inputResponses["name"]

	local inclDirWin = M._winGetIncludeFullFilePath()
	local srcDirWin = M._winGetSrcFullFilePath()

	if M._isValidString(path) and path:find("/$") == nil then
		path = path .. "/"
	end

	if M._isValidString(path) then
		inclDirWin = inclDirWin .. M._asWindowsPath(path)
		srcDirWin = srcDirWin .. M._asWindowsPath(path)
	end

	os.execute("mkdir " .. inclDirWin)
	os.execute("mkdir " .. srcDirWin)

	vim.cmd("e " .. srcDirWin .. name .. ".cpp")
	local path_incl = '#include "'
	if M._isValidString(path) then
		path_incl = path_incl .. path .. name .. '.hpp"'
	else
		path_incl = path_incl .. name .. '.hpp"'
	end

	vim.api.nvim_buf_set_lines(0, 0, -1, false, { path_incl, "" })
	vim.cmd("w")
	vim.cmd("e " .. inclDirWin .. name .. ".hpp")

	local classDef = {
		"#ifndef " .. name:upper() .. "_H",
		"#define " .. name:upper() .. "_H",
		"",
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

M.createDataStructure = function()
	local ds_prompt = {
		prompts = {
			{
				prompt = "Path to store data structure: ",
				default = "",
				completion = "dir",
				cancelreturn = "",
				reskey = "path"
			},
			{
				prompt = "Enter new data structure name: ",
				default = "",
				cancelreturn = "",
				reskey = "name"
			}
		},
		conf = {
			prompt = "Create struct {name} at " .. M._inclDir .. "{path}?: ",
			default = "",
			cancelreturn = "",
		}
	}

	local inputResponses = M._promptUser(ds_prompt)
	if M._isTableEmpty(inputResponses) then
		print("ERROR::createClass : Invalid inputs")
	end

	local path = inputResponses["path"]
	local name = inputResponses["name"]

	local inclDirWin = M._winGetIncludeFullFilePath()

	if M._isValidString(path) and path:find("/$") == nil then
		path = path .. "/"
	end

	if M._isValidString(path) then
		inclDirWin = inclDirWin .. M._asWindowsPath(path)
	end

	os.execute("mkdir " .. inclDirWin)

	vim.cmd("e " .. inclDirWin .. name .. ".hpp")

	local structDef = {
		"#ifndef " .. name:upper() .. "_H",
		"#define " .. name:upper() .. "_H",
		"",
		"struct " .. name,
		"{",
		"",
		"};",
		"",
		"#endif // " .. name:upper() .. "_H",
	}
	vim.api.nvim_buf_set_lines(0, 0, -1, false, structDef)
	vim.cmd("w")
end

M.switchClassFile = function()
	local file_complement = M._findFileComplement()
	if not file_complement then
		print("ERROR::switchClassFile : Could not find complementary file")
		return
	end

	vim.cmd("e " .. M._findFileComplement())
end

---Prompts the user for input using the prompts given
---@param inputs table
M._promptUser = function(inputs)
	local responses = {}

	for _, p in ipairs(inputs.prompts) do
		local opts = {}
		for key, val in pairs(p) do
			opts[key] = val
		end

		responses[opts.reskey] = vim.fn.input(opts)
	end

	if inputs.conf then
		local formatted_conf_prompt = inputs.conf.prompt
		for key, val in pairs(responses) do
			formatted_conf_prompt = formatted_conf_prompt:gsub("{" .. key .. "}", val)
		end

		inputs.conf.prompt = formatted_conf_prompt
		local conf = vim.fn.input(inputs.conf)
		if conf == 'n' then
			print("Input cancelled.");
			return {}
		end
	end

	return responses
end

-- TODO: @ntipp Add nested scoping
M.createFuncFromProto = function()
	local src_file = M._findFileComplement()

	if not src_file then
		print("ERROR::createFuncFromProto : Could not locate source file with name: " .. src_file)
		return
	end

	local line_num = vim.fn.line(".")
	local file = vim.api.nvim_buf_get_lines(0, 0, -1, true)

	if M._isTableEmpty(file) then
		print("ERROR::createFuncFromProto : buf_get_lines returned empty table.")
		return
	end

	if line_num > #file then
		print("ERROR::createFuncFromProto : line_num is greater than number of lines in file.")
		return
	end

	local keywords_to_ignore = {
		"override",
		"virtual",
		"static",
		"inline",
	}

	local current_line = file[line_num] or ""
	for _, val in ipairs(keywords_to_ignore) do
		current_line = current_line:gsub(val, "")
	end

	local s = current_line:find("%S")
	local e = current_line:find(";")
	local is_ml_def = false

	if s == nil then
		print("ERROR::createFuncFromProto : Line is empty")
		return
	end

	if e == nil then
		current_line = current_line:sub(s) .. "\n"
		for i = line_num + 1, #file, 1 do
			local nLine = file[i]

			if M._isValidString(nLine) then
				local ns = nLine:find("%S")
				local ws_offset = ns - (ns - s)
				nLine = nLine:sub(ws_offset + 1)
				e = nLine:find(";")
				if e then
					is_ml_def = true
					nLine = nLine:sub(1, e - 1)
					nLine = nLine:gsub("override", "")
					current_line = current_line .. " " .. nLine
					break
				else
					current_line = current_line .. "\n" .. nLine
				end
			end
		end
		if e == nil then
			print("ERROR::createFuncFromProto : Could not find termination of function prototype")
			return
		end
	else
		current_line = current_line:sub(s, e - 1)
	end

	if e < s then
		print("ERROR::createFuncFromProto : Terminating character (;) is in an invalid place. Please fix")
		return
	end


	local fn_begin, fn_end = current_line:find("%S*%(")
	local return_type = ""
	local func_name = nil
	local scope_name = nil

	func_name = current_line:sub(fn_begin, fn_end - 1)

	if fn_begin > 2 then
		return_type = current_line:sub(1, fn_begin - 2)
	end

	local add_type_spaced_s, add_type_spaced_e = func_name:find("^[%*&]*")
	if add_type_spaced_s and add_type_spaced_e then
		return_type = return_type .. func_name:sub(add_type_spaced_s, add_type_spaced_e)
		func_name = func_name:sub(add_type_spaced_e + 1)
	end

	if not scope_name then
		local file_name = vim.fn.expand("%:p:t")
		if not file_name then
			print("ERROR::createFuncFromProto : Could not get current buffer name")
			return
		else
			local keywords_to_match = { "class", "namespace", "struct" }
			local prepattern = "%s*"
			local postpattern = "%s[^{%s]*"
			local result = nil
			local match = nil
			file_name = file_name:sub(1, file_name:find("%.") - 1)

			local start_def_found = false
			local line_index = line_num - 1
			while line_index > 1 do
				local line = file[line_index]
				if line:match("{") then
					start_def_found = true
				end

				if start_def_found then
					for _, keyword in ipairs(keywords_to_match) do
						local format_to_match = prepattern .. keyword .. postpattern
						match = line:match(format_to_match)
						if match then
							result = match:gsub(keyword .. "%s", "")
							break
						end
					end
				end

				if result then
					scope_name = result .. "::"
					break
				end

				line_index = line_index - 1
			end
		end
	end

	vim.cmd("e " .. src_file)

	local src_lines = vim.api.nvim_buf_get_lines(0, -2, -1, true)
	if M._isTableEmpty(src_lines) then
		print("ERROR::createFuncFromProto : Failed to retrieve last line of file with name: " .. src_file)
		return
	end

	local last_line = src_lines[1]
	local func_imp = {
		last_line
	}

	if last_line ~= "" then
		table.insert(func_imp, "")
	end

	local first_line = return_type .. scope_name .. func_name
	if is_ml_def then
		local currentIndex = 0
		local lastIndex = fn_end
		local formatted_str = nil
		while true do
			currentIndex = current_line:find("\n", currentIndex + 1)
			if currentIndex then
				formatted_str = current_line:sub(lastIndex, currentIndex - 1)
				if lastIndex == fn_end then
					formatted_str = first_line .. formatted_str
				end
			else
				formatted_str = current_line:sub(lastIndex)
			end

			if formatted_str then
				formatted_str = M._deleteDefaultArgs(formatted_str)
			end

			table.insert(func_imp, formatted_str)

			if currentIndex then
				lastIndex = currentIndex + 1
			else
				break
			end
		end
	else
		local args = current_line:sub(fn_end)
		args = M._deleteDefaultArgs(args)
		table.insert(func_imp, first_line .. args)
	end

	table.insert(func_imp, "{")
	table.insert(func_imp, "\t// TODO: Implementation")
	table.insert(func_imp, "}")

	vim.api.nvim_buf_set_lines(0, -2, -1, true, func_imp)
	vim.cmd("w")
end

---Toggles comments between lstart and lend, prioritizing deleting existing lines before comments
---if there is a both commented and uncommented lines
---@param lstart integer line number to start the search
---@param lend integer line number to end the search
M._toggleComments = function(lstart, lend)
	local s = lstart or 0
	local e = lend or 0
	if s < 1 then
		print("ERROR::TOGGLE_COMMENTS : Cannot have a line start < 1")
		return
	end

	if e < s then
		print("ERROR::TOGGLE_COMMENTS : Cannot have a lend be less than lstart")
		return
	end

	local lines_to_edit = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
	if lines_to_edit == nil or M._isTableEmpty(lines_to_edit) then
		print("ERROR::VISUAL_TOGGLE_COMMENTS : Could not get lines in selection area")
		return
	end

	if not M._removeComments(lines_to_edit, s, e) then
		local nlinesToComment = (e - s) + 1
		if nlinesToComment > 1 and M._pretty_ml_comments then
			local rest_of_file = vim.api.nvim_buf_get_lines(0, e, -2, false)
			for _, str in ipairs(rest_of_file) do
				table.insert(lines_to_edit, str)
			end
			e = -2
		elseif not M._slo then
			if nlinesToComment > 1 then
				lines_to_edit = {
					lines_to_edit[1],
					lines_to_edit[#lines_to_edit]
				}
			else
				lines_to_edit = { lines_to_edit[1] }
			end
		end

		local commented_lines = {}
		local ml_white_space = nil
		if nlinesToComment > 1 and M._pretty_ml_comments then
			ml_white_space = lines_to_edit[1]:match("^%s*")
			table.insert(commented_lines, ml_white_space .. "/*")
		end

		for i, str in ipairs(lines_to_edit) do
			local commented_line = nil

			local white_space = str:match("^%s*") or ""
			local rol = str:match("%S.*") or ""

			if M._slo or nlinesToComment == 1 then
				if str ~= "" then
					commented_line = white_space .. "// " .. rol
				else
					commented_line = str
				end
			elseif M._pretty_ml_comments then
				if i <= nlinesToComment then
					commented_line = white_space .. "\t" .. rol
				else
					if i == nlinesToComment + 1 then
						table.insert(commented_lines, ml_white_space .. "*/")
					end
					commented_line = str
				end
			else
				if i == 1 then
					commented_line = white_space .. "/* " .. rol
				elseif i == nlinesToComment then
					commented_line = str .. " */"
				end
			end

			table.insert(commented_lines, commented_line)
		end

		if not M._pretty_ml_comments and not M._slo then
			vim.api.nvim_buf_set_lines(0, s - 1, s, false, { commented_lines[1] })
			if #commented_lines > 1 then
				vim.api.nvim_buf_set_lines(0, e - 1, e, false, { commented_lines[2] })
			end
		else
			vim.api.nvim_buf_set_lines(0, s - 1, e, false, commented_lines)
		end
	end

	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, false, true), 'm', false)
end

M.toggleComment = function()
	local cpos = vim.fn.getpos(".")
	local lnum = cpos[2]

	M._toggleComments(lnum, lnum)
end

M.visualToggleComments = function()
	local lstart, lend = M._getVisualAreaLineNum()

	if lstart == nil or lend == nil then
		print("ERROR::VISUAL_TOGGLE_COMMENTS : Could not find start/end number(s)")
		return
	end

	M._toggleComments(lstart, lend)
end

M.openFloatingWindow = function()
	local ui = vim.api.nvim_list_uis()[1]

	local width_offset = 30
	local width = M._srcDir:len() + width_offset
	local height = 10

	local centered_row = math.floor(((ui.height * 0.2) - (height * 0.5)) + 0.5)
	local centered_col = math.floor(((ui.width * 0.5) - (width* 0.5)) + 0.5)
	M._pre_float_state = {
		opts = {
			number = vim.opt.number,
			relativenumber = vim.opt.relativenumber,
		},
	}

	local config = {
		relative = "editor",
		col = centered_col,
		row = centered_row,
		width = width,
		height = height,
		title = "Class Creation",
		title_pos = "center",
		border = "single",
	}

	local preview_buf = vim.api.nvim_create_buf(false, true)
 	M._cc_preview_win_id = vim.api.nvim_open_win(preview_buf, false, config)
	vim.api.nvim_set_current_win(M._cc_preview_win_id)

	local test_width = math.floor(width * 0.9 + 0.5)
	local test_height = 4

	local test_centered_row = math.floor(((height * 0.2) - (test_height * 0.5)) + 0.5)
	local test_centered_col = math.floor(((width * 0.5) - (test_width* 0.5)) + 0.5)

	local test_config = {
		relative = "win",
		win = M._cc_preview_win_id,
		col = test_centered_col,
		row = test_centered_row,
		width = test_width,
		height = test_height,
		title = "Class Creation",
		title_pos = "center",
		border = "single",
	}

	local test_buf = vim.api.nvim_create_buf(false, true)
	M._cc_prompt_win_id = vim.api.nvim_open_win(test_buf, false, test_config)

	vim.opt.number = false
	vim.opt.relativenumber = false

	local default_include_path = M._asWindowsPath(M._inclDir)
	local default_src_path = M._asWindowsPath(M._srcDir)
	local class_name_prompt = "Class name: "
	local subdirectories_prompt = "Class path: "
	vim.api.nvim_buf_set_lines(preview_buf, 0, 1, false, {
		default_include_path,
		"",
		default_src_path,
	})


	local line_restrictions = {
		{ 4, class_name_prompt:len() },
		{ 5, subdirectories_prompt:len() }
	}

end

M._getNearestValidCursorPos = function(res)
	local cursor = vim.fn.getpos(".")

	local cur_row = cursor[2]
	local cur_col = cursor[3] - 1

	local des_row = cur_row
	local des_col = cur_col
	local oob = false

	for i, restriction_tbl in ipairs(res) do
		if i == 1 and cur_row < restriction_tbl[1] then
			des_row = restriction_tbl[1]
			des_col = restriction_tbl[2]
			oob = true
			break
		elseif i == #res and cur_row > restriction_tbl[1] then
			des_row = restriction_tbl[1]
			des_col = restriction_tbl[2]
			oob = true
			break
		end

		if cur_row == restriction_tbl[1] and cur_col < restriction_tbl[2] then
			des_col = restriction_tbl[2]
			oob = true
			break
		end
	end

	return des_row, des_col, oob
end

M._floatRestrictCursor = function(res)
	local des_row, des_col = M._getNearestValidCursorPos(res)
	vim.api.nvim_win_set_cursor(0, { des_row, des_col })
end

M._splitString = function(str, delimiter)
	if not str then
		return nil
	end

	local current_index = 0
	local last_index = 1
	local output = {}
	while true do
		current_index = str:find(delimiter, current_index + 1)
		if current_index then
			table.insert(output, str:sub(last_index, current_index - 1))
			last_index = current_index + 1
		else
			table.insert(output, str:sub(last_index))
			break
		end
	end

	return output
end

M.buildProject = function()
	print("Building!")
	local build_buf = vim.api.nvim_create_buf(false, true)
	local win_config = {
		vertical = true,
		split = "right"
	}

	local build_win_id = vim.api.nvim_open_win(build_buf, false, win_config)

	local stream_buffer = ""
	local process_stream = function(data)
		if #data == 1 and data[1] == '' then
			return
		end

		for _, str in ipairs(data) do
			if str == '' then
				local esc_char = string.char(27)
				local patterns_to_KILL = {
					esc_char .. "%[%d*;?%d*m",
					string.char(13)
				}

				for _, pattern in ipairs(patterns_to_KILL) do
					stream_buffer = stream_buffer:gsub(pattern, "")
				end

				local last_line = vim.api.nvim_buf_get_lines(build_buf, -2, -1, false)[1]
				if last_line == "" then
					vim.api.nvim_buf_set_lines(build_buf, -2, -1, false, { stream_buffer })
				else
					vim.api.nvim_buf_set_lines(build_buf, -2, -1, false, { last_line, stream_buffer })
				end
				stream_buffer = ""
			else
				stream_buffer = stream_buffer .. str
			end
		end
	end
	vim.fn.jobstart({ "make" },
		{
			on_exit = function()
				local file = io.open("build.log", "r")
				if file then
					M._buildErrMsgs = {}
					local content = file:read("*all")
					local lines = M._splitString(content, '\n')
					if lines and not M._isTableEmpty(lines) then
						for _, str in ipairs(lines) do
							local error = str:match(".-%.[ch]p?p?:%d*:%d*:.-:.*")
							if error then
								local error_split = M._splitString(error, ":")
								local error_type = (error_split[4]:match("error") and 'E') or 'W'
								table.insert(M._buildErrMsgs,
									{
										filename = error_split[1],
										lnum = error_split[2],
										col = error_split[3],
										type = error_type,
										text = error_split[5]
									})
							end
						end
					end
					vim.fn.input("Build complete. Hit any key to close")
					vim.api.nvim_win_close(build_win_id, true)
					M._pushErrorMsgsToQfList()
					file:close()
				end
			end,
			on_stdout = function(_, data, _)
				process_stream(data)
			end,
			on_stderr = function(_, data, _)
				process_stream(data)
			end
		}
	)
end

M._pushErrorMsgsToQfList = function()
	if not M._isTableEmpty(M._buildErrMsgs) then
		vim.fn.setqflist(M._buildErrMsgs, 'r')
		vim.cmd("copen")
	end
end

---comment
---@param opts any
M.setup = function(opts)
	if not M._isValidString(opts.root_dir) then
		print("ERROR::setup : Root directory cannot be nil or empty")
		return
	end

	M._setRootDir(opts.root_dir)
	M.set_incl_dir(opts.incl_dir)
	M.set_src_dir(opts.src_dir)

	M._DEBUG = opts.debug
	M._slo = opts.slo
	M._pretty_ml_comments = not M._slo and opts.pretty_ml_comments or false

	vim.keymap.set("n", "<leader>cc", M.createClass, { desc = "Create C++ class" })
	vim.keymap.set("n", "<leader>cd", M.createDataStructure, { desc = "Create data structure" })
	vim.keymap.set("n", "<C-O>", M.switchClassFile, { desc = "Switch class file" })
	vim.keymap.set(
		"n",
		"<leader>cp",
		M.createFuncFromProto,
		{ desc = "Create implementation of prototype on current line" }
	)
	vim.keymap.set("v", "<C-C>", M.visualToggleComments, { desc = "Toggle comments on selected lines" })
	vim.keymap.set("n", "<C-C>", M.toggleComment, { desc = "Toggle comment on current line" })
	vim.keymap.set("n", "<C-B>", M.buildProject, { desc = "Run build script" })
	vim.keymap.set("n", "<leader>cq", function() vim.cmd("copen") end, { desc = "Open qfix list" })
	vim.keymap.set("n", "<leader>cQ", function() vim.cmd("cclose") end, { desc = "Close qfix list" })
end

M._findFileComplement = function()
	local current_buf = vim.api.nvim_buf_get_name(0)

	local dir = nil
	local comp_file = nil

	if M._srcDir == "" and M._srcDir == M._inclDir then
		comp_file = (current_buf:sub(-4) == ".hpp" and current_buf:sub(1, -4) .. "cpp")
			or current_buf:sub(1, -4) .. "hpp"
	else
		local full_src_path = M._winGetSrcFullFilePath()
		local full_include_path = M._winGetIncludeFullFilePath()
		for i = current_buf:len(), 1, -1 do
			local char = current_buf:sub(i, i)
			if char == "\\" then
				dir = current_buf:sub(1, i)
				if dir == full_src_path then comp_file = full_include_path .. M._asWindowsPath(current_buf:sub(i + 1, -4)) .. "hpp"
					break
				elseif dir == full_include_path then
					comp_file = full_src_path .. M._asWindowsPath(current_buf:sub(i + 1, -4)) .. "cpp"
					break
				end
			end
		end
	end

	return comp_file
end

M._asWindowsPath = function(path)
	return string.gsub(path, "/", "\\")
end

M._winGetSrcFullFilePath = function()
	if M._rootDir and M._srcDir then
		return M._asWindowsPath(M._rootDir .. M._srcDir)
	end
end

M._winGetIncludeFullFilePath = function()
	if M._rootDir and M._inclDir then
		return M._asWindowsPath(M._rootDir .. M._inclDir)
	end
end

M._isValidString = function(str)
	return type(str) == "string" and str ~= ""
end

M._isTableEmpty = function(t)
	local next = next
	return next(t) == nil
end

M._getVisualAreaLineNum = function()
	local lstart = nil
	local lend = nil

	local vstart = vim.fn.getpos("v")
	local vend = vim.fn.getpos(".")

	if vstart[2] > vend[2] then
		lstart = vend[2]
		lend = vstart[2]
	elseif vstart[2] == vend[2] then
		lstart = vstart[2]
		lend = vstart[2]
	else
		lstart = vstart[2]
		lend = vend[2]
	end

	if M._DEBUG then
		print("\nDEBUG::VISUAL_TOGGLE_COMMENTS:\n\tstart line: " .. lstart .. "\n\tend line: " .. lend .. "\n")
	end

	return lstart, lend
end

M._formatPrint = function(tbl, title)
	if title then
		print("\n** " .. title .. " **\n\t")
	end

	if tbl then
		for key, value in pairs(tbl) do
			print(key .. ": " .. value .. "\n\t")
		end
	end
end

M._removeComments = function(lines, lnum_start, lnum_end)
	local s = lnum_start
	local e = lnum_end

	local lines_to_write = {}
	local lnum_start_offset = nil
	local ml_white_space = nil
	local comment_syntax = { "//", "/%*", "%*/" }
	for i, str in ipairs(lines) do
		local comment = nil
		for _, syntax in ipairs(comment_syntax) do
			comment = str:match(syntax)
			if comment then
				if not lnum_start_offset then
					lnum_start_offset = i - 1
				end

				local format = syntax .. "%s*"
				if comment == "/*" then
					ml_white_space = str:match("^%s*")
					if not str:match(syntax .. "%S") then
						local line_to_delete = (s + (i - 1))
						vim.api.nvim_buf_set_lines(0, line_to_delete - 1, line_to_delete, true, { })
						e = e - 1
						print("Deleted line " .. tostring(line_to_delete) .. " new editing end " .. tostring(e))
						break
					end
				elseif comment == "*/" then
					if not str:match("%S+.*" .. syntax) then
						local del_off = (ml_white_space == nil and (i - 1)) or (i - 2)
						local line_to_delete = (s + del_off)
						vim.api.nvim_buf_set_lines(0, line_to_delete - 1, line_to_delete, true, { })
						e = e - 1
						break
					end
					format = "%s*%*/%s*$"
					ml_white_space = nil
				end

				local formatted_string = str:gsub(format, "")
				table.insert(lines_to_write, formatted_string)
				break
			end
		end

		if not comment and lnum_start_offset then
			local uncommented_line = str
			if ml_white_space then
				local white_space = uncommented_line:match("^%s*")
				if white_space:len() > ml_white_space:len() then
					uncommented_line = ml_white_space .. (uncommented_line:match("%S.*") or "")
				end
			end
			table.insert(lines_to_write, uncommented_line)
		end
	end

	if not M._isTableEmpty(lines_to_write) then
		local write_line_start = (s + lnum_start_offset) - 1
		local write_line_end = e
		vim.api.nvim_buf_set_lines(0, write_line_start, write_line_end, false, lines_to_write)

		if M._DEBUG then
			print("Original lines: \n")
			print(vim.inspect(lines))
			print("Lines to write: \n")
			print(vim.inspect(lines_to_write))
		end
		return true
	end

	return false
end

M._find = function(str, pattern)
	local currentIndex = 0
	local lastIndex = nil
	local count = 0

	while true do
		currentIndex = str:find(pattern, currentIndex + 1)
		if currentIndex then
			lastIndex = currentIndex
			count = count + 1
		else
			break
		end
	end

	return lastIndex, count
end

M._debugLog = function(str)
	if M._DEBUG then
		print(str)
	end
end

M._deleteDefaultArgs = function(str)
	if not str then
		print("ERROR::M._deleteDefaultArgs : Received invalid input")
		return nil
	end

	local formatted_str = str
	local current_index = 0

	while true do
	  current_index = formatted_str:find("%s=", current_index + 1)
	  if current_index then
		local index_after_def_arg = nil
		local index_to_start_search = current_index
		local n_brace_index = formatted_str:find("%(", current_index)
		if n_brace_index then
			local n_close_brace_index = formatted_str:find("%)", current_index)
			if n_close_brace_index then
				index_to_start_search = n_close_brace_index
			end
		end

		index_after_def_arg = formatted_str:find("[,%)]", index_to_start_search) or index_to_start_search
		formatted_str = formatted_str:sub(1, current_index - 1) .. formatted_str:sub(index_after_def_arg)
	  else
		break
	  end
	end

	return formatted_str
end

return M
