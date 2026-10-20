-- Replacement for the deprecated nvim_buf_add_highlight(), built on extmarks.
-- col_end -1 highlights to end of line; ns_id 0/-1 maps to a shared namespace;
-- out-of-range columns are clamped instead of raising.
local M = {}

local fallback_ns

function M.add_highlight(buf, ns_id, hl_group, line, col_start, col_end)
  if not ns_id or ns_id <= 0 then
    fallback_ns = fallback_ns or vim.api.nvim_create_namespace("nvim-navbuddy.add_highlight")
    ns_id = fallback_ns
  end
  local opts = { hl_group = hl_group, end_row = line, end_col = col_end, strict = false }
  if col_end == nil or col_end < 0 then
    opts.end_row, opts.end_col = line + 1, 0
  end
  vim.api.nvim_buf_set_extmark(buf, ns_id, line, math.max(col_start or 0, 0), opts)
  return ns_id
end

return M
