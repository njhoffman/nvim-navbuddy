local highlights = require("nvim-navbuddy.highlights")
local nui_popup = require("nui.popup")
local nui_layout = require("nui.layout")
local nui_text = require("nui.text")

local utils = require("nvim-navbuddy.utils")
local state = require("nvim-navbuddy.state")
local buffer = require("nvim-navbuddy.buffer")
local border = require("nvim-navbuddy.border")

local display = {}

local NORMAL_WINHIGHLIGHT = "Normal:NavbuddyNormalFloat,FloatBorder:NavbuddyFloatBorder"
local DIM_WINHIGHLIGHT = "Normal:NavbuddyNormalFloatDim,FloatBorder:NavbuddyFloatBorderDim"

--- Build a section's popup. Options from the section's config win over the
--- defaults and over `opts`.
---@param config Navbuddy.config
---@param section "title"|"left"|"mid"|"right"
---@param opts? { enter?: boolean, focusable?: boolean, border?: table, win_options?: table }
local function section_popup(config, section, opts)
  opts = opts or {}
  local section_config = config.window.sections[section]

  local win_options = vim.tbl_extend("force", {
    wrap = false,
    cursorline = false,
    winhighlight = NORMAL_WINHIGHLIGHT,
    winblend = config.window.winblend,
  }, opts.win_options or {}, section_config.win_options or {})

  local popup = nui_popup({
    enter = opts.enter,
    focusable = opts.focusable or false,
    border = opts.border or border.resolve(section_config.border, config.window.border, section),
    win_options = win_options,
    buf_options = vim.tbl_extend("force", { modifiable = false }, section_config.buf_options or {}),
  })
  popup.panel = section
  popup.normal_winhighlight = win_options.winhighlight
  return popup
end

function display:new(obj)
  -- Object
  setmetatable(obj, self)
  self.__index = self

  local config = obj.config
  highlights.setup(config)

  -- Reopening after help or a picker keeps the original return point
  obj.start_buf = obj.start_buf or obj.for_buf

  obj.winblend = config.window.winblend

  local title_popup = section_popup(config, "title")
  local left_popup = section_popup(config, "left")
  local mid_popup = section_popup(config, "mid", {
    enter = true,
    focusable = true,
    win_options = { scrolloff = config.window.scrolloff },
  })

  local right_border = border.resolve(config.window.sections.right.border, config.window.border, "right")
  if border.supports_text(config.window.sections.right.border or config.window.border) then
    right_border.text = {
      bottom = nui_text("[" .. obj.lsp_name .. "]", "NavbuddyFloatBorder"),
      bottom_align = "right",
    }
  end
  local right_popup = section_popup(config, "right", { border = right_border })

  local layout = nui_layout(
    {
      relative = "editor",
      size = config.window.size,
      position = config.window.position,
    },
    nui_layout.Box({
      nui_layout.Box(title_popup, { size = {
        height = 2,
        width = "100%",
      } }),
      nui_layout.Box({
        nui_layout.Box(left_popup, { size = { width = config.window.sections.left.size } }),
        nui_layout.Box(mid_popup, { size = { width = config.window.sections.mid.size } }),
        nui_layout.Box(right_popup, { grow = 1 }),
      }, { dir = "row", grow = 1 }),
    }, { dir = "col" })
  )

  obj.layout = layout

  obj.left = left_popup
  obj.mid = mid_popup
  obj.right = right_popup
  obj.title = title_popup
  obj.state = {
    leaving_window_for_action = false,
    leaving_window_for_reorientation = false,
    closed = false,
    source_buffer_scrolloff = nil,
    in_buffer_list = false, -- Track if we're navigating buffers in left panel
    buffer_list = nil, -- Store current buffer list
    buffer_focused = false, -- Track if left pane (buffer list) is focused/active
    preview_focused = false, -- Track if right pane (leaf preview) is focused/active
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
        obj:redraw()
      end

      obj.focus_node.parent.memory = obj.focus_node.index

      obj:clear_highlights()
      obj:focus_range()
    end,
  })

  obj.resize_autocmd = vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
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
      vim.api.nvim_set_option_value("guicursor", obj.state.user_gui_cursor, { scope = "global" })
    end,
  })

  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = augroup,
    buffer = obj.mid.bufnr,
    callback = function()
      if obj.state.user_gui_cursor ~= "" then
        vim.api.nvim_set_option_value("guicursor", "a:NavbuddyCursor", { scope = "global" })
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
        require("nvim-navbuddy.hl").add_highlight(
          self.for_buf,
          state.ns,
          highlight,
          range["start"].line - 1,
          range["start"].character,
          range["end"].character
        )
      else
        require("nvim-navbuddy.hl").add_highlight(
          self.for_buf,
          state.ns,
          highlight,
          range["start"].line - 1,
          range["start"].character,
          -1
        )
        require("nvim-navbuddy.hl").add_highlight(
          self.for_buf,
          state.ns,
          highlight,
          range["end"].line - 1,
          0,
          range["end"].character
        )
        for i = range["start"].line, range["end"].line - 2, 1 do
          require("nvim-navbuddy.hl").add_highlight(self.for_buf, state.ns, highlight, i, 0, -1)
        end
      end
    end
  end

  if self.config.source_buffer.follow_node then
    self:reorient(self.for_win, self.config.source_buffer.reorient)
  end
end

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

  vim.api.nvim_set_option_value("winhighlight", self.right.normal_winhighlight, { win = self.right.winid })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = self.right.winid })
  vim.api.nvim_set_option_value("foldlevel", 100, { win = self.right.winid })
  vim.api.nvim_set_option_value("wrap", false, { win = self.right.winid })
  if self.winblend then
    vim.wo[self.right.winid].winblend = self.winblend
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
  vim.api.nvim_buf_clear_namespace(self.for_buf, state.ns, 0, -1)
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
    local buf_utils = require("nvim-navbuddy.buffer.utils")
    self.state.buffer_list = buf_utils.get_current_buffers(self.for_buf)
    buffer.fill_files(self.left, self.for_buf, self.config)
    self.state.in_buffer_list = true
  else
    buffer.fill_lsp(self.left, node.parent, self.config)
    self.state.in_buffer_list = false
    self.state.buffer_list = nil
    if self.state.buffer_focused then
      self:exit_buffer_focus()
    end
  end
  local winsize = {
    w = vim.api.nvim_win_get_width(self.title.winid),
    h = vim.api.nvim_win_get_height(self.title.winid),
  }
  local opts = { winsize = winsize, align = "center", separator = "  " }
  buffer.fill_title(self.title, node, self.config, opts)
end

--- Switch the source window to the buffer under the buffer list cursor. The
--- switch happens only once that buffer's symbols arrive, so the display never
--- pairs one buffer's nodes with another buffer's text.
---@param opts? { confirm?: boolean } confirm: keep the buffer when Navbuddy is closed
function display:select_buffer(opts)
  if not self.state.in_buffer_list or not self.state.buffer_list then
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(self.left.winid)
  local selected_buf_info = self.state.buffer_list[cursor_pos[1]]
  if not (selected_buf_info and selected_buf_info.data) then
    return
  end

  local target_bufnr = selected_buf_info.data.buffer
  local confirm = opts ~= nil and opts.confirm == true

  -- Any newer selection supersedes a request still in flight
  self.switch_request_id = (self.switch_request_id or 0) + 1

  if target_bufnr == self.for_buf then
    if confirm then
      self:confirm_source()
    end
    return
  end

  self:reload_buffer(target_bufnr, self.switch_request_id, confirm)
end

local function pick_symbol_client(bufnr, preference)
  local clients = vim.tbl_filter(function(client)
    return client.server_capabilities and client.server_capabilities.documentSymbolProvider
  end, vim.lsp.get_clients({ bufnr = bufnr }))

  for _, name in ipairs(preference or {}) do
    for _, client in ipairs(clients) do
      if client.name == name then
        return client
      end
    end
  end
  return clients[1]
end

function display:reload_buffer(bufnr, request_id, confirm)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Listed buffers can be unloaded, for example the extra files in `nvim a b`
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    pcall(vim.fn.bufload, bufnr)
  end

  local client = pick_symbol_client(bufnr, self.config.lsp.preference)
  if not client then
    vim.notify("No LSP server attached to buffer", vim.log.levels.WARN)
    return
  end

  local navic = require("nvim-navic.lib")

  utils.request_document_symbols(client, bufnr, function(err, symbols)
    if not vim.api.nvim_win_is_valid(self.for_win) then
      return
    end

    if err then
      vim.notify("Could not get symbols for buffer", vim.log.levels.WARN)
      return
    end

    navic.update_data(bufnr, symbols or {})
    navic.update_context(bufnr, { 1, 0 })
    local context_data = navic.get_context_data(bufnr)
    local root_node = context_data and context_data[1]

    if not (root_node and root_node.children and root_node.children[1]) then
      vim.notify("No symbols found in buffer", vim.log.levels.WARN)
      return
    end

    self:commit_buffer_switch(bufnr, root_node.children[1], client.name)
    if confirm then
      self:confirm_source()
    end
  end, {
    is_cancelled = function()
      return request_id ~= self.switch_request_id
    end,
  })
end

function display:commit_buffer_switch(bufnr, focus_node, lsp_name)
  self:clear_highlights()

  vim.api.nvim_win_set_buf(self.for_win, bufnr)
  self.source_entry_cursor = vim.api.nvim_win_get_cursor(self.for_win)

  self.for_buf = bufnr
  self.focus_node = focus_node
  self.lsp_name = lsp_name
  self.right.border:set_text("bottom", nui_text("[" .. lsp_name .. "]", "NavbuddyFloatBorder"), "right")

  self:redraw()
  self:focus_range()
end

--- Make the current buffer the one Navbuddy returns to when it is closed.
function display:confirm_source()
  if self.for_buf ~= self.start_buf then
    self.start_buf = self.for_buf
    self.start_cursor = self.source_entry_cursor or self.start_cursor
  end
end

--- Put the source window back on the buffer and cursor Navbuddy returns to.
function display:restore_start()
  if not vim.api.nvim_buf_is_valid(self.start_buf) then
    return
  end
  if vim.api.nvim_win_get_buf(self.for_win) ~= self.start_buf then
    vim.api.nvim_win_set_buf(self.for_win, self.start_buf)
  end
  vim.api.nvim_win_set_cursor(self.for_win, self.start_cursor)
end

function display:navigate_buffer_list(direction)
  if not self.state.in_buffer_list or not self.state.buffer_list then
    return false
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(self.left.winid)
  local new_pos = cursor_pos[1]

  if direction == "up" and new_pos > 1 then
    new_pos = new_pos - 1
  elseif direction == "down" and new_pos < #self.state.buffer_list then
    new_pos = new_pos + 1
  else
    return false
  end

  vim.api.nvim_win_set_cursor(self.left.winid, { new_pos, 0 })
  return true
end

function display:enter_preview_focus()
  self.state.preview_focused = true
  self:show_preview()
  vim.wo[self.left.winid].winhighlight = DIM_WINHIGHLIGHT
  vim.wo[self.mid.winid].winhighlight = DIM_WINHIGHLIGHT
end

function display:exit_preview_focus()
  self.state.preview_focused = false
  vim.wo[self.left.winid].winhighlight = self.left.normal_winhighlight
  vim.wo[self.mid.winid].winhighlight = self.mid.normal_winhighlight
  self:redraw()
end

function display:enter_buffer_focus()
  self.state.buffer_focused = true
  vim.wo[self.left.winid].cursorline = true
  vim.wo[self.mid.winid].winhighlight = DIM_WINHIGHLIGHT
  vim.wo[self.right.winid].winhighlight = DIM_WINHIGHLIGHT
end

function display:exit_buffer_focus()
  self.state.buffer_focused = false
  vim.wo[self.left.winid].cursorline = false
  vim.wo[self.mid.winid].winhighlight = self.mid.normal_winhighlight
  vim.wo[self.right.winid].winhighlight = self.right.normal_winhighlight
end

function display:close()
  self.state.closed = true
  if self.resize_autocmd then
    pcall(vim.api.nvim_del_autocmd, self.resize_autocmd)
    self.resize_autocmd = nil
  end
  self.switch_request_id = (self.switch_request_id or 0) + 1
  self.layout:unmount()
  self:clear_highlights()

  vim.api.nvim_set_option_value("guicursor", self.state.user_gui_cursor, { scope = "global" })
  if self.state.source_buffer_scrolloff then
    vim.api.nvim_set_option_value("scrolloff", self.state.source_buffer_scrolloff, { win = self.for_win })
  end
end

return display
