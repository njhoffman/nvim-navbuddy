local border = require("nvim-navbuddy.border")

describe("border", function()
  describe("normalize", function()
    it("wraps a style name", function()
      assert.same({ style = "none" }, border.normalize("none"))
    end)

    it("wraps a list of border characters", function()
      local chars = { "a", "b", "c", "d", "e", "f", "g", "h" }
      assert.same({ style = chars }, border.normalize(chars))
    end)

    it("returns a copy of an options table", function()
      local options = { style = "rounded" }
      local result = border.normalize(options)
      result.text = {}
      assert.same({ style = "rounded" }, options)
    end)

    it("returns an empty table for nil", function()
      assert.same({}, border.normalize(nil))
    end)
  end)

  describe("resolve", function()
    it("prefers the section border", function()
      assert.same({ style = "double" }, border.resolve("double", "single", "right"))
    end)

    it("builds the joined window border when the section has none", function()
      assert.same(border.get_border("single", "right"), border.resolve(nil, "single", "right"))
    end)

    it("wraps a borderless window style", function()
      assert.same({ style = "none" }, border.resolve(nil, "none", "right"))
    end)
  end)

  describe("supports_text", function()
    it("is false for styles that cannot carry text", function()
      for _, style in ipairs({ "none", "shadow", "solid" }) do
        assert.is_false(border.supports_text(style))
        assert.is_false(border.supports_text({ style = style }))
      end
    end)

    it("is true for other styles and character lists", function()
      assert.is_true(border.supports_text("single"))
      assert.is_true(border.supports_text({ style = "rounded" }))
      assert.is_true(border.supports_text({ "a", "b", "c", "d", "e", "f", "g", "h" }))
    end)
  end)

  describe("get_border", function()
    it("returns passthrough for unknown styles", function()
      local result = border.get_border("my_custom", "left")
      assert.equals("my_custom", result)
    end)

    it("returns 8-element arrays for all style/section combos", function()
      for _, style in ipairs({ "single", "rounded", "double", "solid" }) do
        for _, section in ipairs({ "title", "nav_title", "left", "mid", "right" }) do
          local result = border.get_border(style, section)
          assert.is_not_nil(result, style .. "/" .. section .. " returned nil")
          assert.equals(8, #result.style, style .. "/" .. section .. " has wrong length")
        end
      end
    end)

    it("returns correct single-style title border", function()
      local result = border.get_border("single", "title")
      -- title: top_left, top, top_right, right, right, none, left, left
      assert.equals("\xe2\x94\x8c", result.style[1]) -- "┌"
      assert.equals("", result.style[6]) -- none
    end)

    it("returns correct single-style left border", function()
      local result = border.get_border("single", "left")
      -- left section starts with left char (not top_left)
      assert.equals("\xe2\x94\x82", result.style[1]) -- "│" (left char used as top_left)
    end)

    it("returns correct single-style mid border", function()
      local result = border.get_border("single", "mid")
      -- mid: none, top, none, none, bottom_T, bottom, bottom, none
      assert.equals("", result.style[1]) -- none
      assert.equals("", result.style[4]) -- none
    end)
  end)
end)
