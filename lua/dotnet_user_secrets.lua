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
local function get_user_secrets_file(csproj)
	local secrets_id = get_user_secrets_id(csproj)
	if not secrets_id then
		print("No UserSecretsId found in " .. csproj)
		return
	end

	-- Determine the file path based on the operating system
	local secrets_file
	if vim.fn.has("win32") == 1 then
		secrets_file = os.getenv("APPDATA") .. "\\Microsoft\\UserSecrets\\" .. secrets_id .. "\\secrets.json"
	else
		secrets_file = os.getenv("HOME") .. "/.microsoft/usersecrets/" .. secrets_id .. "/secrets.json"
	end

	return secrets_file
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

	local secrets_file = get_user_secrets_file(selected_csproj)
	if secrets_file and vim.fn.filereadable(secrets_file) == 1 then
		vim.cmd("close") -- Close the floating window
		vim.cmd("edit " .. secrets_file)
	else
		print("User secrets file not found.")
	end
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
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, csproj_files)

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
