local hl = require("nvim-navbuddy.highlights")

describe("highlights", function()
  describe("_clamp_color", function()
    it("returns 0 for negative values", function()
      assert.equals(0, hl._clamp_color(-10))
      assert.equals(0, hl._clamp_color(-1))
    end)

    it("returns 255 for values above 255", function()
      assert.equals(255, hl._clamp_color(256))
      assert.equals(255, hl._clamp_color(999))
    end)

    it("returns input for values in valid range", function()
      assert.equals(0, hl._clamp_color(0))
      assert.equals(128, hl._clamp_color(128))
      assert.equals(255, hl._clamp_color(255))
    end)
  end)

  describe("_to_rgb", function()
    it("parses red", function()
      local r, g, b = hl._to_rgb("#FF0000")
      assert.equals(255, r)
      assert.equals(0, g)
      assert.equals(0, b)
    end)

    it("parses black", function()
      local r, g, b = hl._to_rgb("#000000")
      assert.equals(0, r)
      assert.equals(0, g)
      assert.equals(0, b)
    end)

    it("parses white", function()
      local r, g, b = hl._to_rgb("#FFFFFF")
      assert.equals(255, r)
      assert.equals(255, g)
      assert.equals(255, b)
    end)

    it("parses mixed hex with leading zeros", function()
      local r, g, b = hl._to_rgb("#0A1B2C")
      assert.equals(10, r)
      assert.equals(27, g)
      assert.equals(44, b)
    end)

    it("parses lowercase hex", function()
      local r, g, b = hl._to_rgb("#ff8800")
      assert.equals(255, r)
      assert.equals(136, g)
      assert.equals(0, b)
    end)
  end)

  describe("darken", function()
    it("returns same color at 0 percent", function()
      local result = hl.darken("#FFFFFF", 0)
      assert.equals("#ffffff", result)
    end)

    it("darkens by 50 percent", function()
      local result = hl.darken("#FFFFFF", 50)
      -- 255 * 0.5 = 127.5, floor = 127 = 0x7f
      assert.equals("#7f7f7f", result)
    end)

    it("returns near-black at 100 percent", function()
      local result = hl.darken("#FFFFFF", 100)
      assert.equals("#000", result)
    end)
  end)

  describe("get_color_from_hl", function()
    it("returns foreground hex for a defined highlight", function()
      vim.api.nvim_set_hl(0, "TestNavbuddyHl", { fg = 0xFF0000 })
      local result = hl.get_color_from_hl("TestNavbuddyHl")
      assert.equals("#ff0000", result.foreground)
      vim.api.nvim_set_hl(0, "TestNavbuddyHl", {})
    end)

    it("returns background hex when defined", function()
      vim.api.nvim_set_hl(0, "TestNavbuddyHlBg", { bg = 0x00FF00 })
      local result = hl.get_color_from_hl("TestNavbuddyHlBg")
      assert.equals("#00ff00", result.background)
      vim.api.nvim_set_hl(0, "TestNavbuddyHlBg", {})
    end)

    it("returns empty table for undefined highlight", function()
      local result = hl.get_color_from_hl("NonExistentHighlight12345")
      assert.is_nil(result.foreground)
      assert.is_nil(result.background)
    end)
  end)

  describe("setup", function()
    it("creates dim highlight groups for buffer focus mode", function()
      -- Clear any existing highlights
      vim.api.nvim_set_hl(0, "NavbuddyNormalFloatDim", {})
      vim.api.nvim_set_hl(0, "NavbuddyFloatBorderDim", {})

      hl.setup({})

      local dim_float = vim.api.nvim_get_hl(0, { name = "NavbuddyNormalFloatDim" })
      assert.is_not_nil(next(dim_float), "NavbuddyNormalFloatDim should be defined")

      local dim_border = vim.api.nvim_get_hl(0, { name = "NavbuddyFloatBorderDim" })
      assert.is_not_nil(next(dim_border), "NavbuddyFloatBorderDim should be defined")
    end)

    it("creates standard highlight groups", function()
      -- Clear highlights
      vim.api.nvim_set_hl(0, "NavbuddyCursorLine", {})
      vim.api.nvim_set_hl(0, "NavbuddyCursor", {})
      vim.api.nvim_set_hl(0, "NavbuddyName", {})

      hl.setup({})

      local cursor_line = vim.api.nvim_get_hl(0, { name = "NavbuddyCursorLine" })
      assert.is_not_nil(next(cursor_line), "NavbuddyCursorLine should be defined")

      local cursor = vim.api.nvim_get_hl(0, { name = "NavbuddyCursor" })
      assert.is_not_nil(next(cursor), "NavbuddyCursor should be defined")

      local name = vim.api.nvim_get_hl(0, { name = "NavbuddyName" })
      assert.is_not_nil(next(name), "NavbuddyName should be defined")
    end)

    it("respects custom_hl_group for cursor line", function()
      vim.api.nvim_set_hl(0, "NavbuddyCursorLine", {})
      hl.setup({ custom_hl_group = "Visual" })

      local cursor_line = vim.api.nvim_get_hl(0, { name = "NavbuddyCursorLine" })
      assert.is_not_nil(cursor_line.link, "NavbuddyCursorLine should be a link")
    end)
  end)

  describe("get_border_chars", function()
    it("maps 'default' to 'single'", function()
      local result = hl.get_border_chars("default", "left")
      local single = hl.get_border_chars("single", "left")
      assert.are.same(result, single)
    end)

    it("returns passthrough for unknown styles", function()
      local result = hl.get_border_chars("custom_style", "left")
      assert.equals("custom_style", result)
    end)

    it("returns 8-element array for left section", function()
      local result = hl.get_border_chars("single", "left")
      assert.equals(8, #result.style)
    end)

    it("returns 8-element array for mid section", function()
      local result = hl.get_border_chars("single", "mid")
      assert.equals(8, #result.style)
    end)

    it("returns 8-element array for right section", function()
      local result = hl.get_border_chars("single", "right")
      assert.equals(8, #result)
    end)

    it("returns correct single-style left border chars", function()
      local result = hl.get_border_chars("single", "left")
      assert.equals("\xe2\x94\x8c", result.style[1]) -- top_left: "┌"
      assert.equals("\xe2\x94\x82", result.style[8]) -- left: "│"
    end)

    it("works for all known styles", function()
      for _, style in ipairs({ "single", "rounded", "double", "solid" }) do
        for _, section in ipairs({ "left", "mid", "right" }) do
          local result = hl.get_border_chars(style, section)
          assert.is_not_nil(result, style .. "/" .. section .. " returned nil")
        end
      end
    end)
  end)
end)
