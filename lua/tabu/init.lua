local buffers_by_tab = require("tabu.state")
local setup = require("tabu.setup")
local popup = require("plenary.popup")
local utils = require("tabu.utils")

local _in_patterns_to_ignore = function(bufname)
	for _, pattern in pairs(setup.pattern_to_ignore) do
		if string.match(bufname, pattern) then
			return true
		end
	end
	return false
end

local update_tabs_table = function(tabs)
	for _, tab in pairs(tabs) do
		buffers_by_tab[tab.tabnr] = {}
		for _, winnr in pairs(tab.windows) do
			local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winnr))
			if not _in_patterns_to_ignore(bufname) then
				table.insert(buffers_by_tab[tab.tabnr], vim.api.nvim_win_get_buf(winnr))
			end
		end
	end
end

-- Groups
local group = vim.api.nvim_create_augroup("Tabu", { clear = true })

-- This events are necessary for the `reload_preview` function to work correctly
vim.api.nvim_create_autocmd("BufDelete", {
	group = group,
	callback = function()
		local tabs = vim.fn.gettabinfo()
		vim.schedule(function()
			update_tabs_table(tabs)
		end)
	end,
})
vim.api.nvim_create_autocmd("TabNew", {
	group = group,
	callback = function()
		local tabs = vim.fn.gettabinfo()
		vim.schedule(function()
			update_tabs_table(tabs)
		end)
	end,
})
vim.api.nvim_create_autocmd("TabClosed", {
	group = group,
	callback = function()
		local tabs = vim.fn.gettabinfo()
		vim.schedule(function()
			update_tabs_table(tabs)
		end)
	end,
})

local M = {}

M._create_windows = function()
	local pickers_bufnr = v.nvim_create_buf(false, false)
	local preview_bufnr = v.nvim_create_buf(false, false)
	local total_width = setup.config.windows.picker.width + setup.config.windows.previewer.width

	popup.create(pickers_bufnr, {
		border = {},
		title = false,
		highlight = "PickersHighlight",
		borderhighlight = "PickersBorder",
		enter = true,
		line = math.floor(((vim.o.lines - setup.config.height) / 2) - 1),
		col = math.floor((vim.o.columns - total_width) / 2),
		minwidth = setup.config.windows.picker.width,
		minheight = setup.config.height,
		borderchars = setup.config.borderchars,
	}, false)
	popup.create(preview_bufnr, {
		border = {},
		title = "~ Tabú ~",
		highlight = "PreviewHighlight",
		borderhighlight = "PreviewBorder",
		enter = false,
		line = math.floor(((vim.o.lines - setup.config.height) / 2) - 1),
		col = math.floor(((vim.o.columns - total_width) + setup.config.windows.picker.width + 6) / 2),
		minwidth = setup.config.windows.previewer.width,
		minheight = setup.config.height,
		borderchars = setup.config.borderchars,
	}, false)

	setup.config.windows.picker.id = pickers_bufnr
	setup.config.windows.previewer.id = preview_bufnr
end

M._set_mappings = function()
	for mode in pairs(setup.mappings) do
		for key_bind in pairs(setup.mappings[mode]) do
			local func = string.format(
				setup.mappings[mode][key_bind],
				setup.config.windows.picker.id,
				setup.config.windows.previewer.id
			)
			vim.api.nvim_buf_set_keymap(setup.config.windows.picker.id, mode, key_bind, func, { silent = true })
		end
	end
end

M._display_buffers_by_tab = function(tabs_table)
	-- populate pickers window
	for tab_idx, _ in ipairs(tabs_table) do
		local line = { " " .. tostring(tab_idx) .. " " }
		vim.api.nvim_buf_set_lines(setup.config.windows.picker.id, tab_idx - 1, -1, true, line)
	end
	M._load_preview(tabs_table, setup.config.windows.picker.id, setup.config.windows.previewer.id)
end

M._load_preview = function(tabs_table, pickernr, previewnr)
	local info = vim.fn.getpos(".")
	local curr_cursor_line = info[2]

	local lines = {}
	for _, buf_value in ipairs(tabs_table[curr_cursor_line]) do
		local formatted_path = utils.format_path(vim.api.nvim_buf_get_name(buf_value))
		table.insert(lines, formatted_path)
	end
	vim.api.nvim_buf_set_lines(previewnr, 0, -1, true, lines)
end

M.reload_preview = function(pickernr, previewnr, direction)
	local info = vim.fn.getpos(".") -- get cursor position
	local curr_cursor_line = info[2]
	local next_line = curr_cursor_line + setup.config.directions[direction]

	local number_of_tabs = #vim.api.nvim_buf_get_lines(pickernr, 0, -1, false)

	-- check if next line is valid
	if not (next_line > 0 and next_line <= number_of_tabs) then
		if next_line == 0 then
			next_line = number_of_tabs
		else
			next_line = 1
		end
	end

	vim.fn.setpos(".", { pickernr, next_line, 1, 1 })

	local new_lines = {}
	for _, buf_value in pairs(buffers_by_tab[next_line]) do
		local formatted_path = utils.format_path(vim.api.nvim_buf_get_name(buf_value))
		table.insert(new_lines, formatted_path)
	end
	vim.api.nvim_buf_set_lines(previewnr, 0, -1, true, new_lines)
end

M.clean = function()
	setup.config.windows.picker.id = nil
	setup.config.windows.previewer.id = nil
end

M.get_tabs_table = function(tabs)
	local tabs_table = {}
	for _, tab in pairs(tabs) do
		tabs_table[tab.tabnr] = {}
		for _, winnr in pairs(tab.windows) do
			local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winnr))
			if not _in_patterns_to_ignore(bufname) then
				table.insert(tabs_table[tab.tabnr], vim.api.nvim_win_get_buf(winnr))
			end
		end
	end
	return tabs_table
end

M.debug = function()
	local tabs_table = M.get_tabs_table(vim.fn.gettabinfo())

	M._create_windows()
	M._set_mappings()
	M._display_buffers_by_tab(tabs_table)
end

M.close = function(pickernr, previewnr)
	M.clean()
	v.nvim_exec(string.format("%s,%sbw!", pickernr, previewnr), true)
end

M.select_tab = function(pickernr, previewnr)
	local info = vim.fn.getpos(".")
	local tab_num = info[2]
	vim.api.nvim_exec(":tabn" .. tab_num, true)
	M.close(pickernr, previewnr)
end

vim.api.nvim_set_keymap("n", "<Leader>a", ':lua require"tabu.init".debug()<CR>', { noremap = true, silent = true })

return M
