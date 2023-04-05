local navic = require("nvim-navic.lib")

local function highlight_setup()
  for lsp_num = 1, 26 do
    local navbuddy_ok, _ = pcall(vim.api.nvim_get_hl_by_name, "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num), false)
    local navic_ok, navic_hl = pcall(vim.api.nvim_get_hl_by_name, "NavicIcons" .. navic.adapt_lsp_num_to_str(lsp_num), true)
    if not navbuddy_ok and navic_ok then
      navic_hl = navic_hl["foreground"]
      vim.api.nvim_set_hl(0, "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num), { fg = navic_hl })
    end

    local ok, navbuddy_hl = pcall(vim.api.nvim_get_hl_by_name, "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num), true)
    if ok then
      navbuddy_hl = navbuddy_hl["foreground"]
      vim.api.nvim_set_hl(0, "NavbuddyCursorLine" .. navic.adapt_lsp_num_to_str(lsp_num), { bg = navbuddy_hl })
    else
      local _, normal_hl = pcall(vim.api.nvim_get_hl_by_name, "Normal", true)
      normal_hl = normal_hl["foreground"]
      vim.api.nvim_set_hl(0, "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num), { fg = normal_hl })
      vim.api.nvim_set_hl(0, "NavbuddyCursorLine" .. navic.adapt_lsp_num_to_str(lsp_num), { bg = normal_hl })
    end
  end

  local ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyCursorLine", false)
  if not ok then
    vim.api.nvim_set_hl(0, "NavbuddyCursorLine", { reverse = true, bold = true })
  end

  ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyCursor", false)
  if not ok then
    vim.api.nvim_set_hl(0, "NavbuddyCursor", { bg = "#000000", blend = 100 })
  end

  ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyName", false)
  if not ok then
    vim.api.nvim_set_hl(0, "NavbuddyName", { link = "IncSearch" })
  end

  ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyScope", false)
  if not ok then
    vim.api.nvim_set_hl(0, "NavbuddyScope", { link = "Visual" })
  end

  ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyFloatBorder", false)
  if not ok then
    vim.api.nvim_set_hl(0, "NavbuddyFloatBorder", { link = "FloatBorder" })
  end
end

return {
  setup = highlight_setup,
}
