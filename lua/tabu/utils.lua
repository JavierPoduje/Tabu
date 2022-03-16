local M = {}

M.string_to_table = function(str)
	local t = {}
	str:gsub(".", function(c)
		table.insert(t, c)
	end)
	return t
end

M.format_path = function (path)
  local dir = vim.fn.finddir('.git/..', ';')
  return path:gsub(dir, "")
end

return M

