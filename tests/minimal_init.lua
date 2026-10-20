local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
local deps = root .. "/deps"

vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(deps .. "/plenary.nvim")
vim.opt.rtp:prepend(deps .. "/nvim-navic")
vim.opt.rtp:prepend(deps .. "/nui.nvim")

vim.opt.swapfile = false
vim.cmd("runtime plugin/plenary.vim")
