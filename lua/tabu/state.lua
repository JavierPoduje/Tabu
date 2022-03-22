local M = {}

local buffers_by_tabs = {}

return setmetatable(M, {
	__index = function(_, k)
		return buffers_by_tabs[k]
	end,
})

