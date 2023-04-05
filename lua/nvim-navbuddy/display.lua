local highlights = require("nvim-navbuddy.highlights")
local nui_popup = require("nui.popup")
local nui_layout = require("nui.layout")
local nui_text = require("nui.text")

-- local utils = require("nvim-navbuddy.utils")
local state = require("nvim-navbuddy.state")
local buffer = require("nvim-navbuddy.buffer")

local display = {}

function display:new(obj)
  highlights.setup()

  -- Object
  setmetatable(obj, self)
  self.__index = self

  local config = obj.config

  -- NUI elements
  local left_popup = nui_popup({
    focusable = false,
    border = config.window.sections.left.border or buffer.get_border(config.window.border, "left"),
    win_options = {
      winhighlight = "FloatBorder:NavbuddyFloatBorder",
    },
    buf_options = {
      modifiable = false,
    },
  })

  local mid_popup = nui_popup({
    enter = true,
    border = config.window.sections.mid.border or buffer.get_border(config.window.border, "mid"),
    win_options = {
      winhighlight = "FloatBorder:NavbuddyFloatBorder",
      scrolloff = config.window.scrolloff,
    },
    buf_options = {
      modifiable = false,
    },
  })

  local lsp_name = {
    bottom = nui_text("[" .. obj.lsp_name .. "]", "NavbuddyFloatBorder"),
    bottom_align = "right",
  }

  if config.window.sections.right.border == "none" or config.window.border == "none" or config.window.sections.right.border == "shadow" or config.window.border == "shadow" or config.window.sections.right.border == "solid" or config.window.border == "solid" then
    lsp_name = nil
  end

  local right_popup = nui_popup({
    focusable = false,
    border = {
      style = config.window.sections.right.border or buffer.get_border(config.window.border, "right"),
      text = lsp_name,
    },
    win_options = {
      winhighlight = "FloatBorder:NavbuddyFloatBorder",
    },
    buf_options = {
      modifiable = false,
    },
  })

  -- utils.get_layout_opts(),
  local layout = nui_layout(
    {
      size = {
        width = "60%",
        height = "15",
      },
      position = "100%",
    },
    nui_layout.Box({
      nui_layout.Box(left_popup, { size = { width = "30%" } }),
      nui_layout.Box(mid_popup, { size = { width = "40%" } }),
      nui_layout.Box(right_popup, { size = { width = "30%" } }),
    }, { dir = "row" })
  )

  obj.layout = layout
  obj.left = left_popup
  obj.mid = mid_popup
  obj.right = right_popup
  obj.state = {
    leaving_window_for_action = false,
    leaving_window_for_reorientation = false,
    closed = false,
    source_buffer_scrolloff = nil,
    user_gui_cursor = nil,
  }

  -- Set filetype
  vim.api.nvim_buf_set_option(obj.mid.bufnr, "filetype", "Navbuddy")

  -- Hidden cursor
  obj.state.user_gui_cursor = vim.api.nvim_get_option("guicursor")
  if obj.state.user_gui_cursor ~= "" then
    vim.api.nvim_set_option("guicursor", "a:NavbuddyCursor")
  end

  -- User Scrolloff
  if config.source_buffer.scrolloff then
    obj.state.source_buffer_scrolloff = vim.api.nvim_get_option("scrolloff")
    vim.api.nvim_set_option("scrolloff", config.source_buffer.scrolloff)
  end

  -- Autocmds
  local augroup = vim.api.nvim_create_augroup("Navbuddy", { clear = false })
  vim.api.nvim_clear_autocmds({ buffer = obj.mid.bufnr })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    buffer = obj.mid.bufnr,
    callback = function()
      local cursor_pos = vim.api.nvim_win_get_cursor(obj.mid.winid)
      if obj.focus_node ~= obj.focus_node.parent.children[cursor_pos[1]] then
        vim.dbglog("moved")
        obj.focus_node = obj.focus_node.parent.children[cursor_pos[1]]
        -- obj.layout:update(utils.get_layout_opts(obj.focus_node))
        obj:redraw()
      end

      obj.focus_node.parent.memory = obj.focus_node.index

      obj:clear_highlights()
      obj:focus_range()
    end,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = augroup,
    buffer = obj.mid.bufnr,
    callback = function()
      if obj.state.leaving_window_for_action == false and obj.state.leaving_window_for_reorientation == false and obj.state.closed == false then
        obj:close()
      end
    end,
  })

  -- Mappings
  for i, v in pairs(config.mappings) do
    obj.mid:map("n", i, function()
      v(obj)
    end)
  end

  -- Display
  layout:mount()
  obj:redraw()
  obj:focus_range()

  return obj
end

function display:focus_range()
  local ranges = nil

  if vim.deep_equal(self.focus_node.scope, self.focus_node.name_range) then
    ranges = { { "NavbuddyScope", self.focus_node.scope } }
  else
    ranges = { { "NavbuddyScope", self.focus_node.scope }, { "NavbuddyName", self.focus_node.name_range } }
  end

  if self.config.source_buffer.highlight then
    for _, v in ipairs(ranges) do
      local highlight, range = unpack(v)

      if range["start"].line == range["end"].line then
        vim.api.nvim_buf_add_highlight(self.for_buf, state.ns, highlight, range["start"].line - 1, range["start"].character, range["end"].character)
      else
        vim.api.nvim_buf_add_highlight(self.for_buf, state.ns, highlight, range["start"].line - 1, range["start"].character, -1)
        vim.api.nvim_buf_add_highlight(self.for_buf, state.ns, highlight, range["end"].line - 1, 0, range["end"].character)
        for i = range["start"].line, range["end"].line - 2, 1 do
          vim.api.nvim_buf_add_highlight(self.for_buf, state.ns, highlight, i, 0, -1)
        end
      end
    end
  end

  if self.config.source_buffer.follow_node then
    local last_range = ranges[#ranges][2]
    vim.api.nvim_win_set_cursor(self.for_win, { last_range["start"].line, last_range["start"].character })

    self.state.leaving_window_for_reorientation = true
    vim.api.nvim_set_current_win(self.for_win)

    if self.config.source_buffer.reorient == "smart" then
      local total_lines = self.focus_node.scope["end"].line - self.focus_node.scope["start"].line + 1

      if total_lines >= vim.api.nvim_win_get_height(self.for_win) then
        vim.api.nvim_command("normal! zt")
      else
        local mid_line = bit.rshift(self.focus_node.scope["start"].line + self.focus_node.scope["end"].line, 1)
        vim.api.nvim_win_set_cursor(self.for_win, { mid_line, 0 })
        vim.api.nvim_command("normal! zz")
        vim.api.nvim_win_set_cursor(self.for_win, { self.focus_node.name_range["start"].line, self.focus_node.name_range["start"].character })
      end
    elseif self.config.source_buffer.reorient == "mid" then
      vim.api.nvim_command("normal! zz")
    elseif self.config.source_buffer.reorient == "top" then
      vim.api.nvim_command("normal! zt")
    end

    vim.api.nvim_set_current_win(self.mid.winid)
    self.state.leaving_window_for_reorientation = false
  end
end

function display:clear_highlights()
  vim.api.nvim_buf_clear_highlight(self.for_buf, state.ns, 0, -1)
end

function display:redraw()
  local node = self.focus_node
  buffer.fill_lsp(self.mid, node, self.config)

  if node.children then
    if node.memory then
      buffer.fill_lsp(self.right, node.children[node.memory], self.config)
    else
      buffer.fill_lsp(self.right, node.children[1], self.config)
    end
  else
    buffer.clear(self.right)
  end

  if node.parent.is_root then
    -- buffer.clear(self.left)
    buffer.fill_curbufs(self.left, self.for_buf, self.config)
  else
    buffer.fill_lsp(self.left, node.parent, self.config)
  end
end

function display:close()
  self.state.closed = true
  vim.api.nvim_set_option("guicursor", self.state.user_gui_cursor)
  if self.state.source_buffer_scrolloff then
    vim.api.nvim_set_option("scrolloff", self.state.source_buffer_scrolloff)
  end
  self.layout:unmount()
  self:clear_highlights()
end

return display
