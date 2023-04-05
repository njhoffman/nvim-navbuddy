local function get_border(style, section)
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
		blank = " ",
    none = ''
	}

  local border_chars_map = {
    title = {
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
        border_chars.blank,
        border_chars.blank,
        border_chars.blank,
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
        border_chars.none,
        border_chars.none,
        border_chars.bottom[style],
        border_chars.bottom[style],
        border_chars.bottom_T[style],
        border_chars.left[style],
      },
    },
    right = {
      style = {
        border_chars.top_T[style],
        border_chars.top[style],
        border_chars.right[style],
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

return {
  get_border = get_border,
}
