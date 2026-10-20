local border = require("nvim-navbuddy.border")

describe("border", function()
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
