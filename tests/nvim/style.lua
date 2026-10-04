local h = dofile("tests/nvim/helper.lua")
local render = require("plan.render")
local celebration = require("plan.celebration")
local function marks(ns)
  return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
end

h.run(function()
  h.open({ "[] First", "[] Second", "[x] Already done", "* Pointer", "inline []" })
  h.ready(1, 3)
  assert(#marks(celebration.namespace) == 0, "Opening a file must not celebrate old completions")
  local icons = {}
  for _, mark in ipairs(marks(render.namespace)) do
    if mark[4].conceal then
      icons[mark[2]] = mark[4].conceal
    end
  end
  assert(icons[0] == "○" and icons[2] == "✓", "Use the accomplishment ring/check style")
  local done = vim.api.nvim_get_hl(0, { name = "PlanDoneText", link = false })
  assert(
    done.bold and done.strikethrough and done.fg,
    "Completed titles need green bold strikethrough"
  )
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  h.keys("<CR>")
  h.ready(2, 3)
  h.wait(function()
    return #marks(celebration.namespace) == 1
  end, "Completion animation missing")
  assert(marks(celebration.namespace)[1][4].conceal == "✦", "First frame must match term-todos")
  h.wait(function()
    local current = marks(celebration.namespace)
    return #current == 1 and current[1][4].conceal == "✧"
  end, "Second animation frame missing")
  h.wait(function()
    return #marks(celebration.namespace) == 0
  end, "Animation must stop after 900 ms")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_buf_set_lines(0, 1, 2, false, { "[x] Second" })
  render.refresh(vim.api.nvim_get_current_buf())
  h.ready(3, 3)
  h.wait(function()
    return #marks(celebration.namespace) == 1
  end, "Typing [x] must celebrate too")
  h.keys("<CR>")
  h.ready(2, 3)
  h.wait(function()
    return #marks(celebration.namespace) == 0
  end, "Reopening a task must cancel animation")
  local deleted = vim.api.nvim_get_current_buf()
  h.keys("<CR>")
  h.ready(3, 3)
  vim.api.nvim_buf_delete(deleted, { force = true })
  vim.wait(1100, function()
    return false
  end, 20)
  assert(not vim.api.nvim_buf_is_valid(deleted), "Timers must tolerate wiped buffers")
  require("plan").setup({ icons = false, animation = false })
  h.open({ "[] Raw syntax" })
  h.ready(0, 1)
  for _, mark in ipairs(marks(render.namespace)) do
    assert(not mark[4].conceal, "Icons must be optional")
  end
  h.keys("<CR>")
  h.ready(1, 1)
  assert(#marks(celebration.namespace) == 0, "Animation must be optional")
end)
