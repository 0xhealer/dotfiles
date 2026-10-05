vim.pack.add({
	{ src = "https://github.com/neovim/nvim-lspconfig" },
	{ src = "https://github.com/mason-org/mason.nvim" },
	{ src = "https://github.com/mason-org/mason-lspconfig.nvim" },
	{ src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
})

require("mason").setup()

require("mason-lspconfig").setup({
	ensure_installed = {
		"eslint",
		"oxlint",
		"lua_ls",
		"cssls",
		"html",
		"vtsls",
		"tailwindcss",
		"rust_analyzer",
		"clangd",
		"basedpyright",
		"ruff",
		"gopls",
		"marksman",
		"bashls",
		"jsonls",
		"yamlls",
		"dockerls",
		"jdtls",
		"phpactor",
		"omnisharp",
		"solargraph",
		"powershell_es",
	},
})

require("mason-tool-installer").setup({
	ensure_installed = {
		"prettier",
		"prettierd",
		"selene",
		"shellcheck",
		"shfmt",
		"stylua",
		"oxfmt",
		"clang-format",

		"goimports",
		"gofumpt",
	},
	auto_update = false,
	run_on_start = true,
})

local capabilities = {
	workspace = {
		fileOperations = {
			didRename = true,
			willRename = true,
		},
	},
}
vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(capabilities),
})

vim.lsp.enable({ "glsl_analyzer" })
