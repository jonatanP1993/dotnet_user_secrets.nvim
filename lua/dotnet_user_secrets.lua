local M = {}

-- Function to find all .csproj files in the current directory and subdirectories
local function find_all_csproj()
	local cwd = vim.fn.getcwd()
	local csproj_files = vim.fn.split(vim.fn.system("find " .. cwd .. " -name '*.csproj'"), "\n")
	if #csproj_files == 0 then
		print("No .csproj files found.")
		return nil
	end
	return csproj_files
end

-- Function to extract UserSecretsId from the selected .csproj file
local function get_user_secrets_id(csproj_path)
	local secrets_id = nil
	for line in io.lines(csproj_path) do
		secrets_id = line:match("<UserSecretsId>(.-)</UserSecretsId>")
		if secrets_id then
			break
		end
	end
	return secrets_id
end

-- Function to get the path to the secrets.json file
local function get_user_secrets_file(secrets_id)
	local secrets_file
	if vim.fn.has("win32") == 1 then
		secrets_file = os.getenv("APPDATA") .. "\\Microsoft\\UserSecrets\\" .. secrets_id .. "\\secrets.json"
	else
		secrets_file = os.getenv("HOME") .. "/.microsoft/usersecrets/" .. secrets_id .. "/secrets.json"
	end

	return secrets_file
end

local function command_exists(command)
	local cmd

	if package.config:sub(1, 1) == "\\" then
		cmd = "where " .. command .. " > nul 2&1"
	else
		cmd = "command -v " .. command .. " > /dev/null 2 >&1"
	end

	local success = os.execute(cmd)

	if success == nil or success == false then
		return false
	else
		return true
	end
end

local function create_and_init_user_secrets_file(project_name)
	vim.notify(
		"Unable to find secrets file, trying to create it automatically",
		vim.log.levels.INFO,
		{ title = "INFO" }
	)

	if not command_exists("dotnet user-secrets") then
		vim.notify(
			"Please ensure that 'dotnet user-secrets' is properly installed",
			vim.log.levels.ERROR,
			{ title = "Error" }
		)
		return
	end
	vim.fn.system(
		"dotnet user-secrets init --project "
			.. project_name
			.. "&& dotnet user-secrets clear --project "
			.. project_name
	)

	local user_secret_id = get_user_secrets_id(project_name)
	if user_secret_id then
		local user_secret_file = get_user_secrets_file(user_secret_id)
		if user_secret_file and vim.fn.filereadable(user_secret_file) == 1 then
			vim.cmd("close") -- Close the floating window
			vim.cmd("edit " .. user_secret_file)
		end
	end
	vim.notify("Successfully created new secrets file", vim.log.levels.INFO, { title = "INFO" })
end

-- Function to handle the selection of a .csproj file
local function select_file()
	local line = vim.fn.line(".")
	local csproj_files = vim.b.csproj_files
	local selected_csproj = csproj_files[line]

	if not selected_csproj then
		print("Invalid selection.")
		return
	end

	local user_secret_id = get_user_secrets_id(selected_csproj)
	if user_secret_id then
		local secrets_file = get_user_secrets_file(user_secret_id)
		if secrets_file and vim.fn.filereadable(secrets_file) == 1 then
			vim.cmd("close") -- Close the floating window
			vim.cmd("edit " .. secrets_file)
		else
			create_and_init_user_secrets_file(selected_csproj)
		end
	else
		create_and_init_user_secrets_file(selected_csproj)
	end
end

local function get_display_names(csproj_files)
	local result = {}
	for _, proj_file in ipairs(csproj_files) do
		local t = {}
		for str in string.gmatch(proj_file, "([^" .. "/" .. "]+)") do
			-- insert the substring in table
			table.insert(t, str)
		end
		table.insert(result, t[#t])
	end
	return result
end

-- Function to open a floating window for selecting a .csproj file
local function open_selection_window(csproj_files)
	-- Set window dimensions
	local width = math.floor(vim.o.columns * 0.6)
	local height = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Create a buffer for the floating window
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

	-- Set the content of the buffer
	local display_names = get_display_names(csproj_files)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_names)

	-- Create the floating window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	-- Set key mappings for navigation and selection
	vim.keymap.set("n", "<CR>", select_file)
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<ESC>", ":close<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "k", "k", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "j", "j", { noremap = true, silent = true })

	-- Store state for the selection
	vim.b.csproj_files = csproj_files
	vim.b.selection_win = win
end

-- Function to initiate the user secrets selection
M.open_user_secrets = function()
	local csproj_files = find_all_csproj()
	if not csproj_files then
		return
	end
	open_selection_window(csproj_files)
end

return M
