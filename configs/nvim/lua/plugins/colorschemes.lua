vim.o.background = "dark"

vim.pack.add({
	{ src = "https://github.com/rose-pine/neovim", name = "rose-pine" },
	{ src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
	{ src = "https://github.com/folke/tokyonight.nvim" },
	{ src = "https://github.com/ellisonleao/gruvbox.nvim" },
	{ src = "https://github.com/rebelot/kanagawa.nvim" },
	{ src = "https://github.com/craftzdog/solarized-osaka.nvim" },
	{ src = "https://github.com/akinsho/horizon.nvim" },
})

require("rose-pine").setup({

	variant = "main",
	dark_variant = "main",
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

require("catppuccin").setup({
	flavour = "mocha",
	transparent_background = true,
})

require("tokyonight").setup({
	style = "night",
	transparent = true,
})

require("gruvbox").setup({
	transparent_mode = true,
})

require("kanagawa").setup({
	transparent = true,

})

require("solarized-osaka").setup({
	style = "vivid",
	transparent = true,
	styles = {
		sidebars = "transparent",
		floats = "transparent",
	},
	sidebars = {
		"qf",
		"vista_kind",
		"terminal",
		"spectre_panel",
		"startuptime",
		"Outline",
	},
})

require("horizon").setup({
	plugins = {
		bufferline = true,
		gitsigns = true,
		whichkey = true,
	},
})

vim.cmd([[colorscheme catppuccin-mocha]])
