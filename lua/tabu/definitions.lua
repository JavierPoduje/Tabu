local M = {}

local definitions = {
	mappings = {
		n = {
			["<Esc>"] = ':lua require("tabu.init").close(%s, %s)<CR>',
			["<CR>"] = ':lua require("tabu.init").select_tab(%s, %s)<CR>',
			["j"] = ':lua require("tabu.init").reload_preview(%s, %s, "DOWN")<CR>',
			["k"] = ':lua require("tabu.init").reload_preview(%s, %s, "UP")<CR>',
		},
	},
	config = {
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
	},
  pattern_to_ignore = {
    "NvimTree"
  }
}

return setmetatable(M, {
	__index = function(_, k)
		return definitions[k]
	end,
})

