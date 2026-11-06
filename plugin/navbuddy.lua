if vim.g.loaded_navbuddy then
  return
end
vim.g.loaded_navbuddy = true

vim.api.nvim_create_user_command("Navbuddy", function(cmd)
  require("nvim-navbuddy").open({ root = cmd.fargs[1] == "root" })
end, {
  nargs = "?",
  complete = function()
    return { "root" }
  end,
  desc = "Navbuddy",
})
