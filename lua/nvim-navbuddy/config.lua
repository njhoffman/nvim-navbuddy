local actions = require("nvim-navbuddy.actions")

-- local new_config = {
--   mappings = {},
--   icons = {},
--   window = { border = '', size = '', position = '', y_offset = 0 },
--   backends = { lsp = {}, ts_nodes = {}, ts_syntax = {}, regex = {}, extmarks = {} },
--   menu_mode = {
--     theme = 'hl-line',
--     padding = { icon_left = 1, icon_right = 1, node_marker = 0, scrollbar = 1 },
--     sections = { left = { size = '', border = nil, padding = {}, show_files = true } },
--     scrolloff = nil,
--     y_offset = 1,
--     node_markers = {},
--   },
--   title_mode = {
--     theme = 'hl-icons2',
--     icons = {},
--     mappings = {},
--   },
-- }

local config = {
  theme = "hl-line", -- hl-line, hl-icon, hl-icon-alt
  node_markers = {
    enabled = true,
    icons = {
      leaf = " ",
      leaf_selected = "→",
      branch = "",
    },
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
      },
      mid = {
        size = "40%",
        border = nil,
      },
      right = {
        -- preview = 'leaf',
        border = nil,
      },
    },
  },
  icons = {
    [1] = " ", -- File
    [2] = " ", -- Module
    [3] = " ", -- Namespace
    [4] = " ", -- Package
    [5] = " ", -- Class
    [6] = " ", -- Method
    [7] = " ", -- Property
    [8] = " ", -- Field
    [9] = " ", -- Constructor
    [10] = "練", -- Enum
    [11] = "練", -- Interface
    [12] = " ", -- Function
    [13] = " ", -- Variable
    [14] = " ", -- Constant
    [15] = " ", -- String
    [16] = " ", -- Number
    [17] = "◩ ", -- Boolean
    [18] = " ", -- Array
    [19] = " ", -- Object
    [20] = " ", -- Key
    [21] = "ﳠ ", -- Null
    [22] = " ", -- EnumMember
    [23] = " ", -- Struct
    [24] = " ", -- Event
    [25] = " ", -- Operator
    [26] = " ", -- TypeParameter
    [255] = " ", -- Macro
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

    ["t"] = actions.telescope({
      layout_strategy = "horizontal",
      layout_config = {
        height = 0.60,
        width = 0.60,
        prompt_position = "top",
        preview_width = 0.50,
      },
    }),

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

return config
