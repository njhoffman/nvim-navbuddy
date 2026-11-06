local get_size = function(node)
  local size = { w = 0, h = 0 }
  local icon_size = 3
  if type(node.children) == 'table' then
    size.h = #node.children > size.h and #node.children or size.h
    for _, child_node in ipairs(node.children) do
      local text = ' ' .. icon_size .. child_node.name
      size.w = #text > size.w and #text or size.w
    end
  end
  return size
end

local function get_dimensions(node)
  local margin = 5
  local sizes = {
    left = {},
    mid = get_size(node),
    right = {},
    totals = { w = 0, h = 0 },
    max = { w = 0, h = 0 },
  }
  if sizes.mid.w > 0 then
    sizes.totals.h = sizes.totals.h + sizes.mid.h + margin
    sizes.totals.w = sizes.totals.w + sizes.mid.w + margin
  end

  if node.children then
    local right_node = node.children[1] or node.children[node.memory]
    -- self.right, node.children[node.memory] node.children[1], self.config
    sizes.right = get_size(right_node)
    sizes.right.w = sizes.right.w + margin
    sizes.max.w = sizes.max.w < sizes.right.w and sizes.right.w or sizes.max.w
    sizes.max.h = sizes.max.h < sizes.right.h and sizes.right.h or sizes.max.h
    sizes.totals.w = sizes.right.w + sizes.totals.w
  end
  if type(node.parent) == 'table' then
    sizes.left = get_size(node.parent)
    sizes.left.w = sizes.left.w + margin
    sizes.max.w = sizes.max.w < sizes.left.w and sizes.left.w or sizes.max.w
    sizes.max.h = sizes.max.h < sizes.left.h and sizes.left.h or sizes.max.h
    sizes.totals.w = sizes.totals.w + sizes.left.w
  end
  return sizes
end

local apply_bounds = function(size_opts, col_sizes)
  local size = { w = col_sizes.w, h = col_sizes.h }
  -- size.w = size_opts.max_w and size_opts.max_w < size.w and size_opts.max_w or size.w
  size.h = size_opts.max_h and size_opts.max_h < size.h and size_opts.max_h or size.h
  -- size.w = size_opts.min_w and size_opts.min_w > size.w and size_opts.min_w or size.w
  size.h = size_opts.min_h and size_opts.min_h > size.h and size_opts.min_h or size.h
  return size
end

local calculate_size = function(size_config, col_sizes)
  local convert_percent = function(num, size, win_size)
    if string.match(tostring(num), '%%$') then
      num = string.gsub(num, '%%', '') / 100
      if size == 'max_w' or size == 'min_w' then
        num = num * win_size.w
      else
        num = num * win_size.h
      end
    end
    return num
  end

  local win_size = { h = vim.api.nvim_win_get_height(0), w = vim.api.nvim_win_get_width(0) }
  for _, size in ipairs({ 'min_h', 'max_h', 'min_w', 'max_w' }) do
    size_config[size] = convert_percent(size_config[size], size, win_size)
  end

  if vim.dbglog then vim.dbglog('\nsize_config**', size_config, '\n**col_sizes', col_sizes) end
  return apply_bounds(size_config, col_sizes)
end

local get_layout_opts = function(focus_node)
  local config = {
    size = {
      max_h = '20%',
      min_h = '5%',
      min_w = '40%',
      max_w = '80%',
      left_w = '30%',
      mid_w = '40%',
      right_w = '30%',
      position = '100%',
    },
  }

  if type(focus_node) == 'nil' then
    return {
      relative = 'editor',
      size = {
        height = config.size.min_h,
        width = config.size.min_w,
      },
      position = config.size.position,
    }
  end

  local col_sizes = get_dimensions(focus_node)

  local calculated_size = calculate_size(config.size, col_sizes)

  if vim.dbglog then vim.dbglog('calculated size', calculated_size) end
  local opts = {
    size = {
      height = calculated_size.h,
      width = calculated_size.w,
    },
    position = config.size.position,
  }
  if vim.dbglog then vim.dbglog('\ncontent**', col_sizes, '\n**parsed', calculated_size) end
  return opts
end

---@param name string
---@param config Navbuddy.config
---@return boolean
local check_integration = function(name, config)
  local enabled = config.integrations[name]

  if enabled == nil or enabled == "auto" then
    local success, _ = pcall(require, name:gsub("_", "-"))
    return success
  end

  return enabled
end

local request_document_symbols

--- Request a buffer's document symbols, retrying while the server reports errors
--- such as a stale document after an edit. navic.request_symbol can't target a
--- buffer that isn't current: without a URI it asks about the current buffer, and
--- it nests a URI it is given.
---@param client vim.lsp.Client
---@param bufnr number
---@param callback fun(err: any, symbols: table?)
---@param opts? { retries?: number, is_cancelled?: fun(): boolean }
request_document_symbols = function(client, bufnr, callback, opts)
  opts = opts or {}
  local retries = opts.retries or 10
  local params = { textDocument = { uri = vim.uri_from_bufnr(bufnr) } }

  local function on_response(err, symbols)
    if opts.is_cancelled and opts.is_cancelled() then
      return
    end
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      return
    end
    if err and retries > 0 then
      vim.defer_fn(function()
        request_document_symbols(client, bufnr, callback, {
          retries = retries - 1,
          is_cancelled = opts.is_cancelled,
        })
      end, 750)
      return
    end
    callback(err, symbols)
  end

  if vim.fn.has("nvim-0.11") == 1 then
    client:request("textDocument/documentSymbol", params, on_response, bufnr)
  else
    client.request("textDocument/documentSymbol", params, on_response, bufnr)
  end
end

--- Pad or shorten text to exactly `width` display cells, cutting on whole characters.
---@param text string
---@param width number
---@return string
local function fit_width(text, width)
  if width <= 0 then
    return ""
  end

  local text_width = vim.fn.strdisplaywidth(text)
  if text_width <= width then
    return text .. string.rep(" ", width - text_width)
  end

  local chars = vim.fn.strchars(text)
  while chars > 0 and vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, chars)) > width - 1 do
    chars = chars - 1
  end
  local shortened = vim.fn.strcharpart(text, 0, chars) .. "…"
  return shortened .. string.rep(" ", width - vim.fn.strdisplaywidth(shortened))
end

return {
  get_layout_opts = get_layout_opts,
  request_document_symbols = request_document_symbols,
  fit_width = fit_width,
  check_integration = check_integration,
  _get_size = get_size,
  _get_dimensions = get_dimensions,
  _apply_bounds = apply_bounds,
}
