local backend = require("plan.backend")
local render = require("plan.render")
local M = {}

function M.toggle(fallback)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "plan" or not vim.bo[buf].modifiable or vim.bo[buf].readonly then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local response = backend.request({ action = "toggle", line = line })
  if not response then
    return
  end
  if not response.line then
    if fallback then
      vim.cmd.normal({ args = { "+" }, bang = true })
    else
      vim.notify("plan.nvim: place the cursor on a task beginning with [] or [x].")
    end
    return
  end
  vim.api.nvim_buf_set_lines(buf, cursor[1] - 1, cursor[1], false, { response.line })
  vim.api.nvim_win_set_cursor(
    0,
    { cursor[1], math.min(cursor[2], math.max(#response.line - 1, 0)) }
  )
  render.refresh(buf)
end

function M.enter()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local response = backend.request({
    action = "continue",
    line = vim.api.nvim_get_current_line(),
    column = cursor[2],
  })
  if response and response.clear then
    return "<C-u>"
  end
  return "<CR>" .. ((response and response.prefix) or "")
end

function M.stats()
  local response =
    backend.request({ action = "analyze", lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) })
  if response then
    local stats = response.stats
    vim.b.plan_stats = stats
    vim.notify(
      ("Plan: %d/%d done (%d%%), %d pending, %d pointers"):format(
        stats.done,
        stats.total,
        stats.percent,
        stats.pending,
        stats.pointers
      )
    )
  end
end

function M.navigate(direction)
  local response =
    backend.request({ action = "analyze", lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) })
  if not response then
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local target
  for _, item in ipairs(response.items) do
    if item.kind == "todo" and (item.row - row) * direction > 0 then
      if not target or (item.row - target) * direction < 0 then
        target = item.row
      end
    end
  end
  if target then
    vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
  end
end

return M
