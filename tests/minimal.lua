vim.opt.runtimepath:prepend(vim.env.PLAN_ROOT or vim.fn.getcwd())
vim.opt.termguicolors = true
vim.g.mapleader = " "
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.o.laststatus = 2
vim.o.statusline = " %f %m %= %{v:lua.require('plan').status()} "
vim.cmd("filetype plugin on")
require("plan").setup({ debounce = 10 })
