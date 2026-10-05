local icons = require("utils.icons")

local function apply_transparency()
	local groups = {
		"Normal",
		"NormalNC",
		"NormalFloat",
		"FloatBorder",
		"FloatTitle",
		"SignColumn",
		"LineNr",
		"CursorLineNr",
		"EndOfBuffer",
		"TabLine",
		"TabLineFill",
		"TabLineSel",
		"WinSeparator",
		"VertSplit",
		"Pmenu",
		"PmenuSel",
		"PmenuSbar",
		"PmenuThumb",
		"WhichKeyFloat",
		"WhichKeyNormal",
		"InclineNormal",
		"InclineNormalNC",
	}
	for _, group in ipairs(groups) do
		vim.api.nvim_set_hl(0, group, { bg = "none" })
	end
end

apply_transparency()
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = apply_transparency,
})

vim.diagnostic.config({
	underline = true,

	update_in_insert = true,
	virtual_text = {
		spacing = 4,
		source = "if_many",
		prefix = "●",
		format = function(diagnostic)
			return string.format("%s (%s: %s)", diagnostic.message, diagnostic.source, diagnostic.code)
		end,
	},
	severity_sort = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
			[vim.diagnostic.severity.WARN] = icons.diagnostics.Warn,
			[vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
			[vim.diagnostic.severity.INFO] = icons.diagnostics.Info,
		},
	},
})
