local backend = require("plan.backend")
local config = require("plan.config")
local celebration = require("plan.celebration")
local M = { namespace = vim.api.nvim_create_namespace("plan.nvim") }
local revisions = {}
local snapshots = {}
local focus_ns = vim.api.nvim_create_namespace("plan.focus")
local groups =
  { todo = "PlanTodo", done = "PlanDone", pointer = "PlanPointer", heading = "PlanHeading" }

function M.highlights()
  vim.api.nvim_set_hl(0, "PlanTodo", { default = true, fg = "#f9e2af", ctermfg = 3 })
  vim.api.nvim_set_hl(0, "PlanTodoText", { default = true, bold = true })
  vim.api.nvim_set_hl(0, "PlanDone", { default = true, fg = "#a6e3a1", ctermfg = 10, bold = true })
  vim.api.nvim_set_hl(
    0,
    "PlanDoneText",
    { default = true, fg = "#a6e3a1", ctermfg = 10, bold = true, strikethrough = true }
  )
  vim.api.nvim_set_hl(0, "PlanDoneFocus", { default = true, bg = "#183c27" })
  vim.api.nvim_set_hl(0, "PlanPointer", { default = true, link = "Special" })
  vim.api.nvim_set_hl(
    0,
    "PlanHeading",
    { default = true, fg = "#f9e2af", ctermfg = 3, bold = true }
  )
end

function M.focus(buf)
  vim.api.nvim_buf_clear_namespace(buf, focus_ns, 0, -1)
  if vim.api.nvim_get_current_buf() ~= buf then
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local item = (vim.b[buf].plan_items or {})[row + 1]
  if item and item.kind == "done" then
    vim.api.nvim_buf_set_extmark(
      buf,
      focus_ns,
      row,
      0,
      { line_hl_group = "PlanDoneFocus", priority = 50 }
    )
  end
end

local function paint(buf, item)
  local group = groups[item.kind]
  if not group then
    return
  end
  local task = item.kind == "todo" or item.kind == "done"
  local length = item.kind == "heading" and item.length or item.marker_end
  local options = { end_col = length, hl_group = group, priority = 200 }
  if task and config.options.icons then
    options.conceal = item.kind == "done" and "✓" or "○"
  end
  vim.api.nvim_buf_set_extmark(buf, M.namespace, item.row, 0, options)
  if task and item.length > item.marker_end then
    vim.api.nvim_buf_set_extmark(buf, M.namespace, item.row, item.marker_end, {
      end_col = item.length,
      hl_group = item.kind == "done" and "PlanDoneText" or "PlanTodoText",
    })
  end
end

local function celebrate_changes(buf, items, lines)
  local previous = snapshots[buf]
  if previous and #previous.lines == #lines then
    for index, item in ipairs(items) do
      local before = previous.items[index]
      if
        item.kind == "done"
        and before.kind == "todo"
        and previous.lines[index]:sub(before.marker_end + 1)
          == lines[index]:sub(item.marker_end + 1)
      then
        celebration.start(buf, item.row, item.marker_end)
      end
    end
  end
  snapshots[buf] = { items = items, lines = lines }
end

local function valid(buf, tick)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.api.nvim_buf_is_loaded(buf)
    and vim.bo[buf].filetype == "plan"
    and vim.api.nvim_buf_get_changedtick(buf) == tick
end

function M.refresh(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  backend.request({ action = "analyze", lines = lines }, function(response, error)
    if not valid(buf, tick) then
      return
    end
    if not response then
      if error then
        vim.notify("plan.nvim: " .. error, vim.log.levels.ERROR)
      end
      return
    end
    vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
    for _, item in ipairs(response.items) do
      paint(buf, item)
    end
    vim.b[buf].plan_stats = response.stats
    vim.b[buf].plan_items = response.items
    M.focus(buf)
    celebrate_changes(buf, response.items, lines)
    vim.api.nvim_exec_autocmds(
      "User",
      { pattern = "PlanUpdated", modeline = false, data = { buf = buf } }
    )
    vim.cmd.redrawstatus()
  end)
end

function M.schedule(buf)
  revisions[buf] = (revisions[buf] or 0) + 1
  local revision = revisions[buf]
  vim.defer_fn(function()
    if revisions[buf] == revision then
      M.refresh(buf)
    end
  end, config.options.debounce)
end

function M.clear(buf)
  revisions[buf] = nil
  snapshots[buf] = nil
  celebration.clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, focus_ns, 0, -1)
    vim.b[buf].plan_stats = nil
    vim.b[buf].plan_items = nil
  end
end

return M
