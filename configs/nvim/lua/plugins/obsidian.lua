vim.pack.add({
	{ src = "https://github.com/obsidian-nvim/obsidian.nvim", version = vim.version.range("*") },
})

local vault = vim.env.OBSIDIAN_VAULT or vim.fn.expand("~/Documents/vault")
if vim.fn.isdirectory(vault) == 0 then
	vim.notify("obsidian.nvim skipped: vault not found: " .. vault .. " (set $OBSIDIAN_VAULT)", vim.log.levels.WARN)
	return
end

require("obsidian").setup({
	legacy_commands = false,
	workspaces = {
		{
			name = "vault",
			path = vault,
		},
	},
	picker = {
		name = "snacks.picker",
	},
})
