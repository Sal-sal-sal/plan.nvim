local M = {}
local paths = {}

function M.open(lines, extension)
  local path = vim.fn.tempname() .. (extension or ".plan")
  paths[#paths + 1] = path
  vim.fn.writefile(lines, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return path
end

function M.wait(predicate, message)
  assert(vim.wait(3000, predicate, 10), message or "Timed out")
end

function M.ready(done, total)
  M.wait(function()
    local stats = vim.b.plan_stats
    return stats and stats.done == done and stats.total == total
  end, "Statistics did not update")
end

function M.keys(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

function M.run(test)
  local ok, error = xpcall(test, debug.traceback)
  for _, path in ipairs(paths) do
    vim.fn.delete(path)
  end
  if not ok then
    io.stderr:write(error .. "\n")
    vim.cmd("cquit 1")
  end
  print("PASS: " .. vim.fn.expand("<sfile>"))
  vim.cmd("qa!")
end

return M
