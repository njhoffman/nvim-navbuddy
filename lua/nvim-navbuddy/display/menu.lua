local highlights = require("nvim-navbuddy.highlights")
local nui_popup = require("nui.popup")
local nui_layout = require("nui.layout")
local nui_text = require("nui.text")

-- local utils = require("nvim-navbuddy.utils")
local state = require("nvim-navbuddy.state")
local buffer = require("nvim-navbuddy.buffer")
local border = require("nvim-navbuddy.border")

local display = {}

function display:new(obj)
  highlights.setup()

  -- Object
  setmetatable(obj, self)
  self.__index = self

  local config = obj.config

  obj.winblend = config.window.winblend

  local win_options = {
    wrap = false,
    cursorline = false,
    winhighlight = "Normal:NavbuddyNormalFloat,FloatBorder:NavbuddyFloatBorder",
  }
  if obj.winblend ~= nil then
    win_options = vim.tbl_deep_extend("force", win_options, {
      winblend = obj.winblend,
    })
  end

  local title_popup = nui_popup({
    focusable = false,
    border = config.window.sections.title.border or border.get_border(config.window.border, "title"),
    win_options = win_options,
    buf_options = {
      modifiable = false,
    },
  })

  -- NUI elements
  local left_popup = nui_popup({
    focusable = false,
    border = config.window.sections.left.border or border.get_border(config.window.border, "left"),
    win_options = win_options,
    buf_options = {
      modifiable = false,
    },
  })

  local mid_popup = nui_popup({
    enter = true,
    border = config.window.sections.mid.border or border.get_border(config.window.border, "mid"),
    win_options = vim.tbl_deep_extend("force", {
      scrolloff = config.window.scrolloff,
    }, win_options),
    buf_options = {
      modifiable = false,
    },
  })

  local lsp_name = {
    bottom = nui_text("[" .. obj.lsp_name .. "]", "NavbuddyFloatBorder"),
    bottom_align = "right",
  }

  if
    config.window.sections.right.border == "none"
    or config.window.border == "none"
    or config.window.sections.right.border == "shadow"
    or config.window.border == "shadow"
    or config.window.sections.right.border == "solid"
    or config.window.border == "solid"
  then
    lsp_name = nil
  end

  local right_border = config.window.sections.right.border or border.get_border(config.window.border, "right")
  right_border.text = lsp_name
  local right_popup = nui_popup({
    focusable = false,
    border = right_border,
    win_options = win_options,
    buf_options = {
      modifiable = false,
    },
  })

  -- utils.get_layout_opts(),

  local layout = nui_layout(
    {
      relative = "editor",
      size = {
        width = 80,
        height = 15,
      },
      position = "98%",
    },
    nui_layout.Box({
      nui_layout.Box(title_popup, { size = {
        height = 2,
        width = "100%",
      } }),
      nui_layout.Box({
        nui_layout.Box(left_popup, { size = { width = "30%" } }),
        nui_layout.Box(mid_popup, { size = { width = "40%" } }),
        nui_layout.Box(right_popup, { grow = 1 }),
      }, { dir = "row", size = { height = 13 } }),
    }, { dir = "col" })
  )

  obj.layout = layout

  left_popup.panel = "left"
  mid_popup.panel = "mid"
  right_popup.panel = "right"
  title_popup.panel = "title"

  obj.left = left_popup
  obj.mid = mid_popup
  obj.right = right_popup
  obj.title = title_popup
  obj.state = {
    leaving_window_for_action = false,
    leaving_window_for_reorientation = false,
    closed = false,
    source_buffer_scrolloff = nil,
    -- user_gui_cursor = nil,
  }

  -- Set filetype
  vim.api.nvim_set_option_value("filetype", "Navbuddy", { buf = obj.mid.bufnr })

  -- Hidden cursor
  obj.state.user_gui_cursor = vim.api.nvim_get_option_value("guicursor", { scope = "global" })
  if obj.state.user_gui_cursor ~= "" then
    vim.api.nvim_set_option_value("guicursor", "a:NavbuddyCursor", { scope = "global" })
  end

  -- User Scrolloff
  if config.source_buffer.scrolloff then
    obj.state.source_buffer_scrolloff = vim.api.nvim_get_option_value("scrolloff", { win = obj.for_win })
    vim.api.nvim_set_option_value("scrolloff", config.source_buffer.scrolloff, { win = obj.for_win })
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
        obj.focus_node = obj.focus_node.parent.children[cursor_pos[1]]
        -- obj.layout:update(utils.get_layout_opts(obj.focus_node))
        obj:redraw()
      end

      obj.focus_node.parent.memory = obj.focus_node.index

      obj:clear_highlights()
      obj:focus_range()
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    buffer = self.forbuf,
    callback = function(arg)
      if
        obj.state.leaving_window_for_action == false
        and obj.state.leaving_window_for_reorientation == false
        and obj.state.closed == false
      then
        obj:close()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = augroup,
    buffer = obj.mid.bufnr,
    callback = function()
      if
        obj.state.leaving_window_for_action == false
        and obj.state.leaving_window_for_reorientation == false
        and obj.state.closed == false
      then
        obj:close()
      end
    end,
  })

  vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = augroup,
    buffer = obj.mid.bufnr,
    callback = function()
      vim.api.nvim_set_option("guicursor", obj.state.user_gui_cursor)
    end,
  })

  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = augroup,
    buffer = obj.mid.bufnr,
    callback = function()
      if obj.state.user_gui_cursor ~= "" then
        vim.api.nvim_set_option("guicursor", "a:NavbuddyCursor")
      end
    end,
  })

  -- Mappings
  for i, v in pairs(config.mappings) do
    obj.mid:map("n", i, function()
      v.callback(obj)
    end, { nowait = true })
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
        vim.api.nvim_buf_add_highlight(
          self.for_buf,
          state.ns,
          highlight,
          range["start"].line - 1,
          range["start"].character,
          range["end"].character
        )
      else
        vim.api.nvim_buf_add_highlight(
          self.for_buf,
          state.ns,
          highlight,
          range["start"].line - 1,
          range["start"].character,
          -1
        )
        vim.api.nvim_buf_add_highlight(
          self.for_buf,
          state.ns,
          highlight,
          range["end"].line - 1,
          0,
          range["end"].character
        )
        for i = range["start"].line, range["end"].line - 2, 1 do
          vim.api.nvim_buf_add_highlight(self.for_buf, state.ns, highlight, i, 0, -1)
        end
      end
    end
  end

  if self.config.source_buffer.follow_node then
    self:reorient(self.for_win, self.config.source_buffer.reorient)
  end
end

-- function display:focus_range()
--   local ranges = nil
--
--   if vim.deep_equal(self.focus_node.scope, self.focus_node.name_range) then
--     ranges = { { 'NavbuddyScope', self.focus_node.scope } }
--   else
--     ranges = { { 'NavbuddyScope', self.focus_node.scope }, { 'NavbuddyName', self.focus_node.name_range } }
--   end
--
--   if self.config.source_buffer.highlight then
--     for _, v in ipairs(ranges) do
--       local highlight, range = unpack(v)
--
--       if range['start'].line == range['end'].line then
--         vim.api.nvim_buf_add_highlight(
--           self.for_buf,
--           state.ns,
--           highlight,
--           range['start'].line - 1,
--           range['start'].character,
--           range['end'].character
--         )
--       else
--         vim.api.nvim_buf_add_highlight(
--           self.for_buf,
--           state.ns,
--           highlight,
--           range['start'].line - 1,
--           range['start'].character,
--           -1
--         )
--         vim.api.nvim_buf_add_highlight(
--           self.for_buf,
--           state.ns,
--           highlight,
--           range['end'].line - 1,
--           0,
--           range['end'].character
--         )
--         for i = range['start'].line, range['end'].line - 2, 1 do
--           vim.api.nvim_buf_add_highlight(self.for_buf, state.ns, highlight, i, 0, -1)
--         end
--       end
--     end
--   end
--
--   if self.config.source_buffer.follow_node then
--     self:reorient(self.for_win, self.config.source_buffer.reorient)
--   end
-- end

function display:reorient(ro_win, reorient_method)
  vim.api.nvim_win_set_cursor(
    ro_win,
    { self.focus_node.name_range["start"].line, self.focus_node.name_range["start"].character }
  )

  self.state.leaving_window_for_reorientation = true
  vim.api.nvim_set_current_win(ro_win)

  if reorient_method == "smart" then
    local total_lines = self.focus_node.scope["end"].line - self.focus_node.scope["start"].line + 1

    if total_lines >= vim.api.nvim_win_get_height(ro_win) then
      vim.api.nvim_command("normal! zt")
    else
      local mid_line = bit.rshift(self.focus_node.scope["start"].line + self.focus_node.scope["end"].line, 1)
      vim.api.nvim_win_set_cursor(ro_win, { mid_line, 0 })
      vim.api.nvim_command("normal! zz")
      vim.api.nvim_win_set_cursor(
        ro_win,
        { self.focus_node.name_range["start"].line, self.focus_node.name_range["start"].character }
      )
    end
  elseif reorient_method == "mid" then
    vim.api.nvim_command("normal! zz")
  elseif reorient_method == "top" then
    vim.api.nvim_command("normal! zt")
  end

  vim.api.nvim_set_current_win(self.mid.winid)
  self.state.leaving_window_for_reorientation = false
end

function display:show_preview()
  vim.api.nvim_win_set_buf(self.right.winid, self.for_buf)

  vim.api.nvim_win_set_option_value(
    "winhighlight",
    "Normal:NavbuddyNormalFloat,FloatBorder:NavbuddyFloatBorder",
    { win = self.right.winid }
  )
  vim.api.nvim_set_option_value("signcolumn", "no", { win = self.right.winid })
  vim.api.nvim_set_option_value("foldlevel", 100, { win = self.right.winid })
  vim.api.nvim_set_option_value("wrap", false, { win = self.right.winid })
  if self.winblend then
    vim.api.nvim_win_set_option(self.right.winid, "winblend", self.winblend)
    -- else
    --   vim.api.nvim_win_set_option(
    --     self.right.winid,
    --     "winhighlight",
    --     "Normal:NavbuddyNormalFloat,FloatBorder:NavbuddyFloatBorder"
    --   )
  end

  self:reorient(self.right.winid, "smart")
end

function display:hide_preview()
  vim.api.nvim_win_set_buf(self.right.winid, self.right.bufnr)
  local node = self.focus_node
  if node.children then
    if node.memory then
      buffer.fill_lsp(self.right, node.children[node.memory], self.config)
    else
      buffer.fill_lsp(self.right, node.children[1], self.config)
    end
  else
    buffer.clear(self.right)
  end
end

function display:clear_highlights()
  vim.api.nvim_buf_clear_highlight(self.for_buf, state.ns, 0, -1)
end

function display:redraw()
  local node = self.focus_node
  buffer.fill_lsp(self.mid, node, self.config)

  local preview_method = self.config.window.sections.right.preview

  if preview_method == "always" then
    self:show_preview()
  else
    if node.children then
      if node.memory then
        buffer.fill_lsp(self.right, node.children[node.memory], self.config)
      else
        buffer.fill_lsp(self.right, node.children[1], self.config)
      end
    else
      if preview_method == "leaf" then
        self:show_preview()
      else
        buffer.clear(self.right)
      end
    end
  end

  if node.parent.is_root then
    -- buffer.clear(self.left)
    buffer.fill_files(self.left, self.for_buf, self.config)
  else
    buffer.fill_lsp(self.left, node.parent, self.config)
  end
  local winsize = {
    w = vim.api.nvim_win_get_width(self.title.winid),
    h = vim.api.nvim_win_get_height(self.title.winid),
  }
  local opts = { winsize = winsize, align = "center", separator = "  " }
  buffer.fill_title(self.title, node, self.config, opts)
end

function display:close()
  self.state.closed = true
  self.layout:unmount()
  self:clear_highlights()

  vim.api.nvim_set_option_value("guicursor", self.state.user_gui_cursor, { scope = "global" })
  if self.state.source_buffer_scrolloff then
    vim.api.nvim_set_option_value("scrolloff", self.state.source_buffer_scrolloff, { win = self.for_win })
  end
end

return display
