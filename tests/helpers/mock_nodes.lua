local M = {}

function M.make_node(opts)
  return {
    is_root = opts.is_root or false,
    index = opts.index or 1,
    memory = opts.memory or 1,
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

function M.make_root()
  return M.make_node({ is_root = true, name = "root", kind = 1 })
end

--- Build a linked sibling list under a root node.
--- specs: list of {name=string, kind=number, children={...}}
function M.make_tree(specs)
  local root = M.make_root()
  root.children = {}

  local function build_children(parent, child_specs)
    parent.children = {}
    for i, spec in ipairs(child_specs) do
      local node = M.make_node({
        name = spec.name or ("node_" .. i),
        kind = spec.kind or 12,
        index = i,
        parent = parent,
      })
      if i > 1 then
        node.prev = parent.children[i - 1]
        parent.children[i - 1].next = node
      end
      if spec.children then
        build_children(node, spec.children)
      end
      parent.children[i] = node
    end
  end

  build_children(root, specs)
  return root
end

return M
