local navic = require("nvim-navic.lib")
local set_hl = vim.api.nvim_set_hl
local get_hl = vim.api.nvim_get_hl_by_name
local navic_num = navic.adapt_lsp_num_to_str

local function get_color_from_hl(name)
  local result = {}
  for k, v in pairs(vim.api.nvim_get_hl_by_name(name, true)) do
    result[k] = string.format("#%06x", v)
  end
  return result
end

local function clamp_color(color)
  return math.max(math.min(color, 255), 0)
end

local function to_rgb(color)
  return tonumber(color:sub(2, 3), 16), tonumber(color:sub(4, 5), 16), tonumber(color:sub(6), 16)
end

local function darken(color, percent)
  local r, g, b = to_rgb(color)
  if type(r) ~= "nil" and type(g) ~= "nil" and type(b) ~= "nil" then
    r = clamp_color(math.floor(tonumber(r * (100 - percent) / 100) or r))
    g = clamp_color(math.floor(tonumber(g * (100 - percent) / 100) or g))
    b = clamp_color(math.floor(tonumber(b * (100 - percent) / 100) or b))
  end
  local new_color = "#" .. string.format("%0x", r) .. string.format("%0x", g) .. string.format("%0x", b)
  if #new_color == 6 then
    new_color = "#0" .. string.format("%0x", r) .. string.format("%0x", g) .. string.format("%0x", b)
  end

  return new_color
end

local function highlight_setup()
  for lsp_num = 1, 26 do
    local navbuddy_ok, _ = pcall(get_color_from_hl, "Navbuddy" .. navic_num(lsp_num))
    local navic_ok, navic_hl = pcall(get_color_from_hl, "NavicIcons" .. navic_num(lsp_num))
    if not navbuddy_ok and navic_ok then
      navic_hl = navic_hl["foreground"]
      local navic_hldim = darken(navic_hl, 50)
      set_hl(0, "Navbuddy" .. navic_num(lsp_num), { fg = navic_hl })
      if #navic_hldim == 7 then
        set_hl(0, "Navbuddy" .. navic_num(lsp_num) .. "Dim", { fg = navic_hldim })
      end
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
  get_color_from_hl = get_color_from_hl,
  darken = darken,
  setup = highlight_setup,
}
