-- Runs navbuddy.attach and navbuddy.open against real LSP clients backed by an
-- in-process server, so the attached client list is observed through open().

describe("attached clients", function()
  local navbuddy, source_buf, opened, original_new, clients

  local function server(dispatchers)
    return {
      request = function(method, _, callback)
        if method == "initialize" then
          callback(nil, { capabilities = { documentSymbolProvider = true } })
        elseif method == "textDocument/documentSymbol" then
          local range = { start = { line = 0, character = 0 }, ["end"] = { line = 1, character = 1 } }
          local selection = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } }
          vim.schedule(function()
            callback(nil, { { name = "fun", kind = 12, range = range, selectionRange = selection } })
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
