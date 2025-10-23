-- Display module - delegates to display/menu.lua for the main navigation interface
-- This maintains compatibility with the fork's init.lua while using the refactored architecture

local menu = require("nvim-navbuddy.display.menu")

local display = {}
display.__index = display

---Create a new display instance
---@param opts Navbuddy.display.opts
---@return Navbuddy.display
function display.new(opts)
  return menu:new(opts)
end

-- Re-export the menu display class as the display module
-- This allows both `require("nvim-navbuddy.display").new(opts)`
-- and direct usage of the menu module
setmetatable(display, {
  __index = menu,
  __call = function(_, opts)
    return menu:new(opts)
  end
})

return display
