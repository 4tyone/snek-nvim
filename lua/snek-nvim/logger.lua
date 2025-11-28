---@diagnostic disable: missing-parameter
local c = require("snek-nvim.config")
local loop = vim.uv or vim.loop

---@class Log
local log = {}

---@alias LogLevel "off" | "trace" | "debug" | "info" | "warn" | "error"

local level_values = {
  off = 0,
  trace = 1,
  debug = 2,
  info = 3,
  warn = 4,
  error = 5,
}

local join_path = function(...)
  local is_windows = loop.os_uname().version:match("Windows")
  local path_sep = is_windows and "\\" or "/"
  if vim.version().minor >= 10 then
    return table.concat(vim.iter({ ... }):flatten():totable(), path_sep):gsub(path_sep .. "+", path_sep)
  end
  return table.concat(vim.tbl_flatten({ ... }), path_sep):gsub(path_sep .. "+", path_sep)
end

local create_log_file = function()
  local log_path = log:get_log_path()
  if log_path ~= nil then
    return
  end
  if vim.fn.isdirectory(vim.fn.stdpath("cache")) == 0 then
    local cache_dir = vim.fn.stdpath("cache")
    if type(cache_dir) == "string" then
      vim.fn.mkdir(cache_dir, "p")
    elseif type(cache_dir) == "table" then
      cache_dir = cache_dir[1]
      vim.fn.mkdir(cache_dir, "p")
    end
  end

  log_path = join_path(vim.fn.stdpath("cache"), "snek-nvim.log")
  local file = io.open(log_path, "w")
  if file == nil then
    error("Failed to create log file: " .. log_path)
    return
  end
  file:close()
end

function log:write_log_file(level, msg)
  local log_path = log:get_log_path()
  if log_path == nil then
    create_log_file()
    return
  end
  local file = io.open(log_path, "a")
  if file == nil then
    vim.api.nvim_err_writeln("Failed to open log file: " .. log_path)
    return
  end
  file:write(string.format("[%-6s %s] %s\n", level:upper(), os.date(), msg))
  file:close()
end

function log:add_entry(level, msg)
  local conf = c.config

  if not self.__notify_fmt then
    self.__notify_fmt = function(message)
      return string.format("[snek] %s", message)
    end
  end

  if conf.log_level == "off" or level_values[conf.log_level] == nil then
    return
  end

  if self.__log_file == nil then
    self.__log_file = create_log_file()
  end

  self:write_log_file(level, msg)
  if level_values[level] >= level_values[conf.log_level] then
    print(self.__notify_fmt(msg))
  end
end

function log:get_log_path()
  local log_path = join_path(vim.fn.stdpath("cache"), "snek-nvim.log")
  if vim.fn.filereadable(log_path) == 0 then
    return nil
  end
  return log_path
end

function log:warn(msg)
  self:add_entry("warn", msg)
  vim.api.nvim_notify(self.__notify_fmt(msg), vim.log.levels.WARN, { title = "Snek" })
end

function log:error(msg)
  self:add_entry("error", msg)
  vim.api.nvim_notify(self.__notify_fmt(msg), vim.log.levels.ERROR, { title = "Snek" })
end

function log:info(msg)
  self:add_entry("info", msg)
end

function log:debug(msg)
  self:add_entry("debug", msg)
end

function log:trace(msg)
  self:add_entry("trace", msg)
end

setmetatable({}, log)
return log
