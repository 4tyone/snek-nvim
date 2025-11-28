local lsp = require("snek-nvim.lsp.lsp_handler")
local log = require("snek-nvim.logger")
local u = require("snek-nvim.util")

local loop = u.uv

local M = {}

M.is_running = function()
  return lsp:is_running()
end

M.start = function()
  if M.is_running() then
    log:warn("Snek is already running.")
    return
  else
    log:trace("Starting Snek...")
  end
  vim.g.SNEK_DISABLED = 0
  lsp:start()
end

M.stop = function()
  vim.g.SNEK_DISABLED = 1
  if not M.is_running() then
    log:warn("Snek is not running.")
    return
  else
    log:trace("Stopping Snek...")
  end
  lsp:stop()
end

M.restart = function()
  if M.is_running() then
    M.stop()
  end
  M.start()
end

M.toggle = function()
  if M.is_running() then
    M.stop()
  else
    M.start()
  end
end

M.show_log = function()
  local log_path = log:get_log_path()
  if log_path ~= nil then
    vim.cmd.tabnew()
    vim.cmd(string.format(":e %s", log_path))
  else
    log:warn("No log file found to show!")
  end
end

M.clear_log = function()
  local log_path = log:get_log_path()
  if log_path ~= nil then
    loop.fs_unlink(log_path)
  else
    log:warn("No log file found to remove!")
  end
end

return M
