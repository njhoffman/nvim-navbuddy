local state = require("nvim-navbuddy.state")

local get_current_buffers = function(active_bufnr)
  local devicons = require("nvim-web-devicons")

  local loclist_items = {}

  local bufnrs = vim.tbl_filter(function(b)
    return 1 == vim.fn.buflisted(b)
  end, vim.api.nvim_list_bufs())

  for _, bufnr in ipairs(bufnrs) do
    -- local bufname = entry.info.name ~= "" and entry.info.name or "[No Name]"
    -- local hidden = entry.info.hidden == 1 and "h" or "a"
    -- local readonly = vim.api.nvim_buf_get_option(entry.bufnr, "readonly") and "=" or " "
    -- local changed = entry.info.changed == 1 and "+" or " "
    -- local indicator = entry.flag .. hidden .. readonly .. changed
    local ignored = false
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
      ignored = true
    end
    -- always ignore terminals
    if string.match(bufname, "term://.*") then
      ignored = true
    end

    if not ignored then
      local name_hl = "BuddyNormal"
      local modified = ""

      -- if bufnr == current_buffer then
      --   name_hl = "BuddyBuffersActive"
      -- end

      if vim.api.nvim_buf_get_option(bufnr, "modified") then
        modified = " *"
      end

      -- sorting = "id"
      local order = bufnr -- if config["buffers"].sorting == "name" then
      --   order = bufname
      -- end

      local fileparts = vim.split(bufname, "/")
      local filename = fileparts[#fileparts]

      -- local numbers_text = {}
      -- numbers_text = { text = buffer .. " ", hl = "SidebarNvimBuffersNumber" }

      local icon = { devicons.get_icon(bufname) }
      loclist_items[#loclist_items + 1] = {
        group = "buffers",
        display = {
          { text = icon[1], hl = icon[2] },
          -- numbers_text,
          { text = filename, hl = icon[2] },
        },
        data = {
          buffer = bufnr,
          filepath = bufname,
          name = filename,
          current = tonumber(active_bufnr) == tonumber(bufnr),
        },
        order = order,
      }
    end
  end
  return loclist_items
end

local merge = function(...)
  return vim.tbl_deep_extend("force", ...)
end

local function clear_buffer(buf)
  vim.api.nvim_win_set_buf(buf.winid, buf.bufnr)

  vim.api.nvim_win_set_option(buf.winid, "signcolumn", "no")
  vim.api.nvim_win_set_option(buf.winid, "foldlevel", 100)
  vim.api.nvim_win_set_option(buf.winid, "wrap", true)

  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf.bufnr, 0, -1, false, {})
  vim.api.nvim_buf_set_option(buf.bufnr, "modifiable", false)
  for _, extmark in ipairs(vim.api.nvim_buf_get_extmarks(buf.bufnr, state.ns, 0, -1, {})) do
    vim.api.nvim_buf_del_extmark(buf.bufnr, state.ns, extmark[1])
  end
end

return { clear_buffer = clear_buffer, get_current_buffers = get_current_buffers }
