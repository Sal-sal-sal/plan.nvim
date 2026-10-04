local M = {}

function M.check()
  vim.health.start("plan.nvim")
  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10+ available")
  else
    vim.health.error("Neovim 0.10+ is required")
  end
  local path = require("plan.backend").path()
  if path ~= "" and vim.fn.executable(path) == 1 then
    local result = vim.system({ path, "--version" }, { text = true }):wait(2000)
    if result.code == 0 then
      vim.health.ok(vim.trim(result.stdout) .. " at " .. path)
    else
      vim.health.error("Rust engine could not start", { result.stderr })
    end
  else
    vim.health.error("Rust engine missing", { "Run :PlanBuild or configure opts.binary." })
  end
  if vim.fn.executable("cargo") == 1 then
    vim.health.ok("Cargo available for source builds")
  else
    vim.health.info("Cargo is optional when using a release binary")
  end
end

return M
