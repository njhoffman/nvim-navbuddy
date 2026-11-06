# Changelog

All notable changes to this fork are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.3] - 2026-11-05

### Changed

- `open(bufnr)` for a buffer that isn't current uses a window already showing it, or shows it in the current window. Closing with `q` or `<esc>` then returns to the previous buffer.

### Fixed

- `open(bufnr)` requests symbols for that buffer rather than the current one.
- Live buffer switching retries while the server reports errors, as opening does.
- Each open no longer leaves a `VimResized` autocmd behind.
- Names with multibyte characters are padded and shortened by display width and are never cut mid-character, and node markers stay inside the window.
- The title is centered correctly, its icons are highlighted, and long paths shorten by display width.
- The `hl-icon` theme highlights the whole icon.

## [0.2.2] - 2026-11-05

### Fixed

- `:Navbuddy` is available without calling `setup()`, so setups that only call `attach` work. The plugin itself still loads on first use.
- `lsp.auto_attach` no longer errors on `LspAttach` events without client data, and calling `setup()` repeatedly no longer adds autocmds or removes the handling for detached servers and deleted buffers.
- Setting `lsp.auto_attach = false` in a later `setup()` call now turns it off.
- Dimmed colors in the buffer list are correct for channels below `0x10`, and an icon highlight with no foreground no longer causes an error.

## [0.2.1] - 2026-11-05

### Fixed

- `window.size`, `window.position` and each section's `size`, `win_options` and `buf_options` now take effect. The defaults are the layout Navbuddy already used: 80x15 at `98%`, with a 30% left section. If your setup sets these options, expect the window to change.
- `setup()` now applies `theme` and `integrations`.
- Leaving buffer or preview focus mode restores a section's own `winhighlight`.
- The help window is centered and tall enough for every mapping, and opens with a list of border characters.

## [0.2.0] - 2026-11-05

### Changed

- Closing with `q` or `<esc>` after live-switching returns to the original buffer and cursor. Press `h` in buffer focus mode to keep the new buffer.
- With several LSP servers attached and no matching `lsp.preference`, `:Navbuddy` now shows the server chooser, as documented. Before, it used whichever server attached last.

### Fixed

- A second LSP server no longer replaces the first in Navbuddy's list, so `lsp.preference` and the chooser see every attached server.
- When a server detaches, Navbuddy removes that server rather than the one attached most recently.
- Live buffer switching now requests symbols for the selected buffer rather than the Navbuddy window, so it works with real LSP servers.
- A switch only happens once the selected buffer's symbols arrive. Buffers with no LSP server or no symbols are left in the list without being switched to, and late responses are ignored.
- After a switch, the LSP name and source highlights follow the new buffer, and `lsp.preference` chooses the server.
- `<enter>` and the split actions no longer fail or use the wrong cursor position after a switch.

## [0.1.1] - 2026-11-05

### Added

- `TODO.md` listing known issues and suggestions, and this changelog.
- Specs that run against the real display, with pending specs recording known bugs.

### Changed

- Replaced deprecated Neovim APIs, including `nvim_buf_add_highlight`, which is now handled by an extmark-based helper.

### Fixed

- Preview no longer crashes, so `l` on a leaf node, `s` and `window.sections.right.preview` work.
- `j`/`k` move between top-level symbols again. They only move through the buffer list in buffer focus mode.
- `J`/`K` keep the tree correct after a move, so sibling navigation follows the new order and later actions on a moved node's children hit the right lines. This also fixes moved nodes landing on the wrong lines with servers that return `SymbolInformation`.
- `nvim-web-devicons` is now optional as documented; without it the buffer list shows file names only.
- Opening no longer crashes with `window.border` set to `"none"`, `"shadow"` or a list of border characters, or with a border set on individual sections.

## [0.1.0] - 2026-10-19

First tagged version of this fork. It includes the upstream nvim-navbuddy history and the changes merged from
hasansujon786's fork.

### Added

- Buffer list in the left panel at the top level, with buffer switching that keeps Navbuddy open.
- Buffer focus mode: `h` at the top level focuses the buffer list, `j`/`k` live-switch the active buffer, and `l` returns to navigation.
- Preview focus mode: `l` on a leaf node shows its source in the right panel and dims the other panels.
- Breadcrumb title bar with truncation based on window width.
- `:Navbuddy root` and `open({ root = true })` to open at the top-level node.
- Fuzzy finding through snacks.nvim, alongside telescope.nvim.
- Type annotations, help docs generated from source, and a plenary test suite run with `make test`.

### Changed

- Split the display into separate display and buffer rendering modules.
- Modernized Neovim API usage.
