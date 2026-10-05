vim.pack.add({ { src = "https://github.com/stevearc/conform.nvim" } })

local oxfmtFormatter = { "oxfmt", "prettierd", "prettier", stop_after_first = true }
require("conform").setup({
	default_format_opts = {
		timeout_ms = 3000,
		async = false,
		quiet = false,
		lsp_format = "fallback",
	},
	formatters_by_ft = {
		javascript = oxfmtFormatter,
		typescript = oxfmtFormatter,
		javascriptreact = oxfmtFormatter,
		typescriptreact = oxfmtFormatter,
		json = oxfmtFormatter,
		css = oxfmtFormatter,
		html = oxfmtFormatter,
		markdown = oxfmtFormatter,
		yaml = oxfmtFormatter,
		less = oxfmtFormatter,
		scss = oxfmtFormatter,
		["markdown.mdx"] = oxfmtFormatter,
		lua = { "stylua" },
		sh = { "shfmt" },
		fish = { "fish_indent" },
		c = { "clang-format" },
		cpp = { "clang-format" },
		rust = { "rustfmt" },
		go = { "goimports", "gofumpt" },
		python = { "ruff_format" },
	},
	formatters = {
		oxfmt = {

			require_cwd = true,
		},
	},
	format_on_save = function(bufnr)
		if vim.b[bufnr].disable_autoformat then
			return
		end
		return {
			timeout_ms = 500,
			lsp_fallback = true,
		}
	end,
})
