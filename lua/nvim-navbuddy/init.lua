--- *nvim-navbuddy* *navbuddy*
---
--- A simple popup display that provides breadcrumbs like navigation feature but
--- in keyboard centric manner inspired by ranger file manager.

---@text TABLE OF CONTENTS
---
---@toc
---@tag navbuddy-table-of-contents
---@text

---@text REQUIREMENTS
---
--- - nvim-lspconfig: `https://github.com/neovim/nvim-lspconfig`
--- - nvim-navic: `https://github.com/SmiteshP/nvim-navic`
--- - nui.nvim: `https://github.com/MunifTanjim/nui.nvim`
--- - Neovim: 0.8 or above
---
---@text OPTIONAL REQUIREMENTS
---
--- - Comment.nvim: `https://github.com/numToStr/Comment.nvim`
--- - Fuzzy find: Only one of these is needed.
---     - telescope.nvim: `https://github.com/nvim-telescope/telescope.nvim`
---     - snacks.nvim: `https://github.com/folke/snacks.nvim`
---@tag navbuddy-requirements
---@toc_entry Requirements


---@text INSTALLATION
--- >lua
---   -- lazy.nvim
---   {
---     "neovim/nvim-lspconfig",
---     dependencies = {
---       "hasansujon786/nvim-navbuddy",
---       opts = { lsp = { auto_attach = true } }
---       dependencies = {
---         "SmiteshP/nvim-navic",
---         "MunifTanjim/nui.nvim"
---       }
---     }
---   }
--- <
---@tag navbuddy-installation
---@toc_entry Installation

---@text USAGE
---
--- nvim-navbuddy needs to be attached to lsp servers of the buffer to work. Use the
--- navbuddy.attach function while setting up lsp servers. You can skip this
--- step if you have enabled auto_attach option during setup.
---
--- Example: >lua
---   require("lspconfig").clangd.setup {
---     on_attach = function(client, bufnr)
---       navbuddy.attach(client, bufnr)
---     end
---   }
--- <
--- Then simply use command `Navbuddy` to open the window.
---@tag navbuddy-usage
---@toc_entry Usage

---@text COMMANDS
---
--- Navbuddy does not define any default keybindings for nvim. The example
--- keybindings are:
--- >vim
---   nnoremap zo :Navbuddy<cr>
---   nnoremap zi :Navbuddy root<cr>
--- <
--- root~
--- Open navbuddy with root node, the first node left of current node.
---@tag :Navbuddy navbuddy-commands
---@toc_entry Commands

local navic = require("nvim-navic.lib")
local nui_menu = require("nui.menu")
local display = require("nvim-navbuddy.display")
local actions = require("nvim-navbuddy.actions")
local default_config = require("nvim-navbuddy.config")

-- Default configuration loaded from nvim-navbuddy.config module
-- See lua/nvim-navbuddy/config.lua for full default configuration
---@type Navbuddy.config
local config = default_config

setmetatable(config.icons, {
  __index = function()
    return "? "
  end,
})

---@private
---@type table<number, vim.lsp.Client[]>
local navbuddy_attached_clients = {}

local function choose_lsp_menu(for_buf, make_request)
  local style = nil

  if config.window.border ~= nil and config.window.border ~= "None" then
    style = config.window.border
  else
    style = "single"
  end

  local min_width = 23
  local lines = {}

  for _, v in ipairs(navbuddy_attached_clients[for_buf]) do
    min_width = math.max(min_width, #v.name)
    table.insert(lines, nui_menu.item(v.id .. ":" .. v.name))
  end

  local min_height = #lines

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
      local id = tonumber(string.match(item.text, "%d+"))
      for _, check_client in ipairs(navbuddy_attached_clients[for_buf]) do
        if id == check_client.id then
          make_request(check_client)
          return
        end
      end
    end,
  })

  menu:mount()
end

local function request(for_buf, handler, opts)
  local function make_request(client)
    navic.request_symbol(for_buf, function(bufnr, symbols)
      navic.update_data(bufnr, symbols)
      navic.update_context(bufnr)
      local context_data = navic.get_context_data(bufnr)

      local curr_node = context_data[#context_data]

      handler(for_buf, curr_node, client.name, opts)
    end, client)
  end

  if navbuddy_attached_clients[for_buf] == nil then
    vim.notify("No lsp servers attached", vim.log.levels.ERROR)
  elseif #navbuddy_attached_clients[for_buf] == 1 then
    make_request(navbuddy_attached_clients[for_buf][1])
  elseif config.lsp.preference ~= nil then
    local found = false

    for _, preferred_lsp in ipairs(config.lsp.preference) do
      for _, attached_lsp in ipairs(navbuddy_attached_clients[for_buf]) do
        if preferred_lsp == attached_lsp.name then
          navbuddy_attached_clients[for_buf] = { attached_lsp }
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

---@private
---@param bufnr number
---@param curr_node Navbuddy.symbolNode
---@param lsp_name string
---@param opts Navbuddy.openOpts
local function handler(bufnr, curr_node, lsp_name, opts)
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

  while opts.root and curr_node and not curr_node.parent.is_root do
    curr_node = curr_node.parent
  end

  if not curr_node then
    return
  end

  display.new({
    for_buf = bufnr,
    for_win = vim.api.nvim_get_current_win(),
    start_cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win()),
    focus_node = curr_node,
    config = config,
    lsp_name = lsp_name,
  })
end

local navbuddy = {}

local function setup_commands()
  local get_complete = function()
    return { "root" }
  end

  vim.api.nvim_create_user_command("Navbuddy", function(cmd)
    ---@type Navbuddy.openOpts
    local opts = {}
    if cmd.fargs[1] == "root" then
      opts.root = true
    end

    navbuddy.open(opts)
  end, { nargs = "?", complete = get_complete, desc = "Navbuddy" })
end

---@text API
---
--- |nvim-navbuddy| provides the following functions for the user.
---@tag navbuddy-api
---@toc_entry API

--- Configure |nvim-navbuddy|'s options. See more |navbuddy-config|
---@param user_config Navbuddy.config
function navbuddy.setup(user_config)
  if user_config ~= nil then
    if user_config.window ~= nil then
      config.window = vim.tbl_deep_extend("keep", user_config.window, config.window)
    end

    -- If one is set, default for others should be none
    if
      config.window.sections.left.border ~= nil
      or config.window.sections.mid.border ~= nil
      or config.window.sections.right.border ~= nil
    then
      config.window.sections.left.border = config.window.sections.left.border or "none"
      config.window.sections.mid.border = config.window.sections.mid.border or "none"
      config.window.sections.right.border = config.window.sections.right.border or "none"
    end

    if user_config.node_markers ~= nil then
      config.node_markers = vim.tbl_deep_extend("keep", user_config.node_markers, config.node_markers)
    end

    if user_config.icons ~= nil then
      for k, v in pairs(user_config.icons) do
        if navic.adapt_lsp_str_to_num(k) then
          config.icons[navic.adapt_lsp_str_to_num(k)] = v
        end
      end
    end

    if user_config.use_default_mappings ~= nil then
      config.use_default_mappings = user_config.use_default_mappings
    end

    if user_config.mappings ~= nil then
      if config.use_default_mappings then
        config.mappings = vim.tbl_deep_extend("keep", user_config.mappings, config.mappings)
      else
        config.mappings = user_config.mappings
      end
    end

    if user_config.lsp ~= nil then
      config.lsp = vim.tbl_deep_extend("keep", user_config.lsp, config.lsp)
    end

    if user_config.source_buffer ~= nil then
      config.source_buffer = vim.tbl_deep_extend("keep", user_config.source_buffer, config.source_buffer)
    end

    if user_config.custom_hl_group ~= nil then
      config.custom_hl_group = user_config.custom_hl_group
    end
  end

  if config.lsp.auto_attach == true then
    local navbuddy_augroup = vim.api.nvim_create_augroup("navbuddy", { clear = false })
    vim.api.nvim_clear_autocmds({ group = navbuddy_augroup })
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local bufnr = args.buf
        if args.data == nil and args.data.client_id == nil then
          return
        end
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or not client.server_capabilities.documentSymbolProvider then
          return
        end
        navbuddy.attach(client, bufnr)
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
        navbuddy.attach(client, buffer_number)
      end
    end
  end

  setup_commands()
end

--- Opens Navbuddy for the given buffer or options.
---@param opts? number|Navbuddy.openOpts Optional buffer number or options table.
---        If a number, it's treated as a buffer number.
---        If a table, it may include a `bufnr` field.
---        If omitted, the current buffer is used.
function navbuddy.open(opts)
  -- Get bufnr and validate
  local bufnr = type(opts) == "number" and opts
    or type(opts) == "table" and opts.bufnr
    or vim.api.nvim_get_current_buf()
  assert(vim.api.nvim_buf_is_valid(bufnr), "Invalid buffer number")

  opts = type(opts) == "table" and opts or {}

  request(bufnr, handler, opts)
end

---@param client vim.lsp.Client
---@param bufnr number
function navbuddy.attach(client, bufnr)
  if not client.server_capabilities.documentSymbolProvider then
    if not vim.g.navbuddy_silence then
      vim.notify(
        'nvim-navbuddy: Server "' .. client.name .. '" does not support documentSymbols.',
        vim.log.levels.ERROR
      )
    end
    return
  end

  if navbuddy_attached_clients[bufnr] == nil then
    navbuddy_attached_clients[bufnr] = {}
  end

  -- Check if already attached
  for _, c in ipairs(navbuddy_attached_clients[bufnr]) do
    if c.id == client.id then
      return
    end
  end

  -- Check for stopped lsp servers
  for i, c in ipairs(navbuddy_attached_clients[bufnr]) do
    if c.is_stopped then
      table.remove(navbuddy_attached_clients[bufnr], i)
    end
  end

  table.insert(navbuddy_attached_clients[bufnr], client)

  local navbuddy_augroup = vim.api.nvim_create_augroup("navbuddy", { clear = false })
  vim.api.nvim_clear_autocmds({
    buffer = bufnr,
    group = navbuddy_augroup,
  })
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function()
      navic.clear_buffer_data(bufnr)
      navbuddy_attached_clients[bufnr] = nil
    end,
    group = navbuddy_augroup,
    buffer = bufnr,
  })
  vim.api.nvim_create_autocmd("LspDetach", {
    callback = function()
      if navbuddy_attached_clients[bufnr] ~= nil then
        for i, c in ipairs(navbuddy_attached_clients[bufnr]) do
          if c.id == client.id then
            table.remove(navbuddy_attached_clients[bufnr], i)
            break
          end
        end
        if #navbuddy_attached_clients[bufnr] == 0 then
          navbuddy_attached_clients[bufnr] = nil
        end
      end
    end,
    group = navbuddy_augroup,
    buffer = bufnr,
  })
end

return navbuddy
