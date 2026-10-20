local utils = require("nvim-navbuddy.utils")
local mock = require("tests.helpers.mock_nodes")

describe("utils", function()
  describe("_get_size", function()
    it("returns zero for node with no children", function()
      local node = mock.make_node({ name = "leaf" })
      local size = utils._get_size(node)
      assert.equals(0, size.w)
      assert.equals(0, size.h)
    end)

    it("returns zero for empty children table", function()
      local node = mock.make_node({ name = "empty", children = {} })
      local size = utils._get_size(node)
      assert.equals(0, size.w)
      assert.equals(0, size.h)
    end)

    it("returns correct height as child count", function()
      local root = mock.make_tree({
        { name = "a" },
        { name = "b" },
        { name = "c" },
      })
      local size = utils._get_size(root)
      assert.equals(3, size.h)
    end)

    it("returns width based on longest child name", function()
      local root = mock.make_tree({
        { name = "short" },
        { name = "a_longer_name" },
        { name = "mid" },
      })
      local size = utils._get_size(root)
      -- width = max of " 3<name>" for each child (icon_size=3, concatenated as string)
      -- " 3a_longer_name" = 15 chars
      assert.equals(15, size.w)
    end)
  end)

  describe("_apply_bounds", function()
    it("returns input unchanged when no bounds set", function()
      local result = utils._apply_bounds({}, { w = 50, h = 30 })
      assert.equals(50, result.w)
      assert.equals(30, result.h)
    end)

    it("clamps height to max_h", function()
      local result = utils._apply_bounds({ max_h = 20 }, { w = 50, h = 30 })
      assert.equals(20, result.h)
    end)

    it("clamps height up to min_h", function()
      local result = utils._apply_bounds({ min_h = 10 }, { w = 50, h = 5 })
      assert.equals(10, result.h)
    end)

    it("applies both min and max", function()
      local result = utils._apply_bounds({ min_h = 10, max_h = 20 }, { w = 50, h = 5 })
      assert.equals(10, result.h)

      result = utils._apply_bounds({ min_h = 10, max_h = 20 }, { w = 50, h = 25 })
      assert.equals(20, result.h)
    end)

    it("preserves width unchanged", function()
      local result = utils._apply_bounds({ max_h = 10 }, { w = 100, h = 30 })
      assert.equals(100, result.w)
    end)
  end)

  describe("_get_dimensions", function()
    it("calculates mid dimensions for a root with children", function()
      local root = mock.make_tree({
        { name = "foo" },
        { name = "bar" },
      })
      local dims = utils._get_dimensions(root)
      assert.is_not_nil(dims.mid)
      assert.equals(2, dims.mid.h)
    end)

    it("calculates right dimensions from grandchildren", function()
      -- get_dimensions(node) shows node.children as mid, node.children[1].children as right
      local root = mock.make_tree({
        { name = "child_a", children = {
          { name = "grandchild_1" },
          { name = "grandchild_2" },
        }},
        { name = "child_b" },
      })
      local dims = utils._get_dimensions(root)
      -- right = get_size(root.children[1]) which looks at root.children[1].children
      assert.equals(2, dims.right.h)
    end)

    it("returns empty left when node has no parent table", function()
      local root = mock.make_tree({ { name = "solo" } })
      local dims = utils._get_dimensions(root)
      assert.are.same({}, dims.left)
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
