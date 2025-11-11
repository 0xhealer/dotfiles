local set = vim.opt

-- Disable Netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

set.incsearch = true
set.backup = false
set.clipboard = "unnamedplus"
set.cmdheight = 1
set.completeopt = { "menu", "menuone", "noselect" }
set.conceallevel = 0
set.fileencoding = "utf-8"
set.hlsearch = true
set.ignorecase = true
set.mouse = "a"
set.pumheight = 10
set.showmode = false
set.showtabline = 0
set.smartcase = true
set.smartindent = true
set.splitbelow = true
set.splitright = true
set.swapfile = false
set.termguicolors = true
set.timeoutlen = 500
set.undofile = true
set.undodir = vim.fn.stdpath("data") .. "/undo"
set.updatetime = 100
set.writebackup = false
set.expandtab = true
set.shiftwidth = 2
set.cursorline = false
set.number = true
set.breakindent = true
set.relativenumber = true
set.numberwidth = 2
set.signcolumn = "yes:1"
set.wrap = false
set.scrolloff = 10
set.sidescrolloff = 10
set.showcmd = false
set.ruler = true
set.guifont = "monospace:h17"
set.title = true
set.confirm = true
set.fillchars = { eob = " " }
set.winborder = "rounded" -- solid
set.winborder = "single"
vim.filetype.add({
    extension = {
        env = "dotenv",
    },
    filename = {
        [".env"] = "dotenv",
        ["env"] = "dotenv",
    },
    pattern = {
        ["[jt]sconfig.*.json"] = "jsonc",
        ["%.env%.[%w_.-]+"] = "dotenv",
    },
})
