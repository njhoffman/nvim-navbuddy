local utils = require("nvim-navbuddy.utils")

describe("utils", function()
  describe("fit_width", function()
    it("pads short text to the width", function()
      assert.equals("ab  ", utils.fit_width("ab", 4))
    end)

    it("returns text that already fits unchanged", function()
      assert.equals("abcd", utils.fit_width("abcd", 4))
    end)

    it("shortens long text with an ellipsis", function()
      assert.equals("abc…", utils.fit_width("abcdef", 4))
    end)

    it("measures wide characters by display cells", function()
      assert.equals("日本 ", utils.fit_width("日本", 5))
    end)

    it("never cuts inside a character", function()
      local fitted = utils.fit_width("日本語テキスト", 6)
      assert.equals("日本… ", fitted)
      assert.equals(6, vim.fn.strdisplaywidth(fitted))
    end)

    it("counts a multibyte icon by its display width", function()
      assert.equals(10, vim.fn.strdisplaywidth(utils.fit_width(" 󰊕 name", 10)))
    end)

    it("returns an empty string for no width", function()
      assert.equals("", utils.fit_width("abc", 0))
    end)
  end)

  describe("display_text", function()
    it("removes variation selectors", function()
      assert.equals("\226\154\153 Configuration", utils.display_text("\226\154\153\239\184\143 Configuration"))
      assert.equals("a", utils.display_text("a\239\184\142"))
    end)

    it("removes zero width joiners", function()
      assert.equals("ab", utils.display_text("a\226\128\141b"))
    end)

    it("leaves other text alone", function()
      assert.equals("日本語 🔥 café", utils.display_text("日本語 🔥 café"))
    end)
  end)

  describe("height_in_rows", function()
    local saved_lines

    before_each(function()
      saved_lines = vim.o.lines
      vim.o.lines = 40
    end)

    after_each(function()
      vim.o.lines = saved_lines
    end)

    it("converts a percentage of the editor", function()
      assert.equals(12, utils.height_in_rows("30%"))
    end)

    it("returns numbers unchanged", function()
      assert.equals(15, utils.height_in_rows(15))
    end)
  end)

  describe("check_integration", function()
    it("returns true when explicitly enabled", function()
      local config = { integrations = { telescope = true } }
      assert.is_true(utils.check_integration("telescope", config))
    end)

    it("returns false when explicitly disabled", function()
      local config = { integrations = { telescope = false } }
      assert.is_false(utils.check_integration("telescope", config))
    end)

    it("auto-detects when set to nil", function()
      -- plenary is loaded, so requiring it should succeed
      local config = { integrations = { plenary = nil } }
      local result = utils.check_integration("plenary", config)
      assert.is_true(result)
    end)

    it("auto-detects when set to 'auto'", function()
      local config = { integrations = { nonexistent_plugin_xyz = "auto" } }
      local result = utils.check_integration("nonexistent_plugin_xyz", config)
      assert.is_false(result)
    end)
  end)
end)
