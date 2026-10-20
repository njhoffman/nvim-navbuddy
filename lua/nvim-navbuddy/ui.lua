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

local ui = {}

---@private
---@param style BorderConfig
---@param section SectionName
---@return any
function ui.get_border_chars(style, section)
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
local function hl_exists(name)
  local hl = vim.api.nvim_get_hl(0, { name = name })
  return next(hl) ~= nil
end

function ui.highlight_setup(config)
  local set_hl = vim.api.nvim_set_hl

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
end

return ui
