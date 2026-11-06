local M = {}

function M.make_node(opts)
  return {
    is_root = opts.is_root or false,
    index = opts.index or 1,
    memory = opts.memory,
    kind = opts.kind or 12, -- Function
    name = opts.name or "node",
    name_range = opts.name_range or { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 4 } },
    scope = opts.scope or { start = { line = 0, character = 0 }, ["end"] = { line = 5, character = 0 } },
    prev = opts.prev or nil,
    next = opts.next or nil,
    children = opts.children or nil,
    parent = opts.parent or nil,
  }
end

--- Matches the root built by navic's lib.parse: no name, kind or name_range.
function M.make_root()
  return {
    is_root = true,
    index = 1,
    scope = {
      start = { line = -10, character = 0 },
      ["end"] = { line = 2147483640, character = 0 },
    },
  }
end

--- Build a linked sibling list under a root node.
--- specs: list of {name=string, kind=number, children={...}}
--- Lines are 1-based like navic's. Each node covers "<name> {" through "}", with
--- its children in between; M.source_lines returns the matching buffer text.
function M.make_tree(specs)
  local root = M.make_root()
  root.children = {}
  local next_line = 1

  local function build_children(parent, child_specs)
    parent.children = {}
    for i, spec in ipairs(child_specs) do
      local name = spec.name or ("node_" .. i)
      local first_line = next_line
      next_line = next_line + 1

      local node = M.make_node({
        name = name,
        kind = spec.kind or 12,
        index = i,
        parent = parent,
        name_range = {
          start = { line = first_line, character = 0 },
          ["end"] = { line = first_line, character = #name },
        },
      })
      if i > 1 then
        node.prev = parent.children[i - 1]
        parent.children[i - 1].next = node
      end
      if spec.children then
        build_children(node, spec.children)
      end

      node.scope = {
        start = { line = first_line, character = 0 },
        ["end"] = { line = next_line, character = 1 },
      }
      next_line = next_line + 1
      parent.children[i] = node
    end
  end

  build_children(root, specs)
  return root
end

--- Buffer text whose line numbers match the ranges assigned by M.make_tree.
function M.source_lines(root)
  local lines = {}

  local function add(node)
    table.insert(lines, node.name .. " {")
    for _, child in ipairs(node.children or {}) do
      add(child)
    end
    table.insert(lines, "}")
  end

  for _, node in ipairs(root.children) do
    add(node)
  end
  return lines
end

return M
