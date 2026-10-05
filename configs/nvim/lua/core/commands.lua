vim.api.nvim_create_user_command("ToggleFormatter", function()
	require("utils.editor").toggle_formatter()
end, { desc = "Toggle formatter for current buffer" })

vim.api.nvim_create_user_command("SkelC", function()
	require("tools.skeleton_c").insert()
end, { desc = "Insert a C header/source skeleton for the current file" })
