local log = require("snek-nvim.logger")

local M = {}

---Get the plugin's root directory
---@return string
local function get_plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":h:h:h:h")
end

---Get the path to the snek binary
---@return string
function M.get_binary_path()
  local plugin_root = get_plugin_root()
  local arch = vim.loop.os_uname().machine:lower()

  local arch_dir
  if arch:find("arm64") or arch:find("aarch64") then
    arch_dir = "arm64"
  else
    arch_dir = "x86_64"
  end

  return plugin_root .. "/bin/macos-" .. arch_dir .. "/snek"
end

return M
