# nvim-navbuddy Development Notes

## Project Overview

This is a fork of nvim-navbuddy with custom refactored architecture and merged features from hasansujon786's fork.

**Repository Structure:**
- Original: `https://github.com/smiteshp/nvim-navbuddy`
- Intermediate fork: `https://github.com/hasansujon786/nvim-navbuddy`
- This fork: Custom refactored version

## Recent Changes (2025-10-23)

### Commit History (Latest First)

#### f3bb132 - Keep Navbuddy open when switching buffers
- Modified buffer selection to reload LSP data instead of closing
- Added `reload_buffer()` method to fetch symbols for selected buffer
- Updates source window and display state asynchronously
- Allows rapid browsing through multiple buffers

#### 7167d1a - Add buffer selection in left panel at root level
- Made buffer list selectable when at root level
- Added state tracking: `in_buffer_list`, `buffer_list`
- Enhanced j/k/h keys to navigate and select buffers
- New methods: `select_buffer()`, `navigate_buffer_list()`

#### 1be4d72 - Integrate custom refactored display architecture
- Converted display.lua to dispatcher pattern (470→26 lines)
- Kept modular structure: display/, buffer/ subdirectories
- Integrated custom features with fork's functionality

#### e972df6 - Merge hasansujon786/nvim-navbuddy fork
- Merged 7 features from hasansujon786's fork
- Added snacks.nvim integration, root command, type annotations
- Resolved conflicts in display.lua, init.lua, actions.lua

## Architecture

### Modular File Structure

```
lua/nvim-navbuddy/
├── Core
│   ├── init.lua          - Main entry, uses config module
│   ├── actions.lua       - Navigation actions (with buffer selection)
│   ├── config.lua        - Centralized configuration (205 lines)
│   └── types.lua         - Type annotations
│
├── Display (Refactored)
│   ├── display.lua       - Dispatcher (26 lines) → display/menu.lua
│   ├── display/menu.lua  - Main navigation interface (459 lines)
│   └── display/title.lua - Independent title bar (138 lines)
│
├── Buffer System (Custom)
│   ├── buffer/init.lua   - Module exports
│   ├── buffer/lsp.lua    - LSP symbol rendering
│   ├── buffer/file.lua   - File list rendering
│   ├── buffer/title.lua  - Smart title with truncation (107 lines)
│   └── buffer/utils.lua  - Utilities (get_current_buffers)
│
├── UI Customization
│   ├── border.lua        - Custom border generation per section
│   └── highlights.lua    - Color manipulation (354 lines)
│
└── Integrations
    ├── picker/telescope.lua
    └── picker/snacks.lua
```

### Key Design Patterns

#### 1. Display Dispatcher Pattern
`display.lua` acts as a compatibility layer:
```lua
function display.new(opts)
  return menu:new(opts)
end
```

#### 2. Buffer Selection State Machine
```lua
state.in_buffer_list  -- Boolean: showing buffers at root
state.buffer_list     -- Array: buffer data from get_current_buffers()
```

#### 3. Async LSP Data Loading
```lua
navic.request_symbol(bufnr, callback, client)
-- Callback updates focus_node and redraws
```

## Current Features

### Buffer Selection at Root Level
**How it works:**
1. Navigate to root with `0` key
2. Left panel shows buffer list
3. Use `j`/`k` to navigate buffers
4. Press `h` to select buffer
5. Navbuddy reloads with new buffer's LSP data
6. Stay in Navbuddy, continue browsing

**Key Files:**
- `display/menu.lua`: `select_buffer()`, `reload_buffer()`, `navigate_buffer_list()`
- `actions.lua`: Enhanced `next_sibling()`, `previous_sibling()`, `parent()`
- `buffer/utils.lua`: `get_current_buffers()`

### Custom Features Active

1. **Independent Title Bar** (`display/title.lua`)
   - Floating at bottom, configurable via `config.window.sections.title`

2. **Smart Title Truncation** (`buffer/title.lua`)
   - Builds full node chain, truncates with `…` based on window width

3. **Custom Borders** (`border.lua`)
   - Different styles per section: left, mid, right, title

4. **Modular Buffers** (`buffer/`)
   - Separate LSP, file, title rendering

5. **Enhanced Highlights** (`highlights.lua`)
   - Color darkening, custom highlight groups

### Fork Features Integrated

- ✅ Snacks.nvim fuzzy finding
- ✅ Telescope integration
- ✅ Root node command (`:Navbuddy root`)
- ✅ `win_options` & `buf_options` per section
- ✅ Number lines support
- ✅ Preview modes: leaf/always/never
- ✅ Type annotations
- ✅ Bug fixes from upstream

## Configuration

Configuration is in `lua/nvim-navbuddy/config.lua`.

**Key config sections:**
```lua
config = {
  window = {
    border = "single",
    sections = {
      title = {},  -- Custom title bar config
      left = { size = "20%", win_options = nil },
      mid = { size = "40%", win_options = {} },
      right = { preview = "leaf", win_options = nil }
    }
  },
  integrations = {
    telescope = nil,  -- auto-detect or set true/false
    snacks = nil
  }
}
```

## Testing

### Basic Load Test
```bash
nvim --headless -c "lua require('nvim-navbuddy')" -c "qa"
```

### Manual Testing Workflow
1. Open file with LSP: `nvim file.lua`
2. Attach LSP if needed
3. Open Navbuddy: `:Navbuddy`
4. Test navigation: `jklh0`
5. Test buffer selection:
   - Press `0` (go to root)
   - Press `jjj` (navigate buffers)
   - Press `h` (select buffer, should reload LSP)
6. Verify title bar updates
7. Verify LSP hierarchy loads

## Known Issues / TODO

- [ ] Test with multiple LSP servers on same buffer
- [ ] Add error handling for buffers without LSP
- [ ] Consider adding visual indicator when in buffer selection mode
- [ ] Document buffer selection in help docs
- [ ] Test with very long buffer lists

## Development Tips

### Adding New Actions

1. Add function to `actions.lua`:
```lua
function actions.my_action()
  local callback = function(display)
    -- Check if at root with buffers
    if display.focus_node.parent.is_root and display.state.in_buffer_list then
      -- Buffer mode behavior
    else
      -- Normal LSP navigation behavior
    end
  end
  return { callback = callback, description = "..." }
end
```

2. Add to default mappings in `config.lua`

### Modifying Display Behavior

Main display logic is in `display/menu.lua`:
- `new()` - Initialization
- `redraw()` - Update all panels
- `focus_range()` - Highlight in source buffer
- `show_preview()` / `hide_preview()` - Right panel preview

### Buffer Operations

Buffer utilities in `buffer/utils.lua`:
- `get_current_buffers(active_bufnr)` - Returns filtered buffer list
- `clear_buffer(buf)` - Clears buffer content

Buffer rendering:
- `buffer/lsp.lua` - Renders LSP symbols
- `buffer/file.lua` - Renders buffer list with icons
- `buffer/title.lua` - Renders breadcrumb path

## Git Workflow

Current branch: `master`
Remote: `origin` (your fork)
Upstream: `upstream` (SmiteshP/nvim-navbuddy)

### Commit Message Format
```
feat/fix/chore: Short description

Longer explanation of changes.
- Bullet points for details
- Technical implementation notes

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## References

### External Dependencies
- `nvim-navic` - LSP symbol provider
- `nui.nvim` - UI framework
- `nvim-web-devicons` - File icons
- `telescope.nvim` (optional) - Fuzzy finding
- `snacks.nvim` (optional) - Alternative fuzzy finding

### Key nvim-navic Functions Used
```lua
navic.request_symbol(bufnr, callback, client)  -- Request LSP symbols
navic.update_data(bufnr, symbols)              -- Update symbol cache
navic.update_context(bufnr)                    -- Update context
navic.get_context_data(bufnr)                  -- Get symbol hierarchy
navic.adapt_lsp_num_to_str(kind)              -- Convert symbol kind
```

## Next Steps / Ideas

1. **Buffer Preview in Right Panel**
   - Show buffer content preview when hovering over buffer in list
   - Similar to LSP symbol preview

2. **Buffer Filtering**
   - Add ability to filter buffer list (e.g., only modified buffers)
   - Use `/` key to search buffer names

3. **Recent Buffers First**
   - Option to sort by most recently used
   - Config: `buffers.sorting = "recent" | "name" | "id"`

4. **Buffer Actions**
   - Delete buffer from list
   - Save buffer
   - Close buffer

5. **Multi-Buffer Operations**
   - Visual selection of multiple buffers
   - Batch operations

6. **Session Integration**
   - Save/restore navbuddy state per session
   - Remember last position per buffer

---

**Last Updated:** 2025-10-23
**Version:** Custom fork with buffer selection
**Status:** Stable, feature complete
