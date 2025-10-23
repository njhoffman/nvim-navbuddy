local navic = require("nvim-navic.lib")
local highlights = require("nvim-navbuddy.highlights")
local nui_popup = require("nui.popup")
local nui_layout = require("nui.layout")

-- local utils = require("nvim-navbuddy.utils")
local state = require("nvim-navbuddy.state")
local buffer = require("nvim-navbuddy.buffer")
local border = require("nvim-navbuddy.border")

local display = {}

function display:new(obj)
  -- Object
  setmetatable(obj, self)
  self.__index = self

  local config = obj.config
  highlights.setup(config)

  local title_popup = nui_popup({
    focusable = false,
    -- border = config.window.sections.title.border or border.get_border(config.window.border, "title"),
    border = {
      style = { " ", "─", "╮", "│", "", "", "", "" },
    },
    win_options = {
      winhighlight = "Comment:NavbuddyNormalTitle,FloatBorder:NavbuddyTitleBorder",
      wrap = false,
    },
    buf_options = {
      modifiable = false,
    },
  })
  -- utils.get_layout_opts(),
  -- vim.api.nvim_open_win(obj.for_buf, false, {
  --   relative = "win",
  --   row = winsize.h - 2,
  --   col = 0,
  --   width = 10,
  --   height = 2,
  -- })
  local layout = nui_layout(
    {
      relative = "editor",
      size = {
        width = "100%",
        height = 3,
      },
      position = { row = "100%", col = 0 },
    },
    nui_layout.Box({
      nui_layout.Box(title_popup, { size = { height = 2 } }),
    }, { dir = "col" })
  )

  obj.layout = layout

  title_popup.panel = "title"

  obj.title = title_popup
  obj.state = {
    leaving_window_for_action = false,
    closed = false,
    user_gui_cursor = nil,
  }

  -- Set filetype
  vim.api.nvim_buf_set_option(obj.title.bufnr, "filetype", "Navbuddy")

  local augroup = vim.api.nvim_create_augroup("Navbuddy", { clear = false })
  vim.api.nvim_clear_autocmds({ buffer = obj.title.bufnr })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    buffer = obj.for_buf,
    callback = function()
      -- local context_data = navic.get_context_data(bufnr)
      local context_data = navic.get_context_data(obj.for_buf)
      local curr_node = context_data[#context_data]
      if self.focus_node ~= curr_node then
        obj.focus_node = curr_node
        vim.dbglog("redrawing", curr_node.is_root, vim.tbl_keys(curr_node))
        obj:redraw()
      else
        vim.dbglog("same node", obj.focus_node.name, curr_node.name)
      end
      --
      -- obj:clear_highlights()
    end,
  })
  -- vim.api.nvim_create_autocmd("VimResized", {
  --   group = augroup,
  --   buffer = self.forbuf,
  --   callback = function(arg)
  --     if obj.state.leaving_window_for_action == false and obj.state.closed == false then
  --       obj:close()
  --     end
  --   end,
  -- })

  if not vim.api.nvim_win_is_valid(obj.for_win) then
    return obj:close()
  end

  -- Display
  layout:mount()
  obj:redraw()
  return obj
end

function display:clear_highlights()
  vim.api.nvim_buf_clear_highlight(self.for_buf, state.ns, 0, -1)
end

function display:redraw()
  local node = self.focus_node
  if self.title.winid then
    local winsize = {
      w = vim.api.nvim_win_get_width(self.for_win),
      h = vim.api.nvim_win_get_height(self.for_win),
    }
    local opts = { winsize = winsize }
    local width = buffer.fill_title(self.title, node, self.config, opts)
    width = width > 2 and width or 2
    self.layout:update({
      size = { width = "100%", height = 3 },
    })
  end
end

function display:close()
  self.state.closed = true
  self.layout:unmount()
  -- self:clear_highlights()
end

return display
