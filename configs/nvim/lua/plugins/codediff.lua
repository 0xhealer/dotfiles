vim.pack.add({ { src = "https://github.com/esmuellert/codediff.nvim" } })

require("codediff").setup({
	explorer = {
		auto_open_on_cursor = true,
		view_mode = "tree",
	},
	keymaps = {
		view = {
			toggle_stage = "<Space>",
		},
	},
})
