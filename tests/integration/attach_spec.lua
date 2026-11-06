-- Runs navbuddy.attach and navbuddy.open against real LSP clients backed by an
-- in-process server, so the attached client list is observed through open().

describe("attached clients", function()
  local navbuddy, source_buf, opened, original_new, clients
  local requests, errors_to_send, symbols_to_send

  local function server(dispatchers)
    return {
      request = function(method, params, callback)
        if method == "initialize" then
          callback(nil, { capabilities = { documentSymbolProvider = true } })
        elseif method == "textDocument/documentSymbol" then
          table.insert(requests, params.textDocument.uri)
          local range = { start = { line = 0, character = 0 }, ["end"] = { line = 1, character = 1 } }
          local selection = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } }
          local symbols = symbols_to_send or { { name = "fun", kind = 12, range = range, selectionRange = selection } }
          vim.schedule(function()
            if errors_to_send > 0 then
              errors_to_send = errors_to_send - 1
              callback({ code = -32801, message = "content modified" }, nil)
            else
              callback(nil, symbols)
            end
          end)
        else
          callback(nil, nil)
        end
        return true, 1
      end,
      notify = function()
        return true
      end,
      is_closing = function()
        return false
      end,
      terminate = function()
        dispatchers.on_exit(0, 15)
      end,
    }
  end

  local function start_client(name)
    local id = vim.lsp.start({ name = name, cmd = server, root_dir = vim.fn.getcwd() }, { bufnr = source_buf })
    local client = vim.lsp.get_client_by_id(id)
    table.insert(clients, client)
    assert.is_true(vim.wait(1000, function()
      return client.initialized
    end, 5))
    return client
  end

  local function fake_client(id, name, stopped)
    return {
      id = id,
      name = name,
      server_capabilities = { documentSymbolProvider = true },
      is_stopped = function()
        return stopped
      end,
    }
  end

  local function wait_for_display()
    assert.is_true(vim.wait(1000, function()
      return opened ~= nil
    end, 5))
    return opened
  end

  local function chooser_text()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
        if text:find(":", 1, true) then
          return text
        end
      end
    end
    return ""
  end

  before_each(function()
    package.loaded["nvim-navbuddy"] = nil
    package.loaded["nvim-navbuddy.config"] = nil
    package.loaded["nvim-web-devicons"] = {
      get_icon = function()
        return nil, nil
      end,
    }
    navbuddy = require("nvim-navbuddy")

    source_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(source_buf, "navbuddy_attach_spec.lua")
    vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, { "fun {", "}" })
    vim.api.nvim_set_current_buf(source_buf)

    clients, opened = {}, nil
    requests, errors_to_send, symbols_to_send = {}, 0, nil
    local display = require("nvim-navbuddy.display")
    original_new = display.new
    display.new = function(opts)
      opened = original_new(opts)
      return opened
    end
  end)

  after_each(function()
    require("nvim-navbuddy.display").new = original_new
    if opened and not opened.state.closed then
      pcall(opened.close, opened)
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
    for _, client in ipairs(clients) do
      client:stop(true)
    end
    vim.wait(1000, function()
      return #vim.lsp.get_clients() == 0
    end, 5)
    vim.cmd("silent! %bwipeout!")
    package.loaded["nvim-web-devicons"] = nil
    pcall(vim.api.nvim_del_augroup_by_name, "navbuddy_auto_attach")
  end)

  it("keeps the first client when a second attaches", function()
    navbuddy.setup({ lsp = { preference = { "first_lsp" } } })
    navbuddy.attach(start_client("first_lsp"), source_buf)
    navbuddy.attach(start_client("second_lsp"), source_buf)

    navbuddy.open()

    assert.equals("first_lsp", wait_for_display().lsp_name)
  end)

  it("offers every attached client when there is no preference", function()
    navbuddy.attach(fake_client(101, "first_lsp", false), source_buf)
    navbuddy.attach(fake_client(102, "second_lsp", false), source_buf)

    navbuddy.open()

    local text = chooser_text()
    assert.is_truthy(text:find("first_lsp", 1, true), text)
    assert.is_truthy(text:find("second_lsp", 1, true), text)
  end)

  it("drops stopped clients when another attaches", function()
    navbuddy.attach(fake_client(101, "stopped_a", true), source_buf)
    navbuddy.attach(fake_client(102, "stopped_b", true), source_buf)
    navbuddy.attach(start_client("running_lsp"), source_buf)

    navbuddy.open()

    assert.equals("running_lsp", wait_for_display().lsp_name)
  end)

  it("removes only the client that detached", function()
    local first = start_client("first_lsp")
    local second = start_client("second_lsp")
    navbuddy.attach(first, source_buf)
    navbuddy.attach(second, source_buf)

    vim.api.nvim_exec_autocmds("LspDetach", { buffer = source_buf, data = { client_id = first.id } })
    navbuddy.open()

    assert.equals("second_lsp", wait_for_display().lsp_name)
  end)

  it("keeps the remaining client when the most recent one detaches", function()
    local first = start_client("first_lsp")
    local second = start_client("second_lsp")
    navbuddy.attach(first, source_buf)
    navbuddy.attach(second, source_buf)

    vim.api.nvim_exec_autocmds("LspDetach", { buffer = source_buf, data = { client_id = second.id } })
    navbuddy.open()

    assert.equals("first_lsp", wait_for_display().lsp_name)
  end)

  it("keeps detach handling after a second setup", function()
    local first = start_client("first_lsp")
    local second = start_client("second_lsp")
    navbuddy.attach(first, source_buf)
    navbuddy.attach(second, source_buf)

    navbuddy.setup({ lsp = { auto_attach = true } })
    vim.api.nvim_exec_autocmds("LspDetach", { buffer = source_buf, data = { client_id = first.id } })
    navbuddy.open()

    assert.equals("second_lsp", wait_for_display().lsp_name)
  end)

  describe("opening a buffer that isn't current", function()
    local other_buf, source_win

    local function press_close()
      require("nvim-navbuddy.actions").close().callback(opened)
    end

    before_each(function()
      source_win = vim.api.nvim_get_current_win()
      other_buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(other_buf, "navbuddy_attach_other.lua")
      vim.api.nvim_buf_set_lines(other_buf, 0, -1, false, { "fun {", "}" })

      local client = start_client("mock_lsp")
      vim.lsp.buf_attach_client(other_buf, client.id)
      navbuddy.attach(client, source_buf)
      navbuddy.attach(client, other_buf)
    end)

    after_each(function()
      if opened and not opened.state.closed then
        pcall(opened.close, opened)
      end
      opened = nil
      vim.cmd("silent! only")
    end)

    it("asks about the current buffer by default", function()
      navbuddy.open()
      wait_for_display()

      assert.same({ vim.uri_from_bufnr(source_buf) }, requests)
    end)

    it("asks about the requested buffer", function()
      navbuddy.open(other_buf)
      wait_for_display()

      assert.same({ vim.uri_from_bufnr(other_buf) }, requests)
    end)

    it("accepts the buffer in an options table", function()
      navbuddy.open({ bufnr = other_buf })

      assert.equals(other_buf, wait_for_display().for_buf)
    end)

    it("shows the buffer in the current window and returns on close", function()
      vim.api.nvim_win_set_cursor(source_win, { 2, 0 })

      navbuddy.open(other_buf)
      wait_for_display()

      assert.equals(source_win, opened.for_win)
      assert.equals(other_buf, vim.api.nvim_win_get_buf(source_win))

      press_close()

      assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
      assert.same({ 2, 0 }, vim.api.nvim_win_get_cursor(source_win))
    end)

    it("uses a window already showing the buffer", function()
      vim.cmd("vsplit")
      local other_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(other_win, other_buf)
      vim.api.nvim_set_current_win(source_win)

      navbuddy.open(other_buf)
      wait_for_display()

      assert.equals(other_win, opened.for_win)
      assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))

      press_close()

      assert.equals(other_buf, vim.api.nvim_win_get_buf(other_win))
      assert.equals(other_win, vim.api.nvim_get_current_win())
    end)

    it("leaves the window alone when the buffer has no symbols", function()
      symbols_to_send = {}

      navbuddy.open(other_buf)
      vim.wait(50, function()
        return false
      end, 5)

      assert.is_nil(opened)
      assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
    end)

    it("says so when the buffer has no symbols", function()
      symbols_to_send = {}
      local messages = {}
      local saved_notify = vim.notify
      vim.notify = function(message, level)
        table.insert(messages, { message = message, level = level })
      end

      navbuddy.open(other_buf)
      local notified = vim.wait(500, function()
        return messages[1] ~= nil
      end, 5)
      vim.notify = saved_notify

      assert.is_true(notified)
      assert.same({ { message = "No symbols found in buffer", level = vim.log.levels.INFO } }, messages)
    end)

    it("retries the same buffer after a server error", function()
      errors_to_send = 1

      navbuddy.open(other_buf)
      assert.is_true(vim.wait(2000, function()
        return opened ~= nil
      end, 10))

      assert.same({ vim.uri_from_bufnr(other_buf), vim.uri_from_bufnr(other_buf) }, requests)
    end)
  end)

  describe("auto_attach", function()
    local function lsp_attach_autocmds()
      local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = "navbuddy_auto_attach", event = "LspAttach" })
      return ok and autocmds or {}
    end

    it("attaches a client that starts after setup", function()
      navbuddy.setup({ lsp = { auto_attach = true } })

      start_client("auto_lsp")
      navbuddy.open()

      assert.equals("auto_lsp", wait_for_display().lsp_name)
    end)

    it("attaches clients already running at setup", function()
      start_client("early_lsp")

      navbuddy.setup({ lsp = { auto_attach = true } })
      navbuddy.open()

      assert.equals("early_lsp", wait_for_display().lsp_name)
    end)

    it("adds one autocmd however many times setup runs", function()
      navbuddy.setup({ lsp = { auto_attach = true } })
      navbuddy.setup({ lsp = { auto_attach = true } })
      navbuddy.setup({ lsp = { auto_attach = true } })

      assert.equals(1, #lsp_attach_autocmds())
    end)

    it("removes the autocmd when setup turns it off", function()
      navbuddy.setup({ lsp = { auto_attach = true } })
      navbuddy.setup({ lsp = { auto_attach = false } })

      assert.equals(0, #lsp_attach_autocmds())
    end)

    it("ignores LspAttach without client data", function()
      navbuddy.setup({ lsp = { auto_attach = true } })

      vim.v.errmsg = ""
      vim.api.nvim_exec_autocmds("LspAttach", { buffer = source_buf })

      assert.equals("", vim.v.errmsg)
    end)

    it("ignores LspAttach for an unknown client", function()
      navbuddy.setup({ lsp = { auto_attach = true } })

      vim.v.errmsg = ""
      vim.api.nvim_exec_autocmds("LspAttach", { buffer = source_buf, data = { client_id = 99999 } })

      assert.equals("", vim.v.errmsg)
    end)
  end)

  it("reports no servers once the last client detaches", function()
    local notified
    local saved_notify = vim.notify
    vim.notify = function(message)
      notified = message
    end
    local first = start_client("first_lsp")
    navbuddy.attach(first, source_buf)

    vim.api.nvim_exec_autocmds("LspDetach", { buffer = source_buf, data = { client_id = first.id } })
    navbuddy.open()
    vim.notify = saved_notify

    assert.equals("No lsp servers attached", notified)
    assert.is_nil(opened)
  end)
end)
