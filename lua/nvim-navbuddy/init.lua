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
    then
      config.window.sections.left.border = config.window.sections.left.border or "none"
      config.window.sections.mid.border = config.window.sections.mid.border or "none"
      config.window.sections.right.border = config.window.sections.right.border or "none"
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

  if config.theme == "default" then
    config.theme = "hl-line1"
  end

  if config.lsp.auto_attach == true then
    lsp.auto_attach(config)
  end
end

return {
  setup = setup,
}
