local navic = require('nvim-navic.lib')
local buf_utils = require('nvim-navbuddy.buffer.utils')
local state = require('nvim-navbuddy.state')

local function node_chain_length(node_chain, separator)
  local path_length = 0
  for i, node in ipairs(node_chain) do
    if not node.is_root then
      if i == 1 then
        path_length = 2 + #node.name
      else
        path_length = path_length + #separator + #node.name
      end
    end
  end
  return path_length
end

local function fill_title(buf, focus_node, config, opts)
  -- local icon = config.icons[focus_node.kind]
  -- local node_path = icon .. focus_node.name
  -- local sfx = navic.adapt_lsp_num_to_str(focus_node.kind)
  -- local hls = { { "Navbuddy" .. sfx, 1, 3 } }
  buf_utils.clear_buffer(buf)
  opts = opts or { align = 'left', separator = '  ' }
  local node_chain = { focus_node }
  local parent_node = focus_node.parent

  local winwidth = opts.winsize.w or vim.api.nvim_win_get_width(buf)

  while type(parent_node) ~= 'nil' and type(parent_node.name) ~= 'nil' do
    table.insert(node_chain, parent_node)
    parent_node = parent_node.parent
  end

  local rev = {}
  for i = #node_chain, 1, -1 do
    rev[#rev + 1] = node_chain[i]
  end
  node_chain = rev

  local node_names = {}
  local chain_length = 0
  for i, node in ipairs(node_chain) do
    if not node.is_root then
      if i == 1 then
        chain_length = chain_length + #node.name + 2
      else
        chain_length = chain_length + #opts.separator + #node.name
      end
      table.insert(node_names, vim.trim(node.name))
    end
  end

  local truncate_i = #node_chain > 2 and 2 or 1
  while chain_length >= winwidth - 3 do
    chain_length = chain_length - #node_names[truncate_i] + 1
    node_names[truncate_i] = '…'
    truncate_i = truncate_i == #node_names and 1 or (truncate_i + 1)
  end
  -- vim.dbglog('2', chain_length, node_names)

  local icon_n = 0
  local node_path = ''
  local hls = {}
  for i, node in ipairs(node_chain) do
    local icon = config.icons[node.kind]
    local sfx = navic.adapt_lsp_num_to_str(node.kind)
    if not node.is_root then
      if i == 1 then
        table.insert(hls, { 'Navbuddy' .. sfx, #node_path - 1, #node_path })
        node_path = icon .. node_names[i]
      else
        if i == #node_chain then
          table.insert(hls, { 'Navbuddy' .. sfx, #node_path + 4, #node_path + 5 })
        else
          table.insert(hls, { 'Navbuddy' .. sfx, #node_path + 4, #node_path + 5 })
        end
        node_path = node_path .. opts.separator .. icon .. node_names[i]
      end
      icon_n = icon_n + 1
    end
  end
  node_path = node_path:gsub('^%s*(.-)%s*$', '%1')
  local icon_width = icon_n * 2
  -- icon_width = icon_width > 0 and icon_width or 0

  local indent = 0
  if opts.align == 'center' then
    indent = math.floor((winwidth - #node_path) / 2) + icon_width
  end
  node_path = string.rep('', indent, ' ') .. node_path
  -- vim.dbglog('3', indent, node_path, hls)

  vim.api.nvim_buf_set_option(buf.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, { node_path })
  vim.api.nvim_buf_set_option(buf.bufnr, 'modifiable', false)

  for _, hl in ipairs(hls) do
    if hl[2] + indent < winwidth and hl[3] < winwidth then
      vim.api.nvim_buf_add_highlight(buf.bufnr, state.ns, hl[1], 0, indent + hl[2], indent + hl[3])
    end
  end
end

return fill_title
