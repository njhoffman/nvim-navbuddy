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
  request_document_symbols = request_document_symbols,
  fit_width = fit_width,
  check_integration = check_integration,
}
