local navic = require("nvim-navic.lib")
local state = require("nvim-navbuddy.state")
local utils = require("nvim-navbuddy.utils")
local highlights = require("nvim-navbuddy.highlights")

local function clear_buffer(buf)
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, {})
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", false)
end

local function update_title(buf, focus_node, config)
  -- local icon = config.icons[focus_node.kind]
  -- local node_path = icon .. focus_node.name
  -- local sfx = navic.adapt_lsp_num_to_str(focus_node.kind)
  -- local hls = { { "Navbuddy" .. sfx, 1, 3 } }

  local node_chain = { focus_node }
  local parent_node = focus_node.parent
  while type(parent_node) ~= "nil" and type(parent_node.name) ~= "nil" do
    table.insert(node_chain, parent_node)
    parent_node = parent_node.parent
  end

  local rev = {}
  for i = #node_chain, 1, -1 do
    rev[#rev + 1] = node_chain[i]
  end
  node_chain = rev

  local node_path = ""
  local hls = {}
  for i, node in ipairs(node_chain) do
    local icon = config.icons[node.kind]
    local sfx = navic.adapt_lsp_num_to_str(node.kind)
    if i == 1 then
      table.insert(hls, { "Navbuddy" .. sfx, #node_path + 0, #node_path + 3 })
      node_path = icon .. node.name
    else
      table.insert(hls, { "Navbuddy" .. sfx, #node_path + 4, #node_path + 7 })
      node_path = node_path .. "  " .. icon .. node.name
    end
  end
  node_path = node_path:gsub("^%s*(.-)%s*$", "%1")
  local winwidth = vim.api.nvim_win_get_width(buf.winid)

  -- TODO: why do I have to subtract 10 from nodepath here? stupid
  local indent = math.floor((winwidth - #node_path + 10) / 2)
  node_path = string.rep("", indent, " ") .. node_path
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, { node_path })
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", false)
  for _, hl in ipairs(hls) do
    if hl[2] + indent < winwidth and hl[3] < winwidth then
      vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, hl[1], 0, indent + hl[2], indent + hl[3])
    end
  end
end

-- TODO: figure out why right section window borer not being parsed
local function fill_lsp(buf, node, config)
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
    local sfx = navic.adapt_lsp_num_to_str(child_node.kind)
    if config.theme == "hl-line1" then
      local hl_group = "Navbuddy" .. sfx
      hl_group = buf.panel ~= "mid" and hl_group .. "Dim" or hl_group
      vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, hl_group, i - 1, 0, -1)
      -- u.add_hl(buf.bufnr, namespace, "Navbuddy" .. sfx .. 'Text', i - 1, 0, 1)
      -- u.add_hl(buf.bufnr, namespace, "Navbuddy" .. sfx, i - 1, 1, 4)
      -- u.add_hl(buf.bufnr, namespace, "Navbuddy" .. sfx .. 'Text', i - 1, 0, 1)
    elseif config.theme == "hl-icons1" then
      vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, "Navbuddy" .. sfx, i - 1, 2, 4)
    end
  end

  if cursor_pos[1] ~= node.index then
    cursor_pos[1] = node.index
  end

  local hl_group = "Navbuddy" .. navic.adapt_lsp_num_to_str(node.kind)
  hl_group = buf.panel ~= "mid" and hl_group .. "Dim" or hl_group
  vim.api.nvim_buf_set_extmark(
    buf.bufnr,
    state.ns,
    cursor_pos[1] - 1,
    0,
    { end_row = cursor_pos[1], hl_eol = true, hl_group = hl_group }
  )
  vim.api.nvim_buf_set_extmark(
    buf.bufnr,
    state.ns,
    cursor_pos[1] - 1,
    0,
    { end_row = cursor_pos[1], hl_eol = true, hl_group = "NavbuddyCursorLine" }
  )
  vim.api.nvim_win_set_cursor(buf.winid, cursor_pos)
end

local function fill_curbufs(buf, active_bufnr, config)
  local lines = {}

  local active_buf = { idx = nil, hl = nil }
  local curbufs = utils.get_current_buffers(active_bufnr)
  for i, curbuf in ipairs(curbufs) do
    local text = " " .. (curbuf.display[1].text or "") .. " " .. (curbuf.display[2].text or "")
    if curbuf.data.current then
      active_buf.idx = i
      active_buf.hl = curbuf.display[1].hl
    end
    table.insert(lines, text)
  end

  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", false)

  for i, curbuf in ipairs(curbufs) do
    if config.theme == "hl-line1" then
      local hl_group = curbuf.display[1].hl
      if type(hl_group) ~= "string" or #hl_group < 0 then
        vim.dbglog("ERROR curbuf", curbuf)
      else
        local file_hl = highlights.get_color_from_hl(hl_group)
        local hldark = { fg = highlights.darken(file_hl.foreground, 50) }
        vim.api.nvim_set_hl(0, hl_group .. "Dim", hldark)
        vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, hl_group .. "Dim", i - 1, 0, -1)
      end
    elseif config.theme == "hl-icons1" then
      vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, curbuf.display[1].hl, i - 1, 2, 4)
    end
  end

  if active_buf.idx ~= nil then
    vim.api.nvim_buf_set_extmark(buf.bufnr, state.ns, active_buf.idx - 1, 0, {
      end_row = active_buf.idx,
      hl_eol = true,
      hl_group = active_buf.hl,
    })
    vim.api.nvim_buf_set_extmark(buf.bufnr, state.ns, active_buf.idx - 1, 0, {
      end_row = active_buf.idx,
      hl_eol = true,
      hl_group = "NavbuddyCursorLine",
    })
    vim.api.nvim_win_set_cursor(buf.winid, { active_buf.idx, 0 })
  end
end

return {
  update_title = update_title,
  clear = clear_buffer,
  fill_lsp = fill_lsp,
  fill_curbufs = fill_curbufs,
}
