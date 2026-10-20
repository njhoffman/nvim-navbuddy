# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fork of nvim-navbuddy -- a keyboard-centric LSP symbol navigator for Neovim with a ranger-inspired three-panel popup UI. This fork adds a refactored display architecture, buffer selection at root level, and merged features from hasansujon786's fork (snacks.nvim, type annotations, root command, etc.).

**Dependencies:** nvim-navic (LSP symbols), nui.nvim (UI), nvim-lspconfig. Optional: nvim-web-devicons, telescope.nvim, snacks.nvim, Comment.nvim/mini.comment.

## Common Commands

```bash
# Basic load test
nvim --headless -c "lua require('nvim-navbuddy')" -c "qa"

# Format code
stylua lua/

# Generate help docs from source annotations
nvim --headless -c "luafile scripts/minidoc.lua" -c "qa"
```

```bash
# Run all tests (clones deps on first run)
make test

# Run unit or integration tests separately
make test-unit
make test-integration
```

Tests use plenary.nvim (busted-style). Test deps are cloned into `deps/` (gitignored). Manual testing: open a file with LSP active, run `:Navbuddy`, test navigation (`j`/`k`/`h`/`l`/`0`), buffer focus mode (press `h` at root to focus buffer list, `j`/`k` to live-switch, `l` to exit).

## Code Style

- StyLua: 120 columns, 2-space indent, Unix line endings, double quotes preferred (`.stylua.toml`)
- Lua LSP config disables `undefined-field` diagnostics (`.luarc.json`)
- Commit messages: `feat/fix/chore: Short description`

## Architecture

### Entry Point & Public API (`init.lua`)
- `navbuddy.setup(config)` -- merge user config with defaults
- `navbuddy.attach(client, bufnr)` -- attach to LSP client
- `navbuddy.open(opts?)` -- open the navigator; also exposed as `:Navbuddy` and `:Navbuddy root`
- LSP symbols come from `navic.request_symbol()`, which calls back with a node tree

### Display Dispatcher Pattern
`display.lua` is a thin dispatcher (26 lines) that delegates to `display/menu.lua`. This maintains backward compatibility while keeping the actual UI code modular.

### Three-Panel UI (`display/menu.lua`)
Built on nui.nvim layouts:
- **Left panel**: Parent nodes (ancestors) or buffer list when at root
- **Mid panel**: Current node's siblings (active navigation target)
- **Right panel**: Children / preview of selected node
- **Title bar** (`display/title.lua`): Independent floating window showing breadcrumb path

### Buffer Rendering (`buffer/`)
Separate modules for different content types:
- `buffer/lsp.lua` -- renders LSP symbol tree into a buffer
- `buffer/file.lua` -- renders buffer list with devicons
- `buffer/title.lua` -- builds breadcrumb string with smart truncation based on window width
- `buffer/utils.lua` -- `get_current_buffers()`, `clear_buffer()`

### Actions (`actions.lua`)
All navigation callbacks follow a pattern: return `{ callback = function(display) ... end, description = "..." }`. Actions check `display.focus_node.parent.is_root`, `display.state.in_buffer_list`, and `display.state.buffer_focused` to differentiate between LSP navigation, buffer list browsing, and buffer focus mode.

### Buffer Focus Mode (`display/menu.lua`)
When at root level with the buffer list visible, pressing `h` enters "buffer focus mode":
- `enter_buffer_focus()` dims mid/right panes via `NavbuddyNormalFloatDim` winhighlight, enables cursorline on left pane
- `j`/`k` navigates the buffer list AND live-switches the active buffer (calls `select_buffer()`)
- `l` calls `exit_buffer_focus()` to restore pane appearance and return to normal navigation
- State tracked via `display.state.buffer_focused` (boolean)

### Preview Focus Mode (`display/menu.lua`)
When pressing `l` on a leaf node (no children), the right pane shows source code preview and left/mid panes are dimmed:
- `enter_preview_focus()` calls `show_preview()` and dims left/mid panes
- `h` calls `exit_preview_focus()` to restore panes and redraw
- `j`/`k` also exits preview focus before navigating
- State tracked via `display.state.preview_focused` (boolean)

### State (`state.lua`)
Global state: `mode`, `attached_clients` (map of LSP client IDs), `ns` (vim namespace for extmarks).

### Configuration (`config.lua`)
Centralized defaults merged via `vim.tbl_deep_extend`. Key sections: `window.sections.{left,mid,right,title}`, `mappings`, `integrations.{telescope,snacks}`, `lsp.auto_attach`, `icons`.

### Adding New Actions
1. Add function to `actions.lua` returning `{ callback, description }`
2. Handle both buffer-list and LSP-navigation modes if applicable
3. Add default key mapping in `config.lua`
