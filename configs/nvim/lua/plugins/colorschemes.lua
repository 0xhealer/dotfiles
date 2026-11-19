-- Rose Pine (Moon) is the only theme. Terminal, prompt, tmux, editor and desktop all use the same palette.
vim.o.background = "dark"

vim.pack.add({ { src = "https://github.com/rose-pine/neovim", name = "rose-pine" } })

require("rose-pine").setup({
	variant = "moon",
	dark_variant = "moon",
	dim_inactive_windows = false,
	extend_background_behind_borders = true,
	enable = {
		terminal = true,
		legacy_highlights = true,
		migrations = true,
	},
	styles = {
		bold = true,
		italic = true,
		transparency = true,
	},
})

vim.cmd([[colorscheme rose-pine-moon]])
