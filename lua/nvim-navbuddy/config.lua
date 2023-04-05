local actions = require("nvim-navbuddy.actions")

local config = {
  theme = "default", -- default, hl-line1, hl-icon1, hl-icon2
  window = {
    border = "single",
    size = "60%",
    position = "50%",
    scrolloff = nil,
    sections = {
      title = {},
      left = {
        size = "20%",
      },
      mid = {
        size = "40%",
      },
      right = {},
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
    ["<esc>"] = actions.close,
    ["q"] = actions.close,

    ["j"] = actions.next_sibling,
    ["k"] = actions.previous_sibling,

    ["h"] = actions.parent,
    ["l"] = actions.children,

    ["v"] = actions.visual_name,
    ["V"] = actions.visual_scope,

    ["y"] = actions.yank_name,
    ["Y"] = actions.yank_scope,

    ["i"] = actions.insert_name,
    ["I"] = actions.insert_scope,

    ["a"] = actions.append_name,
    ["A"] = actions.append_scope,

    ["r"] = actions.rename,

    ["d"] = actions.delete,

    ["f"] = actions.fold_create,
    ["F"] = actions.fold_delete,

    ["c"] = actions.comment,

    ["<enter>"] = actions.select,
    ["o"] = actions.select,

    ["J"] = actions.move_down,
    ["K"] = actions.move_up,
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
