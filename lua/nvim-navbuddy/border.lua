local function get_border(style, section)
  if style ~= 'single' and style ~= 'rounded' and style ~= 'double' and style ~= 'solid' then
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
		blank = " ",
		none = "",
	}

  local border_chars_map = {
    title = {
      style = {
        border_chars.top_left[style],
        border_chars.top[style],
        border_chars.top_right[style],
        border_chars.right[style],
        border_chars.right[style],
        border_chars.none,
        border_chars.left[style],
        border_chars.left[style],
      },
    },
    nav_title = {
      style = {
        border_chars.top_left[style],
        border_chars.top[style],
        border_chars.top_right[style],
        border_chars.right[style],
        border_chars.right[style],
        border_chars.bottom[style],
        border_chars.left[style],
        border_chars.left[style],
      },
    },
    left = {
      style = {
        border_chars.left[style], -- top_left
        border_chars.top[style], -- top
        border_chars.top_T[style], -- top
        border_chars.right[style],
        border_chars.bottom_T[style],
        border_chars.bottom[style],
        border_chars.bottom_left[style],
        border_chars.left[style],
      },
    },
    mid = {
      style = {
        border_chars.none,
        border_chars.top[style],
        border_chars.none, -- top
        border_chars.none,
        border_chars.bottom_T[style],
        border_chars.bottom[style],
        border_chars.bottom[style],
        border_chars.none,
      },
    },
    right = {
      style = {
        border_chars.top_T[style],
        border_chars.top[style],
        border_chars.right[style], -- top_right
        border_chars.right[style],
        border_chars.bottom_right[style],
        border_chars.bottom[style],
        border_chars.bottom_T[style],
        border_chars.left[style],
      },
    },
  }
  return border_chars_map[section]
end

--- Returns a new nui border options table for any supported border value: a
--- style name, a list of border characters, or an options table.
local function normalize(value)
  if value == nil then
    return {}
  end
  if type(value) == "string" or (value.style == nil and vim.islist(value)) then
    return { style = value }
  end
  return vim.tbl_extend("force", {}, value)
end

--- Nui options for a section: its own border if set, else the window border.
local function resolve(section_border, window_border, section)
  return normalize(section_border or get_border(window_border, section))
end

--- Whether a configured border value can carry text such as the LSP name.
local function supports_text(value)
  local style = type(value) == "table" and value.style or value
  return style ~= "none" and style ~= "shadow" and style ~= "solid"
end

return {
  get_border = get_border,
  normalize = normalize,
  resolve = resolve,
  supports_text = supports_text,
}
