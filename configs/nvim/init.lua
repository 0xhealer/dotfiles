if vim.loader then
  vim.loader.enable()
end

require("core.options")
require("core.autocmds")
require("core.commands")
require("core.ui")
require("utils")

local ok, err = pcall(require, "plugins")
if not ok then
  vim.schedule(function()
    vim.notify("plugins failed to load:\n" .. tostring(err), vim.log.levels.ERROR)
  end)
end

local kok, kerr = pcall(require, "core.keymaps")
if not kok then
  vim.schedule(function()
    vim.notify("keymaps failed to load:\n" .. tostring(kerr), vim.log.levels.ERROR)
  end)
end
