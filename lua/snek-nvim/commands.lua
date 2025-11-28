local api = require("snek-nvim.api")
local log = require("snek-nvim.logger")

local M = {}

M.setup = function()
  vim.api.nvim_create_user_command("SnekStart", function()
    api.start()
  end, {})

  vim.api.nvim_create_user_command("SnekStop", function()
    api.stop()
  end, {})

  vim.api.nvim_create_user_command("SnekRestart", function()
    api.restart()
  end, {})

  vim.api.nvim_create_user_command("SnekToggle", function()
    api.toggle()
  end, {})

  vim.api.nvim_create_user_command("SnekStatus", function()
    log:trace(string.format("Snek is %s", api.is_running() and "running" or "not running"))
  end, {})

  vim.api.nvim_create_user_command("SnekShowLog", function()
    api.show_log()
  end, {})

  vim.api.nvim_create_user_command("SnekClearLog", function()
    api.clear_log()
  end, {})
end

return M
