local h = dofile("tests/nvim/helper.lua")
local namespace = require("plan.celebration").namespace
local function count()
  return #vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {})
end
h.run(function()
  h.open({ "[] Repeat" })
  h.ready(0, 1)
  h.keys("<CR>")
  h.ready(1, 1)
  h.wait(function()
    return count() == 1
  end)
  h.keys("<CR>")
  h.ready(0, 1)
  h.keys("<CR>")
  h.ready(1, 1)
  assert(count() <= 1, "Rapid completion must not leave overlapping animation marks")
  h.wait(function()
    return count() == 0
  end, "Rapid completion must clear every animation mark")
end)
