local api = vim.api

local augroup = api.nvim_create_augroup("userConfig", {})

api.nvim_create_autocmd("InsertLeave", {
  group = augroup,
  pattern = "*",
  command  = "set nopaste",
})

api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = { "*.h", "*.c" },
  callback = function(args)
    require("tools.include_formatter").format(args.buf)
  end,
})
