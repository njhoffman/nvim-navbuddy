local navic = require('nvim-navic.lib')
local buf_utils = require('nvim-navbuddy.buffer.utils')
local state = require('nvim-navbuddy.state')

-- TODO: figure out why right section window borer not being parsed
local function fill_lsp(buf, node, config)
  local cursor_pos = vim.api.nvim_win_get_cursor(buf.winid)
  buf_utils.clear_buffer(buf)

  local parent = node.parent
  local lines = {}
  local bufwidth = buf._.size.width
  for _, child_node in ipairs(parent.children) do
    local text = ' ' .. config.icons[child_node.kind] .. child_node.name
    if #text > bufwidth then
      text = string.sub(text, 0, bufwidth - 1) .. '…'
    end
    local spacing = bufwidth - #text
    text = text .. string.rep(' ', spacing)
    table.insert(lines, text)
  end

  vim.api.nvim_buf_set_option(buf.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf.bufnr, 'modifiable', false)
  if cursor_pos[1] ~= node.index then
    cursor_pos[1] = node.index
  end

  for i, child_node in ipairs(parent.children) do
    local sfx = navic.adapt_lsp_num_to_str(child_node.kind)
    local hl_group = 'Navbuddy' .. sfx
    if config.theme == 'hl-line' then
      hl_group = buf.panel ~= 'mid' and hl_group .. 'Dim' or hl_group
      vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, hl_group, i - 1, 0, -1)
      -- u.add_hl(buf.bufnr, namespace, "Navbuddy" .. sfx .. 'Text', i - 1, 0, 1)
      -- u.add_hl(buf.bufnr, namespace, "Navbuddy" .. sfx, i - 1, 1, 4)
      -- u.add_hl(buf.bufnr, namespace, "Navbuddy" .. sfx .. 'Text', i - 1, 0, 1)
      if config.node_markers.enabled then
        -- local markercol = buf._.size.width - 10
        local markercol = #lines[i]
        local markersym = child_node.children ~= nil and config.node_markers.icons.branch
          or i == cursor_pos[1] and config.node_markers.icons.leaf_selected
          or config.node_markers.icons.leaf
        vim.api.nvim_buf_set_extmark(buf.bufnr, state.ns, i - 1, markercol, {
          virt_text = {
            {
              markersym,
              i == cursor_pos[1] and { 'NavbuddyCursorLine', hl_group } or hl_group,
            },
          },
          virt_text_pos = 'overlay', -- eol, right_align, overlay
          virt_text_hide = false,
        })
      end
    elseif config.theme == 'hl-icon' then
      vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, 'Navbuddy' .. sfx, i - 1, 2, 4)
    end
  end
  --  fill_lsp   …   if   if   vim.api.nvim_buf_set_extmark   virt_text
  -- 84-88 -> 67-68, 50-51 -> 34-35, 39-40 -> 27-28, 28-29 -> 20-21, 16-17 -> 14-15, -1-0 -> 0,1
  local hl_group = 'Navbuddy' .. navic.adapt_lsp_num_to_str(node.kind)
  hl_group = buf.panel ~= 'mid' and hl_group .. 'Dim' or hl_group
  vim.api.nvim_buf_set_extmark(
    buf.bufnr,
    state.ns,
    cursor_pos[1] - 1,
    0,
    { end_row = cursor_pos[1], hl_eol = true, hl_group = hl_group }
  )

  if buf.panel ~= 'title' then
    vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, 'NavbuddyCursorLine', cursor_pos[1] - 1, 0, -1)
    vim.api.nvim_buf_set_extmark(
      buf.bufnr,
      state.ns,
      cursor_pos[1] - 1,
      0,
      { end_row = cursor_pos[1], hl_eol = true, hl_group = 'NavbuddyCursorLine' }
    )
    vim.api.nvim_win_set_cursor(buf.winid, cursor_pos)
  end
end

return fill_lsp
