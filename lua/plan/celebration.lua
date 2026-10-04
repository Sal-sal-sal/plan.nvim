local config = require("plan.config")
local M = { namespace = vim.api.nvim_create_namespace("plan.celebration") }
local active = {}

function M.clear(buf)
  active[buf] = nil
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
  end
end

function M.start(buf, row, marker_end)
  if not config.options.animation then
    return
  end
  active[buf] = active[buf] or {}
  local previous = active[buf][row]
  if previous and previous.mark then
    vim.api.nvim_buf_del_extmark(buf, M.namespace, previous.mark)
  end
  local token = {}
  active[buf][row] = token
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local started = vim.uv.hrtime()
  local mark
  local function frame()
    if not vim.api.nvim_buf_is_valid(buf) or not active[buf] or active[buf][row] ~= token then
      return
    end
    local elapsed = (vim.uv.hrtime() - started) / 1000000
    if
      elapsed >= 900
      or vim.api.nvim_buf_get_changedtick(buf) ~= tick
      or vim.bo[buf].filetype ~= "plan"
    then
      if mark then
        vim.api.nvim_buf_del_extmark(buf, M.namespace, mark)
      end
      active[buf][row] = nil
      return
    end
    local symbol = math.floor(elapsed / 150) % 2 == 0 and "✦" or "✧"
    local options = { id = mark, end_col = marker_end, hl_group = "PlanDone", priority = 1000 }
    if config.options.icons then
      options.conceal = symbol
    else
      options.virt_text = { { " " .. symbol, "PlanDone" } }
    end
    mark = vim.api.nvim_buf_set_extmark(buf, M.namespace, row, 0, options)
    token.mark = mark
    vim.cmd.redraw()
    vim.defer_fn(frame, 150)
  end
  frame()
end

return M
