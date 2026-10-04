local M = {}
local source = debug.getinfo(1, "S").source:sub(2)
M.root = vim.fn.fnamemodify(source, ":p:h:h:h")
M.options = { mappings = true, debounce = 100, binary = nil, icons = true, animation = true }

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", M.options, options or {})
end

return M
