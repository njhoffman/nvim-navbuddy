local state = require('nvim-navbuddy.state')
local buf_utils = require('nvim-navbuddy.buffer.utils')
local highlights = require('nvim-navbuddy.highlights')

local function fill_files(buf, active_bufnr, config)
  local lines = {}

  local active_buf = { idx = nil, hl = nil }
  local curbufs = buf_utils.get_current_buffers(active_bufnr)
  for i, curbuf in ipairs(curbufs) do
    local text = ' ' .. (curbuf.display[1].text or '') .. ' ' .. (curbuf.display[2].text or '')
    if curbuf.data.current then
      active_buf.idx = i
      active_buf.hl = curbuf.display[1].hl
    end
    table.insert(lines, text)
  end

  vim.api.nvim_buf_set_option(buf.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf.bufnr, 'modifiable', false)

  for i, curbuf in ipairs(curbufs) do
    if config.theme == 'hl-line' then
      local hl_group = curbuf.display[1].hl
      if type(hl_group) ~= 'string' or #hl_group < 0 then
        vim.dbglog('ERROR curbuf', curbuf)
      else
        local file_hl = highlights.get_color_from_hl(hl_group)
        local hldark = { fg = highlights.darken(file_hl.foreground, 50) }
        vim.api.nvim_set_hl(0, hl_group .. 'Dim', hldark)
        vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, hl_group .. 'Dim', i - 1, 0, -1)
      end
    elseif config.theme == 'hl-icon' then
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
      hl_group = 'NavbuddyCursorLine',
    })
    vim.api.nvim_win_set_cursor(buf.winid, { active_buf.idx, 0 })
  end
end

return fill_files
