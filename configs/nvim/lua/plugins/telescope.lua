vim.pack.add({
	{ src = "https://github.com/nvim-lua/plenary.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope-fzf-native.nvim" },
})

vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if name == "telescope-fzf-native.nvim" and (kind == "install" or kind == "update") then
			if vim.fn.executable("make") == 1 then
				vim.system({ "make" }, { cwd = ev.data.path }):wait()
			end
		end
	end,
})

local actions = require("telescope.actions")

require("telescope").setup({
	defaults = {
		prompt_prefix = "   ",
		selection_caret = " ",
		sorting_strategy = "ascending",
		layout_config = { prompt_position = "top" },
		file_ignore_patterns = { "^%.git/", "node_modules/" },
		vimgrep_arguments = {
			"rg",
			"--color=never",
			"--no-heading",
			"--with-filename",
			"--line-number",
			"--column",
			"--smart-case",
			"--hidden",
			"--glob=!.git/",
		},
		mappings = {
			i = {
				["<C-j>"] = actions.move_selection_next,
				["<C-k>"] = actions.move_selection_previous,
				["<esc>"] = actions.close,
			},
		},
	},
	pickers = {
		find_files = { hidden = true },
		buffers = {
			sort_mru = true,
			ignore_current_buffer = true,
			mappings = { i = { ["<C-d>"] = actions.delete_buffer } },
		},
	},
})

pcall(require("telescope").load_extension, "fzf")
