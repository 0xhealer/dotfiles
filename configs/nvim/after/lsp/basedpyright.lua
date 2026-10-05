---@type vim.lsp.Config
return {
	settings = {
		basedpyright = {
			analysis = {
				typeCheckingMode = "standard",
				autoImportCompletions = true,
			},
		},
	},
}
