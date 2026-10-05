local icons = require("utils.icons")

vim.pack.add({ { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("^1") } })

---@module 'blink.cmp'
---@type blink.cmp.Config
require("blink.cmp").setup({
	snippets = {
		preset = "default",
	},
	completion = {
		accept = {
			auto_brackets = {
				enabled = true,
			},
		},
		menu = {
			border = "none",
			draw = {
				treesitter = { "lsp" },
			},
		},
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 200,
		},
		ghost_text = {

			enabled = vim.g.ai_cmp,
		},
	},

	cmdline = {
		enabled = true,
		keymap = {
			preset = "cmdline",
			["<Right>"] = false,
			["<Left>"] = false,

			["<Down>"] = { "select_next", "fallback" },
			["<Up>"] = { "select_prev", "fallback" },
		},
		completion = {
			list = { selection = { preselect = false } },
			menu = {
				auto_show = function(ctx)
					return vim.fn.getcmdtype() == ":"
				end,
			},
			ghost_text = { enabled = true },
		},
	},

	keymap = {
		preset = "enter",
		["<C-y>"] = { "select_and_accept" },

		["<Down>"] = { "select_next", "fallback" },
		["<Up>"] = { "select_prev", "fallback" },
	},

	appearance = {
		kind_icons = icons.kinds,
	},
})
