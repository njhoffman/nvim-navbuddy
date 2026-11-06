describe("plugin/navbuddy.lua", function()
  local saved_notify, notifications

  local function source_plugin()
    pcall(vim.api.nvim_del_user_command, "Navbuddy")
    vim.g.loaded_navbuddy = nil
    package.loaded["nvim-navbuddy"] = nil
    vim.cmd.source("plugin/navbuddy.lua")
  end

  before_each(function()
    saved_notify = vim.notify
    notifications = {}
    vim.notify = function(message)
      table.insert(notifications, message)
    end
    source_plugin()
  end)

  after_each(function()
    vim.notify = saved_notify
  end)

  it("defines :Navbuddy without setup", function()
    assert.equals(2, vim.fn.exists(":Navbuddy"))
  end)

  it("does not load the plugin until the command runs", function()
    assert.is_nil(package.loaded["nvim-navbuddy"])

    vim.cmd("Navbuddy")

    assert.is_not_nil(package.loaded["nvim-navbuddy"])
    assert.equals("No lsp servers attached", notifications[1])
  end)

  it("passes root to open", function()
    local received
    package.loaded["nvim-navbuddy"] = {
      open = function(opts)
        received = opts
      end,
    }

    vim.cmd("Navbuddy root")
    assert.is_true(received.root)

    vim.cmd("Navbuddy")
    assert.is_false(received.root)
  end)

  it("completes the root argument", function()
    assert.same({ "root" }, vim.fn.getcompletion("Navbuddy ", "cmdline"))
  end)

  it("only defines the command once", function()
    vim.api.nvim_del_user_command("Navbuddy")

    vim.cmd.source("plugin/navbuddy.lua")

    assert.equals(0, vim.fn.exists(":Navbuddy"))
  end)

  it("still works after setup", function()
    require("nvim-navbuddy").setup({})

    assert.equals(2, vim.fn.exists(":Navbuddy"))
  end)
end)
