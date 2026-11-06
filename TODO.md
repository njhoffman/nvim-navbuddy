# TODO

Open issues and suggestions for this nvim-navbuddy fork, from a full read of `lua/`, the tests and the docs.
Items marked "Reproduced" failed in a headless run against the real display (Neovim 0.13-dev); the others come from reading the code.

Reviewed: 2026-11-05

## 1. Crashes and broken navigation

- [x] **Preview crashes on a call to a nonexistent API.** (p1) [bug] `show_preview()` calls `vim.api.nvim_win_set_option_value`, which does not exist.
  Reproduced: `attempt to call field 'nvim_win_set_option_value' (a nil value)` at `display/menu.lua:374`.
  Breaks `l` on a leaf (preview focus mode), `s` (`toggle_preview`), and `preview = "leaf"/"always"`.
  Fix: use `nvim_set_option_value("winhighlight", ..., { win = ... })`.
- [x] **j/k cannot move between top-level symbols.** (p1) [bug] At top level they move the buffer list cursor instead of the focused node.
  Reproduced: `next_sibling` on `first` leaves `focus_node` on `first`.
  `actions.lua:44` and `:86` test `in_buffer_list`, which is true at every top-level node, but the docs limit this behavior to buffer focus mode.
  Fix: test `state.buffer_focused`, and update the actions_spec case that expects the current branch.
- [x] **Most border settings crash on open.** (p1) [bug] `right_border.text = lsp_name` assumes a table, but the border can be a string.
  Reproduced at `display/menu.lua:81` with `window.border = "none"` or `"shadow"`, and with any string in `sections.right.border`.
  `setup()` also fills unset section borders with `"none"`, so setting a border on any one section crashes too (`init.lua:271-279`).
  The README's eight-character array also fails, with `text not supported for style:none`, because `border.get_border` returns it without wrapping it in `{ style = ... }`.
  Fix: normalize every border to a table before attaching text. This probably also answers the TODO comment at `buffer/lsp.lua:5`, which should go with this fix.
- [x] **Moving a node leaves stale tree data, so later edits can hit the wrong lines.** (p1) [bug] `swap_nodes` does not update the neighbors' links or the descendants' ranges.
  Reproduced: after `J` on `second`, `first.next` is still `second` and `fourth.prev` is still `third` (`actions.lua:584-588`).
  Reproduced by a pending spec: only the two swapped nodes get new line numbers (`:601-609`), so `d`, `V` or `J` on a child of a moved node acts on its old lines.
  Fix: repair `prev.next` and `next.prev`, and shift line numbers recursively, or re-request symbols after each move.
- [x] **Live buffer switching leaves inconsistent state.** (p1) [bug] `select_buffer` changes the window's buffer before it knows the new buffer can be loaded (`display/menu.lua:471-474`).
  Reproduced by a pending spec: with no LSP on the target, `for_buf` and the node tree still describe the old buffer, so actions apply its ranges to the buffer now showing.
  `q` restores `start_cursor` in whichever buffer is showing, which can be out of range, and never restores the original buffer (`actions.lua:27`).
  The async callback in `reload_buffer` has no closed-display check or stale-response guard, so it can redraw dead windows or apply responses out of order when `j`/`k` is held.
  It also ignores `lsp.preference` and the attached-client list (`:485`), leaves highlights on the old buffer, skips `focus_range()`, and leaves the old LSP name in the border.
  Fix: keep the original buffer and cursor, commit the switch only after symbols arrive, and drop stale or post-close responses.
- [x] **Optional nvim-web-devicons is a hard requirement.** (p1) [bug] `buffer/utils.lua:4` requires it unconditionally, and every top-level redraw reaches that line.
  Without it, the display errors as soon as a top-level node is shown, which is what `:Navbuddy root` always does.
  Reproduced by a pending spec that blocks the module. It went unnoticed because the module resolves from `~/.config/nvim` here, which is the isolation gap listed in project 4.
  Fix: `pcall(require, ...)` and render without icons.
- [x] **A second LSP client evicts the first.** (p1) [bug] `if c.is_stopped then` tests a method, which is always truthy, so it should be `c:is_stopped()` (`init.lua:397`).
  `Client.is_stopped` is confirmed to be a function; the two-client flow itself was not run.
  Each new client removes earlier ones, so the chooser menu and `lsp.preference` rarely get more than one client to work with. `table.remove` inside `ipairs` also skips entries.
  Fix: call the method and iterate backward. Also covers the "test with multiple LSP servers" note in `DEVELOPMENT_NOTES.md`.
- [ ] **`open(bufnr)` mishandles a buffer that isn't current.** (p2) [bug] `init.lua:154` calls `navic.request_symbol`, which asks about the current buffer instead of `bufnr`. Its `file_uri` argument doesn't help, because navic nests it as `textDocument.textDocument`.
  The handler also takes its window and cursor from the current window (`init.lua:203`, `:230-231`), so the display would pair them with the wrong buffer.
  Fix: send the request directly, as `display:reload_buffer` does, and use a window showing `bufnr` or open it in the current one.
- [x] **`setup()` drops `theme` and `integrations`.** (p2) [bug] Neither key is merged into the config (`init.lua:264-316`).
  Reproduced: `setup({ theme = "hl-icon", integrations = { telescope = false } })` leaves `hl-line` and `nil`.
  Fix: merge them, ideally replacing the per-key merging with one `tbl_deep_extend` plus the mapping special case.
- [x] **`window.size`, `position` and section options have no effect.** (p2) [bug] The layout is hardcoded to 80x15 at `"98%"` (`display/menu.lua:93-113`).
  Reproduced: the mid pane is 32 columns wide on a 200-column screen with the default `size = "60%"`.
  `sections.*.size`, `sections.*.win_options` and `sections.*.buf_options` are also never read, though the README or types document them, and the config spec only asserts the table contents.
  Fix: build the layout from config, and decide whether the commented-out `utils.get_layout_opts` sizing is still wanted.
- [x] **Help window is smaller with the new default size.** (p2) [bug] `actions.help` uses `window.size` and `window.position`, which now default to 80x15 at `98%`, so the mappings list needs scrolling.
  Fix: give help its own size, large enough for the mapping count and centered.
- [ ] **`wrap` in a section's `win_options` is overwritten.** (p3) [bug] `clear_buffer` sets `wrap = true` on each redraw (`buffer/utils.lua:81`), and also `signcolumn` and `foldlevel`.
  Fix: stop setting these on every fill, and restore them only after a preview.
- [x] **`:Navbuddy` does not exist until `setup()` runs.** (p2) [bug] The README's `attach`-only flow ends in an unknown command.
  Reproduced: `exists(":Navbuddy")` is 0 after `require`, and the repo has no `plugin/` directory.
  Fix: define the command from `plugin/navbuddy.lua`, with lazy requires so startup stays cheap.
- [x] **The LspAttach guard and autocmd are wrong.** (p2) [bug] `args.data == nil and args.data.client_id == nil` errors on the case it means to catch, and should use `or` (`init.lua:324`).
  The autocmd at `:321` has no `group`, so `nvim_clear_autocmds` misses it and every `setup()` call adds another.
- [x] **LspDetach can remove the wrong client.** (p2) [bug] The callback closes over the most recently attached `client` and ignores `args.data.client_id` (`init.lua:417-433`).
  Each `attach` also clears the previous buffer autocmds. With two clients, detaching one removes the other from the list.
  Fix: read the client id from the event. Depends on the `is_stopped` fix to be observable.
- [x] **`darken()` produces wrong colors.** (p2) [bug] Channels are formatted with `%0x`, which does not pad.
  Reproduced: `darken("#100520", 0)` returns `#010520` and `darken("#0a0b0c", 0)` returns `#abc` (`highlights.lua:85-88`).
  `file.lua:30` also passes `file_hl.foreground` unchecked, and `darken(nil, 50)` errors when an icon highlight has no fg.
  Fix: `string.format("#%02x%02x%02x", r, g, b)` and a nil guard, with spec cases for both.
- [ ] **VimResized autocmds leak on every open.** (p2) [bug] `buffer = self.forbuf` is a misspelled field, so it is nil and the autocmd is global (`display/menu.lua:175-178`).
  Only buffer-local autocmds are cleared, so one more accumulates per open, and each keeps its display object alive.
  Fix: delete the autocmd in `close()`, or use a per-display augroup.
- [ ] **Remaining deprecated APIs.** (p2) [chore] `vim.lsp.get_buffers_by_client_id` (`init.lua:343`) is deprecated for removal in 0.13, and `nvim_buf_clear_highlight` remains at `display/menu.lua:410`.
  Fix: use `client.attached_buffers` and `nvim_buf_clear_namespace`.
- [ ] **Title and list widths use byte counts.** (p2) [bug] Multibyte names and icons get wrong padding, can be cut mid-character, and the title centers off target.
  `buffer/lsp.lua:15-19` and `buffer/title.lua:47-57` use `#` and `string.sub`.
  `string.rep("", indent, " ")` at `title.lua:92` returns one space fewer than `indent`, so the title highlights are off by one. Should be `string.rep(" ", indent)`.
  Fix: use `vim.fn.strdisplaywidth` and `vim.fn.strcharpart`.
- [ ] **`fill_title` default options crash.** (p3) [bug] The default `opts` has no `winsize`, so `opts.winsize.w` errors, and the fallback passes a popup where a window id is needed (`buffer/title.lua:25-29`).
  Only reachable by callers that omit `opts`.
- [ ] **`r` can rename the wrong symbol.** (p3) [bug] `actions.rename` relies on `follow_node` having moved the cursor (`actions.lua:432-436`).
  With `follow_node = false` the rename applies to the symbol at the original cursor.
  Fix: set the cursor to the focused node's name first.
- [ ] **Yank always targets the `+` register.** (p3) [feature] `yank_name` and `yank_scope` hardcode `"+y` (`actions.lua:267`, `:290`), which depends on a clipboard provider.
  Fix: accept a register option, defaulting to `v:register` or the current behavior.

## 2. Dead code and cleanup

- [ ] **Remove unused modules.** (p2) [refactor] Nothing requires `lsp.lua`, `ui.lua` or `display/title.lua`, and none of them would work if called.
  `lsp.lua` uses an undefined global `config`. `display/title.lua:123-124` compares the nil return of `fill_title`. `ui.lua` duplicates `highlights.lua`, though `scripts/minidoc.lua` still reads it, so switch that first.
  Also unused: `state.mode`, `state.attached_clients`, `highlights.get_border_chars`, `utils.get_layout_opts` and its helpers (which the specs still cover), and the commented-out `focus_range` at `display/menu.lua:287-336`.
  Decide first whether the title-bar mode is worth finishing. If so, keep `display/title.lua` and turn this into a feature.
- [ ] **Avoid repeated work on each redraw.** (p3) [perf] `get_current_buffers` runs twice per top-level redraw (`display/menu.lua:440`, `buffer/file.lua:9`), and `nvim_set_hl` runs per listed buffer (`file.lua:31`).
  Fix: pass the list through and define `*Dim` groups once.
- [ ] **Consolidate repeated action code.** (p3) [refactor] Cursor placement and visual selection repeat across about ten actions, and the reorient logic is duplicated between `actions.select` and `display:reorient`.
  Fix: extract helpers before adding more actions.
- [ ] **Stop tracking `.claude/settings.local.json`.** (p3) [chore] It is a machine-local permission file. Add it to `.gitignore` and untrack it.

## 3. Documentation

- [ ] **Minimum Neovim version is wrong.** (p2) [docs] README and `init.lua:17` say 0.8, but `vim.lsp.get_clients` needs 0.10.
  Fix: state the real minimum, and test it in CI.
- [ ] **Install snippets point to other repos.** (p2) [docs] README uses `SmiteshP/nvim-navbuddy` and `init.lua:35` uses `hasansujon786/nvim-navbuddy`, so following them installs a version without this fork's features.
  `.github/FUNDING.yml` also still names the upstream author, which may be intentional.
- [ ] **Remove placeholder text from the README requirements.** (p3) [docs] `README.md:14-21` has a stray `**test**` heading and a nested "item one" list, and the section doesn't list `nvim-web-devicons` as optional.
- [ ] **README config does not match the defaults.** (p2) [docs] It shows `preview = "leaf"`, but that line is commented out in `config.lua:100`, so preview is off by default. It also shows `t` as `actions.telescope` where the default is `fuzzy_find`.
  Decide which `preview` default is intended; it interacts with preview focus mode.
- [ ] **Help file omits fork features.** (p2) [docs] `doc/navbuddy.txt` has no mention of buffer focus mode, preview focus mode or the `*Dim` highlights, because it is generated from the stale `ui.lua`.
  Fix: point `scripts/minidoc.lua` at `highlights.lua`, document both modes, and regenerate.
- [ ] **CLAUDE.md describes modules that are not wired in.** (p3) [docs] It presents `display/title.lua` as the title bar and `state.lua` as live global state, but the title popup is built in `display/menu.lua` and clients live in `init.lua`.
- [ ] **Move the known-issues list out of `DEVELOPMENT_NOTES.md`.** (p3) [docs] Its "Known Issues / TODO" section duplicates this file. Replace it with a pointer here.

## 4. Tests and tooling

- [x] **Test the real display.** (p1) [test] `actions_spec` stubs every display method, so `display/menu.lua` has no coverage, and all 80 specs pass with the crashes above present.
  Added `tests/integration/display_spec.lua`, which mounts the real layout, and made `tests/helpers/mock_nodes.lua` match navic's nameless root and give nodes real line ranges.
  Remaining known bugs are `pending` specs. Each fix should change its spec to `it`.
- [ ] **Isolate the test runtime.** (p2) [test] `tests/minimal_init.lua` only prepends to `rtp`, so `~/.config/nvim` stays visible and supplies `nvim-web-devicons` to the specs.
  Fix: reset `rtp` to `$VIMRUNTIME` plus `deps/`, or run with temporary `XDG_*` directories.
- [ ] **Single-spec runs fail on module loading.** (p3) [test] `PlenaryBustedFile tests/unit/title_spec.lua` fails with `module 'nvim-navic.lib' not found`, although `require` works under the same `-u tests/minimal_init.lua`.
  `PlenaryBustedDirectory`, which the Makefile uses, is not affected. Cause not yet found.
  Fix: find the cause, then add a `make test-file FILE=...` target.
- [ ] **Add CI.** (p2) [chore] `.github/` only holds `FUNDING.yml`, so nothing runs tests or format checks on push.
  Fix: a GitHub Actions matrix covering the minimum supported Neovim, stable and nightly. Pin `deps/` to known commits, since `make deps` clones whatever is on the default branch.
- [ ] **Add format, lint and docs targets.** (p3) [chore] The Makefile only covers tests, `stylua --check lua/` reports 10 files, and luacheck reports 300 warnings with no `.luacheckrc`.
  `scripts/minidoc.lua` needs `mini.doc`, which `make deps` does not fetch.
  Fix: add `make fmt`, `make lint` and `make docs`, plus a luacheck config declaring `vim`.

## 5. Suggestions

- [ ] **Report why nothing opened.** (p2) [feature] `:Navbuddy` returns silently when a buffer has no symbols (`init.lua:215-217`).
  Fix: notify at INFO level. Also covers the "error handling" note in `DEVELOPMENT_NOTES.md`.
- [ ] **Switch to buffers whose LSP is still starting.** (p3) [feature] Selecting an unloaded buffer loads it, but its server usually hasn't attached yet, so the first press warns and only a later press switches.
  Fix: wait for `LspAttach` on that buffer for a short time before warning.
- [ ] **Show buffer focus mode more clearly.** (p3) [feature] Only the dimming signals the mode. `DEVELOPMENT_NOTES.md` suggests a visual indicator; a title or border label would do.
- [ ] **Improve the buffer list.** (p3) [feature] `buffer/utils.lua` computes `modified` and `order` and never uses them, so show a modified marker and offer sorting.
  Long lists are also listed as untested in `DEVELOPMENT_NOTES.md`.
- [ ] **Keep the window open on resize.** (p3) [feature] VimResized closes Navbuddy. Relayout instead, once the layout is config-driven.
