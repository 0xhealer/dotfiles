-- Setting the Leader key
vim.g.maplocalleader = " "
vim.g.mapleader = " "

-- Variables for easier calling
local keymap = vim.keymap.set
local opts = {noremap = true, silent = true}


-- Move selected line / block of text in visual mode
keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
keymap("v", "K", ":m '<-2<CR>gv=gv", opts)


-- better indenting
keymap("v", "<", "<gv")
keymap("v", ">", ">gv")

-- paste over currently selected text without yanking it
keymap("v", "p", '"_dp')
keymap("v", "P", '"_dP')

-- copy everything between { and } including the brackets
-- p puts text after the cursor,
-- P puts text before the cursor.
keymap("n", "YY", "va{Vy", opts)

-- Move to start/end of line
keymap({ "n", "x", "o" }, "H", "^", opts)
keymap({ "n", "x", "o" }, "L", "g_", opts)

-- Panes resizing
keymap("n", "+", ":vertical resize +5<CR>")
keymap("n", "_", ":vertical resize -5<CR>")
keymap("n", "=", ":resize +5<CR>")
keymap("n", "-", ":resize -5<CR>")

-- ctrl + x to cut full line
keymap("n", "<C-x>", "dd", opts)

-- Select all
keymap("n", "<C-a>", "ggVG", opts)

-- Ctrl + S to save files
keymap("n", "<C-s>", "<CMD>update<CR>", opts)
keymap("v", "<C-s>", "<C-S> <C-C>:update<CR>", opts)
keymap("i", "<C-s>", "<C-O>:update<CR>", opts)

-- Quiting and Writing
keymap("n", "<leader>q", "<CMD>q!<CR>", opts)
keymap("n", "<leader>w", "<CMD>wq!<CR>", opts)