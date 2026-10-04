local h = dofile("tests/nvim/helper.lua")
local render = require("plan.render")
h.run(function()
  h.open({ "[] Keep me", "[x] Finished" })
  h.ready(1, 2)
  vim.bo.filetype = "text"
  assert(vim.wo.conceallevel == 0, "Changing filetype must restore window options")
  assert(vim.fn.maparg("<CR>", "n") == "", "Changing filetype must remove plan mappings")
  assert(vim.fn.exists(":PlanToggle") == 0, "Changing filetype must remove plan commands")
  assert(
    #vim.api.nvim_buf_get_extmarks(0, render.namespace, 0, -1, {}) == 0,
    "Changing filetype must remove decorations"
  )
  vim.bo.filetype = "plan"
  h.ready(1, 2)
  assert(vim.fn.exists(":PlanToggle") == 2, "Reattaching must restore plan commands")
  vim.bo.readonly = true
  h.keys("<CR>")
  assert(vim.api.nvim_get_current_line() == "[] Keep me", "Readonly files must not be toggled")
  vim.bo.readonly = false
  require("plan").setup({ binary = "/missing/plan-nvim" })
  h.keys("<CR>")
  assert(vim.api.nvim_get_current_line() == "[] Keep me", "A missing engine must not corrupt tasks")
  require("plan.config").options.binary = nil
  h.keys("<CR>")
  h.ready(2, 2)
  local undo = vim.bo.undolevels
  assert(undo ~= -1, "Plugin must preserve undo history")
end)
