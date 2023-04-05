local navic = require("nvim-navic.lib")
local set_hl = vim.api.nvim_set_hl
local get_hl = vim.api.nvim_get_hl_by_name
local navic_num = navic.adapt_lsp_num_to_str

local function highlight_setup()
  for lsp_num = 1, 26 do
    local navbuddy_ok, _ = pcall(get_hl, "Navbuddy" .. navic_num(lsp_num), false)
    local navic_ok, navic_hl = pcall(get_hl, "NavicIcons" .. navic_num(lsp_num), true)
    if not navbuddy_ok and navic_ok then
      navic_hl = navic_hl["foreground"]
      set_hl(0, "Navbuddy" .. navic_num(lsp_num), { fg = navic_hl })
      set_hl(0, "Navbuddy" .. navic_num(lsp_num) .. "Dim", { fg = navic_hl, bg = "#000000", blend = 90 })
    end

    -- local ok, navbuddy_hl = pcall(get_hl, "Navbuddy" .. navic_num(lsp_num), true)
    -- if ok then
    --   navbuddy_hl = navbuddy_hl["foreground"]
    --   set_hl(0, "NavbuddyCursorLine" .. navic_num(lsp_num), { bg = navbuddy_hl })
    -- else
    --   local _, normal_hl = pcall(get_hl, "Normal", true)
    --   normal_hl = normal_hl["foreground"]
    --   set_hl(0, "Navbuddy" .. navic_num(lsp_num), { fg = normal_hl })
    --   set_hl(0, "NavbuddyCursorLine" .. navic_num(lsp_num), { bg = normal_hl })
    -- end
  end

  local ok, _ = pcall(get_hl, "NavbuddyCursorLine", false)
  if not ok then
    set_hl(0, "NavbuddyCursorLine", { reverse = true, bold = true })
  end

  ok, _ = pcall(get_hl, "NavbuddyCursor", false)
  if not ok then
    set_hl(0, "NavbuddyCursor", { bg = "#000000", blend = 100 })
  end

  ok, _ = pcall(get_hl, "NavbuddyName", false)
  if not ok then
    set_hl(0, "NavbuddyName", { link = "IncSearch" })
  end

  ok, _ = pcall(get_hl, "NavbuddyScope", false)
  if not ok then
    set_hl(0, "NavbuddyScope", { link = "Visual" })
  end

  ok, _ = pcall(get_hl, "NavbuddyFloatBorder", false)
  if not ok then
    set_hl(0, "NavbuddyFloatBorder", { link = "FloatBorder" })
  end
end

return {
  setup = highlight_setup,
}
