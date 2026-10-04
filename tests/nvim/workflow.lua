local h = dofile("tests/nvim/helper.lua")
h.run(function()
  local path = h.open({
    "# Today",
    "[] Learn Қазақша 🚀",
    "* Remember",
    "inline [] stays",
    "[] Next",
    "[x] Finished",
  })
  assert(vim.bo.filetype == "plan")
  h.ready(1, 3)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  h.keys("<CR>")
  assert(
    vim.api.nvim_get_current_line() == "[x] Learn Қазақша 🚀",
    "Enter must complete a task"
  )
  h.ready(2, 3)
  h.keys("u")
  assert(
    vim.api.nvim_get_current_line() == "[] Learn Қазақша 🚀",
    "Undo must restore the task"
  )
  h.ready(1, 3)
  h.keys("<C-r>")
  assert(
    vim.api.nvim_get_current_line() == "[x] Learn Қазақша 🚀",
    "Redo must complete again"
  )
  h.ready(2, 3)
  h.keys("<CR>")
  assert(
    vim.api.nvim_get_current_line() == "[] Learn Қазақша 🚀",
    "Enter must reopen a task"
  )
  h.ready(1, 3)
  h.keys("]t")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "Next must skip pointers and inline markers")
  h.keys("[t")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 2)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  h.keys("<CR>")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "Enter on ordinary text must move normally")
  assert(vim.api.nvim_buf_get_lines(0, 3, 4, false)[1] == "inline [] stays")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  h.keys("A<CR>New task<Esc>")
  assert(
    vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == "[] New task",
    "Insert Enter must continue a todo"
  )
  h.ready(1, 4)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  h.keys("A<CR>New pointer<Esc>")
  assert(
    vim.api.nvim_buf_get_lines(0, 4, 5, false)[1] == "* New pointer",
    "Insert Enter must continue a pointer"
  )
  vim.cmd.write()
  local saved = vim.fn.readfile(path)
  assert(saved[2] == "[] Learn Қазақша 🚀" and saved[3] == "[] New task")
  assert(not table.concat(saved, "\n"):find("✦"), "Animation must never enter the saved file")
  h.open({ "[] " })
  h.ready(0, 1)
  h.keys("A<CR>Plain text<Esc>")
  assert(vim.api.nvim_get_current_line() == "Plain text", "An empty list item must exit the list")
  local normal = h.open({ "[] is plain here" }, ".txt")
  assert(vim.bo.filetype ~= "plan")
  assert(vim.fn.maparg("<CR>", "n") == "", "Plan mappings must stay buffer-local")
  assert(vim.fn.readfile(normal)[1] == "[] is plain here")
end)
