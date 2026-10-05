local keymap = vim.keymap.set

local opts = { noremap = true, silent = true }

keymap("n", "x", '"_x', { desc = "Delete char (no yank)" })
keymap("n", "<Leader>p", '"0p', { desc = "Paste after (no yank)" })
keymap("n", "<Leader>P", '"0P', { desc = "Paste before (no yank)" })
keymap("v", "<Leader>p", '"0p', { desc = "Paste over selection (no yank)" })
keymap("n", "<Leader>c", '"_c', { desc = "Change (no yank)" })
keymap("n", "<Leader>C", '"_C', { desc = "Change to end of line (no yank)" })
keymap("v", "<Leader>c", '"_c', { desc = "Change selection (no yank)" })
keymap("v", "<Leader>C", '"_C', { desc = "Change to end of line (no yank)" })
keymap("n", "<Leader>d", '"_d', { desc = "Delete (no yank)" })
keymap("n", "<Leader>D", '"_D', { desc = "Delete to end of line (no yank)" })
keymap("v", "<Leader>d", '"_d', { desc = "Delete selection (no yank)" })
keymap("v", "<Leader>D", '"_D', { desc = "Delete to end of line (no yank)" })

keymap("n", "+", "<C-a>", { desc = "Increment number" })
keymap("n", "-", "<C-x>", { desc = "Decrement number" })

keymap("n", "dw", 'vb"_d', { desc = "Delete word backwards (no yank)" })
keymap("n", "dW", "dw", { noremap = true, silent = true, desc = "Delete word forward (vanilla dw)" })

keymap("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

keymap("n", "<Leader>o", "o<Esc>^Da", vim.tbl_extend("force", opts, { desc = "New line below (no comment continuation)" }))
keymap("n", "<Leader>O", "O<Esc>^Da", vim.tbl_extend("force", opts, { desc = "New line above (no comment continuation)" }))

keymap("n", "<C-m>", "<C-i>", vim.tbl_extend("force", opts, { desc = "Jumplist forward" }))

keymap("n", "te", ":tabedit<CR>", { desc = "New tab" })
keymap("n", "<tab>", ":tabnext<CR>", vim.tbl_extend("force", opts, { desc = "Next tab" }))
keymap("n", "<s-tab>", ":tabprev<CR>", vim.tbl_extend("force", opts, { desc = "Previous tab" }))
keymap("n", "ss", ":split<Return>", vim.tbl_extend("force", opts, { desc = "Split window horizontally" }))
keymap("n", "sv", ":vsplit<Return>", vim.tbl_extend("force", opts, { desc = "Split window vertically" }))
keymap("n", "sh", "<C-w>h", { desc = "Move to left window" })
keymap("n", "sk", "<C-w>k", { desc = "Move to window above" })
keymap("n", "sj", "<C-w>j", { desc = "Move to window below" })
keymap("n", "sl", "<C-w>l", { desc = "Move to right window" })

keymap("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Move to window below" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Move to window above" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
keymap("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Move to left window" })
keymap("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Move to window below" })
keymap("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Move to window above" })
keymap("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Move to right window" })

local function save_file()
	if vim.fn.expand("%") == "" then
		vim.ui.input({ prompt = "Save as: " }, function(name)
			if name and name ~= "" then
				vim.cmd("write " .. vim.fn.fnameescape(name))
			end
		end)
	else
		vim.cmd("write")
	end
end

keymap("n", "<C-s>", save_file, vim.tbl_extend("force", opts, { desc = "Save file" }))
keymap("i", "<C-s>", function()
	vim.cmd("stopinsert")
	save_file()
end, vim.tbl_extend("force", opts, { desc = "Save file" }))

keymap("n", "<leader>q", ":q<CR>", vim.tbl_extend("force", opts, { desc = "Quit" }))
keymap("n", "<leader>wq", ":wq!<CR>", vim.tbl_extend("force", opts, { desc = "Force save and quit" }))

keymap("n", "<M-Down>", "<cmd>move .+1<cr>==", { silent = true, desc = "Move line down" })
keymap("n", "<M-Up>", "<cmd>move .-2<cr>==", { silent = true, desc = "Move line up" })
keymap("i", "<M-Down>", "<cmd>move .+1<cr><cmd>normal! ==<cr>", { silent = true, desc = "Move line down" })
keymap("i", "<M-Up>", "<cmd>move .-2<cr><cmd>normal! ==<cr>", { silent = true, desc = "Move line up" })
keymap("v", "<M-Down>", ":move '>+1<cr>gv=gv", { silent = true, desc = "Move selection down" })
keymap("v", "<M-Up>", ":move '<-2<cr>gv=gv", { silent = true, desc = "Move selection up" })

keymap("n", "<M-j>", "<cmd>move .+1<cr>==", { silent = true, desc = "Move line down" })
keymap("n", "<M-k>", "<cmd>move .-2<cr>==", { silent = true, desc = "Move line up" })
keymap("i", "<M-j>", "<cmd>move .+1<cr><cmd>normal! ==<cr>", { silent = true, desc = "Move line down" })
keymap("i", "<M-k>", "<cmd>move .-2<cr><cmd>normal! ==<cr>", { silent = true, desc = "Move line up" })
keymap("v", "<M-j>", ":move '>+1<cr>gv=gv", { silent = true, desc = "Move selection down" })
keymap("v", "<M-k>", ":move '<-2<cr>gv=gv", { silent = true, desc = "Move selection up" })
keymap("n", "<M-S-Down>", "<cmd>copy .<cr>", { silent = true, desc = "Duplicate line down" })
keymap("n", "<M-S-Up>", "<cmd>copy .-1<cr>", { silent = true, desc = "Duplicate line up" })
keymap("i", "<M-S-Down>", "<cmd>copy .<cr>", { silent = true, desc = "Duplicate line down" })
keymap("i", "<M-S-Up>", "<cmd>copy .-1<cr>", { silent = true, desc = "Duplicate line up" })
keymap("v", "<M-S-Down>", ":copy '><cr>gv", { silent = true, desc = "Duplicate selection down" })
keymap("v", "<M-S-Up>", ":copy '<-1<cr>gv", { silent = true, desc = "Duplicate selection up" })

keymap({ "n", "t" }, "<C-t>", function()
	require("snacks").terminal.toggle()
end, { silent = true, desc = "Toggle terminal (VSCode Ctrl+T)" })
keymap("n", "<leader>e", function()
	require("oil").open_float(nil, { preview = {} })
end, { silent = true, desc = "Explorer (VSCode Ctrl+Shift+E)" })
keymap("n", "<leader>[", "zc", { desc = "Fold (VSCode Ctrl+Alt+[)" })
keymap("n", "<leader>]", "zo", { desc = "Unfold (VSCode Ctrl+Alt+])" })
keymap("n", "<leader>{", "zM", { desc = "Fold all (VSCode Ctrl+Shift+Alt+[)" })
keymap("n", "<leader>}", "zR", { desc = "Unfold all (VSCode Ctrl+Shift+Alt+])" })

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("MarkdownBold", { clear = true }),
	pattern = "markdown",
	callback = function(ev)
		keymap("x", "<C-b>", 'c**<C-r>"**<Esc>', { buffer = ev.buf, desc = "Bold selection" })
		keymap("n", "<C-b>", "i****<Esc>hi", { buffer = ev.buf, desc = "Insert bold" })
		keymap("i", "<C-b>", "****<Left><Left>", { buffer = ev.buf, desc = "Insert bold" })
	end,
})

keymap("n", "<leader>i", function() end, { desc = "Toggle inlay hints (not implemented)" })

keymap("n", "<leader>yf", function()
	require("utils.editor").yank_relative_path_with_line()
end, { desc = "Yank relative path with line number" })

keymap("n", "<leader>yp", function()
	require("utils.editor").yank_absolute_path_with_line()
end, { desc = "Yank absolute path with line number" })

keymap("v", "<leader>cb", ":<C-u>lua require('utils.editor').copy_as_codeblock()<CR>", { desc = "Copy selection as markdown codeblock" })

keymap("n", "<leader>j", function()
	require("utils.editor").open_package_json()
end, { desc = "Open package.json in floating window" })

keymap("n", "<leader>bd", function()
	require("utils.editor").delete_hidden_buffers()
end, { desc = "Delete hidden buffers" })

local map = function(keymaps)
	for _, keymap_entry in ipairs(keymaps) do
		local lhs = keymap_entry[1]
		local rhs = keymap_entry[2]
		local mode = keymap_entry.mode or "n"
		local kopts = {
			desc = keymap_entry.desc,
			silent = keymap_entry.silent ~= false,
			noremap = keymap_entry.noremap ~= false,
			expr = keymap_entry.expr,
			nowait = keymap_entry.nowait,
			buffer = keymap_entry.buffer,
		}
		keymap(mode, lhs, rhs, kopts)
	end
end

local Snacks = require("snacks")
local curated_colorschemes = {
	["rose-pine"] = true,
	["catppuccin"] = true,
	["tokyonight"] = true,
	["gruvbox"] = true,
	["kanagawa"] = true,
	["solarized-osaka"] = true,
	["horizon"] = true,
}
keymap("n", "<leader>uc", function()
	local items = vim.tbl_filter(function(item)
		return curated_colorschemes[item.text]
	end, require("snacks.picker.source.vim").colorschemes())
	Snacks.picker.pick({
		source = "colorschemes",
		items = items,
		format = "text",
		preview = "colorscheme",
		preset = "vertical",
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.schedule(function()
					vim.cmd("colorscheme " .. item.text)
				end)
			end
		end,
	})
end, { noremap = true, silent = true, desc = "Pick colorscheme (curated, live preview)" })

map({
	{
		"sf",
		function()
			require("oil").open_float(nil, { preview = {} })
		end,
		desc = "Toggle file explorer",
	},
})

map({
	{
		"gI",
		function()
			local clients = vim.lsp.get_clients({ bufnr = 0, name = "vtsls" })
			if #clients > 0 then
				local params = vim.lsp.util.make_position_params(0, "utf-16")
				clients[1]:request("workspace/executeCommand", {
					command = "typescript.goToSourceDefinition",
					arguments = { params.textDocument.uri, params.position },
				}, function(err, result)
					if err then
						vim.notify("goToSourceDefinition: " .. err.message, vim.log.levels.ERROR)
						return
					end
					if result and #result > 0 then
						vim.lsp.util.show_document(result[1], "utf-16", { focus = true })
					else
						vim.notify("No source definition found", vim.log.levels.INFO)
					end
				end, 0)
			else
				vim.lsp.buf.implementation()
			end
		end,
		desc = "Goto Source Definition / Implementation",
	},
	{
		"gd",
		function()
			Snacks.picker.lsp_definitions({ jump = { reuse_win = false } })
		end,
		desc = "LSP Goto Definition",
	},
	{ "gD", Snacks.picker.lsp_declarations, desc = "LSP Goto Declaration" },
	{ "gy", Snacks.picker.lsp_type_definitions, desc = "LSP Goto T[y]pe Definition" },
	{ "gr", Snacks.picker.lsp_references, desc = "LSP Goto Definition" },
	{ "K", vim.lsp.buf.hover, desc = "Hover" },
	{ "gK", vim.lsp.buf.signature_help, desc = "Signature Help" },
	{
		"<c-k>",
		vim.lsp.buf.signature_help,
		desc = "Signature Help",
		mode = "i",
	},
	{
		"]d",
		function()
			vim.diagnostic.jump({ count = 1, float = true })
		end,
		desc = "Jump to next diagnostic",
		mode = "n",
	},
	{
		"[d",
		function()
			vim.diagnostic.jump({ count = -1, float = true })
		end,
		desc = "Jump to previous diagnostic",
		mode = "n",
	},
	{
		"<leader>ca",
		vim.lsp.buf.code_action,
		desc = "Code Action",
		mode = { "n", "x" },
	},
	{
		"<leader>cc",
		vim.lsp.codelens.run,
		desc = "Run Codelens",
		mode = "n",
	},
	{ "<leader>cC", vim.lsp.codelens.refresh, desc = "Refresh & Display Codelens" },
	{ "<leader>cr", vim.lsp.buf.rename, desc = "Rename" },
	{
		"<leader>cf",
		function()
			require("conform").format()
		end,
		desc = "Format code",
		mode = { "n", "x" },
	},
})

map({
	{ "<leader>cl", Snacks.picker.lsp_config, desc = "Lsp Info" },
	{ "<leader>cR", Snacks.rename.rename_file, desc = "Rename File" },
	{ ";f", Snacks.picker.files, desc = "Find files" },
	{ ";r", Snacks.picker.grep, desc = "Live grep" },
	{ ";;", Snacks.picker.resume, desc = "Resume picker" },
	{
		"\\\\",
		function()
			Snacks.picker.buffers({
				confirm = function(picker, item)
					picker:close()
					if not item then
						return
					end

					vim.schedule(function()
						for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
							for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
								if vim.api.nvim_win_get_buf(win) == item.buf then
									vim.api.nvim_set_current_tabpage(tab)
									vim.api.nvim_set_current_win(win)
									return
								end
							end
						end
						vim.api.nvim_set_current_buf(item.buf)
					end)
				end,
			})
		end,
		desc = "List buffers",
	},
	{ ";e", Snacks.picker.diagnostics, desc = "Diagnostics" },
	{ ";c", Snacks.picker.lsp_incoming_calls, desc = "LSP incoming calls" },
	{ ";n", Snacks.picker.notifications, desc = "Notifications" },
	{
		";g",
		function()
			Snacks.lazygit.open()
		end,
		desc = "Lazygit",
	},
	{
		"]]",
		function()
			Snacks.words.jump(vim.v.count1)
		end,
		desc = "Next Reference",
		mode = { "n", "t" },
	},
	{
		"[[",
		function()
			Snacks.words.jump(-vim.v.count1)
		end,
		desc = "Prev Reference",
		mode = { "n", "t" },
	},
})

map({
	{
		"]b",
		function()
			require("bufferline.commands").cycle(vim.v.count1)
		end,
		desc = "Next buffer",
	},
	{
		"[b",
		function()
			require("bufferline.commands").cycle(-vim.v.count1)
		end,
		desc = "Previous buffer",
	},
	{ "<leader>bc", "<cmd>BufferLinePickClose<cr>", desc = "Pick buffer to close" },
	{ "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin/unpin buffer" },
	{ "<leader>bb", "<cmd>BufferLinePick<cr>", desc = "Pick buffer to jump to" },
	{ "<leader>bn", "<cmd>enew<cr>", desc = "New empty buffer" },
	{ "<C-n>", "<cmd>enew<cr>", desc = "New empty buffer" },
})

map({
	{
		"<leader>tt",
		function()
			Snacks.terminal.toggle()
		end,
		desc = "Toggle terminal",
		mode = { "n", "t" },
	},
})

map({
	{
		"<leader>gb",
		function()
			require("gitsigns").blame_line()
		end,
		desc = "Blame current line",
	},
	{
		"<leader>gB",
		function()
			require("gitsigns").blame()
		end,
		desc = "Blame buffer",
	},
	{
		"<leader>go",
		function()
			local async = require("gitsigns.async")
			local cache = require("gitsigns.cache").cache

			async.run(function()
				local bufnr = vim.api.nvim_get_current_buf()
				local lnum = vim.api.nvim_win_get_cursor(0)[1]
				local bcache = cache[bufnr]
				if not bcache then
					return
				end

				bcache:get_blame(lnum)
				local blame = bcache.blame
				if not blame or not blame.entries or not blame.entries[lnum] then
					return
				end

				local info = blame.entries[lnum]
				local sha = info.commit.sha

				if tonumber("0x" .. sha:sub(1, 8)) == 0 then
					vim.notify("Line not committed yet", vim.log.levels.WARN)
					return
				end

				vim.cmd.tabnew()
				require("gitsigns.actions.diffthis").show(bufnr, sha, info.filename)
				async.schedule()
				pcall(vim.api.nvim_win_set_cursor, 0, { info.orig_lnum or lnum, 0 })
			end)
		end,
		desc = "Open file from blamed commit",
	},
	{
		"<leader>gd",
		function()
			local MiniDiff = require("mini.diff")
			MiniDiff.toggle_overlay()
		end,
	},
})

map({
	{ "<leader>dv", "<cmd>CodeDiff<cr>", desc = "Toggle CodeDiff" },
	{ "<leader>dh", "<cmd>CodeDiff history %<cr>", desc = "File history (current file)" },
	{ "<leader>dH", "<cmd>CodeDiff history<cr>", desc = "File history (repo)" },
})

local mc = require("multicursor-nvim")

keymap({ "n", "x" }, "<c-up>", function()
	mc.lineAddCursor(-1)
end, { desc = "Add cursor above" })
keymap({ "n", "x" }, "<c-down>", function()
	mc.lineAddCursor(1)
end, { desc = "Add cursor below" })
keymap({ "n", "x" }, "<leader><up>", function()
	mc.lineSkipCursor(-1)
end, { desc = "Skip line, add cursor above" })
keymap({ "n", "x" }, "<leader><down>", function()
	mc.lineSkipCursor(1)
end, { desc = "Skip line, add cursor below" })

keymap({ "n", "x" }, "<leader>n", function()
	mc.matchAddCursor(1)
end, { desc = "Add cursor on next match" })
keymap({ "n", "x" }, "<leader>N", function()
	mc.matchAddCursor(-1)
end, { desc = "Add cursor on previous match" })
keymap({ "n", "x" }, "<leader>s", function()
	mc.matchSkipCursor(1)
end, { desc = "Skip match, find next" })
keymap({ "n", "x" }, "<leader>S", function()
	mc.matchSkipCursor(-1)
end, { desc = "Skip match, find previous" })

keymap("n", "<c-leftmouse>", mc.handleMouse)
keymap("n", "<c-leftdrag>", mc.handleMouseDrag)
keymap("n", "<c-leftrelease>", mc.handleMouseRelease)

mc.addKeymapLayer(function(layerSet)
	layerSet({ "n", "x" }, "<left>", mc.prevCursor)
	layerSet({ "n", "x" }, "<right>", mc.nextCursor)
	layerSet({ "n", "x" }, "<leader>x", mc.deleteCursor)
	layerSet("n", "<esc>", function()
		if not mc.cursorsEnabled() then
			mc.enableCursors()
		else
			mc.clearCursors()
		end
	end)
end)

keymap({ "n", "x", "o" }, "gs", function()
	require("flash").jump()
end, { desc = "Flash jump" })
keymap({ "n", "x", "o" }, "gS", function()
	require("flash").treesitter()
end, { desc = "Flash treesitter select" })
keymap({ "n", "x" }, "<leader>R", function()
	require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
end, { desc = "Search and replace (grug-far)" })
map({
	{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
	{ "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics (Trouble)" },
	{ "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Location list (Trouble)" },
	{ "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list (Trouble)" },
})

keymap("n", "<leader>?", function()
	require("which-key").show({ global = true })
end, { noremap = true, silent = true, desc = "Show all keybindings (which-key)" })

local function tb(name, opts)
	return function()
		require("telescope.builtin")[name](opts or {})
	end
end
map({
	{ "<leader>ff", tb("find_files"), desc = "Find files" },
	{ "<leader>fg", tb("live_grep"), desc = "Live grep" },
	{ "<leader>fw", tb("grep_string"), desc = "Grep word under cursor", mode = { "n", "x" } },
	{ "<leader>fb", tb("buffers"), desc = "Buffers" },
	{ "<leader>fr", tb("oldfiles"), desc = "Recent files" },
	{ "<leader>fR", tb("resume"), desc = "Resume last picker" },
	{ "<leader>fc", tb("find_files", { cwd = vim.fn.stdpath("config") }), desc = "Find config file" },
	{ "<leader>fG", tb("git_files"), desc = "Git files" },
	{ "<leader>fh", tb("help_tags"), desc = "Help tags" },
	{ "<leader>fk", tb("keymaps"), desc = "Keymaps" },
	{ "<leader>fm", tb("marks"), desc = "Marks" },
	{ "<leader>fj", tb("jumplist"), desc = "Jumplist" },
	{ "<leader>f:", tb("command_history"), desc = "Command history" },
	{ "<leader>f/", tb("current_buffer_fuzzy_find"), desc = "Fuzzy find in buffer" },
	{ "<leader>fd", tb("diagnostics"), desc = "Diagnostics" },
	{ "<leader>fs", tb("lsp_document_symbols"), desc = "Document symbols" },
	{ "<leader>fS", tb("lsp_dynamic_workspace_symbols"), desc = "Workspace symbols" },
	{ "<leader>fC", tb("colorscheme", { enable_preview = true }), desc = "Colorschemes" },
	{ "<leader>fo", tb("vim_options"), desc = "Options" },
	{ "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Todo comments" },
	{ "<leader>gc", tb("git_commits"), desc = "Git commits" },
	{ "<leader>gs", tb("git_status"), desc = "Git status" },
})

keymap("n", "<leader>vh", function()
	vim.cmd("edit " .. vim.fn.fnameescape(tostring(Obsidian.dir) .. "/Home.md"))
end, { desc = "Open Obsidian vault home" })

keymap("n", "<leader>vf", "<cmd>Obsidian quick_switch<cr>", { desc = "Find note in vault (Snacks picker)" })
