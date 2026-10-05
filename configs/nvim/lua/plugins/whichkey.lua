vim.pack.add({ { src = "https://github.com/folke/which-key.nvim" } })

require("which-key").setup({
	preset = "modern",
	delay = 200,
	win = {
		no_overlap = false,
		width = 0.8,
		height = { min = 10, max = 0.7 },
		col = 0.5,
		row = 0.5,
		border = "rounded",
		padding = { 1, 2 },
		title = true,
		title_pos = "center",
	},
	layout = { width = { min = 28 }, spacing = 4 },
	sort = { "local", "order", "group", "alphanum", "mod" },
	expand = 1,
	show_help = true,
})

require("which-key").add({
	{ "<leader>b", group = "Buffers" },
	{ "<leader>c", group = "Code" },
	{ "<leader>d", group = "Diff" },
	{ "<leader>f", group = "Find (Telescope)" },
	{ "<leader>g", group = "Git" },
	{ "<leader>t", group = "Terminal" },
	{ "<leader>u", group = "UI" },
	{ "<leader>x", group = "Trouble" },
	{ "<leader>y", group = "Yank path" },
	{ "s", group = "Split / Window" },
	{ ";", group = "Find (Snacks)" },
})
