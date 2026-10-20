describe("navbuddy.setup", function()
  local function fresh_require()
    -- Clear cached modules to get fresh state
    package.loaded["nvim-navbuddy"] = nil
    package.loaded["nvim-navbuddy.config"] = nil
    package.loaded["nvim-navbuddy.actions"] = nil
    package.loaded["nvim-navbuddy.utils"] = nil
    package.loaded["nvim-navbuddy.state"] = nil
    return require("nvim-navbuddy"), require("nvim-navbuddy.config")
  end

  it("loads default config without errors", function()
    local _, config = fresh_require()
    assert.equals("single", config.window.border)
    assert.equals("60%", config.window.size)
    assert.equals(true, config.use_default_mappings)
    assert.equals(false, config.lsp.auto_attach)
  end)

  it("merges window overrides with defaults", function()
    local navbuddy, config = fresh_require()
    navbuddy.setup({
      window = {
        border = "rounded",
        size = "80%",
      },
    })
    assert.equals("rounded", config.window.border)
    assert.equals("80%", config.window.size)
    -- defaults preserved
    assert.equals("50%", config.window.position)
  end)

  it("sets section border defaults to 'none' when one is specified", function()
    local navbuddy, config = fresh_require()
    navbuddy.setup({
      window = {
        sections = {
          left = { border = "double" },
        },
      },
    })
    assert.equals("double", config.window.sections.left.border)
    assert.equals("none", config.window.sections.mid.border)
    assert.equals("none", config.window.sections.right.border)
  end)

  it("disables default mappings when use_default_mappings is false", function()
    local navbuddy, config = fresh_require()
    local custom_action = { callback = function() end, description = "custom" }
    navbuddy.setup({
      use_default_mappings = false,
      mappings = {
        ["x"] = custom_action,
      },
    })
    -- Only user mapping should remain
    assert.is_not_nil(config.mappings["x"])
    assert.is_nil(config.mappings["j"])
    assert.is_nil(config.mappings["k"])
  end)

  it("merges user mappings with defaults when use_default_mappings is true", function()
    local navbuddy, config = fresh_require()
    local custom_action = { callback = function() end, description = "custom" }
    navbuddy.setup({
      mappings = {
        ["x"] = custom_action,
      },
    })
    -- Both user and default mappings present
    assert.is_not_nil(config.mappings["x"])
    assert.is_not_nil(config.mappings["j"])
  end)

  it("merges source_buffer overrides", function()
    local navbuddy, config = fresh_require()
    navbuddy.setup({
      source_buffer = {
        reorient = "top",
      },
    })
    assert.equals("top", config.source_buffer.reorient)
    assert.equals(true, config.source_buffer.follow_node)
    assert.equals(true, config.source_buffer.highlight)
  end)

  it("sets custom_hl_group", function()
    local navbuddy, config = fresh_require()
    navbuddy.setup({
      custom_hl_group = "Visual",
    })
    assert.equals("Visual", config.custom_hl_group)
  end)

  it("handles nil config gracefully", function()
    local navbuddy, config = fresh_require()
    navbuddy.setup(nil)
    assert.equals("single", config.window.border)
  end)
end)
