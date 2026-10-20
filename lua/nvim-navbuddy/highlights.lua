---@text HIGHLIGHT
---
--- |nvim-navbuddy| provides the following highlights which get used when
--- available.
---
--- `NavbuddyName`  - highlight for name in source buffer
--- `NavbuddyScope` - highlight for scope of context in source buffer
--- `NavbuddyFloatBorder` - Floatborder highlight
--- `NavbuddyNormalFloat` - Float normal highlight
--- `NavbuddyNormalFloatDim` - Dimmed float normal (used in buffer focus mode)
--- `NavbuddyFloatBorderDim` - Dimmed float border (used in buffer focus mode)
--- `NavbuddyTitleBorder` - Title bar border highlight
--- `NavbuddyNormalTitle` - Title bar normal highlight
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
local navic_num = navic.adapt_lsp_num_to_str

local function hl_exists(name)
  local hl = vim.api.nvim_get_hl(0, { name = name })
  return next(hl) ~= nil
end

local function get_color_from_hl(name)
  local result = {}
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
  if hl.fg then
    result.foreground = string.format("#%06x", hl.fg)
  end
  if hl.bg then
    result.background = string.format("#%06x", hl.bg)
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
    local sfx = navic.adapt_lsp_num_to_str(lsp_num)
    local navbuddy_name = "Navbuddy" .. sfx
    local navic_name = "NavicIcons" .. sfx

    if not hl_exists(navbuddy_name) then
      local navic_hl = vim.api.nvim_get_hl(0, { name = navic_name, link = false })
      if navic_hl.fg then
        set_hl(0, navbuddy_name, { fg = navic_hl.fg })
      end
    end

    local navbuddy_hl = vim.api.nvim_get_hl(0, { name = navbuddy_name, link = false })
    if navbuddy_hl.fg then
      local highlight
      if config.custom_hl_group ~= nil then
        highlight = { link = config.custom_hl_group }
      else
        highlight = { bg = navbuddy_hl.fg }
      end
      set_hl(0, "NavbuddyCursorLine" .. sfx, highlight)
    else
      local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
      local fg = normal_hl.fg
      set_hl(0, navbuddy_name, { fg = fg })

      local highlight
      if config.custom_hl_group ~= nil then
        highlight = { link = config.custom_hl_group }
      else
        highlight = { bg = fg }
      end
      set_hl(0, "NavbuddyCursorLine" .. sfx, highlight)
    end
  end

  if not hl_exists("NavbuddyCursorLine") then
    local highlight
    if config.custom_hl_group ~= nil then
      highlight = { link = config.custom_hl_group }
    else
      highlight = { reverse = true, bold = true }
    end
    set_hl(0, "NavbuddyCursorLine", highlight)
  end

  if not hl_exists("NavbuddyCursor") then
    set_hl(0, "NavbuddyCursor", { bg = "#000000", blend = 100 })
  end

  if not hl_exists("NavbuddyName") then
    set_hl(0, "NavbuddyName", { link = "IncSearch" })
  end

  if not hl_exists("NavbuddyScope") then
    set_hl(0, "NavbuddyScope", { link = "Visual" })
  end

  if not hl_exists("NavbuddyFloatBorder") then
    set_hl(0, "NavbuddyFloatBorder", { link = "FloatBorder" })
  end

  if not hl_exists("NavbuddyNormalFloat") then
    set_hl(0, "NavbuddyNormalFloat", { link = "NormalFloat" })
  end

  if not hl_exists("NavbuddyTitleBorder") then
    set_hl(0, "NavbuddyTitleBorder", { link = "FloatBorder" })
  end

  if not hl_exists("NavbuddyNormalTitle") then
    set_hl(0, "NavbuddyNormalTitle", { link = "NormalFloat" })
  end

  if not hl_exists("NavbuddyNormalFloatDim") then
    set_hl(0, "NavbuddyNormalFloatDim", { link = "Comment" })
  end

  if not hl_exists("NavbuddyFloatBorderDim") then
    set_hl(0, "NavbuddyFloatBorderDim", { link = "Comment" })
  end
end

return {
  get_border_chars = get_border_chars,
  get_color_from_hl = get_color_from_hl,
  darken = darken,
  setup = highlight_setup,
  _clamp_color = clamp_color,
  _to_rgb = to_rgb,
}
