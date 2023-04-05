local navic = require("nvim-navic.lib")
local state = require("nvim-navbuddy.state")

local function clear_buffer(buf)
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, {})
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", false)
end

local function fill_buffer(buf, node, config)
  local cursor_pos = vim.api.nvim_win_get_cursor(buf.winid)
  clear_buffer(buf)

  local parent = node.parent

  local lines = {}
  for _, child_node in ipairs(parent.children) do
    local text = " " .. config.icons[child_node.kind] .. child_node.name
    table.insert(lines, text)
  end

  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", false)

  for i, child_node in ipairs(parent.children) do
    vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, "Navbuddy" .. navic.adapt_lsp_num_to_str(child_node.kind), i - 1, 0, -1)
  end

  if cursor_pos[1] ~= node.index then
    cursor_pos[1] = node.index
  end

  vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, "NavbuddyCursorLine", cursor_pos[1] - 1, 0, -1)
  vim.api.nvim_buf_set_extmark(buf.bufnr, state.ns, cursor_pos[1] - 1, #lines[cursor_pos[1]], {
    end_row = cursor_pos[1],
    hl_eol = true,
    hl_group = "NavbuddyCursorLine" .. navic.adapt_lsp_num_to_str(node.kind),
  })
  vim.api.nvim_win_set_cursor(buf.winid, cursor_pos)
end

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

return {
  clear = clear_buffer,
  fill = fill_buffer,
  get_border = get_border,
}
