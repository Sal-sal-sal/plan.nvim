if vim.b.did_plan_ftplugin then
  return
end
vim.b.did_plan_ftplugin = true
require("plan").attach(0)
