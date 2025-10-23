local navic = require("nvim-navic.lib")
local nui_menu = require("nui.menu")

local menu_display = require("nvim-navbuddy.display.menu")
local title_display = require("nvim-navbuddy.display.title")
local state = require("nvim-navbuddy.state")

local function choose_lsp_menu(for_buf, make_request)
  local style = nil

  if config.window.border ~= nil and config.window.border ~= "None" then
    style = config.window.border
  else
    style = "single"
  end

  local min_width = 23
  local lines = {}

  for _, v in ipairs(state.attached_clients[for_buf]) do
    min_width = math.max(min_width, #v.name)
    table.insert(lines, nui_menu.item(v.id .. ":" .. v.name))
  end

  local min_height = #lines

  local selection = nil

  local menu = nui_menu({
    relative = "editor",
    position = "50%",
    border = {
      style = style,
      text = {
        top = "[Choose LSP Client]",
        top_align = "center",
      },
    },
  }, {
    lines = lines,
    min_width = min_width,
    min_height = min_height,
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "q", "<C-c>" },
      submit = { "<CR>", "<Space>", "l" },
    },
    on_close = function() end,
    on_submit = function(item)
      selection =
        { id = tonumber(string.match(item.text, "%d+")), name = string.sub(string.match(item.text, ":.+"), 2) }
      make_request(selection)
    end,
  })

  menu:mount()
end

local function request(for_buf, _handler)
  local function make_request(client)
    navic.request_symbol(for_buf, function(bufnr, symbols)
      navic.update_data(bufnr, symbols)
      navic.update_context(bufnr)
      local context_data = navic.get_context_data(bufnr)

      local curr_node = context_data[#context_data]

      _handler(for_buf, curr_node, client.name)
    end, client)
  end

  if #state.attached_clients[for_buf] == 1 then
    make_request(state.attached_clients[for_buf][1])
  elseif config.lsp.preference ~= nil then
    local found = false

    for _, preferred_lsp in ipairs(config.lsp.preference) do
      for _, attached_lsp in ipairs(state.attached_clients[for_buf]) do
        if preferred_lsp == attached_lsp.name then
          state.attached_clients[for_buf] = { attached_lsp }
          found = true
          make_request(attached_lsp)
          break
        end
      end

      if found then
        break
      end
    end

    if not found then
      choose_lsp_menu(for_buf, make_request)
    end
  else
    choose_lsp_menu(for_buf, make_request)
  end
end

local function menu_handler(bufnr, curr_node, lsp_name)
  if curr_node.is_root then
    if curr_node.children then
      local curr_line = vim.api.nvim_win_get_cursor(0)[1]
      local closest_dist = math.abs(curr_line - curr_node.children[1].scope["start"].line)
      local closest_node = curr_node.children[1]

      for _, node in ipairs(curr_node.children) do
        if math.abs(curr_line - node.scope["start"].line) < closest_dist then
          closest_dist = math.abs(curr_line - node.scope["start"].line)
          closest_node = node
        end
      end

      curr_node = closest_node
    else
      return
    end
  end

  local winid = vim.fn.bufwinid(bufnr)
  menu_display:new({
    for_buf = bufnr,
    for_win = winid,
    start_cursor = vim.api.nvim_win_get_cursor(winid),
    focus_node = curr_node,
    config = config,
    lsp_name = lsp_name,
  })
end

local function title_handler(bufnr, curr_node, lsp_name)
  if curr_node.is_root then
    if curr_node.children then
      local curr_line = vim.api.nvim_win_get_cursor(0)[1]
      local closest_dist = math.abs(curr_line - curr_node.children[1].scope["start"].line)
      local closest_node = curr_node.children[1]

      for _, node in ipairs(curr_node.children) do
        if math.abs(curr_line - node.scope["start"].line) < closest_dist then
          closest_dist = math.abs(curr_line - node.scope["start"].line)
          closest_node = node
        end
      end
      curr_node = closest_node
    else
      return
    end
  end

  local winid = vim.fn.bufwinid(bufnr)
  title_display:new({
    for_buf = bufnr,
    for_win = winid,
    start_cursor = vim.api.nvim_win_get_cursor(winid),
    focus_node = curr_node,
    config = config,
    lsp_name = lsp_name,
  })
end

local function open(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if state.mode == "title" then
    request(bufnr, title_handler)
  else
    request(bufnr, menu_handler)
  end
end

local function attach(client, bufnr)
  if not client.server_capabilities.documentSymbolProvider then
    if not vim.g.navbuddy_silence then
      vim.notify(
        'nvim-navbuddy: Server "' .. client.name .. '" does not support documentSymbols.',
        vim.log.levels.ERROR
      )
    end
    return
  end

  if state.attached_clients[bufnr] == nil then
    state.attached_clients[bufnr] = {}
  end
  table.insert(state.attached_clients[bufnr], client)

  local navbuddy_augroup = vim.api.nvim_create_augroup("navbuddy", { clear = false })
  vim.api.nvim_clear_autocmds({
    buffer = bufnr,
    group = navbuddy_augroup,
  })
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function()
      navic.clear_buffer_data(bufnr)
      state.attached_clients[bufnr] = nil
    end,
    group = navbuddy_augroup,
    buffer = bufnr,
  })

  vim.api.nvim_buf_create_user_command(bufnr, "Navbuddy", function()
    open(bufnr)
  end, {})
end

-- local function auto_attach(_config)
--   config = vim.tbl_deep_extend("force", config, _config)
--   local navbuddy_augroup = vim.api.nvim_create_augroup("navbuddy", { clear = false })
--   vim.api.nvim_clear_autocmds({
--     group = navbuddy_augroup,
--   })
--   vim.api.nvim_create_autocmd("LspAttach", {
--     callback = function(args)
--       local bufnr = args.buf
--       local client = vim.lsp.get_client_by_id(args.data.client_id)
--       if not client.server_capabilities.documentSymbolProvider then
--         return
--       end
--       attach(client, bufnr)
--     end,
--   })
-- end

local function auto_attach(_config)
  config = vim.tbl_deep_extend("force", config, _config)

  local navbuddy_augroup = vim.api.nvim_create_augroup("navbuddy", { clear = false })
  vim.api.nvim_clear_autocmds({
    group = navbuddy_augroup,
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local bufnr = args.buf
      if args.data == nil and args.data.client_id == nil then
        return
      end
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client.server_capabilities.documentSymbolProvider then
        return
      end
      attach(client, bufnr)
    end,
  })

  --- Attach to already active clients.
  local all_clients = vim.lsp.get_clients()

  local supported_clients = vim.tbl_filter(function(client)
    return client.server_capabilities.documentSymbolProvider
  end, all_clients)

  for _, client in ipairs(supported_clients) do
    local buffers_of_client = vim.lsp.get_buffers_by_client_id(client.id)

    for _, buffer_number in ipairs(buffers_of_client) do
      attach(client, buffer_number)
    end
  end
end

return {
  auto_attach = auto_attach,
}
