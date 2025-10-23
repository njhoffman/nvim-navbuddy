local actions = require("nvim-navbuddy.actions")

-- stylua: ignore start
---@text DEFAULT CONFIG
---
--- Use |navbuddy.setup| to override any of the default options
---
--- window: table
---   Set options related to window's "border", "size", "position".
---
--- icons: table
---   Icons to show for captured symbols. Default icons assume that you
---   have nerd-fonts.
---
--- use_default_mappings: boolean
---   If set to false, only mappings set by user are set. Else default mappings
---   are used for keys that are not set by user.
---
--- mappings: table
---   Actions to be triggered for specified keybindings. For each keybinding
---   it takes a table of format
---   { callback = <function_to_be_called>, description = "string"}.
---   The callback function takes the "display" object as an argument.
---
--- lsp: table
---   auto_attach: boolean
---     Enable to have Navbuddy automatically attach to every LSP for
---     current buffer. Its disabled by default.
---   preference: table
---     Table ranking lsp_servers. Lower the index, higher the priority of
---     the server. If there are more than one server attached to a
---     buffer, navbuddy will refer to this list to make a decision on
---     which one to use.
---     example: Incase a buffer is attached to clangd and ccls both and
---     the preference list is { "clangd", "pyright" }. Then clangd will
---     be prefered.
---
--- source_buffer:
---   follow_node: boolean
---     Move the source buffer such that focused node is visible.
---   highlight: boolean
---     Highlight focused node on source buffer
---   reorient: string
---     Reorient buffer after changing nodes. options are "smart", "top",
---     "mid" or "none"
---
--- node_markers: table
---   Indicate whether a node is a leaf or branch node. Default icons assume
---   you have nerd-fonts.
---
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@tag navbuddy-config
---@toc_entry Config
---@type Navbuddy.config

--minidoc_replace_start ---@class Navbuddy.config
--minidoc_replace_end
--minidoc_replace_start {
local config = {
  theme = "hl-line", -- hl-line, hl-icon, hl-icon-alt
  custom_hl_group = nil,   -- "Visual" or any other hl group to use instead of inverted colors
  use_default_mappings = true,
  node_markers = {
    enabled = true,
    icons = {
      leaf = " ",
      leaf_selected = "→",
      branch = "",
    },
  },
  integrations = {
    -- Requires you to have `nvim-telescope/telescope.nvim` installed.
    telescope = nil,
    -- Requires you to have `folke/snacks.nvim` installed.
    snacks = nil,
  },
  -- padding = { icon_left = 1, icon_right = 1, node_marker = 0, scroll_bar = 1 },
  window = {
    border = "single",
    size = "60%",
    position = "50%",
    scrolloff = nil,
    winblend = nil, -- winblend value [0-100 or nil] (transparency)
    sections = {
      title = {},
      left = {
        size = "20%",
        border = nil,
        win_options = nil
      },
      mid = {
        size = "40%",
        border = nil,
        win_options = {
          -- number = true,-- Uncomment this line if you want see the number
          -- relativenumber = true,
        },
      },
      right = {
        -- preview = 'leaf',
        border = nil,
        win_options = nil
      },
    },
  },
  icons = {
    [1] = "󰈙 ",  -- File
    [2] = " ",  -- Module
    [3] = "󰌗 ",  -- Namespace
    [4] = " ",  -- Package
    [5] = "󰌗 ",  -- Class
    [6] = "󰆧 ",  -- Method
    [7] = " ",  -- Property
    [8] = " ",  -- Field
    [9] = " ",  -- Constructor
    [10] = "󰕘",  -- Enum
    [11] = "󰕘",  -- Interface
    [12] = "󰊕 ", -- Function
    [13] = "󰆧 ", -- Variable
    [14] = "󰏿 ", -- Constant
    [15] = " ", -- String
    [16] = "󰎠 ", -- Number
    [17] = "◩ ", -- Boolean
    [18] = "󰅪 ", -- Array
    [19] = "󰅩 ", -- Object
    [20] = "󰌋 ", -- Key
    [21] = "󰟢 ", -- Null
    [22] = " ", -- EnumMember
    [23] = "󰌗 ", -- Struct
    [24] = " ", -- Event
    [25] = "󰆕 ", -- Operator
    [26] = "󰊄 ", -- TypeParameter
    [255] = "󰉨 ",-- Macro
  },
  mappings = {
    ["<esc>"] = actions.close(),
    ["q"] = actions.close(),

    ["j"] = actions.next_sibling(),
    ["k"] = actions.previous_sibling(),

    ["h"] = actions.parent(),
    ["l"] = actions.children(),
    ["0"] = actions.root(),

    ["v"] = actions.visual_name(),
    ["V"] = actions.visual_scope(),

    ["y"] = actions.yank_name(),
    ["Y"] = actions.yank_scope(),

    ["i"] = actions.insert_name(),
    ["I"] = actions.insert_scope(),

    ["a"] = actions.append_name(),
    ["A"] = actions.append_scope(),

    ["r"] = actions.rename(),

    ["d"] = actions.delete(),

    ["f"] = actions.fold_create(),
    ["F"] = actions.fold_delete(),

    ["c"] = actions.comment(),

    ["<enter>"] = actions.select(),
    ["o"] = actions.select(),

    ["J"] = actions.move_down(),
    ["K"] = actions.move_up(),

    ["s"] = actions.toggle_preview(),

    ["<C-v>"] = actions.vsplit(),
    ["<C-s>"] = actions.hsplit(),

    ["t"] = actions.fuzzy_find(),       -- Fuzzy finder at current level.
    -- ["t"] = actions.telescope({
    --   layout_strategy = "horizontal",
    --   layout_config = {
    --     height = 0.60,
    --     width = 0.60,
    --     prompt_position = "top",
    --     preview_width = 0.50,
    --   },
    -- }),

    ["g?"] = actions.help(),
  },
  lsp = {
    auto_attach = false,
    preference = nil,
  },
  source_buffer = {
    follow_node = true,
    scrolloff = nil,
    highlight = true,
    reorient = "smart",
  },
}
--minidoc_afterlines_end
-- stylua: ignore end

return config
