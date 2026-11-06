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
  local saved_guicursor, saved_notify, notifications

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
    notifications = {}
    vim.notify = function(message)
      table.insert(notifications, message)
    end

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

  describe("layout", function()
    local saved_columns, saved_lines

    before_each(function()
      saved_columns, saved_lines = vim.o.columns, vim.o.lines
      vim.o.columns, vim.o.lines = 100, 40
    end)

    after_each(function()
      if current and not current.state.closed then
        pcall(current.close, current)
      end
      vim.o.columns, vim.o.lines = saved_columns, saved_lines
    end)

    local function outer_width(popup)
      local win_config = vim.api.nvim_win_get_config(popup.winid)
      return vim.api.nvim_win_get_width(popup.winid) + (#win_config.border > 0 and 2 or 0)
    end

    local function total_height(display)
      return vim.api.nvim_win_get_height(display.title.winid) + vim.api.nvim_win_get_height(display.mid.winid)
    end

    it("keeps the default 80x15 window", function()
      local display = open(root.children[1])

      assert.equals(80, vim.api.nvim_win_get_width(display.title.winid) + 2)
      assert.equals(11, total_height(display) - 1)
    end)

    it("applies a fixed window.size", function()
      local display = open(root.children[1], { window = { size = { width = 60, height = 20 } } })

      assert.equals(60, vim.api.nvim_win_get_width(display.title.winid) + 2)
      assert.equals(16, total_height(display) - 1)
    end)

    it("applies a percentage window.size to both dimensions", function()
      local display = open(root.children[1], { window = { size = "50%" } })

      assert.equals(50, vim.api.nvim_win_get_width(display.title.winid) + 2)
      assert.equals(16, total_height(display) - 1)
    end)

    it("applies window.position", function()
      local top_left = open(root.children[1], { window = { position = { row = 0, col = 0 } } })
      local start_pos = vim.fn.win_screenpos(top_left.title.winid)
      top_left:close()

      local bottom_right = open(root.children[1], { window = { position = { row = "100%", col = "100%" } } })
      local end_pos = vim.fn.win_screenpos(bottom_right.title.winid)

      assert.is_true(start_pos[1] < end_pos[1])
      assert.is_true(start_pos[2] < end_pos[2])
    end)

    it("applies section sizes and lets the right section fill the rest", function()
      local narrow =
        open(root.children[1], { window = { sections = { left = { size = "20%" }, mid = { size = "20%" } } } })
      local narrow_left, narrow_mid = outer_width(narrow.left), outer_width(narrow.mid)
      local narrow_right = vim.api.nvim_win_get_width(narrow.right.winid)
      narrow:close()

      local wide =
        open(root.children[1], { window = { sections = { left = { size = "40%" }, mid = { size = "40%" } } } })

      assert.is_true(narrow_left < outer_width(wide.left))
      assert.is_true(narrow_mid < outer_width(wide.mid))
      assert.is_true(narrow_right > vim.api.nvim_win_get_width(wide.right.winid))
    end)

    it("applies a section's win_options to that section only", function()
      local display = open(root.children[1], { window = { sections = { mid = { win_options = { number = true } } } } })

      assert.is_true(vim.wo[display.mid.winid].number)
      assert.is_false(vim.wo[display.left.winid].number)
    end)

    it("applies a section's buf_options to that section only", function()
      local display = open(root.children[1], { window = { sections = { mid = { buf_options = { tabstop = 3 } } } } })

      assert.equals(3, vim.bo[display.mid.bufnr].tabstop)
      assert.are_not.equal(3, vim.bo[display.left.bufnr].tabstop)
    end)

    it("restores a section's own winhighlight after buffer focus", function()
      local custom = "Normal:Comment"
      local display =
        open(root.children[1], { window = { sections = { mid = { win_options = { winhighlight = custom } } } } })

      assert.equals(custom, winhighlight(display.mid))
      press(actions.parent())
      assert.equals(DIM_WINHL, winhighlight(display.mid))
      press(actions.children())
      assert.equals(custom, winhighlight(display.mid))
    end)

    it("applies window.winblend", function()
      local display = open(root.children[1], { window = { winblend = 20 } })

      assert.equals(20, vim.wo[display.mid.winid].winblend)
    end)

    it("uses the configured theme", function()
      local display = open(root.children[1], { theme = "hl-icon" })

      assert_has(panel_text(display.mid), "first")
    end)

    for _, case in ipairs({ { 60, 40 }, { 100, 10 }, { 40, 8 } }) do
      it(("opens the default window on a %dx%d screen"):format(case[1], case[2]), function()
        vim.o.columns, vim.o.lines = case[1], case[2]

        local display = open(root.children[1])

        assert.is_true(vim.api.nvim_win_is_valid(display.mid.winid))
        assert.is_true(vim.api.nvim_win_get_height(display.mid.winid) >= 1)
      end)
    end
  end)

  describe("text widths", function()
    local function open_named(names, overrides)
      local specs = {}
      for i, name in ipairs(names) do
        specs[i] = { name = name }
      end
      root = mock.make_tree(specs)
      vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, mock.source_lines(root))
      return open(root.children[1], overrides)
    end

    local function mid_lines(display)
      return vim.api.nvim_buf_get_lines(display.mid.bufnr, 0, -1, false)
    end

    local function is_valid_utf8(text)
      local i = 1
      while i <= #text do
        local byte = text:byte(i)
        local length = byte < 0x80 and 1
          or (byte >= 0xC2 and byte < 0xE0) and 2
          or (byte >= 0xE0 and byte < 0xF0) and 3
          or (byte >= 0xF0 and byte < 0xF5) and 4
        if not length or i + length - 1 > #text then
          return false
        end
        for j = i + 1, i + length - 1 do
          local continuation = text:byte(j)
          if continuation < 0x80 or continuation > 0xBF then
            return false
          end
        end
        i = i + length
      end
      return true
    end

    it("fills each line to the same display width whatever the name", function()
      local display = open_named({ "plain", "日本語", "café" })
      local lines = mid_lines(display)

      local width = vim.fn.strdisplaywidth(lines[1])
      assert.equals(width, vim.fn.strdisplaywidth(lines[2]))
      assert.equals(width, vim.fn.strdisplaywidth(lines[3]))
    end)

    it("leaves room for the node marker inside the window", function()
      local display = open_named({ "plain" })

      local line_width = vim.fn.strdisplaywidth(mid_lines(display)[1])
      assert.is_true(line_width < vim.api.nvim_win_get_width(display.mid.winid))
    end)

    it("uses the whole width when node markers are off", function()
      local display = open_named({ "plain" }, { node_markers = { enabled = false } })

      local line_width = vim.fn.strdisplaywidth(mid_lines(display)[1])
      assert.equals(vim.api.nvim_win_get_width(display.mid.winid), line_width)
    end)

    it("shortens a long multibyte name on a character boundary", function()
      local display = open_named({ string.rep("日本語", 30) })
      local line = mid_lines(display)[1]

      assert.is_false(is_valid_utf8(("日"):sub(1, 2)))
      assert.is_true(is_valid_utf8(line))
      assert_has(line, "…")
      assert.is_true(vim.fn.strdisplaywidth(line) < vim.api.nvim_win_get_width(display.mid.winid))
    end)

    it("centers the title by display width", function()
      local display = open_named({ "日本語" })
      local line = vim.api.nvim_buf_get_lines(display.title.bufnr, 0, 1, false)[1]
      local indent = #line:match("^ *")
      local text_width = vim.fn.strdisplaywidth(line) - indent
      local win_width = vim.api.nvim_win_get_width(display.title.winid)

      assert.equals(math.floor((win_width - text_width) / 2), indent)
    end)

    it("highlights exactly the icon of each title node", function()
      local display = open(root.children[1].children[1])
      local line = vim.api.nvim_buf_get_lines(display.title.bufnr, 0, 1, false)[1]
      local icon = display.config.icons[12]
      local ns = require("nvim-navbuddy.state").ns
      local marks = vim.api.nvim_buf_get_extmarks(display.title.bufnr, ns, 0, -1, { details = true })

      assert.equals(2, #marks)
      for _, mark in ipairs(marks) do
        assert.equals("NavbuddyFunction", mark[4].hl_group)
        assert.equals(icon, line:sub(mark[3] + 1, mark[4].end_col))
      end
    end)

    it("shortens a title that cannot fit without hanging", function()
      local display = open_named({ string.rep("long_name_", 40) })
      local line = vim.api.nvim_buf_get_lines(display.title.bufnr, 0, 1, false)[1]

      assert_has(line, "…")
      assert.is_true(vim.fn.strdisplaywidth(line) <= vim.api.nvim_win_get_width(display.title.winid))
    end)

    it("highlights the whole icon with theme hl-icon", function()
      local display = open_named({ "plain" }, { theme = "hl-icon" })
      local line = mid_lines(display)[1]
      local icon = display.config.icons[12]
      local ns = require("nvim-navbuddy.state").ns
      local found = false

      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(display.mid.bufnr, ns, 0, -1, { details = true })) do
        if mark[2] == 0 and mark[4].hl_group == "NavbuddyFunction" and mark[4].end_col then
          found = found or line:sub(mark[3] + 1, mark[4].end_col) == icon
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("help", function()
    local saved_lines

    before_each(function()
      saved_lines = vim.o.lines
    end)

    after_each(function()
      vim.o.lines = saved_lines
    end)

    local function help_win()
      local win = vim.api.nvim_get_current_win()
      assert.are_not.equal("", vim.api.nvim_win_get_config(win).relative)
      return win
    end

    it("fits every mapping in a centered window", function()
      vim.o.lines = 60
      open(root.children[2], { window = { position = { row = 0, col = 0 } } })

      press(actions.help())

      local win = help_win()
      local buf = vim.api.nvim_win_get_buf(win)
      assert.equals(vim.api.nvim_buf_line_count(buf), vim.api.nvim_win_get_height(win))
      assert.is_true(vim.fn.win_screenpos(win)[1] > 5)
      vim.api.nvim_win_close(win, true)
    end)

    it("stays within a short screen", function()
      vim.o.lines = 12
      open(root.children[2])

      press(actions.help())

      local win = help_win()
      assert.is_true(vim.api.nvim_win_get_height(win) <= 8)
      vim.api.nvim_win_close(win, true)
    end)

    it("opens with a border character list", function()
      open(root.children[2], { window = { border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" } } })

      press(actions.help())

      vim.api.nvim_win_close(help_win(), true)
    end)

    it("reopens Navbuddy when closed with q", function()
      local display = open(root.children[2])

      press(actions.help())
      vim.cmd("normal q")

      assert.is_false(display.state.closed)
      assert.equals("second", display.focus_node.name)
      assert.equals(display.mid.winid, vim.api.nvim_get_current_win())
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

    it("lists a file whose icon highlight has no foreground", function()
      vim.api.nvim_set_hl(0, "NavbuddySpecNoFg", { bg = "#808080" })
      package.loaded["nvim-web-devicons"] = {
        get_icon = function()
          return "x", "NavbuddySpecNoFg"
        end,
      }

      local display = open(root.children[1])

      assert_has(panel_text(display.left), "navbuddy_spec_source.lua")
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

    it("does not switch to a buffer with no LSP", function()
      local display = open(root.children[1])
      add_listed_buffer("navbuddy_spec_other.lua")

      press(actions.parent())
      display:redraw()
      press(actions.next_sibling())

      assert.equals(2, vim.api.nvim_win_get_cursor(display.left.winid)[1])
      assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
      assert.equals(source_buf, display.for_buf)
      assert.equals("first", display.focus_node.name)
      assert.equals("No LSP server attached to buffer", notifications[1])
    end)

    describe("with an LSP server", function()
      local requests, held, hold_responses, symbols_by_buf, clients
      local other, third_buf

      local function symbols_for(names)
        local symbols = {}
        for i, name in ipairs(names) do
          local first = (i - 1) * 2
          local range = { start = { line = first, character = 0 }, ["end"] = { line = first + 1, character = 1 } }
          local selection = { start = { line = first, character = 0 }, ["end"] = { line = first, character = #name } }
          table.insert(symbols, { name = name, kind = 12, range = range, selectionRange = selection })
        end
        return symbols
      end

      local function lines_for(names)
        local lines = {}
        for _, name in ipairs(names) do
          table.insert(lines, name .. " {")
          table.insert(lines, "}")
        end
        return lines
      end

      local function server(dispatchers)
        return {
          request = function(method, params, callback)
            if method == "initialize" then
              callback(nil, { capabilities = { documentSymbolProvider = true } })
            elseif method == "textDocument/documentSymbol" then
              local uri = params.textDocument.uri
              table.insert(requests, uri)
              local function respond()
                callback(nil, symbols_by_buf[vim.uri_to_bufnr(uri)])
              end
              if hold_responses then
                table.insert(held, respond)
              else
                vim.schedule(respond)
              end
            else
              callback(nil, nil)
            end
            return true, #requests
          end,
          notify = function()
            return true
          end,
          is_closing = function()
            return false
          end,
          terminate = function()
            dispatchers.on_exit(0, 15)
          end,
        }
      end

      local function attach(bufnr, name)
        local id = vim.lsp.start({
          name = name or "mock_lsp",
          cmd = server,
          root_dir = vim.fn.getcwd(),
        }, { bufnr = bufnr })
        local client = vim.lsp.get_client_by_id(id)
        clients[id] = client
        assert.is_true(vim.wait(1000, function()
          return client.initialized
        end, 5))
        return client
      end

      local function add_lsp_buffer(name, symbol_names, server_name)
        local buf = add_listed_buffer(name)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines_for(symbol_names))
        symbols_by_buf[buf] = symbols_for(symbol_names)
        attach(buf, server_name)
        return buf
      end

      local function wait_for_buffer(display, bufnr)
        assert.is_true(vim.wait(1000, function()
          return display.for_buf == bufnr
        end, 5))
      end

      local function flush()
        vim.wait(30, function()
          return false
        end, 5)
      end

      local function open_focused()
        local display = open(root.children[1])
        display:redraw()
        press(actions.parent())
        return display
      end

      before_each(function()
        requests, held, hold_responses, symbols_by_buf, clients = {}, {}, false, {}, {}
        symbols_by_buf[source_buf] = symbols_for({ "first", "second" })
        attach(source_buf)
        other = add_lsp_buffer("navbuddy_spec_other.lua", { "other_one", "other_two" })
        third_buf = add_lsp_buffer("navbuddy_spec_third.lua", { "third_one" })
      end)

      after_each(function()
        if current and not current.state.closed then
          pcall(current.close, current)
        end
        for _, client in pairs(clients) do
          client:stop(true)
        end
        vim.wait(1000, function()
          return #vim.lsp.get_clients() == 0
        end, 5)
      end)

      it("requests symbols for the selected buffer, not the Navbuddy window", function()
        local display = open_focused()

        press(actions.next_sibling())
        wait_for_buffer(display, other)

        assert.same({ vim.uri_from_bufnr(other) }, requests)
      end)

      it("switches window, nodes and panels once symbols arrive", function()
        local display = open_focused()

        press(actions.next_sibling())
        wait_for_buffer(display, other)

        assert.equals(other, vim.api.nvim_win_get_buf(source_win))
        assert.equals("other_one", display.focus_node.name)
        assert_has(panel_text(display.mid), "other_two")
        assert_lacks(panel_text(display.mid), "first")
        assert.is_true(display.state.buffer_focused)
        assert.equals(2, vim.api.nvim_win_get_cursor(display.left.winid)[1])
      end)

      it("leaves the window alone until symbols arrive", function()
        local display = open_focused()
        hold_responses = true

        press(actions.next_sibling())

        assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
        assert.equals(source_buf, display.for_buf)

        held[1]()
        wait_for_buffer(display, other)
      end)

      it("moves source highlights to the new buffer", function()
        local display = open_focused()
        local ns = require("nvim-navbuddy.state").ns

        press(actions.next_sibling())
        wait_for_buffer(display, other)

        assert.equals(0, source_highlight_count())
        assert.is_true(#vim.api.nvim_buf_get_extmarks(other, ns, 0, -1, {}) > 0)
      end)

      it("ignores a response superseded by a newer selection", function()
        local display = open_focused()
        hold_responses = true

        press(actions.next_sibling())
        press(actions.next_sibling())
        assert.equals(2, #held)

        held[2]()
        wait_for_buffer(display, third_buf)
        held[1]()
        flush()

        assert.equals(third_buf, display.for_buf)
        assert.equals(third_buf, vim.api.nvim_win_get_buf(source_win))
        assert.equals("third_one", display.focus_node.name)
      end)

      it("ignores a response that arrives after closing", function()
        local display = open_focused()
        hold_responses = true

        press(actions.next_sibling())
        press(actions.close())
        held[1]()
        flush()

        assert.equals(source_buf, display.for_buf)
        assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
      end)

      it("does not switch to a buffer with no symbols", function()
        symbols_by_buf[other] = {}
        local display = open_focused()

        press(actions.next_sibling())
        flush()

        assert.equals(source_buf, display.for_buf)
        assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
        assert.equals("first", display.focus_node.name)
        assert.equals("No symbols found in buffer", notifications[1])
      end)

      it("switches back to the original buffer", function()
        local display = open_focused()

        press(actions.next_sibling())
        wait_for_buffer(display, other)
        press(actions.previous_sibling())
        wait_for_buffer(display, source_buf)

        assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
        assert.equals("first", display.focus_node.name)
      end)

      it("returns to the original buffer and cursor on close", function()
        local display = open_focused()

        press(actions.next_sibling())
        wait_for_buffer(display, other)
        press(actions.close())

        assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(source_win))
      end)

      it("stays on a confirmed buffer on close", function()
        local display = open_focused()

        press(actions.next_sibling())
        wait_for_buffer(display, other)
        press(actions.parent())
        press(actions.close())

        assert.equals(other, vim.api.nvim_win_get_buf(source_win))
      end)

      it("confirms a selection whose response is still in flight", function()
        local display = open_focused()
        hold_responses = true

        press(actions.next_sibling())
        press(actions.parent())
        held[2]()
        wait_for_buffer(display, other)
        press(actions.close())

        assert.equals(other, vim.api.nvim_win_get_buf(source_win))
      end)

      it("goes to a node in the new buffer on select and records the jump", function()
        local display = open_focused()

        press(actions.next_sibling())
        wait_for_buffer(display, other)
        press(actions.children())
        press(actions.next_sibling())
        press(actions.select())

        assert.equals(other, vim.api.nvim_win_get_buf(source_win))
        assert.equals(3, vim.api.nvim_win_get_cursor(source_win)[1])
        local jumped_from_source = false
        for _, jump in ipairs(vim.fn.getjumplist(source_win)[1]) do
          jumped_from_source = jumped_from_source or jump.bufnr == source_buf
        end
        assert.is_true(jumped_from_source)
      end)

      it("splits to the new buffer and leaves the original window on the original", function()
        local display = open_focused()

        press(actions.next_sibling())
        wait_for_buffer(display, other)
        press(actions.children())
        press(actions.vsplit())

        assert.equals(source_buf, vim.api.nvim_win_get_buf(source_win))
        assert.equals(other, vim.api.nvim_get_current_buf())
        vim.cmd("only")
      end)

      it("shows the switched buffer's server name", function()
        local named = add_lsp_buffer("navbuddy_spec_named.lua", { "named_one" }, "other_lsp")
        local display = open_focused()

        vim.api.nvim_win_set_cursor(display.left.winid, { 3, 0 })
        press(actions.next_sibling())
        wait_for_buffer(display, named)

        assert.equals("other_lsp", display.lsp_name)
        assert.equals("[other_lsp]", display.right.border._.text.bottom:content())
      end)

      it("uses lsp.preference to choose the server", function()
        attach(other, "preferred_lsp")
        local display = open(root.children[1], { lsp = { preference = { "preferred_lsp" } } })
        display:redraw()
        press(actions.parent())

        press(actions.next_sibling())
        wait_for_buffer(display, other)

        assert.equals("preferred_lsp", display.lsp_name)
        assert.equals("[preferred_lsp]", display.right.border._.text.bottom:content())
      end)

      it("loads an unloaded buffer before looking for a server", function()
        local path = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "local x" }, path)
        local unloaded = vim.fn.bufadd(path)
        vim.bo[unloaded].buflisted = true
        local display = open(root.children[1])
        assert.is_false(vim.api.nvim_buf_is_loaded(unloaded))
        vim.api.nvim_win_set_cursor(display.left.winid, { 3, 0 })
        display:redraw()
        press(actions.parent())

        vim.api.nvim_win_set_cursor(display.left.winid, { 3, 0 })
        press(actions.next_sibling())

        assert.is_true(vim.api.nvim_buf_is_loaded(unloaded))
        assert.equals(source_buf, display.for_buf)
        vim.fn.delete(path)
      end)
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

    it("does not preview a leaf by default", function()
      local display = open(root.children[2])

      assert.equals(display.right.bufnr, vim.api.nvim_win_get_buf(display.right.winid))
      assert.equals("", panel_text(display.right))
    end)

    it("previews a leaf with sections.right.preview = leaf", function()
      local display = open(root.children[2], { window = { sections = { right = { preview = "leaf" } } } })

      assert.equals(source_buf, vim.api.nvim_win_get_buf(display.right.winid))
    end)

    it("still enters preview focus with sections.right.preview = never", function()
      local display = open(root.children[2], { window = { sections = { right = { preview = "never" } } } })

      press(actions.children())

      assert.equals(source_buf, vim.api.nvim_win_get_buf(display.right.winid))
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

    it("removes its VimResized autocmd", function()
      local function resize_autocmds()
        return #vim.api.nvim_get_autocmds({ group = "Navbuddy", event = "VimResized" })
      end
      local before = resize_autocmds()

      for _ = 1, 3 do
        local display = open(root.children[2])
        assert.equals(before + 1, resize_autocmds())
        display:close()
      end

      assert.equals(before, resize_autocmds())
    end)

    it("removes its VimResized autocmd when resized", function()
      local before = #vim.api.nvim_get_autocmds({ group = "Navbuddy", event = "VimResized" })
      open(root.children[2])

      vim.api.nvim_exec_autocmds("VimResized", {})

      assert.equals(before, #vim.api.nvim_get_autocmds({ group = "Navbuddy", event = "VimResized" }))
    end)

    it("closes on VimResized", function()
      local display = open(root.children[2])

      vim.api.nvim_exec_autocmds("VimResized", {})

      assert.is_true(display.state.closed)
    end)
  end)
end)
