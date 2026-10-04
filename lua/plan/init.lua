local M = {}
local configured = false

function M.setup(options)
  require("plan.config").setup(options)
  require("plan.render").highlights()
  vim.filetype.add({ extension = { plan = "plan" } })
  if not configured then
    configured = true
    local group = vim.api.nvim_create_augroup("plan.nvim", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "*",
      callback = function(event)
        if event.match == "plan" then
          M.attach(event.buf)
        else
          require("plan.buffer").detach(event.buf)
        end
      end,
    })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = function()
        require("plan.render").highlights()
      end,
    })
    vim.api.nvim_create_user_command(
      "PlanBuild",
      M.build,
      { desc = "Build the plan.nvim Rust engine" }
    )
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "plan" then
      M.attach(buf)
    end
  end
end

function M.attach(buf)
  if not configured then
    M.setup()
  end
  require("plan.buffer").attach(buf)
end

function M.build()
  require("plan.backend").build()
end

function M.status()
  local stats = vim.b.plan_stats
  return stats and ("Plan %d/%d"):format(stats.done, stats.total) or ""
end

return M
