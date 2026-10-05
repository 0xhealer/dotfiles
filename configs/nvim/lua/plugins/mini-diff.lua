vim.pack.add({ { src = "https://github.com/nvim-mini/mini.diff" } })

require("mini.diff").setup({
	view = {

		overlay_style = "hunk",
	},
	mappings = {

		goto_next = "]c",
		goto_prev = "[c",
	},
})
