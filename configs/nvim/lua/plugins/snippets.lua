return {
  "echasnovski/mini.snippets",
  version = false,
  event = "InsertEnter",
  dependencies = { "rafamadriz/friendly-snippets", "abeldekat/cmp-mini-snippets" },
  config = function()
    local gen_loader = require("mini.snippets"), gen_loader
    require("mini.snippets").setup({
      mappings = {
        expand = '<C-j>',
        jump_next = '<Down>',
        jump_prev = '<Up>',
        stop = '<C-c>',
      },

    })
  end

}
