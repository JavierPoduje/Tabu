local popup = require("plenary.popup")
local utils = require("tabu.utils")

local M = {}

M.mappings = {
	n = {
		["<Esc>"] = ':lua require("tabu").close(%s, %s)<CR>',
		["<CR>"] = ':lua require("tabu").select_tab(%s, %s)<CR>', -- TODO
		["d"] = ':lua require("tabu").delete_tab(%s, %s)<CR>', -- TODO
		["j"] = ':lua require("tabu").reload_preview(%s, %s, "DOWN")<CR>',
		["k"] = ':lua require("tabu").reload_preview(%s, %s, "UP")<CR>',
	},
}

local config = {
	windows = {
		picker = {
			id = nil,
			width = 3,
		},
		previewer = {
			id = nil,
			width = 80,
		},
	},
	height = 25,
	borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
	directions = {
		UP = -1,
		DOWN = 1,
	},
}

M.buffers_by_tab = {}

M.clean = function()
  config.windows.picker.id = nil
  config.windows.previewer.id = nil
  M.buffers_by_tab = {}
end

M.create_windows = function()
	local pickers_bufnr = v.nvim_create_buf(false, false)
	local preview_bufnr = v.nvim_create_buf(false, false)

	local total_width = config.windows.picker.width + config.windows.previewer.width

	popup.create(pickers_bufnr, {
		border = {},
		title = false,
		highlight = "PickersHighlight",
		borderhighlight = "PickersBorder",
		enter = true,
		line = math.floor(((vim.o.lines - config.height) / 2) - 1),
		col = math.floor((vim.o.columns - total_width) / 2),
		minwidth = config.windows.picker.width,
		minheight = config.height,
		borderchars = config.borderchars,
	}, false)
	popup.create(preview_bufnr, {
		border = {},
		title = "~~ Tabú ~~",
		highlight = "PreviewHighlight",
		borderhighlight = "PreviewBorder",
		enter = false,
		line = math.floor(((vim.o.lines - config.height) / 2) - 1),
		col = math.floor(((vim.o.columns - total_width) + config.windows.picker.width + 6) / 2),
		minwidth = config.windows.previewer.width,
		minheight = config.height,
		borderchars = config.borderchars,
	}, false)

	config.windows.picker.id = pickers_bufnr
	config.windows.previewer.id = preview_bufnr
	M.set_mappings()
end

M.populate_buffers_by_tab = function()
	local tabnrs = vim.api.nvim_list_tabpages()
	for tab_idx, tab_nr in ipairs(tabnrs) do
		-- populate a table with the buffers posibilities by tabs
		M.buffers_by_tab[tab_idx] = {}

		local windownrs = vim.api.nvim_tabpage_list_wins(tab_nr)
		for win_nr, win_id in ipairs(windownrs) do
			local bufnr = vim.api.nvim_win_get_buf(win_id)
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			-- exclude tab-manager's windows
			if bufnr ~= config.windows.picker.id and bufnr ~= config.windows.previewer.id and bufname ~= "" then
				table.insert(M.buffers_by_tab[tab_nr], bufnr)
			end
		end
	end
end

M.display_buffers_by_tab = function()
	-- populate pickers window
	for tab_idx, tab_nr in ipairs(M.buffers_by_tab) do
		local line = { " " .. tostring(tab_idx) .. " " }
		vim.api.nvim_buf_set_lines(config.windows.picker.id, tab_idx - 1, -1, true, line)
	end

	M.load_preview(config.windows.picker.id, config.windows.previewer.id)
end

M.set_mappings = function()
	for mode in pairs(M.mappings) do
		for key_bind in pairs(M.mappings[mode]) do
			local func = string.format(M.mappings[mode][key_bind], config.windows.picker.id, config.windows.previewer.id)
			vim.api.nvim_buf_set_keymap(config.windows.picker.id, mode, key_bind, func, { silent = true })
		end
	end
end

M.select_tab = function(pickernr, previewnr)
	local info = vim.fn.getpos(".") -- get cursor position
	local curr_cursor_line = info[2]
  print(curr_cursor_line)
end

M.load_preview = function(pickernr, previewnr)
	local info = vim.fn.getpos(".")
	local curr_cursor_line = info[2]

	local lines = {}
	for _, buf_value in ipairs(M.buffers_by_tab[curr_cursor_line]) do
		local formatted_path = utils.format_path(vim.api.nvim_buf_get_name(buf_value))
		table.insert(lines, formatted_path)
	end
	vim.api.nvim_buf_set_lines(previewnr, 0, -1, true, lines)
end

M.reload_preview = function(pickernr, previewnr, direction)
	local info = vim.fn.getpos(".") -- get cursor position
	local curr_cursor_line = info[2]
	local next_line = curr_cursor_line + config.directions[direction]

	local number_of_tabs = #vim.api.nvim_buf_get_lines(pickernr, 0, -1, false)

  -- If moving UP on the first line, set next_line to the last line,
  -- If moving Down on the last line, set next_line to the first line.
	if not (next_line > 0 and next_line <= number_of_tabs) then
    if next_line == 0 then
      next_line = number_of_tabs
    else
      next_line = 1
    end
	end

	vim.fn.setpos(".", { pickernr, next_line, 1, 1 })

	local new_lines = {}

  for _, buf_value in pairs(M.buffers_by_tab[next_line]) do
    local formatted_path = utils.format_path(vim.api.nvim_buf_get_name(buf_value))
    table.insert(new_lines, formatted_path)
  end
  vim.api.nvim_buf_set_lines(previewnr, 0, -1, true, new_lines)
end

M.close = function(pickernr, previewnr)
  M.clean()
	v.nvim_exec(string.format("%s,%sbw!", pickernr, previewnr), true)
end

M.run = function()
  M.create_windows()
  M.populate_buffers_by_tab()
  M.display_buffers_by_tab()
end

vim.api.nvim_set_keymap('n', '<Leader>a', ':lua require("tabu").run()<CR>', { noremap = true, silent = true })

return M

