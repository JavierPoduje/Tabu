local buffers_by_tab = require("tabu.state")
local defs = require("tabu.definitions")
local popup = require("plenary.popup")
local utils = require("tabu.utils")

local update_tabs_table = function(tabs)
	local in_patterns_to_ignore = function(bufname)
		for _, pattern in pairs(defs.pattern_to_ignore) do
			if string.match(bufname, pattern) then
				return true
			end
		end

		return false
	end

	for _, tab in pairs(tabs) do
		buffers_by_tab[tab.tabnr] = {}
		for _, winnr in pairs(tab.windows) do
			local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winnr))
			if not in_patterns_to_ignore(bufname) then
				table.insert(buffers_by_tab[tab.tabnr], vim.api.nvim_win_get_buf(winnr))
			end
		end
	end
end

-- Groups
local group = vim.api.nvim_create_augroup("Tabu", { clear = true })

vim.api.nvim_create_autocmd("BufDelete", {
	group = group,
	callback = function()
		local tabs = vim.fn.gettabinfo()
		buffers_by_tab = {}
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
		buffers_by_tab = {}
		vim.schedule(function()
			update_tabs_table(tabs)
		end)
	end,
})

local M = {}

M._create_windows = function()
	local pickers_bufnr = v.nvim_create_buf(false, false)
	local preview_bufnr = v.nvim_create_buf(false, false)
	local total_width = defs.config.windows.picker.width + defs.config.windows.previewer.width

	popup.create(pickers_bufnr, {
		border = {},
		title = false,
		highlight = "PickersHighlight",
		borderhighlight = "PickersBorder",
		enter = true,
		line = math.floor(((vim.o.lines - defs.config.height) / 2) - 1),
		col = math.floor((vim.o.columns - total_width) / 2),
		minwidth = defs.config.windows.picker.width,
		minheight = defs.config.height,
		borderchars = defs.config.borderchars,
	}, false)
	popup.create(preview_bufnr, {
		border = {},
		title = "~ Tabú ~",
		highlight = "PreviewHighlight",
		borderhighlight = "PreviewBorder",
		enter = false,
		line = math.floor(((vim.o.lines - defs.config.height) / 2) - 1),
		col = math.floor(((vim.o.columns - total_width) + defs.config.windows.picker.width + 6) / 2),
		minwidth = defs.config.windows.previewer.width,
		minheight = defs.config.height,
		borderchars = defs.config.borderchars,
	}, false)

	defs.config.windows.picker.id = pickers_bufnr
	defs.config.windows.previewer.id = preview_bufnr
end

M._set_mappings = function()
	for mode in pairs(defs.mappings) do
		for key_bind in pairs(defs.mappings[mode]) do
			local func = string.format(
				defs.mappings[mode][key_bind],
				defs.config.windows.picker.id,
				defs.config.windows.previewer.id
			)
			vim.api.nvim_buf_set_keymap(defs.config.windows.picker.id, mode, key_bind, func, { silent = true })
		end
	end
end

M._display_buffers_by_tab = function()
	-- populate pickers window
	for tab_idx, _ in ipairs(buffers_by_tab) do
		local line = { " " .. tostring(tab_idx) .. " " }
		vim.api.nvim_buf_set_lines(defs.config.windows.picker.id, tab_idx - 1, -1, true, line)
	end
	M._load_preview(defs.config.windows.picker.id, defs.config.windows.previewer.id)
end

M._load_preview = function(pickernr, previewnr)
	local info = vim.fn.getpos(".")
	local curr_cursor_line = info[2]

	local lines = {}
	for _, buf_value in ipairs(buffers_by_tab[curr_cursor_line]) do
		local formatted_path = utils.format_path(vim.api.nvim_buf_get_name(buf_value))
		table.insert(lines, formatted_path)
	end
	vim.api.nvim_buf_set_lines(previewnr, 0, -1, true, lines)
end

M.reload_preview = function(pickernr, previewnr, direction)
	local info = vim.fn.getpos(".") -- get cursor position
	local curr_cursor_line = info[2]
	local next_line = curr_cursor_line + defs.config.directions[direction]

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
	defs.config.windows.picker.id = nil
	defs.config.windows.previewer.id = nil
end

M.debug = function()
	M._create_windows()
	M._set_mappings()
	M._display_buffers_by_tab()
end

M.close = function(pickernr, previewnr)
	M.clean()
	v.nvim_exec(string.format("%s,%sbw!", pickernr, previewnr), true)
end

M.select_tab = function(pickernr, previewnr)
	M.close(pickernr, previewnr)

	local info = vim.fn.getpos(".")
	local tab_num = info[2]
	vim.api.nvim_exec(":tabn" .. tab_num, true)
end

vim.api.nvim_set_keymap("n", "<Leader>a", ':lua require"tabu.init".debug()<CR>', { noremap = true, silent = true })

return M
