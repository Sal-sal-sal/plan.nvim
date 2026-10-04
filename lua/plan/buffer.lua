local actions = require("plan.actions")
local config = require("plan.config")
local render = require("plan.render")
local M = {}
local attached = {}

function M.detach(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  local state = attached[buf]
  if not state then
    return
  end
  attached[buf] = nil
  render.clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_call(buf, function()
      if state.conceal then
        vim.opt_local.conceallevel = state.conceal.level
        vim.opt_local.concealcursor = state.conceal.cursor
      end
      for _, mapping in ipairs(state.mappings) do
        local current = vim.fn.maparg(mapping.key, mapping.mode, false, true)
        if current.buffer == 1 and current.desc == mapping.desc then
          vim.keymap.del(mapping.mode, mapping.key, { buffer = buf })
          if mapping.before.buffer == 1 then
            vim.fn.mapset(mapping.mode, false, mapping.before)
          end
        end
      end
    end)
    for _, name in ipairs(state.commands) do
      pcall(vim.api.nvim_buf_del_user_command, buf, name)
    end
    vim.b[buf].did_plan_ftplugin = nil
  end
  vim.api.nvim_del_augroup_by_id(state.group)
end

function M.attach(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  if attached[buf] or vim.bo[buf].filetype ~= "plan" then
    return
  end
  local state = { mappings = {}, commands = {} }
  attached[buf] = state
  if config.options.icons then
    vim.api.nvim_buf_call(buf, function()
      state.conceal = { level = vim.wo.conceallevel, cursor = vim.wo.concealcursor }
      vim.opt_local.conceallevel = 2
      vim.opt_local.concealcursor = "nc"
    end)
  end
  local commands = {
    PlanToggle = actions.toggle,
    PlanStats = actions.stats,
    PlanNext = function()
      actions.navigate(1)
    end,
    PlanPrev = function()
      actions.navigate(-1)
    end,
  }
  for name, callback in pairs(commands) do
    vim.api.nvim_buf_create_user_command(buf, name, function()
      callback()
    end, {})
    state.commands[#state.commands + 1] = name
  end
  if config.options.mappings then
    local function map(mode, key, callback, desc, extra)
      local before
      vim.api.nvim_buf_call(buf, function()
        before = vim.fn.maparg(key, mode, false, true)
      end)
      state.mappings[#state.mappings + 1] = { mode = mode, key = key, desc = desc, before = before }
      vim.keymap.set(
        mode,
        key,
        callback,
        vim.tbl_extend("force", { buffer = buf, silent = true, desc = desc }, extra or {})
      )
    end
    map("n", "<CR>", function()
      actions.toggle(true)
    end, "Toggle plan task")
    map("i", "<CR>", actions.enter, "Continue plan list", { expr = true, replace_keycodes = true })
    map("n", "]t", function()
      actions.navigate(1)
    end, "Next pending task")
    map("n", "[t", function()
      actions.navigate(-1)
    end, "Previous pending task")
    map("n", "<leader>pt", actions.toggle, "Toggle plan task")
    map("n", "<leader>ps", actions.stats, "Plan statistics")
  end
  local group = vim.api.nvim_create_augroup("plan_buffer_" .. buf, { clear = true })
  state.group = group
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if attached[buf] ~= state then
        return true
      end
      render.schedule(buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
    group = group,
    buffer = buf,
    callback = function()
      render.schedule(buf)
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = buf,
    callback = function()
      render.focus(buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      M.detach(buf)
    end,
  })
  render.refresh(buf)
end

return M
