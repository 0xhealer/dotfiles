local set = vim.opt

set.number = true
set.relativenumber = true
set.title = true
set.cursorline = false
set.wrap = false
set.scrolloff = 10
set.sidescrolloff = 8

set.tabstop = 2
set.shiftwidth = 2
set.softtabstop = 2
set.expandtab = true
set.smartindent = true
set.autoindent = true

set.selection = "exclusive"
set.selectmode = "mouse,key"
set.mousemodel = "popup"
set.keymodel = "startsel,stopsel"

set.ignorecase = true
set.smartcase = true
set.hlsearch = true
set.incsearch = true

set.termguicolors = true
set.signcolumn = "yes"
set.showmatch = true
set.matchtime = 2
set.cmdheight = 0
set.completeopt = "menuone,noinsert,noselect"
set.showmode = true
set.pumheight = 10
set.pumblend = 10
set.winblend = 0
set.winborder = "rounded"
set.pumborder = "none"
set.conceallevel = 0
set.concealcursor = ""
set.synmaxcol = 300
set.laststatus = 3

set.backup = false
set.writebackup = false
set.swapfile = false
set.undofile = true

local undodir = vim.fn.stdpath("state") .. "/undodir"
if vim.fn.isdirectory(undodir) == 0 then
	vim.fn.mkdir(undodir, "p")
end
set.undodir = undodir
set.updatetime = 300
set.timeoutlen = 500
set.ttimeoutlen = 0
set.autoread = true
set.autowrite = false

set.hidden = true
set.errorbells = false
set.backspace = "indent,eol,start"
set.autochdir = false
set.iskeyword:append("-")
set.path:append("**")
set.wildignore:append({ "*/node_modules/*" })
set.mouse = "a"
set.clipboard:append("unnamedplus")

set.modifiable = true

set.guicursor =
	"n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175"

set.foldmethod = "expr"
set.foldexpr = "v:lua.vim.treesitter.foldexpr()"
set.foldlevel = 99

set.splitbelow = true
set.splitright = true

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0

vim.g.netrw_keepdir = 0

vim.g.netrw_localcopydircmd = vim.fn.has("win32") == 1 and "cmd /c robocopy /e" or "cp -r"

set.wildmenu = true
set.wildmode = "longest:full,full"
set.wildignore:append({ "*.o", "*.obj", "*.pyc", "*.class", "*.jar" })

set.fillchars:append("diff:╱")

require("vim._core.ui2").enable({
	enable = true,
	msg = {
		targets = {
			[""] = "msg",
			empty = "cmd",
			bufwrite = "msg",
			confirm = "cmd",
			emsg = "pager",
			echo = "msg",
			echomsg = "msg",
			echoerr = "pager",
			completion = "cmd",
			list_cmd = "pager",
			lua_error = "pager",
			lua_print = "msg",
			progress = "pager",
			rpc_error = "pager",
			quickfix = "msg",
			search_cmd = "cmd",
			search_count = "cmd",
			shell_cmd = "pager",
			shell_err = "pager",
			shell_out = "pager",
			shell_ret = "msg",
			undo = "msg",
			verbose = "pager",
			wildlist = "cmd",
			wmsg = "msg",
			typed_cmd = "msg",
		},
		cmd = { height = 0.5 },
		dialog = { height = 0.5 },
		msg = { height = 0.3, timeout = 5000 },
		pager = { height = 0.5 },
	},
})
