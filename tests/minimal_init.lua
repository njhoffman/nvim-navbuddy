local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local deps = root .. "/deps"

-- Only the plugin, its test dependencies and Neovim's own runtime: nothing from
-- the user's config, data directories or packages.
vim.o.runtimepath = table.concat({
  root,
  deps .. "/plenary.nvim",
  deps .. "/nvim-navic",
  deps .. "/nui.nvim",
  vim.env.VIMRUNTIME,
}, ",")
vim.o.packpath = ""

vim.opt.swapfile = false
vim.o.shadafile = "NONE"
vim.cmd("runtime plugin/plenary.vim")
