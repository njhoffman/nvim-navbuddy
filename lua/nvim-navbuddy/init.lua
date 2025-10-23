--- *nvim-navbuddy* *navbuddy*
---
--- A simple popup display that provides breadcrumbs like navigation feature but
--- in keyboard centric manner inspired by ranger file manager.

---@text TABLE OF CONTENTS
---
---@toc
---@tag navbuddy-table-of-contents
---@text

---@text REQUIREMENTS
---
--- - nvim-lspconfig: `https://github.com/neovim/nvim-lspconfig`
--- - nvim-navic: `https://github.com/SmiteshP/nvim-navic`
--- - nui.nvim: `https://github.com/MunifTanjim/nui.nvim`
--- - Neovim: 0.8 or above
---
---@text OPTIONAL REQUIREMENTS
---
--- - Comment.nvim: `https://github.com/numToStr/Comment.nvim`
--- - Fuzzy find: Only one of these is needed.
---     - telescope.nvim: `https://github.com/nvim-telescope/telescope.nvim`
---     - snacks.nvim: `https://github.com/folke/snacks.nvim`
---@tag navbuddy-requirements
---@toc_entry Requirements

---@text INSTALLATION
--- >lua
---   -- lazy.nvim
---   {
---     "neovim/nvim-lspconfig",
---     dependencies = {
---       "hasansujon786/nvim-navbuddy",
---       opts = { lsp = { auto_attach = true } }
---       dependencies = {
---         "SmiteshP/nvim-navic",
---         "MunifTanjim/nui.nvim"
---       }
---     }
---   }
--- <
---@tag navbuddy-installation
---@toc_entry Installation

---@text USAGE
---
--- nvim-navbuddy needs to be attached to lsp servers of the buffer to work. Use the
--- navbuddy.attach function while setting up lsp servers. You can skip this
--- step if you have enabled auto_attach option during setup.
---
--- Example: >lua
---   require("lspconfig").clangd.setup {
---     on_attach = function(client, bufnr)
---       navbuddy.attach(client, bufnr)
---     end
---   }
--- <
--- Then simply use command `Navbuddy` to open the window.
---@tag navbuddy-usage
---@toc_entry Usage

---@text COMMANDS
---
--- Navbuddy does not define any default keybindings for nvim. The example
--- keybindings are:
--- >vim
---   nnoremap zo :Navbuddy<cr>
---   nnoremap zi :Navbuddy root<cr>
--- <
--- root~
--- Open navbuddy with root node, the first node left of current node.
---@tag :Navbuddy navbuddy-commands
---@toc_entry Commands

local navic = require("nvim-navic.lib")
local lsp = require("nvim-navbuddy.lsp")
local config = require("nvim-navbuddy.config")

setmetatable(config.icons, {
  __index = function()
    return "? "
  end,
})

local function setup(user_config)
  if user_config ~= nil then
    if user_config.window ~= nil then
      config.window = vim.tbl_deep_extend("keep", user_config.window, config.window)
    end

    -- If one is set, default for others should be none
    if
      config.window.sections.left.border ~= nil
      or config.window.sections.mid.border ~= nil
      or config.window.sections.right.border ~= nil
      or config.window.sections.title.border ~= nil
    then
      config.window.sections.left.border = config.window.sections.left.border or "none"
      config.window.sections.mid.border = config.window.sections.mid.border or "none"
      config.window.sections.right.border = config.window.sections.right.border or "none"
      config.window.sections.title.border = config.window.sections.title.border or "none"
    end

    if user_config.icons ~= nil then
      for k, v in pairs(user_config.icons) do
        if navic.adapt_lsp_str_to_num(k) then
          config.icons[navic.adapt_lsp_str_to_num(k)] = v
        end
      end
    end

    if user_config.mappings ~= nil then
      config.mappings = user_config.mappings
    end

    if user_config.lsp ~= nil then
      config.lsp = vim.tbl_deep_extend("keep", user_config.lsp, config.lsp)
    end

    if user_config.source_buffer ~= nil then
      config.source_buffer = vim.tbl_deep_extend("keep", user_config.source_buffer, config.source_buffer)
    end
  end

  if config.lsp.auto_attach == true then
    lsp.auto_attach(config)
  end
end

return {
  setup = setup,
}
