local actions = require("nvim-navbuddy.actions")
local mock = require("tests.helpers.mock_nodes")

local function make_display(focus_node, opts)
  opts = opts or {}
  local redrawn = false
  local buffer_selected = false
  local buffer_focus_entered = false
  local buffer_focus_exited = false
  local preview_focus_entered = false
  local preview_focus_exited = false
  return {
    focus_node = focus_node,
    for_buf = vim.api.nvim_create_buf(false, true),
    for_win = vim.api.nvim_get_current_win(),
    start_cursor = { 1, 0 },
    state = {
      in_buffer_list = opts.in_buffer_list or false,
      buffer_focused = opts.buffer_focused or false,
      preview_focused = opts.preview_focused or false,
    },
    config = require("nvim-navbuddy.config"),
    redrawn = function() return redrawn end,
    redraw = function(self) redrawn = true end,
    close = function() end,
    navigate_buffer_list = function() return opts.can_navigate or false end,
    select_buffer = function(self) buffer_selected = true end,
    enter_buffer_focus = function(self) self.state.buffer_focused = true; buffer_focus_entered = true end,
    exit_buffer_focus = function(self) self.state.buffer_focused = false; buffer_focus_exited = true end,
    enter_preview_focus = function(self) self.state.preview_focused = true; preview_focus_entered = true end,
    exit_preview_focus = function(self) self.state.preview_focused = false; preview_focus_exited = true end,
    _test = {
      was_buffer_selected = function() return buffer_selected end,
      was_focus_entered = function() return buffer_focus_entered end,
      was_focus_exited = function() return buffer_focus_exited end,
      was_preview_entered = function() return preview_focus_entered end,
      was_preview_exited = function() return preview_focus_exited end,
    },
  }
end

describe("actions", function()
  describe("next_sibling", function()
    it("moves to next node", function()
      local root = mock.make_tree({
        { name = "first" },
        { name = "second" },
        { name = "third" },
      })
      local display = make_display(root.children[1])
      actions.next_sibling().callback(display)
      assert.equals("second", display.focus_node.name)
    end)

    it("stops at last node", function()
      local root = mock.make_tree({
        { name = "first" },
        { name = "last" },
      })
      local display = make_display(root.children[2])
      actions.next_sibling().callback(display)
      assert.equals("last", display.focus_node.name)
    end)
  end)

  describe("previous_sibling", function()
    it("moves to previous node", function()
      local root = mock.make_tree({
        { name = "first" },
        { name = "second" },
        { name = "third" },
      })
      local display = make_display(root.children[3])
      actions.previous_sibling().callback(display)
      assert.equals("second", display.focus_node.name)
    end)

    it("stops at first node", function()
      local root = mock.make_tree({
        { name = "first" },
        { name = "second" },
      })
      local display = make_display(root.children[1])
      actions.previous_sibling().callback(display)
      assert.equals("first", display.focus_node.name)
    end)
  end)

  describe("parent", function()
    it("moves to parent node", function()
      local root = mock.make_tree({
        { name = "outer", children = {
          { name = "inner" },
        }},
      })
      local inner = root.children[1].children[1]
      local display = make_display(inner)
      actions.parent().callback(display)
      assert.equals("outer", display.focus_node.name)
    end)

    it("does not move past root", function()
      local root = mock.make_tree({
        { name = "top_level" },
      })
      local display = make_display(root.children[1])
      actions.parent().callback(display)
      -- At root level, parent() should not change focus_node to root itself
      assert.equals("top_level", display.focus_node.name)
    end)
  end)

  describe("children", function()
    it("moves to first child", function()
      local root = mock.make_tree({
        { name = "parent_fn", children = {
          { name = "child_a" },
          { name = "child_b" },
        }},
      })
      local display = make_display(root.children[1])
      actions.children().callback(display)
      assert.equals("child_a", display.focus_node.name)
    end)

    it("uses memory for child selection", function()
      local root = mock.make_tree({
        { name = "parent_fn", children = {
          { name = "child_a" },
          { name = "child_b" },
        }},
      })
      root.children[1].memory = 2
      local display = make_display(root.children[1])
      actions.children().callback(display)
      assert.equals("child_b", display.focus_node.name)
    end)
  end)

  describe("buffer_focus_mode", function()
    it("parent enters buffer focus when at root with buffer list", function()
      local root = mock.make_tree({ { name = "top" } })
      local display = make_display(root.children[1], { in_buffer_list = true })
      actions.parent().callback(display)
      assert.is_true(display._test.was_focus_entered())
      assert.is_true(display.state.buffer_focused)
    end)

    it("parent calls select_buffer when already focused", function()
      local root = mock.make_tree({ { name = "top" } })
      local display = make_display(root.children[1], { in_buffer_list = true, buffer_focused = true })
      actions.parent().callback(display)
      assert.is_true(display._test.was_buffer_selected())
    end)

    it("next_sibling live-switches buffer when focused", function()
      local root = mock.make_tree({ { name = "top" } })
      local display = make_display(root.children[1], {
        in_buffer_list = true,
        buffer_focused = true,
        can_navigate = true,
      })
      actions.next_sibling().callback(display)
      assert.is_true(display._test.was_buffer_selected())
    end)

    it("previous_sibling live-switches buffer when focused", function()
      local root = mock.make_tree({ { name = "top" } })
      local display = make_display(root.children[1], {
        in_buffer_list = true,
        buffer_focused = true,
        can_navigate = true,
      })
      actions.previous_sibling().callback(display)
      assert.is_true(display._test.was_buffer_selected())
    end)

    it("next_sibling does not select buffer when not focused", function()
      local root = mock.make_tree({ { name = "top" } })
      local display = make_display(root.children[1], {
        in_buffer_list = true,
        buffer_focused = false,
        can_navigate = true,
      })
      actions.next_sibling().callback(display)
      assert.is_false(display._test.was_buffer_selected())
    end)

    it("children exits buffer focus mode", function()
      local root = mock.make_tree({
        { name = "top", children = { { name = "child" } } },
      })
      local display = make_display(root.children[1], { buffer_focused = true })
      actions.children().callback(display)
      assert.is_true(display._test.was_focus_exited())
      assert.is_false(display.state.buffer_focused)
    end)
  end)

  describe("preview_focus_mode", function()
    it("children enters preview focus on leaf node", function()
      local root = mock.make_tree({
        { name = "leaf_fn" },
      })
      local display = make_display(root.children[1])
      actions.children().callback(display)
      assert.is_true(display._test.was_preview_entered())
      assert.is_true(display.state.preview_focused)
    end)

    it("children does nothing when already in preview focus", function()
      local root = mock.make_tree({
        { name = "leaf_fn" },
      })
      local display = make_display(root.children[1], { preview_focused = true })
      actions.children().callback(display)
      -- Should not enter again (already focused)
      assert.is_false(display._test.was_preview_entered())
    end)

    it("parent exits preview focus", function()
      local root = mock.make_tree({
        { name = "outer", children = {
          { name = "leaf" },
        }},
      })
      local inner = root.children[1].children[1]
      local display = make_display(inner, { preview_focused = true })
      actions.parent().callback(display)
      assert.is_true(display._test.was_preview_exited())
      assert.is_false(display.state.preview_focused)
    end)

    it("next_sibling exits preview focus and navigates", function()
      local root = mock.make_tree({
        { name = "first" },
        { name = "second" },
      })
      local display = make_display(root.children[1], { preview_focused = true })
      actions.next_sibling().callback(display)
      assert.is_true(display._test.was_preview_exited())
      assert.equals("second", display.focus_node.name)
    end)

    it("previous_sibling exits preview focus and navigates", function()
      local root = mock.make_tree({
        { name = "first" },
        { name = "second" },
      })
      local display = make_display(root.children[2], { preview_focused = true })
      actions.previous_sibling().callback(display)
      assert.is_true(display._test.was_preview_exited())
      assert.equals("first", display.focus_node.name)
    end)
  end)

  describe("root", function()
    it("navigates to top level from nested node", function()
      local root = mock.make_tree({
        { name = "level1", children = {
          { name = "level2", children = {
            { name = "level3" },
          }},
        }},
      })
      local deep = root.children[1].children[1].children[1]
      local display = make_display(deep)
      actions.root().callback(display)
      assert.equals("level1", display.focus_node.name)
      assert.is_true(display.focus_node.parent.is_root)
    end)

    it("does nothing when already at root level", function()
      local root = mock.make_tree({
        { name = "top" },
      })
      local display = make_display(root.children[1])
      actions.root().callback(display)
      assert.equals("top", display.focus_node.name)
    end)
  end)
end)
