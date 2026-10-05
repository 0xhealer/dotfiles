vim.pack.add({ { src = "https://github.com/folke/snacks.nvim" } })

require("snacks").setup({
	indent = { enabled = true },
	scroll = { enabled = false },
	picker = {
		enabled = true,
		sources = {
			files = { hidden = true },
			grep = { hidden = true },
		},
	},
	notifier = { enabled = true },
	statuscolumn = { enabled = true },
	words = { enabled = true },
	terminal = { enabled = true },
	lazygit = {
		enabled = true,
		configure = true,
		theme = {
			activeBorderColor = { fg = "WarningMsg", bold = true },
		},
	},
})
