vim.pack.add({ { src = "https://github.com/folke/flash.nvim" } })

require("flash").setup({
	modes = { search = { enabled = false }, char = { enabled = false } },
})
