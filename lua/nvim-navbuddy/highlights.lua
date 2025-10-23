---@text HIGHLIGHT
---
--- |nvim-navbuddy| provides the following highlights which get used when
--- available.
---
--- `NavbuddyName`  - highlight for name in source buffer
--- `NavbuddyScope` - highlight for scope of context in source buffer
--- `NavbuddyFloatBorder` - Floatborder highlight
--- `NavbuddyNormalFloat` - Float normal highlight
---
--- The following highlights are are used to highlight elements in the navbuddy
--- window according to their type. If you have "NavicIcons<type>" highlights
--- already defined, these will automatically get linked to them unless defined
--- explicitly.
---
--- `NavbuddyFile`
--- `NavbuddyModule`
--- `NavbuddyNamespace`
--- `NavbuddyPackage`
--- `NavbuddyClass`
--- `NavbuddyMethod`
--- `NavbuddyProperty`
--- `NavbuddyField`
--- `NavbuddyConstructor`
--- `NavbuddyEnum`
--- `NavbuddyInterface`
--- `NavbuddyFunction`
--- `NavbuddyVariable`
--- `NavbuddyConstant`
--- `NavbuddyString`
--- `NavbuddyNumber`
--- `NavbuddyBoolean`
--- `NavbuddyArray`
--- `NavbuddyObject`
--- `NavbuddyKey`
--- `NavbuddyNull`
--- `NavbuddyEnumMember`
--- `NavbuddyStruct`
--- `NavbuddyEvent`
--- `NavbuddyOperator`
--- `NavbuddyTypeParameter`
---@tag navbuddy-highlights
---@toc_entry Highlights

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

---@private
---@param style BorderConfig
---@param section SectionName
---@return any
local function get_border_chars(style, section)
  if style == "default" then
    style = "single"
  end
  if style ~= "single" and style ~= "rounded" and style ~= "double" and style ~= "solid" then
    return style
  end

	-- stylua: ignore
	local border_chars = {
		top_left = {
			single  = "┌",
			rounded = "╭",
			double  = "╔",
			solid   = "▛",
		},
		top = {
			single  = "─",
			rounded = "─",
			double  = "═",
			solid   = "▀",
		},
		top_right = {
			single  = "┐",
			rounded = "╮",
			double  = "╗",
			solid   = "▜",
		},
		right = {
			single  = "│",
			rounded = "│",
			double  = "║",
			solid   = "▐",
		},
		bottom_right = {
			single  = "┘",
			rounded = "╯",
			double  = "╝",
			solid   = "▟",
		},
		bottom = {
			single  = "─",
			rounded = "─",
			double  = "═",
			solid   = "▄",
		},
		bottom_left = {
			single  = "└",
			rounded = "╰",
			double  = "╚",
			solid   = "▙",
		},
		left = {
			single  = "│",
			rounded = "│",
			double  = "║",
			solid   = "▌",
		},
		top_T = {
			single  = "┬",
			rounded = "┬",
			double  = "╦",
			solid   = "▛",
		},
		bottom_T = {
			single  = "┴",
			rounded = "┴",
			double  = "╩",
			solid   = "▙",
		},
		blank = "",
	}

  local border_chars_map = {
    left = {
      style = {
        border_chars.top_left[style],
        border_chars.top[style],
        border_chars.top[style],
        border_chars.blank,
        border_chars.bottom[style],
        border_chars.bottom[style],
        border_chars.bottom_left[style],
        border_chars.left[style],
      },
    },
    mid = {
      style = {
        border_chars.top_T[style],
        border_chars.top[style],
        border_chars.top[style],
        border_chars.blank,
        border_chars.bottom[style],
        border_chars.bottom[style],
        border_chars.bottom_T[style],
        border_chars.left[style],
      },
    },
    right = {
      border_chars.top_T[style],
      border_chars.top[style],
      border_chars.top_right[style],
      border_chars.right[style],
      border_chars.bottom_right[style],
      border_chars.bottom[style],
      border_chars.bottom_T[style],
      border_chars.left[style],
    },
  }
  return border_chars_map[section]
end
---@private
---@param config Navbuddy.config
local function highlight_setup(config)
  for lsp_num = 1, 26 do
    local navbuddy_ok, _ = pcall(
      vim.api.nvim_get_hl_by_name,
      "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num),
      false
    )
    local navic_ok, navic_hl =
      pcall(
        vim.api.nvim_get_hl_by_name,
        "NavicIcons" .. navic.adapt_lsp_num_to_str(lsp_num),
        true
      )

    if not navbuddy_ok and navic_ok then
      navic_hl = navic_hl["foreground"]
      vim.api.nvim_set_hl(0, "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num), { fg = navic_hl })
    end

    local ok, navbuddy_hl = pcall(
      vim.api.nvim_get_hl_by_name,
      "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num),
      true
    )

    if ok then
      navbuddy_hl = navbuddy_hl["foreground"]

      local highlight
      if config.custom_hl_group ~= nil then
        highlight = { link = config.custom_hl_group }
      else
        highlight = { bg = navbuddy_hl }
      end
      vim.api.nvim_set_hl(0, "NavbuddyCursorLine" .. navic.adapt_lsp_num_to_str(lsp_num), highlight)
    else
      local _, normal_hl = pcall(vim.api.nvim_get_hl_by_name, "Normal", true)
      normal_hl = normal_hl["foreground"]
      vim.api.nvim_set_hl(0, "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num), { fg = normal_hl })

      local highlight
      if config.custom_hl_group ~= nil then
        highlight = { link = config.custom_hl_group }
      else
        highlight = { bg = normal_hl }
      end
      vim.api.nvim_set_hl(0, "NavbuddyCursorLine" .. navic.adapt_lsp_num_to_str(lsp_num), highlight)
    end
    -- local navbuddy_ok, _ = pcall(get_color_from_hl, "Navbuddy" .. navic_num(lsp_num))
    -- local navic_ok, navic_hl = pcall(get_color_from_hl, "NavicIcons" .. navic_num(lsp_num))
    -- if not navbuddy_ok and navic_ok then
    --   navic_hl = navic_hl["foreground"]
    --   local navic_hldim = darken(navic_hl, 30)
    --   set_hl(0, "Navbuddy" .. navic_num(lsp_num), { fg = navic_hl })
    --   if #navic_hldim == 7 then
    --     set_hl(0, "Navbuddy" .. navic_num(lsp_num) .. "Dim", { fg = navic_hldim })
    --   end
    -- end

    -- local ok, navbuddy_hl = pcall(vim.api.nvim_get_hl_by_name, "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num), true)
    -- if ok then
    --   navbuddy_hl = navbuddy_hl["foreground"]
    --   vim.api.nvim_set_hl(0, "NavbuddyCursorLine" .. navic.adapt_lsp_num_to_str(lsp_num), { bg = navbuddy_hl })
    -- else
    --   local _, normal_hl = pcall(vim.api.nvim_get_hl_by_name, "Normal", true)
    --   normal_hl = normal_hl["foreground"]
    --   vim.api.nvim_set_hl(0, "Navbuddy" .. navic.adapt_lsp_num_to_str(lsp_num), { fg = normal_hl })
    --   vim.api.nvim_set_hl(0, "NavbuddyCursorLine" .. navic.adapt_lsp_num_to_str(lsp_num), { bg = normal_hl })
    -- end
  end

  -- local ok, _ = pcall(get_hl, "NavbuddyCursorLine", false)
  -- if not ok then
  --   set_hl(0, "NavbuddyCursorLine", { reverse = true, bold = true })
  -- end

  -- ok, _ = pcall(get_hl, "NavbuddyCursor", false)
  -- if not ok then
  --   set_hl(0, "NavbuddyCursor", { bg = "#000000", blend = 100 })
  -- end

  -- ok, _ = pcall(get_hl, "NavbuddyName", false)
  -- if not ok then
  --   set_hl(0, "NavbuddyName", { link = "IncSearch" })
  -- end

  -- ok, _ = pcall(get_hl, "NavbuddyScope", false)
  -- if not ok then
  --   set_hl(0, "NavbuddyScope", { link = "Visual" })
  -- end

  -- ok, _ = pcall(get_hl, "NavbuddyFloatBorder", false)
  -- if not ok then
  --   set_hl(0, "NavbuddyFloatBorder", { link = "FloatBorder" })
  -- end

  -- ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyNormalFloat", false)
  -- if not ok then
  --   vim.api.nvim_set_hl(0, "NavbuddyNormalFloat", { link = "NormalFloat" })
  -- end

  local ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyCursorLine", false)
  if not ok then
    local highlight
    if config.custom_hl_group ~= nil then
      highlight = { link = config.custom_hl_group }
    else
      highlight = { reverse = true, bold = true }
    end
    vim.api.nvim_set_hl(0, "NavbuddyCursorLine", highlight)
  end

  ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyCursor", false)
  if not ok then
    vim.api.nvim_set_hl(0, "NavbuddyCursor", {
      bg = "#000000",
      blend = 100,
    })
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

  ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyNormalFloat", false)
  if not ok then
    vim.api.nvim_set_hl(0, "NavbuddyNormalFloat", { link = "NormalFloat" })
  end

  ok, _ = pcall(get_hl, "NavbuddyTitleBorder", false)
  if not ok then
    set_hl(0, "NavbuddyTitleBorder", { link = "FloatBorder" })
  end

  ok, _ = pcall(vim.api.nvim_get_hl_by_name, "NavbuddyNormalTitle", false)
  if not ok then
    vim.api.nvim_set_hl(0, "NavbuddyNormalTitle", { link = "NormalFloat" })
  end
end

return {
  get_border_chars = get_border_chars,
  get_color_from_hl = get_color_from_hl,
  darken = darken,
  setup = highlight_setup,
}
