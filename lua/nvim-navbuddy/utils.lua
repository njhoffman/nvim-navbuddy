local M = {}

---@param name string
---@param config Navbuddy.config
---@return boolean
function M.check_integration(name, config)
  local enabled = config.integrations[name]

  if enabled == nil or enabled == "auto" then
    local success, _ = pcall(require, name:gsub("_", "-"))
    return success
  end

  return enabled
end

return M
