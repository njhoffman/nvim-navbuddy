describe("test runtime", function()
  it("does not include the user's config or data directories", function()
    local paths = vim.api.nvim_list_runtime_paths()

    assert.is_false(vim.tbl_contains(paths, vim.fn.stdpath("config")))
    assert.is_false(vim.tbl_contains(paths, vim.fn.stdpath("data") .. "/site"))
  end)

  it("does not find optional plugins", function()
    assert.same({}, vim.api.nvim_get_runtime_file("lua/nvim-web-devicons.lua", true))
    assert.same({}, vim.api.nvim_get_runtime_file("lua/telescope/init.lua", true))
  end)

  it("finds the required dependencies", function()
    assert.equals(1, #vim.api.nvim_get_runtime_file("lua/nvim-navic/lib.lua", true))
    assert.equals(1, #vim.api.nvim_get_runtime_file("lua/nui/popup/init.lua", true))
  end)
end)
