local title = require("nvim-navbuddy.buffer.title")
local mock = require("tests.helpers.mock_nodes")

describe("title", function()
  describe("_node_chain_length", function()
    it("returns 0 for empty chain", function()
      assert.equals(0, title._node_chain_length({}, " > "))
    end)

    it("skips root nodes", function()
      local root = mock.make_root()
      assert.equals(0, title._node_chain_length({ root }, " > "))
    end)

    it("returns 2 + name length for single non-root node", function()
      local node = mock.make_node({ name = "hello" })
      -- first node: 2 + #"hello" = 7
      assert.equals(7, title._node_chain_length({ node }, " > "))
    end)

    it("adds separator length for subsequent nodes", function()
      local a = mock.make_node({ name = "aaa" })
      local b = mock.make_node({ name = "bbb" })
      local sep = " > "
      -- first: 2 + 3 = 5, second: 3 + 3 = 6, total = 11
      assert.equals(11, title._node_chain_length({ a, b }, sep))
    end)

    it("handles mixed root and non-root nodes", function()
      local root = mock.make_root()
      local a = mock.make_node({ name = "fn" })
      local b = mock.make_node({ name = "var" })
      local sep = "  "
      -- root skipped, first non-root: 2 + 2 = 4, second: 2 + 3 = 5, total = 9
      assert.equals(9, title._node_chain_length({ root, a, b }, sep))
    end)

    it("uses separator length correctly", function()
      local a = mock.make_node({ name = "x" })
      local b = mock.make_node({ name = "y" })
      -- sep = " :: " (4 chars)
      -- first: 2 + 1 = 3, second: 4 + 1 = 5, total = 8
      assert.equals(8, title._node_chain_length({ a, b }, " :: "))
    end)
  end)
end)
