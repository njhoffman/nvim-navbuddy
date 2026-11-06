-- Exercises the real display: nui layout, windows, buffers and autocmds. Only the
-- LSP request and nvim-web-devicons are left out.
--
-- `pending` specs describe correct behavior for bugs listed in TODO.md. Plenary
-- skips their bodies; change `pending` to `it` in the change that fixes the bug.

local actions = require("nvim-navbuddy.actions")
local mock = require("tests.helpers.mock_nodes")

local NORMAL_WINHL = "Normal:NavbuddyNormalFloat,FloatBorder:NavbuddyFloatBorder"
local DIM_WINHL = "Normal:NavbuddyNormalFloatDim,FloatBorder:NavbuddyFloatBorderDim"

local TREE = {
  {
    name = "first",
    children = {
      { name = "child_a" },
      { name = "child_b" },
    },
  },
  { name = "second" },
  { name = "third" },
  { name = "fourth" },
}

describe("display", function()
  local source_buf, source_win, root, current
  local saved_guicursor, saved_notify

  local function new_config(overrides)
    package.loaded["nvim-navbuddy.config"] = nil
    return vim.tbl_deep_extend("force", require("nvim-navbuddy.config"), overrides or {})
  end

  local function open(focus_node, overrides)
    current = require("nvim-navbuddy.display").new({
      for_buf = source_buf,
      for_win = source_win,
      start_cursor = { 1, 0 },
      focus_node = focus_node,
      config = new_config(overrides),
      lsp_name = "mock_lsp",
    })
    return current
  end

  local function press(action, display)
    action.callback(display or current)
  end

  local function panel_text(popup)
    return table.concat(vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false), "\n")
  end

  local function assert_has(text, expected)
    assert.is_truthy(text:find(expected, 1, true), ("expected %q in %q"):format(expected, text))
  end

  local function assert_lacks(text, unexpected)
    assert.is_falsy(text:find(unexpected, 1, true), ("did not expect %q in %q"):format(unexpected, text))
  end

  local function winhighlight(popup)
    return vim.api.nvim_get_option_value("winhighlight", { win = popup.winid })
  end

  local function source_highlight_count()
    local ns = require("nvim-navbuddy.state").ns
    return #vim.api.nvim_buf_get_extmarks(source_buf, ns, 0, -1, {})
  end

  local function float_count()
    local count = 0
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        count = count + 1
      end
    end
    return count
  end

  local function add_listed_buffer(name)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, name)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "other buffer" })
    return buf
  end

  before_each(function()
    saved_guicursor = vim.o.guicursor
    saved_notify = vim.notify
    vim.notify = function() end

    vim.api.nvim_set_hl(0, "NavbuddySpecIcon", { fg = "#808080" })
    package.preload["nvim-web-devicons"] = nil
    package.loaded["nvim-web-devicons"] = {
      get_icon = function()
        return "x", "NavbuddySpecIcon"
      end,
    }

    root = mock.make_tree(TREE)
    source_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(source_buf, "navbuddy_spec_source.lua")
    vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, mock.source_lines(root))
    vim.api.nvim_set_current_buf(source_buf)
    source_win = vim.api.nvim_get_current_win()
  end)

  after_each(function()
    if current and not current.state.closed then
      pcall(current.close, current)
    end
    current = nil

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
    vim.cmd("silent! %bwipeout!")

    vim.o.guicursor = saved_guicursor
    vim.notify = saved_notify
    package.preload["nvim-web-devicons"] = nil
    package.loaded["nvim-web-devicons"] = nil
  end)

  describe("open", function()
    it("shows siblings, buffer list and children for a top-level node", function()
      local display = open(root.children[1])

      assert_has(panel_text(display.mid), "first")
      assert_has(panel_text(display.mid), "fourth")
      assert_has(panel_text(display.left), "navbuddy_spec_source.lua")
      assert_has(panel_text(display.right), "child_a")
      assert.is_true(display.state.in_buffer_list)
    end)

    it("shows parents and siblings for a nested node", function()
      local display = open(root.children[1].children[2])

      assert_has(panel_text(display.mid), "child_a")
      assert_has(panel_text(display.mid), "child_b")
      assert_has(panel_text(display.left), "second")
      assert_lacks(panel_text(display.left), "navbuddy_spec_source.lua")
      assert.equals("", panel_text(display.right))
      assert.is_false(display.state.in_buffer_list)
    end)

    it("places the mid cursor on the focused node and focuses the mid window", function()
      local display = open(root.children[3])

      assert.equals(3, vim.api.nvim_win_get_cursor(display.mid.winid)[1])
      assert.equals(display.mid.winid, vim.api.nvim_get_current_win())
    end)

    it("shows the breadcrumb path in the title", function()
      local display = open(root.children[1].children[2])
      local title = panel_text(display.title)

      assert_has(title, "first")
      assert_has(title, "child_b")
      assert.is_true(title:find("first", 1, true) < title:find("child_b", 1, true))
    end)

    it("installs the configured mappings on the mid buffer", function()
      local display = open(root.children[1])
      local keys = {}
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(display.mid.bufnr, "n")) do
        keys[map.lhs] = true
      end

      assert.is_true(keys.j)
      assert.is_true(keys.k)
      assert.is_true(keys.h)
      assert.is_true(keys.l)
    end)

    it("moves the source cursor to the focused node and highlights it", function()
      open(root.children[2])

      assert.equals(root.children[2].name_range.start.line, vim.api.nvim_win_get_cursor(source_win)[1])
      assert.is_true(source_highlight_count() > 0)
    end)

    for _, style in ipairs({ "single", "rounded", "double", "solid" }) do
      it("opens with window.border = " .. style, function()
        local display = open(root.children[1], { window = { border = style } })

        assert.is_true(vim.api.nvim_win_is_valid(display.right.winid))
      end)
    end

    it("opens with window.border = none", function()
      local display = open(root.children[1], { window = { border = "none" } })

      assert.is_true(vim.api.nvim_win_is_valid(display.right.winid))
    end)

    it("opens with window.border = shadow", function()
      local display = open(root.children[1], { window = { border = "shadow" } })

      assert.is_true(vim.api.nvim_win_is_valid(display.right.winid))
    end)

    it("opens with a string border on the right section", function()
      local display = open(root.children[1], { window = { sections = { right = { border = "rounded" } } } })

      assert.is_true(vim.api.nvim_win_is_valid(display.right.winid))
    end)

    it("opens with an eight-character border array", function()
      local border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" }
      local display = open(root.children[1], { window = { border = border } })

      assert.is_true(vim.api.nvim_win_is_valid(display.right.winid))
    end)

    it("opens with borders set per section", function()
      local display = open(root.children[1], {
        window = { sections = { left = { border = "double" }, mid = { border = "none" }, right = { border = "none" } } },
      })

      assert.is_true(vim.api.nvim_win_is_valid(display.right.winid))
    end)

    it("opens with a border options table", function()
      local display = open(root.children[1], { window = { sections = { right = { border = { style = "rounded" } } } } })

      assert.is_true(vim.api.nvim_win_is_valid(display.right.winid))
    end)

    it("shows the LSP name on the right border when the style allows it", function()
      local display = open(root.children[1])

      assert.is_not_nil(display.right.border._.text)
    end)

    it("omits the LSP name on a borderless right section", function()
      local display = open(root.children[1], { window = { border = "none" } })

      assert.is_nil(display.right.border._.text)
    end)

    it("does not write the LSP name into the user's border table", function()
      local right_border = { style = "rounded" }
      local config = new_config()
      config.window.sections.right.border = right_border

      current = require("nvim-navbuddy.display").new({
        for_buf = source_buf,
        for_win = source_win,
        start_cursor = { 1, 0 },
        focus_node = root.children[1],
        config = config,
        lsp_name = "mock_lsp",
      })

      assert.is_nil(right_border.text)
    end)

    it("opens at a top-level node without nvim-web-devicons", function()
      package.loaded["nvim-web-devicons"] = nil
      package.preload["nvim-web-devicons"] = function()
        error("module 'nvim-web-devicons' not found")
      end

      local display = open(root.children[1])

      assert_has(panel_text(display.left), "navbuddy_spec_source.lua")
    end)
  end)

  describe("buffer list icons", function()
    local function without_devicons()
      package.loaded["nvim-web-devicons"] = nil
      package.preload["nvim-web-devicons"] = function()
        error("module 'nvim-web-devicons' not found")
      end
    end

    it("opens with theme hl-icon without nvim-web-devicons", function()
      without_devicons()

      local display = open(root.children[1], { theme = "hl-icon" })

      assert_has(panel_text(display.left), "navbuddy_spec_source.lua")
    end)

    it("still lists buffers on redraw without nvim-web-devicons", function()
      without_devicons()
      add_listed_buffer("navbuddy_spec_other.lua")
      local display = open(root.children[1])

      press(actions.next_sibling())

      assert_has(panel_text(display.left), "navbuddy_spec_other.lua")
      assert.equals("second", display.focus_node.name)
    end)

    it("lists a file type that has no icon", function()
      package.loaded["nvim-web-devicons"] = {
        get_icon = function()
          return nil, nil
        end,
      }

      local display = open(root.children[1])

      assert_has(panel_text(display.left), "navbuddy_spec_source.lua")
    end)
  end)

  describe("navigation", function()
    it("moves between nested siblings with next and previous", function()
      local display = open(root.children[1].children[1])

      press(actions.next_sibling())
      assert.equals("child_b", display.focus_node.name)
      assert.equals(2, vim.api.nvim_win_get_cursor(display.mid.winid)[1])

      press(actions.previous_sibling())
      assert.equals("child_a", display.focus_node.name)
    end)

    it("stays on the last nested sibling", function()
      local display = open(root.children[1].children[2])

      press(actions.next_sibling())

      assert.equals("child_b", display.focus_node.name)
    end)

    it("moves into children and back to the parent", function()
      local display = open(root.children[1])

      press(actions.children())
      assert.equals("child_a", display.focus_node.name)
      assert_has(panel_text(display.left), "first")

      press(actions.parent())
      assert.equals("first", display.focus_node.name)
      assert_has(panel_text(display.left), "navbuddy_spec_source.lua")
    end)

    it("returns to the remembered child", function()
      local display = open(root.children[1].children[2])
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = display.mid.bufnr })

      press(actions.parent())
      press(actions.children())

      assert.equals("child_b", display.focus_node.name)
    end)

    it("jumps to the top level with root", function()
      local display = open(root.children[1].children[2])

      press(actions.root())

      assert.equals("first", display.focus_node.name)
      assert.is_true(display.state.in_buffer_list)
    end)

    it("follows the mid cursor on CursorMoved", function()
      local display = open(root.children[1].children[1])

      vim.api.nvim_win_set_cursor(display.mid.winid, { 2, 0 })
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = display.mid.bufnr })

      assert.equals("child_b", display.focus_node.name)
      assert.equals(root.children[1].children[2].name_range.start.line, vim.api.nvim_win_get_cursor(source_win)[1])
    end)

    it("moves between top-level siblings outside buffer focus mode", function()
      local display = open(root.children[1])

      press(actions.next_sibling())
      assert.equals("second", display.focus_node.name)
      assert.equals(2, vim.api.nvim_win_get_cursor(display.mid.winid)[1])

      press(actions.previous_sibling())
      assert.equals("first", display.focus_node.name)
    end)
  end)

  describe("buffer focus mode", function()
    it("dims mid and right and enables the left cursorline", function()
      local display = open(root.children[1])

      press(actions.parent())

      assert.is_true(display.state.buffer_focused)
      assert.is_true(vim.wo[display.left.winid].cursorline)
      assert.equals(DIM_WINHL, winhighlight(display.mid))
      assert.equals(DIM_WINHL, winhighlight(display.right))
    end)

    it("restores the panes when exited", function()
      local display = open(root.children[1])

      press(actions.parent())
      press(actions.children())

      assert.is_false(display.state.buffer_focused)
      assert.is_false(vim.wo[display.left.winid].cursorline)
      assert.equals(NORMAL_WINHL, winhighlight(display.mid))
      assert.equals(NORMAL_WINHL, winhighlight(display.right))
      assert.equals("first", display.focus_node.name)
    end)

    it("leaves the buffer list alone outside focus mode", function()
      add_listed_buffer("navbuddy_spec_other.lua")
      local display = open(root.children[1])

      press(actions.next_sibling())

      assert.equals(1, vim.api.nvim_win_get_cursor(display.left.winid)[1])
      assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
    end)

    it("live-switches the source window while moving through the list", function()
      local other = add_listed_buffer("navbuddy_spec_other.lua")
      local display = open(root.children[1])

      press(actions.parent())
      press(actions.next_sibling())

      assert.equals(2, vim.api.nvim_win_get_cursor(display.left.winid)[1])
      assert.equals(other, vim.api.nvim_win_get_buf(source_win))
    end)

    pending("keeps for_buf and the source window consistent when the target has no LSP", function()
      add_listed_buffer("navbuddy_spec_other.lua")
      local display = open(root.children[1])

      press(actions.parent())
      press(actions.next_sibling())

      assert.equals(display.for_buf, vim.api.nvim_win_get_buf(source_win))
    end)
  end)

  describe("preview", function()
    it("shows the source on a leaf and dims left and mid", function()
      local display = open(root.children[2])

      press(actions.children())

      assert.is_true(display.state.preview_focused)
      assert.equals(source_buf, vim.api.nvim_win_get_buf(display.right.winid))
      assert.equals(DIM_WINHL, winhighlight(display.left))
      assert.equals(DIM_WINHL, winhighlight(display.mid))
    end)

    it("restores the panes when preview focus exits", function()
      local display = open(root.children[2])

      press(actions.children())
      press(actions.parent())

      assert.is_false(display.state.preview_focused)
      assert.equals(display.right.bufnr, vim.api.nvim_win_get_buf(display.right.winid))
      assert.equals(NORMAL_WINHL, winhighlight(display.left))
      assert.equals(NORMAL_WINHL, winhighlight(display.mid))
    end)

    it("exits preview focus and moves on next_sibling", function()
      local display = open(root.children[2])

      press(actions.children())
      press(actions.next_sibling())

      assert.is_false(display.state.preview_focused)
      assert.equals("third", display.focus_node.name)
      assert.equals(display.right.bufnr, vim.api.nvim_win_get_buf(display.right.winid))
      assert.equals(NORMAL_WINHL, winhighlight(display.mid))
    end)

    it("toggles with toggle_preview", function()
      local display = open(root.children[1])

      press(actions.toggle_preview())
      assert.equals(source_buf, vim.api.nvim_win_get_buf(display.right.winid))

      press(actions.toggle_preview())
      assert.equals(display.right.bufnr, vim.api.nvim_win_get_buf(display.right.winid))
    end)

    it("opens with sections.right.preview = always", function()
      local display = open(root.children[1], { window = { sections = { right = { preview = "always" } } } })

      assert.equals(source_buf, vim.api.nvim_win_get_buf(display.right.winid))
    end)
  end)

  describe("moving nodes", function()
    it("swaps the source text and keeps focus on the moved node", function()
      local display = open(root.children[2])

      press(actions.move_down())

      local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
      local second = display.focus_node
      assert.equals("second", second.name)
      assert.equals(3, second.index)
      assert.equals("second {", lines[second.name_range.start.line])
      assert.equals("third {", lines[root.children[2].name_range.start.line])
    end)

    it("relinks the neighbors of the swapped nodes", function()
      open(root.children[2])
      local first, fourth = root.children[1], root.children[4]

      press(actions.move_down())

      assert.equals("third", first.next.name)
      assert.equals("second", fourth.prev.name)
    end)

    it("shifts the ranges of descendants of a moved node", function()
      open(root.children[1])
      local child = root.children[1].children[1]

      press(actions.move_down())

      local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
      assert.equals("child_a {", lines[child.name_range.start.line])
    end)
  end)

  describe("moving nodes across trees", function()
    local function assert_ranges_match_source()
      local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)

      local function check(node)
        assert.equals(node.name .. " {", lines[node.name_range.start.line])
        assert.equals(node.name .. " {", lines[node.scope.start.line])
        assert.equals("}", lines[node.scope["end"].line])
        for _, child in ipairs(node.children or {}) do
          check(child)
        end
      end

      for _, node in ipairs(root.children) do
        check(node)
      end
    end

    it("keeps every range matching the source after moving down", function()
      open(root.children[1])

      press(actions.move_down())

      assert_ranges_match_source()
    end)

    it("keeps every range matching the source after moving up", function()
      open(root.children[2])

      press(actions.move_up())

      assert_ranges_match_source()
    end)

    it("keeps ranges matching across repeated moves", function()
      open(root.children[1])

      press(actions.move_down())
      press(actions.move_down())
      press(actions.move_up())

      assert_ranges_match_source()
    end)

    it("shifts grandchildren of a moved node", function()
      root = mock.make_tree({
        { name = "outer", children = { { name = "middle", children = { { name = "inner" } } } } },
        { name = "after" },
      })
      vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, mock.source_lines(root))
      open(root.children[1])

      press(actions.move_down())

      assert_ranges_match_source()
    end)

    it("shifts once when scope and name_range are the same table", function()
      for _, node in ipairs(root.children) do
        node.name_range = node.scope
      end
      open(root.children[2])
      local start_line = root.children[2].scope.start.line
      local third_lines = root.children[3].scope["end"].line - root.children[3].scope.start.line + 1
      local second = root.children[2]

      press(actions.move_down())

      assert.equals(start_line + third_lines, second.scope.start.line)
    end)

    it("traverses siblings in the new order after a move", function()
      local display = open(root.children[2])

      press(actions.move_down())
      press(actions.previous_sibling())
      assert.equals("third", display.focus_node.name)

      press(actions.previous_sibling())
      assert.equals("first", display.focus_node.name)

      press(actions.next_sibling())
      press(actions.next_sibling())
      press(actions.next_sibling())
      assert.equals("fourth", display.focus_node.name)
    end)
  end)

  describe("closing", function()
    it("removes the windows, source highlights and hidden cursor", function()
      local before = vim.o.guicursor
      local display = open(root.children[2])
      assert.is_true(float_count() > 0)
      assert.are_not.equal(before, vim.o.guicursor)

      display:close()

      assert.equals(0, float_count())
      assert.equals(0, source_highlight_count())
      assert.equals(before, vim.o.guicursor)
      assert.is_true(display.state.closed)
    end)

    it("returns the cursor to the start position on the close action", function()
      open(root.children[3])

      press(actions.close())

      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(source_win))
    end)

    it("leaves the cursor on the node on the select action", function()
      open(root.children[3])

      press(actions.select())

      assert.equals(root.children[3].name_range.start.line, vim.api.nvim_win_get_cursor(source_win)[1])
      assert.equals(0, float_count())
    end)

    it("closes when focus leaves the mid window", function()
      local display = open(root.children[2])

      vim.api.nvim_set_current_win(source_win)

      assert.is_true(display.state.closed)
      assert.equals(0, float_count())
    end)

    it("closes on VimResized", function()
      local display = open(root.children[2])

      vim.api.nvim_exec_autocmds("VimResized", {})

      assert.is_true(display.state.closed)
    end)
  end)
end)
