local set = vim.opt_local
local keymap = vim.keymap.set

set.expandtab = true
set.tabstop = 2
set.shiuftwidth = 2

keymap("n","<leader>td",function()
  require("dap-go").debug_test()
end, {buffer = 0})

